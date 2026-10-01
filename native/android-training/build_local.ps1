$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$appWorkspace = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $projectDir))
$sharedGradleHome = Join-Path $appWorkspace '.tools\gradle-8.9-complete\gradle-8.9'
$sharedGradleUserHome = Join-Path $appWorkspace '.gradle-user-home'
$systemJdk = 'C:\Program Files\Java\jdk-21'
$studioJdk = 'E:\Android\Studio\Android_studio\jbr'

if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = if (Test-Path -LiteralPath $systemJdk) { $systemJdk } else { $studioJdk }
}

if (-not $env:ANDROID_HOME) {
    $env:ANDROID_HOME = 'E:\Android\sdk'
}

$gradleCommand = Join-Path $projectDir 'gradlew.bat'
if (Test-Path -LiteralPath (Join-Path $sharedGradleHome 'bin\gradle.bat')) {
    $gradleCommand = Join-Path $sharedGradleHome 'bin\gradle.bat'
    if (-not $env:GRADLE_USER_HOME -and (Test-Path -LiteralPath $sharedGradleUserHome)) {
        $env:GRADLE_USER_HOME = $sharedGradleUserHome
    }
}

Push-Location $projectDir
try {
    & $gradleCommand --no-daemon testDebugUnitTest assembleDebug
    if ($LASTEXITCODE -ne 0) {
        throw "Android build failed with exit code $LASTEXITCODE"
    }
    Write-Host "APK: $projectDir\app\build\outputs\apk\debug\app-debug.apk"
} finally {
    Pop-Location
}
