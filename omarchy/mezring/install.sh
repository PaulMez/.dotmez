#!/usr/bin/env bash
# mezring installer: udev rules + uinput, the mezringd user service, the default
# config and the Omarchy bar plugin. Re-run any time to update. Idempotent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG_DIR="$HOME/.config/mezring"
UNIT_DIR="$HOME/.config/systemd/user"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/mez.rings"
SKIP_SUDO=0
SKIP_PLUGIN=0

for a in "$@"; do
  case "$a" in
    --no-sudo) SKIP_SUDO=1 ;;
    --no-plugin) SKIP_PLUGIN=1 ;;
    -h|--help)
      echo "usage: install.sh [--no-sudo] [--no-plugin]"
      echo "  --no-sudo    skip the udev/uinput system step (needs a password)"
      echo "  --no-plugin  skip the Omarchy bar plugin"
      exit 0 ;;
  esac
done

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '    \033[1;32m✓\033[0m %s\n' "$*"; }
warn(){ printf '    \033[1;33m!\033[0m %s\n' "$*"; }

# ------------------------------------------------------------------ checks
say "Checking dependencies"
python3 - <<'EOF' || { echo "python >= 3.11 required"; exit 1; }
import sys; assert sys.version_info >= (3, 11), sys.version
EOF
ok "python3 $(python3 -c 'import sys;print(".".join(map(str,sys.version_info[:3])))')"
command -v bluetoothctl >/dev/null || { echo "bluez-utils (bluetoothctl) required"; exit 1; }
ok "bluetoothctl"
for t in wtype hyprctl wpctl notify-send; do
  if command -v "$t" >/dev/null; then ok "$t"; else warn "$t not found (actions using it will do nothing)"; fi
done

# ------------------------------------------------------------------ system
if [[ $SKIP_SUDO -eq 0 ]]; then
  say "System step (sudo): udev rules for the rings + uinput"
  sudo install -m 644 "$REPO/71-mezring.rules" /etc/udev/rules.d/71-mezring.rules
  sudo install -m 644 "$REPO/uinput.conf" /etc/modules-load.d/mezring.conf
  sudo rm -f /etc/udev/rules.d/70-mezring.rules
  sudo modprobe uinput
  sudo udevadm control --reload
  sudo udevadm trigger
  ok "/etc/udev/rules.d/71-mezring.rules, /etc/modules-load.d/mezring.conf"
else
  warn "skipped system step; without it the daemon cannot read the rings or create virtual input"
fi

# ------------------------------------------------------------------ config
say "Config"
mkdir -p "$CFG_DIR"
if [[ ! -f "$CFG_DIR/mezring.toml" ]]; then
  cp "$REPO/mezring.toml" "$CFG_DIR/mezring.toml"
  ok "created $CFG_DIR/mezring.toml from defaults"
else
  ok "kept existing $CFG_DIR/mezring.toml"
fi
cp "$REPO/mezring.toml" "$CFG_DIR/mezring.example.toml"

# ------------------------------------------------------------------ service
say "User service"
mkdir -p "$UNIT_DIR"
sed "s#%h/gitrpo/.dotmez/omarchy/mezring#$REPO#" "$REPO/mezringd.service" > "$UNIT_DIR/mezringd.service"
systemctl --user daemon-reload
systemctl --user enable mezringd.service >/dev/null
systemctl --user restart mezringd.service
sleep 1
if systemctl --user is-active --quiet mezringd.service; then
  ok "mezringd running  (logs: journalctl --user -u mezringd -f)"
else
  warn "mezringd failed to start; see: journalctl --user -u mezringd -e"
fi

# ------------------------------------------------------------------ plugin
if [[ $SKIP_PLUGIN -eq 0 ]]; then
  if command -v omarchy-shell >/dev/null && command -v omarchy >/dev/null; then
    say "Omarchy bar plugin"
    mkdir -p "$PLUGIN_DIR"
    cp "$REPO/plugin/manifest.json" "$REPO/plugin/Panel.qml" "$PLUGIN_DIR/"
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    sleep 0.5
    if omarchy plugin list --json 2>/dev/null | grep -q '"mez.rings"'; then
      omarchy plugin enable mez.rings >/dev/null 2>&1 || true
      # A freshly added or changed bar widget only mounts reliably after a shell restart.
      omarchy restart shell >/dev/null 2>&1 || true
      ok "mez.rings installed and enabled (right section of the bar; shell restarted)"
    else
      warn "shell has not picked the plugin up yet; try: omarchy-shell shell rescanPlugins && omarchy plugin enable mez.rings"
    fi
  else
    warn "omarchy-shell not found; skipping bar plugin"
  fi
fi

say "Done"
echo "  left-click the ◎ in the bar for status, live events and mappings; right-click cycles modes"
echo "  config: $CFG_DIR/mezring.toml   (daemon reloads on save from the panel; or: systemctl --user kill -s HUP mezringd)"
