[CmdletBinding()]
param(
  [string]$HostName = $(if ($env:CODEX_IMAGE_PASTE_HOST) { $env:CODEX_IMAGE_PASTE_HOST } else { "spark" }),
  [string]$RemoteDir = $(if ($env:CODEX_IMAGE_PASTE_REMOTE_DIR) { $env:CODEX_IMAGE_PASTE_REMOTE_DIR } else { "/home/fhestvang/.cache/codex-clipboard-images" }),
  [string]$WslDistro = $(if ($env:CODEX_IMAGE_PASTE_WSL_DISTRO) { $env:CODEX_IMAGE_PASTE_WSL_DISTRO } else { "Ubuntu" }),
  [string]$File,
  [switch]$AllowRepeat
)

$ErrorActionPreference = "Stop"

# wezterm launches this helper with the pane's working directory, which under WSL is
# a \\wsl.localhost\... UNC path. PowerShell then resolves absolute UNC destinations
# (Copy-Item to \\wsl.localhost\Ubuntu\...) RELATIVE to that UNC location and mangles
# them, so the copy silently lands at a phantom path. Anchor to a Windows drive so
# UNC paths stay absolute.
Set-Location -LiteralPath ([System.IO.Path]::GetTempPath())

function Write-Failure {
  param([string]$Message)
  [Console]::Error.WriteLine($Message)
  exit 1
}

function Get-Tool {
  param([string]$Name)
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Failure "$Name was not found on PATH"
  }
  $cmd.Source
}

function New-TempPngPath {
  $name = "codex-clipboard-{0}.png" -f ([Guid]::NewGuid().ToString("N"))
  Join-Path ([IO.Path]::GetTempPath()) $name
}

function Get-StateDir {
  $root = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [IO.Path]::GetTempPath() }
  $path = Join-Path $root "fhh\codex-image-paste"
  New-Item -ItemType Directory -Path $path -Force | Out-Null
  $path
}

function Get-ClipboardSequenceNumber {
  if (-not ("FhhClipboardNative" -as [type])) {
    Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class FhhClipboardNative {
  [DllImport("user32.dll")]
  public static extern uint GetClipboardSequenceNumber();
}
"@
  }
  [FhhClipboardNative]::GetClipboardSequenceNumber()
}

function Get-LastClipboardSequencePath {
  Join-Path (Get-StateDir) "last-clipboard-sequence.txt"
}

function Get-LastClipboardSequence {
  $path = Get-LastClipboardSequencePath
  if (Test-Path -LiteralPath $path) {
    return (Get-Content -LiteralPath $path -Raw).Trim()
  }
  $null
}

function Set-LastClipboardSequence {
  param([string]$Sequence)
  Set-Content -LiteralPath (Get-LastClipboardSequencePath) -Value $Sequence -NoNewline
}

function Get-LastImageHashPath {
  Join-Path (Get-StateDir) "last-image.sha256"
}

function Get-LastImageHash {
  $path = Get-LastImageHashPath
  if (Test-Path -LiteralPath $path) {
    return (Get-Content -LiteralPath $path -Raw).Trim().ToLowerInvariant()
  }
  $null
}

function Set-LastImageHash {
  param([string]$Hash)
  Set-Content -LiteralPath (Get-LastImageHashPath) -Value $Hash -NoNewline
}

