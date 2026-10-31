extends VBoxContainer
## 2.2: giriş menüsündeki sunucu listesi. Kaynaklar: resmi liste (GitHub'daki sunucular.json),
## oyuncunun kendi eklediği adresler (ayarlar.cfg) ve yerel ağda kendini duyuran sunucular (UDP 7779).
## Her sunucu sırayla yoklanır (Net.probe): ad, oyuncu sayısı, ping, sürüm.

signal join_requested(address: String, port: int)

const SETTINGS_PATH := "user://ayarlar.cfg"
const LIST_URL := "https://raw.githubusercontent.com/johntitor08/mycity-online/main/sunucular.json"
const WEB_ADDRESS_URL := "https://raw.githubusercontent.com/johntitor08/mycity-online/sunucu/adres.json"

## Son yoklama sonuçları (menü yeniden kurulunca liste boş görünmesin): anahtar -> bilgi
static var _cache := {}
static var _remote: Array = []

var official := ""                 # "adres:port" (main.gd'den)
var entries: Array = []            # {key, name, desc, address, port, source: resmi|liste|benim|lan}
var _queue: Array = []
var _probing := ""
var _rows: VBoxContainer
var _note: Label
var _lan: PacketPeerUDP
var _rows_dirty := true


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	add_child(head)
	var t := Label.new()
	t.text = "Sunucular"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color("#facc15"))
	t.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(t)
	var refresh := Button.new()
	refresh.text = "Yenile"
	refresh.custom_minimum_size = Vector2(90, 36)
	refresh.pressed.connect(refresh_all)
	head.add_child(refresh)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 380)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 13)
	_note.add_theme_color_override("font_color", Color("#94a3b8"))
	_note.text = "Kendi sunucunu eklemek için soldaki adres/port alanlarını doldurup \"Listeme ekle\"ye bas."
	add_child(_note)
	Net.probe_done.connect(_on_probe_done)
	if not OS.has_feature("web"):
		_lan = PacketPeerUDP.new()
		if _lan.bind(Net.DISCOVERY_PORT) != OK:
			_lan = null           # aynı bilgisayarda ikinci bir menü açıksa port dolu: yerel ağ araması atlanır
	_rebuild_entries()
	_queue_all()
	if _remote.is_empty():
		_fetch_list()


func _exit_tree() -> void:
	if _probing != "":
		Net.cancel_probe()
	if _lan:
		_lan.close()


## Oyuncunun kendi listesi: [{ad, adres, port}]
func saved() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var l = cfg.get_value("sunucular", "liste", [])
	return l if l is Array else []


func add_saved(address: String, port: int) -> String:
	address = address.strip_edges()
	if address == "":
		return "Önce sunucu adresini yaz."
	var l := saved()
	for e in l:
		if str(e.get("adres", "")) == address and int(e.get("port", 0)) == port:
			return "Bu sunucu zaten listende."
	if l.size() >= 20:
		return "Listende en fazla 20 sunucu olabilir."
	l.append({"ad": address, "adres": address, "port": port})
	_store(l)
	_rebuild_entries()
	_queue_all()
	return ""


func remove_saved(address: String, port: int) -> void:
	_store(saved().filter(func(e): return not (str(e.get("adres", "")) == address and int(e.get("port", 0)) == port)))
	_rebuild_entries()


