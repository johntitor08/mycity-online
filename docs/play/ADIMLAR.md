# Play Store'a yükleme adımları

Hazır olanlar (bu klasörde): imzalı **AAB** (`build/android/MyCityOnline.aab`), simge, öne çıkan görsel, 8 ekran görüntüsü,
mağaza metni (`magaza.md`), form cevapları (`formlar.md`), gizlilik politikası (`../gizlilik.md`).

1. **Geliştirici hesabı:** https://play.google.com/console → kişisel hesap, 25 $ tek seferlik ücret, kimlik doğrulaması (birkaç gün sürebilir).
2. **Uygulama oluştur:** Ad "MyCity Online", varsayılan dil Türkçe, tür **Oyun**, **Ücretsiz**.
3. **Mağaza kaydı:** `magaza.md`'deki kısa/uzun açıklama; `icon_512.png`, `feature_1024x500.png`, `ekran/` klasöründeki görüntüler.
4. **Uygulama içeriği:** `formlar.md`'deki cevaplarla gizlilik politikası, reklam, uygulama erişimi, içerik derecelendirmesi,
   hedef kitle ve **veri güvenliği** formlarını doldur.
5. **Kapalı test:** Test → Kapalı test → kanal oluştur → `MyCityOnline.aab`'yi yükle → en az **12 test kullanıcısı** ekle,
   katılım bağlantısını paylaş. Play App Signing'i kabul et (Google uygulamayı kendi anahtarıyla imzalar; bizim anahtar "yükleme anahtarı").
6. **14 gün** sonra: Üretim → "Üretime erişim başvurusu". Onaylanınca aynı AAB'yi üretime gönder.

Yükleme anahtarı: `~/.android-keys/mycity-upload.jks` (şifresi yanındaki `.txt`). **Yedekle**; kaybolursa Play Console'dan sıfırlatmak gerekir.
Her yeni sürümde `version/code` bir artırılmalı (export_presets.cfg → Android).
