# MyCity Online (Godot 4.6)

Çok oyunculu 2D şehir oyunu: arsa al ve üzerine bina dik, kumarhanede bahis oyna,
Texas Hold'em poker oyna, gölde ve denizde balık tut, plajda yüz, hastanede doktor ve
markette kasiyer olarak çalış. Şifreli hesaplar, karakter özelleştirme, müzik ve ses efektleri var.

![Şehir](docs/ekran/sehir2.png)

| | |
|---|---|
| ![Plaj](docs/ekran/plaj.png) | ![Poker](docs/ekran/poker.png) |
| ![Arsalar](docs/ekran/arsalar.png) | ![Karakter](docs/ekran/karakter_duzenle.png) |

## Çalıştırma

```sh
./oyna.sh            # oyunu aç
./sunucu.sh 7777     # ekransız adanmış sunucu (isteğe bağlı)
./duzenle.sh         # Godot düzenleyicisinde aç
./test.sh            # otomatik testler
```

Menüde:
- **Sunucu Kur ve Oyna**: Bu bilgisayar sunucu olur, sen de oynarsın.
- **Sunucuya Katıl**: Arkadaşının IP adresini ve portunu yazıp bağlan.
- **Karakterini Düzenle**: Ten rengi, saç modeli (kısa/uzun/topuz/kirpi/kel), saç, tişört ve
  pantolon rengi. Oyun içinde sol üstteki **Karakter** butonuyla da değiştirilebilir.

## Hesaplar

Bir isimle ilk girişte hesap o şifreyle oluşturulur; sonraki girişlerde aynı şifre gerekir
(isim büyük/küçük harf duyarsız). Aynı hesap aynı anda iki kez giremez. Para, balıklar,
arsalar ve karakter görünümü hesaba kaydedilir.

Şifre ağa düz metin olarak gitmez: istemci isimle birlikte SHA-256 özetini gönderir, sunucu bu
özeti rastgele bir tuzla bir kez daha özetleyerek saklar. ENet bağlantısı şifrelenmediği için
bu, şifrenin kendisini korur ama tam bir güvenlik katmanı değildir; başka sitelerde kullandığın
bir şifreyi kullanma. Eski (şifresiz) kayıtlarda ilk girişte yazılan şifre hesaba bağlanır.

## Arkadaşlarla internetten oynamak

Sunucu UDP **7777** portunu dinler (ENet).
- **Aynı ağ (ev/okul Wi-Fi)**: Sunucunun yerel IP'sini (`ip a`, ör. 192.168.1.20) gir. Hemen çalışır.
- **İnternet**: Sunucuyu kuranın modeminde UDP 7777'yi o bilgisayara yönlendirmesi (port forwarding)
  gerekir; katılanlar sunucunun dış IP'sini girer.
- **Port açmadan**: Tailscale / ZeroTier / Radmin VPN ile sanal ağ kur, VPN IP'sini kullan.
- **7/24 sunucu**: Bir VPS'e projeyi kopyala, `./sunucu.sh` (veya
  `godot --headless --path . -- --sunucu --port=7777`) çalıştır.

