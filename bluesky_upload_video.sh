#!/bin/bash

# Bluesky Video Upload Script
# Usage: ./bluesky_upload_video.sh <video_path> <post_text> [handle] [password]
# 
# Environment variables (if not provided as args):
# - BLUESKY_HANDLE: Your Bluesky handle
# - BLUESKY_PASSWORD: Your Bluesky app password

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Parse arguments
VIDEO_PATH="${1}"
POST_TEXT="${2:-"Check out this video!"}"
BLUESKY_HANDLE="${3:-${BLUESKY_HANDLE}}"
BLUESKY_PASSWORD="${4:-${BLUESKY_PASSWORD}}"

# Validate inputs
if [ -z "$VIDEO_PATH" ]; then
    log_error "Usage: $0 <video_path> <post_text> [handle] [password]"
    exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
    log_error "Video file not found: $VIDEO_PATH"
    exit 1
fi

if [ -z "$BLUESKY_HANDLE" ] || [ -z "$BLUESKY_PASSWORD" ]; then
    log_error "BLUESKY_HANDLE and BLUESKY_PASSWORD must be set (via env vars or args)"
    exit 1
fi

# Get video filename and size
VIDEO_FILENAME=$(basename "$VIDEO_PATH")
VIDEO_SIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH")

log_info "Starting Bluesky video upload process..."
log_info "Video: $VIDEO_FILENAME (${VIDEO_SIZE} bytes)"

# Step 1: Create session
log_info "Step 1: Authenticating with Bluesky..."
SESSION_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"identifier\":\"${BLUESKY_HANDLE}\",\"password\":\"${BLUESKY_PASSWORD}\"}" \
    "https://bsky.social/xrpc/com.atproto.server.createSession")

# Check for errors
if echo "$SESSION_RESPONSE" | grep -q "error"; then
    log_error "Authentication failed:"
    echo "$SESSION_RESPONSE" | jq '.'
    exit 1
fi

ACCESS_JWT=$(echo "$SESSION_RESPONSE" | jq -r '.accessJwt')
DID=$(echo "$SESSION_RESPONSE" | jq -r '.did')
HANDLE=$(echo "$SESSION_RESPONSE" | jq -r '.handle')

log_info "Authenticated as: $HANDLE ($DID)"

# Step 2: Resolve PDS host from DID
log_info "Step 2: Resolving PDS host..."
DID_DOC=$(curl -s "https://plc.directory/${DID}")
PDS_ENDPOINT=$(echo "$DID_DOC" | jq -r '.service[] | select(.type == "AtprotoPersonalDataServer") | .serviceEndpoint')
PDS_HOST=$(echo "$PDS_ENDPOINT" | sed 's|https://||' | sed 's|http://||')
PDS_DID="did:web:${PDS_HOST}"

log_info "PDS Host: $PDS_HOST"
log_info "PDS DID: $PDS_DID"

# Step 3: Get service auth token for video upload
log_info "Step 3: Getting service auth token..."
EXPIRY=$(($(date +%s) + 1800))  # 30 minutes from now

SERVICE_AUTH_RESPONSE=$(curl -s -G \
    -H "Authorization: Bearer ${ACCESS_JWT}" \
    --data-urlencode "aud=${PDS_DID}" \
    --data-urlencode "lxm=com.atproto.repo.uploadBlob" \
    --data-urlencode "exp=${EXPIRY}" \
    "https://bsky.social/xrpc/com.atproto.server.getServiceAuth")

SERVICE_TOKEN=$(echo "$SERVICE_AUTH_RESPONSE" | jq -r '.token')

if [ "$SERVICE_TOKEN" == "null" ] || [ -z "$SERVICE_TOKEN" ]; then
    log_error "Failed to get service auth token:"
    echo "$SERVICE_AUTH_RESPONSE" | jq '.'
    exit 1
fi

log_info "Service token obtained"

# Step 4: Upload video to video service
log_info "Step 4: Uploading video to video service..."
UPLOAD_URL="https://video.bsky.app/xrpc/app.bsky.video.uploadVideo?did=${DID}&name=${VIDEO_FILENAME}"

UPLOAD_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${SERVICE_TOKEN}" \
    -H "Content-Type: video/mp4" \
    -H "Content-Length: ${VIDEO_SIZE}" \
    --data-binary "@${VIDEO_PATH}" \
    "${UPLOAD_URL}")

# Step 5: Poll for video processing status
log_info "Step 5: Waiting for video processing..."
MAX_ATTEMPTS=120  # 2 minutes max (120 * 1 second)
ATTEMPT=0
BLOB_REF=""
STATUS_RESPONSE=""

