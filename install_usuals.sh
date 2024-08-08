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

# #update first
MezPrint "Updating apt"
sudo apt update -y
sudo apt upgrade -y


# Checkout https://github.com/joouha/euporie       Jupyter
# Checkout https://github.com/tconbeer/harlequin   SQL IDE

MezPrint "Installing The Usual Suspects..."
# Dependencies & Common Apps
declare -a Reqs=("wget" "zsh" "curl" "git" "unzip" "fontconfig" "nano" "screenfetch" "gawk" "htop" "rmlint" "ncdu" "gdu" "btop" "bat" "lazydocker" "ranger" "fzf")
arraylength=${#Reqs[@]}
declare -a failedInstalls  # Array to keep track of failed installations



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

# Loop through each requirement
for req in "${Reqs[@]}"; do
    MezPrint "Installing $req..."
    user_type=$(check_superuser)
    
    # Check user type and install requirement accordingly
    case $user_type in
        "root")
            apt install "$req" -yy || failedInstalls+=("$req")
            ;;
        "superuser")
            sudo apt install "$req" -yy || failedInstalls+=("$req")
            ;;
        "normal_user")
            echo "sudo password required for installation of $req"
            sudo apt install "$req" -yy || failedInstalls+=("$req")
            ;;
    esac
done


# Harlequin
MezPrint "Installing Harlequin"
case $user_type in
        "root")
            apt install -y pipx || failedInstalls+=("$req")
            ;;
        "superuser")
            sudo apt install -y pipx || failedInstalls+=("$req")
            ;;
        "normal_user")
            echo "sudo password required for installation of $req"
            sudo apt install -y pipx || failedInstalls+=("$req")
            ;;
esac
pipx install harlequin
pipx ensurepath



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
git clone --depth=1 https://github.com/PaulMez/.dotmez.git ~/.dotmez

#Nerd Fonts
MezPrint "Installing Nerd Fonts (FiraCode)"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip
unzip FiraCode.zip -d ~/.fonts
rm FiraCode.zip
fc-cache -fv


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
