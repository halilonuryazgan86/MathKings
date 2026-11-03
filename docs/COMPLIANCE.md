# Çocuk Güvenliği ve Uyum — Değerlendirme Listesi

> Bu liste teknik durumu gösterir; **hukuki görüş değildir**. "Doğrulanmadı" maddeleri yayından önce
> bir KVKK/bilişim hukukçusu ve Google Play politika incelemesiyle kapatılmalıdır.

## Uygulanmış teknik önlemler (Sprint 3)
| Konu | Durum |
|---|---|
| Hesap sahibi yetişkin; çocuk yalnızca profil | Yapıldı: kayıtta 18+ beyanı + rıza sürümü zorunlu |
| Ebeveyn kapısı (hesap ekranlarından önce) | Yapıldı: tarafsız doğum yılı sorusu, saklanmaz, 18 altı yanıtta 5 dk kilit |
| Çocuktan gerçek ad/kişisel veri alınmaması | Yapıldı: takma ad listeden; sunucu yalnızca harf/boşluk kabul eder (e-posta, telefon girilemez) |
| Saklanan veri en aza indirildi | Yapıldı: ebeveyn e-postası, şifre özeti, rıza sürümü/zamanı; profil: takma ad, sınıf, karakter, ilerleme |
| Şifreler düz metin saklanmaz | Yapıldı: ASP.NET Core Identity (PBKDF2) |
| Güvenli oturum | Yapıldı: 15 dk erişim + 30 gün yenileme belirteci; çıkışta iptal; cihazda şifreli dosya, erişim belirteci yalnızca bellekte |
| Kaba kuvvet / hesap tespiti | Yapıldı: 5 hatada 15 dk kilit, IP başına istek sınırı, kayıt/şifre sıfırlamada aynı yanıt |
| Hesap ve verilerin silinmesi (oyun içinden) | Yapıldı: şifre onaylı kalıcı silme (profil ve ilerleme dahil) |
| Sohbet, mesajlaşma, reklam, analitik SDK | Yok |
| Ödeme | Yok (Premium ileride, yetişkin kontrollü) |
| HTTPS | Üretimde zorunlu (HSTS + yönlendirme); geliştirmede yerel HTTP |

## Doğrulanmadı / yapılacak
- **KVKK aydınlatma metni ve açık rıza metni:** oyundaki metin TASLAK. Veri sorumlusu bilgisi, saklama süreleri, yurt dışı aktarım (sunucu konumu), başvuru kanalı eklenmeli.
- **Veli onayı yöntemi:** şu an e-posta doğrulaması + 18+ beyanı. Yeterliliği hukuken teyit edilmeli.
- **Google Play Families Policy:** hedef kitle beyanı, Data Safety formu, "Teacher Approved" başvurusu (isteğe bağlı), gizlilik politikası URL'si.
- **Gizlilik politikası** web sayfası (mağaza zorunlu).
- **Gerçek e-posta gönderici** (SMTP/servis) ve e-posta şablonları; şu an yalnızca geliştirme log'u. Üretimde API başlamaz (kasıtlı).
- **Saklama süreleri:** uzun süre kullanılmayan hesapların silinmesi politikası.
- **Android Keystore** ile belirteç saklama (şu an uygulama alanında şifreli dosya).
- **Sunucu barındırma:** konum (KVKK yurt dışı aktarım), yedekleme, şifreli disk, log'larda kişisel veri olmaması.
- **Soru içerikleri:** öğretmen incelemesi (`data/questions/*.json` → `reviewStatus`).
