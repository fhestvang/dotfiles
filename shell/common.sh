# Shared interactive shell configuration for Bash and Zsh.

if [ -r "$HOME/github/dotfiles/shell/wslg-env.sh" ]; then
  . "$HOME/github/dotfiles/shell/wslg-env.sh"
fi

DOTFILES_MACHINE="$("$HOME/github/dotfiles/bin/prompt-host" 2>/dev/null || hostname -s 2>/dev/null || printf local)"
export DOTFILES_MACHINE

dotfiles_is_spark() {
  [ "$DOTFILES_MACHINE" = "spark" ]
}

dotfiles_spark_command() {
  local command_prefix="$1"
  shift
  local quoted="" arg

  for arg in "$@"; do
    quoted+=" $(printf '%q' "$arg")"
  done

  if [ -t 0 ] && [ -t 1 ]; then
    ssh -o ClearAllForwardings=yes -t spark "$command_prefix$quoted"
  else
    ssh -o ClearAllForwardings=yes spark "$command_prefix$quoted"
  fi
}

dotfiles_path_prepend() {
  [ -d "$1" ] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

dotfiles_path_prepend "$HOME/.local/bin"
dotfiles_path_prepend "$HOME/bin"
dotfiles_path_prepend "$HOME/.cargo/bin"
dotfiles_path_prepend "$HOME/.local/share/fzf/bin"
export PATH

alias ll='ls -alF'
alias la='ls -A'
alias cc='claude --continue'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias gs='git status'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gba='git branch -a'
alias ga='git add -p'
alias gpl='git pull --ff-only'
alias gps='git push'
alias glog="git log --graph --topo-order --pretty='%C(yellow)%h%Creset %C(cyan)%ar%Creset %C(green)%an%Creset %C(auto)%d%Creset %s' --abbrev-commit"

whereami() {
  printf '%s\n' "$DOTFILES_MACHINE"
}

dotfiles_tmux_client_session() {
  local base="${1:-main}" tty_name session_name

  tty_name="$(tty 2>/dev/null || printf client-$$)"
  tty_name="${tty_name#/dev/}"
  tty_name="$(printf '%s' "$tty_name" | tr -c '[:alnum:]_.-' '-')"
  [ -n "$tty_name" ] || tty_name="client-$$"

  session_name="${base}-${tty_name}"
  tmux has-session -t "$base" 2>/dev/null || tmux new-session -d -s "$base"
  tmux has-session -t "$session_name" 2>/dev/null || tmux new-session -d -t "$base" -s "$session_name"
  printf '%s\n' "$session_name"
}

t() {
  local target_session

  target_session="$(dotfiles_tmux_client_session main)"
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$target_session"
  else
    exec tmux -2 attach-session -t "$target_session"
  fi
}

spark() {
  if dotfiles_is_spark; then
    printf 'already on spark\n'
  else
    ssh -t spark
  fi
}

ts() {
  local remote_command ssh_command

  remote_command='export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; export TERM=xterm-256color; base=main; tty_name="$(tty 2>/dev/null || printf client-$$)"; tty_name="${tty_name#/dev/}"; tty_name="$(printf "%s" "$tty_name" | tr -c "[:alnum:]_.-" "-")"; session_name="$base-$tty_name"; tmux has-session -t "$base" 2>/dev/null || tmux new-session -d -s "$base"; tmux has-session -t "$session_name" 2>/dev/null || tmux new-session -d -t "$base" -s "$session_name"; exec tmux -2 attach-session -t "$session_name"'

  if dotfiles_is_spark; then
    if [ -n "${TMUX:-}" ]; then
      t
    else
      t
    fi
  elif [ -n "${TMUX:-}" ] && command -v tmux >/dev/null 2>&1; then
    ssh_command="ssh -tt -o ClearAllForwardings=yes spark $(printf '%q' "$remote_command")"
    tmux detach-client -E "$ssh_command"
  else
    ssh -tt -o ClearAllForwardings=yes spark "$remote_command"
  fi
}

tsp() {
  local target_session

  if [ -n "${TMUX:-}" ]; then
    tmux choose-tree -Zw
  else
    target_session="$(dotfiles_tmux_client_session main)"
    tmux set-hook -g client-attached 'set-hook -gu client-attached; choose-tree -Zw'
    exec tmux -2 attach-session -t "$target_session"
  fi
}

laptop() {
  if dotfiles_is_spark; then
    if [ -n "${TMUX:-}" ] && [ -n "${SSH_CONNECTION:-}" ]; then
      tmux detach-client -P
    elif [ -n "${TMUX:-}" ]; then
      tmux detach-client
    elif [ -n "${SSH_CONNECTION:-}" ]; then
      exit
    else
      printf 'already on spark, but not inside tmux or ssh\n'
    fi
  else
    printf 'already on laptop/local machine\n'
  fi
}

if command -v eza >/dev/null 2>&1; then
  alias l='eza -l --icons --git -a'
  alias lt='eza --tree --level=2 --long --icons --git'
else
  alias l='ls -CF'
fi

if command -v batcat >/dev/null 2>&1; then
  alias cat='batcat'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat'
fi

if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  alias kg='kubectl get'
  alias kd='kubectl describe'
  alias kl='kubectl logs -f'
  alias ke='kubectl exec -it'
  alias kcns='kubectl config set-context --current --namespace'
fi

if command -v docker >/dev/null 2>&1; then
  alias dco='docker compose'
  alias dps='docker ps'
  alias dpa='docker ps -a'
  alias dx='docker exec -it'
fi

if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  nvm() {
    unset -f nvm
    . "$NVM_DIR/nvm.sh"
    nvm "$@"
  }
fi

if [ -n "${BASH_VERSION:-}" ] && [ -s "$NVM_DIR/bash_completion" ]; then
  . "$NVM_DIR/bash_completion"
fi

FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  dotfiles_path_prepend "$FNM_PATH"
  if command -v fnm >/dev/null 2>&1; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      eval "$(fnm env --shell zsh)"
    else
      eval "$(fnm env --shell bash)"
    fi
  fi
fi

if command -v mise >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(mise activate zsh)"
  else
    eval "$(mise activate bash)"
  fi
fi

if [ -n "${BASH_VERSION:-}" ] && [ -r "$HOME/.openclaw/completions/openclaw.bash" ]; then
  . "$HOME/.openclaw/completions/openclaw.bash"
fi

__dotfiles_refresh_tmux_display_env() {
  [ -n "${TMUX:-}" ] || return 0
  command -v tmux >/dev/null 2>&1 || return 0
  eval "$(
    for name in DISPLAY WAYLAND_DISPLAY XAUTHORITY DBUS_SESSION_BUS_ADDRESS XDG_CURRENT_DESKTOP XDG_SESSION_TYPE; do
      tmux show-environment -s "$name" 2>/dev/null | sed '/^-/d'
    done
  )"
}

