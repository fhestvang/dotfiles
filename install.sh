#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup}"
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
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

  # Debian usrmerge (e.g. Raspberry Pi OS) ships the binary at usr/bin/zsh;
  # older layouts use bin/zsh. Link whichever the deb actually produced.
  local zsh_bin=""
  local cand
  for cand in "$zsh_root/usr/bin/zsh" "$zsh_root/bin/zsh"; do
    if [ -x "$cand" ]; then
      zsh_bin="$cand"
      break
    fi
  done

  if [ -n "$zsh_bin" ]; then
    ln -sfn "$zsh_bin" "$HOME/.local/bin/zsh"
    echo "installed: user-local zsh -> $HOME/.local/bin/zsh"
  else
    echo "skip: user-local zsh package extraction did not produce a zsh binary"
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

github_latest_asset_url() {
  local repo="$1"
  local pattern="$2"

  have curl || return 1
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    sed -n 's/.*"browser_download_url": "\(.*\)".*/\1/p' |
    grep -E "$pattern" |
    head -n 1
}

install_apt_user_binary() {
  local package="$1"
  local binary_rel="$2"
  local primary="$3"
  shift 3

  if have "$primary"; then
    local alias_name
    for alias_name in "$@"; do
      if ! have "$alias_name"; then
        local primary_path
        primary_path="$(command -v "$primary")"
        mkdir -p "$HOME/.local/bin"
        ln -sfn "$primary_path" "$HOME/.local/bin/$alias_name"
      fi
    done
    return
  fi

  if ! have apt-get || ! have dpkg-deb; then
    echo "skip: user-local $primary install needs apt-get and dpkg-deb"
    return
  fi

  local tmp root alias_name
  tmp="$(mktemp -d)"
  root="$HOME/.local/opt/apt-user/$package"
  mkdir -p "$HOME/.local/bin" "$root"

  if ! (cd "$tmp" && apt-get download "$package"); then
    rm -rf "$tmp"
    echo "skip: could not download apt package $package"
    return
  fi

  rm -rf "$root"
  mkdir -p "$root"
  for deb in "$tmp"/*.deb; do
    dpkg-deb -x "$deb" "$root"
  done
  rm -rf "$tmp"

  if [ ! -x "$root/$binary_rel" ]; then
    echo "skip: $package did not provide $binary_rel"
    return
  fi

  ln -sfn "$root/$binary_rel" "$HOME/.local/bin/$primary"
  for alias_name in "$@"; do
    ln -sfn "$root/$binary_rel" "$HOME/.local/bin/$alias_name"
  done
  echo "installed: user-local $primary -> $HOME/.local/bin/$primary"
}

install_eza_user() {
  # eza must actually run, not merely exist: the apt-extracted build is missing
  # its libgit2 shared lib on bare machines. Reinstall from the self-contained
  # GitHub release (musl static on x86_64, gnu on aarch64) when eza is absent or
  # broken.
  if have eza && eza --version >/dev/null 2>&1; then
    return
  fi

  local target url tmp eza_bin
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    *) echo "skip: unsupported eza architecture $(uname -m)"; return ;;
  esac

  url="$(github_latest_asset_url eza-community/eza "eza_${target}[.]tar[.]gz$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find eza release asset for $target"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/eza.tar.gz" && tar -xzf "$tmp/eza.tar.gz" -C "$tmp"; then
    eza_bin="$(find "$tmp" -type f -name eza -perm -u=x | head -n 1)"
    if [ -n "$eza_bin" ]; then
      mkdir -p "$HOME/.local/bin"
      rm -f "$HOME/.local/bin/eza"
      install -m 755 "$eza_bin" "$HOME/.local/bin/eza"
      echo "installed: user-local eza -> $HOME/.local/bin/eza"
    else
      echo "skip: eza archive did not contain eza binary"
    fi
  else
    echo "skip: eza download or extraction failed"
  fi
  rm -rf "$tmp"
}

install_linear_tui_user() {
  # Linear TUI (roeyazroel/linear-tui) — a Go binary, installed from the GitHub
  # release rather than `go install` (no Go toolchain on the fleet). Auth is via
  # the LINEAR_API_KEY env var, injected at launch by the shell wrapper in
  # shell/common.sh (Bao-backed), so no key is ever written to disk here.
  if have linear-tui; then
    return
  fi

  local arch url tmp bin
  case "$(uname -m)" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) echo "skip: unsupported linear-tui architecture $(uname -m)"; return ;;
  esac

  url="$(github_latest_asset_url roeyazroel/linear-tui "linux_${arch}[.]tar[.]gz$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find linear-tui release asset for linux_$arch"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/linear-tui.tar.gz" && tar -xzf "$tmp/linear-tui.tar.gz" -C "$tmp"; then
    bin="$(find "$tmp" -type f -name linear-tui -perm -u=x | head -n 1)"
    if [ -n "$bin" ]; then
      mkdir -p "$HOME/.local/bin"
      install -m 755 "$bin" "$HOME/.local/bin/linear-tui"
      echo "installed: user-local linear-tui -> $HOME/.local/bin/linear-tui"
    else
      echo "skip: linear-tui archive did not contain the binary"
    fi
  else
    echo "skip: linear-tui download or extraction failed"
  fi
  rm -rf "$tmp"
}

install_bao_user() {
  # OpenBao CLI — needed on every box that reads secrets from Bao (chezmoi
  # secret rendering, the scw/linear wrappers). GitHub release binary.
  if have bao; then
    return
  fi

  local a url tmp bin
  case "$(uname -m)" in
    x86_64) a="x86_64" ;;
    aarch64|arm64) a="arm64" ;;
    *) echo "skip: unsupported bao architecture $(uname -m)"; return ;;
  esac

  url="$(github_latest_asset_url openbao/openbao "bao_[0-9][^_]*_Linux_${a}[.]tar[.]gz$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find bao release asset for Linux_$a"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/bao.tar.gz" && tar -xzf "$tmp/bao.tar.gz" -C "$tmp"; then
    bin="$(find "$tmp" -type f -name bao -perm -u=x | head -n 1)"
    if [ -n "$bin" ]; then
      mkdir -p "$HOME/.local/bin"
      install -m 755 "$bin" "$HOME/.local/bin/bao"
      echo "installed: user-local bao -> $HOME/.local/bin/bao"
    else
      echo "skip: bao archive did not contain the binary"
    fi
  else
    echo "skip: bao download or extraction failed"
  fi
  rm -rf "$tmp"
}

install_vkv_user() {
  # vkv (FalcoSuessgott/vkv) — recursive OpenBao/Vault KV browser + search, the
  # thing the Bao web UI can't do. Go binary from the GitHub release.
  if have vkv; then
    return
  fi

  local a url tmp bin
  case "$(uname -m)" in
    x86_64) a="x86_64" ;;
    aarch64|arm64) a="arm64" ;;
    *) echo "skip: unsupported vkv architecture $(uname -m)"; return ;;
  esac

  url="$(github_latest_asset_url FalcoSuessgott/vkv "vkv_Linux_${a}[.]tar[.]gz$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find vkv release asset for Linux_$a"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/vkv.tar.gz" && tar -xzf "$tmp/vkv.tar.gz" -C "$tmp"; then
    bin="$(find "$tmp" -type f -name vkv -perm -u=x | head -n 1)"
    if [ -n "$bin" ]; then
      mkdir -p "$HOME/.local/bin"
      install -m 755 "$bin" "$HOME/.local/bin/vkv"
      echo "installed: user-local vkv -> $HOME/.local/bin/vkv"
    else
      echo "skip: vkv archive did not contain the binary"
    fi
  else
    echo "skip: vkv download or extraction failed"
  fi
  rm -rf "$tmp"
}

install_apt_user_tools() {
  install_apt_user_binary direnv usr/bin/direnv direnv
  install_apt_user_binary fd-find usr/bin/fdfind fdfind fd
  install_apt_user_binary ripgrep usr/bin/rg rg
  install_apt_user_binary bat usr/bin/batcat batcat bat
  # unzip is a hard dependency of install_yazi_user; pull it user-local so yazi
  # is not silently skipped on minimal images that lack it.
  install_apt_user_binary unzip usr/bin/unzip unzip
}

report_tool_health() {
  # Surface partial failures instead of always printing a cheerful "done".
  # Mirror the interactive PATH so tools that live outside ~/.local/bin (fzf)
  # are not falsely reported missing.
  local PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$HOME/.local/share/fzf/bin:$PATH"
  local tool missing=()
  for tool in zsh starship fzf zoxide eza rg fd bat atuin mise direnv tmux git bao linear-tui vkv chezmoi; do
    have "$tool" || missing+=("$tool")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "health: all expected tools resolve"
  else
    echo "health: MISSING -> ${missing[*]}"
  fi
}

install_mise_user() {
  if have mise; then
    return
  fi

  local arch asset_pattern url tmp
  case "$(uname -m)" in
    x86_64) arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) echo "skip: unsupported mise architecture $(uname -m)"; return ;;
  esac

  asset_pattern="mise-v[0-9][^/]*-linux-$arch$"
  url="$(github_latest_asset_url jdx/mise "$asset_pattern" || true)"
  if [ -z "$url" ]; then
    if have curl; then
      curl -fsSL https://mise.run | sh -s -- -y --bin-dir "$HOME/.local/bin" \
        || echo "skip: mise install script failed"
      return
    fi
    echo "skip: could not find mise release asset for linux-$arch"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/mise"; then
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$tmp/mise" "$HOME/.local/bin/mise"
    echo "installed: user-local mise -> $HOME/.local/bin/mise"
  else
    echo "skip: mise download failed"
  fi
  rm -rf "$tmp"
}

install_yazi_user() {
  if have yazi; then
    return
  fi

  local target url tmp yazi_bin ya_bin
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    *) echo "skip: unsupported yazi architecture $(uname -m)"; return ;;
  esac

  if ! have unzip; then
    echo "skip: yazi install needs unzip"
    return
  fi

  url="$(github_latest_asset_url sxyazi/yazi "yazi-${target}[.]zip$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find yazi release asset for $target"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/yazi.zip" && unzip -q "$tmp/yazi.zip" -d "$tmp"; then
    yazi_bin="$(find "$tmp" -type f -name yazi -perm -u=x | head -n 1)"
    ya_bin="$(find "$tmp" -type f -name ya -perm -u=x | head -n 1)"
    if [ -n "$yazi_bin" ]; then
      mkdir -p "$HOME/.local/bin"
      install -m 755 "$yazi_bin" "$HOME/.local/bin/yazi"
      [ -n "$ya_bin" ] && install -m 755 "$ya_bin" "$HOME/.local/bin/ya"
      echo "installed: user-local yazi -> $HOME/.local/bin/yazi"
    else
      echo "skip: yazi archive did not contain yazi binary"
    fi
  else
    echo "skip: yazi download or extraction failed"
  fi
  rm -rf "$tmp"
}

install_atuin_user() {
  if have atuin; then
    return
  fi

  local target url tmp atuin_bin
  case "$(uname -m)" in
    x86_64) target="x86_64-unknown-linux-gnu" ;;
    aarch64|arm64) target="aarch64-unknown-linux-gnu" ;;
    *) echo "skip: unsupported atuin architecture $(uname -m)"; return ;;
  esac

  url="$(github_latest_asset_url atuinsh/atuin "atuin-${target}[.]tar[.]gz$" || true)"
  if [ -z "$url" ]; then
    echo "skip: could not find atuin release asset for $target"
    return
  fi

  tmp="$(mktemp -d)"
  if curl -fL "$url" -o "$tmp/atuin.tar.gz" && tar -xzf "$tmp/atuin.tar.gz" -C "$tmp"; then
    atuin_bin="$(find "$tmp" -type f -name atuin -perm -u=x | head -n 1)"
    if [ -n "$atuin_bin" ]; then
      mkdir -p "$HOME/.local/bin"
      install -m 755 "$atuin_bin" "$HOME/.local/bin/atuin"
      echo "installed: user-local atuin -> $HOME/.local/bin/atuin"
    else
      echo "skip: atuin archive did not contain atuin binary"
    fi
  else
    echo "skip: atuin download or extraction failed"
  fi
  rm -rf "$tmp"
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

windows_powershell() {
  local candidate

  if command -v powershell.exe >/dev/null 2>&1; then
    command -v powershell.exe
    return
  fi

  for candidate in \
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /mnt/c/Program\ Files/PowerShell/7/pwsh.exe
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  return 1
}

windows_home_from_wsl() {
  have wslpath || return 1

  local powershell win_home
  powershell="$(windows_powershell)" || return 1
  win_home="$(
    "$powershell" -NoProfile -NonInteractive \
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

install_agent_runtime_configs() {
  local toolkit_dir="${FHH_TOOLKIT_DIR:-$HOME/github/fhh-toolkit}"
  local script

  if [ ! -d "$toolkit_dir" ]; then
    echo "skip: fhh-toolkit not found for agent runtime sync ($toolkit_dir)"
    return
  fi

  for script in \
    "$toolkit_dir/runtimes/codex/sync-config.sh" \
    "$toolkit_dir/runtimes/claude/sync-config.sh" \
    "$toolkit_dir/runtimes/pi/sync-config.sh" \
    "$toolkit_dir/runtimes/vibe/sync-config.sh"
  do
    if [ -x "$script" ]; then
      if ! "$script"; then
        echo "warn: agent runtime sync failed: $script" >&2
      fi
    else
      echo "skip: agent runtime sync missing: $script"
    fi
  done
}

install_packages() {
  if have apt-get; then
    if [ "$(id -u)" -eq 0 ]; then
      apt-get update
      apt-get install -y zsh fzf zoxide tmux git curl direnv fd-find ripgrep bat
    elif sudo -n true 2>/dev/null; then
      sudo apt-get update
      sudo apt-get install -y zsh fzf zoxide tmux git curl direnv fd-find ripgrep bat
    else
      echo "skip: sudo requires a password in this session"
      echo "run manually: sudo apt-get update && sudo apt-get install -y zsh fzf zoxide tmux git curl direnv fd-find ripgrep bat"
    fi
  elif have brew; then
    brew install zsh fzf zoxide starship tmux git direnv fd ripgrep bat eza atuin yazi
  else
    echo "skip: no supported package manager found"
  fi

  install_starship_user
  install_zsh_user_apt
  install_fzf_user
  install_zoxide_user
  install_apt_user_tools
  install_eza_user
  install_mise_user
  install_yazi_user
  install_atuin_user
  install_bao_user
  install_linear_tui_user
  install_vkv_user
  install_chezmoi_user
}

ensure_ssh_include() {
  # chezmoi owns ~/.ssh/config.d/*.conf, but the top-level ~/.ssh/config is
  # machine-local (it holds host-specific blocks).
  # Make sure that local config pulls in the shared fragments. Idempotent.
  local ssh_dir="$HOME/.ssh"
  local cfg="$ssh_dir/config"
  local include_line="Include config.d/*.conf"

  mkdir -p "$ssh_dir/config.d"
  chmod 700 "$ssh_dir" "$ssh_dir/config.d" 2>/dev/null || true

  if [ ! -e "$cfg" ]; then
    printf '%s\n' "$include_line" >"$cfg"
    chmod 600 "$cfg"
    echo "ssh: created $cfg with config.d include"
    return
  fi

  if ! grep -qxF "$include_line" "$cfg"; then
    printf '%s\n\n%s\n' "$include_line" "$(cat "$cfg")" >"$cfg.dotfiles-tmp" \
      && mv "$cfg.dotfiles-tmp" "$cfg"
    echo "ssh: added config.d include to $cfg"
  fi
}

install_chezmoi_user() {
  # chezmoi is the fleet's convergence manager (pull model). A box bootstrapped
  # by install.sh gets it too; `chezmoi init --apply <repo>` then takes over and
  # `chezmoi update` (cron) keeps it converged. This replaced the old push
  # fan-out (the retired hooks/post-commit + bin/dotfiles-fleet-sync).
  if have chezmoi; then
    return
  fi
  if have curl; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" \
      || echo "skip: chezmoi install failed"
  else
    echo "skip: curl required for user-local chezmoi install"
  fi
}

if [ "$INSTALL_PACKAGES" -eq 1 ]; then
  install_packages
fi

ensure_ssh_include
install_zsh_plugins
install_wezterm_config
install_agent_runtime_configs
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

report_tool_health
echo "done"
