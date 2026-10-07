param([string]$AgentBaseUrl = 'http://127.0.0.1:8000/api/app/v1/')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env.ps1"
$source = Split-Path -Parent $PSScriptRoot
$buildRoot = $source
if ($source -match '[^\x00-\x7F]') {
    $buildRoot = 'D:\dev\ai_trainer-build'
    New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
    & robocopy $source $buildRoot /E /XD .git .dart_tool build .gradle .kotlin .plugin_symlinks /XF local.properties *.log *.apk /NJH /NJS /NDL /NFL /NP
    if ($LASTEXITCODE -ge 8) { throw 'Could not prepare ASCII build workspace.' }
}
Push-Location $buildRoot
try {
    & flutter.bat pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
    & dart.bat analyze
    if ($LASTEXITCODE -ne 0) { throw 'Flutter analysis failed.' }
    & flutter.bat test
    if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
    & flutter.bat build apk --debug "--dart-define=AGENT_BASE_URL=$AgentBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    $apk = Join-Path $buildRoot 'build\app\outputs\flutter-apk\app-debug.apk'
    $destination = Join-Path $source 'build\app\outputs\flutter-apk'
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    if ($buildRoot -ne $source) { Copy-Item -LiteralPath $apk -Destination $destination -Force }
    Write-Host "APK: $destination\app-debug.apk"
} finally { Pop-Location }
