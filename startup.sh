#!/bin/bash

# Fix npm directory permissions
sudo chown -R 1000:1000 /home/node/.npm

# Create Python user packages directory if it doesn't exist
mkdir -p "$HOME/.local/lib/python3.10/site-packages"

# Install additional Python packages
echo 'Installing additional Python packages...'
if ! pip install --no-cache-dir --user jupyter matplotlib; then
    echo "Warning: Failed to install some Python packages, continuing anyway..."
fi

# Check if requirements need to be installed
if [ -f /data/python-scripts/n8n-python-tools/requirements.txt ]; then
    echo "Checking project Python requirements..."
    if ! pip freeze | grep -q "aiohttp_socks"; then
        echo "Installing missing project requirements..."
        if ! pip install --user -r /data/python-scripts/n8n-python-tools/requirements.txt; then
            echo "Warning: Failed to install some project requirements, continuing anyway..."
        fi
    else
        echo "Project requirements already installed."
    fi
fi

# Initialize database directory if it doesn't exist
if [ ! -d "$N8N_USER_FOLDER" ]; then
    echo "Creating n8n user folder..."
    mkdir -p "$N8N_USER_FOLDER"
fi

echo "Starting n8n..."
exec n8n start
