# Build helper binaries. Windows host builds the x64 exe locally.
# macOS and Linux artifacts are produced on those hosts (or via cross).
# Intel Mac: MACOSX_DEPLOYMENT_TARGET=11.7 — do not raise that floor.
param(
    [ValidateSet('windows', 'linux', 'macos-arm64', 'macos-x64', 'all-local')]
    [string]$Target = 'windows'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Helper = Join-Path $Root 'helper'
$Dist = Join-Path $Helper 'dist'
New-Item -ItemType Directory -Path $Dist -Force | Out-Null

. (Join-Path $Root 'scripts\version-lib.ps1')
$label = Get-BuildLabel

Push-Location $Helper
try {
    switch ($Target) {
        'windows' {
            cargo build --release
            if ($LASTEXITCODE -ne 0) { throw 'cargo build failed' }
            $exe = Join-Path $Helper 'target/release/remote-keyboard-helper.exe'
            Copy-Item $exe (Join-Path $Dist "remotekeyboard-windows-x64-$label.exe") -Force
        }
        'linux' {
            cargo build --release --target x86_64-unknown-linux-gnu
            if ($LASTEXITCODE -ne 0) { throw 'linux cargo build failed' }
            $bin = Join-Path $Helper 'target/x86_64-unknown-linux-gnu/release/remote-keyboard-helper'
            Copy-Item $bin (Join-Path $Dist "remotekeyboard-linux-x64-$label") -Force
        }
        'macos-arm64' {
            $env:MACOSX_DEPLOYMENT_TARGET = '11.7'
            cargo build --release --target aarch64-apple-darwin
            if ($LASTEXITCODE -ne 0) { throw 'macos-arm64 cargo build failed' }
            $bin = Join-Path $Helper 'target/aarch64-apple-darwin/release/remote-keyboard-helper'
            Copy-Item $bin (Join-Path $Dist "remotekeyboard-macos-arm64-$label") -Force
        }
        'macos-x64' {
            $env:MACOSX_DEPLOYMENT_TARGET = '11.7'
            cargo build --release --target x86_64-apple-darwin
            if ($LASTEXITCODE -ne 0) { throw 'macos-x64 cargo build failed' }
            $bin = Join-Path $Helper 'target/x86_64-apple-darwin/release/remote-keyboard-helper'
            Copy-Item $bin (Join-Path $Dist "remotekeyboard-macos-x64-$label") -Force
        }
        'all-local' {
            cargo build --release
        }
    }
} finally {
    Pop-Location
}

Write-Host "Helper artifacts in $Dist"
