#!/usr/bin/env bash
# mezring uninstaller. Removes the service, bar plugin and system rules.
# Keeps ~/.config/mezring unless --purge is given.
set -euo pipefail

CFG_DIR="$HOME/.config/mezring"
UNIT_DIR="$HOME/.config/systemd/user"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/mez.rings"
PURGE=0; SKIP_SUDO=0
for a in "$@"; do
  case "$a" in
    --purge) PURGE=1 ;;
    --no-sudo) SKIP_SUDO=1 ;;
    -h|--help) echo "usage: uninstall.sh [--purge] [--no-sudo]"; exit 0 ;;
  esac
done

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
ok()  { printf '    \033[1;32m✓\033[0m %s\n' "$*"; }

say "Stopping service"
systemctl --user disable --now mezringd.service 2>/dev/null || true
rm -f "$UNIT_DIR/mezringd.service"
systemctl --user daemon-reload
ok "mezringd service removed"

say "Removing bar plugin"
if command -v omarchy >/dev/null; then
  omarchy plugin disable mez.rings >/dev/null 2>&1 || true
fi
rm -rf "$PLUGIN_DIR"
command -v omarchy-shell >/dev/null && omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
ok "mez.rings removed"

if [[ $SKIP_SUDO -eq 0 ]]; then
  say "System step (sudo): udev rules + uinput autoload"
  sudo rm -f /etc/udev/rules.d/71-mezring.rules /etc/udev/rules.d/70-mezring.rules /etc/modules-load.d/mezring.conf
  sudo udevadm control --reload
  sudo udevadm trigger
  ok "rules removed (rings go back to being plain keyboards/touchscreens to the kernel)"
fi

if [[ $PURGE -eq 1 ]]; then
  rm -rf "$CFG_DIR"
  ok "removed $CFG_DIR"
else
  echo "    kept $CFG_DIR (use --purge to delete)"
fi
say "Done"
