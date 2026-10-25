extends "res://scripts/ui/game_panel.gd"
## Telefon: mesajlar, arkadaşlar, şehir haberleri, fotoğraf albümü ve kamera.

signal camera_requested
signal nav_requested(pos: Vector2)

const ALBUM := "user://album"

var tabs: HBoxContainer
var page: VBoxContainer
var cur := "msg"
var chat_with := ""
var _input: LineEdit


func _ready() -> void:
	build("Telefon", Vector2(500, 0))
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	page = VBoxContainer.new()
	page.size_flags_horizontal = SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	scroll.add_child(page)
	Phone.changed.connect(_refresh)
	Phone.refresh()
	_refresh()


func _show(t: String) -> void:
	cur = t
	chat_with = ""
	if t == "friends" or t == "news":
		Phone.refresh()
	_refresh()


func _tab(label: String, id: String) -> void:
	var b := add_button(tabs, label, _show.bind(id))
	b.custom_minimum_size = Vector2(0, 34)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	if id == cur:
		b.modulate = Color("#facc15")


func _refresh() -> void:
	for c in tabs.get_children():
		c.queue_free()
	_tab("Mesajlar%s" % ((" (%d)" % Phone.unread) if Phone.unread > 0 else ""), "msg")
	_tab("Arkadaşlar", "friends")
	_tab("Haberler", "news")
	_tab("Albüm", "album")
	add_button(tabs, "📷", func(): camera_requested.emit()).tooltip_text = "Fotoğraf modu (%s)" % Settings.key_name("photo")
	for c in page.get_children():
		c.queue_free()
	_input = null
	match cur:
		"msg":
			_messages() if chat_with == "" else _chat()
		"friends":
			_friends()
		"news":
			_news()
		"album":
			_album()


static func ago(unix: float) -> String:
	var s := Time.get_unix_time_from_system() - unix
	if s < 60:
		return "şimdi"
	if s < 3600:
		return "%d dk önce" % int(s / 60.0)
	if s < 86400:
		return "%d sa önce" % int(s / 3600.0)
	return "%d gün önce" % int(s / 86400.0)


func _messages() -> void:
	var row := HBoxContainer.new()
	page.add_child(row)
	var to := LineEdit.new()
	to.placeholder_text = "Kime? (oyuncu adı)"
	to.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(to)
	add_button(row, "Yeni mesaj", func():
		if to.text.strip_edges() != "":
			chat_with = to.text.strip_edges()
			_refresh())
	var convs := Phone.conversations()
	if convs.is_empty():
		add_label(page, "Henüz mesaj yok. Bir arkadaşına yaz; çevrimdışı olsa da ulaşır.", 14, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for c in convs:
		var b := add_button(page, "%s%s\n%s%s  ·  %s" % [c.w, ("  (%d yeni)" % c.unread) if c.unread > 0 else "",
			"Sen: " if c.last.get("o", false) else "", str(c.last.x).left(40), ago(float(c.last.d))], _open_chat.bind(str(c.w)))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		if c.unread > 0:
			b.modulate = Color("#bfdbfe")


func _open_chat(w: String) -> void:
	chat_with = w
	Phone.read_all(w)
	_refresh()


func _chat() -> void:
	var head := HBoxContainer.new()
	page.add_child(head)
	add_button(head, "← Geri", func(): chat_with = ""; _refresh())
	add_label(head, "  %s" % chat_with, 18, Color("#facc15"))
	for m in Phone.inbox:
		if str(m.w) != chat_with:
			continue
		var mine: bool = m.get("o", false)
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#1d4ed8") if mine else Color("#334155")
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(8)
		box.add_theme_stylebox_override("panel", sb)
		box.size_flags_horizontal = SIZE_SHRINK_END if mine else SIZE_SHRINK_BEGIN
		box.custom_minimum_size = Vector2(120, 0)
		page.add_child(box)
		var v := VBoxContainer.new()
		box.add_child(v)
		var l := add_label(v, str(m.x), 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
		add_label(v, ago(float(m.d)), 11, Color("#cbd5e1"))
	var row := HBoxContainer.new()
	page.add_child(row)
	_input = LineEdit.new()
	_input.placeholder_text = "Mesaj yaz..."
	_input.max_length = Phone.MSG_LEN
	_input.size_flags_horizontal = SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_t): _send())
	row.add_child(_input)
	add_button(row, "Gönder", _send)
	_input.call_deferred("grab_focus")


func _send() -> void:
	if _input == null or _input.text.strip_edges() == "":
		return
	Phone.send(chat_with, _input.text)
	_input.text = ""


func _friends() -> void:
	var row := HBoxContainer.new()
	page.add_child(row)
	var n := LineEdit.new()
	n.placeholder_text = "Oyuncu adı"
	n.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(n)
	add_button(row, "Arkadaş ekle", func():
		if n.text.strip_edges() != "":
			Phone.add_friend(n.text.strip_edges()))
	add_label(page, "Karşılıklı arkadaşsanız birbirinizin nerede olduğunu görür, yol tarifi alabilirsiniz.", 13, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Phone.friends.is_empty():
		add_label(page, "Arkadaş listen boş.", 14, Color("#7c859e"))
	for f in Phone.friends:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		page.add_child(r)
		var st := "çevrimdışı"
		if f.online:
			st = "çevrimiçi — %s" % f.get("area", "?") if f.mutual else "çevrimiçi (konum için seni de eklemeli)"
		var l := add_label(r, "%s %s\n%s" % ["●" if f.online else "○", f.n, st], 14, Settings.ok_text() if f.online else Color("#94a3b8"))
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		add_button(r, "Mesaj", func(): cur = "msg"; _open_chat(str(f.n)))
		if f.has("pos"):
			add_button(r, "Yol tarifi", func(): nav_requested.emit(f.pos))
		add_button(r, "Sil", Phone.remove_friend.bind(str(f.n)))


func _news() -> void:
	if Phone.news.is_empty():
		add_label(page, "Henüz haber yok.", 14, Color("#7c859e"))
	var list: Array = Phone.news.duplicate()
	list.reverse()
	for n in list:
		var l := add_label(page, "• %s  (%s)" % [n.x, ago(float(n.d))], 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


static func album_files() -> Array:
	var out: Array = []
	var d := DirAccess.open(ALBUM)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".png"):
			out.append(ALBUM + "/" + f)
	out.sort()
	out.reverse()
	return out


func _album() -> void:
	var files := album_files()
	if files.is_empty():
		add_label(page, "Albüm boş. 📷 ya da %s ile fotoğraf modunu aç." % Settings.key_name("photo"), 14, Color("#94a3b8"))
		return
	add_label(page, "%d fotoğraf  •  Klasör: %s" % [files.size(), ProjectSettings.globalize_path(ALBUM)], 12, Color("#94a3b8")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var g := GridContainer.new()
	g.columns = 3
	page.add_child(g)
	for f in files.slice(0, 30):
		var img := Image.load_from_file(f)
		if img == null:
			continue
		img.resize(144, 81)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.custom_minimum_size = Vector2(144, 81)
		tr.tooltip_text = f.get_file()
		tr.mouse_filter = MOUSE_FILTER_STOP
		tr.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_view_photo(f))
		g.add_child(tr)


func _view_photo(f: String) -> void:
	for c in page.get_children():
		c.queue_free()
	add_button(page, "← Albüm", func(): _refresh())
	var img := Image.load_from_file(f)
	if img != null:
		img.resize(464, 261)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		page.add_child(tr)
	add_label(page, f.get_file(), 12, Color("#94a3b8"))
	add_button(page, "Sil", func():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		_refresh())
