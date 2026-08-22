#!/bin/bash
#
# Apply this machine's Omarchy laptop display + text-sizing setup.
#
# Three independent knobs decide how big things look, and it is easy to fight
# one with another:
#
#   1. Hyprland per-monitor `scale`  -- uniform multiplier on ALL UI and text
#   2. GTK text-scaling-factor       -- text only, layout/icons unchanged
#      and QT_FONT_DPI                  (the Qt equivalent; Qt ignores #2)
#   3. Terminal font size            -- per terminal, independent of both
#
# The internal panel (3456x2160, ~302 DPI) and a 1080p external (~81 DPI)
# cannot share a single scale, so monitors.lua sets them per-output. GDK_SCALE
# stays at 1 deliberately: it is global and integer-only, so it cannot express
# a mixed-DPI setup and only ever double-scales GTK3 apps on top of the
# compositor's own scaling.
#
# Terminal configs are PATCHED IN PLACE rather than copied out of this repo.
# All three import Omarchy's live theme state and have their font-family and
# colors rewritten by the theme switcher, so overwriting them wholesale would
# clobber the current theme.
#
# Flags:
#   --dry-run   print what would change, write nothing
#   -h|--help   show this header
#
# Safe to re-run: every step is idempotent and backs up before writing.

set -euo pipefail

# ---- tunables ---------------------------------------------------------------
# Valid internal-panel scales are documented in configs/hypr/monitors.lua.
TEXT_SCALE="1.1"        # GTK text-only multiplier (1.0 = no change)
QT_FONT_DPI="105"       # Qt text sizing; 96 is the default. Set in monitors.lua.
TERM_FONT_SIZE="11"     # ghostty / foot / alacritty
INTERNAL_OUTPUT="eDP-1" # used only for a sanity warning
# -----------------------------------------------------------------------------

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        -h|--help)  sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)          echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stamp="$(date +%Y%m%d%H%M%S)"

info() { printf "%b\n" "$1"; }
ok()   { printf "${GREEN}%s${RESET}\n" "$1"; }
warn() { printf "${YELLOW}warning: %s${RESET}\n" "$1" >&2; }
skip() { printf "skip: %s\n" "$1"; }

# Back up $1 to $1.bak.<stamp> unless it already matches what we are about to
# write. Silent no-op in dry-run.
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

# patch_line <file> <sed-expression> <grep-check-for-desired-state> <label>
# Applies the sed expression only if the desired state is not already present.
patch_line() {
    local file="$1" expr="$2" want="$3" label="$4"

    if [ ! -f "$file" ]; then
        skip "$label ($file not present)"
        return 0
    fi
    if grep -qE "$want" "$file"; then
        skip "$label (already $TERM_FONT_SIZE)"
        return 0
    fi
    if $DRY_RUN; then
        info "  would patch $file: $label"
        return 0
    fi
    backup_file "$file"
    sed -i -E "$expr" "$file"
    ok "  $label -> $TERM_FONT_SIZE"
}

# ---- 1. Hyprland monitors + env ---------------------------------------------
info "\n== Hyprland display config =="

src="$script_dir/configs/hypr/monitors.lua"
dst="$HOME/.config/hypr/monitors.lua"

if [ ! -f "$src" ]; then
    echo "error: $src not found" >&2
    exit 1
fi

# monitors.lua names specific outputs. Warn rather than fail: the file still
# has a catch-all rule, so an unknown machine gets sane defaults.
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    if ! hyprctl monitors -j 2>/dev/null | grep -q "\"$INTERNAL_OUTPUT\""; then
        warn "$INTERNAL_OUTPUT not connected; monitors.lua is written for this laptop."
    fi
fi

if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    skip "monitors.lua (identical)"
elif $DRY_RUN; then
    info "  would install $src -> $dst"
else
    mkdir -p "$(dirname "$dst")"
    backup_file "$dst"
    cp "$src" "$dst"
    ok "  monitors.lua installed (GDK_SCALE=1, QT_FONT_DPI=$QT_FONT_DPI, per-output scales)"
fi

# ---- 2. GTK text scaling -----------------------------------------------------
info "\n== GTK text scaling =="

if ! command -v gsettings >/dev/null 2>&1; then
    skip "text-scaling-factor (gsettings not installed)"
else
    current="$(gsettings get org.gnome.desktop.interface text-scaling-factor 2>/dev/null || echo unknown)"
    # gsettings prints full float precision (1.1000000000000001), so compare
    # numerically rather than as strings.
    if awk -v a="$current" -v b="$TEXT_SCALE" 'BEGIN { exit !(a == b) }' 2>/dev/null; then
        skip "text-scaling-factor (already $TEXT_SCALE)"
    elif $DRY_RUN; then
        info "  would set text-scaling-factor: $current -> $TEXT_SCALE"
    else
        gsettings set org.gnome.desktop.interface text-scaling-factor "$TEXT_SCALE"
        ok "  text-scaling-factor $current -> $TEXT_SCALE"
    fi
fi

# ---- 3. Terminal font sizes --------------------------------------------------
info "\n== Terminal font sizes =="

patch_line "$HOME/.config/ghostty/config" \
    "s/^font-size = .*/font-size = $TERM_FONT_SIZE/" \
    "^font-size = $TERM_FONT_SIZE\$" \
    "ghostty font-size"

patch_line "$HOME/.config/foot/foot.ini" \
    "s/^(font=.*):size=.*/\\1:size=$TERM_FONT_SIZE/" \
    "^font=.*:size=$TERM_FONT_SIZE\$" \
    "foot font size"

# `^size = ` is unique to the [font] table in Omarchy's alacritty.toml; the
# other numeric keys are padding.x / padding.y.
patch_line "$HOME/.config/alacritty/alacritty.toml" \
    "s/^size = .*/size = $TERM_FONT_SIZE/" \
    "^size = $TERM_FONT_SIZE\$" \
    "alacritty font size"

# ---- 4. Apply ----------------------------------------------------------------
info "\n== Apply =="

if $DRY_RUN; then
    info "  dry run: nothing reloaded"
else
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
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

    if command -v omarchy >/dev/null 2>&1; then
        omarchy restart terminal >/dev/null 2>&1 || true
        ok "  terminals signalled to reload"
    fi
fi

cat <<'NOTES'

Notes:
  - hl.env (GDK_SCALE, QT_FONT_DPI) only affects apps launched AFTER the
    reload. Restart anything already running to pick the new values up.
  - foot applies its font size to NEW windows only.
  - text-scaling-factor and QT_FONT_DPI are global, not per-monitor: the text
    bump also lands on the external display, where scale is 1.
  - To resize the laptop panel, edit the `scale` in ~/.config/hypr/monitors.lua
    (valid values are tabulated in that file) or test live first with:
        omarchy hyprland monitor scaling 2.4
NOTES
