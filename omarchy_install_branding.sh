#!/bin/bash
#
# Apply the "Mezarchy" branding to an Omarchy install: screensaver text,
# boot splash (Plymouth) + login screen (SDDM) logo, and the idle timers.
#
# What it reproduces (captured from the live machine on 2026-09-14):
#
#   1. ~/.config/omarchy/branding/screensaver.txt   -- MEZARCHY block letters,
#      shown by `omarchy-screensaver` (ttfx) when the screensaver kicks in.
#   2. ~/.config/omarchy/branding/mezarchy-logo.png -- 920x190 logo used for
#      both the Plymouth boot splash and the SDDM login screen.
#   3. ~/.config/omarchy/shell.json  idle.screensaver / idle.lock -- seconds of
#      idle before the screensaver starts and before hyprlock takes over.
#   4. ~/.config/omarchy/branding/backgrounds/*.png -- the mezarchy wallpapers
#      (repo: configs/omarchy/branding/backgrounds/). Omarchy only lists user
#      backgrounds per theme (~/.config/omarchy/backgrounds/<theme>/), so the
#      one real copy lives under branding/ and each theme's folder gets
#      symlinks to it. Every Omarchy picker walks with `find -L`, so links show
#      up in the switcher, bg-next, and thumbnail caching. Default is the
#      current theme only; --all-themes links every installed theme.
#
# The splash/login logo is NOT copied into /usr/share by hand. Omarchy owns
# those files (package omarchy-settings) and ships a tool for exactly this:
#
#   omarchy-plymouth-set '<bg-hex>' '<text-hex>' <logo.png>
#
# It rebuilds /usr/share/plymouth/themes/omarchy and /usr/share/sddm/themes/omarchy
# atomically as root, tinting the bullet/entry/lock glyphs with the text colour
# and painting the background colour into the script + QML. Re-running it later
# with a theme's own colours (Omarchy menu > Style > Unlock) will overwrite the
# logo again -- re-run this script to get it back. `omarchy-plymouth-reset`
# restores stock Omarchy branding.
#
# Flags:
#   --dry-run        print what would change, write nothing
#   --no-plymouth    only do the user-level parts (skip the sudo step)
#   --plymouth       force the Plymouth/SDDM rebuild even if the logo already
#                    matches (use after changing BG_HEX / TEXT_HEX below)
#   --all-themes     link the wallpapers into every installed theme, not just
#                    the current one
#   -h|--help        show this header
#
# Run it from a real terminal: omarchy-plymouth-set needs sudo, and sudo needs
# a TTY. Safe to re-run: every step is idempotent and backs up before writing.

set -euo pipefail

# ---- tunables ---------------------------------------------------------------
# Colours handed to omarchy-plymouth-set. BG is tokyo-night's background (the
# theme in use when this was captured); TEXT is pure white rather than the
# theme foreground so the glyphs read cleanly against the logo.
BG_HEX="#1a1b26"
TEXT_HEX="#ffffff"
IDLE_SCREENSAVER=120    # seconds; Omarchy default is 150
IDLE_LOCK=300           # seconds; Omarchy default is 300
# -----------------------------------------------------------------------------

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

DRY_RUN=false
DO_PLYMOUTH=true
FORCE_PLYMOUTH=false
ALL_THEMES=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)      DRY_RUN=true ;;
        --no-plymouth)  DO_PLYMOUTH=false ;;
        --plymouth)     FORCE_PLYMOUTH=true ;;
        --all-themes)   ALL_THEMES=true ;;
        -h|--help)      sed -n '3,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)              echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="$script_dir/configs/omarchy/branding"
bg_source_dir="$source_dir/backgrounds"
branding_dir="$HOME/.config/omarchy/branding"
bg_store_dir="$branding_dir/backgrounds"          # one real copy lives here
user_bg_root="$HOME/.config/omarchy/backgrounds"   # per-theme dirs Omarchy scans
theme_name_file="$HOME/.local/state/omarchy/current/theme.name"
shell_json="$HOME/.config/omarchy/shell.json"
default_shell_json="/usr/share/omarchy/config/omarchy/shell.json"
stamp="$(date +%Y%m%d%H%M%S)"

