#!/bin/bash
#bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/PaulMez/.dotmez/main/omarchy_install_usuals.sh)"
#
# Arch / Omarchy flavour of install_usuals.sh.
#
# The generic install_usuals.sh has to cope with apt/dnf/yum/pacman/zypper, so it
# side-loads binaries (eza, zellij) and fonts from GitHub releases and pulls
# helix from an Ubuntu PPA. On Arch everything except Fresh, Herdr and Harlequin
# is a first-class package, so this variant installs from the repos + AUR and
# skips all the tarball juggling. Keep this in sync with install_usuals.sh when
# the "usual suspects" list changes.
#
# Flags:
#   --no-update   skip the full `pacman -Syu` system upgrade
#   --no-aur      skip AUR packages (rmlint) even if an AUR helper is present
#   --no-shell    don't touch oh-my-zsh / powerlevel10k / the login shell

set -uo pipefail

#FuncColors
MezBack='\e[46;30m'
MezBackW='\e[37;30m'
MezBackCy='\e[36;40m'
MezCyan='\e[36m'
reset='\e[0m'

# Define ANSI color codes for the rainbow
RED="\033[0;31m"
CYAN="\033[0;36m"
ORANGE="\033[0;33m"
YELLOW="\033[0;93m" # Light yellow
GREEN="\033[0;32m"
BLUE="\033[0;34m"
INDIGO="\033[0;35m" # Magenta can substitute for indigo
VIOLET="\033[0;95m" # Light magenta
RESET="\033[0m"

MezPrint () {
    echo -e "${MezCyan}\n$1${reset}\n"
}

MezPrintCen () {
    echo -e "${MezCyan}"
    echo $1 | sed -e :a -e "s/^.\{1,$(tput cols)\}$/ & /;ta" | tr -d '\n' | head -c $(tput cols)
    echo -e "${reset}\n"
}

MezBanner () {
    echo -e "${BLUE}        _                                    ${RESET}"
    echo -e "${BLUE}       | |          _                        ${RESET}"
    echo -e "${BLUE}     __| |  ___   _| |_  ____   _____  _____ ${RESET}"
    echo -e "${BLUE}    / _  | / _ \ (_   _)|    \ | ___ |(___  )${RESET}"
    echo -e "${VIOLET} _ ( (_| || |_| |  | |_ | | | || ____| / __/ ${RESET}"
    echo -e "${INDIGO}(_) \____| \___/    \__)|_|_|_||_____)(_____)${RESET}"
    echo -e "${VIOLET}                                             ${RESET}"
    echo -e "${VIOLET}                                             ${RESET}"
    echo -e "${CYAN}_____________________________________________${RESET}"
}

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
DO_UPDATE=true
DO_AUR=true
DO_SHELL=true

for arg in "$@"; do
    case "$arg" in
        --no-update) DO_UPDATE=false ;;
        --no-aur)    DO_AUR=false ;;
        --no-shell)  DO_SHELL=false ;;
        -h|--help)
            sed -n '3,17p' "$0"
            exit 0
            ;;
        *)
            echo "unknown option: $arg" >&2
            exit 1
            ;;
    esac
done

clear
MezPrint "Installing......                            "
MezBanner

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
if ! command -v pacman &> /dev/null; then
    echo "error: pacman not found. This script is for Arch / Omarchy." >&2
    echo "       Use ./install_usuals.sh on Debian/Ubuntu/Fedora/openSUSE." >&2
    exit 1
fi

# Root can call pacman directly; anyone else needs sudo. Priming the sudo
# timestamp up front means the long unattended stretch below doesn't stall on a
# password prompt halfway through.
if [ "$EUID" -eq 0 ]; then
    SUDO=""
    IS_ROOT=true
else
    IS_ROOT=false
    if ! command -v sudo &> /dev/null; then
        echo "error: not root and sudo is not installed." >&2
        exit 1
    fi
    SUDO="sudo"
    MezPrint "Priming sudo..."
    sudo -v || { echo "error: sudo authentication failed." >&2; exit 1; }
fi

declare -a failedInstalls=()  # Array to keep track of failed installations

# Where this checkout actually lives. install_usuals.sh assumes ~/.dotmez, but a
# working copy may sit anywhere (e.g. ~/gitrpo/.dotmez), and the per-app install
# scripts already resolve their own paths this way.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Package helpers
# ---------------------------------------------------------------------------

# AUR helper, if any. yay is what Omarchy ships with; paru is the usual
# alternative. Only used for packages that genuinely aren't in the repos.
AUR_HELPER=""
if [ "$DO_AUR" = true ]; then
    for h in yay paru; do
        if command -v "$h" &> /dev/null; then
            AUR_HELPER="$h"
            break
        fi
    done
fi

# Install repo packages. --needed skips anything already at the current version,
# so re-running this script is cheap and non-destructive. Installed one at a
# time so a single bad package name doesn't abort the whole batch.
pac_install() {
    local pkg
    for pkg in "$@"; do
        if pacman -Qq "$pkg" &> /dev/null; then
            echo "  already installed: $pkg"
            continue
        fi
        MezPrint "Installing $pkg..."
        if ! $SUDO pacman -S --needed --noconfirm "$pkg"; then
            failedInstalls+=("$pkg")
        fi
    done
}

