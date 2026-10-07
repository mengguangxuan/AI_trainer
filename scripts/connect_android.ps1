param([string]$DeviceId)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env.ps1"
$adbArgs = @()
if ($DeviceId) { $adbArgs += @('-s', $DeviceId) }
& adb.exe @adbArgs reverse tcp:8000 tcp:8000
if ($LASTEXITCODE -ne 0) { throw 'Connect an authorized USB device or emulator first.' }
Write-Host 'Android can now access http://127.0.0.1:8000/api/app/v1/'
