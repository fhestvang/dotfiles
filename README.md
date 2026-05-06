# dotfiles

Linux-native shell, Git, tmux, and prompt configuration.

This repo is the source of truth for the laptop and `spark`.

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

On machines where `chsh` is unavailable or sudo is not available, enable an
interactive Bash-to-Zsh handoff:

```sh
./install.sh --install-packages --auto-zsh
```

To stay in Bash for one shell:

```sh
DOTFILES_STAY_IN_BASH=1 bash
```

## Machines

Laptop:

- Prompt label: `laptop`
- Uses system Zsh when installed.
- Source repo: `~/github/dotfiles`

Spark:

- Prompt label: `spark`
- Uses user-local Zsh at `~/.local/bin/zsh` when system Zsh is unavailable.
- Uses `~/.bash_profile` to enter Zsh from interactive Bash login shells.
- Source repo: `~/github/dotfiles`

Fresh shells should enter Zsh on both machines. Existing shells and tmux panes
keep the environment they started with.

To reload the current pane:

```sh
exec zsh -l
```

## Syncing Spark

From the laptop:

```sh
rsync -az --delete \
  -e 'ssh -o BatchMode=yes -o ClearAllForwardings=yes' \
  ~/github/dotfiles/ spark:~/github/dotfiles/

ssh -o BatchMode=yes -o ClearAllForwardings=yes spark \
  'cd ~/github/dotfiles && ./install.sh --install-packages --auto-zsh'
```

Verify both machines are on the same commit:

```sh
git -C ~/github/dotfiles log --oneline -1
ssh -o BatchMode=yes -o ClearAllForwardings=yes spark \
  'git -C ~/github/dotfiles log --oneline -1'
```

## Managed Files

- `~/.bashrc`
- `~/.bash_profile`
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

## Runtime Notes

- Autosuggestions are a Zsh feature here. Bash gets the prompt, `fzf`,
  `zoxide`, and aliases, but not grey inline autosuggestions.
- Autosuggestions appear for matching history or completion candidates; random
  text usually has no suggestion.
- `Ctrl-R`, `Ctrl-T`, `Alt-C`, and `z <name>` work after the shell has loaded
  the managed config.
- If a machine looks stale, check whether the current pane is old:

```sh
echo "$SHELL"
echo "$ZSH_VERSION"
git -C ~/github/dotfiles log --oneline -1
```

## What You Can Do

Prompt:

- See the machine name as `laptop`, `spark`, or the short hostname.
- See the current directory.
- See Git branch and dirty/ahead/behind status when inside a repo.
- Keep the prompt compact by leaving date/time out of the left prompt.

Navigation:

- `z <name>` jumps to a directory you use often.
- `zi` opens an interactive `zoxide` picker.
- `Alt-C` opens an `fzf` directory picker.
- `Ctrl-T` opens an `fzf` file picker.

History:

- `Ctrl-R` opens fuzzy command history search.
- In Zsh, typing the start of a previous command shows a grey autosuggestion.
- Press right arrow or `Ctrl-E` to accept an autosuggestion.

Completion:

- `Tab` completes commands, paths, Git branches, flags, and many installed tools.
- In Zsh, `fzf-tab` turns richer completions into a fuzzy menu.
- In Zsh, syntax highlighting marks valid and invalid commands while you type.

Aliases:

- `t` attaches to or creates the main tmux session.
- `cc` runs `claude --continue`.

Project helpers:

- `hermes ...` runs the remote Hermes CLI on `spark`.
- `gt ...` runs the remote Gas Town CLI on `spark`.
- `bd ...` runs the remote Beads CLI on `spark`.

## Oh My Zsh

Oh My Zsh is a Zsh configuration framework. It is not Zsh itself.

What it would add:

- A large plugin catalog with ready-made aliases and completions.
- Many themes and prompt presets.
- A familiar community-standard layout.
- Convenient plugin toggles like `plugins=(git docker npm gh)`.

Why this repo does not use it right now:

- The current setup already covers the high-value pieces: prompt, fuzzy search,
  smarter `cd`, autosuggestions, syntax highlighting, and fuzzy tab completion.
- Startup is easier to understand because every loaded file is explicit.
- It is easier to reuse in dev containers and minimal machines.
- Debugging is simpler because there is no framework layer.

Good reasons to add Oh My Zsh later:

- You want lots of prebuilt command-specific plugins quickly.
- You like experimenting with themes.
- You want a larger convention around Zsh config.

The practical tradeoff:

```text
Current setup = small, explicit, fast, portable
Oh My Zsh    = bigger framework, more bundled convenience
```
