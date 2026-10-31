extends Node
## Büyük tanıtım videosu (tools/teaser_dev.sh) için: tests/screenshot.gd "--klip" ile çalışınca
## her _shot() çağrısı burada kısa bir klibe dönüşür: karanlıktan açıl, yazı, yavaş yakınlaşma, karar.
## Klipler arasındaki hazırlık siyah ekranda ve hızlandırılmış geçer; betik "KLIP a b" satırlarına göre keser.

const Map = preload("res://scripts/map.gd")
const Avatar = preload("res://scripts/avatar.gd")
const HOLD := 2.3
const FAST := 10.0                 # siyah ekrandaki hazırlık hızı

## görüntü adı -> [etiket, yazı]. Listede olmayanlar videoya girmez.
const CAPS := {
	"sehir": ["ŞEHİR", "Arkadaşlarınla aynı şehirde yaşa"],
	"karakterler": ["KARAKTER", "Kendi karakterini tasarla"],
	"arsalar": ["ARSA", "Arsa al, evini gökdelene büyüt"],
	"plaj": ["PLAJ", "Denizde yüz, iskelede balık tut"],
	"hospital": ["MESLEKLER", "Doktor ol, teşhis koy"],
	"casino": ["KUMARHANE", "Rulet ve poker"],
	"araclar": ["ARAÇLAR", "Bisiklet, araba, tekne"],
	"gece": ["GÜN VE GECE", "Gece şehrin ışıkları yanar"],
	"firtina": ["HAVA DURUMU", "Yağmur, fırtına, sis"],
	"ev": ["EVİN", "Evini istediğin gibi döşe"],
	"pazar": ["PAZAR YERİ", "Topla, sat, kazan"],
	"isletme": ["İŞLETME", "Büfe aç, kafeye, restorana büyüt"],
	"sehir_npc": ["YAŞAYAN ŞEHİR", "Sokaklar şehir halkıyla dolu"],
	"tarla": ["ÇİFTLİK", "Tarla ek, hasat et"],
	"sonbahar": ["MEVSİMLER", "İlkbahar, yaz, sonbahar, kış"],
	"klan": ["KLAN", "Klanını kur, kasayı doldur"],
	"yaris": ["YARIŞ", "Şehir içi yarışlar"],
	"festival": ["ETKİNLİKLER", "Festivaller ve şehir etkinlikleri"],
	"karakol": ["POLİS", "Polis ol, suçluyu yakala"],
	"hapis": ["SUÇ VE CEZA", "…ya da hapse düş"],
	"carsi": ["ÇARŞI", "Kıyafet ve aksesuar"],
	"banka": ["BANKA", "Faiz, kredi, kasa"],
	"borsa": ["BORSA", "Hisse al, sat"],
	"secim": ["SEÇİM", "Belediye başkanını seç"],
	"dugun": ["DÜĞÜN", "Evlen, aile kur"],
	"nehir": ["ŞEHİR", "Nehir, köprüler, parklar"],
	"otobus": ["OTOBÜS", "Duraktan durağa otobüs"],
	"taksi": ["TAKSİ", "Taksici ol, yolcu taşı"],
	"yangin": ["İTFAİYE", "Yangını söndür"],
	"parti": ["EV PARTİSİ", "Arkadaşlarını partiye çağır"],
	"basarim": ["BAŞARIMLAR", "Başarımlar ve unvanlar"],
	"futbol": ["SPOR", "Plaj futbolu"],
	"langirt": ["LANGIRT", "Langırt maçı"],
	"harita": ["HARİTA", "Haritada bir yere dokun, yolu göstersin"],
	"kis_kartopu": ["KIŞ", "Kardan adam, kartopu savaşı"],
	"gokkusagi": ["HAVA", "Yağmurdan sonra gökkuşağı"],
	"feribot": ["FERİBOT", "Feribotla Sanayi Limanı'na"],
	"fabrika": ["FABRİKA", "Üretim bandında çalış"],
	"lig": ["LİG", "Haftalık lig ve sezonlar"],
	"ahir": ["HAYVANCILIK", "Tavuk, inek, koyun besle"],
	"galeri_ozellestir": ["GALERİ", "Arabanı boya, jant tak"],
	"mutfak": ["MUTFAK", "Tariflerle yemek pişir"],
	"deniz_alti": ["DALGIÇLIK", "Dal, inci topla"],
	"batik_gemi": ["BATIK GEMİ", "Batıktan hazine çıkar"],
	"teleferik": ["DAĞ", "Teleferikle dağa çık"],
	"maden": ["MADEN", "Madende cevher kaz"],
	"kayak": ["KAYAK", "Kayak pistinden kay"],
	"muze": ["MÜZE", "Bulduklarını müzeye bağışla"],
	"konser": ["KONSER", "Sahnede çal, söyle"],
	"olta_vurdu": ["BALIKÇILIK", "Oltayı at, balık vursun"],
	"telefon": ["TELEFON", "Mesajlar, haberler, uygulamalar"],
	"takas": ["TAKAS", "Oyuncularla güvenli takas"],
	"hara": ["ATLAR", "Atını al, bin"],
	"hipodrom": ["HİPODROM", "At yarışı ve bahis"],
	"kamp": ["KAMP", "Ormanda kamp ateşi"],
	"teleskop": ["GECE GÖKYÜZÜ", "Teleskopla yıldızlar"],
	"okul_sinav": ["OKUL", "Sınava gir, diploma al"],
	"dedektif_supheli": ["DEDEKTİF", "İpuçlarını topla, davayı çöz"],
	"lunapark": ["LUNAPARK", "Dönme dolap, çarpışan araba, atış"],
	"balon": ["BALON", "Sıcak hava balonuyla uç"],
	"ucus": ["HAVALİMANI", "Uçakla yolculuk"],
	"cadilar": ["ÖZEL GÜNLER", "Cadılar Bayramı"],
	"yilbasi": ["ÖZEL GÜNLER", "Yılbaşı"],
	"spor_salonu": ["SPOR SALONU", "Güçlen, maratona katıl"],
	"korsan_adasi": ["KORSAN ADASI", "Hazine haritasını takip et"],
	"hayvanat_bahcesi": ["HAYVANAT BAHÇESİ", "Zürafa, aslan, fil"],
	"akvaryum": ["AKVARYUM", "Dev akvaryum"],
	"okyanus_liman": ["AÇIK OKYANUS", "30 adalı okyanusa yelken aç"],
	"okyanus_firtina": ["OKYANUS", "Fırtınada dalgalarla boğuş"],
	"okyanus_kraken": ["KRAKEN", "Derinliklerin canavarı"],
	"tren_sehir": ["TREN", "Şehir Garı'ndan trene bin"],
	"tren_yolculuk": ["TREN", "Dağa, lunaparka, Yeni Mahalle'ye"],
	"sinema_film": ["SİNEMA", "Arkadaşlarınla film izle"],
	"karaoke": ["KARAOKE", "Mikrofonu kap"],
	"paintball": ["PAINTBALL", "Takımını seç, boya at"],
	"ozel_ada": ["ÖZEL ADA", "Kendi adanı satın al"],
	"korsan_baskini": ["KORSAN BASKINI", "Limanı korsanlardan koru"],
	"gol_kayik": ["GÖL", "Gölde kayık turu"],
	"zindan_kat": ["MAĞARA ZİNDANI", "4 kişilik ekiple aşağı in"],
	"zindan_boss": ["ZİNDAN", "Boss'u birlikte yen"],
	"zombi_gecesi": ["ZOMBİ GECESİ", "Dolunayda şehri savun"],
	"roket": ["UZAY ÜSSÜ", "Roketini yap, fırlat"],
	"ay_madeni": ["AY", "Ay'da taş kaz"],
	"mini_golf": ["MİNİ GOLF", "Delik delik yarış"],
	"bowling": ["BOWLING", "Strike!"],
	"pazar_meydani": ["YENİ MAHALLE", "Kendi pazar tezgâhını kur"],
	"tuning_drift": ["TUNING", "Motor, nitro, drift"],
	"sokak_yarisi": ["SOKAK YARIŞI", "Arkadaşlarınla kafa kafaya"],
	"guzellik_sovu": ["EVCİL HAYVAN ŞOVU", "Eğit, yarıştır, kupayı kap"],
	"deprem": ["AFETLER", "Deprem: enkazı kaldır"],
	"sel_yardim": ["AFETLER", "Selde mahsur kalanları kurtar"],
	"kar_firtinasi": ["AFETLER", "Kar fırtınası"],
	"mutfak_servisi": ["RESTORAN", "Siparişleri zamanında yetiştir"],
	"akademi": ["AŞÇILIK YARIŞMASI", "Jüriyi etkile"],
	"batik_sehir": ["BATIK ŞEHİR", "Denizaltıyla okyanusun dibine"],
	"projeler_park": ["BELEDİYE PROJELERİ", "Şehre park, heykel kazandır"],
	"fiskiye_gece": ["BELEDİYE PROJELERİ", "Meydanda ışıklı fıskiye"],
	"festival_dans": ["PLAJ FESTİVALİ", "DJ kabini ve dans pisti"],
	"festival_havai_fisek": ["PLAJ FESTİVALİ", "Havai fişekler"],
	"sehir_otoyol_girisi": ["OTOYOL", "Arabanla şehirden çık"],
	"otoyol_sahil": ["OTOYOL", "20 km'lik yolculuk"],
	"yalikent": ["YALIKENT", "Sahil kasabası"],
	"camlibel": ["ÇAMLIBEL", "Dağ kenti"],
	"camlibel_kaplica": ["KAPLICA", "Yorgunluğunu at"],
	"sehirlerarasi_otobus": ["OTOGAR", "Şehirler arası otobüs"],
	"dokunmatik": ["HER YERDE", "Windows, Linux, Android ve tarayıcı"],
	"sunucular": ["YENİ: SUNUCU LİSTESİ", "Farklı sunucular, tek dokunuşla katıl"],
	"ic_hospital": ["YENİ: KURUMLARIN İÇİ", "19 binanın içine gir"],
	"ic_casino": ["KUMARHANE", "Rulet masası, slot makineleri"],
	"ic_karakol": ["KARAKOL", "Komiserin masası, nezarethane"],
	"ic_kaplica": ["KAPLICA", "Buharı tüten havuzlar"],
	"ic_banka": ["BANKA", "Kasa dairesi"],
	"ic_okul": ["OKUL", "Sıralar ve kara tahta"],
}

