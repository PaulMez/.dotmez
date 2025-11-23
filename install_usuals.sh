#!/bin/bash
#bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/PaulMez/.dotmez/main/install_usuals.sh)"

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
echo $1 | sed  -e :a -e "s/^.\{1,$(tput cols)\}$/ & /;ta" | tr -d '\n' | head -c $(tput cols)
echo -e "${reset}\n"
}

#intro
clear
# MezPrint "[--------------------------------------------]"
MezPrint "Installing......                            "
# Print each line with different colors to simulate a rainbow
echo -e "${BLUE}        _                                    ${RESET}";
echo -e "${BLUE}       | |          _                        ${RESET}";
echo -e "${BLUE}     __| |  ___   _| |_  ____   _____  _____ ${RESET}";
echo -e "${BLUE}    / _  | / _ \ (_   _)|    \ | ___ |(___  )${RESET}";
echo -e "${VIOLET} _ ( (_| || |_| |  | |_ | | | || ____| / __/ ${RESET}";
echo -e "${INDIGO}(_) \____| \___/    \__)|_|_|_||_____)(_____)${RESET}";
echo -e "${VIOLET}                                             ${RESET}";
echo -e "${VIOLET}                                             ${RESET}";
echo -e "${CYAN}_____________________________________________${RESET}";
# MezPrint "[--------------------------------------------]"
# MezPrint "Installing Requirements..." 


# exit

                              

# MezPrint "Installing The Usual Suspects..." 

# for i in $(seq 1 4); do
#    echo -ne "\rProgress 1: $i/4"
#    sleep 1
# done
# echo # Move to the next line
# for x in $(seq 1 4); do
#    echo -ne "\rProgress 2: $x/4"
#    sleep 1
# done


# echo "Choose an option:"
# select option in "Option 1" "Option 2" "Exit"; do
#    case $option in
#       "Option 1")
#          echo "You chose Option 1"
#          ;;
#       "Option 2")
#          echo "You chose Option 2"
#          ;;
#       "Exit")
#          break
#          ;;
#       *)
#          echo "Invalid option"
#          ;;
#    esac
# done

# Function to check if the user is root or superuser
check_superuser() {
    if [ "$EUID" -eq 0 ]; then
        echo "root"
    else
        sudo -v &>/dev/null
        if [ $? -eq 0 ]; then
            echo "superuser"
        else
            echo "normal_user"
        fi
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Package manager update function
update_packages() {
    local pkg_mgr=$1
    local user_type=$2
    
    MezPrint "Updating package manager ($pkg_mgr)..."
    
    case $pkg_mgr in
        "apt")
            case $user_type in
                "root")
                    apt update -y && apt upgrade -y
                    ;;
                *)
                    sudo apt update -y && sudo apt upgrade -y
                    ;;
            esac
            ;;
        "dnf")
            case $user_type in
                "root")
                    dnf update -y
                    ;;
                *)
                    sudo dnf update -y
                    ;;
            esac
            ;;
        "yum")
            case $user_type in
                "root")
                    yum update -y
                    ;;
                *)
                    sudo yum update -y
                    ;;
            esac
            ;;
        "pacman")
            case $user_type in
                "root")
                    pacman -Syu --noconfirm
                    ;;
                *)
                    sudo pacman -Syu --noconfirm
                    ;;
            esac
            ;;
        "zypper")
            case $user_type in
                "root")
                    zypper refresh && zypper update -y
                    ;;
                *)
                    sudo zypper refresh && sudo zypper update -y
                    ;;
            esac
            ;;
    esac
}

# Package installation function
install_package() {
    local pkg=$1
    local pkg_mgr=$2
    local user_type=$3
    
    case $pkg_mgr in
        "apt")
            case $user_type in
                "root")
                    apt install "$pkg" -y || return 1
                    ;;
                *)
                    sudo apt install "$pkg" -y || return 1
                    ;;
            esac
            ;;
        "dnf")
            case $user_type in
                "root")
                    dnf install "$pkg" -y || return 1
                    ;;
                *)
                    sudo dnf install "$pkg" -y || return 1
                    ;;
            esac
            ;;
        "yum")
            case $user_type in
                "root")
                    yum install "$pkg" -y || return 1
                    ;;
                *)
                    sudo yum install "$pkg" -y || return 1
                    ;;
            esac
            ;;
        "pacman")
            case $user_type in
                "root")
                    pacman -S "$pkg" --noconfirm || return 1
                    ;;
                *)
                    sudo pacman -S "$pkg" --noconfirm || return 1
                    ;;
            esac
            ;;
        "zypper")
            case $user_type in
                "root")
                    zypper install -y "$pkg" || return 1
                    ;;
                *)
                    sudo zypper install -y "$pkg" || return 1
                    ;;
            esac
            ;;
        *)
            echo "Unknown package manager: $pkg_mgr"
            return 1
            ;;
    esac
}

