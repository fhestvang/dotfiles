local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local wsl_distro = 'Ubuntu'

local shell_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; exec "$shell" -l'
local tmux_command = 'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"; shell="$(command -v zsh 2>/dev/null || command -v bash 2>/dev/null || printf /bin/sh)"; export SHELL="$shell"; if command -v tmux >/dev/null 2>&1; then base="${FHH_TMUX_BASE:-main}"; tty_name="$(tty 2>/dev/null || printf client-$$)"; tty_name="${tty_name#/dev/}"; tty_name="$(printf "%s" "$tty_name" | tr -c "[:alnum:]_.-" "-")"; [ -n "$tty_name" ] || tty_name="client-$$"; session_name="$base-$tty_name"; tmux has-session -t "$base" 2>/dev/null || tmux new-session -d -s "$base"; tmux has-session -t "$session_name" 2>/dev/null || tmux new-session -d -t "$base" -s "$session_name"; exec tmux -2 attach-session -t "$session_name"; fi; exec "$shell" -l'
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
config.font_size = 11.5
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
table.insert(config.keys, {
  key = 'v',
  mods = 'CTRL',
  action = wezterm.action.PasteFrom 'Clipboard',
})
table.insert(config.keys, {
  key = 'v',
  mods = 'CTRL|SHIFT',
  action = wezterm.action.PasteFrom 'Clipboard',
})
remote_image_paste.apply(config, {
  wsl_distro = wsl_distro,
  key = 'v',
  mods = 'CTRL|ALT',
})

return config
