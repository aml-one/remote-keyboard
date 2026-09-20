# Sync the helper crate to Nova and build macOS arm64 + Intel (Big Sur 11.7).
[CmdletBinding()]
param(
    [string]$Nova = 'ambrus@192.168.31.230'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'version-lib.ps1')
$label = Get-BuildLabel
$Helper = Join-Path $RepoRoot 'helper'
$Dist = Join-Path $Helper 'dist'
$RemoteHelper = '/Users/ambrus/src/remote-keyboard/helper'
New-Item -ItemType Directory -Path $Dist -Force | Out-Null

function Convert-ToScpPath([string]$WindowsPath) {
    $full = [System.IO.Path]::GetFullPath($WindowsPath).Replace('\', '/')
    if ($full -match '^(?i)([A-Z]):/(.*)$') {
        return "/$($Matches[1].ToLower())/$($Matches[2])"
    }
    return $full
}

$ssh = Join-Path $env:WINDIR 'System32/OpenSSH/ssh.exe'
$scp = Join-Path $env:WINDIR 'System32/OpenSSH/scp.exe'
if (-not (Test-Path $ssh)) { $ssh = 'ssh' }
if (-not (Test-Path $scp)) { $scp = 'scp' }

$archive = Join-Path $env:TEMP 'remote-keyboard-helper-nova.tgz'
$wslHelper = ((wsl.exe -d Ubuntu wslpath -a ($Helper -replace '\\', '/')) -replace "`0", '').Trim()
$wslArchive = ((wsl.exe -d Ubuntu wslpath -a ($archive -replace '\\', '/')) -replace "`0", '').Trim()
if (-not $wslHelper -or -not $wslArchive) { throw 'WSL path conversion failed for the helper archive.' }

Write-Host "==> Sync helper crate to Nova" -ForegroundColor Cyan
$pack = @"
set -euo pipefail
cd '$wslHelper'
tar -czf '$wslArchive' --exclude=target --exclude=dist --exclude=.git .
"@
$pack = ($pack -replace "`r`n", "`n").Trim()
& wsl.exe -d Ubuntu -- bash -lc $pack
if ($LASTEXITCODE -ne 0) { throw 'Could not package the helper crate.' }

& $ssh $Nova "mkdir -p '$RemoteHelper'"
& $scp $archive "${Nova}:/tmp/remote-keyboard-helper.tgz"
if ($LASTEXITCODE -ne 0) { throw 'Helper upload to Nova failed.' }
& $ssh $Nova "rm -rf '$RemoteHelper' && mkdir -p '$RemoteHelper' && tar -xzf /tmp/remote-keyboard-helper.tgz -C '$RemoteHelper'"
if ($LASTEXITCODE -ne 0) { throw 'Nova extract failed.' }

Write-Host "==> Build macOS arm64 + Intel helpers on Nova" -ForegroundColor Cyan
$remote = @'
set -euo pipefail
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v cargo >/dev/null; then
  curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
  . "$HOME/.cargo/env"
fi
. "$HOME/.cargo/env"
export MACOSX_DEPLOYMENT_TARGET=11.7
cd /Users/ambrus/src/remote-keyboard/helper
rustup target add aarch64-apple-darwin x86_64-apple-darwin
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
'@
$remote = $remote -replace "`r`n", "`n"
$remoteFile = Join-Path $env:TEMP 'remote-keyboard-helper-nova-build.sh'
[System.IO.File]::WriteAllText($remoteFile, $remote, [System.Text.UTF8Encoding]::new($false))
& $scp $remoteFile "${Nova}:/tmp/remote-keyboard-helper-build.sh"
if ($LASTEXITCODE -ne 0) { throw 'Could not upload Nova build script.' }
& $ssh $Nova "bash /tmp/remote-keyboard-helper-build.sh"
if ($LASTEXITCODE -ne 0) { throw "Nova helper build failed ($LASTEXITCODE)" }

& $scp "${Nova}:${RemoteHelper}/target/aarch64-apple-darwin/release/remote-keyboard-helper" (Join-Path $Dist "remotekeyboard-macos-arm64-$label")
if ($LASTEXITCODE -ne 0) { throw 'scp macOS arm64 helper failed' }
& $scp "${Nova}:${RemoteHelper}/target/x86_64-apple-darwin/release/remote-keyboard-helper" (Join-Path $Dist "remotekeyboard-macos-x64-$label")
if ($LASTEXITCODE -ne 0) { throw 'scp macOS Intel helper failed' }

Write-Host "macOS helpers remotekeyboard-macos-arm64-$label and remotekeyboard-macos-x64-$label"
