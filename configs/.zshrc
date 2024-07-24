# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/powerlevel10k/powerlevel10k.zsh-theme

# Need oh-my-zsh first
plugins=(
  zsh-syntax-highlighting 
  zsh-autosuggestions
  z
)
source $HOME/.oh-my-zsh/oh-my-zsh.sh

function gitcap() {
  git add . && git commit -m "$1" && git push
}

function cat() {
    # Check if batcat is installed
    if command -v batcat &> /dev/null; then
        # If installed, use batcat with all provided arguments
        batcat "$@"
    else
        # If not installed, show a message and fall back to default cat
        echo "batcat is not installed. Falling back to default cat command."
        command cat "$@"
    fi
}



## SAME FOR BTOP

# alias ls='ls --color=auto'
alias ls='exa -1la --colour=always --icons  --group-directories-first'
# alias ll='ls -lahG --color=auto'
alias ll='exa -a --colour=always --icons  --group-directories-first'
alias lt='exa -Ta --colour=always --icons  --group-directories-first'

alias tt="cd ~/aws/tinytales/"
alias ttf="cd ~/aws/tinytales/tinytales_frontend/"
alias ttb="cd ~/aws/tinytales/tinytales_backend"
alias askmez="python3 /Users/paulmez/aws/openai/askMez.py "
alias MezTu_ssh="ssh meztu@192.168.1.41"
alias MezTop_ssh="ssh meza@192.168.1.2 && wsl"
alias olrag_env="cd /mnt/c/Users/Meza/ollama_rag && source olrag_env/bin/activate"
alias p3="python3"
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias md='mkdir -p'
alias rd=rmdir
#sudo du -h --max-depth=1 /usr/share/ | sort -hr | head -n 10



# # Add or update LS_COLORS settings directly
# update_ls_colors() {
#     # Define new color settings
#     local new_colors=(
#         "DIR=01;34;40"  # directory
#         "STICKY_OTHER_WRITABLE=01;34;40"  # dir that is sticky and other-writable (+t,o+w)
#         "OTHER_WRITABLE=01;34;40"  # dir that is other-writable (o+w) and not sticky
#         "STICKY=01;34;40"  # dir with the sticky bit set (+t) and not other-writable
#         "*.sh=01;38;5;200;48;5;235"  # custom color for .sh scripts
#         "*.py=01;38;5;165;48;5;235"  # custom color for .py scripts
#     )
#     # Start with existing LS_COLORS or initialize a new one if not present
#     eval "$(dircolors -b)"  # Initializes LS_COLORS with defaults
#     local current_ls_colors="${LS_COLORS:-}"
#     # Update or add new color settings
#     for color_setting in "${new_colors[@]}"; do
#         local key="${color_setting%%=*}"
#         local value="${color_setting#*=}"
#         # Remove existing setting if present
#         current_ls_colors=$(echo "${current_ls_colors}" | sed "s|${key}=[^:]*:||g")
#         # Append the new setting
#         current_ls_colors="${current_ls_colors}${key}=${value}:"
#     done
#     # Ensure the final colon is not duplicated
#     current_ls_colors=${current_ls_colors%:}
#     # Export the updated LS_COLORS
#     export LS_COLORS="${current_ls_colors}"
#     echo $LS_COLORS
#     # echo $dircolors
# }
# # Call the function to update LS_COLORS
# update_ls_colors






#this needs testing - failed
# if ! shopt -oq posix; then
#   if [ -f /usr/share/bash-completion/bash_completion ]; then
#     . /usr/share/bash-completion/bash_completion
#   elif [ -f /etc/bash_completion ]; then
#     . /etc/bash_completion
#   fi
# fi


SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt share_history
setopt extended_history 
setopt inc_append_history
setopt hist_ignore_dups hist_ignore_all_dups

bindkey ";5A" history-search-backward
bindkey ";5B" history-search-forward

# Define the function
set_ohmyzsh_backg_color() {
    local colors=('014' '164' '056' '128')
    echo ${colors[$RANDOM % ${#colors[@]}]}
}
    
# Call the function
# set_ohmyzsh_backg_color




# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
