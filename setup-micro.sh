#!/usr/bin/env bash

set -e

echo "🚀 Setting up Micro editor..."

CONFIG_DIR="$HOME/.config/micro"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

mkdir -p "$CONFIG_DIR"

cat > "$SETTINGS_FILE" <<'EOF'
{
    "autoclose": true,
    "autosave": 0,
    "colorscheme": "monokai",
    "cursorline": true,
    "diffgutter": true,
    "mouse": true,
    "softwrap": true,
    "status": true,
    "tabsize": 4,
    "tabstospaces": true,
    "autoindent": true,
    "hlsearch": true,
    "syntax": true
}
EOF

echo "✅ Micro settings installed"

echo "📦 Installing Micro plugins..."

micro -plugin install filemanager || true

echo "✅ Plugins installed"

echo ""
echo "🎉 Micro setup complete!"
echo ""
echo "Run:"
echo "  micro filename.py"
echo ""
echo "Useful shortcuts:"
echo "  Ctrl+S       Save"
echo "  Ctrl+F       Search"
echo "  Ctrl+Z       Undo"
echo "  Ctrl+V       Paste"
echo "  Ctrl+E       Command mode"
