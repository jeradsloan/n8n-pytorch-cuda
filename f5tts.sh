# --- Variables for clarity ---
# Path to your reference audio file ON THE SERVER snowball.scrappienet.lan
REF_AUDIO_SERVER_PATH="/home/piadmin/gen-ai/F5-TTS/voice-references/shorter11s--prezzie-voice-clone-cleanup_South_Park-S27E01-Sermon_on_the_Mount_HDTV-720p.wav"

# Content of your reference text file
# Using tr -d '\n' to ensure it's a single line and no issues with newlines in JSON
REF_TEXT_CONTENT=""

# Content of your generation text file
GEN_TEXT_CONTENT="Very proud of our great  Republican Senators for fighting, over the Weekend and far beyond, if necessary, in order to get my great Appointments approved, and on their way to helping us MAKE AMERICA GREAT AGAIN!"

# The model name or ID as it appears in the "Choose TTS Model" component
TTS_MODEL_NAME="F5TTS_v1_Base" # As per your CLI model name, check if UI uses "F5-TTS"

# Boolean for "Remove Silences"
REMOVE_SILENCES=false # Or false

# Numerical values for sliders
CROSS_FADE_DURATION=0.15 # Default from your CLI help
SPEED=1.0 # Default from your CLI help

# --- The CURL Command ---
curl -X POST http://snowball.scrappienet.lan:7861/gradio_api/call/infer -s -H "Content-Type: application/json" -d "{
  \"data\": [
    {\"path\":\"$REF_AUDIO_SERVER_PATH\",\"meta\":{\"_type\":\"gradio.FileData\"}},
    \"$REF_TEXT_CONTENT\",
    \"$GEN_TEXT_CONTENT\",
    \"$TTS_MODEL_NAME\",
    $REMOVE_SILENCES,
    $CROSS_FADE_DURATION,
    $SPEED
  ]
}" \
  | awk -F'"' '{ print $4}'  \
  | read EVENT_ID; curl -N http://snowball.scrappienet.lan:7861/gradio_api/call/infer/$EVENT_ID
