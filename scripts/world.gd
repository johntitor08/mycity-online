extends Node2D
## Şehir sahnesi: haritayı çizer, oyuncuları yürütür, binalara girişi yönetir.
## Görseller assets/ altındaki SVG'lerdir (tools/make_art.py ile üretilir).

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const HUD = preload("res://scripts/ui/hud.gd")
const PANELS := {
	"hospital": preload("res://scripts/ui/hospital_panel.gd"),
	"market": preload("res://scripts/ui/market_panel.gd"),
	"casino": preload("res://scripts/ui/casino_panel.gd"),
	"poker": preload("res://scripts/ui/poker_panel.gd"),
	"realestate": preload("res://scripts/ui/land_panel.gd"),
	"fishing": preload("res://scripts/ui/fish_panel.gd"),
}
const BUILDING_TEX := {
	"hospital": preload("res://assets/buildings/hospital.svg"),
	"market": preload("res://assets/buildings/market.svg"),
	"casino": preload("res://assets/buildings/casino.svg"),
	"poker": preload("res://assets/buildings/poker.svg"),
	"realestate": preload("res://assets/buildings/realestate.svg"),
}
const PLOT_TEX := [
	null,
	preload("res://assets/plots/house.svg"),
	preload("res://assets/plots/villa.svg"),
	preload("res://assets/plots/tower.svg"),
]
const Avatar = preload("res://scripts/avatar.gd")
# Doğa ve plaj nesneleri: [doku, yükseklik]
const PROPS := [
	[preload("res://assets/nature/tree_round.svg"), 72.0],
	[preload("res://assets/nature/tree_pine.svg"), 80.0],
	[preload("res://assets/nature/bush.svg"), 30.0],
	[preload("res://assets/beach/palm.svg"), 120.0],
	[preload("res://assets/beach/umbrella_red.svg"), 92.0],
	[preload("res://assets/beach/umbrella_blue.svg"), 92.0],
	[preload("res://assets/beach/umbrella_yellow.svg"), 92.0],
	[preload("res://assets/beach/sunbed.svg"), 58.0],
	[preload("res://assets/beach/lifeguard.svg"), 128.0],
	[preload("res://assets/beach/sandcastle.svg"), 40.0],
]
const BOAT_TEX := preload("res://assets/beach/boat.svg")
const SPEED := 300.0

var my_pos := Vector2.ZERO
var my_facing := "down"
var my_moving := false
var shown := {}            # peer_id -> ekranda yumuşatılmış konum
var anim := {}             # peer_id -> {facing, moving}
var camera: Camera2D
var hud
var ui_layer: CanvasLayer
var panel = null
var zone := {}
var font: Font
var nature: Array = []     # [konum, PROPS indeksi, ölçek]
var _was_swimming := false
var decor: Array = []      # [konum, tür] çim/çiçek süsleri
var _t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	my_pos = Net.spawn_pos
	camera = Camera2D.new()
	add_child(camera)
	camera.limit_left = int(Map.WORLD.position.x)
	camera.limit_top = int(Map.WORLD.position.y)
	camera.limit_right = int(Map.WORLD.end.x)
	camera.limit_bottom = int(Map.WORLD.end.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = my_pos
	camera.make_current()
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	hud = HUD.new()
	ui_layer.add_child(hud)
	hud.character_requested.connect(open_character_editor)
	_make_nature()


func _process(delta: float) -> void:
	_t += delta
	my_moving = false
	if panel == null and not hud.is_typing():
		var dir := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			dir.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir.x += 1
		if dir != Vector2.ZERO:
			my_facing = _facing_of(dir)
			var step := dir.normalized() * SPEED * delta * (0.55 if Map.in_sea(my_pos) else 1.0)
			# Göle yürünmez; eksen eksen dene ki kıyı boyunca kayabilelim.
			for s in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
				var np: Vector2 = (my_pos + s).clamp(Map.WORLD.position + Vector2(20, 20), Map.WORLD.end - Vector2(20, 20))
				if not Map.in_water(np):
					my_moving = np != my_pos
					my_pos = np
					break
	Net.update_my_pos(my_pos, delta)
	camera.position = my_pos
	var swimming := Map.in_sea(my_pos)
	if swimming and not _was_swimming:
		Sfx.play("splash", -4.0)
	_was_swimming = swimming
	Sfx.set_ambience(clampf(1.0 - (Map.BEACH.position.y - my_pos.y) / 700.0, 0.0, 1.0))

	var me := Net.my_id()
	for id in Net.pos_view:
		if id == me:
			continue
		var target: Vector2 = Net.pos_view[id]
		var old: Vector2 = shown.get(id, target)
		var now := old.lerp(target, minf(1.0, delta * 10.0))
		shown[id] = now
		var a: Dictionary = anim.get(id, {"facing": "down", "moving": false})
		var d := target - old
		a.moving = d.length() > 2.0
		if a.moving:
			a.facing = _facing_of(d)
		anim[id] = a
	for id in shown.keys():
		if not Net.pos_view.has(id) or not Net.roster.has(id):
			shown.erase(id)
			anim.erase(id)
	_update_zone()
	queue_redraw()


func _facing_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and panel == null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.6, 0.6), Vector2(2, 2))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.6, 0.6), Vector2(2, 2))
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_E:
			if panel == null:
				_open_panel()
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if panel != null:
				_close_panel()
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if panel == null:
				hud.focus_chat()
				get_viewport().set_input_as_handled()


