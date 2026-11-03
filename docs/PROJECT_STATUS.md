# MathKings (Matematik Krallığı) — Proje Durumu

> Son güncelleme: 3 Kasım 2026 · Sürüm: 0.5.0 (versionCode 1)
> Hedef: 9–12 yaş (4–7. sınıf) için 2D platform + matematik macera oyunu. İlk platform Android.

## Özet

| Alan | Durum |
|---|---|
| Oynanabilir içerik | 3 dünya, 4 bölüm, Matematik Savaşı, Hazine Avı, Kesir Köprüsü |
| Hesap ve bulut kayıt | Çalışıyor (yetişkin hesabı + çocuk profilleri, çevrimdışı öncelikli senkron) |
| Testler | Godot 151/151, sunucu 34/34, uçtan uca 21/21 (HTTP ve HTTPS) |
| Android derleme | Debug APK ve imzalı release AAB üretiliyor |
| Gerçek cihaz testi | **Yapılmadı** |
| Yayın | Teknik olarak hazır; sunucu, gizlilik politikası ve içerik onayı bekliyor |

## Teknoloji

- **İstemci:** Godot 4.7.2 (GDScript), Compatibility renderer, yatay ekran
- **Sunucu:** ASP.NET Core 10, EF Core 10, PostgreSQL 16 (Laragon), ASP.NET Core Identity
- **Geliştirme e-postası:** Laragon Mailpit (SMTP 1025, arayüz http://localhost:8025)
- **Android:** JDK 17, SDK platform 36, build-tools 36.1.0, NDK 29, Gradle 8.11.1
- **Mimari:** modüler monolit; oyun sunucusuz da tam çalışır

## Tamamlanan sprintler

### Sprint 0 — Analiz ve hazırlık
- Mimari, klasör yapısı, kullanıcı akışı, kabul kriterleri, araç kurulumları.

### Sprint 1 — Oynanabilir temel (`b6c767a`)
- Açılış, ana menü, misafir profil (takma ad listeden + sınıf; gerçek ad yok), karakter seçimi
- Platform hareketi (coyote time, zıplama tamponu), çoklu dokunmatik kontroller, kamera
- Metin tabanlı bölüm haritaları, kontrol noktaları, cezasız yeniden doğma
- Yerel kayıt: atomik yazma, bozuk kayıt kurtarma, tek seferlik ödül

### Sprint 2 — Matematik Savaşı (`da316df`)
- Sınıfa göre soru üretimi (dört işlem, işlem önceliği), tipik hatalardan çeldiriciler
- Yanlışta seçenek elenir + Baykuş ipucu; ikinci yanlışta çözüm. Oyuncu can kaybetmez
- 1–3 savaş yıldızı, ödül yalnızca rekor artışında (tekrar oynayarak altın kasılamaz)
- Kodla üretilen ses efektleri, konu bazlı öğrenme istatistiği

### Sprint 3 — Hesap altyapısı (`f300d29`, `81c3c23`)
- Yetişkin hesabı: 18+ beyanı, rıza sürümü, 6 haneli e-posta kodu, şifre sıfırlama
- Güvenlik: 15 dk / 30 gün belirteçler, çıkışta iptal, kilitleme, istek sınırı, hesap tespitini önleme
- Çocuk profilleri (en fazla 5; yalnızca takma ad, sınıf, karakter), oyun içinden hesap silme
- Ebeveyn kapısı (doğum yılı, saklanmaz), misafir ilerlemesini hesaba aktarma
- Kayıpsız birleştirme; altın sunucu ve istemcide aynı formülle hesaplanır
- Mailpit ile gerçek SMTP akışı; telefonda yerel ağ üzerinden HTTPS test profili

### Sprint 4 — Macera genişletme (`b23f816`)
- Krallık Haritası: sıralı kilitler; sınıf etiketi yalnızca öneri, hiçbir dünya zorunlu değil
- Bölümler: Orman Yolu, Gizli Patika, Kristal Tüneli, Köprülü Sahil
- Çarpanlar Mağarası: kat, çarpan, asal sayı, bölünebilme soruları
- Kesirler Adası: karşılaştırma, denk kesir, toplama/çıkarma, bir sayının kesri, kesir çarpımı
- Hazine Avı (isteğe bağlı, 15 altın, bir kez) ve Kesir Köprüsü (şekil modeli)
- Orman, mağara ve ada temaları; dünyaya özel canavarlar

### Sprint 5 — Kalite ve yayın hazırlığı (`590618a`)
- Performans: 30–49 FPS'ten 62–135 FPS'e (V-Sync kapalı, Intel HD 520)
- Tema başına kodla üretilen özgün müzik döngüleri
- Güvenlik gözden geçirmesi: başlıklar, ters proxy desteği, kalıcı anahtarlar, üretim korumaları
- Uyarlanabilir ikon, imzalı AAB (16 KB hizalı), `scripts/build-release.ps1`
- Dokümanlar: `RELEASE.md`, `PLAYTEST.md`, `COMPLIANCE.md`

## Yayından önce yapılması gerekenler

| # | İş | Sorumlu | Not |
|---|---|---|---|
| 1 | Gerçek Android cihazda test | Kullanıcı + geliştirme | Performans yalnızca dizüstünde ölçüldü |
| 2 | Çocuklarla kullanılabilirlik testi | Kullanıcı | `docs/PLAYTEST.md` |
| 3 | Soru dosyalarının öğretmen incelemesi | Öğretmen | 3 dosya `reviewStatus: draft` |
| 4 | Sunucu barındırma, alan adı, HTTPS | Geliştirme | Ayarlar `docs/RELEASE.md` içinde |
| 5 | Gerçek e-posta sağlayıcısı (SMTP) | Kullanıcı seçecek | Brevo, Amazon SES veya kendi SMTP |
| 6 | `release_base_url` gerçek adresle değiştirilecek | Geliştirme | Şu an örnek adres |
| 7 | Gizlilik politikası sayfası | Kullanıcı / hukuk | 13 yaş altı için Play zorunlu |
| 8 | Hesap silme web bağlantısı | Geliştirme | Play zorunlu |
| 9 | KVKK aydınlatma ve rıza metinleri | Hukuk | Oyundaki metin taslak |
| 10 | Play Console kaydı, Veri güvenliği formu | Kullanıcı | Yanıtlar `docs/RELEASE.md` içinde |
| 11 | Dahili test kanalına ilk yükleme | Kullanıcı + geliştirme | |

## Sonraki geliştirme seçenekleri

- **Geometri Tapınağı:** açılar, çokgenler, çevre ve alan (haritada "Yakında")
- **Zekâ Kalesi:** mantık problemleri, karma görevler, bölüm sonu mücadeleleri ("Yakında")
- **Sunucu yayına alma:** Linux sunucu, Docker, nginx, otomatik yedekleme
- **Uyarlanabilir zorluk:** kayıtlı konu istatistiklerine göre soru seçimi
- **Nihai sanat ve ses:** kodla çizilen geçici görseller ve sesler yerine özgün tasarımlar
- **İngilizce dil desteği:** altyapı hazır (`localization/strings.csv`)
- **Premium dünya paketleri:** içerik modelinde `isPremium` alanı hazır; ödeme entegrasyonu yok
- **iOS sürümü**

## Bilinen sorunlar ve kararlar

- **Kapanış uyarısı:** oyun, müzik başladıktan 1–2 sn içinde kapatılırsa Godot bir sızıntı uyarısı yazar. Oyun sırasında sızıntı yoktur.
- **İlk kullanım takılması:** mağarada ölçüm sırasında bir kez 280 ms takılma görüldü; muhtemelen grafik derlemesi. Cihazda kontrol edilmeli.
- **Kesir Köprüsü kalıcı değil:** tekrar oynamada yeniden çözülür (alıştırma amaçlı bilinçli tercih).
- **İstatistik birleştirme:** iki cihazdan gelen konu istatistiklerinde en büyük değer alınır; bir kısmı eksik sayılabilir.
- **Belirteç saklama:** Android Keystore yerine uygulama alanında şifreli dosya kullanılıyor.
- **Görseller:** tüm karakter ve nesneler kodla çiziliyor; geçicidir.

## Önemli dosyalar

| Dosya | İçerik |
|---|---|
| `README.md` | Kurulum, çalıştırma, test komutları |
| `docs/GDD.md` | Oyun tasarım dokümanı |
| `docs/RELEASE.md` | Yayın listesi, Veri güvenliği yanıtları, sunucu ayarları, güvenlik gözden geçirmesi |
| `docs/COMPLIANCE.md` | Çocuk güvenliği ve uyum değerlendirmesi |
| `docs/PLAYTEST.md` | Çocuklarla test protokolü |
| `game/data/` | Dünya kataloğu, bölüm haritaları, soru şablonları |
| `%USERPROFILE%\.mathkings\` | Yükleme anahtarı ve şifresi (repo dışında; yedeklenmeli) |
