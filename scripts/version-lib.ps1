# Remote Keyboard versioning. Repo-root `version` is the source of truth.
#
#   version file    1.0.0
#   build number    10000            major * 10000 + minor * 100 + patch
#   display label   v1.0.0-260812    v<semver>-<yyMMdd>
#
# Dot-source it:  . scripts/version-lib.ps1

$script:RepoRoot = Split-Path $PSScriptRoot -Parent
$script:VersionFile = Join-Path $script:RepoRoot 'version'
$script:PubspecPath = Join-Path $script:RepoRoot 'app/pubspec.yaml'
$script:DartDefinesPath = Join-Path $script:RepoRoot 'app/dart_defines.json'
$script:ReleaseBumpLockFile = Join-Path $script:RepoRoot '.release-bump-lock'

function Read-PlainTextFile {
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset).Trim()
}

function Get-ProjectVersion {
    if (-not (Test-Path -LiteralPath $script:VersionFile)) {
        throw "Missing version file: $script:VersionFile"
    }
    $raw = Read-PlainTextFile -Path $script:VersionFile
    if ($raw -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid version in $script:VersionFile : '$raw' (expected major.minor.patch)"
    }
    return $raw
}

function Get-BuildDateStamp {
    param([datetime]$Now = (Get-Date))
    return $Now.ToString('yyMMdd')
}

function Get-BuildNumber {
    param([string]$SemVer)
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    $parts = $SemVer -split '\.'
    if ($parts.Count -ne 3) { throw "Invalid semver: $SemVer" }
    if ([int]$parts[1] -gt 9 -or [int]$parts[2] -gt 9) {
        throw "Version $SemVer cannot be encoded: minor and patch must be one digit."
    }
    return ([int]$parts[0] * 10000) + ([int]$parts[1] * 100) + [int]$parts[2]
}

function Get-BuildLabel {
    param(
        [string]$SemVer,
        [string]$BuildDate
    )
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    if (-not $BuildDate) { $BuildDate = Get-BuildDateStamp }
    return "v$SemVer-$BuildDate"
}

function Sync-PubspecVersion {
    param([string]$SemVer)
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    if (-not (Test-Path -LiteralPath $script:PubspecPath)) {
        throw "Missing pubspec: $script:PubspecPath"
    }
    $buildNumber = Get-BuildNumber -SemVer $SemVer
    $lines = Get-Content -LiteralPath $script:PubspecPath -Encoding UTF8
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*version:\s*') {
            $lines[$i] = "version: $SemVer+$buildNumber"
            $found = $true
            break
        }
    }
    if (-not $found) { throw "No version: line in $script:PubspecPath" }
    [System.IO.File]::WriteAllLines($script:PubspecPath, $lines, [System.Text.UTF8Encoding]::new($false))
}

function Sync-DartDefinesFile {
    param(
        [string]$SemVer,
        [string]$BuildDate
    )
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    if (-not $BuildDate) { $BuildDate = Get-BuildDateStamp }
    $payload = (@{
        APP_VERSION    = $SemVer
        APP_BUILD_DATE = $BuildDate
    } | ConvertTo-Json -Compress) + "`n"
    [System.IO.File]::WriteAllText($script:DartDefinesPath, $payload, [System.Text.UTF8Encoding]::new($false))
}

function Get-FlutterVersionDefines {
    param(
        [string]$SemVer,
        [string]$BuildDate
    )
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    if (-not $BuildDate) { $BuildDate = Get-BuildDateStamp }
    return @(
        "--dart-define=APP_VERSION=$SemVer",
        "--dart-define=APP_BUILD_DATE=$BuildDate"
    )
}

function Set-ProjectVersion {
    param([Parameter(Mandatory)][string]$SemVer)
    if ($SemVer -notmatch '^\d+\.\d+\.\d+$') {
        throw "Invalid semver: $SemVer"
    }
    [System.IO.File]::WriteAllText($script:VersionFile, $SemVer, [System.Text.UTF8Encoding]::new($false))
    Sync-PubspecVersion -SemVer $SemVer
    Sync-DartDefinesFile -SemVer $SemVer
}

function Get-NextProjectVersion {
    param([string]$SemVer)
    if (-not $SemVer) { $SemVer = Get-ProjectVersion }
    $parts = $SemVer -split '\.'
    if ($parts.Count -ne 3) { throw "Invalid semver: $SemVer" }
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    if ($patch -ge 9) {
        $patch = 0
        $minor++
        if ($minor -ge 10) {
            $minor = 0
            $major++
        }
    } else {
        $patch++
    }
    return "$major.$minor.$patch"
}

function Bump-ProjectVersion {
    $next = Get-NextProjectVersion -SemVer (Get-ProjectVersion)
    Set-ProjectVersion -SemVer $next
    . (Join-Path $PSScriptRoot 'changelog-lib.ps1')
    New-ChangelogStub -SemVer (Get-NextProjectVersion -SemVer $next) | Out-Null
    return $next
}
