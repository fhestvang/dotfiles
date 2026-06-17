# ~/.zshrc

DOTFILES_ZSH_ROOT="$HOME/.local/opt/zsh-ubuntu"
if [ -d "$DOTFILES_ZSH_ROOT/usr/share/zsh/functions" ]; then
  fpath=(
    "$DOTFILES_ZSH_ROOT/usr/share/zsh/site-functions"
    "$DOTFILES_ZSH_ROOT/usr/share/zsh/vendor-functions"
    "$DOTFILES_ZSH_ROOT/usr/share/zsh/vendor-completions"
    "$DOTFILES_ZSH_ROOT/usr/share/zsh/functions"
    "$DOTFILES_ZSH_ROOT/usr/share/zsh/functions"/**/*(/N)
    $fpath
  )
fi

if [ -d "$HOME/.local/share/zsh/site-functions" ]; then
  fpath=("$HOME/.local/share/zsh/site-functions" $fpath)
fi

if [ -d "$DOTFILES_ZSH_ROOT/usr/lib/$(uname -m)-linux-gnu/zsh/$ZSH_VERSION" ]; then
  module_path=("$DOTFILES_ZSH_ROOT/usr/lib/$(uname -m)-linux-gnu/zsh/$ZSH_VERSION" $module_path)
elif [ -d "$DOTFILES_ZSH_ROOT/usr/lib/aarch64-linux-gnu/zsh/$ZSH_VERSION" ]; then
  module_path=("$DOTFILES_ZSH_ROOT/usr/lib/aarch64-linux-gnu/zsh/$ZSH_VERSION" $module_path)
elif [ -d "$DOTFILES_ZSH_ROOT/usr/lib/x86_64-linux-gnu/zsh/$ZSH_VERSION" ]; then
  module_path=("$DOTFILES_ZSH_ROOT/usr/lib/x86_64-linux-gnu/zsh/$ZSH_VERSION" $module_path)
fi

export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=20000

setopt AUTO_CD
setopt EXTENDED_GLOB
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt NO_BEEP

if [[ -o interactive ]]; then
  autoload -Uz compinit
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  _zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
  if [[ -n "$_zcompdump"(#qN.mh+24) ]]; then
    compinit -d "$_zcompdump"
  else
    compinit -C -d "$_zcompdump"
  fi
  unset _zcompdump

  zstyle ':completion:*' menu select
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
  zstyle ':completion:*' verbose yes

  # vim navigation inside the completion menu (applies to carapace too, since
  # carapace only supplies candidates; the menu itself is zsh's menuselect).
  zmodload zsh/complist
  bindkey -M menuselect 'h' vi-backward-char
  bindkey -M menuselect 'j' vi-down-line-or-history
  bindkey -M menuselect 'k' vi-up-line-or-history
  bindkey -M menuselect 'l' vi-forward-char
  bindkey -M menuselect '^[' undo            # Esc backs out of the menu

  bindkey -v
  export KEYTIMEOUT=1
  autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  bindkey -M viins '^[[A' up-line-or-beginning-search
  bindkey -M viins '^[[B' down-line-or-beginning-search
  bindkey -M vicmd '^[[A' up-line-or-beginning-search
  bindkey -M vicmd '^[[B' down-line-or-beginning-search

  bindkey -M viins '^?' backward-delete-char
  bindkey -M viins '^H' backward-delete-char
  bindkey -M vicmd '^?' backward-delete-char
  bindkey -M vicmd '^H' backward-delete-char
  bindkey -M viins '^W' backward-kill-word
  bindkey -M vicmd '^W' backward-kill-word
  bindkey -M viins '^U' kill-whole-line
  bindkey -M vicmd '^U' kill-whole-line
fi

if [ -r "$HOME/github/dotfiles/shell/common.sh" ]; then
  . "$HOME/github/dotfiles/shell/common.sh"
fi

ZSH_PLUGIN_DIR="${ZSH_PLUGIN_DIR:-$HOME/.local/share/zsh/plugins}"

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

if [ -r "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
  . "$ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
  if [[ -o interactive ]]; then
    bindkey '^ ' autosuggest-accept
    bindkey '^@' autosuggest-accept
    bindkey -M viins '^ ' autosuggest-accept
    bindkey -M viins '^@' autosuggest-accept
  fi
fi

if ! command -v starship >/dev/null 2>&1; then
  autoload -Uz vcs_info
  zstyle ':vcs_info:git:*' formats '%F{blue}%b%f'
  precmd() { vcs_info }
  DOTFILES_PROMPT_HOST="$("$HOME/github/dotfiles/bin/prompt-host" 2>/dev/null || hostname -s)"
  PROMPT='%F{cyan}${DOTFILES_PROMPT_HOST}%f %F{green}%~%f %# '
  RPROMPT='${vcs_info_msg_0_}'
fi

if [ -r "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  . "$ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

if [ -s "$HOME/.bun/_bun" ]; then
  . "$HOME/.bun/_bun"
fi

# Sandcastle Control Center
alias scc='node "$HOME/github/fos-workbench/scripts/sandcastle-control-center.mjs"'

# Local k3s tutorial cluster.
if [ -z "${KUBECONFIG:-}" ] && [ -r "$HOME/.kube/fos-workbench-k3s.yaml" ]; then
  export KUBECONFIG="$HOME/.kube/fos-workbench-k3s.yaml"
fi

# bun completions
[ -s "/home/fhestvang/.bun/_bun" ] && source "/home/fhestvang/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Omnigent: stop the build-age update nag (0.1.0 is latest; no newer release)
export OMNIGENT_NO_UPDATE_CHECK=1

# Scaleway CLI: inject API keys from OpenBao at call time, never from disk.
# config.yaml holds only non-secret defaults; the access/secret key live at
# kv/projects/scaleway/cli in Bao. Auth-free subcommands skip Bao so opening a
# terminal (and the autocomplete eval below) never needs Bao reachable.
scw() {
  case "$1" in
    autocomplete|version|help|--help|-h|config|"")
      command scw "$@" ;;
    *)
      local _ak _sk
      _ak=$(bao kv get -field=access_key kv/projects/scaleway/cli 2>/dev/null) \
        && _sk=$(bao kv get -field=secret_key kv/projects/scaleway/cli 2>/dev/null) \
        || { print -u2 "scw: could not read creds from Bao (sealed or unauthenticated?)"; return 1; }
      SCW_ACCESS_KEY=$_ak SCW_SECRET_KEY=$_sk command scw "$@" ;;
  esac
}

# Scaleway CLI autocomplete initialization (only when the CLI binary is present;
# $+commands checks for an external command and ignores the wrapper function
# above, which `command -v` would otherwise match on machines without scw).
if (( $+commands[scw] )); then
  eval "$(scw autocomplete script shell=zsh)"
fi

# carapace-bin: multi-shell completions (https://carapace.sh)
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
# carapace filters case-sensitively itself, ignoring zsh's matcher-list, so
# lowercase input (`nvim re`) misses uppercase files (README.md) without this.
export CARAPACE_MATCH=1
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
if (( $+commands[carapace] )); then
  source <(carapace _carapace)
fi