function Get-FileSha256 {
  param([string]$Path)
  (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Save-ClipboardImageAsPng {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $allowRepeat = $AllowRepeat -or $env:CODEX_IMAGE_PASTE_ALLOW_REPEAT -eq "1"
  $lastSequence = if ($allowRepeat) { $null } else { Get-LastClipboardSequence }
  $lastImageHash = if ($allowRepeat) { $null } else { Get-LastImageHash }
  $lastError = $null

  for ($freshAttempt = 0; $freshAttempt -lt 10; $freshAttempt++) {
    $sequence = Get-ClipboardSequenceNumber
    if ($lastSequence -and "$sequence" -eq "$lastSequence") {
      if ($freshAttempt -eq 9) {
        Write-Failure "clipboard has not changed since the last image paste; take a fresh screenshot and retry"
      }
      Start-Sleep -Milliseconds 150
      continue
    }

    $image = $null
    for ($attempt = 0; $attempt -lt 6; $attempt++) {
      try {
        $image = [System.Windows.Forms.Clipboard]::GetImage()
        break
      } catch {
        $lastError = $_.Exception.Message
        if ($attempt -eq 5) {
          Write-Failure "failed to read Windows clipboard image: $lastError"
        }
        Start-Sleep -Milliseconds 50
      }
    }

    if ($null -eq $image) {
      exit 0
    }

    $path = New-TempPngPath
    try {
      $image.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $image.Dispose()
    }

    $imageHash = Get-FileSha256 $path
    if ($lastImageHash -and $imageHash -eq $lastImageHash) {
      Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
      if ($freshAttempt -eq 9) {
        Write-Failure "clipboard image matches the last pasted screenshot; take a fresh screenshot and retry"
      }
      Start-Sleep -Milliseconds 150
      continue
    }

    Set-LastClipboardSequence "$sequence"
    Set-LastImageHash "$imageHash"
    return $path
  }
}

function Save-FileAsPng {
  param([string]$Path)

  Add-Type -AssemblyName System.Drawing
  $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
  $image = [System.Drawing.Image]::FromFile($resolved)
  $out = New-TempPngPath
  try {
    $image.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $image.Dispose()
  }
  $out
}

function Assert-SafeRemotePath {
  param([string]$Path)
  if ($Path -notmatch "^[A-Za-z0-9._~/-]+$") {
    Write-Failure "remote path contains unsupported characters: $Path"
  }
}

function Test-LocalTarget {
  param([string]$Name)
  $lower = $Name.ToLowerInvariant()
  if ($lower -in @("local", "localhost", "127.0.0.1", "::1", "laptop")) {
    return $true
  }
  if ($env:COMPUTERNAME -and $lower -eq $env:COMPUTERNAME.ToLowerInvariant()) {
    return $true
  }
  return $false
}

function Invoke-Wsl {
  param([string]$Command)
  $wsl = Get-Tool "wsl.exe"
  & $wsl "-d" $WslDistro "--" "bash" "-lc" $Command
  if ($LASTEXITCODE -ne 0) {
    Write-Failure "wsl command failed for distro $WslDistro"
  }
}

function Get-WslHome {
  $wsl = Get-Tool "wsl.exe"
  $home = (& $wsl "-d" $WslDistro "--" "bash" "-lc" 'printf %s "$HOME"') -join ""
  if ($LASTEXITCODE -ne 0 -or -not $home) {
    Write-Failure "could not resolve WSL home for distro $WslDistro"
  }
  $home
}

function Resolve-WslPath {
  param([string]$Path)
  if ($Path.StartsWith("/")) {
    return $Path.TrimEnd("/")
  }
  if ($Path.StartsWith("~/")) {
    return "$(Get-WslHome)/$($Path.Substring(2))"
  }
  "$(Get-WslHome)/$Path"
}

function Convert-WslPathToUnc {
  param([string]$LinuxPath)
  $relative = $LinuxPath.TrimStart("/") -replace "/", "\"
  $roots = @("\\wsl.localhost\$WslDistro", "\\wsl$\$WslDistro")
  foreach ($root in $roots) {
    if (Test-Path -LiteralPath $root) {
      return "$root\$relative"
    }
  }
  "$($roots[0])\$relative"
}

$sshOptions = @("-o", "BatchMode=yes", "-o", "ClearAllForwardings=yes", "-o", "ConnectTimeout=4")
$tempFile = $null

try {
  if ($File) {
    $tempFile = Save-FileAsPng -Path $File
  } else {
    $tempFile = Save-ClipboardImageAsPng
  }

  if (-not $tempFile -or -not (Test-Path -LiteralPath $tempFile)) {
    exit 0
  }

  if (Test-LocalTarget $HostName) {
    $remoteDirAbs = Resolve-WslPath $RemoteDir
  } elseif ($RemoteDir.StartsWith("/")) {
    $remoteDirAbs = $RemoteDir.TrimEnd("/")
  } else {
    Write-Failure "RemoteDir must be absolute; got $RemoteDir"
  }

  Assert-SafeRemotePath $remoteDirAbs
  $remoteName = "clip-{0}-{1}.png" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $PID
  $remotePath = "$remoteDirAbs/$remoteName"
  Assert-SafeRemotePath $remotePath

  if (Test-LocalTarget $HostName) {
    Invoke-Wsl "mkdir -p '$remoteDirAbs' && chmod 700 '$remoteDirAbs'"
    $uncDir = Convert-WslPathToUnc $remoteDirAbs
    $uncPath = Convert-WslPathToUnc $remotePath
    if (-not (Test-Path -LiteralPath $uncDir)) {
      New-Item -ItemType Directory -Path $uncDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $tempFile -Destination $uncPath -Force
    [Console]::Out.WriteLine($remotePath)
    exit 0
  }

  $ssh = Get-Tool "ssh.exe"
  $scp = Get-Tool "scp.exe"

  & $ssh @sshOptions $HostName "mkdir -p $remoteDirAbs && chmod 700 $remoteDirAbs"
  if ($LASTEXITCODE -ne 0) {
    Write-Failure "failed to create remote staging directory: $remoteDirAbs"
  }

  & $scp @sshOptions -q -- $tempFile "${HostName}:$remotePath"
  if ($LASTEXITCODE -ne 0) {
    Write-Failure "failed to upload image to $HostName"
  }

  [Console]::Out.WriteLine($remotePath)
} finally {
  if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
  }
}
