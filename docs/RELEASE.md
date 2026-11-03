# Yayın Hazırlığı (Google Play)

## Derleme
| Çıktı | Komut | Not |
|---|---|---|
| Debug APK (test) | `godot --headless --path game --export-debug "Android" builds/MathKings-debug.apk` | Yerel ağ API'si, geliştirme sertifikası kabul edilir |
| Release AAB (Play) | `powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1` | Gradle derlemesi, yükleme anahtarıyla imzalı |

- Yükleme anahtarı: `%USERPROFILE%\.mathkings\mathkings-upload.keystore`, şifresi aynı klasörde
  `upload-keystore.properties`. **Repoda değildir; bir şifre yöneticisine yedekleyin.**
  Play App Signing açık olduğu için kaybolursa Play Console'dan sıfırlanabilir.
- Her yeni yüklemede `game/export_presets.cfg` → `version/code` artırılmalı.
- Gradle şablonu `game/android/` (git dışında). Yeniden kurmak için Godot editöründe
  Proje → Android Derleme Şablonunu Yükle.

## Yayın öncesi zorunlu adımlar
- [ ] `project.godot` → `mathkings/api/release_base_url`: gerçek **HTTPS** API adresi (şu an örnek adres).
- [ ] Sunucu üretim ayarları (aşağıda) ve gerçek SMTP sağlayıcısı.
- [ ] Gizlilik politikası URL'si (13 yaş altı hedef kitle için Play zorunlu kılar).
- [ ] Hesap silme için web bağlantısı (Play, uygulama içi silmeye ek olarak web yolu ister).
- [ ] Soru dosyalarının öğretmen incelemesi (`reviewStatus: draft` → `approved`).
- [ ] Gerçek cihazlarda test (düşük ve orta seviye Android), çocuklarla kullanılabilirlik testi (PLAYTEST.md).
- [ ] Önce **Dahili test** kanalına yükleme, sonra kapalı test.

## Play Console — Veri güvenliği formu (taslak yanıtlar)
| Soru | Yanıt |
|---|---|
| Veri toplanıyor mu? | Evet, yalnızca isteğe bağlı ebeveyn hesabı açılırsa |
| Kişisel bilgi | E-posta adresi — hesap yönetimi; zorunlu değil (misafir oynanabilir) |
| Uygulama etkinliği | Oyun ilerlemesi (bölüm, toplanan öğeler, konu istatistikleri) — uygulama işlevselliği |
| Konum, kişiler, fotoğraf, cihaz kimliği | Toplanmıyor (cihaz kimliği yalnızca yerel oturum şifrelemesinde kullanılır, gönderilmez) |
| Üçüncü taraflarla paylaşım | Yok |
| Reklam / analitik SDK | Yok |
| Aktarımda şifreleme | Evet (HTTPS) |
| Silme talebi | Evet — oyun içinden şifreyle kalıcı silme (+ web bağlantısı eklenecek) |
| Hedef kitle | 9–12 yaş (aile politikası kapsamında) |

## Sunucu üretim ayarları
`ASPNETCORE_ENVIRONMENT=Production` iken eksik ayarla **API bilerek başlamaz**.
| Ayar | Açıklama |
|---|---|
| `ConnectionStrings__Default` | PostgreSQL bağlantısı (ayrı, yetkisi kısıtlı kullanıcı) |
| `Email__Mode=Smtp`, `Email__Smtp__Host/Port/EnableSsl/User/Password/From` | E-posta sağlayıcısı |
| `DataProtection__KeysPath` | Belirteç şifreleme anahtarları için kalıcı, yedeklenen klasör |
| `ReverseProxy__KnownProxies__0` | nginx vb. arkasındaysa proxy IP'si (istek sınırı doğru IP'yi görsün) |
| `AllowedHosts` | API alan adı |
Veritabanı: `dotnet ef migrations bundle` ile üretilen paket veya `dotnet ef database update`.

## Güvenlik gözden geçirmesi (Sprint 5)
| Kontrol | Sonuç |
|---|---|
| NuGet bilinen açıklar (`dotnet list package --vulnerable`) | Yok |
| Repoda şifre/anahtar | Yok (user-secrets, `%USERPROFILE%\.mathkings`) |
| Güvenlik başlıkları (nosniff, DENY, no-referrer, no-store) | Eklendi + test |
| Ters proxy arkasında IP tabanlı istek sınırı | Yapılandırılabilir hale getirildi |
| Belirteç anahtarlarının kalıcılığı | Üretimde zorunlu hale getirildi |
| Üretimde geliştirme uçları (`/dev/last-code`) | Kapalı + test |
| Üretimde eksik SMTP/anahtar ayarı | API başlamaz + test |
| İstemci: release'de geliştirme sertifikası | Kabul edilmez (yalnızca debug) |
| İstemci: release API adresi | Ayrı ayar; HTTPS olmalı |
| Kimlik doğrulama (kilit, istek sınırı, hesap tespiti, silme) | Sprint 3 testleri |
| Açık konu | Belirteçler Android Keystore yerine uygulama alanında şifreli dosyada |
