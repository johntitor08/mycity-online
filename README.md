# MyCity Online (Godot 4.6)

Çok oyunculu 2D şehir oyunu: arsa al ve üzerine bina dik, kumarhanede bahis oyna,
Texas Hold'em poker oyna, gölde ve denizde balık tut, plajda yüz, hastanede doktor ve
markette kasiyer olarak çalış. Seviye/XP, meslek yetenekleri, enerji, eşyalar ve günlük görevlerle
RPG sistemi; şifreli hesaplar, karakter özelleştirme, müzik ve ses efektleri var. Çiftlik ve mevsimler,
klanlar ve sohbet kanalları, yarış/turnuva/hazine avı/festival etkinlikleri, polis ve suç sistemi (0.6);
Çarşı ve aksesuarlar, banka ve borsa, belediye seçimi, düğün ve aile (0.7); başarımlar ve unvanlar,
mini harita, açık deniz ve Martı Adası, mevsimlik eğlence, plaj futbolu ve langırt (0.8); taksi, kargo,
itfaiye ve çöpçülük meslekleri, nehir/park/otobüs, ev partileri, ayarlar ve eğitim turu (0.9); Sanayi Limanı,
feribot ve fabrika, haftalık lig, mevsim/gece müzikleri, yönetici komutları ve otomatik yedekler (1.0).

**İndir (Windows / Linux):** https://johntitortheprog.itch.io/mycity-online
**Resmi sunucu:** `traded-rolled.tun.ply.gg:12861` (menüde "Resmi Sunucuya Katıl")

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

## 1.4: Lunapark, havalimanı ve balon, dedektiflik, okul

| | |
|---|---|
| ![Lunapark](docs/ekran/lunapark.png) | ![Çarpışan arabalar](docs/ekran/carpisan.png) |
| ![Atış poligonu](docs/ekran/atis_poligonu.png) | ![Havalimanı](docs/ekran/havalimani.png) |
| ![Balon turu](docs/ekran/balon.png) | ![Dedektif](docs/ekran/dedektif_dosya.png) |
| ![Şüpheli](docs/ekran/dedektif_supheli.png) | ![Okul](docs/ekran/okul_sinav.png) |

- **Fuar ve Havalimanı:** Merkez taksi durağının doğusundaki **servisle** (20 TL) gidilen yeni bölge.
- **Lunapark:** Gişeden jeton al (5 jeton 40 TL).
  - **Dönme dolap:** 30 saniyelik tur, herkes görür.
  - **Çarpışan arabalar:** 60 sn; oyunculara ve NPC arabalara çarptıkça puan. Çarpışmayı sunucu denetler.
  - **Atış poligonu:** Ördekleri vur; üç sıra, altın ördek 5 puan. Hedefleri sunucu üretir.
  - **Pamuk şeker.** Biletleri ödül standında Dev Lolipop, Peluş Ayı, Dev Peluş Zürafa ve
    Lunapark Feneri'ne çevir (eşyalar evine konur).
- **Havalimanı:** Terminalden şehre, Martı Adası'na, dağ köyüne ya da Sanayi Limanı'na hızlı uçuş
  (uçuş animasyonu); pistte kalkan uçaklar.
- **Sıcak hava balonu:** 45 saniyelik şehir turu. Kamera uzaklaşır; balonu herkes gökyüzünde görür;
  turda fotoğraf modu kullanılabilir.
- **Dedektiflik:** Karakolun yanındaki **Dedektif Ferhat**'tan vaka al. Her vakada şehrin, Sanayi'nin ve
  dağın farklı yerlerinde 3 ipucu ve sorgulanacak 3 şüpheli var ("Haritada göster" ile yol tarifi).
  Delilleri birleştirip suçluyu seç; yanlış suçlama bekletir ve ödülü azaltır. 4 vaka: Kayıp Altın Balık,
  Bankada Sahte Para, Dağ Evi'nin Kayıp Erzakı, Müzeden Kaybolan Fosil.
- **Okul:** Bankanın doğusunda. 7 kurs; her biri sunucuda puanlanan 5 soruluk sınavla bitiyor. Diplomalar
  kalıcı bonus verir:
  - Aşçılık: %30 ihtimalle 2 porsiyon
  - Sürücü: araç %10 daha hızlı
  - Müzik: sahne kazancı +%20
  - Dalgıçlık: +20 sn oksijen
  - Finans: kira +%10
  - Binicilik: yarışta +%3 hız
  - İlk Yardım: hastane maaşı +%15
- Yeni başarımlar ve unvanlar: Çarpışma Kralı, Keskin Nişancı, Bilet Avcısı, Pilot, Gökyüzü Gezgini,
  Dedektif, Baş Dedektif, Profesör.

## 1.3: Telefon ve fotoğraf, güvenli takas, at ve hipodrom, kamp, animasyonlar

| | |
|---|---|
| ![Telefon](docs/ekran/telefon.png) | ![Fotoğraf modu](docs/ekran/foto_modu.png) |
| ![Takas](docs/ekran/takas.png) | ![Hara](docs/ekran/hara.png) |
| ![Hipodrom](docs/ekran/hipodrom.png) | ![Kamp](docs/ekran/kamp.png) |
| ![Olta: atış](docs/ekran/olta_atis.png) | ![Olta: vurdu](docs/ekran/olta_vurdu.png) |

