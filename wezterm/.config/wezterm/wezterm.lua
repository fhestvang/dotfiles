local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Win+Shift+S stale-frame bug: fixed at the OS level (DisableOverlays=1 in
-- GraphicsDrivers, 2026-06-12) — see docs/wezterm-screenshot-wrong-pane.md.
-- front_end='Software' and window_background_opacity=0.99 were both tested
-- live and did NOT affect it; don't bring them back for that reason.
-- NOTE: this config does not reliably auto-reload — fully quit and relaunch
-- WezTerm after editing, and sync the laptop copy (bin/sync-wezterm-to-windows).
config.color_scheme = 'Catppuccin Mocha'
-- Mocha ships ANSI bright-black as #585b70 (surface2), which TUIs (Claude Code
-- menus, fzf, etc.) use for dim/secondary text — unreadable on the #1e1e2e bg.
-- Lift just that slot to overlay1; the other seven match the stock scheme.
config.colors = {
  brights = {
    '#7f849c', -- bright black: overlay1 instead of surface2
    '#f38ba8',
    '#a6e3a1',
    '#f9e2af',
    '#89b4fa',
    '#f5c2e7',
    '#94e2d5',
    '#a6adc8',
  },
  -- Fancy tab bar still draws a rounded tab "pill" at the top-left even with the
  -- label blanked (format-tab-title). Its default bg is a darker scheme shade, so
  -- the pill shows as a small rounded rectangle. Paint every tab slot the titlebar
  -- bg so the pill is invisible; the integrated min/max/close buttons are unaffected.
  tab_bar = {
    background = '#1e1e2e',
    active_tab = { bg_color = '#1e1e2e', fg_color = '#1e1e2e' },
    inactive_tab = { bg_color = '#1e1e2e', fg_color = '#1e1e2e' },
    inactive_tab_hover = { bg_color = '#1e1e2e', fg_color = '#1e1e2e' },
    new_tab = { bg_color = '#1e1e2e', fg_color = '#1e1e2e' },
    new_tab_hover = { bg_color = '#1e1e2e', fg_color = '#1e1e2e' },
  },
}

local wsl_distro = 'Ubuntu'

local shell_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; exec "$shell" -l'
local tmux_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; if command -v tmux >/dev/null 2>&1; then base="${FHH_TMUX_BASE:-main}"; tmux -2 new-session -A -s "$base"; fi; exec "$shell" -l'
local spark_context_prefix = "printf '\\033]1337;SetUserVar=FHH_HOST=c3Bhcms=\\a'; printf '\\033]1337;SetUserVar=FHH_IMAGE_PASTE_HOST=c3Bhcms=\\a'; "
-- Tag local laptop panes so CTRL+V image paste saves into WSL here instead of
-- falling through to default_host='spark'. base64: bG9jYWw= = 'local'. Without
-- this, pasting in a local Claude session writes the screenshot to spark and the
-- path typed into the terminal dangles. Spark panes set the spark marker above;
-- the untagged 'WezTerm Spark' desktop shortcut still relies on default_host.
local local_context_prefix = "printf '\\033]1337;SetUserVar=FHH_HOST=bG9jYWw=\\a'; printf '\\033]1337;SetUserVar=FHH_IMAGE_PASTE_HOST=bG9jYWw=\\a'; "

local function wsl_command_args(...)
  return {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--cd',
    '~',
    '--',
    ...,
  }
end

local function wsl_bash_args(command)
  return wsl_command_args(
    'bash',
    '-lc',
    command
  )
end

local function spark_args(command)
  return {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--cd',
    '~',
    '--',
    'ssh',
    '-t',
    'spark',
    spark_context_prefix .. command,
  }
end

