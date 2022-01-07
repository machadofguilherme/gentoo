source /usr/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/site-functions/zsh-syntax-highlighting.zsh
source /usr/share/zsh/site-functions/zsh-autosuggestions.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export PATH="/usr/lib/ccache/bin${PATH:+:}${PATH}"
export CCACHE_DIR="/var/cache/ccache"

# Completion
autoload -U compinit
compinit

# Correction
setopt correctall

# History
export HISTSIZE=3000
export HISTFILE="$HOME/.history"
export SAVEHIST=$HISTSIZE
setopt hist_ignore_all_dups

alias esync='sudo emerge --sync; reset'
alias @world='sudo emerge -uNDa @world; sudo emerge -cq'

ufetch
