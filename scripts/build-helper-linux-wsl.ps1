# Build the Linux x64 helper in WSL Ubuntu.
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'version-lib.ps1')
$label = Get-BuildLabel
$Helper = Join-Path $RepoRoot 'helper'
$Dist = Join-Path $Helper 'dist'
New-Item -ItemType Directory -Path $Dist -Force | Out-Null

function Get-WslLinuxDistro {
    $raw = (wsl.exe -l -q 2>&1 | Out-String) -replace "`0", ''
    if ($LASTEXITCODE -ne 0 -and [string]::IsNullOrWhiteSpace($raw)) {
        throw 'WSL is not available. Install WSL + Ubuntu to build the Linux helper.'
    }
    $distros = @()
    foreach ($line in ($raw -split "`r?`n")) {
        $name = $line.Trim()
        if (-not $name) { continue }
        if ($name -match 'docker-desktop|podman') { continue }
        $distros += $name
    }
    foreach ($preferred in @('Ubuntu', 'Ubuntu-24.04', 'Ubuntu-22.04', 'Debian')) {
        $hit = $distros | Where-Object { $_ -eq $preferred } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    if ($distros.Count -gt 0) { return $distros[0] }
    throw 'No usable WSL Linux distro found.'
}

function Convert-ToWslPath([string]$WindowsPath) {
    $full = [System.IO.Path]::GetFullPath($WindowsPath).Replace('\', '/')
    if ($full -match '^(?i)([A-Z]):/(.*)$') {
        return "/mnt/$($Matches[1].ToLower())/$($Matches[2])"
    }
    throw "Cannot map $WindowsPath to WSL"
}

$distro = Get-WslLinuxDistro
$helperWsl = Convert-ToWslPath $Helper
$destWsl = Convert-ToWslPath (Join-Path $Dist "remotekeyboard-linux-x64-$label")
$cmd = @"
set -euo pipefail
export PATH=`"`$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin`"
if ! command -v cargo >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
fi
. `"`$HOME/.cargo/env`"
# Use `$HOME` in paths (Windows has it). Other `$VARS` are emptied by wsl.exe.
export CARGO_TARGET_DIR=`"`$HOME/src/remote-keyboard-helper-target`"
cd '$helperWsl'
cargo build --release
cp -f "`$HOME/src/remote-keyboard-helper-target/release/remote-keyboard-helper" '$destWsl'
"@
$cmd = ($cmd -replace "`r`n", "`n").Trim()
Write-Host "Building Linux helper via WSL ($distro)..." -ForegroundColor Cyan
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$wslOut = & wsl.exe -d $distro -- bash -lc $cmd 2>&1
$wslExit = $LASTEXITCODE
$ErrorActionPreference = $prevEap
foreach ($line in $wslOut) { Write-Host ($line | Out-String).TrimEnd() }
if ($wslExit -ne 0) { throw "Linux helper build failed in WSL ($wslExit)." }

$built = Join-Path $Dist "remotekeyboard-linux-x64-$label"
if (-not (Test-Path -LiteralPath $built)) {
    throw "WSL cargo did not write $built"
}
Write-Host "Linux helper remotekeyboard-linux-x64-$label"
