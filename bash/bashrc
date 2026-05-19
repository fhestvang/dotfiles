# ~/.bashrc

case $- in
  *i*) ;;
  *) return ;;
esac

HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize

if [ -x /usr/bin/lesspipe ]; then
  eval "$(SHELL=/bin/sh lesspipe)"
fi

if [ -x /usr/bin/dircolors ]; then
  test -r "$HOME/.dircolors" && eval "$(dircolors -b "$HOME/.dircolors")" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -r "$HOME/github/dotfiles/shell/common.sh" ]; then
  . "$HOME/github/dotfiles/shell/common.sh"
fi

if [ -r "$HOME/.bash_aliases" ]; then
  . "$HOME/.bash_aliases"
fi

__fos_refresh_tmux_display_env() {
  [ -n "${TMUX:-}" ] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  eval "$(
    for name in DISPLAY WAYLAND_DISPLAY XAUTHORITY; do
      tmux show-environment -s "$name" 2>/dev/null | sed '/^-/d'
    done
  )"
}

case ";${PROMPT_COMMAND:-};" in
  *";__fos_refresh_tmux_display_env;"*) ;;
  *) PROMPT_COMMAND="__fos_refresh_tmux_display_env${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac

if ! command -v starship >/dev/null 2>&1; then
  DOTFILES_PROMPT_HOST="$("$HOME/github/dotfiles/bin/prompt-host" 2>/dev/null || hostname -s)"
  PS1='\[\033[0;36m\]${DOTFILES_PROMPT_HOST}\[\033[0m\] \[\033[0;32m\]\w\[\033[0m\] \$ '
fi