if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd __dotfiles_refresh_tmux_display_env
fi

if command -v zoxide >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(zoxide init zsh)"
  else
    eval "$(zoxide init bash)"
  fi
fi

if command -v yazi >/dev/null 2>&1; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || return
    yazi "$@" --cwd-file="$tmp"
    cwd="$(cat "$tmp" 2>/dev/null)"
    rm -f "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  }
fi

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
elif command -v fdfind >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
fi

if command -v fzf >/dev/null 2>&1; then
  if [ -n "${BASH_VERSION:-}" ]; then
    [ -r /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
    [ -r /usr/share/doc/fzf/examples/completion.bash ] && . /usr/share/doc/fzf/examples/completion.bash
    [ -r "$HOME/.local/share/fzf/shell/key-bindings.bash" ] && . "$HOME/.local/share/fzf/shell/key-bindings.bash"
    [ -r "$HOME/.local/share/fzf/shell/completion.bash" ] && . "$HOME/.local/share/fzf/shell/completion.bash"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    if zle >/dev/null 2>&1; then
      [ -r /usr/share/doc/fzf/examples/key-bindings.zsh ] && . /usr/share/doc/fzf/examples/key-bindings.zsh
      [ -r /usr/share/doc/fzf/examples/completion.zsh ] && . /usr/share/doc/fzf/examples/completion.zsh
      [ -r "$HOME/.local/share/fzf/shell/key-bindings.zsh" ] && . "$HOME/.local/share/fzf/shell/key-bindings.zsh"
      [ -r "$HOME/.local/share/fzf/shell/completion.zsh" ] && . "$HOME/.local/share/fzf/shell/completion.zsh"
    fi
  fi
fi

if command -v atuin >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(atuin init zsh)"
  else
    eval "$(atuin init bash)"
  fi
fi

if command -v direnv >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(direnv hook zsh)"
  else
    eval "$(direnv hook bash)"
  fi
fi

for dotfiles_openbao_env in \
  "$HOME/github/fos/platform/openbao/openbao-github-cli-shell-env.sh" \
  "$HOME/github/fos/infrastructure/openbao-github-cli-shell-env.sh"; do
  if [ -x "$dotfiles_openbao_env" ]; then
    eval "$("$dotfiles_openbao_env" 2>/dev/null)" || true
    break
  fi
done
unset dotfiles_openbao_env

hermes() {
  if dotfiles_is_spark; then
    command hermes "$@"
  else
    dotfiles_spark_command "export PATH=\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH; hermes" "$@"
  fi
}

agent-plan() {
  command agent-plan "$@"
}

agent-fast() {
  command agent-fast "$@"
}

agent-private() {
  command agent-private "$@"
}

gc() {
  if dotfiles_is_spark; then
    (cd "$HOME/gc" 2>/dev/null || cd "$HOME"; command gc "$@")
  else
    dotfiles_spark_command "export PATH=\$HOME/opt/go/bin:\$HOME/go/bin:\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH; cd ~/gc 2>/dev/null || cd ~; gc" "$@"
  fi
}

gt() {
  if dotfiles_is_spark; then
    command gt "$@"
  else
    dotfiles_spark_command "export PATH=\$HOME/.local/bin:\$PATH; gt" "$@"
  fi
}

bd() {
  if dotfiles_is_spark; then
    command bd "$@"
  else
    dotfiles_spark_command "export PATH=\$HOME/.local/bin:\$PATH; bd" "$@"
  fi
}

if command -v starship >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then
    eval "$(starship init zsh)"
  else
    eval "$(starship init bash)"
  fi
fi
