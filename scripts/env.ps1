param(
    [string]$FlutterSdk = 'D:\dev\flutter',
    [string]$AndroidSdk = 'D:\dev\android-sdk',
    [string]$Jdk = 'D:\dev\jdk-21.0.12.1+1'
)
$ErrorActionPreference = 'Stop'
foreach ($file in @("$FlutterSdk\bin\flutter.bat", "$AndroidSdk\platform-tools\adb.exe", "$Jdk\bin\java.exe")) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing build tool: $file" }
}
$env:ANDROID_HOME = $AndroidSdk
$env:JAVA_HOME = $Jdk
$env:FLUTTER_STORAGE_BASE_URL = 'https://storage.flutter-io.cn'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$env:PATH = "$FlutterSdk\bin;$AndroidSdk\platform-tools;$Jdk\bin;$env:PATH"