# Install AUR packages. Never run an AUR helper as root — makepkg refuses.
aur_install() {
    local pkg
    for pkg in "$@"; do
        if pacman -Qq "$pkg" &> /dev/null; then
            echo "  already installed: $pkg"
            continue
        fi
        if [ -z "$AUR_HELPER" ]; then
            if [ "$DO_AUR" = false ]; then
                echo "skipping AUR package $pkg (--no-aur)"
            else
                echo "no AUR helper (yay/paru) found; skipping $pkg"
                failedInstalls+=("$pkg (needs AUR helper)")
            fi
            continue
        fi
        if [ "$IS_ROOT" = true ]; then
            echo "refusing to build AUR package $pkg as root; skipping"
            failedInstalls+=("$pkg (root cannot build AUR)")
            continue
        fi
        MezPrint "Installing $pkg (AUR via $AUR_HELPER)..."
        if ! "$AUR_HELPER" -S --needed --noconfirm "$pkg"; then
            failedInstalls+=("$pkg (AUR)")
        fi
    done
}

# ---------------------------------------------------------------------------
# System update
# ---------------------------------------------------------------------------
# Arch has no safe partial upgrade: `pacman -Sy` followed by an install can pull
# a package built against libraries you haven't updated yet. So it's a full -Syu
# or nothing.
if [ "$DO_UPDATE" = true ]; then
    MezPrint "Updating the system (pacman -Syu)..."
    $SUDO pacman -Syu --noconfirm || failedInstalls+=("system-upgrade")
else
    MezPrint "Skipping system upgrade (--no-update)"
    echo "note: installing without a preceding -Syu risks a partial upgrade."
fi

# Checkout https://github.com/joouha/euporie       Jupyter
# Checkout https://github.com/tconbeer/harlequin   SQL IDE

# ---------------------------------------------------------------------------
# The usual suspects
# ---------------------------------------------------------------------------
MezPrint "Installing The Usual Suspects..."

# Arch names differ from Debian's in a few places:
#   links2      -> links        (Arch ships the one binary with both UIs)
#   pipx        -> python-pipx
#   FiraCode.zip from nerd-fonts releases -> ttf-firacode-nerd
# eza, zellij and helix are all real packages here, so no binary downloads and
# no PPA dance.
declare -a Reqs=(
    # Core utilities
    "wget" "curl" "git" "unzip" "gawk" "nano"
    # Shell & terminal
    "zsh" "micro" "screenfetch"
    # System monitoring & disk usage
    "htop" "btop" "ncdu" "gdu"
    # File management & navigation
    "ranger" "fzf" "eza" "bat"
    # Other tools
    "fontconfig" "links" "lazydocker"
    # Packaged on Arch, side-loaded on Debian by install_usuals.sh
    "helix" "zellij" "python-pipx" "ttf-firacode-nerd"
)

pac_install "${Reqs[@]}"

# rmlint is AUR-only.
aur_install "rmlint"

# Nerd Fonts came from ttf-firacode-nerd above; refresh the cache so the new
# family is visible to terminals started from this session onwards.
MezPrint "Refreshing font cache"
fc-cache -f > /dev/null 2>&1 || failedInstalls+=("fc-cache")
echo "FiraCode Nerd Font installed. On Omarchy: omarchy-font-set \"FiraCode Nerd Font\""

# ---------------------------------------------------------------------------
# Harlequin (pipx)
# ---------------------------------------------------------------------------
MezPrint "Installing Harlequin"
if command -v pipx &> /dev/null; then
    pipx install harlequin || failedInstalls+=("harlequin")
    pipx ensurepath
else
    echo "pipx not on PATH (python-pipx install failed?); skipping Harlequin"
    failedInstalls+=("harlequin")
fi

# ---------------------------------------------------------------------------
# Fresh — terminal text editor / IDE (https://getfresh.dev/)
# ---------------------------------------------------------------------------
# Upstream only publishes a piped install script and a .deb; there is no AUR
# package worth trusting, so this stays a curl | sh.
MezPrint "Installing Fresh (terminal IDE)"
if curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh | sh; then
    if ! command -v fresh &> /dev/null; then
        # The installer may only put fresh on PATH for new shells.
        echo "fresh installed but not yet on PATH in this shell"
    fi
else
    echo "Failed to install Fresh."
    failedInstalls+=("fresh")
fi

# ---------------------------------------------------------------------------
# Herdr — agent/session manager (https://herdr.dev/docs/install/)
# ---------------------------------------------------------------------------
# Installs into versioned folders and puts the current one on PATH. Use
# 'herdr update' to upgrade and 'herdr channel set preview|stable' to switch
# release channels.
MezPrint "Installing Herdr"
if command -v herdr &> /dev/null; then
    echo "herdr already installed ($(herdr --version 2>/dev/null || echo 'version unknown')); running 'herdr update'"
    herdr update || failedInstalls+=("herdr-update")