func _store(l: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("sunucular", "liste", l)
	cfg.save(SETTINGS_PATH)


static func _key(address: String, port: int) -> String:
	return address if address.begins_with("ws") else "%s:%d" % [address, port]


func _add(list: Array, seen: Dictionary, e: Dictionary) -> void:
	e["key"] = _key(e.address, e.port)
	if seen.has(e.key):
		return
	seen[e.key] = true
	list.append(e)


func _rebuild_entries() -> void:
	var web := OS.has_feature("web")
	var list := []
	var seen := {}
	# resmi sunucu her zaman en üstte (liste indirilemese bile)
	if web:
		_add(list, seen, {"name": "MyCity Resmi Sunucu", "desc": "7/24 açık ana şehir", "address": "resmi-web", "port": 0, "source": "resmi"})
	elif official != "":
		var parts := official.split(":")
		_add(list, seen, {"name": "MyCity Resmi Sunucu", "desc": "7/24 açık ana şehir", "address": parts[0],
			"port": int(parts[1]) if parts.size() > 1 else Net.DEFAULT_PORT, "source": "resmi"})
	for r in _remote:
		if not r is Dictionary:
			continue
		if r.get("resmi", false):
			continue          # yukarıda zaten var
		var addr := str(r.get("wss", "")) if web else str(r.get("adres", ""))
		if addr == "" or (web and not addr.begins_with("ws")):
			continue
		_add(list, seen, {"name": str(r.get("ad", addr)).left(40), "desc": str(r.get("aciklama", "")).left(120),
			"address": addr, "port": int(r.get("port", Net.DEFAULT_PORT)), "source": "liste"})
	for s in saved():
		var addr2 := str(s.get("adres", ""))
		if addr2 == "" or (web and not addr2.begins_with("ws")):
			continue
		_add(list, seen, {"name": str(s.get("ad", addr2)), "desc": "", "address": addr2,
			"port": int(s.get("port", Net.DEFAULT_PORT)), "source": "benim"})
	# yerel ağ: duyurusu son 10 sn içinde gelenler
	var now := Time.get_ticks_msec()
	for k in _cache:
		var c: Dictionary = _cache[k]
		if str(c.get("source", "")) == "lan" and now - int(c.get("seen", 0)) < 10000 and not seen.has(k):
			_add(list, seen, {"name": str(c.get("name", "")), "desc": str(c.get("desc", "")), "address": str(c.address),
				"port": int(c.port), "source": "lan"})
	entries = list
	_rows_dirty = true


func refresh_all() -> void:
	for k in _cache.keys():
		if str(_cache[k].get("source", "")) != "lan":
			_cache.erase(k)
	_fetch_list()
	_rebuild_entries()
	_queue_all()


func _queue_all() -> void:
	for e in entries:
		if e.source != "lan" and not _cache.has(e.key) and not e.key in _queue and e.key != _probing:
			_queue.append(e.key)
	_rows_dirty = true


func _entry(key: String) -> Dictionary:
	for e in entries:
		if e.key == key:
			return e
	return {}


func _process(_d: float) -> void:
	_poll_lan()
	if _probing == "" and not _queue.is_empty():
		var e := _entry(str(_queue[0]))
		if e.is_empty():
			_queue.pop_front()
		elif e.address == "resmi-web":
			_queue.pop_front()
			_probing = e.key
			_resolve_web(func(url: String):
				e["url"] = url
				if not Net.probe(url, 0):
					_cache[e.key] = {"ok": false}
					_probing = ""
				_rows_dirty = true)
		elif Net.probe(e.address, e.port):
			_queue.pop_front()
			_probing = e.key
			_rows_dirty = true
	if _rows_dirty:
		_rows_dirty = false
		_draw_rows()


func _on_probe_done(info: Dictionary) -> void:
	if _probing == "":
		return
	_cache[_probing] = info
	_probing = ""
	_rows_dirty = true


func _poll_lan() -> void:
	if _lan == null:
		return
	var changed := false
	while _lan.get_available_packet_count() > 0:
		var pkt := _lan.get_packet()
		var ip := _lan.get_packet_ip()
		var js = JSON.parse_string(pkt.get_string_from_utf8())
		if not js is Dictionary or not js.has("mycity"):
			continue
		var port := int(js.get("port", Net.DEFAULT_PORT))
		var k := _key(ip, port)
		var info: Dictionary = js
		info["ok"] = true
		info["source"] = "lan"
		info["address"] = ip
		info["port"] = port
		info["seen"] = Time.get_ticks_msec()
		var known := _cache.has(k) and str(_cache[k].get("source", "")) == "lan"
		_cache[k] = info
		if not known:
			changed = true
	if changed:
		_rebuild_entries()


## Tarayıcıda resmi sunucunun güncel wss adresini oku (Cloudflare tüneli her açılışta değişir).
func _resolve_web(cb: Callable) -> void:
	var fallback: String = preload("res://scripts/main.gd").official_web_url()
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
		cb.call(addr if addr.begins_with("ws") else fallback))
	if req.request("%s?t=%d" % [WEB_ADDRESS_URL, int(Time.get_unix_time_from_system())]) != OK:
		req.queue_free()
		cb.call(fallback)


