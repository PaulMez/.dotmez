#!/bin/bash
#bash -c "$(curl -H 'Cache-Control: no-cache' -fsSL https://raw.githubusercontent.com/PaulMez/.dotmez/main/install_usuals.sh)"


#FuncColors
MezBack='\e[46;30m'
MezBackW='\e[37;30m'
MezBackCy='\e[36;40m'
MezCyan='\e[36m'
reset='\e[0m'

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
MezPrintCen "[--------------------------------------------]"
MezPrintCen "[Installing Mez Configs]"
MezPrintCen "[--------------------------------------------]"
MezPrint "Installing Requirements..." 


MezPrint "Installing The Usual Suspects..." 

for i in $(seq 1 4); do
   echo -ne "\rProgress 1: $i/4"
   sleep 1
done
echo # Move to the next line
for x in $(seq 1 4); do
   echo -ne "\rProgress 2: $x/4"
   sleep 1
done


echo "Choose an option:"
select option in "Option 1" "Option 2" "Exit"; do
   case $option in
      "Option 1")
         echo "You chose Option 1"
         ;;
      "Option 2")
         echo "You chose Option 2"
         ;;
      "Exit")
         break
         ;;
      *)
         echo "Invalid option"
         ;;
   esac
done

# #update first
# MezPrint "Updating apt"
# sudo apt-get update

# Dependencies & Common Apps
declare -a Reqs=("wget" "zsh" "curl" "git" "unzip" "fontconfig" "screenfetch" "cmatrix" "gawk" "htop" "rmlint" "ncdu" "gdu" "btop" "bat" "ranger" "fzf" "ZELLIJ")
arraylength=${#Reqs[@]}

# for (( i=0; i<${arraylength}; i++ ));
# do
#   echo -e "${MezBack}$i. ${Reqs[$i]}${reset}"
#   eval "sudo apt install ${Reqs[$i]} -yy"
# done

#Nerd Fonts
MezPrint "Installing Nerd Fonts (FiraCode)"
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip
unzip FiraCode.zip -d ~/.fonts
rm FiraCode.zip
fc-cache -fv

# #Powerlevel10k
MezPrint "Installing Powerlevel10k"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
# # echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc May not need due to config copy anyway