#!/bin/bash
#
# Swap the Omarchy wallpaper between a chosen few mezarchy backgrounds, either
# on a timer or per Hyprland workspace. Which images, and the interval, live in
# ~/.config/omarchy/branding/mezarchy-bg.conf (repo copy:
# configs/omarchy/branding/mezarchy-bg.conf, deployed by
# omarchy_install_branding.sh).
#
# Usage:
#   mezarchy_bg.sh next|prev|random      step through ROTATE (stateless: it reads
#                                        the current background symlink)
#   mezarchy_bg.sh set <name|path>       set one directly
#   mezarchy_bg.sh list                  show the configured images, mark the current
#   mezarchy_bg.sh status                what is installed / running
#
#   mezarchy_bg.sh rotate on [MINUTES]   install + start a systemd user timer that
#                                        runs `next` every MINUTES (default: ROTATE_MINUTES)
#   mezarchy_bg.sh rotate off            stop + remove the timer
#
#   mezarchy_bg.sh workspace on          install + start a systemd user service that
#                                        follows Hyprland workspace switches
#   mezarchy_bg.sh workspace off         stop + remove it
#   mezarchy_bg.sh workspace daemon      what the service runs (foreground)
#
# Rotation and per-workspace fight each other, so turning one on turns the
# other off. Both go through omarchy-theme-bg-set, so you get Omarchy's reveal
# transition, and the background switcher / Super+Ctrl+Space keep working
# (the next timer tick or workspace switch simply takes over again).
#
# Omarchy's background plugin paints one image on every monitor, so with two
# screens the per-workspace mode follows whichever monitor you last focused.
#
# Needs: socat, jq (both on a stock Omarchy install).
set -euo pipefail

conf="$HOME/.config/omarchy/branding/mezarchy-bg.conf"
bg_dir="$HOME/.config/omarchy/branding/backgrounds"
current_link="$HOME/.local/state/omarchy/current/background"
unit_dir="$HOME/.config/systemd/user"
rotate_unit="mezarchy-bg-rotate"
ws_unit="mezarchy-bg-workspace"
self="$(realpath "${BASH_SOURCE[0]}")"

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; RESET="\033[0m"
info() { echo -e "$*"; }
warn() { echo -e "${YELLOW}warn:${RESET} $*" >&2; }
fail() { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

# ---- config -----------------------------------------------------------------
declare -a ROTATE=()
declare -A WORKSPACE=()
ROTATE_MINUTES=15
WORKSPACE_DEFAULT=""
if [ -f "$conf" ]; then
    # shellcheck source=configs/omarchy/branding/mezarchy-bg.conf
    source "$conf"
else
    warn "no config at $conf; run omarchy_install_branding.sh (using every image in $bg_dir)"
    shopt -s nullglob
    for f in "$bg_dir"/*.png; do ROTATE+=("$(basename "$f" .png)"); done
    shopt -u nullglob
fi

# name or path -> absolute path (empty + warning if it does not exist)
resolve() {
    local v="$1" p
    case "$v" in
        "") return ;;
        "~"/*) p="$HOME/${v#\~/}" ;;
        */*) p="$v" ;;
        *.png|*.jpg|*.jpeg|*.webp) p="$bg_dir/$v" ;;
        *) p="$bg_dir/$v.png" ;;
    esac
    if [ -f "$p" ]; then realpath "$p"; else warn "no such background: $v ($p)"; fi
}

current() { [ -L "$current_link" ] && readlink -f "$current_link" || true; }

next_tick() {  # "Sun 2026-09-20 13:11:23 AEST 14min left"
    systemctl --user list-timers "$rotate_unit.timer" --no-pager --no-legend 2>/dev/null \
        | awk '{print $1, $2, $3, $4, "("$5" left)"}'
}

apply() {  # apply <abs-path>: set it unless it is already showing
    local p="$1"
    [ -n "$p" ] || return 0
    [ "$(current)" = "$p" ] && return 0
    omarchy-theme-bg-set "$p" >/dev/null 2>&1 || ln -nsf "$p" "$current_link"
}

