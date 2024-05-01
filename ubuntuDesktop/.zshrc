# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source ~/powerlevel10k/powerlevel10k.zsh-theme
source ~/powerlevel10k/powerlevel10k.zsh-theme

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias your_alias="your_command"
alias ll="ls -lah"
export OLLAMA_HOST="0.0.0.0"


alias olrag_env="cd /mnt/c/Users/Meza/ollama_rag && source olrag_env/bin/activate"
alias p3="python3"


plugins=(
	zsh-autosuggestions
)

HISTFILE=~/.zsh_history
SAVEHIST=10000
setopt share_history
setopt inc_append_history
setopt hist_ignore_dups hist_ignore_all_dups
