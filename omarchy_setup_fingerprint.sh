#!/bin/bash
#
# Wire an already-enrolled fingerprint into PAM on Omarchy: sudo, polkit (GUI
# auth dialogs) and the hyprlock lock screen.
#
# This is omarchy-setup-security-fingerprint minus its package step. That step
# runs `omarchy-pkg-add libfprint`, which hard-conflicts with libfprint-tod-git
# (the TOD driver some readers need, e.g. the Goodix 53xc). pacman --noconfirm
# answers N to the conflict prompt and exits 1, and the upstream script is
# `set -e`, so it dies there and never writes any PAM config — leaving you with
# an enrolled print that nothing actually uses. It would also swap out the TOD
# driver that's doing the work.
#
# Assumes the print is already enrolled. If `fprintd-list "$USER"` shows
# nothing, run `fprintd-enroll "$USER"` first.
#
# Flags:
#   --sudo-only   only touch /etc/pam.d/sudo (skip polkit and the lock screen)
#   --undo        remove the fingerprint lines this script added
#
# Run it from a real terminal — sudo needs a TTY to prompt for your password.

set -euo pipefail

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
RESET="\033[0m"

SUDO_ONLY=false
UNDO=false

for arg in "$@"; do
    case "$arg" in
        --sudo-only) SUDO_ONLY=true ;;
        --undo)      UNDO=true ;;
        -h|--help)   sed -n '3,22p' "$0"; exit 0 ;;
        *)           echo "unknown option: $arg" >&2; exit 1 ;;
    esac
done

# The clamshell gate, verbatim from omarchy-setup-security-fingerprint. With the
# lid shut the reader is unreachable, so success=1 skips exactly the pam_fprintd
# line below it and PAM drops straight to the password prompt instead of
# blocking on a sensor you can't reach. pam_exec needs a literal absolute path.
GATE='auth      [success=1 default=ignore] pam_exec.so quiet /usr/bin/omarchy-hw-laptop-closed'
FPRINT='auth      sufficient pam_fprintd.so'

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Run this as your normal user, not root — it needs \$USER to be you.${RESET}" >&2
    exit 1
fi

if [ ! -f /usr/lib/security/pam_fprintd.so ]; then
    echo -e "${RED}pam_fprintd.so not found. Install fprintd first.${RESET}" >&2
    exit 1
fi

# Prime sudo up front so the edits below don't stall mid-way on a prompt. This
# is also what fails loudly if you're running without a TTY.
sudo -v || { echo -e "${RED}sudo authentication failed.${RESET}" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Undo
# ---------------------------------------------------------------------------
if [ "$UNDO" = true ]; then
    echo -e "${GREEN}Removing fingerprint authentication from PAM.${RESET}\n"
    for f in /etc/pam.d/sudo /etc/pam.d/polkit-1; do
        if [ -f "$f" ] && grep -Eq 'pam_fprintd\.so|omarchy-hw-laptop-closed' "$f"; then
            echo "Cleaning $f..."
            sudo cp "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
            sudo sed -i -e '/pam_fprintd\.so/d' -e '/omarchy-hw-laptop-closed/d' "$f"
        fi
    done
    if [ -f /etc/pam.d/omarchy-lock-fingerprint ]; then
        echo "Removing /etc/pam.d/omarchy-lock-fingerprint..."
        sudo rm -f /etc/pam.d/omarchy-lock-fingerprint
    fi
    echo -e "${GREEN}Done. Password auth is unchanged.${RESET}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Warn if nothing is enrolled — PAM would be pointing at an empty set
# ---------------------------------------------------------------------------
if command -v fprintd-list &> /dev/null; then
    if ! fprintd-list "$USER" 2>/dev/null | grep -q '#'; then
        echo -e "${YELLOW}Warning: no enrolled prints for $USER.${RESET}"
        echo "Run 'fprintd-enroll \"\$USER\"' first, or fingerprint auth will just"
        echo "fall through to the password prompt every time."
        echo
    fi
fi

# ---------------------------------------------------------------------------
# PAM stacks
# ---------------------------------------------------------------------------
# Insert pam_fprintd at line 1, then the gate immediately before it, so the
# final order is: gate, fprintd, then the original stack. Both edits are guarded
# so re-running this doesn't stack duplicate lines.
configure_stack() {
    local f="$1"
    sudo cp "$f" "$f.bak.$(date +%Y%m%d%H%M%S)"
    if ! grep -q 'pam_fprintd\.so' "$f"; then
        echo "  adding pam_fprintd to $f"
        sudo sed -i "1i $FPRINT" "$f"
    else
        echo "  pam_fprintd already in $f"
    fi
    if ! grep -q 'omarchy-hw-laptop-closed' "$f"; then
        echo "  adding clamshell gate to $f"
        sudo sed -i "/pam_fprintd\.so/i $GATE" "$f"
    else
        echo "  clamshell gate already in $f"
    fi
}

echo -e "${GREEN}Configuring sudo...${RESET}"
configure_stack /etc/pam.d/sudo

if [ "$SUDO_ONLY" = false ]; then
    echo -e "${GREEN}Configuring polkit (GUI auth dialogs)...${RESET}"
    if [ -f /etc/pam.d/polkit-1 ]; then
        configure_stack /etc/pam.d/polkit-1
    else
        # No polkit-1 stack on this box, so write the whole thing rather than
        # prepending to a file that doesn't exist.
        echo "  creating /etc/pam.d/polkit-1"
        sudo tee /etc/pam.d/polkit-1 >/dev/null <<EOF
$GATE
$FPRINT
auth      required pam_unix.so

account   required pam_unix.so
password  required pam_unix.so
session   required pam_unix.so
EOF
    fi

    echo -e "${GREEN}Configuring the lock screen...${RESET}"
    sudo tee /etc/pam.d/omarchy-lock-fingerprint >/dev/null <<'EOF'
#%PAM-1.0
auth       required                    pam_fprintd.so
account    include                     system-local-login
EOF
    echo "  wrote /etc/pam.d/omarchy-lock-fingerprint"
fi

echo
echo -e "${GREEN}Done.${RESET} Current /etc/pam.d/sudo:"
echo "---"
cat /etc/pam.d/sudo
echo "---"
echo
echo "Test it in a SECOND terminal before closing this one:"
echo "    sudo -k; sudo true"
echo
echo "If sudo is broken, roll back with:"
echo "    $0 --undo"
echo "(or restore the timestamped .bak file this script just made)"
