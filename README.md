# dotfiles

Linux-native shell, Git, tmux, and prompt configuration.

This repo is the source of truth for the laptop and `spark`. Installed config
files are laid out as GNU Stow packages, with a single installer that backs up
replaced files and can bootstrap the tools the shell config expects.

## Install

```sh
cd ~/github/dotfiles
./install.sh
```

Short setup entrypoint:

```sh
./setup.sh
```

That runs Stow for the managed config packages and moves any replaced files to
`~/.dotfiles-backup/<timestamp>/`.

To install shell tools:

```sh
./install.sh --install-packages
```

The installer uses `apt` or Homebrew when available. Without sudo on Ubuntu, it
still installs user-local tools where possible, including GNU Stow, `eza`,
`direnv`, `fd`, `rg`, `bat`, `mise`, `yazi`, and `atuin`.

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

## Windows WezTerm

On the Windows laptop, run the installer from inside the Ubuntu WSL distro. It
links the Linux dotfiles and copies `wezterm/*` into:

```text
%USERPROFILE%\.config\wezterm\
```

WezTerm then opens directly into an Ubuntu WSL login shell. The launch menu
keeps explicit entries for laptop shell, Spark shell, laptop tmux, Spark tmux,
and PowerShell. Use `t` or the tmux launch-menu entries when you want to attach
the shared `main` tmux session; the default terminal avoids auto-attaching tmux
so restored windows do not create tmux-inside-tmux sessions.

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

## Auto fan-out on commit

`install.sh` links `hooks/post-commit` into `.git/hooks/post-commit`. After a
commit on a source-of-truth machine (`spark`/`laptop`), it runs
`bin/dotfiles-fleet-sync`, which fans out a full `sync.sh` (`--install-packages
--auto-zsh`) to the fleet in the background. The commit returns immediately;
progress lands in `~/.cache/dotfiles-fleet-sync/latest.log`.

The fan-out self-guards: it is a no-op on any host whose `prompt-host` label is
not `spark` or `laptop`, so fleet nodes (which receive a mirrored `.git`) never
fan out to their siblings. Tunables:

```sh
DOTFILES_FLEET="eigil ingvild"   # override the host list
DOTFILES_FANOUT_PUSH=1           # also push origin during fan-out (default off)
dotfiles-fleet-sync              # run the fan-out by hand
```

To skip the fan-out for one commit, use `git commit --no-verify` is not enough
(post-commit always runs); instead commit with the hook disabled:
`git -c core.hooksPath=/dev/null commit ...`.

## SSH config

The top-level `~/.ssh/config` stays machine-local (it holds host-specific blocks
like how Spark reaches the laptop). Shared SSH config lives in the `ssh` stow
package as `~/.ssh/config.d/*.conf` fragments, pulled in by an
`Include config.d/*.conf` line that `install.sh` (`ensure_ssh_include`) adds to
the local config idempotently.

`10-fleet.conf` carries the fleet aliases (`eigil`/`ingvild`/`dicte`/`pi3` over
the tailnet, one block via `HostName %h.olm-hops.ts.net`) and a
`SetEnv LC_ALL=C.UTF-8` block so login shells on boxes lacking `en_US.UTF-8`
don't emit setlocale warnings. The `*.olm-hops.ts.net` glob auto-covers future
tailnet hosts (e.g. Scaleway VPCs).

## Linear (Idea Vault)

`linear-tui` (roeyazroel/linear-tui) is installed fleet-wide by `install.sh`. It
authenticates with `LINEAR_API_KEY`, injected at launch by a wrapper in
`shell/common.sh` in this order: an exported env var, then OpenBao
(`kv/projects/linear`, field `api_key`), then a local `~/.config/linear-tui/env`.

OpenBao is now reachable from **every** box (the tailnet ACL grants `tag:tiny ->
svc:bao`), so the wrapper reads the key from Bao at call time everywhere — no
per-box materialization. Bao auth on the fleet uses a scoped **read-only**
AppRole token in `~/.vault-token`; `bin/bao-relogin` refreshes it from the
AppRole creds in `~/.config/bao/approle`. `BAO_ADDR` defaults via `common.sh`.

Rotation is just (Bao is the single source of truth; no propagation step):

```sh
bao kv patch kv/projects/linear api_key=lin_api_...   # or the OpenBao UI
```

(The old push-materialize helper `dotfiles-fleet-linear-key` was retired once the
fleet could reach Bao directly.)

## Agent Runtime Surface

Dotfiles is the machine bootstrap surface. It installs shell/editor config and,
when `~/github/fhh-toolkit` exists, runs:

```sh
~/github/fhh-toolkit/runtimes/codex/sync-config.sh
~/github/fhh-toolkit/runtimes/claude/sync-config.sh
```

That means laptop and Spark should get the same Codex and Claude defaults from
the toolkit while keeping auth, caches, sessions, memories, telemetry, and
generated hook trust state local.

Canonical dev roots on both machines:

```text
~/github/fos
~/github/fhh-toolkit
~/github/dotfiles
~/github/fos-workbench
~/github/job-searching
```

`~/github/fos` and its siblings are the default work surface. Top-level clones
such as `~/fos` or `~/fhh-toolkit` are transition clones unless a task
explicitly names them.

