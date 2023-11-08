if status is-interactive
    # Commands to run in interactive sessions can go here
end

set fish_greeting
set -gx PATH $PATH $HOME/.local/bin
set URL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/bubblesline.omp.json"

oh-my-posh init fish --config $URL | source
alias top "bashtop"
