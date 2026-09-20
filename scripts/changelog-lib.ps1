# Release notes, one file per version: changelog/changelog-v<semver>
#
# Dot-source it:  . scripts/changelog-lib.ps1

if (-not $script:RepoRoot) {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
}
$script:ChangelogDir = Join-Path $script:RepoRoot 'changelog'

function Get-ChangelogPath {
    param([Parameter(Mandatory)][string]$SemVer)
    if ($SemVer -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semver: $SemVer"
    }
    return Join-Path $script:ChangelogDir "changelog-v$SemVer"
}

function Get-ActiveChangelogPath {
    if (-not (Get-Command Get-NextProjectVersion -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'version-lib.ps1')
    }
    return Get-ChangelogPath -SemVer (Get-NextProjectVersion)
}

function Read-ChangelogEntries {
    param([Parameter(Mandatory)][string]$SemVer)

    $path = Get-ChangelogPath -SemVer $SemVer
    if (-not (Test-Path -LiteralPath $path)) { return @() }

    $features = @()
    $improvements = @()
    $bugfixes = @()

    foreach ($line in Get-Content -LiteralPath $path -Encoding UTF8) {
        if ($line.Trim() -match '^\[(feature|bugfix|improvement)\]\s+(.+)$') {
            $entry = "[$($Matches[1])] $($Matches[2])"
            switch ($Matches[1]) {
                'feature' { $features += $entry }
                'improvement' { $improvements += $entry }
                'bugfix' { $bugfixes += $entry }
            }
        }
    }

    return @($features + $improvements + $bugfixes)
}

function New-ChangelogStub {
    param([Parameter(Mandatory)][string]$SemVer)

    if (-not (Test-Path -LiteralPath $script:ChangelogDir)) {
        New-Item -ItemType Directory -Path $script:ChangelogDir -Force | Out-Null
    }

    $path = Get-ChangelogPath -SemVer $SemVer
    if (Test-Path -LiteralPath $path) { return $path }

    $stub = @"
# v$SemVer

## Features


## Improvements


## Bug fixes

"@
    [System.IO.File]::WriteAllText($path, $stub, [System.Text.UTF8Encoding]::new($false))
    return $path
}
