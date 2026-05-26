local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local wsl_distro = 'Ubuntu'

local shell_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; exec "$shell" -l'
local tmux_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; if command -v tmux >/dev/null 2>&1; then exec tmux new-session -A -s main; fi; exec "$shell" -l'

local function wsl_args(command)
  return {
    'wsl.exe',
    '-d',
    wsl_distro,
    '--cd',
    '~',
    '--',
    'bash',
    '-lc',
    command,
  }
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
    command,
  }
end

config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_decorations = 'TITLE | RESIZE'
config.font_size = 11.5
config.default_cursor_style = 'SteadyBlock'
config.cursor_blink_rate = 0
config.text_blink_rate = 0
config.text_blink_rate_rapid = 0

config.default_prog = wsl_args(tmux_command)

config.launch_menu = {
  {
    label = 'Laptop tmux',
    args = wsl_args(tmux_command),
  },
  {
    label = 'Laptop shell',
    args = wsl_args(shell_command),
  },
  {
    label = 'Spark tmux',
    args = spark_args(tmux_command),
  },
  {
    label = 'Spark shell',
    args = spark_args(shell_command),
  },
  {
    label = 'PowerShell',
    args = { 'powershell.exe', '-NoLogo' },
  },
}

package.path = package.path .. ';' .. wezterm.config_dir .. '/?.lua'
local remote_image_paste = require 'remote-image-paste'
remote_image_paste.apply(config, {
  host = 'spark',
  key = 'v',
  mods = 'CTRL',
})
remote_image_paste.apply(config, {
  host = 'spark',
  key = 'v',
  mods = 'CTRL|SHIFT',
})

return config
