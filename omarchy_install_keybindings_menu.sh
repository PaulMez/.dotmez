#!/bin/bash
#
# Point SUPER+K at a keybindings menu that lists the personal bindings from
# ~/.config/hypr/bindings.lua first (newest on top), then Omarchy's stock list.
#
#   configs/bin/mez-menu-keybindings -> ~/.local/bin/mez-menu-keybindings
#   hl.unbind("SUPER + K") + o.bind("SUPER + K", ...) appended to bindings.lua
#
# bindings.lua is PATCHED, not replaced: only the marked lines are added (or
# removed with --remove). The stock menu stays available as
# `omarchy menu keybindings`.
#
# Flags:
#   --dry-run   print what would change, write nothing
#   --remove    delete the script and restore the stock SUPER+K binding
#   -h|--help   show this header
#
# Safe to re-run: every step is idempotent and backs up before writing.

set -euo pipefail

BIND_COMMENT='-- Keybindings menu with personal bindings pinned to the top (~/.local/bin/mez-menu-keybindings).'
BIND_LINES=(
    'hl.unbind("SUPER + K")'
    'o.bind("SUPER + K", "Keybindings", "mez-menu-keybindings")'
)

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
        -h|--help)  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d%H%M%S)"
src="$script_dir/configs/bin/mez-menu-keybindings"
dst="$HOME/.local/bin/mez-menu-keybindings"
bindings="$HOME/.config/hypr/bindings.lua"

info() { printf "%b\n" "$1"; }
ok()   { printf "${GREEN}%s${RESET}\n" "$1"; }
warn() { printf "${YELLOW}warning: %s${RESET}\n" "$1" >&2; }
skip() { printf "skip: %s\n" "$1"; }

sed_lit() { printf '%s' "$1" | sed 's/[][\\.*^$/]/\\&/g'; }

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

all_present() {
    [ -f "$bindings" ] || return 1
    for line in "${BIND_LINES[@]}"; do
        grep -qF -- "$line" "$bindings" || return 1
    done
}

# ---- remove ------------------------------------------------------------------
if $REMOVE; then
    info "\n== Remove keybindings menu =="
    if [ -f "$dst" ]; then
        if $DRY_RUN; then info "  would delete $dst"; else rm "$dst"; ok "  deleted $dst"; fi
    else
        skip "$dst (not installed)"
    fi
    if [ -f "$bindings" ] && grep -qF -- "${BIND_LINES[1]}" "$bindings"; then
        if $DRY_RUN; then
            info "  would remove the SUPER+K override from $bindings"
        else
            backup_file "$bindings"
            sed -i -e "/^$(sed_lit "$BIND_COMMENT")\$/d" "$bindings"
            for line in "${BIND_LINES[@]}"; do
                sed -i -e "/^$(sed_lit "$line")\$/d" "$bindings"
            done
            sed -i -e ':a' -e '/^\n*$/{$d;N;ba' -e '}' "$bindings"
            ok "  SUPER+K override removed (stock menu is back)"
        fi
    else
        skip "SUPER+K override (not present)"
    fi
    info "\n== Apply =="
    reload_hyprland
    exit 0
fi

# ---- 1. script -----------------------------------------------------------------
info "\n== Menu script =="

[ -f "$src" ] || { echo "error: $src not found" >&2; exit 1; }
for dep in omarchy-menu-keybindings omarchy-menu-select hyprctl; do
    command -v "$dep" >/dev/null 2>&1 || warn "$dep not found on PATH; the menu script needs it"
done

if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    skip "mez-menu-keybindings (identical)"
elif $DRY_RUN; then
    info "  would install $src -> $dst"
else
    mkdir -p "$(dirname "$dst")"
    backup_file "$dst"
    install -m 755 "$src" "$dst"
    ok "  mez-menu-keybindings installed -> $dst"
fi

# ---- 2. binding ----------------------------------------------------------------
info "\n== Hyprland binding =="

if [ ! -f "$bindings" ]; then
    warn "$bindings not found; is this an Omarchy machine? Skipping the binding."
elif all_present; then
    skip "SUPER+K override (already present)"
elif grep -qE '^[[:space:]]*o\.bind\("SUPER \+ K"' "$bindings"; then
    warn "SUPER+K is already rebound to something else in $bindings; not adding ours."
elif $DRY_RUN; then
    info "  would append the SUPER+K override to $bindings"
else
    backup_file "$bindings"
    grep -qF -- "$BIND_COMMENT" "$bindings" || printf '\n%s\n' "$BIND_COMMENT" >> "$bindings"
    for line in "${BIND_LINES[@]}"; do
        grep -qF -- "$line" "$bindings" || printf '%s\n' "$line" >> "$bindings"
    done
    ok "  SUPER+K -> mez-menu-keybindings"
fi

# ---- 3. apply ------------------------------------------------------------------
info "\n== Apply =="
reload_hyprland

cat <<'NOTES'

Notes:
  - SUPER+K now lists every o.bind() in ~/.config/hypr/bindings.lua first,
    bottom of the file on top, then Omarchy's stock list in its usual order.
  - Preview from a shell:  mez-menu-keybindings --print | head
  - The stock menu is still:  omarchy menu keybindings
  - Undo everything with:  ./omarchy_install_keybindings_menu.sh --remove
NOTES