-- Title bar: draw WezTerm's own bar instead of the native Windows one. The
-- native bar ('TITLE') is painted white by Windows in light mode and ignores
-- window_frame colours, which is why the top bar showed up white. With
-- INTEGRATED_BUTTONS WezTerm renders the bar itself (min/max/close folded into
-- the tab bar) and honours window_frame's #1e1e2e below, so the bar matches the
-- terminal background. The fancy tab bar must be on for the integrated bar to
-- render, and it must not auto-hide on a single tab, or the bar (and its
-- buttons) would disappear under tmux's always-single tab.
config.hide_tab_bar_if_only_one_tab = false
config.use_fancy_tab_bar = true
config.window_decorations = 'INTEGRATED_BUTTONS | RESIZE'
config.window_frame = {
  active_titlebar_bg = '#1e1e2e',
  inactive_titlebar_bg = '#1e1e2e',
  active_titlebar_fg = '#cdd6f4',
  inactive_titlebar_fg = '#cdd6f4',
  button_bg = '#1e1e2e',
  button_fg = '#cdd6f4',
}
-- Keep the integrated bar (so min/max/close survive) but blank the tab label.
-- The left side normally shows the running program ('wslhost.exe', tmux, etc.);
-- returning an empty title painted in the titlebar bg leaves only the buttons.
wezterm.on('format-tab-title', function()
  return {
    { Background = { Color = '#1e1e2e' } },
    { Text = '' },
  }
end)
config.show_new_tab_button_in_tab_bar = false
-- Removes the fancy tab bar's per-tab close 'x'. Only exists in newer/nightly
-- WezTerm (post-20240203); on the stable build this key is unknown and a bare
-- assignment would fail the WHOLE config, so guard it with pcall — it's a no-op
-- on stable and takes effect once WezTerm is upgraded.
pcall(function()
  config.show_close_tab_button_in_tabs = false
end)
config.window_padding = {
  left = '4px',
  right = '4px',
  top = '4px',
  -- Lift the tmux status line a few px off the very bottom edge. With
  -- window_content_alignment vertical=Bottom the grid bottom-aligns to the top of
  -- this padding, so the gap below the bar stays a clean constant strip.
  bottom = '6px',
}
-- When the window height is not an exact multiple of cell height, WezTerm has
-- leftover pixels outside the terminal grid. Keep the grid bottom-aligned so
-- the tmux status line sits flush against the bottom edge instead of leaving a
-- visible strip under INSERT/main.
-- window_content_alignment only exists in newer WezTerm releases; on the
-- installed version a bare assignment makes the WHOLE config fail to load
-- (default config, no image-paste keybindings), so probe it with pcall.
pcall(function()
  config.window_content_alignment = {
    horizontal = 'Left',
    vertical = 'Bottom',
  }
end)
config.font_size = 11.5
config.line_height = 0.9
config.default_cursor_style = 'SteadyBlock'
config.cursor_blink_rate = 2000000000
config.text_blink_rate = 0
config.text_blink_rate_rapid = 0

config.command_palette_bg_color = '#11111b'
config.command_palette_fg_color = '#cdd6f4'
config.command_palette_font_size = 12.0
config.command_palette_rows = 12

config.default_prog = wsl_bash_args(local_context_prefix .. 'exec zsh -l')

config.launch_menu = {
  {
    label = 'Laptop shell',
    args = wsl_bash_args(local_context_prefix .. 'exec zsh -l'),
  },
  {
    label = 'Spark shell',
    args = spark_args(shell_command),
  },
  {
    label = 'Laptop tmux',
    args = wsl_bash_args(local_context_prefix .. tmux_command),
  },
  {
    label = 'Spark tmux',
    args = spark_args(tmux_command),
  },
  {
    label = 'PowerShell',
    args = { 'powershell.exe', '-NoLogo' },
  },
}

package.path = package.path .. ';' .. wezterm.config_dir .. '/?.lua'
local remote_image_paste = require 'remote-image-paste'
config.keys = config.keys or {}
-- default_host: spark panes carry FHH_IMAGE_PASTE_HOST=spark and local panes carry
-- =local (set via the launch prefixes). A WezTerm restart drops the per-pane var,
-- leaving orphaned panes untagged. On this laptop, default those to 'local' so
-- pasted screenshots land in WSL here; explicitly-tagged spark panes still upload
-- to spark.
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'local',
  key = 'v',
  mods = 'CTRL',
})
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'local',
  key = 'v',
  mods = 'CTRL|SHIFT',
})
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'local',
  key = 'v',
  mods = 'CTRL|ALT',
})

return config
