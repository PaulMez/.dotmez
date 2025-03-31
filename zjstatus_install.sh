#!/bin/bash
#bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/PaulMez/.dotmez/refs/heads/main/zjstatus_install.sh)"
# Set variables
REPO="dj95/zjstatus"
INSTALL_DIR="$HOME/.config/zellij/plugins"  # Where zjstatus will be stored
LAYOUT_DIR="$HOME/.config/zellij/layouts"  # Zellij layouts directory
LAYOUT_FILE="$LAYOUT_DIR/default.kdl"      # Default layout file
DEST_FILE="$INSTALL_DIR/zjstatus.wasm"     # Plugin file location

# Ensure necessary directories exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$LAYOUT_DIR"

# Remove existing zjstatus.wasm file if it exists
if [[ -f "$DEST_FILE" ]]; then
    echo "Removing existing zjstatus.wasm..."
    rm -f "$DEST_FILE"
fi

# Get the latest release tag
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

# Get the latest zjstatus.wasm download URL
ASSET_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep -Po '"browser_download_url": "\K.*?(?=")' | grep 'zjstatus.wasm' | head -n 1)

# Download and install
if [[ -n "$ASSET_URL" ]]; then
    echo "Downloading zjstatus ($LATEST_TAG) from: $ASSET_URL"
    curl -L "$ASSET_URL" -o "$DEST_FILE"
    echo "zjstatus installed successfully at $DEST_FILE"
else
    echo "Failed to find a suitable binary to download."
    exit 1
fi

# Remove existing layout file if it exists
if [[ -f "$LAYOUT_FILE" ]]; then
    echo "Removing existing layout file..."
    rm -f "$LAYOUT_FILE"
fi

# Create the new default layout file
echo "Creating new default layout file: $LAYOUT_FILE"
cat > "$LAYOUT_FILE" <<EOL
layout {
    default_tab_template {
        children
        pane size=1 borderless=true {
            plugin location="file:$DEST_FILE" {
                format_left  "{mode}#[fg=black,bg=blue,bold]{session}  #[fg=blue,bg=#181825]{tabs}"
                format_right "#[fg=#181825,bg=#b1bbfa]{datetime}"
                format_space "#[bg=#181825]"
    
                hide_frame_for_single_pane "true"
    
                mode_normal  "#[bg=blue] "
    
                tab_normal              "#[fg=#181825,bg=#4C4C59] #[fg=#000000,bg=#4C4C59]{index}  {name} #[fg=#4C4C59,bg=#181825]"
                tab_normal_fullscreen   "#[fg=#6C7086,bg=#181825] {index} {name} [] "
                tab_normal_sync         "#[fg=#6C7086,bg=#181825] {index} {name} <> "
                tab_active              "#[fg=#181825,bg=#ffffff,bold,italic] {index}  {name} #[fg=#ffffff,bg=#181825]"
                tab_active_fullscreen   "#[fg=#9399B2,bg=#181825,bold,italic] {index} {name} [] "
                tab_active_sync         "#[fg=#9399B2,bg=#181825,bold,italic] {index} {name} <> "
    
    
                datetime          "#[fg=#6C7086,bg=#b1bbfa,bold] {format} "
                datetime_format   "%A, %d %b %Y %H:%M"
                datetime_timezone "Australia/Melbourne"
            }
        }
    }
}
EOL

echo "Default layout configured at $LAYOUT_FILE"
