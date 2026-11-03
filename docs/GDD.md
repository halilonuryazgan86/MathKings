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

## Matematik Savaşı (Sprint 2)
- Kristal Kapısı'nda Sayı Canavarı ile karşılaşılır; canavarın 5 kristal canı vardır.
- 4 büyük seçenekli soru. Doğru cevap = 1 hasar. Oyuncu can kaybetmez; savaş her zaman kazanılır.
- 1. yanlış: seçenek elenir, Baykuş adım ipucu verir. 2. yanlış: çözüm gösterilir, yeni soruya geçilir.
- Yıldız: ilk denemede doğru oranı ≥ %80 → 3, ≥ %50 → 2, aksi halde 1.
- Altın: ilk zafer 20 + her yeni yıldız 5. Tekrar oynamada yalnızca rekor artışı ödüllenir.
- Sorular `data/questions/numbers_forest.json` şablonlarından sınıfa göre üretilir
  (4: dört işlem; 5: + basit işlem önceliği; 6–7: parantez ve karma işlem önceliği).
  Bu dosya öğretmen incelemesinden geçmeden yayınlanmaz (`reviewStatus`).
- Konu başına çözülen/ilk denemede doğru sayısı kaydedilir (ileride uyarlanabilir zorluk için).

## Hesap ve bulut kayıt (Sprint 3)
- Hesap yalnızca yetişkine (veli) aittir; çocuklar hesaba profil olarak eklenir (en fazla 5).
- Hesap ekranlarına ebeveyn kapısından (doğum yılı) geçilerek ulaşılır.
- Oyun her zaman yerel kayıtla çalışır; hesaplı profilde değişiklikler 2 sn sonra arka planda gönderilir.
- Birleştirme kuralı (istemci = sunucu): toplananlar birleşir, tamamlanma VEYA, savaş yıldızı ve
  istatistik en büyüğü. Altın saklanmaz, ilerlemeden hesaplanır → iki cihaz birleşince çoğalmaz.
- Misafir ilerlemesi "Bu cihazdaki ilerlemeyi aktar" ile yeni profile taşınır.
- Oturum düşerse oyun durmaz; ilerleme cihazda kalır, tekrar girişte birleşir.
- Uyum maddeleri: `docs/COMPLIANCE.md`.

## Sonraki sprintler

## Açık yasal/uyum maddeleri (doğrulanmadı)
KVKK açık rıza ve veli onayı akışı, Google Play Families Policy, hesap silme gereksinimi,
gizlilik politikası. Sprint 3 öncesi hukuki görüş alınmalı.