Oyuncu verileri (para, balıklar, arsalar) sunucuda `user://mycity_kayit.json` dosyasına kaydedilir
(Flatpak'te: `~/.var/app/org.godotengine.Godot/data/godot/app_userdata/MyCity Online/`).
Hesaplar oyuncu adına bağlıdır; aynı adla tekrar girersen paran ve arsaların geri gelir.

## Oynanış

| Yer | Ne yapılır | Kazanç |
|---|---|---|
| Emlak Ofisi / arsalar | 12 arsa; satın al, Küçük ev → Villa → Gökdelen dik, %70'e geri sat | Her dakika kira (çevrimdışıyken de) |
| Kumarhane | Rulet (renk/tek-çift x2, sayı x36), Zar (x2 / tam 7 x5), At yarışı (x2.5–x12) | Şans |
| Poker Salonu | 6 kişilik Texas Hold'em, körler 10/20, yan potlar, bot ekleme | Diğer oyunculardan |
| Göl iskelesi | Oltayı at, balık vurunca ÇEK; 8 tür göl balığı (Altın Balık 1.500–3.000 TL) | Balık satışı |
| Deniz iskelesi | Deniz balıkları: palamut, lüfer, orkinos, kılıç balığı, köpekbalığı, hazine sandığı (8.000 TL'ye kadar) | Balık satışı |
| Plaj | Palmiyeler, şemsiyeler, şezlonglar, cankurtaran kulesi; denize girip yüzebilirsin (yavaşlarsın) | — |
| Hastane | Belirtiye göre doğru tedaviyi seç, 12 sn süre | 25–49 TL, yanlışta -15 |
| Market | Sepeti topla, doğru para üstünü ver, 25 sn süre | 50–125 TL, yanlışta -20 |

Kontroller: **WASD/Oklar** yürü, **E** binaya gir, **Esc** kapat, **Enter** sohbet, **fare tekerleği** yakınlaştır.
Sol üstte **Ses** (tümünü kapat/aç) ve **Müzik** düğmeleri var; tercih kaydedilir.

## Ses ve müzik

Tüm sesler `tools/make_sounds.py` ile sentezlenir (numpy + scipy): şehir müziği (35 sn döngü),
plaja yaklaştıkça yükselen dalga sesi ve 17 efekt (tık, para, rulet tıkırtısı, zar, at nalı,
kart, fiş, olta, balık vurdu, yakalama, kazanma/kaybetme...). Değiştirmek için betiği düzenleyip
`python3 tools/make_sounds.py` çalıştır.

## Görseller

Tüm çizimler bu proje için yazılmış SVG'lerdir (`assets/`), lisans derdi yoktur:
binalar, arsa yapıları (küçük ev, villa, gökdelen), ağaçlar/çalılar ve karakterler.

Karakterler beyaza yakın çizilmiş katmanlardır ve oyun her birini seçilen renkle boyar:
`legs` (pantolon), `skin` (ten + yüz), `shirt` (tişört) ve 4 saç modeli (`hair_*`).
Her katmanda 3 yön × 3 kare yürüme animasyonu vardır; sola bakış sağ yönün aynalanmasıdır.
Denizdeyken sadece belden yukarısı çizilir.

Görselleri değiştirmek için `tools/make_art.py` içindeki çizimleri düzenleyip
`python3 tools/make_art.py` çalıştır (veya SVG'leri doğrudan Inkscape'te düzenle);
Godot düzenleyicisi açılınca yeniden içe aktarır. Bina tabelalarındaki yazıyı oyun çizer
(SVG'de y=86..118 aralığı boş tabela).

## Mimari

Sunucu yetkilidir: istemciler yalnızca istek (`req_*`) gönderir; zar, kart, balık, ödeme gibi tüm
sonuçları sunucu belirler. Bu yüzden istemci tarafında hile yapılamaz.

```
scripts/
  net.gd      (autoload) bağlantı, oyuncular, para, sohbet, konum senkronu, kayıt dosyası
  land.gd     (autoload) arsalar ve kira
  casino.gd   (autoload) rulet, zar, at yarışı
  poker.gd    (autoload) Texas Hold'em kuralları, el değerlendirme, botlar
  jobs.gd     (autoload) balık, hastane, market
  sfx.gd      (autoload) ses efektleri, müzik, dalga ambiyansı (yalnızca istemcide)
  avatar.gd   karakter seçenekleri ve katmanlı çizim
  map.gd      harita yerleşimi (ortak sabitler)
  world.gd    şehir çizimi, hareket, bina girişleri
  main.gd     menü, sunucu/test modları
  ui/         HUD ve bina pencereleri
assets/       SVG görseller (binalar, arsalar, doğa, plaj, karakter katmanları) ve WAV sesler
tools/        make_art.py (görseller), make_sounds.py (sesler)
assets/       SVG görseller (binalar, arsalar, doğa, karakter katmanları)
tools/        make_art.py: görsel üreteci
tests/        otomatik test istemcisi ve ekran görüntüsü modu
fonts/        DejaVu Sans (kart ♠♥♦♣ ve zar simgeleri için yedek font; lisansı LICENSE-DejaVu.txt)
docs/ekran/   ekran görüntüleri
```

## Sonraki adımlar için fikirler

- Bağlantı şifreleme (ENet DTLS) ve şifre değiştirme
- Plaja büfe/dondurmacı işi, sörf ya da tekne gezisi; şapka/gözlük gibi aksesuarlar
- Oyuncular arası para gönderme, arsa takası, araba/ev eşyası mağazası
- Windows/Android çıktısı: Düzenleyici → Proje → Dışa Aktar (export şablonları gerekir)
