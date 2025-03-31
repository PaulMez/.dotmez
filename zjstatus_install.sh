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
               format_left   "{mode} #[fg=#89B4FA,bold]{session}"
                format_center "{tabs}"
                format_right  "{command_git_branch} {datetime}"
                format_space  ""

                border_enabled  "false"
                border_char     "─"
                border_format   "#[fg=#6C7086]{char}"
                border_position "top"

                hide_frame_for_single_pane "true"

                mode_normal  "#[bg=blue] "
                mode_tmux    "#[bg=#ffc387] "

                tab_normal   "#[fg=#6C7086] {name} "
                tab_active   "#[fg=#9399B2,bold,italic] {name} "

                command_git_branch_command     "git rev-parse --abbrev-ref HEAD"
                command_git_branch_format      "#[fg=blue] {stdout} "
                command_git_branch_interval    "10"
                command_git_branch_rendermode  "static"

                datetime        "#[fg=#6C7086,bold] {format} "
                datetime_format "%A, %d %b %Y %H:%M"
                datetime_timezone "Melbourne/Australia"
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
