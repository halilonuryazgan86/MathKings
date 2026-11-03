# Matematik Krallığı — Kısa Oyun Tasarım Dokümanı

## Özet
Matematik Krallığı'nın kristalleri kaybolmuştur. Oyuncu bir kahraman seçer, haritaları keşfeder,
altın ve yıldız toplar, matematik mücadeleleriyle kristalleri geri kazanır.
Hedef: 9–12 yaş (4–7. sınıf), Android (sonra iOS), Türkçe (İngilizce'ye hazır).

## Temel ilkeler
- Matematik oyun mekaniğinin parçasıdır; yanlış cevap utandırmaz, ipucu verir.
- Karakterler yalnızca görsel olarak farklıdır; ücretli avantaj yoktur.
- Çevrimdışı önce: misafir oyuncu internetsiz oynar, ilerleme cihazda kalır.
- Çocuktan gerçek ad veya kişisel veri istenmez (takma ad listeden seçilir, sınıf bilgisi zorluk içindir).

## Dikey kesit akışı
Splash → Ana Menü (Misafir / Giriş* / Kayıt*) → Profil (takma ad + sınıf) → Kahraman seçimi
→ Baykuş tanıtımı → Sayılar Ormanı Bölüm 1 → Kristal Kapısı → (Sprint 2) Matematik Savaşı → Ödül ekranı.
*Sprint 3'e kadar "yakında".

## Sprint 1 kapsamı ve kabul kriterleri
| Konu | Kriter |
|---|---|
| Menüler | 3 giriş seçeneği; büyük butonlar (≥ 64 px); Türkçe karakterler doğru |
| Profil | Gerçek ad alanı yok; sınıf 4–7; kayıt sonrası tekrar sorulmaz |
| Hareket | Klavye + çoklu dokunmatik; coyote time, zıplama tamponu, değişken zıplama |
| Bölüm | Kontrol noktaları; düşme/diken = son bayraktan devam (ceza yok); 3 yıldız |
| Ödül | Her altın/yıldız bir kez ödüllendirilir; tekrar oynamada soluk görünür |
| Kayıt | Kapat-aç sonrası korunur; bozuk kayıtta çökme yok; arka plana alınınca kaydeder |
| Android | Debug APK cihazda kurulur, yatay ekranda oynanır, geri tuşu menü açar |

## Sayılar
- Tile 64 px; zıplama ≈ 2,75 tile yükseklik, ≈ 4,8 tile koşarak mesafe (ölçüldü).
- Harita kuralı: basamaklar ≤ 2 tile, boşluklar ≤ 3 tile.
- Altın = 1, yıldız = 10 altın.

## Sonraki sprintler
- S2: Matematik Savaşı (soru şablonları, ipuçları, sınıfa göre zorluk), bölüm sonu ödülü.
- S3: .NET 10 API, yetişkin hesabı + çocuk profili, misafir ilerlemesini aktarma, bulut kayıt.

## Açık yasal/uyum maddeleri (doğrulanmadı)
KVKK açık rıza ve veli onayı akışı, Google Play Families Policy, hesap silme gereksinimi,
gizlilik politikası. Sprint 3 öncesi hukuki görüş alınmalı.