rotate_paths() {  # resolved ROTATE list, one per line, missing files dropped
    local n p
    for n in "${ROTATE[@]}"; do p="$(resolve "$n")"; [ -n "$p" ] && echo "$p"; done
}

# ---- one-shot commands ------------------------------------------------------
cmd_step() {  # next|prev|random
    mapfile -t paths < <(rotate_paths)
    [ "${#paths[@]}" -gt 0 ] || fail "ROTATE is empty (check $conf)"
    local cur i idx=-1 n="${#paths[@]}"
    cur="$(current)"
    for i in "${!paths[@]}"; do [ "${paths[$i]}" = "$cur" ] && idx=$i; done
    case "$1" in
        next)   idx=$(( (idx + 1) % n )) ;;
        prev)   idx=$(( (idx - 1 + n) % n )) ;;
        random)
            if [ "$n" -gt 1 ]; then
                local pick=$idx
                while [ "$pick" -eq "$idx" ]; do pick=$(( RANDOM % n )); done
                idx=$pick
            else idx=0; fi ;;
    esac
    apply "${paths[$idx]}"
    info "background -> $(basename "${paths[$idx]}")"
}

cmd_set() {
    local p; p="$(resolve "${1:-}")"
    [ -n "$p" ] || fail "usage: mezarchy_bg.sh set <name|path>"
    apply "$p"
    info "background -> $(basename "$p")"
}

cmd_list() {
    local cur n p mark
    cur="$(current)"
    info "${GREEN}rotate${RESET} (every ${ROTATE_MINUTES}m):"
    for n in "${ROTATE[@]}"; do
        p="$(resolve "$n" 2>/dev/null)"; mark="  "
        [ -z "$p" ] && mark="${RED}? ${RESET}"
        [ -n "$p" ] && [ "$p" = "$cur" ] && mark="${GREEN}* ${RESET}"
        info "  $mark$n"
    done
    info "${GREEN}workspace${RESET} (default: ${WORKSPACE_DEFAULT:-<keep current>}):"
    for k in $(printf '%s\n' "${!WORKSPACE[@]}" | sort -n); do
        info "    $k -> ${WORKSPACE[$k]}"
    done
    info "current: ${cur:-<none>}"
}

# ---- systemd user units -----------------------------------------------------
write_units_rotate() {
    local minutes="$1"
    mkdir -p "$unit_dir"
    cat > "$unit_dir/$rotate_unit.service" <<EOF
[Unit]
Description=mezarchy wallpaper rotation (one step)

[Service]
Type=oneshot
ExecStart=$self next
EOF
    cat > "$unit_dir/$rotate_unit.timer" <<EOF
[Unit]
Description=mezarchy wallpaper rotation every ${minutes} minutes

[Timer]
OnActiveSec=${minutes}min
OnUnitActiveSec=${minutes}min
AccuracySec=30s

[Install]
WantedBy=timers.target
EOF
}

write_units_workspace() {
    mkdir -p "$unit_dir"
    cat > "$unit_dir/$ws_unit.service" <<EOF
[Unit]
Description=mezarchy per-workspace wallpaper
PartOf=graphical-session.target
After=graphical-session.target

[Service]
ExecStart=$self workspace daemon
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical-session.target
EOF
}

unit_off() {  # unit_off <name> <suffixes...>
    local name="$1"; shift
    local s
    for s in "$@"; do
        systemctl --user disable --now "$name.$s" >/dev/null 2>&1 || true
        rm -f "$unit_dir/$name.$s"
    done
    systemctl --user daemon-reload
}

