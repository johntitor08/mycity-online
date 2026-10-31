extends "res://scripts/ui/game_panel.gd"
## Başlangıç rehberi (2.1): solda konular, sağda kısa ve uygulanabilir ipuçları. Üst menüdeki "Rehber" butonundan açılır.

const TOPICS := [
	["İlk adımlar", """[b]Hoş geldin![/b] Burası arkadaşlarınla aynı anda yaşadığın bir şehir.

• [b]Yürü:[/b] {walk}. Bir binaya ya da kişiye yaklaşınca altta ne yapabileceğin yazar; {interact} ile kullan.
• [b]Binalar:[/b] hastane, market, karakol, banka, kaplıca gibi kurumların kapısında {interact} ile içeri gir; görevlinin tezgâhında {interact} ile işini yap. Kapıdaki paspastan dışarı çıkarsın.
• [b]İlk görev:[/b] başında [b]"!"[/b] olan [b]Muhtar Rıza[/b]'yla konuş (Muhtarlık, Mobilyacı'nın sağı). Hikâye görevleri seni adım adım gezdirir ve ödül verir.
• [b]Harita:[/b] {map} ile aç; bir yere tıkla/dokun, kırmızı ok seni oraya götürür.
• [b]Enerji:[/b] iş yapınca azalır. Market'ten simit/kahve al ya da evinde dinlen.
• [b]Seviye:[/b] her işte XP kazanırsın; seviye arttıkça yeni araçlar, meslekler ve yerler açılır."""],
	["Para kazanmak", """İlk paran için en kolayları:

• [b]Hastane[/b] (sol üstte): doktorluk — hastanın derdini doğru teşhis et.
• [b]Market[/b]: kasiyerlik — doğru para üstünü ver.
• [b]Balık:[/b] göl iskelesinde ya da deniz iskelesinde balık tut; Pazar Yeri'nde (Hal) sat. Yalıkent'teki Balık Hali %25 fazla öder.
• [b]Meslekler:[/b] taksi (taksi durağı, araba gerekir), kargo, itfaiye, çöp toplama, fabrika.
• Biraz para birikince [b]arsa al[/b]: ev kira getirir, büfe/kafe müşteri getirir, tarla ve ahır ürün verir.

[i]Not: Kira ve dükkân geliri sadece sen oyundayken işler.[/i]"""],
	["Ev, arsa ve işletme", """• [b]Emlak Ofisi[/b] ya da arsanın içinde {interact}: boş arsayı satın al.
• Arsaya [b]ev[/b] (küçük ev → villa → gökdelen), [b]işletme[/b] (büfe → kafe → restoran), [b]tarla[/b] ya da [b]ahır[/b] kurabilirsin. Kişi başı en fazla 6 arsa.
• [b]Mobilyacı[/b]'dan eşya al, evine yerleştir; arkadaşlarını ev partisine çağır.
• Kafe/restoranında [b]mutfağa gir[/b]: siparişleri zamanında hazırla, bahşiş topla.
• Yalıkent ve Çamlıbel'de de satılık arsalar var."""],
	["Ulaşım", """• [b]{vehicle}:[/b] aracına bin/in. Galeri'den bisiklet, araba ve tekne alınır. [b]Araba sadece yolda[/b] gider; yol dışına inip yürü.
• [b]Otobüs durakları:[/b] şehir içinde duraktan durağa.
• [b]Otoyol:[/b] arabayla şehrin batı ucundaki rampadan çık; [b]Yalıkent[/b] (sahil) ve [b]Çamlıbel[/b] (dağ) kasabalarına git.
• [b]Otogar:[/b] arabası olmayan şehirler arası otobüse biner.
• [b]Tren:[/b] Şehir Garı'ndan dağa, lunaparka ve Yeni Mahalle'ye.
• [b]Teleferik:[/b] dağa; [b]Havalimanı[/b] (lunaparkta): okyanus ve uzay üssüne uçuş."""],
	["Arkadaşlarla", """• [b]Sohbet:[/b] Enter (telefonda "Sohbet" düğmesi). /k klan, /y yakındakiler, /m isim özel mesaj.
• Bir oyuncunun adına tıklayıp [b]para gönderebilir[/b] ya da [b]takas[/b] yapabilirsin.
• [b]Klan[/b] kur ya da katıl; klan kasası ve ligde klan puanı.
• [b]Belediye seçimi:[/b] aday ol, oy ver; başkan şehre park, fıskiye, heykel gibi projeler önerir.
• Birlikte: [b]sokak yarışı[/b], [b]paintball[/b], [b]futbol[/b], [b]mağara zindanı[/b] (4 kişilik ekip), [b]festival[/b]de DJ ve dans."""],
	["Gezilecek yerler", """• [b]Lunapark ve havalimanı:[/b] dönme dolap, çarpışan araba, balon, sinema, bowling, mini golf.
• [b]Dağ:[/b] maden, kayak, kamp; mağara zindanına da buradan girilir.
• [b]Yeni Mahalle:[/b] pazar tezgâhları, tuning garajı ve drift alanı, evcil hayvan parkı, Aşçılık Akademisi.
• [b]Açık Okyanus:[/b] tekneyle 30 ada, hazineler, Kraken. [b]Batık Şehir[/b]e denizaltıyla (Sanayi Limanı).
• [b]Uzay üssü ve Ay:[/b] roket yap, Ay'da taş kaz.
• [b]Yalıkent ve Çamlıbel:[/b] otoyolla ya da otobüsle."""],
	["Etkinlikler", """• [b]Etkinlik[/b] butonu: sıradaki şehir etkinliği (yarış günü, balık turnuvası, hazine avı…) ve ödüller.
• [b]Zombi geceleri[/b] (dolunay), [b]afetler[/b] (deprem, sel, kar fırtınası) ve [b]plaj festivali[/b] kendiliğinden gelir; duyurulara bak.
• [b]Lig[/b]: haftalık sıralamalar ve ödüller. [b]Başarım[/b]: hedefler ve unvanlar.
• [b]Özel günler[/b] gerçek takvime göre gelir (Cadılar Bayramı, yılbaşı, bayramlar)."""],
	["Kontroller", """[b]Bilgisayar:[/b] WASD/oklar yürü · E gir/kullan · F araç · G eylem · M harita · C profil · P telefon · O fotoğraf · V dal · H at · N nitro · Enter sohbet · Esc kapat. Tuşları Ayarlar'dan değiştirebilirsin.

[b]Telefon:[/b] sol altta joystick; sağda E (kullan), F (araç), G (eylem), Harita, Telefon, Profil, Dal, At düğmeleri; arabadayken Nitro. Savaşta ve paintballda ekrana dokunduğun yöne saldırırsın. Telefonu yan çevir.

[b]Hesap:[/b] Ayarlar'da ses, yazı boyutu, tuşlar ve hesabı silme."""],
]

var _list: VBoxContainer
var _text: RichTextLabel
var _cur := 0


func _ready() -> void:
	build("Başlangıç Rehberi", Vector2(820, 520))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(h)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(200, 0)
	_list.add_theme_constant_override("separation", 4)
	h.add_child(_list)
	h.add_child(VSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(560, 440)
	h.add_child(scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 16)
	_text.add_theme_font_size_override("bold_font_size", 16)
	scroll.add_child(_text)
	for i in TOPICS.size():
		var b := add_button(_list, TOPICS[i][0], _select.bind(i))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
	_select(0)


func _select(i: int) -> void:
	_cur = i
	for k in _list.get_child_count():
		(_list.get_child(k) as Button).modulate = Color("#facc15") if k == i else Color.WHITE
	_text.text = "[font_size=22][color=#facc15]%s[/color][/font_size]\n\n%s" % [TOPICS[i][0], Tutorial._text(TOPICS[i][1])]
