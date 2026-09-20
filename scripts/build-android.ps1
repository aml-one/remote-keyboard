# Versioned Remote Keyboard APK. Never run bare flutter build apk.
param(
    [switch]$Arm64Only
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'version-lib.ps1')
$Project = Join-Path $Root 'app'
$semver = Get-ProjectVersion
$buildDate = Get-BuildDateStamp
$label = Get-BuildLabel -SemVer $semver -BuildDate $buildDate
$buildNumber = Get-BuildNumber -SemVer $semver
Sync-PubspecVersion -SemVer $semver
Sync-DartDefinesFile -SemVer $semver -BuildDate $buildDate
$dist = Join-Path $Project 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

Push-Location $Project
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    $flutterArgs = @(
        'build', 'apk', '--release',
        "--dart-define=APP_VERSION=$semver",
        "--dart-define=APP_BUILD_DATE=$buildDate",
        "--build-name=$semver",
        "--build-number=$buildNumber"
    )
    if ($Arm64Only) {
        $flutterArgs += @('--target-platform', 'android-arm64')
    }
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed' }
} finally {
    Pop-Location
}

$built = Get-ChildItem -LiteralPath (Join-Path $Project 'build/app/outputs/flutter-apk') `
    -Filter '*.apk' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $built) { throw 'No APK produced' }
$dest = Join-Path $dist "remotekeyboard-android-arm64-$label.apk"
Copy-Item -LiteralPath $built.FullName -Destination $dest -Force
Write-Host "APK $dest"
if ($label -match 'v1\.0\.0-' -and $semver -ne '1.0.0') {
    throw "Refusing an APK whose label still looks like the dart-define default."
}