- **Telefon (P):** Mesajlar çevrimdışı oyuncuya da ulaşır (gelen kutusu kalıcı). Arkadaş listesi:
  karşılıklı arkadaşsanız birbirinizin nerede olduğunu görür, yol tarifi alırsınız. Şehir haberleri
  (tüm duyurular) ve fotoğraf albümü.
- **Fotoğraf modu (O):** arayüz gizlenir; 1-7 filtre (siyah-beyaz, sepya, sıcak, soğuk, vintage, poster),
  tekerlekle yakınlaştır, N ile isimleri gizle, Boşluk ile çek. Fotoğraflar albüme (user://album) kaydedilir.
- **Güvenli takas:** Yanındaki oyuncunun adına tıkla → "Takas teklif et" (ya da sohbette `/takas isim`).
  Para, balık, ambar ürünleri ve çanta yiyecekleri koyulur; iki taraf da onaylayınca sunucu her şeyi
  yeniden denetleyip takası tek seferde yapar. Teklif değişirse onaylar sıfırlanır, uzaklaşınca iptal olur.
- **At çiftliği (Hara, Sanayi):** At al (en fazla 2), yem ya da mısırla besle, antrenmanla hız ve
  dayanıklılık geliştir. **H** ile atına bin (karada).
- **Hipodrom:** Atınla yarışa katıl, boş kulvarları NPC atlar doldurur. Bekleme sırasında herkes bahis
  oynar (oranlar atların gücüne göre). Yarışta **Boşluk = kamçı**: hızlandırır ama dayanıklılığı bitirir.
  İlk üçe ödül, kazanan ata +1 hız. Yeni yetenek **Binicilik**.
- **Kamp ve orman (dağ eteği):** Mantar, kuzugöbeği, böğürtlen, yaban mersini, kozalak ve odun topla.
  Kamp ateşi yak (2 odun), başında enerji daha hızlı dolar, marshmallow kızart. Dağ Evi'nden çadır al,
  kamp alanına kur, içinde dinlen. Gece teleskoptan takımyıldızları izle, kayan yıldıza dilek tut.
  Yeni orman tarifleri ve müzede **Orman** koleksiyonu.
- **Animasyonlar:** olta artık belirgin (savrularak atış, şamandıra yayı, vurunca bükülen olta ve "!",
  sudan çırpınarak çıkan balık, kaçınca gevşeyen misina); kazmayla kaya kırarken savurma ve taş
  kıymıkları; tarlada ekim/sulama/hasat efektleri; arabada egzoz, teknede köpük izi, bisiklette pedal;
  para değişince yüzen tutar, seviye atlayınca parıltı, yemek pişince buhar; ağaçlar rüzgârda sallanır.
- **Çarpışmalar:** feribot artık adanın içinden geçmiyor (batıdan dolaşır); tekne gövdesi adanın kumsalına
  ve iskelelere giremez; diğer oyuncuların araba ve tekneleri engeldir; NPC arabalar birbirinin ve
  otobüsün içinden geçmez; ahır ve deniz fenerine çarpılır.

## 1.2: Dağ bölgesi, müze, restoran menüsü, konserler

| | |
|---|---|
| ![Dağ köyü](docs/ekran/dag_koyu.png) | ![Kayak](docs/ekran/kayak.png) |
| ![Maden](docs/ekran/maden.png) | ![Müze](docs/ekran/muze.png) |
| ![Konser](docs/ekran/konser.png) | ![Ritim oyunu](docs/ekran/ritim.png) |
| ![Restoran menüsü](docs/ekran/restoran_menu.png) | ![Teleferik](docs/ekran/teleferik.png) |

- **Dağ bölgesi:** Plajdaki (arsaların altı) **teleferikle** dağa çık (30 TL). Dağda:
  - **Maden ocağı:** Dağ Evi'nden kazma al, kayaların yanında **E'yi basılı tut**. Taştan kömür/demir,
    maden damarından gümüş/altın, kristalden elmas/ametist çıkar; ara sıra **fosil** bulunur.
    Yeni yetenek **Madencilik** değerli maden şansını artırır. Madenler Dağ Evi'nde satılır,
    Çarşı ilanlarına da konabilir.
  - **Kayak pisti:** Telesiyejle zirveye çık (kayak kirası 50 TL ya da kendi takımın), 12 kapıdan
    geçerek in. Yön tuşlarıyla dön, aşağı hızlan, yukarı yavaşla. Kaçan kapı +3 sn. Süreye göre ödül,
    pist rekoru ve yeni haftalık **Kayak ligi**.
  - **Dağ Evi:** kazma, kayak takımı, sıcak çikolata ve dağ gözlemesi, maden alımı.
- **Şehir Müzesi** (Sanayi bölgesi): balıklar, deniz hazineleri, fosiller, mineraller ve çiftlik ürünleri
  koleksiyonları. Bir parçayı ilk bağışlayan 200 TL alır, adı vitrine yazılır; bir koleksiyon
  tamamlanınca katkı veren herkese 1.500 TL.
- **Restoran menüsü:** Kafe ve restoranda pişirdiğin yemekleri menüye koy (kafe 3, restoran 8 çeşit),
  fiyatını belirle. NPC müşteriler fiyat makulse sipariş verir; oyuncular gelip yemek yer (enerji ve
  yemek bonusu hemen gelir). Kafende/restoranında da yemek pişirebilirsin.
- **Konserler:** Parktaki **sahnede** gitar, davul ya da klavye çal: ritim oyunu (**D F J K**).
  Çalınan notaları yakındaki herkes duyar. Seyirci ve birlikte çalan oyuncular (grup) kazancı artırır,
  seyirciler bahşiş verebilir. Yeni yetenek **Müzisyenlik** yeni şarkılar açar.
- Yeni başarımlar ve unvanlar: Madenci, Paleontolog, Kar Leoparı, Küratör, Koleksiyoncu, Lokantacı,
  Gurme, Müzisyen, Grup Üyesi, Ritim Ustası.

## 1.1: Hayvan çiftliği, yemek pişirme, dalgıçlık, özelleştirme

| | |
|---|---|
| ![Ahır](docs/ekran/ahir.png) | ![Mutfak](docs/ekran/mutfak.png) |
| ![Deniz altı](docs/ekran/deniz_alti.png) | ![Batık gemi](docs/ekran/batik_gemi.png) |
| ![Galeri](docs/ekran/galeri_ozellestir.png) | ![Boyalı ev ve araba](docs/ekran/boyali_ev_araba.png) |

- **Hayvan çiftliği:** Boş arsaya **Ahır** kur (3.000 TL, çiftçilik seviyesi 3). En fazla 6 hayvan:
  tavuk (yumurta), inek (süt), koyun (yün). Hayvanlar sadece tokken üretir; bir besleme 30 dakika
  yeter (yemle 10 TL ya da 2 buğdayla). Ürünler ambarda birikir, Hal'de satılır ya da mutfakta kullanılır.
- **Yemek pişirme:** Mobilyacı'dan **Ocak ve Tezgâh** alıp evine koy; ev panelinde tarifler çıkar.
  Menemen, ızgara balık, sütlaç, çorba, salata, kabak tatlısı, su böreği, çilekli pasta. Yemekler
  marketteki yiyeceklerden çok enerji verir, bazıları süreli bonus verir: **iş maaşı +%15**,
  **nadir balık şansı**, **XP +%10**. Bonuslar HUD'da görünür.
- **Dalgıçlık:** Açık denizde teknedeyken **V** ile dal. Deniz tabanında mercanlar, yosunlar, balık
  sürüleri ve bir **batık gemi** var. Kumdaki istiridyelerden inci (bazen Siyah İnci) toplanır;
  batıkta ara sıra **hazine sandığı** çıkar. Oksijen 25 sn, Galeri'den alınan **dalış tüpüyle** 60 sn;
  bitince otomatik yüzeye çıkarsın. İnciler balık kovasına girer, iskelede/Hal'de satılır.
- **Özelleştirme:** Galeri'de araba boyası (10 renk), jant (altın/siyah/krom) ve bisiklet rengi;
  kendi binanın dış boyası (arsa panelinde, 9 renk). Herkes görür.
- Yeni başarımlar: Zevk Sahibi, Çoban, Aşçıbaşı, İnci Avcısı, Kâşif.

## 1.0: Sanayi Limanı, lig ve sezonlar, yeni sesler, sağlamlık

| | |
|---|---|
| ![Liman](docs/ekran/liman.png) | ![Fabrika](docs/ekran/fabrika.png) |
| ![Lig](docs/ekran/lig.png) | ![Şampiyonlar](docs/ekran/sampiyonlar.png) |

- **Sanayi Limanı:** Açık denizin karşısında yeni kara: rıhtım, vinçler, konteyner sahası, liman
  iskelesi ve fabrika. **Feribot** şehir (batı plajındaki feribot iskelesi), Martı Adası ve Liman
  arasında sefer yapar (20 TL, fırtınada iptal); kendi teknenle de gidebilirsin.
  **Fabrika işi:** üretim bandından gelen parçayı doğru kutuya ayır (1 Kırmızı, 2 Mavi, 3 Sarı);
  seri yaptıkça kazanç artar ve bant hızlanır. Sunucu süreyi denetler (bot cevapları sayılmaz).
- **Lig ve sezonlar:** Her hafta bir sezon. Zenginlik, Balık, Yarış, Futbol ve Tecrübe ligleri; sezon
  sonunda her ligde ilk üçe 5.000/2.500/1.000 TL ve kalıcı rozet. Parktaki **Şampiyonlar Duvarı** ve
  HUD'daki "Lig" butonu geçmiş şampiyonları gösterir.
- **Sesler ve müzik:** Gece, kış ve yaz için ayrı müzikler (yumuşak geçişle), kuş cıvıltısı, martılar,
  rüzgâr, bina içi uğultu ve adım sesleri.
- **Balık tutma:** iskelede/teknede E ile balık paneli açılır (sağa yaslı; olta animasyonu görünür).
  Olta ancak hemen yanında su varken atılır (sunucu da denetler). Kova sol üstte görünür; balıklar
  iskelede, teknede ya da Pazar Yeri'ndeki Hal'de satılır.
  Otobüse de çarpışma geldi (içinden geçilmez, üstüne gelirse seni kenara iter).
- **Sağlamlık:** Kayıt dosyası açılışta ve 6 saatte bir `yedekler/` klasörüne yedeklenir (son 14).
  Yönetici komutları (sohbette): `/duyuru`, `/kick`, `/sustur isim dk`, `/hava`, `/etkinlik`,
  `/kaydet`, `/yedekle`, `/oyuncular`, `/yonetici isim` — sunucuyu kuran ya da `--yonetici=ad`
  ile başlatılan hesaplar yöneticidir. Sunucu oyuncu hızını denetler (ışınlanma hilesi geri alınır).
  Adanmış sunucuda durum sayfası: `http://127.0.0.1:<port+3>` (JSON: `/json`).

## Meslekler, şehir detayları, ev partileri, ayarlar ve eğitim (0.9)

| | |
|---|---|
| ![Yangın](docs/ekran/yangin.png) | ![Taksi](docs/ekran/taksi.png) |
| ![Park](docs/ekran/geri_donusum.png) | ![Parti](docs/ekran/parti.png) |

- **Yeni meslekler:** Taksi (arabanla duraktan iş al, yolcuyu al ve bırak; hızlıysan bahşiş, mesai
  sen bırakana kadar sürer), Kargo kuryesi (depodan 3 paket, adreslere teslim, 150 sn'de bitirirsen
  ikramiye), İtfaiye (göreve başla; görevli varken şehirde yangın çıkar, yanında E'yi basılı tutarak
  söndür; söndürülmeyen yangın arsaya hasar verir), Çöpçülük (sokaktaki torbaları topla, geri dönüşüme
  götür). Yön oku hedefi gösterir; sol üstte mesai durumu ve "Bırak".
- **Şehir detayları:** Hastane ile Market arasından göle akan nehir ve ana yolda taş köprü; gölün
  güneyinde Şehir Parkı (çeşme, çiçek tarhları, banklar, oyun saatini gösteren saat kulesi), çeşmeye
  bozuk para atıp dilek tutma; şehri dolaşan sarı otobüs ve 5 durak (biletle duraklar arası yolculuk).
- **Ev partileri ve ziyaret:** Ev sahibi evinin içinden parti başlatır (10 dk, kapı açık, şehre duyuru,
  disko ışıkları); misafirler XP ve enerji kazanır. Misafir defteri, 1-5 yıldız ev puanı (günde bir),
  dekor puanı ve "En Güzel Ev Yarışması" etkinliği.
- **Ayarlar ve erişilebilirlik:** Genel/müzik/efekt ses seviyeleri, tam ekran, kamera yakınlığı,
  arayüz ve yazı boyutu, renk körlüğü modu (kırmızı/yeşil yerine turuncu/mavi), tuş atama (menüde ve
  oyunda "Ayarlar"). İlk girişte adım adım eğitim turu (atlanabilir, Ayarlar'dan yeniden başlatılır).

## Başarımlar, harita, açık deniz, mevsimlik eğlence, futbol ve langırt (0.8)

| | |
|---|---|
| ![Futbol](docs/ekran/futbol.png) | ![Harita](docs/ekran/harita.png) |
| ![Ada](docs/ekran/ada.png) | ![Kış](docs/ekran/kis_kartopu.png) |

- **Başarımlar ve unvanlar:** 48 başarım (ilk av, Altın Balık, köpekbalığı, başhekim, gökdelen, pist
  rekoru, başkan, evlilik, şerif, milyoner, gol, langırt, kardan adam...). Her biri para ve XP verir;
  bir kısmı unvan açar (Deniz Kurdu, Başkan, Şerif, Golcü...). Seçtiğin unvan isminin üstünde görünür.
  HUD'da "Başarım" butonu.
- **Mini harita ve navigasyon:** Sağ altta mini harita (binalar, arsaların, oyuncular, görev
  işaretleri, hazine alanı). M ile büyük harita: bir yere tıkla ya da listeden seç (görev hedefi dahil),
  yön oku ve mesafe seni oraya götürür.
- **Açık deniz ve Martı Adası:** Harita güneye büyüdü. Derin denize yüzerek değil tekneyle gidilir.
  Deniz iskelesinin başında Kaptan Rüstem'in yanında tekne kirala (250 TL / 10 dk); iskeleden ya da
  kıyıdan F ile doğrudan tekneye bin. Martı Adası'nda deniz feneri (gece döner) ve en nadir balıkların
  çıktığı ada iskelesi; derin denizde tekneden balık tutmak da şanslıdır. Hazine adaya da saklanabilir.
- **Mevsimlik eğlence ve hava:** Sis ve yağmur sonrası gökkuşağı (balık şansı artar). Kışın çimende
  kardan adam yap (E), T ile fareye doğru kartopu at; yazın plajda dondurmacı (enerji). Mevsimlik
  etkinlikler: Kartopu Savaşı (kış), Hasat Festivali (sonbahar, Hal fiyatları ×1,5), Plaj Kupası (yaz).
- **Plaj futbolu:** Plajın doğusunda saha. Kırmızı ya da Mavi takıma katıl, topa yürüyerek vur
  (fizik sunucuda). 5 gol ya da 6 dakika; kazanan takıma ödül.
- **Langırt:** Plajdaki masada iki kişi ya da bota karşı; W/S veya fareyle çubukları oynat, 5 gol.

## Çarşı, banka ve borsa, belediye seçimi, düğün ve aile (0.7)

| | |
|---|---|
| ![Aksesuarlar](docs/ekran/carsi.png) | ![Borsa](docs/ekran/borsa.png) |
| ![Seçim](docs/ekran/baskan.png) | ![Düğün](docs/ekran/dugun.png) |

- **Çarşı:** Kuaför (5 özel saç boyası), Aksesuarcı (kasket, fötr, beyzbol şapkası, bere, kovboy
  şapkası; güneş/numaralı/kalp gözlük; atkı, papyon) ve Kuyumcu (pırlanta yüzük, altın kolye,
  Sv.10 altın taç). "Dene" ile önizle, al, "Giy". Alınanlar karakter penceresinden de seçilir;
  sunucu sahip olunmayan aksesuarı kabul etmez. Sokaktaki NPC'lerin bir kısmı da aksesuarlı.
- **Banka:** Para yatır/çek; mevduat oyun günü başına %3 faiz getirir (200.000 TL'ye kadar) ve
  soyulamaz. Kredi: seviye × 1.000 TL (en çok 25.000), %10 masraf, 3 oyun gününde ödenir; vadesi
  geçerse banka önce hesaptan sonra cepten tahsil eder.
- **Borsa (oyun içi sanal):** 6 şehir şirketi (MRKT, BALK, KMRH, EMLK, OTO, TARM). Fiyatlar
  dakikada bir dalgalanır ve şehirdeki olaylara tepki verir: balık tutuldukça BALK, hasat oldukça
  TARM, bahis oynandıkça KMRH, arsa/inşaat EMLK, araç satışı OTO, market/işletme satışları MRKT'yi
  yükseltir; fırtına balıkçılık ve tarımı vurur, festival market ve kumarhaneye yarar. Son bir
  saatin grafikleri, kâr/zarar takibi, %1 komisyon.
- **Belediye seçimi (Muhtarlık → Belediye Seçimi):** 90 dakikalık döngü: 30 dk aday başvurusu
  (Sv.5, 2.000 TL, slogan), 30 dk oylama (Sv.2, kişi başı 1 oy), sonra sonuç. Başkan vergi oranını
  belirler (%0–15, kira ve işletme satışlarından belediye kasasına), dönemde bir kez kasayı
  çevrimiçi herkese hibe olarak dağıtır, 30 dakikada bir etkinlik başlatır ve kasadan maaş alır.
  İsminin üstünde "BAŞKAN" rozeti çıkar.
- **Düğün ve aile:** Kuyumcu'dan yüzük al, sevdiğinin yanında sağ üstteki listeden ismine tıkla →
  "Evlenme Teklif Et" (ikiniz de Sv.4+). Kabul edilirse şehirde düğün kutlaması (kalpler, konfeti,
  duyuru). Evliler: ortak aile kasası, birbirinin evine kapı kapalıyken de girebilir, birlikteyken
  %10 fazla XP, eşin mutlu evcil hayvanının bonusu. HUD'da "Aile" butonu; boşanma 5.000 TL.
- **Ağ:** ENet paketleri sıkıştırılıyor; VPN/tünel yollarında (MTU ~1280) büyük paketlerin
  kaybolup bağlantının kopması azalır.
- **0.7.1 — Olta animasyonu ve çarpışma:** Balık tutarken karakterin elinde olta, suda şamandıra;
  balık vurunca şamandıra batar ve halkalar yayılır, yakalanınca balık sudan sıçrar (herkes görür).
  Balık penceresi sağa yaslı açılır. Binaların, evlerin ve işletmelerin içinden yürünemez/araçla
  geçilemez (girişler kapının önünde); NPC arabaların içine girilemez, arabalar önlerindeki
  yaya ve araçlar için durur.

## Çiftlik, klanlar, etkinlikler, polis ve suç (0.6)

| | |
|---|---|
| ![Tarla](docs/ekran/tarla.png) | ![Festival](docs/ekran/festival.png) |
| ![Yarış](docs/ekran/yaris.png) | ![Karakol](docs/ekran/karakol.png) |

- **Çiftlik ve mevsimler:** Boş arsaya **tarla kur** (Sv.2, 1.200 TL): 6 tarh. Buğday, domates,
  mısır, lahana, çilek, balkabağı, karpuz ek (seviyeyle açılır). Ekinler gerçek zamanla büyür,
  çevrimdışıyken de. Sulanmayan ekin yarı verim verir; yağmur/kar kendiliğinden sular, fırtına
  büyüyen ekine zarar verebilir, olgun ekin uzun süre toplanmazsa çürür. Gübre +1 ürün.
  Mevsimler (her biri 3 oyun günü, ~2,4 saat) ekinin hızını, Hal fiyatını, havayı ve şehrin
  görünümünü değiştirir (sonbaharda sararan ağaçlar, kışın kar). Ürünleri Pazar Yeri'ndeki
  **Hal**'de sat, pazarda ilana koy ya da işletmene malzeme yap. Yeni yetenek: Çiftçilik.
- **Klanlar:** HUD'daki **Klan** butonu. Klan kur (Sv.3, 5.000 TL, 2-4 harflik etiket) ya da
  katıl (açık klan / başvuru). Ortak kasa (herkes yatırır, lider çeker), en fazla 10 üye. Üyelerin
  kazandığı XP ve etkinlik zaferleri klan puanı getirir; klan seviyesi her üyenin maaşını artırır
  (+%2/seviye). Klanlar arası sıralama; isimlerin önünde [ETİKET] görünür.
- **Sohbet kanalları:** Genel / Klan / Yakın (700 px) seçicisi; kısayollar `/k mesaj`, `/y mesaj`,
  `/m isim mesaj` (özel). Sağ üstte bir isme tıklayınca "Özel Mesaj Yaz".
- **Etkinlikler:** Sunucu ~9 dakikada bir sırayla etkinlik başlatır, üstte bant çıkar:
  **Yarış Günü** (pistte en hızlı tur), **Balık Turnuvası** (en değerli tek balık),
  **Hazine Avı** (sarı alanda saklı sandığı ilk bulan 4.000 TL alır), **Şehir Festivali**
  (maaşlar +%25, işletmelere 1,5 kat müşteri, bayraklar, gece havai fişek). İlk üçe para, XP ve
  klan puanı.
- **Yarış pisti:** Ana yolun doğu ucundaki damalı bayraktan tur başlat (her zaman açık):
  batı ucu → güneydeki yolun sonu → doğu yolu → bitiş. Sunucu kontrol noktalarını denetler,
  rekor tablosu tutulur.
- **Polis ve suç (G tuşu):** Seviye 3'ten itibaren yankesicilik (yakındaki oyuncu) ve soygun
  (başkasının evi, dükkân kasası ya da tarlası). Suç **aranma yıldızı** verir (3 dk'da bir düşer).
  Sokaktaki devriye ve görevdeki polisler arananları yakalar: hapis (yıldız × 45 sn), para cezası;
  **kefaletle** erken çıkılır. **Karakol**'da Sv.4'ten itibaren polis ol: arananları G ile tutukla,
  ihbar vakalarını çöz (yeni yetenek: Polislik). Güvenlik: Cüzdan Zinciri, Çelik Kilit ve Alarm.
  Seviye 3 altındaki oyuncular suç işleyemez ve soyulamaz.

## İşletmeler, evcil hayvanlar, NPC'ler ve hikâye (0.5)

- **İşletme:** Boş arsaya ev yerine **büfe** aç (Sv.2), sonra **kafe** (Sv.5) ve **restoran** (Sv.9).
  Malzeme koy (toptancı 10 birim/60 TL, ya da balık ve yiyecek), fiyatı (×0,5–×2) ve çalışan
  sayısını (0–3) ayarla. Her dakika NPC müşteriler gelir: öğle ve akşam yoğun, gece ve yağmurda
  az; ucuz fiyat, yüksek puan, çalışan ve dükkânda durman müşteriyi artırır. Malzeme bitince
  müşteri kaçar, puan düşer. Sen çevrimdışıyken de satış sürer; kasayı işletmende topla.
- **Evcil hayvan (Pet Shop):** Kedi (Sv.2, az enerji harcama), köpek (Sv.3, nadir balık),
  papağan (Sv.5, maaş bonusu). Arkandan gelir, herkes görür. Mama ya da balıkla beslenir;
  aç kalırsa bonus durur. HUD'daki "Evcil" butonuyla her yerden beslenir.
- **NPC'ler:** Kaldırımlarda yürüyen vatandaşlar (gece ve yağmurda azalır), yollarda arabalar,
  işletmelere giden müşteriler.
- **Hikâye görevleri:** Muhtar Rıza, Balıkçı Hasan Amca, Dr. Selma, Ayten Abla ve Kaptan Rüstem
  10 adımlık diyaloglu bir görev zinciri verir (başlarında "!" yeni görev, "?" ödül hazır).
  Yanlarına gidip E'ye bas. Görev günlüğü Muhtarlık'ta, o anki görev sol üstte.
- **Satın alma kolaylığı:** Para ya da seviye yetmiyorsa butonda nedeni yazar; Mobilyacı
  kullanılmayan mobilyayı yarı fiyatına geri alır.

## Gün/gece, hava, araçlar, pazar ve evler (0.4)

- **Gün/gece:** 1 oyun günü = 48 dakika (saat sunucu saatinden hesaplanır). Akşam şehir kararır,
  sokak lambaları, vitrinler ve ev içi ışıkları yanar. Gece "gece balıkları" (yayın, turna, levrek,
  lüfer, kalkan, köpekbalığı) 2 kat sık çıkar; hastane ve market gece vardiyası %20 fazla öder.
- **Hava:** Açık, bulutlu, yağmurlu, fırtına (sunucu birkaç dakikada bir değiştirir). Yağmurda balık
  daha çabuk vurur, plajın enerji bonusu kalkar; fırtınada deniz balıkçılığı ve tekne kapalı, şimşek çakar.
- **Araçlar (Galeri, F tuşu):** Bisiklet (Sv.2, 1.500 TL, 1,6× hız), Sürat Teknesi (Sv.4, 6.000 TL,
  denizde 2,2×, teknede açık deniz balıkçılığı), Araba (Sv.6, 12.000 TL, 2,4×, oyuncunun renginde).
- **Pazar Yeri:** Balık, yiyecek, mobilya ve arsa ilanı. Eşya satılana kadar emanette durur;
  satıcıya %5 komisyon düşülerek ödenir (çevrimdışıysa kaydına). İlan kaldırılınca eşya geri gelir.
- **Para gönderme:** Zenginler listesinde bir isme tıkla (Sv.3 gerekir, en fazla 100.000 TL).
- **Ev içi (Mobilyacı + arsadaki "Eve Gir"):** Ev, villa ve gökdelenin büyüyen birer odası var
  (12×8, 16×10, 18×12 karo). 13 çeşit mobilya; ev menüsünden "Yerleştir" → sol tık, sağ tık kaldır.
  Yatağın üstünde durmak enerjiyi ~20 kat hızlı doldurur, lambader gece ışık verir.
  Kapı açılırsa herkes girebilir; kilitlenince misafirler dışarı alınır.

## RPG sistemi

**C** tuşu (ya da HUD'daki "Profil") Karakter Kartı'nı açar.

- **Seviye/XP:** İşler, balık, poker kazançları, bahisler, arsa alma/inşa XP verir. Seviye atlayınca
  `100 × seviye` TL ödül ve dolu enerji. Kilitler: deniz balıkçılığı Sv.3, villa Sv.5, gökdelen Sv.10.
  Seviye isim etiketlerinde ve sıralamada görünür.
- **Meslek yetenekleri** (en fazla Sv.20), her seviye bonus verir:
  Balıkçılık (nadir balık +%8, çekme süresi +0,1 sn), Doktorluk (maaş +%5, süre +0,5 sn),
  Kasiyerlik (maaş +%5, süre +1 sn), Emlakçılık (kira +%5).
- **Enerji:** Balık tutmak 2, hastane/market vakası 3 enerji harcar. 20 sn'de 1 dolar;
  plajda ve denizde 3 kat hızlı. Maksimum `100 + 5 × (seviye − 1)`.
- **Market alışverişi:** Yiyecekler (simit, kahve, tost, döner: +10…+50 enerji) çantaya gider.
  Aletler kalıcıdır: Profesyonel Olta, Steteskop, Hesap Makinesi, Altın Kartvizit.
- **Günlük görevler:** Her gün oyuncuya özel 3 görev (balık tut, hasta iyileştir, pokerde kazan,
  denizde yüz...). Her biri +300 TL ve +80 XP.

Hepsi sunucuda hesaplanır ve hesap kaydına (`rpg` bölümü) yazılır.

## Hesaplar

Bir isimle ilk girişte hesap o şifreyle oluşturulur; sonraki girişlerde aynı şifre gerekir
(isim büyük/küçük harf duyarsız). Aynı hesap aynı anda iki kez giremez. Para, balıklar,
arsalar ve karakter görünümü hesaba kaydedilir.

Şifre ağa düz metin olarak gitmez: istemci isimle birlikte SHA-256 özetini gönderir, sunucu bu
özeti rastgele bir tuzla bir kez daha özetleyerek saklar. ENet bağlantısı şifrelenmediği için
bu, şifrenin kendisini korur ama tam bir güvenlik katmanı değildir; başka sitelerde kullandığın
bir şifreyi kullanma. Eski (şifresiz) kayıtlarda ilk girişte yazılan şifre hesaba bağlanır.

## itch.io'ya yükleme

```sh
butler push build/windows johntitortheprog/mycity-online:windows --userversion 1.4
butler push build/linux johntitortheprog/mycity-online:linux --userversion 1.4
```

## Hazır sürümü derlemek (Windows / Linux)

`export_presets.cfg` hazır. Godot 4.6.3 export şablonları kuruluyken:

```sh
godot --headless --path . --export-release "Linux" build/linux/MyCityOnline.x86_64
godot --headless --path . --export-release "Windows" build/windows/MyCityOnline.exe
```

Derlenmiş oyun tek dosyadır. Ekransız sunucu için: `MyCityOnline.exe --headless -- --sunucu`
(build klasörlerindeki `sunucu-baslat` dosyaları bunu yapar).

## 7/24 sunucu (VPS)

`deploy/` klasörü oyunu bir Ubuntu VPS'te systemd servisi olarak çalıştırır: çökünce ve sunucu
yeniden başlayınca otomatik açılır, UDP portunu açar, her gece kaydı yedekler (14 gün saklanır).

```sh
./deploy/kur.sh root@SUNUCU_IP        # kurar; aynı komut güncellemek için de kullanılır
./deploy/log.sh root@SUNUCU_IP        # canlı loglar (girişler/çıkışlar)
```

SSH anahtarı varsayılan olarak `~/.ssh/mycity_vps` (`MYCITY_SSH_KEY` ile değiştirilebilir).
Sunucuda: program `/opt/mycity`, kayıt ve yedekler `/var/lib/mycity`. Durdurma/yeniden başlatma
(`systemctl stop|restart mycity`) önce kaydı yazar, oyunculara duyuru yapar.
Oracle Cloud'da ayrıca web panelinden (VCN → Security List) UDP 7777 için giriş kuralı eklenmelidir.
Adres belli olunca `scripts/main.gd` içindeki `OFFICIAL_SERVER` doldurulursa menüde
"Resmi Sunucuya Katıl" butonu çıkar.

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

Kontroller: **WASD/Oklar** yürü, **E** binaya gir, **F** araca bin/in, **C** Karakter Kartı,
**Esc** kapat, **Enter** sohbet, **fare tekerleği** yakınlaştır.
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
  rpg.gd      (autoload) seviye/XP, yetenekler, enerji, eşyalar, günlük görevler
  env.gd      (autoload) gün/gece saati, hava durumu ve mevsimler
  garage.gd   (autoload) araçlar
  homes.gd    (autoload) ev içleri ve mobilyalar
  bazaar.gd   (autoload) pazar yeri ve para gönderme
  pets.gd     (autoload) evcil hayvanlar
  biz.gd      (autoload) işletmeler (dakikalık satış)
  story.gd    (autoload) hikâye görevleri ve NPC diyalogları
  farm.gd     (autoload) tarlalar, ekinler, Hal
  clans.gd    (autoload) klanlar, ortak kasa, klan puanı ve sıralaması
  events.gd   (autoload) zamanlanmış etkinlikler ve yarış pisti
  police.gd   (autoload) suç, aranma, hapishane, polislik, güvenlik ürünleri
  shops.gd    (autoload) Çarşı: kuaför, aksesuarcı, kuyumcu; gardırop
  bank.gd     (autoload) banka hesabı, kredi, sanal borsa
  election.gd (autoload) belediye seçimi, vergi, başkanlık
  family.gd   (autoload) evlilik, düğün, aile kasası
  achievements.gd (autoload, Ach) başarımlar ve unvanlar
  football.gd (autoload) plaj futbolu (sunucu fiziği)
  langirt.gd  (autoload) langırt masası (sunucu fiziği, bot)
  seasonal.gd (autoload) kardan adam, kartopu, dondurmacı
  work.gd     (autoload) taksi, kargo, itfaiye, çöpçülük, otobüs, çeşme
  party.gd    (autoload) ev partileri, misafir defteri, ev puanı
  settings.gd (autoload) oyuncu ayarları ve tuş atamaları (istemci)
  tutorial.gd (autoload) ilk giriş eğitim turu (istemci)
  league.gd   (autoload) haftalık lig/sezonlar, rozetler, Şampiyonlar Duvarı
  factory.gd  (autoload) fabrika üretim bandı işi
  npc_sim.gd  yürüyen vatandaşlar, trafik, müşteriler, evcil hayvan takibi (yalnızca istemci)
  lighting.gd gece ışıkları (CanvasModulate + PointLight2D)
  sfx.gd      (autoload) ses efektleri, müzik, dalga ambiyansı (yalnızca istemcide)
  avatar.gd   karakter seçenekleri ve katmanlı çizim
  map.gd      harita yerleşimi (ortak sabitler)
  world.gd    şehir çizimi, hareket, bina girişleri
  main.gd     menü, sunucu/test modları
  ui/         HUD ve bina pencereleri
assets/       SVG görseller (binalar, arsalar, doğa, plaj, karakter katmanları) ve WAV sesler
tools/        make_art.py (görseller), make_sounds.py (sesler)
tests/        otomatik test istemcisi ve ekran görüntüsü modu
deploy/       VPS kurulumu: systemd servisi, kurulum/güncelleme, yedekleme, log betikleri
fonts/        DejaVu Sans (kart ♠♥♦♣ ve zar simgeleri için yedek font; lisansı LICENSE-DejaVu.txt)
docs/ekran/   ekran görüntüleri
```

## Sonraki adımlar için fikirler

- Bağlantı şifreleme (ENet DTLS) ve şifre değiştirme
- Plaja büfe/dondurmacı işi, sörf ya da tekne gezisi; şapka/gözlük gibi aksesuarlar
- Oyuncular arası para gönderme, arsa takası, araba/ev eşyası mağazası
- Windows/Android çıktısı: Düzenleyici → Proje → Dışa Aktar (export şablonları gerekir)
