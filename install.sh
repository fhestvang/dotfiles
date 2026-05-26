#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup}"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
STOW_PACKAGES=(bash zsh git readline tmux starship atuin ghostty wezterm)
STOW_TARGETS=(
  "$HOME/.bashrc"
  "$HOME/.bash_profile"
  "$HOME/.bash_aliases"
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.gitconfig"
  "$HOME/.inputrc"
  "$HOME/.tmux.conf"
  "$HOME/.config/tmux/tmux.conf"
  "$HOME/.config/starship.toml"
  "$HOME/.config/atuin/config.toml"
  "$HOME/.config/ghostty/config"
  "$HOME/.config/wezterm/wezterm.lua"
  "$HOME/.config/wezterm/remote-image-paste.lua"
  "$HOME/.config/wezterm/codex-image-paste.ps1"
)
INSTALL_PACKAGES=0
SET_ZSH=0
AUTO_ZSH=0

export PATH="$HOME/.local/bin:$PATH"

usage() {
  cat <<'USAGE'
Usage: ./install.sh [--install-packages] [--set-zsh] [--auto-zsh]

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

backup_path() {
  local target="$1"
  local rel backup_target

  rel="${target#$HOME/}"
  backup_target="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$backup_target")"
  mv "$target" "$backup_target"
  echo "backup: $target -> $backup_target"
}

copy_file() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [ -f "$target" ] && cmp -s "$source" "$target"; then
    echo "ok: $target already current"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    backup_path "$target"
  fi

  cp "$source" "$target"
  echo "copy: $target <- $source"
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

install_stow_user_apt() {
  if have stow; then
    return
  fi

  if ! have apt-get || ! have dpkg-deb || ! have perl; then
    echo "skip: user-local stow install needs apt-get, dpkg-deb, and perl"
    return
  fi

  local tmp stow_root wrapper
  tmp="$(mktemp -d)"
  stow_root="$HOME/.local/opt/stow-ubuntu"
  wrapper="$HOME/.local/bin/stow"
  mkdir -p "$HOME/.local/bin" "$stow_root"

  (
    cd "$tmp"
    apt-get download stow
    for deb in ./*.deb; do
      dpkg-deb -x "$deb" "$stow_root"
    done
  )

  rm -rf "$tmp"

  if [ -x "$stow_root/usr/bin/stow" ]; then
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      "export PERL5LIB=\"$stow_root/usr/share/perl5\${PERL5LIB:+:\$PERL5LIB}\"" \
      "exec \"$stow_root/usr/bin/stow\" \"\$@\"" \
      > "$wrapper"
    chmod +x "$wrapper"
    echo "installed: user-local stow -> $wrapper"
  else
    echo "skip: user-local stow package extraction did not produce $stow_root/usr/bin/stow"
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
  if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    "$HOME/.tmux/plugins/tpm/bin/install_plugins"
  fi
}

is_wsl() {
  grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease 2>/dev/null
}

windows_home_from_wsl() {
  have powershell.exe || return 1
  have wslpath || return 1

  local win_home
  win_home="$(
    powershell.exe -NoProfile -NonInteractive \
      -Command '[Console]::Out.Write([Environment]::GetFolderPath("UserProfile"))' \
      2>/dev/null | tr -d '\r'
  )"

  [ -n "$win_home" ] || return 1
  wslpath -u "$win_home"
}

install_wezterm_config() {
  local source_dir="$DOTFILES_DIR/wezterm/.config/wezterm"
  local windows_home windows_config_dir file

  [ -d "$source_dir" ] || return 0

  if is_wsl; then
    if windows_home="$(windows_home_from_wsl)"; then
      windows_config_dir="$windows_home/.config/wezterm"
      for file in wezterm.lua remote-image-paste.lua codex-image-paste.ps1; do
        [ -f "$source_dir/$file" ] || continue
        copy_file "$source_dir/$file" "$windows_config_dir/$file"
      done
    else
      echo "skip: could not resolve Windows home for WezTerm config"
    fi
  fi
}

install_packages() {
  if have apt-get; then
    if [ "$(id -u)" -eq 0 ]; then
      apt-get update
      apt-get install -y zsh fzf zoxide tmux git curl stow direnv fd-find ripgrep bat
    elif sudo -n true 2>/dev/null; then
      sudo apt-get update
      sudo apt-get install -y zsh fzf zoxide tmux git curl stow direnv fd-find ripgrep bat
    else
      echo "skip: sudo requires a password in this session"
      echo "run manually: sudo apt-get update && sudo apt-get install -y zsh fzf zoxide tmux git curl stow direnv fd-find ripgrep bat"
    fi
  elif have brew; then
    brew install zsh fzf zoxide starship tmux git stow direnv fd ripgrep bat eza atuin yazi
  else
    echo "skip: no supported package manager found"
  fi

  install_starship_user
  install_zsh_user_apt
  install_stow_user_apt
  install_fzf_user
  install_zoxide_user
}

ensure_stow() {
  if have stow; then
    return
  fi

  install_stow_user_apt
  if ! have stow; then
    echo "error: GNU Stow is required; install stow or run ./install.sh --install-packages" >&2
    exit 1
  fi
}

prepare_stow_target() {
  local target="$1"
  local link_dest resolved

  [ -e "$target" ] || [ -L "$target" ] || return 0

  if [ -L "$target" ]; then
    link_dest="$(readlink "$target")"
    resolved="$(readlink -f "$target" 2>/dev/null || true)"

    if [ -n "$resolved" ]; then
      case "$resolved" in
        "$DOTFILES_DIR"/*)
          return
          ;;
      esac
    fi

    case "$link_dest" in
      "$DOTFILES_DIR"/*|*github/dotfiles/*)
        rm "$target"
        echo "unlink: stale managed link $target -> $link_dest"
        return
        ;;
    esac
  fi

  backup_path "$target"
}

install_stow_packages() {
  local target

  ensure_stow
  for target in "${STOW_TARGETS[@]}"; do
    prepare_stow_target "$target"
  done

  stow -d "$DOTFILES_DIR" -t "$HOME" --no-folding -R "${STOW_PACKAGES[@]}"
}

if [ "$INSTALL_PACKAGES" -eq 1 ]; then
  install_packages
fi

install_zsh_plugins
install_stow_packages
install_wezterm_config
install_tmux_plugins

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
