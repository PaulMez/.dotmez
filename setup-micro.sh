#!/usr/bin/env bash

set -e

echo "🚀 Setting up Micro editor..."

CONFIG_DIR="$HOME/.config/micro"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

mkdir -p "$CONFIG_DIR"

# Only non-default options are listed. Micro strips keys that match its own
# defaults (and silently drops unknown keys) when it rewrites this file on exit,
# so listing defaults here just makes the file churn.
cat > "$SETTINGS_FILE" <<'EOF'
{
    "colorscheme": "monokai-dark",
    "diffgutter": true,
    "hlsearch": true,
    "softwrap": true,
    "tabstospaces": true,
    "lsp.server": "python=pyright-langserver --stdio,rust=rust-analyzer,go=gopls,typescript=typescript-language-server --stdio,javascript=typescript-language-server --stdio,c++=clangd",
    "lsp.formatOnSave": true,
    "lsp.tabcompletion": true,
    "lsp.autocompleteDetails": false
}
EOF

echo "✅ Micro settings installed"

echo "📦 Installing Micro plugins..."

micro -plugin install filemanager || true
micro -plugin install lsp || true

echo "✅ Plugins installed"

# monokai-dark is a truecolor (hex) colorscheme. Without these, micro falls back
# to a 256-color approximation and the theme looks washed out.
if ! grep -q "MICRO_TRUECOLOR" "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'EOF'

# Truecolor for micro (monokai-dark is a hex-based colorscheme)
export COLORTERM=truecolor
export MICRO_TRUECOLOR=1
EOF
    echo "✅ Truecolor exports added to ~/.zshrc"
else
    echo "ℹ️  Truecolor exports already present in ~/.zshrc"
fi

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
echo ""
echo "LSP shortcuts (see MICRO-NOTES.md for language server installs):"
echo "  Ctrl+Space   Autocomplete"
echo "  Alt+K        Hover docs"
echo "  Alt+D        Go to definition"
echo "  Alt+R        Find references"
echo "  Alt+F        Format"
