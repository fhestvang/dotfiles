# ~/.bash_profile

if [ -r "$HOME/.profile" ]; then
  . "$HOME/.profile"
elif [ -r "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi

if [[ $- == *i* ]] && [ -z "${DOTFILES_STAY_IN_BASH:-}" ] && [ -f "$HOME/.dotfiles-auto-zsh" ]; then
  if [ -x "$HOME/.local/bin/zsh" ]; then
    export SHELL="$HOME/.local/bin/zsh"
    exec "$HOME/.local/bin/zsh" -l
  elif command -v zsh >/dev/null 2>&1; then
    export SHELL="$(command -v zsh)"
    exec "$(command -v zsh)" -l
  fi
fi