cmd_rotate() {
    case "${1:-}" in
        on)
            local minutes="${2:-$ROTATE_MINUTES}"
            [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -gt 0 ] || fail "minutes must be a positive integer"
            if systemctl --user is-active --quiet "$ws_unit.service"; then
                info "turning per-workspace mode off (the two would fight)"
                unit_off "$ws_unit" service
            fi
            write_units_rotate "$minutes"
            systemctl --user daemon-reload
            systemctl --user enable --now "$rotate_unit.timer" >/dev/null
            info "${GREEN}rotation on${RESET}: every ${minutes}m through ${#ROTATE[@]} image(s)"
            info "next tick: $(next_tick)" ;;
        off)
            unit_off "$rotate_unit" timer service
            info "rotation off" ;;
        *) fail "usage: mezarchy_bg.sh rotate on [MINUTES] | off" ;;
    esac
}

# ---- per-workspace daemon ---------------------------------------------------
apply_ws() {
    local ws="$1" img
    img="${WORKSPACE[$ws]:-$WORKSPACE_DEFAULT}"
    [ -n "$img" ] || return 0
    apply "$(resolve "$img")"
}

ws_daemon() {
    command -v socat >/dev/null || fail "socat is required (omarchy pkg add socat)"
    command -v jq >/dev/null || fail "jq is required"
    local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}" runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" sock i
    if [ -z "$sig" ]; then  # not inherited: pick the newest running instance
        sig="$(ls -t "$runtime/hypr" 2>/dev/null | head -1 || true)"
    fi
    sock="$runtime/hypr/$sig/.socket2.sock"
    for i in $(seq 1 30); do [ -S "$sock" ] && break; sleep 1; done
    [ -S "$sock" ] || fail "Hyprland event socket not found: $sock"

    apply_ws "$(hyprctl activeworkspace -j | jq -r .id)"
    # workspacev2 fires on switches on the focused monitor; focusedmonv2 when
    # focus jumps to another monitor (which has its own active workspace).
    socat -u "UNIX-CONNECT:$sock" - | while IFS= read -r line; do
        case "$line" in
            "workspacev2>>"*)  ws="${line#workspacev2>>}"; apply_ws "${ws%%,*}" ;;
            "focusedmonv2>>"*) apply_ws "${line##*,}" ;;
        esac
    done
}

cmd_workspace() {
    case "${1:-}" in
        on)
            if systemctl --user is-active --quiet "$rotate_unit.timer"; then
                info "turning rotation off (the two would fight)"
                unit_off "$rotate_unit" timer service
            fi
            write_units_workspace
            systemctl --user daemon-reload
            systemctl --user enable --now "$ws_unit.service" >/dev/null
            info "${GREEN}per-workspace on${RESET}: ${#WORKSPACE[@]} workspace(s) mapped, default ${WORKSPACE_DEFAULT:-<keep current>}" ;;
        off)
            unit_off "$ws_unit" service
            info "per-workspace off" ;;
        daemon) ws_daemon ;;
        *) fail "usage: mezarchy_bg.sh workspace on | off | daemon" ;;
    esac
}

cmd_status() {
    local u
    for u in "$rotate_unit.timer" "$ws_unit.service"; do
        if [ -f "$unit_dir/$u" ]; then
            info "$u: $(systemctl --user is-enabled "$u" 2>/dev/null || true) / $(systemctl --user is-active "$u" 2>/dev/null || true)"
        else
            info "$u: not installed"
        fi
    done
    if [ -f "$unit_dir/$rotate_unit.timer" ]; then
        info "next rotation tick: $(next_tick)"
    fi
    info "current: $(current)"
}

# ---- dispatch ---------------------------------------------------------------
case "${1:-}" in
    next|prev|random) cmd_step "$1" ;;
    set)              cmd_set "${2:-}" ;;
    list)             cmd_list ;;
    status)           cmd_status ;;
    rotate)           cmd_rotate "${2:-}" "${3:-}" ;;
    workspace)        cmd_workspace "${2:-}" ;;
    -h|--help|"")     sed -n '3,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//' ;;
    *)                fail "unknown command: $1 (try --help)" ;;
esac
