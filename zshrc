source /usr/share/zsh/themes/powerlevel10k/powerlevel10k.zsh-theme
source /usr/share/zsh/site-contrib/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
source /usr/share/zsh/site-contrib/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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
export HISTSIZE=2000
export HISTFILE="$HOME/.history"
export SAVEHIST=$HISTSIZE
setopt hist_ignore_all_dups

alias @world='sudo emerge --sync; sudo emerge -uNDa @world; sudo emerge --depclean'

ufetch
