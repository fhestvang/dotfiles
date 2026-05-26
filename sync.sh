#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET="spark"

if [ -x "$DOTFILES_DIR/bin/prompt-host" ]; then
  case "$("$DOTFILES_DIR/bin/prompt-host" 2>/dev/null || true)" in
    spark) DEFAULT_TARGET="laptop" ;;
  esac
fi

TARGET="${1:-$DEFAULT_TARGET}"
REMOTE_DIR="${DOTFILES_REMOTE_DIR:-~/github/dotfiles}"
INSTALL_ARGS="${DOTFILES_INSTALL_ARGS:---install-packages --auto-zsh}"
WSL_DISTRO="${DOTFILES_WSL_DISTRO:-Ubuntu}"
FORCE="${DOTFILES_SYNC_FORCE:-0}"
SSH_OPTS=(-o BatchMode=yes -o ClearAllForwardings=yes)

printf 'sync: %s -> %s:%s\n' "$DOTFILES_DIR" "$TARGET" "$REMOTE_DIR"

abort_if_dirty() {
  local status="$1"
  local label="$2"

  if [ -n "$status" ] && [ "$FORCE" != "1" ]; then
    printf 'abort: %s has uncommitted dotfiles changes\n' "$label" >&2
    printf '%s\n' "$status" >&2
    printf 'set DOTFILES_SYNC_FORCE=1 to overwrite intentionally\n' >&2
    exit 1
  fi
}

SOURCE_STATUS="$(
  if command -v git >/dev/null 2>&1 && git -C "$DOTFILES_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$DOTFILES_DIR" status --porcelain
  fi
)"
abort_if_dirty "$SOURCE_STATUS" "source:$DOTFILES_DIR"

sync_windows_wsl() {
  local status

  status="$(
    ssh "${SSH_OPTS[@]}" "$TARGET" \
      "wsl.exe -d $WSL_DISTRO -- bash -lc \"if [ -d ~/github/dotfiles/.git ]; then git -C ~/github/dotfiles status --porcelain; fi\"" \
      2>/dev/null || true
  )"
  abort_if_dirty "$status" "$TARGET:$WSL_DISTRO"

  tar -C "$DOTFILES_DIR" -czf - . | ssh "${SSH_OPTS[@]}" "$TARGET" \
    "wsl.exe -d $WSL_DISTRO -- bash -lc \"rm -rf ~/github/dotfiles && mkdir -p ~/github/dotfiles && tar -xzf - -C ~/github/dotfiles && cd ~/github/dotfiles && ./install.sh $INSTALL_ARGS\""
}

case "$TARGET" in
  laptop|desktop-t9m5u7n|laptop-tail|desktop-t9m5u7n-tail|laptop-lan|desktop-t9m5u7n-lan)
    sync_windows_wsl
    exit 0
    ;;
esac

REMOTE_STATUS="$(
  ssh "${SSH_OPTS[@]}" "$TARGET" \
    "if [ -d $REMOTE_DIR/.git ]; then git -C $REMOTE_DIR status --porcelain; fi" \
    2>/dev/null || true
)"
abort_if_dirty "$REMOTE_STATUS" "$TARGET"

ssh "${SSH_OPTS[@]}" "$TARGET" "mkdir -p $REMOTE_DIR"

rsync -az --delete \
  -e "ssh ${SSH_OPTS[*]}" \
  "$DOTFILES_DIR/" "$TARGET:$REMOTE_DIR/"

ssh "${SSH_OPTS[@]}" "$TARGET" \
  "cd $REMOTE_DIR && ./install.sh $INSTALL_ARGS"