var layer: CanvasLayer
var black: ColorRect
var cap_box: VBoxContainer
var cap_band: ColorRect
var cap_tag: Label
var cap_text: Label
var title_box: VBoxContainer
var _clips := 0


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	black = ColorRect.new()
	black.color = Color(0.02, 0.03, 0.06, 1.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	cap_band = ColorRect.new()
	cap_band.color = Color(0, 0, 0, 0.55)
	cap_band.position = Vector2(0, 720 - 170)
	cap_band.size = Vector2(1280, 170)
	cap_band.modulate.a = 0.0
	cap_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_band)
	cap_box = VBoxContainer.new()
	cap_box.position = Vector2(64, 720 - 150)
	cap_box.add_theme_constant_override("separation", 0)
	cap_box.modulate.a = 0.0
	cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_box)
	cap_tag = _label(cap_box, "", 22, Color("#facc15"), 6)
	cap_text = _label(cap_box, "", 44, Color.WHITE, 12)
	title_box = VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.modulate.a = 0.0
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title_box)
	Engine.time_scale = FAST


func _label(parent: Control, text: String, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## Gerçek zamanlı bekleme (siyah ekrandaki hız katsayısından bağımsız).
func _hold(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func _world():
	var m = get_tree().root.get_node_or_null("Main")
	return m.get("world") if m != null else null


func clip(n: String) -> void:
	if not CAPS.has(n):
		return
	var c: Array = CAPS[n]
	await _show(func():
		cap_tag.text = c[0]
		cap_text.text = c[1]
		var tw := _tween().set_parallel()
		tw.tween_property(cap_box, "modulate:a", 1.0, 0.35)
		tw.tween_property(cap_band, "modulate:a", 1.0, 0.35), HOLD, 0.0, n != "dokunmatik")
	var tw2 := _tween().set_parallel()
	tw2.tween_property(cap_box, "modulate:a", 0.0, 0.2)
	tw2.tween_property(cap_band, "modulate:a", 0.0, 0.2)


## Siyahtan aç, (yavaş yakınlaşarak) bekle, karart. Klip sınırları kare numarasıyla yazılır.
func _show(on_open: Callable, hold: float, open_alpha := 0.0, hide_ui := true) -> void:
	Engine.time_scale = 1.0
	var w = _world()
	var cam: Camera2D = w.camera if w != null and is_instance_valid(w) and w.get("camera") != null else null
	# klipte HUD (zenginler, ipucu, sohbet) yazının üstüne binmesin; açık paneller görünür kalır
	var ui_was := []
	if hide_ui and w != null and is_instance_valid(w):
		for k in ["hud", "touch"]:
			var c = w.get(k)
			if c is CanvasItem:
				ui_was.append([c, c.visible])
				c.visible = false
	var z0 := cam.zoom if cam else Vector2.ONE
	await get_tree().process_frame
	_clips += 1
	print("KLIP_BASLA %d" % Engine.get_process_frames())
	var tw := _tween()
	tw.tween_property(black, "color:a", open_alpha, 0.22 if open_alpha == 0.0 else 0.8)
	on_open.call()
	if cam:
		_tween().tween_property(cam, "zoom", z0 * 1.07, hold + 0.45)
	await _hold(hold + 0.22)
	var tw3 := _tween()
	tw3.tween_property(black, "color:a", 1.0, 0.22)
	await tw3.finished
	print("KLIP_BITTI %d" % Engine.get_process_frames())
	if cam and is_instance_valid(cam):
		cam.zoom = z0
	for u in ui_was:
		if is_instance_valid(u[0]):
			u[0].visible = u[1]
	Engine.time_scale = FAST


func _title(lines: Array) -> void:
	for c in title_box.get_children():
		c.queue_free()
	for ln in lines:
		var l := _label(title_box, ln[0], ln[1], ln[2], 14 if int(ln[1]) > 40 else 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tween().tween_property(title_box, "modulate:a", 1.0, 0.6)


## --acilis / --kapanis: şehrin üstünde başlık. Başka bir bölümse false döner.
func special(foto: Node) -> bool:
	var args := OS.get_cmdline_user_args()
	if not ("--acilis" in args or "--kapanis" in args):
		return false
	Net.save_path = "user://teaser_dev_kayit.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Net.save_path))
	Net.host("Eren", 7794, false, Net.hash_password("Eren", "teaser1234"))
	Holidays.force("yok")
	await foto._wait(0.5)
	var w = foto.get_parent().world
	Tutorial.finish()
	await foto._wait(1.0)
	w.hud.visible = false
	w.touch.visible = false
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5}]
	var names := ["Ayşe", "Kerem", "Zeynep", "Mehmet"]
	var opening := "--acilis" in args
	var at := Vector2(1220, 515) if opening else Map.SPAWN + Vector2(0, 40)
	Env.hour = 9.5 if opening else 20.5
	for k in 4:
		Net.players[9901 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 12, "ride": ""}
		Net.positions[9901 + k] = at + Vector2(-260 + k * 150, (k % 2) * 40 - 10)
	Net._broadcast_roster()
	w.my_pos = at
	w.camera.zoom = Vector2(0.9, 0.9)
	await foto._wait(1.5)
	w.camera.reset_smoothing()
	if opening:
		await _show(func():
			_title([["MyCity Online", 96, Color.WHITE], ["arkadaşlarınla kendi şehrini kur", 32, Color("#facc15")],
				["", 20, Color.WHITE], ["onlarca meslek  •  3 şehir  •  okyanus, dağ, uzay  •  hepsi aynı dünyada", 24, Color("#e2e8f0")]]), 4.2, 0.5)
	else:
		await _show(func():
			_title([["MyCity Online", 96, Color.WHITE], ["Ücretsiz  •  Çok oyunculu  •  Windows · Linux · Android · Tarayıcı", 28, Color("#e2e8f0")],
				["johntitortheprog.itch.io/mycity-online", 32, Color("#facc15")]]), 4.8, 0.8)
	return true