func _update_zone() -> void:
	var z := {}
	for b in Map.BUILDINGS:
		if b.rect.has_point(my_pos):
			z = {"type": b.type, "label": b.label}
	match Map.fishing_spot(my_pos):
		"lake":
			z = {"type": "fishing", "label": "Göl İskelesi — Balık Tut"}
		"sea":
			z = {"type": "fishing", "label": "Deniz İskelesi — Balık Tut"}
	for i in Map.PLOT_COUNT:
		if Map.plot_rect(i).has_point(my_pos):
			z = {"type": "realestate", "label": "Arsa #%d" % (i + 1), "plot": i}
	zone = z
	hud.set_hint("" if z.is_empty() or panel != null else "[E]  %s" % z.label)


func _open_panel() -> void:
	if zone.is_empty():
		return
	panel = PANELS[zone.type].new()
	if zone.has("plot"):
		panel.focus_plot = zone.plot
	if zone.type == "fishing":
		panel.spot = Map.fishing_spot(my_pos)
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -4.0)


## HUD'daki "Karakter" butonundan çağrılır.
func open_character_editor() -> void:
	if panel != null:
		return
	panel = preload("res://scripts/ui/character_panel.gd").new()
	panel.appearance = Net.roster.get(Net.my_id(), {}).get("appearance", {})
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)


func _close_panel() -> void:
	if panel:
		panel.queue_free()
		panel = null
		get_viewport().gui_release_focus()


# ================================================================== çizim

func _make_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var blocked: Array = []
	for b in Map.BUILDINGS:
		blocked.append(b.rect.grow(36))
	for r in Map.ROADS:
		blocked.append(r.grow(30))
	blocked.append(Map.LAKE.grow(30))
	blocked.append(Map.DOCK.grow(30))
	blocked.append(Rect2(0, Map.BEACH.position.y - 30, 2400, 1000))   # plaj/deniz ayrı yerleşir
	var decor_blocked := blocked.duplicate()   # çim/çiçek arsalara da serpilebilir
	blocked.append(Rect2(Map.PLOT_ORIGIN - Vector2(30, 30), Vector2(1190, 650)))
	for _k in 320:
		var p := Vector2(rng.randf_range(30, 2370), rng.randf_range(40, 1590))
		var ok := true
		for r in blocked:
			if r.has_point(p):
				ok = false
				break
		if ok:
			var kind := 2 if rng.randf() < 0.25 else rng.randi_range(0, 1)
			nature.append([p, kind, rng.randf_range(0.85, 1.25)])
	# Plaj: palmiyeler, şemsiye + şezlong takımları, cankurtaran, kumdan kale
	var by := Map.BEACH.position.y
	for x in range(60, 2400, 170):
		if absf(x - 1005) < 90 or absf(x - 1600) < 90:
			continue
		nature.append([Vector2(x + rng.randf_range(-30, 30), by + 55 + rng.randf_range(0, 25)), 3, rng.randf_range(0.9, 1.15)])
	var k := 0
	for x in [140, 430, 720, 1240, 1820, 2120]:
		nature.append([Vector2(x, by + 150), 4 + k % 3, 1.0])
		nature.append([Vector2(x + 52, by + 175), 7, 1.0])
		nature.append([Vector2(x - 50, by + 178), 7, 1.0])
		k += 1
	nature.append([Vector2(1420, by + 190), 8, 1.0])
	nature.append([Vector2(880, by + 200), 9, 1.0])
	nature.sort_custom(func(a, b): return a[0].y < b[0].y)
	for _k in 900:
		var p := Vector2(rng.randf_range(10, 2390), rng.randf_range(10, 1590))
		var ok := true
		for r in decor_blocked:
			if r.has_point(p):
				ok = false
				break
		if ok and not Map.in_water(p):
			decor.append([p, rng.randi_range(0, 9)])