# Detect package manager
PKG_MGR=$(detect_package_manager)
if [ "$PKG_MGR" = "unknown" ]; then
    echo "Error: Could not detect package manager. Supported: apt, dnf, yum, pacman, zypper"
    exit 1
fi

MezPrint "Detected package manager: $PKG_MGR"

# Update packages
user_type=$(check_superuser)
update_packages "$PKG_MGR" "$user_type"

# Checkout https://github.com/joouha/euporie       Jupyter
# Checkout https://github.com/tconbeer/harlequin   SQL IDE

MezPrint "Installing The Usual Suspects..."
# Dependencies & Common Apps
declare -a Reqs=(
    # Core utilities
    "wget" "curl" "git" "unzip" "gawk" "nano"
    # Shell & terminal
    "zsh" "micro" "screenfetch"
    # System monitoring & disk usage
    "htop" "btop" "ncdu" "gdu" "rmlint"
    # File management & navigation
    "ranger" "fzf" "eza" "bat"
    # Other tools
    "fontconfig" "links2" "lazydocker"
)
declare -a failedInstalls  # Array to keep track of failed installations

# Loop through each requirement
for req in "${Reqs[@]}"; do
    MezPrint "Installing $req..."
    if ! install_package "$req" "$PKG_MGR" "$user_type"; then
        failedInstalls+=("$req")
    fi
done

# Check if eza works, install if needed
MezPrint "Checking eza..."
EZA_WORKS=false
if command -v eza &> /dev/null; then
    # Test if eza actually works
    if eza --version &> /dev/null; then
        echo "eza is already installed and working"
        EZA_WORKS=true
    else
        echo "eza found but not working, will reinstall"
    fi
fi

if [ "$EZA_WORKS" = false ]; then
    MezPrint "Installing eza (from Binary)"
    EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/^v//')
    if [ -z "$EZA_VERSION" ]; then
        EZA_VERSION="0.18.0"  # Fallback version
    fi
    
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) EZA_ARCH="x86_64" ;;
        aarch64|arm64) EZA_ARCH="aarch64" ;;
        *) EZA_ARCH="x86_64" ;;  # Default fallback
    esac
    
    OS_TYPE=$(uname -s)
    case "$OS_TYPE" in
        Linux)  EZA_BINARY="eza_${EZA_VERSION}-${EZA_ARCH}-unknown-linux-musl.tar.gz" ;;
        Darwin) EZA_BINARY="eza_${EZA_VERSION}-${EZA_ARCH}-apple-darwin.tar.gz" ;;
        *)      echo "Unsupported OS for eza: $OS_TYPE"
                failedInstalls+=("eza-unsupported-os")
                ;;
    esac
    
    if [ -n "$EZA_BINARY" ]; then
        EZA_URL="https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/${EZA_BINARY}"
        INSTALL_DIR="/usr/local/bin"
        
        echo "Downloading eza v${EZA_VERSION} from: $EZA_URL"
        curl -L "$EZA_URL" -o eza.tar.gz
        
        if [ $? -eq 0 ]; then
            case $user_type in
                "root")
                    tar -xzf eza.tar.gz -C /tmp
                    # Find the eza binary (might be in a subdirectory)
                    EZA_BIN_PATH=$(find /tmp -name "eza" -type f 2>/dev/null | head -n 1)
                    if [ -n "$EZA_BIN_PATH" ]; then
                        mv "$EZA_BIN_PATH" "$INSTALL_DIR/eza" 2>/dev/null || cp "$EZA_BIN_PATH" "$INSTALL_DIR/eza"
                        chmod +x "$INSTALL_DIR/eza"
                    fi
                    ;;
                *)
                    sudo tar -xzf eza.tar.gz -C /tmp
                    # Find the eza binary (might be in a subdirectory)
                    EZA_BIN_PATH=$(find /tmp -name "eza" -type f 2>/dev/null | head -n 1)
                    if [ -n "$EZA_BIN_PATH" ]; then
                        sudo mv "$EZA_BIN_PATH" "$INSTALL_DIR/eza" 2>/dev/null || sudo cp "$EZA_BIN_PATH" "$INSTALL_DIR/eza"
                        sudo chmod +x "$INSTALL_DIR/eza"
                    fi
                    ;;
            esac
            rm -rf /tmp/eza* eza.tar.gz
            
            if command -v eza &> /dev/null; then
                echo "eza installed successfully"
            else
                echo "eza installation failed - binary not in PATH"
                failedInstalls+=("eza")
            fi
        else
            echo "Failed to download eza"
            failedInstalls+=("eza-download")
        fi
    fi
    
    # Verify installation worked
    if command -v eza &> /dev/null && eza --version &> /dev/null; then
        echo "eza installed and verified successfully"
    elif [ "$EZA_WORKS" = false ]; then
        echo "eza installation failed or not working"
        failedInstalls+=("eza")
    fi
fi

