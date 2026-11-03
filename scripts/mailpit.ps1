# Mailpit'i (geliştirme e-posta kutusu) başlatır veya durdurur.
# Laragon 6 Mailpit'i yönetmediği için ayrı çalıştırılır; API geliştirmede e-postaları buraya gönderir.
#   SMTP: localhost:1025   Arayüz: http://localhost:8025
# Kullanım:
#   powershell -ExecutionPolicy Bypass -File scripts\mailpit.ps1 [start|stop|status]
param(
    [ValidateSet("start", "stop", "status")]
    [string]$Action = "start"
)
$exe = Get-ChildItem "C:\laragon\bin\mailpit" -Recurse -Filter mailpit.exe | Select-Object -First 1 -ExpandProperty FullName
if (-not $exe) { throw "Mailpit bulunamadı (C:\laragon\bin\mailpit)." }
$running = Get-Process mailpit -ErrorAction SilentlyContinue

switch ($Action) {
    "start" {
        if ($running) { Write-Host "Mailpit zaten çalışıyor: http://localhost:8025"; return }
        # Yalnızca bu bilgisayardan erişilir (yerel ağa açılmaz).
        Start-Process $exe -ArgumentList "--smtp", "127.0.0.1:1025", "--listen", "127.0.0.1:8025" -WindowStyle Hidden
        Start-Sleep -Seconds 2
        if (Get-Process mailpit -ErrorAction SilentlyContinue) { Write-Host "Mailpit başladı: http://localhost:8025 (SMTP 1025)" }
        else { throw "Mailpit başlatılamadı (1025 veya 8025 portu dolu olabilir)." }
    }
    "stop" {
        if ($running) { $running | Stop-Process -Force; Write-Host "Mailpit durduruldu." }
        else { Write-Host "Mailpit çalışmıyor." }
    }
    "status" {
        if ($running) { Write-Host "Mailpit çalışıyor: http://localhost:8025" } else { Write-Host "Mailpit çalışmıyor." }
    }
}