func _draw() -> void:
	draw_rect(Map.WORLD, Color("#5d9c4a"))
	for d in decor:
		var p: Vector2 = d[0]
		match d[1]:
			0:
				draw_circle(p, 2.5, Color("#fde047"))
			1:
				draw_circle(p, 2.5, Color("#f9a8d4"))
			2:
				draw_circle(p, 2.5, Color("#ffffff"))
			_:
				draw_line(p, p + Vector2(-3, -7), Color("#4a8a3a"), 2)
				draw_line(p, p + Vector2(2, -8), Color("#4a8a3a"), 2)
	_draw_roads()
	_draw_beach()
	_draw_lake()
	for i in Map.PLOT_COUNT:
		_draw_plot(i)
	for b in Map.BUILDINGS:
		_draw_building(b)
	# Ağaçlar ve oyuncular y'ye göre sıralanarak çizilir (önde olan üstte görünür).
	var items: Array = []
	for n in nature:
		items.append([n[0].y, "n", n])
	for id in shown:
		var info = Net.roster.get(id)
		if info:
			var a: Dictionary = anim.get(id, {"facing": "down", "moving": false})
			items.append([shown[id].y, "p", [shown[id], info.get("appearance", {}), info.name, false, a.facing, a.moving]])
	var mine = Net.roster.get(Net.my_id())
	var my_app = mine.get("appearance", {}) if mine else Net.my_appearance
	items.append([my_pos.y, "p", [my_pos, my_app, Net.my_name, true, my_facing, my_moving]])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		if it[1] == "n":
			_draw_nature(it[2])
		else:
			var a: Array = it[2]
			_draw_player(a[0], a[1], a[2], a[3], a[4], a[5])


func _text(pos: Vector2, text: String, size: int, color: Color, width: float = -1, outline: bool = true) -> void:
	var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0 else HORIZONTAL_ALIGNMENT_LEFT
	if outline:
		draw_string_outline(font, pos, text, align, width, size, 5, Color(0, 0, 0, 0.75))
	draw_string(font, pos, text, align, width, size, color)


## Dokuyu, alt-orta noktası `foot` olacak şekilde `height` yüksekliğinde çizer.
func _draw_tex_at(tex: Texture2D, foot: Vector2, height: float, modulate: Color = Color.WHITE) -> void:
	var s := tex.get_size()
	var w := s.x / s.y * height
	draw_texture_rect(tex, Rect2(foot.x - w / 2.0, foot.y - height, w, height), false, modulate)


func _draw_roads() -> void:
	for r in Map.ROADS:
		draw_rect(r.grow(8), Color("#9ca3af"))   # kaldırım
	for r in Map.ROADS:
		draw_rect(r, Color("#3f4148"))
	var line := Color(1, 1, 1, 0.6)
	for x in range(0, 2400, 70):
		draw_rect(Rect2(x, 442, 34, 6), line)
	for y in range(520, 1600, 70):
		draw_rect(Rect2(1002, y, 6, 34), line)
	for x in range(1070, 2400, 70):
		draw_rect(Rect2(x, 822, 34, 6), line)


func _ellipse(r: Rect2, n: int = 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := r.get_center()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.size.x / 2.0, sin(a) * r.size.y / 2.0))
	return pts


