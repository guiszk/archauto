autoload -U colors && colors
PS1="%{$fg[green]%}%n%{$reset_color%}@%{$fg[white]%}%m %{$fg[cyan]%}%~ %{$reset_color%}%% "
alias ls='ls -G'
alias ll='ls -l'
alias la='ls -la'
alias sml='cd ~/git/SMLoadr; node SMLoadr -q FLAC -u'

autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst
RPROMPT=\$vcs_info_msg_0_
zstyle ':vcs_info:git:*' formats '%F{red}[%b]%f'
zstyle ':vcs_info:*' enable git