info() { printf "%b\n" "$1"; }
ok()   { printf "${GREEN}%s${RESET}\n" "$1"; }
warn() { printf "${YELLOW}warning: %s${RESET}\n" "$1" >&2; }
fail() { printf "${RED}error: %s${RESET}\n" "$1" >&2; exit 1; }
skip() { printf "skip: %s\n" "$1"; }

# Back up $1 to $1.bak.<stamp>. Callers only invoke this when the file exists
# and is about to change, so a backup always means "something differed".
backup_file() {
    local target="$1"
    if $DRY_RUN; then
        info "  would back up $target -> $target.bak.$stamp"
    else
        cp "$target" "$target.bak.$stamp"
        info "  backed up -> $target.bak.$stamp"
    fi
}

for f in screensaver.txt mezarchy-logo.png; do
    [ -f "$source_dir/$f" ] || fail "$source_dir/$f not found"
done
command -v jq >/dev/null || fail "jq is required (pacman -S jq)"

# ---- 1. branding files ------------------------------------------------------
info "${GREEN}Branding files -> $branding_dir${RESET}"
$DRY_RUN || mkdir -p "$branding_dir"
for f in screensaver.txt mezarchy-logo.png; do
    src="$source_dir/$f"
    dst="$branding_dir/$f"
    if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
        skip "$f already matches"
        continue
    fi
    [ -f "$dst" ] && backup_file "$dst"
    if $DRY_RUN; then
        info "  would copy $f"
    else
        cp "$src" "$dst"
        ok "  installed $f"
    fi
done

# ---- 2. idle timers in shell.json -------------------------------------------
info "${GREEN}Idle timers -> $shell_json${RESET}"
if [ ! -f "$shell_json" ]; then
    # Omarchy seeds this on first login; a bare chroot/new user may not have it.
    [ -f "$default_shell_json" ] || fail "$shell_json missing and no default at $default_shell_json"
    if $DRY_RUN; then
        info "  would seed from $default_shell_json"
    else
        mkdir -p "$(dirname "$shell_json")"
        cp "$default_shell_json" "$shell_json"
        info "  seeded from $default_shell_json"
    fi
fi

if [ -f "$shell_json" ]; then
    cur_ss=$(jq -r '.idle.screensaver // empty' "$shell_json")
    cur_lock=$(jq -r '.idle.lock // empty' "$shell_json")
    if [ "$cur_ss" = "$IDLE_SCREENSAVER" ] && [ "$cur_lock" = "$IDLE_LOCK" ]; then
        skip "idle.screensaver=$IDLE_SCREENSAVER idle.lock=$IDLE_LOCK already set"
    else
        info "  idle.screensaver ${cur_ss:-unset} -> $IDLE_SCREENSAVER, idle.lock ${cur_lock:-unset} -> $IDLE_LOCK"
        backup_file "$shell_json"
        if ! $DRY_RUN; then
            tmp="$(mktemp)"
            # Only touch the two idle keys; the bar layout etc. stay as-is so
            # future Omarchy defaults are not pinned by this repo.
            jq --argjson ss "$IDLE_SCREENSAVER" --argjson lock "$IDLE_LOCK" \
               '.idle.screensaver = $ss | .idle.lock = $lock' "$shell_json" > "$tmp"
            mv "$tmp" "$shell_json"
            ok "  updated idle timers"
            # NOT omarchy-refresh-shell: in Omarchy "refresh" means reset the
            # config to package defaults, which would undo the edit just made.
            # reloadConfig is what omarchy-shell-config's own helpers use.
            command -v omarchy-shell >/dev/null && omarchy-shell -q shell reloadConfig >/dev/null 2>&1 || true
        fi
    fi
elif $DRY_RUN; then
    info "  would set idle.screensaver=$IDLE_SCREENSAVER idle.lock=$IDLE_LOCK"
fi

# ---- 3. Plymouth boot splash + SDDM login logo -------------------------------
info "${GREEN}Boot splash + login screen logo${RESET}"
if ! $DO_PLYMOUTH; then
    skip "--no-plymouth given"
elif ! command -v omarchy-plymouth-set >/dev/null; then
    warn "omarchy-plymouth-set not found; is this an Omarchy install? Skipping."
