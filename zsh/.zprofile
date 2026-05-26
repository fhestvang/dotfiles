# ~/.zprofile

if [ -r "$HOME/github/dotfiles/shell/wslg-env.sh" ]; then
  . "$HOME/github/dotfiles/shell/wslg-env.sh"
fi

path_prepend() {
  [ -d "$1" ] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.bun/bin"
export PATH

if [ -r "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi
