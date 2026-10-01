$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = 'E:\Android\Studio\Android_studio\plugins\Kotlin\kotlinc\bin\kotlinc.bat'
$java = 'E:\Android\Studio\Android_studio\jbr\bin\java.exe'
$source = Join-Path $projectDir 'app\src\main\java\com\google\mediapipe\examples\poselandmarker\training\ExerciseAnalyzer.kt'
$smokeCheck = Join-Path $projectDir 'tools\ExerciseAnalyzerSmokeCheck.kt'
$outputDir = Join-Path $env:TEMP 'fitness-coach-algorithm-check'
$outputJar = Join-Path $outputDir 'exercise-smoke.jar'

if (-not (Test-Path -LiteralPath $compiler)) {
    throw "Kotlin compiler not found: $compiler"
}
if (-not (Test-Path -LiteralPath $java)) {
    throw "Java runtime not found: $java"
}

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
& $compiler $source $smokeCheck -include-runtime -d $outputJar
if ($LASTEXITCODE -ne 0) {
    throw "Kotlin compilation failed with exit code $LASTEXITCODE"
}

& $java -jar $outputJar
if ($LASTEXITCODE -ne 0) {
    throw "Smoke check failed with exit code $LASTEXITCODE"
}
