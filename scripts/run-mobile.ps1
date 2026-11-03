# Oyunu dizüstünde telefon/tablet ekran oranında açar; dokunmatik butonlar fareyle kullanılır.
# Kullanım:
#   powershell -ExecutionPolicy Bypass -File scripts\run-mobile.ps1            # güncel telefon (20:9)
#   powershell -ExecutionPolicy Bypass -File scripts\run-mobile.ps1 -Device eski-telefon
#   powershell -ExecutionPolicy Bypass -File scripts\run-mobile.ps1 -Device tablet
param(
    [ValidateSet("telefon", "eski-telefon", "tablet")]
    [string]$Device = "telefon"
)
$root = Split-Path -Parent $PSScriptRoot
$sizes = @{
    "telefon"      = "1280x576"   # 20:9 (günümüz telefonlarının çoğu)
    "eski-telefon" = "1280x720"   # 16:9
    "tablet"       = "1024x768"   # 4:3
}
$godot = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter "Godot_v4.7.2-stable_win64.exe" |
    Select-Object -First 1).FullName
if (-not $godot) { throw "Godot 4.7.2 bulunamadı." }

Write-Host "Açılıyor: $Device ($($sizes[$Device])). Dokunmatik butonlar fareyle, klavye de çalışır."
Start-Process $godot -ArgumentList @("--path", "`"$root\game`"", "--resolution", $sizes[$Device], "--", "--mobile")