# Harlequin
MezPrint "Installing Harlequin"
if ! install_package "pipx" "$PKG_MGR" "$user_type"; then
    failedInstalls+=("pipx")
else
    pipx install harlequin
    pipx ensurepath
fi



# #exa (new way)
# MezPrint "Installing exa"
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
# source $HOME/.cargo/env
# git clone https://github.com/ogham/exa.git
# cd exa
# cargo install --path .
# exa --version
# cd ~

#.dotmez
MezPrint "Installing .dotmez"
if [ -d ~/.dotmez ]; then
    echo "~/.dotmez already exists, updating..."
    cd ~/.dotmez && git pull && cd - || failedInstalls+=("dotmez-update")
else
    git clone --depth=1 https://github.com/PaulMez/.dotmez.git ~/.dotmez || failedInstalls+=("dotmez")
fi

#Nerd Fonts
MezPrint "Installing Nerd Fonts (FiraCode)"
mkdir -p ~/.fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip -O /tmp/FiraCode.zip
if [ $? -eq 0 ]; then
    unzip -q /tmp/FiraCode.zip -d ~/.fonts
    rm -f /tmp/FiraCode.zip
    fc-cache -fv
else
    echo "Failed to download FiraCode font"
    failedInstalls+=("fira-code-font")
fi


# Install Oh-my-zsh
# TBC
MezPrint "Installing Oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# #Powerlevel10k
MezPrint "Installing Powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# # echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc May not need due to config copy anyway / depends on omyzsh

# Oh-my-zsh Plugins
MezPrint "Installing Oh-my-zsh plugins"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Backing up files (only if exist?)
MezPrint "Backing up configs"
chmod +x  ~/.dotmez/backup_configs.sh
~/.dotmez/backup_configs.sh


# Copy .dotmez files
MezPrint "Copying .dotmez configs"
chmod +x ~/.dotmez/copy_configs.sh
~/.dotmez/copy_configs.sh


# Installing Zellij
MezPrint "Installing Zellij (from Binary)"
INSTALL_DIR="/usr/local/bin"
if ! command -v curl &> /dev/null || ! command -v tar &> /dev/null; then
    echo "curl and tar are required to run this script."
    failedInstalls+=("zellij-dependencies")
    exit 1
fi
OS_TYPE=$(uname -s)
case "$OS_TYPE" in
    Linux)  BINARY_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz";;
    Darwin) BINARY_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-apple-darwin.tar.gz";;
    *)      echo "Unsupported OS: $OS_TYPE"
            failedInstalls+=("zellij-unsupported-os")
            exit 1
            ;;
esac
echo "Downloading Zellij for $OS_TYPE..."
curl -L $BINARY_URL -o zellij.tar.gz
if [ $? -eq 0 ]; then
    user_type=$(check_superuser)
    case $user_type in
        "root")
            tar -xzf zellij.tar.gz -C "$INSTALL_DIR"
            ;;
        "superuser"|"normal_user")
            sudo tar -xzf zellij.tar.gz -C "$INSTALL_DIR"
            ;;
    esac
    rm zellij.tar.gz
    case $user_type in
        "root")
            chmod +x "$INSTALL_DIR/zellij"
            ;;
        "superuser"|"normal_user")
            sudo chmod +x "$INSTALL_DIR/zellij"
            ;;
    esac
    if ! command -v zellij &> /dev/null; then
        echo "Zellij installation failed."
        failedInstalls+=("zellij")
    else
        mkdir -p ~/.config/zellij && zellij setup --dump-config > ~/.config/zellij/config.kdl && echo 'default_shell "/usr/bin/zsh"' >> ~/.config/zellij/config.kdl
        # echo "Zellij installed successfully!"
        # zellij --version
    fi
else
    echo "Failed to download Zellij (from Binary)."
    failedInstalls+=("zellij-download")
fi


chsh -s $(which zsh)


zsh

echo -e "${BLUE}        _                                    ${RESET}";
echo -e "${BLUE}       | |          _                        ${RESET}";
echo -e "${BLUE}     __| |  ___   _| |_  ____   _____  _____ ${RESET}";
echo -e "${BLUE}    / _  | / _ \ (_   _)|    \ | ___ |(___  )${RESET}";
echo -e "${VIOLET} _ ( (_| || |_| |  | |_ | | | || ____| / __/ ${RESET}";
echo -e "${INDIGO}(_) \____| \___/    \__)|_|_|_||_____)(_____)${RESET}";
echo -e "${VIOLET}                                             ${RESET}";
echo -e "${VIOLET}                                             ${RESET}";
echo -e "${CYAN}_____________________________________________${RESET}";
# MezPrint "[--------------------------------------------]"
MezPrint "Installation has been completed" 


# Check if there are any failed installations and report them
if [ ${#failedInstalls[@]} -ne 0 ]; then
    echo "Failed to install the following packages:"
    for item in "${failedInstalls[@]}"; do
        echo "$item"
    done
fi
