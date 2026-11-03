# run-mobile.ps1 ile açılan oyun pencerelerini kapatır.
# Yalnızca bu projeyi "--mobile" ile çalıştıran Godot süreçlerini durdurur; Godot editörüne
# ve başka projelere dokunmaz.
# Kullanım: powershell -ExecutionPolicy Bypass -File scripts\stop-mobile.ps1
$root = Split-Path -Parent $PSScriptRoot
$gamePath = Join-Path $root "game"

$targets = Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot_v4%'" | Where-Object {
    $_.CommandLine -and $_.CommandLine.Contains("--mobile") -and $_.CommandLine.Contains($gamePath)
}

if (-not $targets) {
    Write-Host "Çalışan telefon simülasyonu yok."
    return
}

foreach ($p in $targets) {
    Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
    Write-Host "Durduruldu: PID $($p.ProcessId)"
}
