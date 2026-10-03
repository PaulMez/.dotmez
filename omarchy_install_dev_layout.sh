#!/bin/bash
#
# Install the "dev layout" shortcuts on an Omarchy machine: terminals across
# the top half of the current workspace, the browser across the bottom half.
#
#   configs/bin/mez-dev-layout  -> ~/.local/bin/mez-dev-layout
#   SUPER+SHIFT+L  4 terminals  \
#   SUPER+SHIFT+K  3 terminals   > appended to ~/.config/hypr/bindings.lua
#   SUPER+SHIFT+J  2 terminals  /
#
# bindings.lua is PATCHED, not replaced: it holds other personal bindings that
# are not tracked here, so only the marked lines are added (or removed).
# The script uses whatever terminal and browser Omarchy is configured with.
#
# Flags:
#   --dry-run   print what would change, write nothing
#   --remove    delete the script and the binding again
#   -h|--help   show this header
#
# Safe to re-run: every step is idempotent and backs up before writing.

set -euo pipefail

BIND_COMMENT='-- Dev layout: terminals across the top half, browser across the bottom half (~/.local/bin/mez-dev-layout).'
BIND_LINES=(
    'o.bind("SUPER + SHIFT + L", "Dev layout", "mez-dev-layout")'
    'o.bind("SUPER + SHIFT + K", "Dev layout (3)", "mez-dev-layout 3")'
    'o.bind("SUPER + SHIFT + J", "Dev layout (2)", "mez-dev-layout 2")'
)
BIND_KEYS="SUPER+SHIFT+L/K/J"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

DRY_RUN=false
REMOVE=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --remove)   REMOVE=true ;;
        -h|--help)  sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d%H%M%S)"
src="$script_dir/configs/bin/mez-dev-layout"
dst="$HOME/.local/bin/mez-dev-layout"
bindings="$HOME/.config/hypr/bindings.lua"

info() { printf "%b\n" "$1"; }
ok()   { printf "${GREEN}%s${RESET}\n" "$1"; }
warn() { printf "${YELLOW}warning: %s${RESET}\n" "$1" >&2; }
skip() { printf "skip: %s\n" "$1"; }

# Escape a literal string for use as a sed address.
sed_lit() { printf '%s' "$1" | sed 's/[][\\.*^$/]/\\&/g'; }
# Key name ("SUPER + SHIFT + L") out of an o.bind line.
bind_key() { printf '%s' "$1" | sed -E 's/^o\.bind\("([^"]+)".*/\1/'; }
# Command (last quoted argument) out of an o.bind line.
bind_cmd() { printf '%s' "$1" | sed -E 's/.*, "([^"]+)"\)$/\1/'; }

backup_file() {
    local target="$1"
    [ -f "$target" ] || return 0
    if $DRY_RUN; then
        info "  would back up $target -> $target.bak.$stamp"
    else
        cp "$target" "$target.bak.$stamp"
        info "  backed up -> $target.bak.$stamp"
    fi
}

reload_hyprland() {
    if $DRY_RUN; then
        info "  dry run: nothing reloaded"
    elif command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl reload >/dev/null
        errors="$(hyprctl configerrors 2>/dev/null)"
        if [ -n "$errors" ]; then
            printf "${RED}hyprland config errors:${RESET}\n%s\n" "$errors" >&2
        else
            ok "  hyprland reloaded, no config errors"
        fi
    else
        skip "hyprctl reload (not in a Hyprland session)"
    fi
}

# ---- remove ------------------------------------------------------------------
if $REMOVE; then
    info "\n== Remove dev layout =="
    if [ -f "$dst" ]; then
        if $DRY_RUN; then info "  would delete $dst"; else rm "$dst"; ok "  deleted $dst"; fi
    else
        skip "$dst (not installed)"
    fi
    present=false
    for line in "${BIND_LINES[@]}"; do
        [ -f "$bindings" ] && grep -qF "$line" "$bindings" && present=true
    done
    if $present; then
        if $DRY_RUN; then
            info "  would remove the $BIND_KEYS bindings from $bindings"
        else
            backup_file "$bindings"
            # Drop the bind lines and their comment, then any trailing blank lines.
            sed -i -e "/^$(sed_lit "$BIND_COMMENT")\$/d" "$bindings"
            for line in "${BIND_LINES[@]}"; do
                sed -i -e "/^$(sed_lit "$line")\$/d" "$bindings"
            done
            sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$bindings"
            ok "  $BIND_KEYS bindings removed"
        fi
    else
        skip "$BIND_KEYS bindings (not present)"
    fi
    info "\n== Apply =="
    reload_hyprland
    exit 0
fi

# ---- 1. script -----------------------------------------------------------------
info "\n== Layout script =="

[ -f "$src" ] || { echo "error: $src not found" >&2; exit 1; }
for dep in jq flock xdg-terminal-exec omarchy-launch-browser; do
    command -v "$dep" >/dev/null 2>&1 || warn "$dep not found on PATH; the layout script needs it"
done

if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    skip "mez-dev-layout (identical)"
elif $DRY_RUN; then
    info "  would install $src -> $dst"
else
    mkdir -p "$(dirname "$dst")"
    backup_file "$dst"
    install -m 755 "$src" "$dst"
    ok "  mez-dev-layout installed -> $dst"
fi

# ---- 2. binding ----------------------------------------------------------------
info "\n== Hyprland binding =="

if [ ! -f "$bindings" ]; then
    warn "$bindings not found; is this an Omarchy machine? Skipping the bindings."
else
    # Work out which of our lines are missing; refuse a key someone else already uses.
    missing=()
    for line in "${BIND_LINES[@]}"; do
        key="$(bind_key "$line")"
        if grep -qF "$line" "$bindings"; then
            skip "$key binding (already present)"
        elif grep -qE "^[^-]*\"$key\"" "$bindings"; then
            warn "$key is already bound to something else in $bindings; not adding ours."
        else
            missing+=("$line")
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        if $DRY_RUN; then
            info "  would append ${#missing[@]} binding(s) to $bindings"
        else
            backup_file "$bindings"
            # One comment block for ours; add it only the first time.
            grep -qF -- "$BIND_COMMENT" "$bindings" || printf '\n%s\n' "$BIND_COMMENT" >> "$bindings"
            printf '%s\n' "${missing[@]}" >> "$bindings"
            for line in "${missing[@]}"; do ok "  $(bind_key "$line") -> $(bind_cmd "$line")"; done
        fi
    fi
fi

# ---- 3. apply ------------------------------------------------------------------
info "\n== Apply =="
reload_hyprland

cat <<'NOTES'

Notes:
  - SUPER+SHIFT+L = 4 terminals, SUPER+SHIFT+K = 3, SUPER+SHIFT+J = 2.
    Any count 1-8 works from a shell: `mez-dev-layout N`.
  - Re-running the shortcut reuses the windows already on the workspace; it
    never closes a terminal.
  - Undo everything with:  ./omarchy_install_dev_layout.sh --remove
NOTES
