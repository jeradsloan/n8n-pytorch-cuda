FROM nvcr.io/nvidia/pytorch:24.01-py3

# Set NVIDIA Container Runtime configs
ENV NVIDIA_VISIBLE_DEVICES=0
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,video
ENV NVIDIA_REQUIRE_CUDA="cuda>=12.4"

# Update pip
RUN python -m pip install --upgrade pip

# Install Node.js and build dependencies
RUN apt-get update && \
    apt-get install -y curl gnupg python3-dev build-essential sudo nano python3-bs4 python3-requests python3-lxml graphicsmagick libcairo2-dev pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libgdk-pixbuf2.0-dev \
    shared-mime-info \
    && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    # Add Google Chrome repository
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y nodejs google-chrome-stable && \
    npm install -g npm@latest && \
    # Install Chrome and its dependencies
    apt-get install -y ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 \
    libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 \
    libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 \
    libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 \
    libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release wget \
    xdg-utils && \
    # Install Puppeteer globally with Chrome
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true npm install -g puppeteer && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "node ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Create node user and set up directories
RUN useradd -m -s /bin/bash node && \
    mkdir -p /home/node/.n8n && \
    mkdir -p /home/node/.npm && \
    mkdir -p /home/node/.npm-global && \
    mkdir -p /usr/local/lib/node_modules && \
    chown -R node:node /home/node && \
    chown -R node:node /usr/local/lib/node_modules && \
    chown -R 1000:1000 /home/node/.npm

# Set environment variables
ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=stable \
    SHELL=/bin/bash \
    PATH="/usr/local/bin:/usr/bin:$PATH" \
    NODE_PATH="/usr/local/lib/node_modules" \
    N8N_USER_FOLDER=/home/node/.n8n \
    HOME=/home/node \
    NPM_CONFIG_PREFIX=/usr/local \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome \
    PUPPETEER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage" \
    PYTHONPATH="${PYTHONPATH}:/home/node/.local/lib/python3.10/site-packages"

# Set up Chrome directories and permissions
RUN mkdir -p /home/node/.cache/puppeteer && \
    chown -R node:node /home/node/.cache && \
    chmod -R 777 /home/node/.cache/puppeteer && \
    chown -R node:node /usr/bin/google-chrome && \
    chmod 755 /usr/bin/google-chrome

# Install n8n with specific version and clean up
RUN npm cache clean --force && \
    npm install -g --omit=dev n8n@latest --ignore-scripts --force && \
    npm rebuild --prefix=/usr/local/lib/node_modules/n8n sqlite3 && \
    rm -rf /usr/local/lib/node_modules/n8n/node_modules/@n8n/chat && \
    rm -rf /usr/local/lib/node_modules/n8n/node_modules/n8n-design-system && \
    rm -rf /usr/local/lib/node_modules/n8n/node_modules/n8n-editor-ui/node_modules && \
    rm -rf /home/node/.n8n/.n8n/nodes/node_modules/n8n-nodes-base && \
    find /usr/local/lib/node_modules/n8n -type f -name "*.ts" -o -name "*.js.map" -o -name "*.vue" | xargs rm -f && \
    rm -rf /root/.npm && \
    chown -R node:node /usr/local/lib/node_modules && \
    mkdir -p /home/node/.n8n/.n8n && \
    chmod 700 /home/node/.n8n/.n8n

# Copy startup script
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh && \
    chown node:node /startup.sh

# Copy and install Python requirements
COPY data/python-scripts/n8n-python-tools/requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt && rm /tmp/requirements.txt


## UV INSTALL -- astral https://docs.astral.sh
# Install uv as root
RUN curl -LsSf https://astral.sh/uv/install.sh > /tmp/uv-install.sh
RUN sh /tmp/uv-install.sh
RUN rm /tmp/uv-install.sh

# Create the target directory and symlink (as root)
RUN mkdir -p /usr/local/bin
RUN ln -s /home/node/.local/bin/uv /usr/local/bin/uv

# Give ownership of /usr/local/bin/uv and the target to node
RUN chown -R node:node /home/node/.local/bin
RUN chown node:node /usr/local/bin/uv

## USER NODE - switch to node user
USER node

## UV install stuff
 ENV PATH="$PATH:/home/node/.local/bin"
# Verify installation (as node)
 RUN which uv
 RUN uv --version

ENTRYPOINT ["/startup.sh"]
