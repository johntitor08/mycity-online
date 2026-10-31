extends Node
## Giriş menüsü ve sahne geçişleri.
## "--sunucu" argümanıyla (ör. godot --headless -- --sunucu --port=7777) ekransız
## adanmış sunucu olarak çalışır.

const World = preload("res://scripts/world.gd")
const CharacterPanel = preload("res://scripts/ui/character_panel.gd")
const ServerList = preload("res://scripts/ui/server_list.gd")
const SETTINGS_PATH := "user://ayarlar.cfg"
## 7/24 açık resmi sunucu (boşsa menüde buton görünmez). Biçim: "adres" ya da "adres:port".
const OFFICIAL_SERVER := "traded-rolled.tun.ply.gg:12861"
## Tarayıcı sürümünün resmi sunucusu (VPS'te alan adıyla kurulunca ör. "wss://mycity.duckdns.org/oyun").
## Boşsa sayfanın kendi adresi kullanılır: oyun VPS'teki Caddy'den açıldıysa aynı sunucuya bağlanır.
const OFFICIAL_WEB_SERVER := ""
## Tarayıcı sürümü (ör. itch.io) güncel sunucu adresini buradan okur: {"wss": "wss://…"}.
## Bilgisayardaki Cloudflare tüneli adresi değişince bu dosya kendiliğinden güncellenir (~/.local/bin/mycity-web-tunel.sh).
const OFFICIAL_WEB_ADDRESS_URL := "https://raw.githubusercontent.com/johntitor08/mycity-online/sunucu/adres.json"


static func official_web_url() -> String:
	if OFFICIAL_WEB_SERVER != "":
		return OFFICIAL_WEB_SERVER
	var host := str(JavaScriptBridge.eval("location.host", true))
	if str(JavaScriptBridge.eval("location.protocol", true)) == "https:":
		return "wss://%s/oyun" % host
	# yerel deneme (http): aynı makinedeki sunucunun WebSocket portu
	return "ws://%s:%d" % [str(JavaScriptBridge.eval("location.hostname", true)), Net.DEFAULT_PORT + 1]

var menu: Control
var world: Node2D
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var pass_edit: LineEdit
var status: Label
var buttons: Array = []
var server_list: ServerList


func _ready() -> void:
	_add_symbol_font()
	Net.connected_ok.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.disconnected.connect(_on_disconnected)
	var args := OS.get_cmdline_user_args()
	var port := Net.DEFAULT_PORT
	for a in args:
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--kayit="):
			Net.save_path = a.trim_prefix("--kayit=")
		elif a.begins_with("--ad="):
			Net.server_name = a.trim_prefix("--ad=").strip_edges()
		elif a.begins_with("--aciklama="):
			Net.server_desc = a.trim_prefix("--aciklama=").strip_edges()
		elif a == "--hizsiz":
			Net.speed_check = false
		elif a.begins_with("--yonetici="):
			Net.admins_arg = Array(a.trim_prefix("--yonetici=").split(",", false))
	if "--sunucu" in args or "--server" in args:
		var err := Net.host("", port, true)
		if err != "":
			printerr(err)
			get_tree().quit(1)
		return
	if "--test-istemci" in args or "--test-host" in args:
		add_child(load("res://tests/test_client.gd").new())
		return
	if "--test-yardimci" in args:
		add_child(load("res://tests/test_helper.gd").new())
		return
	if "--teaser" in args:
		add_child(load("res://tests/teaser.gd").new())
		return
	if "--foto" in args:
		add_child(load("res://tests/screenshot.gd").new())
		return
	_build_menu()


## Varsayılan fontta kart (♠♥♦♣) ve zar (⚀..⚅) simgeleri yok; DejaVu Sans'ı yedek font yapar.
func _add_symbol_font() -> void:
	var extra = load("res://fonts/DejaVuSans.ttf")
	if extra == null:
		return
	var base := ThemeDB.fallback_font
	var list := base.fallbacks
	list.append(extra)
	base.fallbacks = list


func _build_menu() -> void:
	if menu:
		menu.queue_free()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)

	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color("#151a26")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1e2230")
	sb.border_color = Color("#facc15")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	var title := Label.new()
	title.text = "MyCity Online"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#facc15"))
	outer.add_child(title)
	var sub := Label.new()
	sub.text = "Şehrini kur • Tren, sinema, paintball • 30 adalı okyanus, kendi adan • Çok oyunculu"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("#94a3b8"))
	outer.add_child(sub)
	outer.add_child(HSeparator.new())
	# 2.2: solda giriş, sağda sunucu listesi
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	outer.add_child(cols)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(420, 0)
	v.add_theme_constant_override("separation", 10)
	cols.add_child(v)
	cols.add_child(VSeparator.new())
	server_list = ServerList.new()
	server_list.official = OFFICIAL_SERVER
	server_list.join_requested.connect(_on_list_join)
	cols.add_child(server_list)

	name_edit = _field(v, "Oyuncu adı", cfg.get_value("menu", "name", ""), "Adını yaz")
	pass_edit = _field(v, "Şifre (ilk girişte hesabın bu şifreyle oluşturulur)", "", "En az 4 karakter")
	pass_edit.secret = true
	ip_edit = _field(v, "Sunucu adresi (katılmak için)", cfg.get_value("menu", "ip", "127.0.0.1"), "ör. 192.168.1.20")
	port_edit = _field(v, "Port", str(cfg.get_value("menu", "port", Net.DEFAULT_PORT)), "7777")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	if OS.has_feature("web"):
		# tarayıcıda sunucu kurulamaz; adres alanına wss:// adresi de yazılabilir
		buttons = [_button(row, "Sunucuya Katıl", _on_join)]
	else:
		buttons = [_button(row, "Sunucu Kur ve Oyna", _on_host), _button(row, "Sunucuya Katıl", _on_join)]
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	v.add_child(row1)
	if OFFICIAL_SERVER != "" or OS.has_feature("web"):
		var official := _button(row1, "Resmi Sunucuya Katıl", _on_join_official)
		official.add_theme_color_override("font_color", Color("#facc15"))
		buttons.append(official)
	_button(row1, "Listeme ekle", _on_add_to_list)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	_button(row2, "Karakterini Düzenle", _on_character)
	_button(row2, "Ayarlar", _on_settings)
	var snd := _button(row2, "", _toggle_sound)
	snd.text = "Ses: Kapalı" if Sfx.muted else "Ses: Açık"
	snd.pressed.connect(func(): snd.text = "Ses: Kapalı" if Sfx.muted else "Ses: Açık")

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_color", Color("#fca5a5"))
	v.add_child(status)
	name_edit.grab_focus()
	pass_edit.text_submitted.connect(func(_t): _on_join())


