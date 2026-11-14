extends "res://scripts/ui/game_panel.gd"
## 2.5: yönetici paneli — sohbetteki yönetici komutlarının düğmeli hali (sunucu yetkiyi yine kendisi denetler).
## Duyuru, çevrimiçi oyuncular (sustur / at / yönetici yap), dünya (hava, etkinlik, afet, zombi, festival, özel gün),
## sunucu (kaydet, yedekle) ve arsa boşaltma.

const Map = preload("res://scripts/map.gd")
const WEATHERS := [["açık", "Açık"], ["bulutlu", "Bulutlu"], ["yağmur", "Yağmur"], ["fırtına", "Fırtına"], ["sis", "Sis"], ["gökkuşağı", "Gökkuşağı"]]
const HOLIDAYS := [["takvim", "Takvime göre"], ["yok", "Yok"], ["cadilar", "Cadılar Bayramı"], ["yilbasi", "Yılbaşı"],
	["ramazan", "Ramazan Bayramı"], ["kurban", "Kurban Bayramı"], ["sevgililer", "Sevgililer Günü"]]

var players_box: VBoxContainer
var plot_spin: SpinBox
var plot_info: Label


func _ready() -> void:
	build("Yönetici Paneli", Vector2(860, 0))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	_section(v, "Duyuru")
	var dr := HBoxContainer.new()
	v.add_child(dr)
	var line := LineEdit.new()
	line.placeholder_text = "Herkese gidecek duyuru…"
	line.max_length = 200
	line.size_flags_horizontal = SIZE_EXPAND_FILL
	dr.add_child(line)
	var send := func():
		if line.text.strip_edges() != "":
			_cmd("duyuru " + line.text.strip_edges())
			line.text = ""
	line.text_submitted.connect(func(_t): send.call())
	add_button(dr, "Gönder", send)

	_section(v, "Çevrimiçi oyuncular")
	players_box = VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 4)
	v.add_child(players_box)

	_section(v, "Dünya")
	var wr := HBoxContainer.new()
	v.add_child(wr)
	add_label(wr, "Hava:", 15)
	_option_row(wr, WEATHERS, func(k): _cmd("hava " + k), "Uygula")
	var er := HBoxContainer.new()
	v.add_child(er)
	add_label(er, "Etkinlik:", 15)
	var ev: Array = []
	for k in Events.KINDS:
		ev.append([k, str(Events.KINDS[k].name)])
	_option_row(er, ev, func(k): _cmd("etkinlik " + k), "Başlat")
	var hr := HBoxContainer.new()
	v.add_child(hr)
	add_label(hr, "Özel gün:", 15)
	_option_row(hr, HOLIDAYS, func(k): _cmd("ozelgun " + k), "Uygula")
	var ar := HFlowContainer.new()
	ar.add_theme_constant_override("h_separation", 6)
	ar.add_theme_constant_override("v_separation", 6)
	v.add_child(ar)
	add_label(ar, "Afet:", 15)
	for k in [["deprem", "Deprem"], ["sel", "Sel"], ["kar", "Kar fırtınası"], ["bitir", "Afeti bitir"]]:
		add_button(ar, k[1], _cmd.bind("afet " + k[0]))
	add_label(ar, "   Zombi:", 15)
	add_button(ar, "Başlat", _cmd.bind("zombi başlat"))
	add_button(ar, "Bitir", _cmd.bind("zombi bitir"))
	add_label(ar, "   Festival:", 15)
	add_button(ar, "Başlat", _cmd.bind("festival"))
	add_button(ar, "Bitir", _cmd.bind("festival bitir"))

	_section(v, "Arsalar")
	var pr := HBoxContainer.new()
	v.add_child(pr)
	add_label(pr, "Arsa #", 15)
	plot_spin = add_spin(pr, 1, Map.PLOT_COUNT, 1, 1)
	plot_spin.value_changed.connect(func(_x): _refresh_plot())
	add_button(pr, "Boşalt (sahibine iade)", func(): _cmd("arsasil %d" % int(plot_spin.value)))
	add_button(pr, "İadesiz boşalt", func(): _cmd("arsasil %d iadesiz" % int(plot_spin.value)))
	plot_info = add_label(v, "", 14, Color("#94a3b8"))

	_section(v, "Sunucu")
	var sr := HBoxContainer.new()
	v.add_child(sr)
	add_button(sr, "Kaydet", _cmd.bind("kaydet"))
	add_button(sr, "Yedek al", _cmd.bind("yedekle"))
	add_button(sr, "Çevrimiçi listesi", _cmd.bind("oyuncular"))

	Net.roster_changed.connect(_refresh_players)
	Land.plots_changed.connect(_refresh_plot)
	_refresh_players()
	_refresh_plot()


func _section(parent: Node, title: String) -> void:
	add_label(parent, title, 18, Color("#facc15"))


## Seçenek listesi + düğme: seçili anahtarla cb çağrılır.
func _option_row(parent: Node, items: Array, cb: Callable, label: String) -> void:
	var opt := OptionButton.new()
	for it in items:
		opt.add_item(it[1])
	parent.add_child(opt)
	add_button(parent, label, func(): cb.call(str(items[opt.selected][0])))


func _cmd(text: String) -> void:
	Net.send_chat("/" + text)
	Sfx.play("click", -6.0)


func _refresh_players() -> void:
	if not is_instance_valid(players_box):
		return
	for c in players_box.get_children():
		c.queue_free()
	var ids: Array = Net.roster.keys()
	ids.sort_custom(func(a, b): return str(Net.roster[a].name) < str(Net.roster[b].name))
	for id in ids:
		var info: Dictionary = Net.roster[id]
		var nm := str(info.name)
		var row := HBoxContainer.new()
		players_box.add_child(row)
		var tag := "  [yönetici]" if bool(info.get("admin", false)) else ""
		add_label(row, "%s · Sv.%d · %s%s" % [nm, int(info.get("level", 1)), U.money(int(info.get("money", 0))), tag], 15,
			Color("#86efac") if nm == Net.my_name else Color.WHITE).size_flags_horizontal = SIZE_EXPAND_FILL
		if nm == Net.my_name:
			continue
		add_button(row, "Sustur 10 dk", _cmd.bind("sustur %s 10" % nm))
		add_button(row, "At", _cmd.bind("kick %s" % nm))
		if not bool(info.get("admin", false)):
			add_button(row, "Yönetici yap", _cmd.bind("yonetici %s" % nm))


func _refresh_plot() -> void:
	if not is_instance_valid(plot_info):
		return
	var i := int(plot_spin.value) - 1
	if i < 0 or i >= Land.view.size():
		plot_info.text = ""
		return
	var p: Dictionary = Land.view[i]
	var where: String = {"sehir": "Şehir", "yalikent": "Yalıkent", "camlibel": "Çamlıbel", "mahalle": "Yeni Mahalle"}[Map.plot_region(i)]
	plot_info.text = "#%d (%s): %s" % [i + 1, where, "satılık" if str(p.owner) == "" else "%s — %s" % [p.owner, Land.building_name(p)]]
