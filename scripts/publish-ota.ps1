# Upload Android APK + helper binaries + version/releases JSON to AmL One.
# Do not run unless this conversation asked to publish / build the app.
param(
    [string]$SshHost = $(if ($env:AML_FRANKFURT_SSH) { $env:AML_FRANKFURT_SSH } else { 'ambrus@frankfurt.aml.one' }),
    [int]$SshPort = 717,
    [string]$RemoteDir = '/home/ambrus/www/aml/remotekeyboard.aml.one/downloads'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'version-lib.ps1')
. (Join-Path $PSScriptRoot 'changelog-lib.ps1')

$semver = Get-ProjectVersion
$label = Get-BuildLabel
$notes = @(Read-ChangelogEntries -SemVer $semver)
$dist = Join-Path $Root 'app/dist'
$helperDist = Join-Path $Root 'helper/dist'

function Find-Artifact([string]$Dir, [string]$Pattern) {
    if (-not (Test-Path -LiteralPath $Dir)) { return $null }
    return Get-ChildItem -LiteralPath $Dir -Filter $Pattern |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

$android = Find-Artifact $dist "remotekeyboard-android-*.apk"
if (-not $android) { throw "No Android APK in $dist. Run scripts/build-android.ps1 first." }

$platforms = @{
    remoteKeyboardAndroid    = @{ file = $android.Name; path = $android.FullName }
}
$win = Find-Artifact $helperDist "remotekeyboard-windows-x64-*.exe"
$lin = Find-Artifact $helperDist "remotekeyboard-linux-x64-*"
$macArm = Find-Artifact $helperDist "remotekeyboard-macos-arm64-*"
$macIntel = Find-Artifact $helperDist "remotekeyboard-macos-x64-*"
if (-not $win) { throw "No Windows helper in $helperDist. Run helper/build.ps1 -Target windows first." }
if (-not $lin) { throw "No Linux helper in $helperDist. Run scripts/build-helper-linux-wsl.ps1 first." }
if (-not $macArm) { throw "No macOS arm64 helper in $helperDist. Run scripts/build-helpers-via-nova.ps1 first." }
if (-not $macIntel) { throw "No macOS Intel helper in $helperDist. Run scripts/build-helpers-via-nova.ps1 first." }
$platforms.remoteKeyboardWindows = @{ file = $win.Name; path = $win.FullName }
$platforms.remoteKeyboardLinux = @{ file = $lin.Name; path = $lin.FullName }
$platforms.remoteKeyboardMacos = @{ file = $macArm.Name; path = $macArm.FullName }
$platforms.remoteKeyboardMacosIntel = @{ file = $macIntel.Name; path = $macIntel.FullName }

$manifest = [ordered]@{
    product = 'remote-keyboard'
    version = $semver
    label   = $label
    notes   = @($notes)
}
foreach ($key in $platforms.Keys) {
    $item = $platforms[$key]
    $manifest[$key] = @{
        version = $semver
        label   = $label
        file    = $item.file
        notes   = @($notes)
    }
}

$localManifestDir = Join-Path $Root 'data/releases'
New-Item -ItemType Directory -Path $localManifestDir -Force | Out-Null
$versionJson = Join-Path $localManifestDir 'version.json'
$releasesJson = Join-Path $localManifestDir 'releases.json'
$json = $manifest | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($versionJson, $json, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText($releasesJson, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Publishing Remote Keyboard $label to ${SshHost}:$RemoteDir"
ssh -p $SshPort $SshHost "mkdir -p '$RemoteDir' /var/www/aml/remotekeyboard.aml.one/downloads"
scp -P $SshPort $versionJson $releasesJson "${SshHost}:$RemoteDir/"
foreach ($key in $platforms.Keys) {
    $item = $platforms[$key]
    scp -P $SshPort $item.path "${SshHost}:$RemoteDir/"
}
Write-Host "OTA uploaded. Deploy AmL One so Today can GET the listing."