func _draw_lake() -> void:
	draw_colored_polygon(_ellipse(Map.LAKE.grow(18)), Color("#d9c38c"))
	draw_colored_polygon(_ellipse(Map.LAKE), Color("#2f7fc1"))
	draw_colored_polygon(_ellipse(Map.LAKE.grow(-90)), Color("#2a6fab"))
	for i in 6:
		var y := Map.LAKE.position.y + 160 + i * 90
		var x := Map.LAKE.position.x + 180 + sin(_t + i) * 30.0
		draw_arc(Vector2(x, y), 22, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.35), 2)
	for lp in [Vector2(260, 760), Vector2(300, 790), Vector2(560, 1330), Vector2(190, 1150)]:
		draw_circle(lp, 13, Color("#3f9142"))
		draw_colored_polygon(PackedVector2Array([lp, lp + Vector2(13, -4), lp + Vector2(13, 4)]), Color("#2f7fc1"))
	draw_circle(Vector2(300, 784), 4, Color("#f9a8d4"))
	var d := Map.DOCK
	draw_rect(Rect2(d.position + Vector2(4, 6), d.size), Color(0, 0, 0, 0.25))
	draw_rect(d, Color("#a0703c"))
	for x in range(int(d.position.x), int(d.end.x), 20):
		draw_line(Vector2(x, d.position.y), Vector2(x, d.end.y), Color("#6b4423"), 2)
	draw_rect(d, Color("#232634"), false, 3)
	for px in [d.position.x + 8, d.position.x + 70]:
		draw_circle(Vector2(px, d.end.y + 2), 6, Color("#6b4423"))
	_text(d.position + Vector2(0, -10), "İSKELE", 18, Color.WHITE, d.size.x)


func _draw_building(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.22))
	draw_texture_rect(BUILDING_TEX[b.type], r, false)
	# Tabela SVG'de y=86..118 aralığında boş bırakıldı.
	_text(r.position + Vector2(0, 110), b.label.to_upper(), 22, Color.WHITE, r.size.x)


func _draw_plot(i: int) -> void:
	var r := Map.plot_rect(i)
	var p = Land.view[i] if i < Land.view.size() else {"owner": "", "level": 0, "price": Map.PLOT_PRICES[i]}
	var owner: String = p.owner
	var c := r.get_center()
	if owner == "":
		draw_rect(r, Color("#b8a06a"))
		for k in 6:
			draw_circle(r.position + Vector2(30 + k * 41, 40 + (k * 53) % 110), 4, Color("#9c8655"))
		draw_rect(r, Color("#f5f5f4"), false, 4)
		_text(r.position + Vector2(10, 26), "#%d" % (i + 1), 18, Color.WHITE)
		draw_rect(Rect2(c.x - 3, c.y - 6, 6, 46), Color("#5b3a1e"))
		draw_rect(Rect2(c.x - 62, c.y - 46, 124, 44), Color("#fef3c7"))
		draw_rect(Rect2(c.x - 62, c.y - 46, 124, 44), Color("#dc2626"), false, 3)
		_text(Vector2(c.x - 62, c.y - 28), "SATILIK", 16, Color("#b91c1c"), 124, false)
		_text(Vector2(c.x - 62, c.y - 9), U.money(int(p.price)), 14, Color("#111"), 124, false)
		return
	var col := U.name_color(owner)
	draw_rect(r, Color("#7cb55a"))
	draw_rect(Rect2(c.x - 14, c.y + 20, 28, r.end.y - c.y - 20), Color("#d6c7a1"))   # yürüme yolu
	draw_rect(r, Color("#f5f5f4"), false, 4)
	_text(r.position + Vector2(10, 26), "#%d" % (i + 1), 18, Color.WHITE)
	var level := int(p.level)
	match level:
		0:
			_text(Vector2(r.position.x, c.y), "Boş arsa", 16, Color(1, 1, 1, 0.8), r.size.x)
		1:
			_draw_tex_at(PLOT_TEX[1], Vector2(c.x, c.y + 42), 120)
		2:
			_draw_tex_at(PLOT_TEX[2], Vector2(c.x, c.y + 50), 130)
		3:
			_draw_tex_at(PLOT_TEX[3], Vector2(c.x, c.y + 60), 158)
	# Sahip bayrağı
	var fp := r.position + Vector2(r.size.x - 34, 14)
	draw_rect(Rect2(fp, Vector2(3, 34)), Color("#374151"))
	draw_colored_polygon(PackedVector2Array([fp + Vector2(3, 0), fp + Vector2(26, 7), fp + Vector2(3, 14)]), col)
	_text(Vector2(r.position.x, r.end.y - 8), owner, 16, col.lightened(0.4), r.size.x)


func _draw_nature(n: Array) -> void:
	var prop: Array = PROPS[n[1]]
	var h: float = prop[1] * n[2]
	var p: Vector2 = n[0]
	if n[1] != 7:   # şezlongun gölgesi yok (yere yatık)
		draw_set_transform(p + Vector2(0, -2), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, h * (0.3 if n[1] < 3 else 0.22), Color(0, 0, 0, 0.18))
		draw_set_transform(Vector2.ZERO)
	_draw_tex_at(prop[0], p, h)