func _fetch_list() -> void:
	var req := HTTPRequest.new()
	req.timeout = 8.0
	add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		req.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var js = JSON.parse_string(body.get_string_from_utf8())
		if js is Dictionary and js.get("sunucular") is Array:
			_remote = js.sunucular
			_rebuild_entries()
			_queue_all())
	if req.request("%s?t=%d" % [LIST_URL, int(Time.get_unix_time_from_system() / 300)]) != OK:
		req.queue_free()


# ------------------------------------------------------------------ çizim

func _draw_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var last_src := ""
	var titles := {"resmi": "Resmi", "liste": "Topluluk sunucuları", "benim": "Benim listem", "lan": "Yerel ağ"}
	for e in entries:
		var grp: String = "resmi" if e.source == "resmi" else e.source
		if grp != last_src:
			last_src = grp
			var g := Label.new()
			g.text = titles.get(grp, grp)
			g.add_theme_font_size_override("font_size", 13)
			g.add_theme_color_override("font_color", Color("#64748b"))
			_rows.add_child(g)
		_rows.add_child(_row(e))
	if entries.is_empty():
		var l := Label.new()
		l.text = "Listede sunucu yok."
		l.add_theme_color_override("font_color", Color("#94a3b8"))
		_rows.add_child(l)


func _row(e: Dictionary) -> Control:
	var info: Dictionary = _cache.get(e.key, {})
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#262b3b")
	sb.border_color = Color("#facc15") if e.source == "resmi" else Color("#3d4560")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var nm := str(e.name)
	# kendi eklediğin adreslerde sunucunun kendi adını göster
	if e.source in ["benim", "lan"] and str(info.get("name", "")) != "":
		nm = str(info.name)
	var n := Label.new()
	n.text = nm
	n.add_theme_font_size_override("font_size", 17)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(n)
	var desc := str(e.desc) if str(e.desc) != "" else str(info.get("desc", ""))
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", Color("#94a3b8"))
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(d)
	var st := Label.new()
	st.add_theme_font_size_override("font_size", 13)
	var can_join := true
	if e.key == _probing:
		st.text = "Yoklanıyor..."
		st.add_theme_color_override("font_color", Color("#fde68a"))
	elif info.is_empty():
		st.text = "Sırada..."
		st.add_theme_color_override("font_color", Color("#94a3b8"))
	elif not info.get("ok", false) and str(info.get("reason", "")) != "":
		st.text = "● " + str(info.reason)
		st.add_theme_color_override("font_color", Color("#fb923c"))
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif not info.get("ok", false):
		st.text = "● Kapalı ya da yanıt vermiyor"
		st.add_theme_color_override("font_color", Color("#f87171"))
	elif str(info.get("version", "")) != Net.VERSION:
		st.text = "● Sürüm %s (seninki %s)" % [str(info.version), Net.VERSION] if str(info.get("version", "")) != "" else "● Eski sürüm sunucu"
		st.add_theme_color_override("font_color", Color("#fb923c"))
		can_join = false
	else:
		var bits := ["● %d/%d oyuncu" % [int(info.get("players", 0)), int(info.get("max", Net.MAX_CLIENTS))]]
		if info.has("ping"):
			bits.append("%d ms" % int(info.ping))
		if str(info.get("weather", "")) != "":
			bits.append(str(info.weather))
		st.text = " · ".join(bits)
		st.add_theme_color_override("font_color", Color("#86efac"))
	v.add_child(st)
	if e.source != "resmi":
		var a := Label.new()
		a.text = e.key
		a.add_theme_font_size_override("font_size", 11)
		a.add_theme_color_override("font_color", Color("#64748b"))
		a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(a)
	var btns := VBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(btns)
	var j := Button.new()
	j.text = "Katıl"
	j.custom_minimum_size = Vector2(84, 40)
	j.disabled = not can_join
	j.pressed.connect(func(): join_requested.emit(str(e.get("url", e.address)), int(e.port)))
	btns.add_child(j)
	if e.source == "benim":
		var x := Button.new()
		x.text = "Sil"
		x.custom_minimum_size = Vector2(84, 30)
		x.add_theme_font_size_override("font_size", 13)
		x.pressed.connect(remove_saved.bind(str(e.address), int(e.port)))
		btns.add_child(x)
	return panel
