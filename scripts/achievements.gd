extends Node
## Başarımlar ve unvanlar. Oyun olayları sayaçları artırır (event / set_max); sayaç hedefi geçince başarım
## açılır, para ve XP ödülü verilir. Bazı başarımlar unvan açar; oyuncu bir unvan seçer, isminin üstünde görünür.
## Veri: rec["ach"] = {"got": {kimlik: unix}, "c": {sayaç: n}, "title": kimlik}

signal changed

const U = preload("res://scripts/util.gd")

# kimlik: [sayaç, hedef, ad, açıklama, ödül TL, unvan]
const LIST := {
	"fish1": ["fish", 1, "İlk Av", "İlk balığını tut.", 100, ""],
	"fish100": ["fish", 100, "Usta Balıkçı", "100 balık tut.", 2000, "Balıkçı Reis"],
	"goldfish": ["goldfish", 1, "Altın Balık!", "Gölden Altın Balık çıkar.", 3000, "Şanslı"],
	"shark": ["shark", 1, "Köpekbalığı Avcısı", "Bir köpekbalığı yakala.", 3000, "Deniz Kurdu"],
	"chest": ["chest", 1, "Batık Hazine", "Denizden hazine sandığı çıkar.", 3000, ""],
	"patient10": ["patient", 10, "Stajyer Doktor", "10 hastayı iyileştir.", 300, ""],
	"patient100": ["patient", 100, "Başhekim", "100 hastayı iyileştir.", 2500, "Doktor"],
	"customer100": ["customer", 100, "Kasa Ustası", "100 müşteriye doğru para üstü ver.", 2500, "Kasiyer"],
	"bet50": ["bet", 50, "Şans Oyuncusu", "Kumarhanede 50 bahis oyna.", 800, "Kumarbaz"],
	"poker10": ["poker", 10, "Poker Ası", "Pokerde 10 el kazan.", 2000, "Poker Kralı"],
	"swim": ["swim", 30, "Yüzücü", "Denizde uzun süre yüz.", 300, ""],
	"build1": ["build", 1, "Toprak Sahibi", "İlk arsanı al.", 300, ""],
	"tower": ["tower", 1, "Gökdelen", "Bir gökdelen dik.", 5000, "Emlak Kralı"],
	"biz": ["biz", 1, "Esnaf", "İlk işletmeni aç.", 500, ""],
	"restaurant": ["restaurant", 1, "Şef", "İşletmeni restorana büyüt.", 3000, "Şef"],
	"harvest1": ["harvest", 1, "İlk Hasat", "Tarlandan ilk ürünü topla.", 200, ""],
	"harvest30": ["harvest", 30, "Çiftçi", "30 kez hasat yap.", 2000, "Çiftçi"],
	"race1": ["race", 1, "Pist Çaylağı", "Yarış pistinde bir tur tamamla.", 200, ""],
	"record": ["record", 1, "Pist Rekoru", "Pist rekorunu kır.", 2000, "Pist Kralı"],
	"event_win": ["event_win", 1, "Şampiyon", "Bir şehir etkinliğini kazan.", 1500, "Şampiyon"],
	"treasure": ["treasure", 1, "Hazine Avcısı", "Hazine avında sandığı bul.", 1000, "Hazine Avcısı"],
	"level5": ["level", 5, "Yükselen Yıldız", "Seviye 5'e ulaş.", 500, ""],
	"level10": ["level", 10, "Tecrübeli", "Seviye 10'a ulaş.", 2000, ""],
	"level20": ["level", 20, "Efsane", "Seviye 20'ye ulaş.", 10000, "Efsane"],
	"rich10k": ["money", 10000, "Cebi Dolu", "Cebinde 10.000 TL olsun.", 300, ""],
	"rich100k": ["money", 100000, "Zengin", "Cebinde 100.000 TL olsun.", 2000, "Zengin"],
	"rich1m": ["money", 1000000, "Milyoner", "Cebinde 1.000.000 TL olsun.", 10000, "Milyoner"],
	"saver": ["deposit", 50000, "Tasarruf Ustası", "Bankada 50.000 TL biriktir.", 1000, ""],
	"investor": ["stock_profit", 1, "Borsacı", "Hisseyi kârla sat.", 500, "Borsacı"],
	"pet": ["pet", 1, "Can Dostu", "Bir evcil hayvan sahiplen.", 300, ""],
	"car": ["car", 1, "Direksiyon Başında", "Bir araba al.", 1000, ""],
	"boat": ["boat", 1, "Kaptan", "Bir tekne al.", 800, "Kaptan"],
	"fashion": ["wardrobe", 5, "Moda İkonu", "Gardırobunda 5 parça olsun.", 800, "Moda İkonu"],
	"clan": ["clan", 1, "Takım Oyuncusu", "Bir klana katıl ya da kur.", 300, ""],
	"married": ["married", 1, "Mutlu Son", "Evlen.", 1000, "Romantik"],
	"vote": ["vote", 1, "Seçmen", "Belediye seçiminde oy kullan.", 200, ""],
	"mayor": ["mayor", 1, "Sayın Başkan", "Belediye başkanı seçil.", 3000, "Başkan"],
	"patrol20": ["patrol", 20, "Devriye Gezgini", "20 ihbar vakası çöz.", 1500, ""],
	"arrest5": ["arrest", 5, "Şerif", "5 aranan oyuncuyu tutukla.", 2500, "Şerif"],
	"crime10": ["crime", 10, "Mahallenin Belası", "10 suç işle.", 0, "Haydut"],
	"jailed": ["jailed", 1, "Parmaklıklar Ardında", "Hapse gir.", 0, "Kaçak"],
	"story": ["story_done", 1, "Şehrin Gururu", "Hikâye görevlerinin hepsini bitir.", 5000, "Şehrin Gururu"],
	"goal1": ["goal", 1, "Gol!", "Plaj sahasında gol at.", 200, ""],
	"goal20": ["goal", 20, "Golcü", "20 gol at.", 2000, "Golcü"],
	"langirt": ["langirt_win", 1, "Langırt Ustası", "Langırtta maç kazan.", 500, ""],
	"snowman": ["snowman", 1, "Kardan Adam", "Kışın kardan adam yap.", 300, ""],
	"snowball": ["snowball_hit", 25, "Kartopu Savaşçısı", "Kartopuyla 25 kez isabet ettir.", 1000, "Kar Tanesi"],
	"icecream": ["icecream", 5, "Dondurma Sever", "Plajda 5 dondurma ye.", 200, ""],
	"taxi10": ["taxi", 10, "Taksici", "10 yolcuyu yerine ulaştır.", 1500, "Taksici"],
	"cargo20": ["cargo", 20, "Hızlı Kurye", "20 paket teslim et.", 1500, "Kurye"],
	"fire5": ["fire", 5, "İtfaiye Eri", "5 yangın söndür.", 2500, "İtfaiyeci"],
	"trash50": ["trash", 50, "Temizlik Kahramanı", "50 torba çöpü geri dönüşüme götür.", 1500, "Çevreci"],
	"bus": ["bus", 1, "Otobüs Yolcusu", "Otobüsle yolculuk et.", 100, ""],
	"wish": ["wish", 1, "Dilek Tut", "Parktaki çeşmeye bozuk para at.", 50, ""],
	"party": ["party", 1, "Ev Sahibi", "Evinde parti ver.", 300, ""],
	"party3": ["party_guests", 3, "Partinin Yıldızı", "Partine aynı anda 3 misafir gelsin.", 1500, "Parti Kralı"],
	"league_top": ["league_top", 1, "Kürsüde", "Bir lig sezonunu ilk üçte bitir.", 1000, ""],
	"league_win": ["league_win", 1, "Sezon Şampiyonu", "Bir lig sezonunu birinci bitir.", 3000, "Lig Şampiyonu"],
	"factory50": ["factory", 50, "Usta İşçi", "Fabrikada 50 parçayı doğru ayıkla.", 1500, "Usta"],
	"ferry": ["ferry", 1, "Denizci Yolcu", "Feribotla yolculuk et.", 100, ""],
	"custom": ["custom", 3, "Zevk Sahibi", "Aracını ya da evini 3 kez özelleştir.", 500, "Zevk Sahibi"],
	"ranch": ["ranch_products", 30, "Çiftçi Ailesi", "Ahırdan 30 ürün topla.", 1500, "Çoban"],
	"chef": ["cooked", 10, "Aşçıbaşı", "10 yemek pişir.", 1500, "Aşçıbaşı"],
	"dive1": ["dive", 1, "İlk Dalış", "Tekneden denize dal.", 200, ""],
	"pearl10": ["pearl", 10, "İnci Avcısı", "10 inci topla.", 2500, "İnci Avcısı"],
	"wreck": ["wreck", 1, "Batık Kâşifi", "Batık gemideki sandığı bul.", 3000, "Kâşif"],
	# 1.2
	"miner1": ["mined", 1, "İlk Kazma", "Dağda bir kaya kır.", 200, ""],
	"miner100": ["mined", 100, "Usta Madenci", "100 kaya kır.", 3000, "Madenci"],
	"diamond": ["diamond", 1, "Elmas!", "Bir elmas çıkar.", 2500, ""],
	"fossil": ["fossil", 1, "Paleontolog", "Bir fosil bul.", 800, "Paleontolog"],
	"summit": ["summit", 1, "Zirve", "Telesiyejle zirveye çık.", 300, ""],
	"ski1": ["ski", 1, "Kayakçı", "Kayak pistini bitir.", 400, ""],
	"ski_clean": ["ski_clean", 1, "Kusursuz İniş", "Hiç kapı kaçırmadan pisti bitir.", 1500, "Kar Leoparı"],
	"donate10": ["donate", 10, "Bağışçı", "Müzeye 10 parça bağışla.", 1500, "Küratör"],
	"museum_set": ["museum_set", 1, "Koleksiyoncu", "Tamamlanan bir müze koleksiyonuna katkı ver.", 2000, "Koleksiyoncu"],
	"menu50": ["menu_sold", 50, "Lokantacı", "Restoranında menüden 50 yemek sat.", 3000, "Lokantacı"],
	"gourmet": ["ate_out", 5, "Gurme", "Başka oyuncuların restoranlarında 5 kez yemek ye.", 1000, "Gurme"],
	"song1": ["songs", 1, "İlk Sahne", "Sahnede bir şarkı çal.", 200, ""],
	"songs20": ["songs", 20, "Müzisyen", "Sahnede 20 şarkı çal.", 2500, "Müzisyen"],
	"band": ["band", 1, "Grup Ruhu", "Sahnede başka bir oyuncuyla birlikte çal.", 1500, "Grup Üyesi"],
	"fullcombo": ["fullcombo", 1, "Ritim Ustası", "Bir şarkıyı hiç kaçırmadan çal.", 2000, "Ritim Ustası"],
	"tips10": ["tips", 10, "Sokak Sanatçısı", "Sahnede 10 bahşiş al.", 1000, ""],
	# 1.3
	"photo1": ["photos", 1, "Fotoğrafçı", "Fotoğraf modunda ilk fotoğrafını çek.", 200, ""],
	"photo25": ["photos", 25, "Objektif Ustası", "25 fotoğraf çek.", 1500, "Fotoğrafçı"],
	"friends5": ["friends", 5, "Sosyal Kelebek", "Arkadaş listene 5 kişi ekle.", 500, ""],
	"messages20": ["messages", 20, "Mesajlaşan", "Telefondan 20 mesaj gönder.", 500, ""],
	"trade1": ["trades", 1, "İlk Takas", "Bir oyuncuyla takas yap.", 300, ""],
	"trade10": ["trades", 10, "Tüccar", "10 takas yap.", 2000, "Tüccar"],
	"horse1": ["horse", 1, "At Sahibi", "Hara'dan bir at al.", 500, ""],
	"ride_horse": ["ride_horse", 1, "Süvari", "Atına bin.", 200, ""],
	"horse_win": ["horse_win", 1, "Jokey", "Hipodromda bir yarış kazan.", 2500, "Jokey"],
	"horse_win5": ["horse_win", 5, "Şampiyon Jokey", "Hipodromda 5 yarış kazan.", 5000, "Şampiyon Jokey"],
	"bet_horse": ["bet_horse", 1, "Şanslı Bahisçi", "Hipodromda bahis kazan.", 500, ""],
	"campfire": ["campfire", 1, "Ateşin Başında", "Bir kamp ateşi yak.", 300, ""],
	"marshmallow10": ["marshmallow", 10, "Kampçı", "10 marshmallow kızart.", 1000, "Kampçı"],
	"forage50": ["forage", 50, "Toplayıcı", "Ormandan 50 ürün topla.", 1500, "Toplayıcı"],
	"tent": ["tent", 1, "Doğa İnsanı", "Kamp alanına çadır kur.", 400, ""],
	"astronom": ["astronom", 1, "Astronom", "Gece teleskoptan yıldızları izle.", 500, "Astronom"],
	"wish_star": ["wish_star", 1, "Dilek Tutan", "Kayan yıldıza dilek tut.", 800, "Dilek Tutan"],
	# 1.4
	"fair": ["fair", 1, "Lunaparkta", "Fuar ve Havalimanı'na git.", 200, ""],
	"ferris": ["ferris", 1, "Dönme Dolap", "Dönme dolaba bin.", 300, ""],
	"bumper_king": ["bumper_king", 1, "Çarpışma Kralı", "Çarpışan arabalarda bir turda 15 çarpışma yap.", 1000, "Çarpışma Kralı"],
	"sharpshooter": ["sharpshooter", 1, "Keskin Nişancı", "Atış poligonunda 30 puan yap.", 1000, "Keskin Nişancı"],
	"bilet200": ["bilet", 200, "Bilet Avcısı", "Lunaparkta toplam 200 bilet kazan.", 1500, "Bilet Avcısı"],
	"prize": ["prize", 1, "Ödül Sahibi", "Ödül standından bir ödül al.", 300, ""],
	"flights": ["flights", 1, "İlk Uçuş", "Havalimanından uçağa bin.", 300, ""],
	"flights10": ["flights", 10, "Sık Uçan", "10 uçuş yap.", 1500, "Pilot"],
	"balloon": ["balloon", 1, "Gökyüzü Gezgini", "Sıcak hava balonuyla şehri turla.", 800, "Gökyüzü Gezgini"],
	"case1": ["cases", 1, "Dedektif", "İlk vakanı çöz.", 1000, "Dedektif"],
	"case4": ["cases", 4, "Baş Dedektif", "Bütün vakaları çöz.", 5000, "Baş Dedektif"],
	"diploma1": ["diplomas", 1, "Mezun", "İlk diplomanı al.", 500, ""],
	"diploma7": ["diplomas", 7, "Profesör", "Bütün kursların diplomasını al.", 5000, "Profesör"],
	# 1.5
	"candy25": ["candy", 25, "Şeker Avcısı", "Cadılar Bayramı'nda 25 şeker topla.", 1000, "Şeker Avcısı"],
	"costume": ["costume", 1, "Kılık Değiştiren", "Bir kostüm giy.", 300, ""],
	"gifts10": ["gifts", 10, "Hediye Avcısı", "Yılbaşında 10 hediye kutusu topla.", 1000, "Hediye Avcısı"],
	"santa": ["santa", 1, "Noel Baba'nın Dostu", "Noel Baba'dan hediye al.", 300, ""],
	"hands": ["hands", 3, "Bayramlaşma", "Bayramda 3 büyüğün elini öp.", 800, ""],
	"roses": ["roses", 1, "Romantik", "Sevgililer Günü'nde birine gül ver.", 500, "Romantik"],
	"workout10": ["workouts", 10, "Sporcu", "10 antrenman yap.", 1000, "Sporcu"],
	"fitness100": ["fitness", 100, "Atlet", "Kondisyon + kuvvet toplamı 100 olsun.", 3000, "Atlet"],
	"marathon": ["marathon", 1, "Maratoncu", "Şehir maratonunu bitir.", 500, "Maratoncu"],
	"pirate1": ["pirate_treasure", 1, "Korsan", "Korsan Adası'nda gömülü hazineyi bul.", 2000, "Korsan"],
	"pirate5": ["pirate_treasure", 5, "Korsan Kaptan", "5 gömülü hazine bul.", 6000, "Korsan Kaptan"],
	"zoo": ["zoo", 1, "Hayvansever", "Hayvanat bahçesini ziyaret et.", 300, ""],
	"keeper20": ["keeper", 20, "Bakıcı", "Gönüllü bakıcı olarak 20 kez yem taşı.", 1500, "Bakıcı"],
	"feeding": ["feeding", 3, "Besleme Saati", "3 besleme saatini izle.", 600, ""],
	"aquarium": ["aquarium", 1, "Akvaryum Gezgini", "Akvaryumu gez.", 300, ""],
	# 1.6
	"ocean": ["ocean", 1, "Açık Deniz", "Kendi teknenle Açık Okyanus'a açıl.", 500, ""],
	"isles10": ["isles", 10, "Kâşif", "Okyanusta 10 ada keşfet.", 1500, "Kâşif"],
	"isles30": ["isles", 30, "Haritacı", "Okyanustaki bütün adaları keşfet.", 8000, "Haritacı"],
	"visit15": ["isles_visited", 15, "Ada Ada", "15 farklı adanın sandığını aç.", 4000, "Ada Gezgini"],
	"chests25": ["ocean_chests", 25, "Sandık Avcısı", "Okyanusta 25 sandık aç.", 3000, "Sandık Avcısı"],
	"lights5": ["lighthouses", 5, "Fenerci", "5 deniz fenerini yak.", 2000, "Fenerci"],
	"boat_up": ["boat_up", 9, "Usta Kaptan", "Teknenin bütün yükseltmelerini tamamla.", 6000, "Usta Kaptan"],
	"kraken": ["kraken", 1, "Kraken Avcısı", "Kraken'i yenmeye katıl.", 3000, "Kraken Avcısı"],
	# 1.7
	"train": ["train", 1, "Yolcu", "Trenle yolculuk yap.", 300, ""],
	"films5": ["films", 5, "Sinemasever", "Sinemada 5 film izle.", 1500, "Sinemasever"],
	"karaoke": ["karaoke", 1, "Mikrofon Bende", "Karaokede şarkı söyle.", 300, ""],
	"karaoke_star": ["karaoke_star", 1, "Karaoke Yıldızı", "Karaokede %80 üstü puan al.", 2000, "Karaoke Yıldızı"],
	"island": ["island", 1, "Ada Sahibi", "Okyanusta bir ada satın al.", 3000, "Ada Sahibi"],
	"island_build": ["island_build", 7, "Ada Kralı", "Adandaki bütün yapıları kur.", 10000, "Ada Kralı"],
	"trader": ["trade_profit", 10000, "Tüccar", "Ticaretten toplam 10.000 TL kâr et.", 3000, "Tüccar"],
	"raid_sunk": ["raid_sunk", 1, "Korsan Avcısı", "Bir korsan gemisini batır.", 1500, ""],
	"paint_win": ["paint_wins", 1, "Boya Savaşçısı", "Bir paintball maçı kazan.", 500, ""],
	"paint_hits": ["paint_hits", 100, "Keskin Nişancı", "Paintballda 100 vuruş yap.", 3000, "Keskin Nişancı"],
	"paint_flags": ["paint_flags", 5, "Bayrak Avcısı", "Rakip bayrağı 5 kez üssüne getir.", 2000, ""],
	# 1.8
	"monster1": ["monsters", 1, "İlk Kan", "Zindanda ya da zombi gecesinde bir canavar yen.", 200, ""],
	"monster500": ["monsters", 500, "Canavar Avcısı", "500 canavar yen.", 8000, "Canavar Avcısı"],
	"dungeon5": ["dungeon_floor", 5, "Golem Kırıcı", "Zindanın 5. katını temizle.", 2500, ""],
	"dungeon10": ["dungeon_floor", 10, "Ejderha Avcısı", "Zindanın 10. katında ejderhayı yen.", 10000, "Ejderha Avcısı"],
	"dungeon20": ["dungeon_floor", 20, "Derinlerin Efendisi", "Zindanın 20. katına in.", 25000, "Zindan Efendisi"],
	"zombie_night": ["zombie_nights", 1, "Dolunay Gecesi", "Bir zombi gecesinden sağ çık.", 500, ""],
	"zombie100": ["zombie_kills", 100, "Zombi Avcısı", "100 zombi öldür.", 5000, "Zombi Avcısı"],
	"rescue10": ["rescues", 10, "Kahraman", "Zombi gecelerinde 10 vatandaş kurtar.", 3000, "Kahraman"],
	"rocket": ["rocket", 1, "Roket Bilimci", "Kendi roketini yap.", 2000, ""],
	"moon1": ["moon_trips", 1, "Ay'da İlk Adım", "Ay'a uç.", 1500, "Astronot"],
	"moon_rocks": ["moon_rocks", 100, "Ay Madencisi", "100 Ay Taşı kaz.", 5000, ""],
	"moon_base": ["moon_given", 50, "Üs Kurucu", "Ay üssüne 50 malzeme bağışla.", 4000, "Üs Kurucu"],
	"golf_ace": ["golf_aces", 1, "Tek Vuruş!", "Mini golfta deliği tek vuruşta bul.", 1500, ""],
	"golf_rounds": ["golf_rounds", 10, "Golf Tutkunu", "10 tur mini golf oyna.", 2000, "Golfçü"],
	"bowl_strike": ["bowling_strikes", 1, "Strike!", "Bowlingde strike yap.", 300, ""],
	"bowl200": ["bowling_best", 200, "Bowling Ustası", "Bir bowling oyununda 200 puan yap.", 4000, "Bowling Ustası"],
	"bowl300": ["bowling_best", 300, "Mükemmel Oyun", "Bowlingde 300 puan yap.", 20000, "Mükemmel"],
	# 1.9
	"full_tune": ["full_tune", 1, "Tam Donanım", "Arabana motor, lastik, nitro ve spoylerin hepsini en üst kademede tak.", 3000, "Tuning Ustası"],
	"drift1000": ["drift", 1000, "Drift Kralı", "Drift Alanı'nda tek seferde 1000 drift puanı topla.", 2500, "Drift Kralı"],
	"street1": ["street_races", 1, "Sokakların Tozu", "Bir sokak yarışını bitir.", 500, ""],
	"street_win5": ["street_wins", 5, "Sokak Şampiyonu", "5 sokak yarışı kazan.", 6000, "Sokak Şampiyonu"],
	"pet_train50": ["pet_trains", 50, "Sabırlı Eğitmen", "Evcil hayvanını 50 kez eğit.", 2000, "Eğitmen"],
	"pet_gold": ["pet_gold", 1, "Altın Pati", "Evcil hayvanınla parkur yarışında birinci ol.", 1500, ""],
	"pet_show": ["pet_show_win", 3, "Jürinin Gözdesi", "Güzellik şovunda 3 kez birinci ol.", 4000, "Şov Yıldızı"],
	"stall50": ["stall_sales", 50, "Pazarcı", "Tezgâhından ya da alım ilanlarından 50 satış yap.", 2500, "Pazarcı"],
	"disaster_tasks": ["disaster_tasks", 25, "Gönüllü", "Afetlerde 25 görev tamamla.", 3000, "Gönüllü"],
	"disasters3": ["disasters", 3, "Şehrin Kalkanı", "3 afetin atlatılmasına yardım et.", 4000, "Şehrin Kalkanı"],
	# 2.0
	"chef50": ["chef_orders", 50, "Usta Aşçı", "Mutfak servisinde 50 sipariş yetiştir.", 2500, "Şef"],
	"chef_perfect20": ["chef_perfect", 20, "Kusursuz Tabak", "20 siparişi mükemmel hazırla.", 3000, ""],
	"chef_champ": ["chef_champion", 1, "Altın Kepçe", "Aşçılık yarışmasında birinci ol.", 5000, "Altın Kepçe"],
	"sub": ["submarine", 1, "Derinlere", "Bir denizaltı al.", 2000, ""],
	"species8": ["deep_species", 8, "Deniz Bilimci", "Batık Şehir'de 8 canlı türünü tara.", 3000, "Deniz Bilimci"],
	"species16": ["deep_species", 16, "Okyanus Ansiklopedisi", "Batık Şehir'deki bütün canlıları keşfet.", 8000, "Okyanusbilimci"],
	"artifacts10": ["artifacts", 10, "Arkeolog", "Batık Şehir'den 10 antik eser çıkar.", 4000, "Arkeolog"],
	"project1": ["projects_built", 1, "Şehrin Mimarı", "Bağış yaptığın bir belediye projesi tamamlansın.", 2000, ""],
	"project_votes5": ["project_votes", 5, "Sorumlu Vatandaş", "5 belediye projesinde oy kullan.", 1500, ""],
	"muhtar": ["muhtar", 1, "Muhtar", "Yeni Mahalle'nin muhtarı seçil.", 3000, "Muhtar"],
	"dj1": ["dj_sets", 1, "İlk Set", "Festivalde DJ olarak bir set çal.", 1000, ""],
	"dj_hype": ["dj_hype", 90, "Sahnenin Sahibi", "Bir DJ setinde coşkuyu 90'ın üstüne çıkar.", 4000, "DJ"],
	"dance500": ["dance_points", 500, "Dans Kraliçesi/Kralı", "Bir sette 500 dans puanı topla.", 2500, "Dansçı"],
	"kayik": ["kayik", 1, "Kürekçi", "Gölde kayığa bin.", 200, ""],
}