# Check for upload errors (but handle "already_exists" specially)
ERROR_TYPE=$(echo "$UPLOAD_RESPONSE" | jq -r '.error // empty')
if [ -n "$ERROR_TYPE" ]; then
    if [ "$ERROR_TYPE" == "already_exists" ]; then
        log_warn "Video already processed (duplicate detected)"
        JOB_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.jobId')
        log_info "Using existing Job ID: $JOB_ID"
        # Video is already complete, fetch the blob
        STATE=$(echo "$UPLOAD_RESPONSE" | jq -r '.state')
        if [ "$STATE" == "JOB_STATE_COMPLETED" ]; then
            log_info "Video already completed, fetching blob..."
            STATUS_RESPONSE=$(curl -s -G \
                --data-urlencode "jobId=${JOB_ID}" \
                "https://video.bsky.app/xrpc/app.bsky.video.getJobStatus")
            BLOB_REF=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.blob // empty')
            if [ -n "$BLOB_REF" ] && [ "$BLOB_REF" != "null" ]; then
                # Skip polling loop
                ATTEMPT=$MAX_ATTEMPTS
            fi
        fi
    else
        log_error "Video upload failed:"
        echo "$UPLOAD_RESPONSE" | jq '.'
        exit 1
    fi
else
    JOB_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.jobId')
    log_info "Upload initiated. Job ID: $JOB_ID"
fi

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    sleep 1
    ATTEMPT=$((ATTEMPT + 1))
    
    STATUS_RESPONSE=$(curl -s -G \
        --data-urlencode "jobId=${JOB_ID}" \
        "https://video.bsky.app/xrpc/app.bsky.video.getJobStatus")
    
    STATE=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.state')
    PROGRESS=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.progress // 0')
    
    log_info "Processing: $STATE (${PROGRESS}%)"
    
    # Check if blob is available
    BLOB_REF=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.blob // empty')
    
    if [ -n "$BLOB_REF" ] && [ "$BLOB_REF" != "null" ]; then
        log_info "Video processing complete!"
        break
    fi
    
    # Check for errors
    if echo "$STATUS_RESPONSE" | grep -q '"state":"JOB_STATE_FAILED"'; then
        log_error "Video processing failed:"
        echo "$STATUS_RESPONSE" | jq '.'
        exit 1
    fi
done

if [ -z "$BLOB_REF" ] || [ "$BLOB_REF" == "null" ]; then
    log_error "Video processing timed out after ${MAX_ATTEMPTS} seconds"
    exit 1
fi

# Extract blob details
BLOB_LINK=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.blob.ref["$link"]')
BLOB_MIME=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.blob.mimeType')
BLOB_SIZE=$(echo "$STATUS_RESPONSE" | jq -r '.jobStatus.blob.size')

log_info "Blob ready: $BLOB_LINK"

# Step 6: Get video aspect ratio (try ffprobe, fallback to 16:9)
log_info "Step 6: Detecting video aspect ratio..."
if command -v ffprobe &> /dev/null; then
    VIDEO_WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO_PATH" 2>/dev/null || echo "1920")
    VIDEO_HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO_PATH" 2>/dev/null || echo "1080")
else
    log_warn "ffprobe not found, using default 16:9 aspect ratio"
    VIDEO_WIDTH=1920
    VIDEO_HEIGHT=1080
fi

log_info "Aspect ratio: ${VIDEO_WIDTH}x${VIDEO_HEIGHT}"

# Step 7: Create post with video
log_info "Step 7: Creating post..."
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

POST_RECORD=$(cat <<EOF
{
  "repo": "${DID}",
  "collection": "app.bsky.feed.post",
  "record": {
    "\$type": "app.bsky.feed.post",
    "text": "${POST_TEXT}",
    "createdAt": "${CREATED_AT}",
    "langs": ["en"],
    "embed": {
      "\$type": "app.bsky.embed.video",
      "video": {
        "\$type": "blob",
        "ref": {
          "\$link": "${BLOB_LINK}"
        },
        "mimeType": "${BLOB_MIME}",
        "size": ${BLOB_SIZE}
      },
      "aspectRatio": {
        "width": ${VIDEO_WIDTH},
        "height": ${VIDEO_HEIGHT}
      }
    }
  }
}
EOF
)

POST_RESPONSE=$(curl -s -X POST \
    -H "Authorization: Bearer ${ACCESS_JWT}" \
    -H "Content-Type: application/json" \
    -d "$POST_RECORD" \
    "https://bsky.social/xrpc/com.atproto.repo.createRecord")

# Check for post creation errors
if echo "$POST_RESPONSE" | grep -q "error"; then
    log_error "Post creation failed:"
    echo "$POST_RESPONSE" | jq '.'
    exit 1
fi

POST_URI=$(echo "$POST_RESPONSE" | jq -r '.uri')
POST_CID=$(echo "$POST_RESPONSE" | jq -r '.cid')

log_info "✅ Success! Post created:"
log_info "URI: $POST_URI"
log_info "CID: $POST_CID"

# Extract the post ID from URI for web link
POST_ID=$(echo "$POST_URI" | sed 's|.*app.bsky.feed.post/||')
WEB_URL="https://bsky.app/profile/${HANDLE}/post/${POST_ID}"

log_info "View at: $WEB_URL"
