# MathKings — Matematik Krallığı

9–12 yaş için 2D platform + matematik macera oyunu.
İstemci: Godot 4.7 (GDScript). Sunucu: ASP.NET Core 10 + EF Core + PostgreSQL 16.

## Gereksinimler
- Godot 4.7.2 stable (standart sürüm) + Android export template'leri
- JDK 17 (Temurin), Android SDK (platform-tools, build-tools 36.1.0, platforms;android-36)
- Godot Editör Ayarları → Export → Android: Java SDK Path ve Android SDK Path
- .NET 10 SDK, PostgreSQL 16 (Laragon)

## Oyun
```sh
godot --headless --path game --import   # ilk kurulumda içe aktarma
godot --path game                       # oyunu aç
godot -e --path game                    # editörde aç
```
API adresi: `project.godot` → `mathkings/api/base_url` (varsayılan `http://localhost:5055`).
Gerçek cihazda bilgisayarın yerel IP'si gerekir; yayında HTTPS zorunludur.

## Sunucu
Bağlantı dizeleri repoda değil, `dotnet user-secrets` içindedir (`ConnectionStrings:Default`, `ConnectionStrings:Test`).
```sh
cd server
dotnet tool restore
dotnet run --project src/MathKings.Api        # Development: migration'ları uygular, http://localhost:5055
dotnet ef migrations add <Ad> --project src/MathKings.Api --output-dir Data/Migrations -- --environment Development
```
Geliştirmede e-posta gönderilmez: doğrulama/sıfırlama kodları API log'una yazılır
ve `GET /dev/last-code?email=..&kind=confirm|reset` ile okunabilir (yalnızca Development).

## Testler
```sh
godot --headless --path game -s res://tests/run_tests.gd   # oyun mantığı (birim)
cd server && dotnet test                                   # API birim + entegrasyon (mathkings_test DB)
godot --headless --path game -s res://tools/e2e_cloud.gd   # uçtan uca; API çalışıyor olmalı
```

## Android debug APK
```sh
godot --headless --path game --export-debug "Android" builds/MathKings-debug.apk
adb install -r builds/MathKings-debug.apk
```

## Klasörler
- `game/autoload` — `GameState` (kayıt, profil, senkron), `Cloud` (API + oturum), `Settings` (ses)
- `game/logic` — sahneden bağımsız, test edilebilir mantık
- `game/scenes` — sahneler ve scriptleri (`account/`: ebeveyn kapısı, hesap, profil seçimi)
- `game/data` — dünya kataloğu, bölüm haritaları, soru şablonları
- `game/tools` — geliştirici araçları (export'a dahil değil)
- `server/src/MathKings.Api` — `Auth/`, `Profiles/`, `Progress/`, `Data/`
- `docs/GDD.md` — kısa oyun tasarım dokümanı; `docs/COMPLIANCE.md` — çocuk güvenliği/uyum listesi