var data: Dictionary = {}          # istemci: {got: {...}, c: {...}, title}


func reset() -> void:
	data = {}


func title_name(k: String) -> String:
	return str(LIST[k][5]) if LIST.has(k) else ""


# ------------------------------------------------------------------ istemci API

func set_title(k: String) -> void:
	Net.ask(self, "req_title", {"id": k})


@rpc("authority", "call_local", "reliable")
func on_ach(d: Dictionary) -> void:
	data = d
	changed.emit()


# ------------------------------------------------------------------ sunucu

static func ach_of(rec: Dictionary) -> Dictionary:
	if not rec.get("ach") is Dictionary:
		rec["ach"] = {"got": {}, "c": {}, "title": ""}
	var a: Dictionary = rec["ach"]
	if not a.get("got") is Dictionary:
		a["got"] = {}
	if not a.get("c") is Dictionary:
		a["c"] = {}
	return a


func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


## Sayaç artır (balık, hasta, gol...).
func event(id: int, counter: String, n: int = 1) -> void:
	var rec := _rec(id)
	if rec.is_empty() or n <= 0:
		return
	var a := ach_of(rec)
	a.c[counter] = int(a.c.get(counter, 0)) + n
	_check(id, a, counter)


## Sayaç en az bu değer olsun (seviye, para, mevduat...).
func set_max(id: int, counter: String, value: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var a := ach_of(rec)
	if value <= int(a.c.get(counter, 0)):
		return
	a.c[counter] = value
	_check(id, a, counter)


func _check(id: int, a: Dictionary, counter: String) -> void:
	var opened: Array = []
	for k in LIST:
		var d: Array = LIST[k]
		if d[0] == counter and not a.got.has(k) and int(a.c.get(counter, 0)) >= int(d[1]):
			a.got[k] = Time.get_unix_time_from_system()
			opened.append(k)
	Net.mark_dirty()
	for k in opened:
		var d: Array = LIST[k]
		if int(d[4]) > 0:
			Net.add_money(id, int(d[4]))
		Rpg.add_xp(id, "", 50 + int(int(d[4]) / 20.0))
		var extra := "  Yeni unvan: «%s»" % d[5] if str(d[5]) != "" else ""
		Net.notify(id, "BAŞARIM: %s! +%s%s" % [d[2], U.money(int(d[4])), extra])
		if str(d[5]) != "":
			Net.announce("%s «%s» unvanını kazandı! (%s)" % [Net.players[id].name, d[5], d[2]])
	_send_later(id)


var _pending := {}


## Sık artan sayaçlarda her olayda değil, kısa aralıkla gönder.
func _send_later(id: int) -> void:
	_pending[id] = true


func _process(_d: float) -> void:
	if _pending.is_empty() or not Net.is_server():
		return
	if Engine.get_process_frames() % 10 != 0:
		return
	for id in _pending:
		send_state(id)
	_pending.clear()


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var a := ach_of(rec)
	Net.tell(self, id, "on_ach", {"got": a.got.duplicate(), "c": a.c.duplicate(), "title": str(a.get("title", ""))})
	_refresh_roster(id)


func on_join(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	set_max(id, "level", Rpg.level(id))
	set_max(id, "money", Net.get_money(id))
	set_max(id, "wardrobe", Shops.wardrobe(rec).size())
	send_state(id)


func _refresh_roster(id: int) -> void:
	var a := ach_of(_rec(id))
	var t := title_name(str(a.get("title", "")))
	if str(Net.players[id].get("title", "")) != t:
		Net.players[id]["title"] = t
		Net._broadcast_roster()


@rpc("any_peer", "call_remote", "reliable")
func req_title(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var k := str(d.get("id", ""))
	var a := ach_of(rec)
	if k != "" and (not a.got.has(k) or title_name(k) == ""):
		return
	a["title"] = k
	Net.mark_dirty()
	send_state(id)