else
    logo="$branding_dir/mezarchy-logo.png"
    $DRY_RUN && logo="$source_dir/mezarchy-logo.png"
    installed_sddm=/usr/share/sddm/themes/omarchy/logo.png
    installed_plym=/usr/share/plymouth/themes/omarchy/logo.png
    if ! $FORCE_PLYMOUTH && cmp -s "$logo" "$installed_sddm" && cmp -s "$logo" "$installed_plym"; then
        skip "logo already installed in SDDM and Plymouth themes (use --plymouth to force a colour refresh)"
    elif $DRY_RUN; then
        info "  would run: omarchy-plymouth-set '$BG_HEX' '$TEXT_HEX' $logo   (sudo)"
    else
        info "  running omarchy-plymouth-set (will prompt for sudo)..."
        omarchy-plymouth-set "$BG_HEX" "$TEXT_HEX" "$logo"
        ok "  Plymouth + SDDM rebuilt with mezarchy logo"
    fi
fi

# ---- 4. wallpapers ----------------------------------------------------------
info "${GREEN}Wallpapers -> $bg_store_dir (+ per-theme links)${RESET}"
shopt -s nullglob
bg_files=("$bg_source_dir"/*.png "$bg_source_dir"/*.jpg "$bg_source_dir"/*.jpeg "$bg_source_dir"/*.webp)
shopt -u nullglob
if [ "${#bg_files[@]}" -eq 0 ]; then
    skip "no images in $bg_source_dir"
else
    $DRY_RUN || mkdir -p "$bg_store_dir"
    for src in "${bg_files[@]}"; do
        f="$(basename "$src")"
        dst="$bg_store_dir/$f"
        if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
            skip "$f already stored"
            continue
        fi
        [ -f "$dst" ] && backup_file "$dst"
        if $DRY_RUN; then
            info "  would copy $f"
        else
            cp "$src" "$dst"
            ok "  stored $f"
        fi
    done

    # Which theme folders to link into. Theme names are the directory slugs
    # (e.g. tokyo-night); omarchy-theme-list prettifies them, so read the dirs.
    themes=()
    if $ALL_THEMES; then
        for d in "$HOME/.config/omarchy/themes"/*/ "${OMARCHY_PATH:-/usr/share/omarchy}/themes"/*/; do
            [ -d "$d" ] && themes+=("$(basename "$d")")
        done
        mapfile -t themes < <(printf '%s\n' "${themes[@]}" | sort -u)
    elif [ -s "$theme_name_file" ]; then
        themes=("$(< "$theme_name_file")")
    else
        warn "no current theme recorded in $theme_name_file; use --all-themes or set a theme first"
    fi

    for theme in "${themes[@]}"; do
        tdir="$user_bg_root/$theme"
        $DRY_RUN || mkdir -p "$tdir"
        linked=0
        for src in "${bg_files[@]}"; do
            f="$(basename "$src")"
            link="$tdir/$f"
            target="$bg_store_dir/$f"
            if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
                continue
            fi
            if [ -e "$link" ] && [ ! -L "$link" ]; then
                # A real file with our name: leave it, the user put it there.
                warn "$link exists as a regular file; not replacing"
                continue
            fi
            if $DRY_RUN; then
                info "  would link $theme/$f"
            else
                ln -nsf "$target" "$link"
            fi
            linked=$((linked + 1))
        done
        if [ "$linked" -eq 0 ]; then
            skip "$theme: all wallpapers already linked"
        else
            ok "  $theme: linked $linked wallpaper(s)"
        fi
    done
    # Thumbnails for the picker are cached lazily; warm them for the current
    # theme so the first open of the background switcher is instant.
    if ! $DRY_RUN && command -v omarchy-theme-bg-cache >/dev/null; then
        omarchy-theme-bg-cache >/dev/null 2>&1 || true
    fi
fi

info ""
ok "Done."
info "Pick a mezarchy wallpaper with the background switcher, or: omarchy-theme-bg-set ~/.config/omarchy/branding/backgrounds/mezarchy-minimal.png"
info "Preview the screensaver with: omarchy-launch-screensaver force"
info "The login logo shows on next logout/reboot; the boot splash on next reboot."
