#!/bin/bash

# Set variables
REPO="dj95/zjstatus"
INSTALL_DIR="$HOME/.config/zellij/plugins"  # Where zjstatus will be stored
LAYOUT_DIR="$HOME/.config/zellij/layouts"  # Zellij layouts directory
LAYOUT_FILE="$LAYOUT_DIR/default.kdl"      # Default layout file

# Ensure necessary directories exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$LAYOUT_DIR"

# Get the latest release tag
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

# Get the latest zjstatus.wasm download URL
ASSET_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep -Po '"browser_download_url": "\K.*?(?=")' | grep 'zjstatus.wasm' | head -n 1)

# Define the download location
DEST_FILE="$INSTALL_DIR/zjstatus.wasm"

# Download and install
if [[ -n "$ASSET_URL" ]]; then
    echo "Downloading zjstatus ($LATEST_TAG) from: $ASSET_URL"
    curl -L "$ASSET_URL" -o "$DEST_FILE"
    echo "zjstatus installed successfully at $DEST_FILE"
else
    echo "Failed to find a suitable binary to download."
    exit 1
fi

# Create or update the default layout file
if [[ ! -f "$LAYOUT_FILE" ]]; then
    echo "Creating default layout file: $LAYOUT_FILE"
    cat > "$LAYOUT_FILE" <<EOL
layout {
    default_tab_template {
        children
        pane size=1 borderless=true {
            plugin location="file:$DEST_FILE" {
                // plugin configuration...
            }
        }
    }
}
EOL
    echo "Default layout configured at $LAYOUT_FILE"
else
    echo "Default layout file already exists. Please update it manually if needed."
fi

echo "Installation complete! Restart Zellij and apply the layout."
