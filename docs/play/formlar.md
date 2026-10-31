# Google Play Console — Form cevapları (MyCity Online)

Play Console'da "Uygulama içeriği" bölümündeki formlar için hazır cevaplar. Gizlilik politikasıyla (`docs/gizlilik.md`) tutarlıdır.

## Gizlilik politikası
URL: https://github.com/johntitor08/mycity-online/blob/main/docs/gizlilik.md

## Uygulama erişimi
"Tüm işlevler özel erişim gerektirmeden kullanılabilir" → **Hayır, giriş gerekli.** İnceleme ekibine açıklama:
> Açılış ekranında herhangi bir oyuncu adı ve şifre yazıp "Resmi Sunucuya Katıl"a basın; hesap otomatik oluşturulur. Örnek: ad `PlayInceleme`, şifre `inceleme123`.

(İnceleme sırasında sunucunun açık olması gerekir — bilgisayar uykuya geçmesin.)

## Reklamlar
**Hayır**, uygulama reklam içermiyor.

## İçerik derecelendirmesi (IARC anketi)
- Kategori: **Oyun**
- Şiddet: **Evet — fantastik/çizgi film tarzı** (zindanda canavarlar, zombi geceleri, paintball). Kan yok, gerçekçi şiddet yok.
- Cinsellik, çıplaklık, küfür: **Hayır**
- Uyuşturucu, alkol, tütün: **Hayır**
- **Simüle kumar: Evet** (oyun parasıyla kumarhane, poker, at yarışı bahsi; gerçek para yok, oyun parası satılmaz)
- Kullanıcı etkileşimi: **Evet — kullanıcılar sohbet edebilir** (oyun içi sohbet; yönetici susturma/atma yapabilir)
- Kullanıcıların kişisel bilgi paylaşması: Sohbet üzerinden mümkün → **Evet**
- Konum paylaşımı: **Hayır** · Dijital satın alma: **Hayır**
- Beklenen sonuç: PEGI 12 / USK 12 / ESRB Teen civarı (simüle kumar nedeniyle)

## Hedef kitle ve içerik
- Hedef yaş grupları: **13–15, 16–17, 18 ve üzeri** (13 yaş altı seçilmemeli: sohbet ve simüle kumar var)
- Uygulama çocuklara hitap ediyor mu? **Hayır**

## Veri güvenliği formu
- Uygulama veri topluyor veya paylaşıyor mu? **Evet, topluyor.** Paylaşım: **Hayır.**
- Aktarım sırasında tüm veriler şifreleniyor mu? **Hayır** (Android sürümü UDP ile şifresiz bağlanır)
- Kullanıcılar verilerinin silinmesini isteyebilir mi? **Evet** (oyun içinden ve web üzerinden)
- Hesap oluşturma: **Kullanıcı adı ve şifre ile**
- Hesap silme bağlantısı (web): https://github.com/johntitor08/mycity-online/blob/main/docs/gizlilik.md#hesab%C4%B1n%C4%B1-silme

Toplanan veri türleri (hepsi **zorunlu**, amaç **Uygulama işlevselliği** ve **Hesap yönetimi**, işleme **geçici değil**):

| Play veri türü | Bizdeki karşılığı |
|---|---|
| Kişisel bilgiler → **Kullanıcı kimlikleri** | Oyuncu adı |
| Mesajlar → **Diğer uygulama içi mesajlar** | Oyun içi sohbet (sunucuda saklanmaz → "geçici olarak işlenir" seçilebilir) |
| Uygulama etkinliği → **Diğer kullanıcı tarafından oluşturulan içerik** / **Diğer işlemler** | Oyun ilerlemesi, tezgâh adları, ilanlar |

Toplanmayanlar: konum, kişiler, fotoğraf/video, ses, dosyalar, takvim, cihaz kimlikleri, finansal bilgiler, sağlık, web geçmişi, reklam kimliği.

## Haber uygulaması / COVID / devlet uygulaması
**Hayır.**

## Yeni kişisel geliştirici hesaplarında üretime çıkış şartı
Google, 2023 sonrası açılan kişisel hesaplarda üretime (herkese açık) çıkmadan önce **kapalı testte en az 12 test kullanıcısının 14 gün boyunca kesintisiz kayıtlı kalmasını** şart koşar. Adımlar:
1. Test → Kapalı test → yeni kanal → AAB'yi yükle
2. Test kullanıcılarını e-posta listesiyle ekle (en az 12 Google hesabı)
3. Katılım bağlantısını arkadaşlarına gönder; uygulamayı yüklesinler
4. 14 gün sonra "Üretime erişim başvurusu" yap
