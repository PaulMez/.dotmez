#!/bin/bash

# Define ANSI color codes for the rainbow
RED="\033[0;31m"
ORANGE="\033[0;33m"
YELLOW="\033[0;93m" # Light yellow
GREEN="\033[0;32m"
BLUE="\033[0;34m"
INDIGO="\033[0;35m" # Magenta can substitute for indigo
VIOLET="\033[0;95m" # Light magenta
RESET="\033[0m"


# Print each line with different colors to simulate a rainbow
echo -e "${RED}        _                                    ${RESET}";
echo -e "${ORANGE}       | |          _                        ${RESET}";
echo -e "${YELLOW}     __| |  ___   _| |_  ____   _____  _____ ${RESET}";
echo -e "${GREEN}    / _  | / _ \ (_   _)|    \ | ___ |(___  )${RESET}";
echo -e "${BLUE} _ ( (_| || |_| |  | |_ | | | || ____| / __/ ${RESET}";
echo -e "${INDIGO}(_) \____| \___/    \__)|_|_|_||_____)(_____)${RESET}";
echo -e "${VIOLET}                                             ${RESET}";