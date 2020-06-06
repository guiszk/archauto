autoload -U colors && colors

PS1="%(?..%B%{$fg[red]%}[%?] %{$reset_color%})%{$fg[green]%}%n%{$reset_color%}@%{$fg[white]%}%m %{$fg[cyan]%}%~ %{$reset_color%}%% "
#PS1="%{$fg[green]%}%n%{$reset_color%}@%{$fg[white]%}%m %{$fg[blue]%}%~ %{$reset_color%}%% "
alias ls='ls -G'
alias ll='ls -lh'
alias la='ls -lah'
alias l1='ls -1'
alias sml='cd ~/git/SMLoadr; node SMLoadr -q FLAC -u; cd -'

autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
RPROMPT=\$vcs_info_msg_0_
zstyle ':vcs_info:git:*' formats '%F{red}[%b]%f'
zstyle ':vcs_info:*' enable git

gt () {
    if git rev-parse --is-inside-work-tree 2&>1; then
        git add *
        git commit -m $1 
        git push origin master
    else
        echo "Not a git repo."
    fi
}
