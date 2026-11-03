# Google Play için imzalı release AAB üretir.
# Yükleme anahtarı repo dışındadır: %USERPROFILE%\.mathkings\ (şifre upload-keystore.properties içinde).
# Kullanım: powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$keyDir = Join-Path $env:USERPROFILE ".mathkings"
$props = @{}
Get-Content (Join-Path $keyDir "upload-keystore.properties") | ForEach-Object {
    $k, $v = $_ -split "=", 2
    if ($k) { $props[$k.Trim()] = $v.Trim() }
}

$godot = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4.7.2-stable_win64_console.exe" | Select-Object -First 1).FullName
if (-not $env:JAVA_HOME) { $env:JAVA_HOME = (Get-ChildItem "C:\Program Files\Eclipse Adoptium" -Directory | Select-Object -First 1).FullName }
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"

# Godot release imzası ortam değişkenlerinden okunur; şifre dosyaya/repoya yazılmaz.
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Join-Path $keyDir "mathkings-upload.keystore"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $props["alias"]
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $props["password"]

$out = Join-Path $root "builds\MathKings-release.aab"
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
& $godot --headless --path (Join-Path $root "game") --export-release "Android AAB" $out
$exitCode = $LASTEXITCODE
# Godot'un başlattığı Gradle daemon'ı açık kalırsa çağıran terminal beklemeye devam eder.
& (Join-Path $root "game\android\build\gradlew.bat") --stop -p (Join-Path $root "game\android\build") | Out-Null
if ($exitCode -ne 0 -or -not (Test-Path $out)) { throw "AAB üretilemedi (çıkış kodu $exitCode)." }

& "$env:JAVA_HOME\bin\jarsigner.exe" -verify $out | Select-Object -Last 1
Write-Host "Hazır: $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) MB)"