func _on_settings() -> void:
	var p = load("res://scripts/ui/settings_panel.gd").new()
	p.closed.connect(p.queue_free)
	menu.add_child(p)


func _toggle_sound() -> void:
	Sfx.toggle_mute()


func _saved_appearance():
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return cfg.get_value("karakter", "gorunum", null)


func _on_character() -> void:
	var p = CharacterPanel.new()
	p.offline = true
	var saved = _saved_appearance()
	p.appearance = saved if saved is Dictionary else CharacterPanel.Avatar.default_for(name_edit.text.strip_edges())
	p.closed.connect(p.queue_free)
	menu.add_child(p)


func _field(parent: Node, label: String, value: String, placeholder: String) -> LineEdit:
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", Color("#cbd5e1"))
	parent.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 36)
	parent.add_child(e)
	return e


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)     # ses/karakter ayarlarını koru
	cfg.set_value("menu", "name", name_edit.text.strip_edges())
	cfg.set_value("menu", "ip", ip_edit.text.strip_edges())
	cfg.set_value("menu", "port", int(port_edit.text))
	cfg.save(SETTINGS_PATH)


func _validate() -> bool:
	if name_edit.text.strip_edges() == "":
		status.text = "Önce bir oyuncu adı yaz."
		return false
	if pass_edit.text.length() < 4:
		status.text = "Şifre en az 4 karakter olmalı."
		return false
	if int(port_edit.text) <= 0:
		status.text = "Geçerli bir port gir (ör. 7777)."
		return false
	return true


func _on_host() -> void:
	if not _validate():
		return
	_save_settings()
	var err := Net.host(name_edit.text, int(port_edit.text), false,
		Net.hash_password(name_edit.text, pass_edit.text), _saved_appearance())
	if err != "":
		status.text = err


func _on_join() -> void:
	if not _validate():
		return
	_save_settings()
	var err := Net.join(name_edit.text, ip_edit.text.strip_edges(), int(port_edit.text),
		Net.hash_password(name_edit.text, pass_edit.text), _saved_appearance())
	if err != "":
		status.text = err
		return
	status.add_theme_color_override("font_color", Color("#fde68a"))
	status.text = "Bağlanılıyor..."
	for b in buttons:
		b.disabled = true


func _on_list_join(address: String, port: int) -> void:
	if address == "resmi-web":
		_on_join_official()
		return
	ip_edit.text = address
	if port > 0:
		port_edit.text = str(port)
	_on_join()


func _on_add_to_list() -> void:
	var err := server_list.add_saved(ip_edit.text, int(port_edit.text))
	status.add_theme_color_override("font_color", Color("#fca5a5") if err != "" else Color("#86efac"))
	status.text = err if err != "" else "Sunucu listene eklendi."


func _on_join_official() -> void:
	if OS.has_feature("web"):
		if OFFICIAL_WEB_SERVER == "" and OFFICIAL_WEB_ADDRESS_URL != "":
			_fetch_web_address()
			return
		ip_edit.text = official_web_url()
		_on_join()
		return
	var parts := OFFICIAL_SERVER.split(":")
	ip_edit.text = parts[0]
	port_edit.text = parts[1] if parts.size() > 1 else str(Net.DEFAULT_PORT)
	_on_join()


## Tarayıcıda: güncel tünel adresini oku, sonra bağlan (okunamazsa sayfanın kendi adresi denenir).
func _fetch_web_address() -> void:
	status.add_theme_color_override("font_color", Color("#fde68a"))
	status.text = "Sunucu adresi alınıyor..."
	for b in buttons:
		b.disabled = true
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		var addr := ""
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var js = JSON.parse_string(body.get_string_from_utf8())
			if js is Dictionary:
				addr = str(js.get("wss", ""))
		for b in buttons:
			b.disabled = false
		ip_edit.text = addr if addr.begins_with("ws") else official_web_url()
		_on_join())
	# önbelleğe takılmasın diye zaman damgası
	if req.request("%s?t=%d" % [OFFICIAL_WEB_ADDRESS_URL, int(Time.get_unix_time_from_system())]) != OK:
		req.queue_free()
		ip_edit.text = official_web_url()
		_on_join()


func _on_connected() -> void:
	if menu:
		menu.queue_free()
		menu = null
	world = World.new()
	add_child(world)


func _on_failed(reason: String) -> void:
	if menu == null:
		_build_menu()
	status.add_theme_color_override("font_color", Color("#fca5a5"))
	status.text = reason
	for b in buttons:
		b.disabled = false


func _on_disconnected(reason: String) -> void:
	if world:
		world.queue_free()
		world = null
	if menu == null:
		_build_menu()
	status.text = reason