elif curl -fsSL https://herdr.dev/install.sh | sh; then
    if ! command -v herdr &> /dev/null; then
        echo "herdr installed but not yet on PATH in this shell"
    fi
else
    echo "Failed to install Herdr."
    failedInstalls+=("herdr")
fi

# ---------------------------------------------------------------------------
# .dotmez
# ---------------------------------------------------------------------------
# If we're running from inside a checkout, use that one rather than cloning a
# second copy into ~/.dotmez and deploying configs from the wrong tree.
if [ -f "$script_dir/copy_configs.sh" ]; then
    DOTMEZ="$script_dir"
    MezPrint "Using existing .dotmez checkout at $DOTMEZ"
elif [ -d "$HOME/.dotmez" ]; then
    DOTMEZ="$HOME/.dotmez"
    MezPrint "Updating .dotmez at $DOTMEZ"
    git -C "$DOTMEZ" pull || failedInstalls+=("dotmez-update")
else
    DOTMEZ="$HOME/.dotmez"
    MezPrint "Installing .dotmez"
    git clone --depth=1 https://github.com/PaulMez/.dotmez.git "$DOTMEZ" || failedInstalls+=("dotmez")
fi

# ---------------------------------------------------------------------------
# zsh: oh-my-zsh, powerlevel10k, plugins
# ---------------------------------------------------------------------------
if [ "$DO_SHELL" = true ]; then
    # Every clone below is guarded: git clone into an existing directory fails,
    # which on a re-run would spam errors and pad failedInstalls with noise.
    MezPrint "Installing Oh-my-zsh"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "~/.oh-my-zsh already exists, skipping"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
            || failedInstalls+=("oh-my-zsh")
    fi

    MezPrint "Installing Powerlevel10k"
    if [ -d "$HOME/powerlevel10k" ]; then
        echo "~/powerlevel10k already exists, updating"
        git -C "$HOME/powerlevel10k" pull || failedInstalls+=("powerlevel10k-update")
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k" \
            || failedInstalls+=("powerlevel10k")
    fi

    MezPrint "Installing Oh-my-zsh plugins"
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    for plugin in \
        "zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git" \
        "zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions"
    do
        set -- $plugin
        if [ -d "$ZSH_CUSTOM/plugins/$1" ]; then
            echo "$1 already installed, skipping"
        else
            git clone --depth=1 "$2" "$ZSH_CUSTOM/plugins/$1" || failedInstalls+=("$1")
        fi
    done
else
    MezPrint "Skipping zsh setup (--no-shell)"
fi

# ---------------------------------------------------------------------------
# Configs
# ---------------------------------------------------------------------------
MezPrint "Backing up configs"
chmod +x "$DOTMEZ/backup_configs.sh"
"$DOTMEZ/backup_configs.sh"

MezPrint "Copying .dotmez configs"
chmod +x "$DOTMEZ/copy_configs.sh"
"$DOTMEZ/copy_configs.sh"

# Zellij config (config.kdl -> ~/.config/zellij). The zellij binary came from the
# repos above, so unlike install_usuals.sh there's no later step that could
# clobber this with `zellij setup --dump-config`.
MezPrint "Installing zellij config"
chmod +x "$DOTMEZ/install_zellij_config.sh"
"$DOTMEZ/install_zellij_config.sh" || failedInstalls+=("zellij-config")

MezPrint "Installing fresh config"
chmod +x "$DOTMEZ/install_fresh_config.sh"
"$DOTMEZ/install_fresh_config.sh" || failedInstalls+=("fresh-config")

MezPrint "Installing herdr config"
chmod +x "$DOTMEZ/install_herdr_config.sh"
"$DOTMEZ/install_herdr_config.sh" || failedInstalls+=("herdr-config")

# ---------------------------------------------------------------------------
# Login shell
# ---------------------------------------------------------------------------
# install_usuals.sh ends with an unconditional `chsh` followed by an interactive
# `zsh`, which strands anything after it. Do the chsh only when it's actually a
# change, and never spawn a shell — the caller can just open a new terminal.
if [ "$DO_SHELL" = true ]; then
    ZSH_PATH="$(command -v zsh || true)"
    if [ -z "$ZSH_PATH" ]; then
        echo "zsh not installed; leaving login shell alone"
    elif [ "$(getent passwd "$USER" | cut -d: -f7)" = "$ZSH_PATH" ]; then
        MezPrint "Login shell is already $ZSH_PATH"
    else
        MezPrint "Setting login shell to $ZSH_PATH"
        chsh -s "$ZSH_PATH" || failedInstalls+=("chsh")
    fi
fi

MezBanner
MezPrint "Installation has been completed"

# Check if there are any failed installations and report them
if [ ${#failedInstalls[@]} -ne 0 ]; then
    echo "Failed to install the following packages:"
    for item in "${failedInstalls[@]}"; do
        echo "$item"
    done
    exit 1
fi

echo "Open a new terminal (or run: exec zsh) to pick up the new shell config."
