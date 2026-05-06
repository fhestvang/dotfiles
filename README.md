# dotfiles

Linux-native shell, Git, tmux, and prompt configuration.

## Install

```sh
cd ~/github/dotfiles
./install.sh
```

That links the managed files into `$HOME` and moves any existing files to
`~/.dotfiles-backup/<timestamp>/`.

To install shell tools:

```sh
./install.sh --install-packages
```

The installer uses `apt` or Homebrew when available. Without sudo, it still
installs user-local tools where possible.

To switch the login shell after `zsh` is installed:

```sh
./install.sh --set-zsh
```

## Managed Files

- `~/.bashrc`
- `~/.bash_aliases`
- `~/.zshrc`
- `~/.zprofile`
- `~/.gitconfig`
- `~/.tmux.conf`
- `~/.config/starship.toml`

## Tools

The config uses these when installed:

- `zsh`
- `starship`
- `fzf`
- `zoxide`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
- `fzf-tab`
- `tmux` with TPM

The active config avoids legacy `/mnt/...` paths.
