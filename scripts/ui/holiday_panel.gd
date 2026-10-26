extends "res://scripts/ui/game_panel.gd"
## Parktaki bayram tezgâhı: Cadılar Bayramı'nda kostüm, Sevgililer Günü'nde gül.

func _ready() -> void:
	var h := Holidays.active
	build("%s Tezgâhı" % Holidays.NAMES.get(h, "Bayram"), Vector2(460, 0))
	money_hint(body)
	match h:
		"cadilar":
			add_label(body, "Kostümünü seç (%s). G ile kapıları çal: şeker mi şaka mı!" % U.money(Holidays.COSTUME_PRICE), 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			for k in Holidays.COSTUMES:
				buy_button(body, Holidays.COSTUME_PRICE, Holidays.costume.bind(k), 0, Holidays.COSTUMES[k]).custom_minimum_size = Vector2(0, 36)
			add_button(body, "Kostümü çıkar", Holidays.costume.bind(""))
		"sevgililer":
			add_label(body, "Gül al, sonra sevdiğin birinin yanına gidip G ile ver ♥", 14, Color("#94a3b8"))
			buy_button(body, Holidays.ROSE_PRICE, Holidays.buy_rose, 0, "Gül al").custom_minimum_size = Vector2(0, 38)
		"yilbasi":
			add_label(body, "Mutlu yıllar! Noel Baba'nın yanına gidip E ile hediyeni al; şehirdeki hediye kutularını topla.", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"ramazan", "kurban":
			add_label(body, "İyi bayramlar! Büyüklerin (NPC'ler) yanına gidip G ile elini öp, harçlığını al.", 15).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_:
			add_label(body, "Şu an bir özel gün yok.", 15)