Repo-level `AGENTS.md`, `CLAUDE.md`, `.codex/`, and `.claude/` files should
stay in the owning repo because they carry project contracts and repo-specific
hooks. Shared skills, routing, and runtime defaults belong in
`~/github/fhh-toolkit`; dotfiles only installs/syncs them onto each machine.

## Syncing Spark

From the laptop:

```sh
cd ~/github/dotfiles
./sync.sh spark
```

The script mirrors the repo to `spark:~/github/dotfiles/` and runs:

```sh
./install.sh --install-packages --auto-zsh
```

When run from `spark`, `./sync.sh` defaults to the `laptop` SSH alias and
targets the laptop's Ubuntu WSL distro. The sync script aborts if either side
has uncommitted dotfiles changes. To overwrite intentionally:

```sh
DOTFILES_SYNC_FORCE=1 ./sync.sh laptop
```

Manual form:

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

Stow packages live at the repo root. Each package mirrors the path it owns under
`$HOME`:

```text
bash/.bashrc
zsh/.zshrc
tmux/.tmux.conf
starship/.config/starship.toml
wezterm/.config/wezterm/wezterm.lua
```

`install.sh` currently stows:

```text
bash zsh git readline tmux starship atuin ghostty wezterm
```

Those packages manage:

- `~/.bashrc`
- `~/.bash_profile`
- `~/.bash_aliases`
- `~/.zshrc`
- `~/.zprofile`
- `~/.gitconfig`
- `~/.tmux.conf`
- `~/.config/tmux/tmux.conf`
- `~/.config/starship.toml`
- `~/.config/atuin/config.toml`
- `~/.config/ghostty/config`
- `~/.config/wezterm/wezterm.lua`
- `~/.config/wezterm/remote-image-paste.lua`
- `~/.config/wezterm/codex-image-paste.ps1`

When the installer is running under WSL, the WezTerm files are also copied to
the Windows profile because Windows WezTerm cannot reliably follow Linux
symlinks inside the WSL filesystem.

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
- GNU Stow
- `direnv`
- `atuin`
- `eza`
- `bat`
- `fd`
- `ripgrep`
- `Ghostty`

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

- `cd <name>` jumps to a directory you use often (`zoxide` replaces `cd`).
- `cdi` opens an interactive `zoxide` picker.
- `Alt-C` opens an `fzf` directory picker.
- `Ctrl-T` opens an `fzf` file picker.
- In tmux, the prefix is `Alt-a`.
- In tmux, prefix then `z` opens a zoxide popup and creates a new window at the
  selected directory.
- In tmux, prefix then `Z` opens a zoxide popup shell at the selected directory.

History:

- `Ctrl-R` opens fuzzy command history search.
- In Zsh, typing the start of a previous command shows a grey autosuggestion.
- Press right arrow or `Ctrl-E` to accept an autosuggestion.

Completion:

- `Tab` completes commands, paths, Git branches, flags, and many installed tools.
- In Zsh, `fzf-tab` turns richer completions into a fuzzy menu.
- In Zsh, syntax highlighting marks valid and invalid commands while you type.

Atuin:

- Atuin is enabled automatically when installed.
- `~/.config/atuin/config.toml` keeps a compact fuzzy UI.
- Atuin sync still requires logging in on each machine with `atuin login` or
  `atuin register`.

Aliases:

- `t` attaches to a per-terminal grouped tmux session backed by `main`.
- `ts` does the same on `spark`.
- `tsp` opens the tmux session/window picker on the current machine.
- `cc` runs `claude --continue`.
- `gs`, `gd`, `gco`, `gb`, `ga`, `gpl`, `gps`, and `glog` cover common Git flows.
- `l` and `lt` use `eza` when installed and fall back to classic `ls`.
- `cat` uses `bat`/`batcat` when installed.
- `k`, `kg`, `kd`, `kl`, `ke`, and `kcns` appear when `kubectl` is installed.
- `dco`, `dps`, `dpa`, and `dx` appear when Docker is installed.

Project helpers:

- `hermes ...` runs the remote Hermes CLI on `spark`.
- `gt ...` runs the remote Gas Town CLI on `spark`.
- `gc ...` runs the remote `gc` CLI on `spark`.
- `bd ...` runs the remote Beads CLI on `spark`.

On `spark` itself, those helpers run local commands instead of SSHing back into
the same host.

## Remote Image Paste for Codex

Remote tmux cannot read the local GUI clipboard. For Codex screenshots, the
local terminal must read the clipboard and paste a remote image path into tmux.

For saved screenshots:

```sh
remote-image-paste --host spark --file ./screenshot.png
```

The helper converts clipboard formats such as BMP to PNG, uploads the image to
`spark:/home/fhestvang/.cache/codex-clipboard-images/`, and prints the remote
path. Pasting that path into Codex attaches the image.

Clipboard backends: Windows WezTerm uses the native
`codex-image-paste.ps1` helper with `ssh.exe` and `scp.exe`; Linux uses
`wl-paste` or `xclip`; macOS uses `pngpaste` or `osascript`.

In Windows WezTerm, keep both helper files in `wezterm.config_dir` and wire
paste through the module:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

package.path = package.path .. ';' .. wezterm.config_dir .. '/?.lua'
local remote_image_paste = require 'remote-image-paste'

remote_image_paste.apply(config, { host = 'spark', key = 'v', mods = 'CTRL' })
remote_image_paste.apply(config, { host = 'spark', key = 'v', mods = 'CTRL|SHIFT' })

return config
```

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
