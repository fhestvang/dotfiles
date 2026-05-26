[CmdletBinding()]
param(
  [string]$HostName = $(if ($env:CODEX_IMAGE_PASTE_HOST) { $env:CODEX_IMAGE_PASTE_HOST } else { "spark" }),
  [string]$RemoteDir = $(if ($env:CODEX_IMAGE_PASTE_REMOTE_DIR) { $env:CODEX_IMAGE_PASTE_REMOTE_DIR } else { "/home/fhestvang/.cache/codex-clipboard-images" }),
  [string]$File
)

$ErrorActionPreference = "Stop"

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

function Save-ClipboardImageAsPng {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing

  $image = $null
  for ($attempt = 0; $attempt -lt 6; $attempt++) {
    try {
      $image = [System.Windows.Forms.Clipboard]::GetImage()
      break
    } catch {
      if ($attempt -eq 5) {
        # No image-like clipboard content. Exit silently so WezTerm can fall back to text paste.
        exit 0
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
  $path
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

$ssh = Get-Tool "ssh.exe"
$scp = Get-Tool "scp.exe"
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

  if ($RemoteDir.StartsWith("/")) {
    $remoteDirAbs = $RemoteDir.TrimEnd("/")
  } elseif ($RemoteDir.StartsWith("~/")) {
    Write-Failure "RemoteDir must be absolute; got $RemoteDir"
  } else {
    Write-Failure "RemoteDir must be absolute; got $RemoteDir"
  }

  Assert-SafeRemotePath $remoteDirAbs
  $remoteName = "clip-{0}-{1}.png" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $PID
  $remotePath = "$remoteDirAbs/$remoteName"
  Assert-SafeRemotePath $remotePath

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
