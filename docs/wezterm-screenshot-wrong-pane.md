# WezTerm snip captures the wrong tmux pane ("jumps to something prior")

**Symptom:** You press `Win+Shift+S`, drag over the pane you're looking at, but the
captured image is a *different* tmux pane/session — usually the one you just
switched away from. A second snip is often correct. Single monitor, single
WezTerm window — doesn't matter.

This took ~6 hours to diagnose once because the fixes were going to the repo but
not to the file WezTerm actually reads. Don't repeat that. Work this list **in order**.

## 60-second triage — do these BEFORE theorizing

1. **`Win+V` (Windows clipboard history) right after a snip.** Look at the top image.
   - **Top image already wrong** → the *snip itself* grabbed the wrong surface →
     it's the WezTerm/render layer. Continue below.
   - **Top image correct** → the snip is fine; the bug is the paste pipeline
     (`~/.config/wezterm/codex-image-paste.ps1` — its clipboard sequence-number
     guard can be fooled by unrelated clipboard activity into serving a stale image).

2. **Verify the LIVE config WezTerm actually loads** — `Ctrl+Shift+L` in WezTerm →
   `print(wezterm.config_file)`. Open **that** file and confirm it has
   `config.front_end = 'Software'` and the **de-grouped** `tmux_command`
   (`tmux new-session -A -s "$base"`, NOT per-tty `new-session -d -t "$base" -s ...`).
   - ⚠️ **THE TRAP:** on the laptop this is `C:\Users\<you>\.config\wezterm\wezterm.lua`,
     a **standalone copy** — it is NOT a symlink and does NOT auto-sync from this repo.
     Repo/Spark edits do not reach it. Sync it (see below) and re-check.

3. **Fully quit + relaunch WezTerm** — not `Ctrl+Shift+R`. `front_end` only binds at
   process startup, so a config *reload* won't apply it.

4. **tmux:** `tmux show-options -g focus-events` must be **on**; no grouped sibling
   sessions (`tmux list-sessions -F '#{session_name} #{session_group}'`).

## Known-good state

| Layer   | Setting |
|---------|---------|
| WezTerm | `front_end = 'Software'`, one window |
| tmux    | `focus-events on`, no grouped sibling sessions |
| Laptop  | live config **synced** from this repo (not a stale standalone copy) |

## Syncing the laptop's WezTerm config

The Windows config can't be a symlink (WSL/Windows boundary; Developer Mode off).
Keep it a real file and sync it after any change:

```sh
# on the LAPTOP, in WSL, after pulling dotfiles:
~/github/dotfiles/bin/sync-wezterm-to-windows
# then FULLY quit + relaunch WezTerm
```

Or push it straight from Spark (Spark can reach the laptop):

```sh
scp ~/github/dotfiles/wezterm/.config/wezterm/wezterm.lua \
    laptop:'C:/Users/Bruger/.config/wezterm/wezterm.lua'
# then the user fully restarts WezTerm
```

## Reaching the laptop from Spark (to verify/fix remotely)

`ssh laptop` works (ssh-config alias → user `Bruger` → Windows OpenSSH, lands in
`cmd.exe`); `scp` works too. To run Windows GUI/clipboard inspection, drive
`powershell.exe`. To read WSL-side files, `ssh laptop "wsl -d Ubuntu -- <cmd>"`.

## What it was NOT (ruled out, with proof — don't re-chase)

- **tmux switching windows** — a 600-sample focus-aware watch showed the client
  never left the current session during a snip.
- **Stale GPU frame** — persisted under `front_end='Software'` (CPU rendering).
- **AutoHotkey / PowerToys / Keyboard Manager** — no hook binds `Win+Shift+S`;
  the `codex-image-paste.ahk` only rebinds `Ctrl+V` and only when Zed is focused.

The actual cause was the render/present layer showing a stale surface, fixed by
the synced `front_end='Software'` + de-grouped sessions + `focus-events on`, all
live together after a clean full restart.
