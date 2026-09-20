# Upload Android APK + helper binaries + version/releases JSON to AmL One.
# Do not run unless this conversation asked to publish / build the app.
param(
    [string]$SshHost = $(if ($env:AML_FRANKFURT_SSH) { $env:AML_FRANKFURT_SSH } else { 'ambrus@frankfurt.aml.one' }),
    [int]$SshPort = 717,
    [string]$RemoteDir = '/home/ambrus/www/aml/remotekeyboard.aml.one/downloads',
    [switch]$SkipArtifacts
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

function Find-RawHelper([string]$Dir, [string]$Pattern) {
    if (-not (Test-Path -LiteralPath $Dir)) { return $null }
    return Get-ChildItem -LiteralPath $Dir -Filter $Pattern |
        Where-Object { $_.Extension -ne '.zip' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function ConvertTo-HelperStoreZip {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][ValidateSet('windows', 'linux', 'macos')][string]$Kind,
        [Parameter(Mandatory)][string]$ZipPath
    )
    $parent = Split-Path -Parent $ZipPath
    if ($parent) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        if ($Kind -eq 'windows') {
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $SourcePath, 'remote-keyboard.exe',
                [System.IO.Compression.CompressionLevel]::Optimal)
            return
        }
        if ($Kind -eq 'linux') {
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $SourcePath, 'remote-keyboard',
                [System.IO.Compression.CompressionLevel]::Optimal)
            return
        }
        $stage = Join-Path ([IO.Path]::GetTempPath()) ('rk-app-' + [guid]::NewGuid().ToString('N'))
        $macosDir = Join-Path $stage 'Remote Keyboard Helper.app\Contents\MacOS'
        New-Item -ItemType Directory -Path $macosDir -Force | Out-Null
        $exePath = Join-Path $macosDir 'Remote Keyboard Helper'
        Copy-Item -LiteralPath $SourcePath -Destination $exePath -Force
        $plistPath = Join-Path $stage 'Remote Keyboard Helper.app\Contents\Info.plist'
        $plist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Remote Keyboard Helper</string>
  <key>CFBundleIdentifier</key>
  <string>one.aml.remotekeyboard.helper</string>
  <key>CFBundleName</key>
  <string>Remote Keyboard Helper</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$semver</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.7</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
"@
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($plistPath, $plist, $utf8)
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $exePath, 'Remote Keyboard Helper.app/Contents/MacOS/Remote Keyboard Helper',
            [System.IO.Compression.CompressionLevel]::Optimal)
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $plistPath, 'Remote Keyboard Helper.app/Contents/Info.plist',
            [System.IO.Compression.CompressionLevel]::Optimal)
        Remove-Item -LiteralPath $stage -Recurse -Force
    } finally {
        $zip.Dispose()
    }
}

$android = Find-Artifact $dist "remotekeyboard-android-*.apk"
if (-not $android) { throw "No Android APK in $dist. Run scripts/build-android.ps1 first." }

$platforms = [ordered]@{
    remoteKeyboardAndroid = @{ file = $android.Name; path = $android.FullName }
}
$win = Find-RawHelper $helperDist "remotekeyboard-windows-x64-*.exe"
$lin = Find-RawHelper $helperDist "remotekeyboard-linux-x64-*"
$macArm = Find-RawHelper $helperDist "remotekeyboard-macos-arm64-*"
$macIntel = Find-RawHelper $helperDist "remotekeyboard-macos-x64-*"
if (-not $win) { throw "No Windows helper in $helperDist. Run helper/build.ps1 -Target windows first." }
if (-not $lin) { throw "No Linux helper in $helperDist. Run scripts/build-helper-linux-wsl.ps1 first." }
if (-not $macArm) { throw "No macOS arm64 helper in $helperDist. Run scripts/build-helpers-via-nova.ps1 first." }
if (-not $macIntel) { throw "No macOS Intel helper in $helperDist. Run scripts/build-helpers-via-nova.ps1 first." }

$winZip = Join-Path $helperDist ([IO.Path]::ChangeExtension($win.Name, '.zip'))
$linZip = Join-Path $helperDist ($lin.Name + '.zip')
$macArmZip = Join-Path $helperDist ($macArm.Name + '.zip')
$macIntelZip = Join-Path $helperDist ($macIntel.Name + '.zip')
ConvertTo-HelperStoreZip -SourcePath $win.FullName -Kind windows -ZipPath $winZip
ConvertTo-HelperStoreZip -SourcePath $lin.FullName -Kind linux -ZipPath $linZip
ConvertTo-HelperStoreZip -SourcePath $macArm.FullName -Kind macos -ZipPath $macArmZip
ConvertTo-HelperStoreZip -SourcePath $macIntel.FullName -Kind macos -ZipPath $macIntelZip
$platforms.remoteKeyboardWindows = @{ file = [IO.Path]::GetFileName($winZip); path = $winZip }
$platforms.remoteKeyboardLinux = @{ file = [IO.Path]::GetFileName($linZip); path = $linZip }
$platforms.remoteKeyboardMacos = @{ file = [IO.Path]::GetFileName($macArmZip); path = $macArmZip }
$platforms.remoteKeyboardMacosIntel = @{ file = [IO.Path]::GetFileName($macIntelZip); path = $macIntelZip }

# Store officialReleases() requires file + version + buildNumber > 0, and
# changelog (not notes). releases.json must be an array of platform rows.
$buildNumber = Get-BuildNumber -SemVer $semver
$publishedAt = (Get-Date).ToUniversalTime().ToString('o')
$changelog = [object[]]@($notes)
$versionDoc = [ordered]@{}
$releaseRows = [System.Collections.Generic.List[object]]::new()
foreach ($key in $platforms.Keys) {
    $item = $platforms[$key]
    $info = Get-Item -LiteralPath $item.path
    $sha = (Get-FileHash -LiteralPath $item.path -Algorithm SHA256).Hash.ToLowerInvariant()
    $block = [ordered]@{
        version     = $semver
        buildNumber = $buildNumber
        label       = $label
        file        = $item.file
        sizeBytes   = [long]$info.Length
        sha256      = $sha
        publishedAt = $publishedAt
        changelog   = $changelog
    }
    $versionDoc[$key] = $block
    $row = [ordered]@{ platform = $key }
    foreach ($pair in $block.GetEnumerator()) { $row[$pair.Key] = $pair.Value }
    $releaseRows.Add($row)
}

$localManifestDir = Join-Path $Root 'data/releases'
New-Item -ItemType Directory -Path $localManifestDir -Force | Out-Null
$versionJson = Join-Path $localManifestDir 'version.json'
$releasesJson = Join-Path $localManifestDir 'releases.json'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($versionJson, ($versionDoc | ConvertTo-Json -Depth 8), $utf8)
[System.IO.File]::WriteAllText($releasesJson, ($releaseRows.ToArray() | ConvertTo-Json -Depth 8), $utf8)

Write-Host "Publishing Remote Keyboard $label to ${SshHost}:$RemoteDir"
ssh -p $SshPort $SshHost "mkdir -p '$RemoteDir' /var/www/aml/remotekeyboard.aml.one/downloads"
scp -P $SshPort $versionJson $releasesJson "${SshHost}:$RemoteDir/"
if (-not $SkipArtifacts) {
    foreach ($key in $platforms.Keys) {
        $item = $platforms[$key]
        scp -P $SshPort $item.path "${SshHost}:$RemoteDir/"
    }
}
Write-Host "OTA uploaded. Deploy AmL One so Today can GET the listing."