func _draw_beach() -> void:
	var b := Map.BEACH
	draw_rect(Rect2(b.position.x, b.position.y - 10, b.size.x, 14), Color("#c9b57e"))   # çimden kuma geçiş
	draw_rect(Rect2(b.position, Vector2(b.size.x, b.size.y + 40)), Color("#f0dba5"))
	for i in 160:
		var x := float((i * 397) % 2400)
		var y := b.position.y + 10 + float((i * 211) % int(b.size.y - 20))
		draw_circle(Vector2(x, y), 1.6, Color("#d8c08a"))
	# deniz
	var sea := Map.SEA
	draw_rect(Rect2(sea.position.x, sea.position.y - 10, sea.size.x, sea.size.y + 10), Color("#1f78b8"))
	var shallow := PackedVector2Array()
	var foam := PackedVector2Array()
	for i in 61:
		var x := i * 40.0
		var y := sea.position.y + sin(x / 60.0) * 6.0 + sin(x / 90.0 + _t * 1.3) * 5.0
		foam.append(Vector2(x, y))
		shallow.append(Vector2(x, y))
	for i in range(60, -1, -1):
		shallow.append(Vector2(i * 40.0, sea.position.y + 70 + sin(i * 0.7 + _t * 0.8) * 8.0))
	draw_colored_polygon(shallow, Color("#4fb0dd"))
	draw_polyline(foam, Color(1, 1, 1, 0.85), 5)
	for i in 30:
		var sp := Vector2(float((i * 571) % 2400), sea.position.y + 100 + float((i * 137) % 320))
		var a := 0.25 + 0.25 * sin(_t * 2.0 + i)
		draw_line(sp, sp + Vector2(14, 0), Color(1, 1, 1, a), 2)
	# sandal (dalgada sallanır)
	var bp := Vector2(2050, 2120 + sin(_t * 1.2) * 4.0)
	draw_set_transform(bp, sin(_t * 0.9) * 0.04, Vector2.ONE)
	draw_texture_rect(BOAT_TEX, Rect2(-65, -30, 130, 60), false)
	draw_set_transform(Vector2.ZERO)
	# iskele
	var pr := Map.PIER
	for y in range(int(Map.SEA.position.y) + 10, int(pr.end.y), 60):
		draw_rect(Rect2(pr.position.x - 6, y, 10, 22), Color("#5b3a1e"))
		draw_rect(Rect2(pr.end.x - 4, y, 10, 22), Color("#5b3a1e"))
	draw_rect(Rect2(pr.position + Vector2(5, 8), pr.size), Color(0, 0, 0, 0.2))
	draw_rect(pr, Color("#a0703c"))
	for y in range(int(pr.position.y), int(pr.end.y), 18):
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), Color("#6b4423"), 2)
	draw_rect(pr, Color("#232634"), false, 3)
	_text(Vector2(pr.position.x - 60, pr.end.y + 24), "DENİZ İSKELESİ", 16, Color.WHITE, pr.size.x + 120)


func _draw_player(p: Vector2, app: Dictionary, pname: String, me: bool, facing: String, moving: bool) -> void:
	var swim := Map.in_sea(p)
	if swim:
		var r := 18.0 + sin(_t * 4.0) * 2.0
		draw_set_transform(p + Vector2(0, 4), 0, Vector2(1, 0.4))
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(1, 1, 1, 0.7), 3)
		draw_arc(Vector2.ZERO, r + 8, 0, TAU, 32, Color(1, 1, 1, 0.3), 2)
		draw_set_transform(Vector2.ZERO)
	else:
		# gölge (ve kendi karakterinde beyaz halka)
		draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
		if me:
			draw_arc(Vector2.ZERO, 19, 0, TAU, 32, Color(1, 1, 1, 0.85), 3)
		draw_set_transform(Vector2.ZERO)
	var frame := 0
	if moving:
		frame = [1, 0, 2, 0][int(_t * (6.0 if swim else 9.0)) % 4]
	Avatar.draw(self, p, app, facing, frame, 1.0, swim)
	_text(p + Vector2(-90, -56 + (22 if swim else 0)), pname, 16, Color("#fde68a") if me else Color.WHITE, 180)
