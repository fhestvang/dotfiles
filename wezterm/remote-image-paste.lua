local wezterm = require 'wezterm'
local act = wezterm.action

local M = {}

local function build_command(opts)
  local host = opts.host or os.getenv 'CODEX_IMAGE_PASTE_HOST' or 'spark'
  local remote_dir = opts.remote_dir or os.getenv 'CODEX_IMAGE_PASTE_REMOTE_DIR'
  local configured = opts.command or os.getenv 'CODEX_IMAGE_PASTE_COMMAND'

  if configured then
    local command = { configured, '--host', host }
    if remote_dir and remote_dir ~= '' then
      table.insert(command, '--remote-dir')
      table.insert(command, remote_dir)
    end
    return command
  end

  local triple = wezterm.target_triple or ''
  if triple:find 'windows' then
    local script = opts.windows_script
      or os.getenv 'CODEX_IMAGE_PASTE_WINDOWS_SCRIPT'
      or (wezterm.config_dir .. '\\codex-image-paste.ps1')
    local command = {
      'powershell.exe',
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-STA',
      '-File',
      script,
      '-HostName',
      host,
    }
    if remote_dir and remote_dir ~= '' then
      table.insert(command, '-RemoteDir')
      table.insert(command, remote_dir)
    end
    return command
  end

  local script = (wezterm.home_dir or os.getenv 'HOME' or '')
    .. '/github/dotfiles/bin/remote-image-paste'
  local command = { script, '--host', host }
  if remote_dir and remote_dir ~= '' then
    table.insert(command, '--remote-dir')
    table.insert(command, remote_dir)
  end
  return command
end

function M.action(opts)
  opts = opts or {}
  return wezterm.action_callback(function(window, pane)
    local ok, stdout, stderr = wezterm.run_child_process(build_command(opts))

    if ok and stdout then
      local path = stdout:gsub('%s+$', '')
      if path ~= '' then
        pane:send_paste(path .. ' ')
        window:toast_notification('Remote image paste', path, nil, 3000)
        return
      end
    end

    local has_stderr = stderr and stderr:gsub('%s+', '') ~= ''
    if ok and not has_stderr then
      window:perform_action(act.PasteFrom 'Clipboard', pane)
      return
    end

    local message = 'image paste helper failed'
    if has_stderr then
      message = stderr:gsub('%s+$', '')
    end
    window:toast_notification('Remote image paste failed', message, nil, 6000)
    window:perform_action(act.PasteFrom 'Clipboard', pane)
  end)
end

function M.apply(config, opts)
  opts = opts or {}
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = opts.key or 'v',
    mods = opts.mods or 'CTRL',
    action = M.action(opts),
  })
end

return M
