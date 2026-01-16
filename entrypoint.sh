#!/bin/bash

set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Check if application needs to be initialized
if [ ! -f /app/www/public/index.php ] || [ ! -f /app/firstrun ]; then
    log "Initializing application..."
    
    # Copy application files
    if [ -d /usr/src/www ]; then
        log "Copying application files from /usr/src/www to /app/www"
        cp -a /usr/src/www/. /app/www/
    else
        log "ERROR: Source directory /usr/src/www not found!"
        exit 1
    fi

    # Clean runtime cache
    if [ -d /app/www/runtime/cache ]; then
        log "Cleaning runtime cache..."
        rm -rf /app/www/runtime/*
    fi

    # Ensure runtime directory exists
    mkdir -p /app/www/runtime/{cache,log,temp}
    
    # Set proper permissions
    log "Setting permissions..."
    chown -R www:www /app/www
    chmod -R 755 /app/www
    chmod -R 777 /app/www/runtime

    # Mark as initialized
    touch /app/firstrun
    log "Application initialized successfully"
else
    log "Application already initialized, skipping..."
fi

# Validate critical files
if [ ! -f /app/www/public/index.php ]; then
    log "ERROR: index.php not found after initialization!"
    exit 1
fi

log "Starting services..."
exec "$@"