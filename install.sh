#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup}"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
INSTALL_PACKAGES=0
SET_ZSH=0
AUTO_ZSH=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--install-packages] [--set-zsh]

Options:
  --install-packages  Install missing tools with apt, Homebrew, or user-local installers.
  --set-zsh           Change the login shell to zsh if zsh is installed.
  --auto-zsh          Auto-enter zsh from interactive Bash using ~/.dotfiles-auto-zsh.
  -h, --help          Show this help.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --install-packages) INSTALL_PACKAGES=1 ;;
    --set-zsh) SET_ZSH=1 ;;
    --auto-zsh) AUTO_ZSH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

have() {
  command -v "$1" >/dev/null 2>&1
}

link_file() {
  local source="$1"
  local target="$2"
  local rel backup_target

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "ok: $target already linked"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    rel="${target#$HOME/}"
    backup_target="$BACKUP_DIR/$rel"
    mkdir -p "$(dirname "$backup_target")"
    mv "$target" "$backup_target"
    echo "backup: $target -> $backup_target"
  fi

  ln -s "$source" "$target"
  echo "link: $target -> $source"
}

clone_or_update() {
  local url="$1"
  local dest="$2"

  if [ -d "$dest/.git" ]; then
    git -C "$dest" pull --ff-only
  else
    git clone --depth 1 "$url" "$dest"
  fi
}

install_starship_user() {
  if have starship; then
    return
  fi

  mkdir -p "$HOME/.local/bin"
  if have curl; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y
  else
    echo "skip: curl is required for user-local starship install"
  fi
}

install_zsh_user_apt() {
  if have zsh; then
    return
  fi

  if ! have apt-get || ! have dpkg-deb; then
    echo "skip: user-local zsh install needs apt-get and dpkg-deb"
    return
  fi

  local tmp zsh_root
  tmp="$(mktemp -d)"
  zsh_root="$HOME/.local/opt/zsh-ubuntu"
  mkdir -p "$HOME/.local/bin" "$zsh_root"

  (
    cd "$tmp"
    apt-get download zsh zsh-common
    for deb in ./*.deb; do
      dpkg-deb -x "$deb" "$zsh_root"
    done
  )

  rm -rf "$tmp"

  if [ -x "$zsh_root/bin/zsh" ]; then
    ln -sfn "$zsh_root/bin/zsh" "$HOME/.local/bin/zsh"
    echo "installed: user-local zsh -> $HOME/.local/bin/zsh"
  else
    echo "skip: user-local zsh package extraction did not produce $zsh_root/bin/zsh"
  fi
}

install_fzf_user() {
  if have fzf; then
    return
  fi

  local fzf_dir="$HOME/.local/share/fzf"
  clone_or_update https://github.com/junegunn/fzf "$fzf_dir"
  "$fzf_dir/install" --bin
}

install_zoxide_user() {
  if have zoxide; then
    return
  fi

  if have curl; then
    if curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh; then
      return
    fi
    echo "skip: prebuilt zoxide install failed"
  fi

  if have cargo && have cc; then
    cargo install zoxide --locked || echo "skip: cargo zoxide install failed"
  else
    echo "skip: zoxide needs curl or cargo plus a C compiler"
  fi
}

install_zsh_plugins() {
  local plugin_dir="$HOME/.local/share/zsh/plugins"
  mkdir -p "$plugin_dir"

  clone_or_update https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
  clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting "$plugin_dir/zsh-syntax-highlighting"
  clone_or_update https://github.com/Aloxaf/fzf-tab "$plugin_dir/fzf-tab"
}

install_tmux_plugins() {
  clone_or_update https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
}

install_packages() {
  if have apt-get; then
    if [ "$(id -u)" -eq 0 ]; then
      apt-get update
      apt-get install -y zsh fzf zoxide tmux git curl
    elif sudo -n true 2>/dev/null; then
      sudo apt-get update
      sudo apt-get install -y zsh fzf zoxide tmux git curl
    else
      echo "skip: sudo requires a password in this session"
      echo "run manually: sudo apt-get update && sudo apt-get install -y zsh fzf zoxide tmux git curl"
    fi
  elif have brew; then
    brew install zsh fzf zoxide starship tmux git
  else
    echo "skip: no supported package manager found"
  fi

  install_starship_user
  install_zsh_user_apt
  install_fzf_user
  install_zoxide_user
}

if [ "$INSTALL_PACKAGES" -eq 1 ]; then
  install_packages
fi

install_zsh_plugins
install_tmux_plugins

link_file "$DOTFILES_DIR/bash/bashrc" "$HOME/.bashrc"
link_file "$DOTFILES_DIR/bash/bash_profile" "$HOME/.bash_profile"
link_file "$DOTFILES_DIR/bash/bash_aliases" "$HOME/.bash_aliases"
link_file "$DOTFILES_DIR/zsh/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/zsh/zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/git/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/starship/starship.toml" "$HOME/.config/starship.toml"

if [ "$SET_ZSH" -eq 1 ]; then
  if ! have zsh; then
    echo "skip: zsh is not installed yet"
  elif [ "${SHELL:-}" = "$(command -v zsh)" ]; then
    echo "ok: login shell is already zsh"
  else
    chsh -s "$(command -v zsh)"
  fi
fi

if [ "$AUTO_ZSH" -eq 1 ]; then
  touch "$HOME/.dotfiles-auto-zsh"
  echo "ok: enabled Bash-to-Zsh handoff with $HOME/.dotfiles-auto-zsh"
fi

echo "done"
