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
}

local wsl_distro = 'Ubuntu'

local shell_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; exec "$shell" -l'
local tmux_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; if command -v tmux >/dev/null 2>&1; then base="${FHH_TMUX_BASE:-main}"; tmux -2 new-session -A -s "$base"; fi; exec "$shell" -l'
local spark_context_prefix = "printf '\\033]1337;SetUserVar=FHH_HOST=c3Bhcms=\\a'; printf '\\033]1337;SetUserVar=FHH_IMAGE_PASTE_HOST=c3Bhcms=\\a'; "

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

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_decorations = 'TITLE | RESIZE'
config.window_frame = {
  active_titlebar_bg = '#1e1e2e',
  inactive_titlebar_bg = '#1e1e2e',
  active_titlebar_fg = '#cdd6f4',
  inactive_titlebar_fg = '#cdd6f4',
  button_bg = '#1e1e2e',
  button_fg = '#cdd6f4',
}
config.window_padding = {
  left = '4px',
  right = '4px',
  top = '4px',
  bottom = 0,
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

config.default_prog = wsl_command_args('zsh', '-l')

config.launch_menu = {
  {
    label = 'Laptop shell',
    args = wsl_command_args('zsh', '-l'),
  },
  {
    label = 'Spark shell',
    args = spark_args(shell_command),
  },
  {
    label = 'Laptop tmux',
    args = wsl_bash_args(tmux_command),
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
-- default_host: panes only carry FHH_IMAGE_PASTE_HOST when opened through the
-- spark launch item, and a WezTerm restart drops it. Without a default the
-- helper falls back to 'local' and silently saves into WSL at the same path
-- string Spark would use, so pasted paths dangle. Agents live on spark.
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'spark',
  key = 'v',
  mods = 'CTRL',
})
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'spark',
  key = 'v',
  mods = 'CTRL|SHIFT',
})
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  default_host = 'spark',
  key = 'v',
  mods = 'CTRL|ALT',
})

return config
