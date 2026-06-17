# Win+Shift+S captures a stale frame of WezTerm ("jumps to something prior")

**Symptom:** You press `Win+Shift+S` and the frozen snip overlay shows an *older*
state of the WezTerm window — typically the tmux window/content from before your
last switch, up to minutes old. The live monitor is always correct; only the
capture is stale. A second snip immediately after is always correct.

**Root cause (verified 2026-06-12 with controlled red/green captures):** DWM
promotes the fullscreen WezTerm window to direct hardware scanout (Independent
Flip / Multi-Plane Overlay; dxdiag shows `MPO MaxPlanes: 2` on the AMD iGPU).
Your eyes get fresh frames straight from the scanout plane, but capture APIs
(Snipping Tool's Windows.Graphics.Capture) read DWM's composed desktop surface,
which froze at the moment of promotion. The first snip overlay *demotes* the
window back to composed mode — which is exactly why the second snip works.

**The fix:** disable overlay promotion at boot:

```powershell
# Admin. Note: the widely-cited Dwm\OverlayTestMode=5 key is IGNORED on
# Windows 11 24H2+/build 26200 — this is the key that works there:
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v DisableOverlays /t REG_DWORD /d 1 /f
# then reboot
```

Applied to the laptop 2026-06-12 (key set, active after next reboot).

**No-reboot confirmation / stopgap:** any always-on-top window overlapping
WezTerm forces DWM back to Composed Flip and capture turns fresh instantly
(ForceComposedFlip technique). `fos:platform/shortcuts/windows/fos-composed-pixel.ps1`
is a minimal helper (stop it by creating `%USERPROFILE%\fos-pixel-stop.flag`).

## Ruled out, with proof — don't re-chase

- **`front_end = 'Software'`** — stale snip reproduced with it verified live
  (config synced AND process restarted). Rasterizer choice doesn't change how
  the window is *presented*, which is where the bug lives.
- **`window_background_opacity = 0.99`** — stale snip reproduced with it
  verified live after a full restart. Does not prevent promotion on this stack.
- **tmux switching windows on focus loss** — instrumented every focus event and
  window change with hooks during a live repro: the snip's focus-out/in produced
  zero window/session changes. The "it switches windows" perception is the
  frozen overlay showing the stale surface.
- **tmux focus-events / session grouping** — orthogonal. (A leftover session
  group `transcribe` around `main` exists; harmless without a sibling, but
  worth removing if dictation tooling recreates siblings.)
- **GDI capture (BitBlt/CopyFromScreen)** — always fresh, even mid-bug. Only
  the Windows.Graphics.Capture path (Snipping Tool) reads the stale surface,
  which is why automated GDI probes can't reproduce this; verify via a real
  snip + clipboard readback instead.
- **AutoHotkey / paste pipeline** — separate failure mode entirely, see below.

## Related but separate: pastes landing in WSL instead of Spark

If a pasted image path renders as dead text in a Spark-side agent chat, the
upload was routed to `local` (laptop WSL) — same path string, wrong machine.
Cause: laptop shell prompts stamp the pane's `FHH_IMAGE_PASTE_HOST` user var,
and historically stamped `local`, overriding the helper default. Fixed
2026-06-12: `shell/common.sh` stamps `spark` from every machine (override with
`CODEX_IMAGE_PASTE_HOST`), and `wezterm.lua` passes `default_host = 'spark'`.

⚠️ Both laptop-side copies are standalone (no symlink across the WSL/Windows
boundary): sync `wezterm/.config/wezterm/*` with `bin/sync-wezterm-to-windows`
and the WSL dotfiles checkout via git/scp. The running WezTerm instance does
NOT reliably auto-reload — fully quit and relaunch after any config change.

## Remote diagnosis toolkit (Spark → laptop)

- `ssh desktop-t9m5u7n` works; SSH lands in a *non-interactive* session — GUI
  inspection (window rects, screen pixels, clipboard) must run via a scheduled
  task with `-LogonType Interactive`, `-AllowStartIfOnBatteries` (default task
  conditions silently queue on battery), and `-WindowStyle Hidden` (the task's
  own console window otherwise pollutes captures).
- `fos:platform/shortcuts/windows/fos-capture-probe.ps1` + `fos-capture-probe-task.ps1`:
  scene report (monitors, WezTerm windows, foreground app), GDI window capture
  with average-colour readout, clipboard image readback (`fos-probe-clip.flag`),
  clipboard clear (`fos-probe-clearclip.flag`), focus-WezTerm (`fos-probe-focus.flag`).
- Controlled content: drive the user-visible tmux session from Spark
  (`tmux select-pane -P 'bg=#cc0000'` in a scratch window) and verify what a
  real user snip captured by reading the clipboard back. Clear the clipboard
  first or an older snip masquerades as the result.
