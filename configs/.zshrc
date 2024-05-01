


function gitcap() {
  git add . && git commit -m "$1" && git push
}

cat() {
    # Check if batcat is installed
    if command -v batcat &> /dev/null; then
        # If installed, use batcat with all provided arguments
        batcat "$@"
    else
        # If not installed, show a message and fall back to default cat
        echo "batcat is not installed. Falling back to default cat command."
        command cat "$@"
    }
}

alias ls='ls -lahG --color=auto'
alias ll='ls -ahG --color=auto'
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



#this needs testing
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt share_history
setopt extended_history 
setopt inc_append_history
setopt hist_ignore_dups hist_ignore_all_dups


set_ohmyzsh_backg_color() {
    local colors=('4' 'purple' 'pink' 'yellow')
    echo ${colors[$RANDOM % ${#colors[@]}]}
}



# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh