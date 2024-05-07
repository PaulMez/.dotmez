#!/bin/bash

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

MezPrint "Installing The Usual Suspects..." 

echo -ne "${CYAN}-----                     (33%)\r"
sleep .4
echo -ne "${CYAN}------------              (66%)\r"
sleep .4
echo -ne "${CYAN}----------------------   (100%)\r"
echo -ne '\n'

exit 

# sp='123456789'
# printf ' '
# x=1
# while [ $x -le 9 ]; do
#     printf '\b%.1s' "$sp"
#     sp=${sp#?}${sp%???}
#     let x=x+1
#     sleep 0.1
# done
# echo



# echo "Standard ASCII characters (32-126):"
# for i in {32..126}; do
#     echo "ASCII $i = $(echo -e "\x$(printf %x $i)")"
# done


# echo "Extended ASCII characters (128-255):"
# for i in {128..255}; do
#     # Attempt to display characters as UTF-8, knowing some may not display correctly
#     echo "ASCII $i = $(echo -e "\x$(printf %x $i)")"
# done


# # clock=('🕛 ' '🕐 ' '🕑 ' '🕒 ' '🕓 ' '🕔 ' '🕕 ' '🕖 ' '🕗 ' '🕘 ' '🕙 ' '🕚 ')
# # while true; do
# #     for t in "${clock[@]}"; do
# #         printf "\r$t"
# #         sleep 1
# #     done
# # done



