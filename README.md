# MathKings — Matematik Krallığı

9–12 yaş için 2D platform + matematik macera oyunu. İstemci: Godot 4.7 (GDScript).

## Gereksinimler
- Godot 4.7.2 stable (standart sürüm) + Android export template'leri
- JDK 17 (Temurin), Android SDK (platform-tools, build-tools 36.1.0, platforms;android-36)
- Godot Editör Ayarları → Export → Android: Java SDK Path ve Android SDK Path

## Çalıştırma
```sh
godot --path game                       # oyunu aç
godot -e --path game                    # editörde aç
godot --headless --path game --import   # ilk kurulumda içe aktarma
```

## Testler
```sh
godot --headless --path game -s res://tests/run_tests.gd
```
Çıkış kodu 0 = tüm testler geçti.

## Android debug APK
```sh
godot --headless --path game --export-debug "Android" builds/MathKings-debug.apk
adb install -r builds/MathKings-debug.apk
```

## Klasörler
- `game/autoload` — `GameState` (kayıt, sahne geçişi), `Settings` (ses)
- `game/logic` — sahneden bağımsız, test edilebilir mantık
- `game/scenes` — sahneler ve scriptleri
- `game/data` — dünya kataloğu ve bölüm haritaları (`logic/level_layout.gd` lejantı)
- `game/tools` — geliştirici araçları (export'a dahil değil)
- `docs/GDD.md` — kısa oyun tasarım dokümanı
