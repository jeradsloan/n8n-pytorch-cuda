# N8N PyTorch CUDA Environment Status

## Base Environment
- Base Image: `nvcr.io/nvidia/pytorch:24.01-py3`
- Python Version: 3.10
- Node.js Version: 20.x
- N8N: Latest version (auto-updates during build)

## Key Components

### Browser Automation
- Chrome Browser: Google Chrome Stable (installed via official Google repository)
- Puppeteer: Latest version (globally installed)
- Configuration:
  - Using system-installed Google Chrome
  - Puppeteer configured to skip Chromium download
  - Browser path: `/usr/bin/google-chrome`
  - Running with `--no-sandbox` flag for Docker compatibility

### Python Environment
- Core Dependencies (from requirements.txt):
  - pillow >= 10.0.0
  - requests >= 2.31.0
  - aiohttp >= 3.9.0
  - numpy >= 1.24.0
  - scikit-image >= 0.22.0
  - transformers >= 4.36.0
  - opencv-python-headless >= 4.9.0
  - beautifulsoup4 >= 4.12.0
  - lxml >= 5.1.0
  - linkpreview >= 0.11.0
  - cairosvg >= 2.7.1

### N8N Configuration
- Installation: Global installation with latest version
- Mode: Production
- Release Type: Stable
- User Folder: `/home/node/.n8n`

### System User
- Main User: `node` (UID: 1000)
- Home Directory: `/home/node`
- Sudo Access: Yes (passwordless)

## Build Process Optimizations
- NPM cache cleared before n8n installation
- Force flag used for n8n installation to ensure latest version
- Cleanup of unnecessary files after installation
- Removed unused n8n components:
  - @n8n/chat
  - n8n-design-system
  - Redundant node_modules

## Running Python Scripts
All Python scripts should be run inside the container to ensure proper environment and dependencies. The container provides all necessary dependencies and configurations.

### Using the CLI Tools
1. First, enter the container:
```bash
docker exec -it n8n-pytorch-cuda-pytorch-n8n-1 bash
```

2. Navigate to the Python scripts directory:
```bash
cd /data/python-scripts/n8n-python-tools
```

3. Run the scripts. Examples:
```bash
# Extract images from HTML
python app.py images --html @input.json --url "https://example.com"

# Extract links from HTML
python app.py links --html @input.json

# Resolve URL redirects
python app.py resolve_url --url "https://example.com"
```

### Running Tests
```bash
# Run all tests
pytest

# Run specific test file
pytest tests/test_html_utils.py

# Run with verbose output
pytest -v tests/test_html_utils.py
```

### Environment Variables
The container comes with pre-configured environment variables. If you need to add or modify them:
1. Create a `.env` file in the Python scripts directory
2. Add your variables:
```env
BROWSERLESS_URL=https://browserless.example.com
BROWSERLESS_API_TOKEN=your_token
BROWSERLESS_PROXY=socks5://user:pass@proxy:1080
```

## Environment Variables
```bash
NODE_ENV=production
N8N_RELEASE_TYPE=stable
SHELL=/bin/bash
PATH="/usr/local/bin:/usr/bin:$PATH"
NODE_PATH="/usr/local/lib/node_modules"
N8N_USER_FOLDER=/home/node/.n8n
HOME=/home/node
NPM_CONFIG_PREFIX=/usr/local
PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome
PYTHONPATH="${PYTHONPATH}:/home/node/.local/lib/python3.10/site-packages"
```

## Last Updated
- Date: 2024-12-07
- Status: Working configuration with browser automation support
- Note: To update this date, use `date` command in terminal to get current date in format: `Sat Dec 7 02:11:23 PM PST 2024`
