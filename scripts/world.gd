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
	"galeri": preload("res://scripts/ui/garage_panel.gd"),
	"pazar": preload("res://scripts/ui/bazaar_panel.gd"),
	"mobilya": preload("res://scripts/ui/furniture_shop_panel.gd"),
	"home": preload("res://scripts/ui/home_panel.gd"),
}
const BUILDING_TEX := {
	"hospital": preload("res://assets/buildings/hospital.svg"),
	"market": preload("res://assets/buildings/market.svg"),
	"casino": preload("res://assets/buildings/casino.svg"),
	"poker": preload("res://assets/buildings/poker.svg"),
	"realestate": preload("res://assets/buildings/realestate.svg"),
	"galeri": preload("res://assets/buildings/galeri.svg"),
	"pazar": preload("res://assets/buildings/pazar.svg"),
	"mobilya": preload("res://assets/buildings/mobilya.svg"),
}
const CAR_BODY := preload("res://assets/vehicles/car_body.svg")
const CAR_DETAIL := preload("res://assets/vehicles/car_detail.svg")
const BIKE_TEX := preload("res://assets/vehicles/bike.svg")
const Lighting = preload("res://scripts/lighting.gd")
const WeatherOverlay = preload("res://scripts/ui/weather_overlay.gd")
const FACING_ANGLE := {"right": 0.0, "down": PI / 2.0, "left": PI, "up": -PI / 2.0}
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
var lighting: Node2D
var weather: Control
var furn_tex := {}          # mobilya türü -> doku
var placing := ""           # mobilya yerleştirme modu (tür) ya da ""
var _room := -1             # içinde bulunduğum ev (arsa) ya da -1


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
	hud.profile_requested.connect(open_profile)
	hud.transfer_requested.connect(open_transfer)
	ui_layer.layer = 2
	var wl := CanvasLayer.new()
	wl.layer = 1
	add_child(wl)
	weather = WeatherOverlay.new()
	wl.add_child(weather)
	lighting = Lighting.new()
	add_child(lighting)
	for k in Homes.FURNITURE:
		furn_tex[k] = load("res://assets/furniture/%s.svg" % k)
	Homes.teleported.connect(_on_teleport)
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
			var ride := my_ride()
			var mult := Garage.speed_of(ride)
			if ride == "" and Map.in_sea(my_pos):
				mult = 0.55
			var step := dir.normalized() * SPEED * delta * mult
			# Eksen eksen dene ki kıyı/duvar boyunca kayabilelim.
			for s in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
				var np: Vector2 = _clamp_to_area(my_pos + s)
				if _can_stand(np, ride):
					my_moving = np != my_pos
					my_pos = np
					break
	Net.update_my_pos(my_pos, delta)
	camera.position = my_pos
	_update_area()
	var swimming := Map.in_sea(my_pos) and my_ride() == ""
	if swimming and not _was_swimming:
		Sfx.play("splash", -4.0)
	_was_swimming = swimming
	var outside := _room < 0
	Sfx.set_ambience(clampf(1.0 - (Map.BEACH.position.y - my_pos.y) / 700.0, 0.0, 1.0) if outside else 0.0)
	Sfx.set_environment((1.0 if Env.weather == "storm" else 0.6) if Env.is_rainy() and outside else 0.0,
		Env.darkness() * 0.8 if outside and not Env.is_rainy() else 0.0,
		my_moving and my_ride() in ["car", "boat"], 1.0 if my_ride() == "car" else 0.8)
	lighting.update(my_pos)
	weather.inside = not outside

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


func my_ride() -> String:
	return str(Net.roster.get(Net.my_id(), {}).get("ride", ""))


## Bulunduğum alan: ev içiysem oda, değilsem şehir.
func _clamp_to_area(p: Vector2) -> Vector2:
	if _room >= 0:
		var lvl := int(Land.view[_room].level) if _room < Land.view.size() else 1
		var r := Map.interior_rect(_room, lvl).grow(-18)
		return p.clamp(r.position, r.end)
	return p.clamp(Map.WORLD.position + Vector2(20, 20), Map.WORLD.end - Vector2(20, 20))


func _can_stand(p: Vector2, ride: String) -> bool:
	if _room >= 0:
		return true
	if Map.in_water(p):
		return false              # göl
	if ride == "boat":
		return Map.in_sea(p)      # tekne karaya çıkamaz
	if ride != "":
		return not Map.in_sea(p)  # bisiklet/araba denize giremez
	return true


func _update_area() -> void:
	var room := Map.interior_at(my_pos)
	if room == _room:
		return
	_room = room
	var r := Map.WORLD
	if room >= 0:
		var lvl := int(Land.view[room].level) if room < Land.view.size() else 1
		r = Map.interior_rect(room, lvl).grow(160)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)
	camera.reset_smoothing()
	if room < 0:
		placing = ""


func _on_teleport(pos: Vector2) -> void:
	my_pos = pos
	camera.position = pos
	Net.update_my_pos(my_pos, 1.0)
	_update_area()
	camera.reset_smoothing()
	Sfx.play("door")


## F: araca bin / in.
func _toggle_vehicle() -> void:
	var ride := my_ride()
	if ride != "":
		if ride == "boat" and not _near_shore():
			hud.show_toast("Tekneden inmek için kıyıya ya da iskeleye yaklaş.", false)
			return
		Garage.ride("")
		return
	if _room >= 0:
		return
	if Map.in_sea(my_pos):
		if Garage.owned.has("boat"):
			Garage.ride("boat")
			Sfx.play("splash_small")
		else:
			hud.show_toast("Teknen yok. Galeri'den alabilirsin.", false)
		return
	for k in ["car", "bike"]:
		if Garage.owned.has(k):
			Garage.ride(k)
			Sfx.play("bell" if k == "bike" else "door")
			return
	hud.show_toast("Aracın yok. Galeri'den bisiklet ya da araba alabilirsin.", false)


func _near_shore() -> bool:
	for off in [Vector2(0, -90), Vector2(60, 0), Vector2(-60, 0)]:
		if not Map.in_sea(my_pos + off):
			return true
	return false


## Fare altındaki karo (ev içinde, yerleştirme için).
func _mouse_tile() -> Vector2i:
	if _room < 0:
		return Vector2i(-1, -1)
	var lvl := int(Land.view[_room].level)
	var r := Map.interior_rect(_room, lvl)
	var m := get_global_mouse_position() - r.position
	return Vector2i(int(floor(m.x / Map.TILE)), int(floor(m.y / Map.TILE)))


func start_placing(k: String) -> void:
	placing = k
	hud.show_toast("Sol tık: yerleştir · Sağ tık: eşyayı kaldır · Esc: bitir")


func _facing_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and panel == null:
		if _room >= 0 and _room < Land.view.size() and Land.view[_room].owner == Net.my_name:
			if event.button_index == MOUSE_BUTTON_LEFT and placing != "":
				var t := _mouse_tile()
				var sz: Vector2i = Homes.FURNITURE[placing].size
				Homes.place(_room, placing, t.x - int(sz.x / 2.0), t.y - int(sz.y / 2.0))
				Sfx.play("place")
				if int(Homes.depot.get(placing, 0)) <= 1:
					placing = ""
				return
			if event.button_index == MOUSE_BUTTON_RIGHT:
				var list: Array = Land.view[_room].get("furniture", [])
				for idx in range(list.size() - 1, -1, -1):
					if Homes.furniture_rect(_room, int(Land.view[_room].level), list[idx]).has_point(get_global_mouse_position()):
						Homes.pickup(_room, idx)
						Sfx.play("place", -4.0, 1.3)
						return
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
		KEY_C:
			if panel == null:
				open_profile()
				get_viewport().set_input_as_handled()
		KEY_F:
			if panel == null:
				_toggle_vehicle()
				get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if panel != null:
				_close_panel()
				get_viewport().set_input_as_handled()
			elif placing != "":
				placing = ""
				get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			if panel == null:
				hud.focus_chat()
				get_viewport().set_input_as_handled()


func _update_zone() -> void:
	var z := {}
	if _room >= 0:
		var lvl := int(Land.view[_room].level) if _room < Land.view.size() else 1
		if Map.interior_door(_room, lvl).grow(10).has_point(my_pos):
			z = {"type": "exit_home", "label": "Evden Çık"}
		else:
			z = {"type": "home", "label": "Ev menüsü", "plot": _room}
		zone = z
		hud.set_hint("" if panel != null or placing != "" else "[E]  %s" % z.label)
		return
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
	if zone.type == "exit_home":
		Homes.exit_home()
		return
	panel = PANELS[zone.type].new()
	if zone.has("plot"):
		panel.focus_plot = zone.plot
	if zone.type == "fishing":
		panel.spot = Map.fishing_spot(my_pos)
	if panel.has_signal("place_requested"):
		panel.place_requested.connect(func(k):
			_close_panel()
			start_placing(k))
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -4.0)


## HUD'da bir oyuncunun adına tıklanınca: para gönder.
func open_transfer(to_name: String) -> void:
	if panel != null or to_name == Net.my_name:
		return
	panel = preload("res://scripts/ui/transfer_panel.gd").new()
	panel.to_name = to_name
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)


## Karakter Kartı (C tuşu / HUD "Profil").
func open_profile() -> void:
	if panel != null:
		return
	panel = preload("res://scripts/ui/profile_panel.gd").new()
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
	_draw_interiors()
	for lp in Map.lamp_positions():
		draw_rect(Rect2(lp.x - 2, lp.y - 34, 4, 34), Color("#374151"))
		draw_circle(lp + Vector2(0, -36), 6, Color("#fde68a") if Env.darkness() > 0.2 else Color("#e5e7eb"))
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
			items.append([shown[id].y, "p", [shown[id], info.get("appearance", {}), "%s · Sv.%d" % [info.name, int(info.get("level", 1))], false, a.facing, a.moving, str(info.get("ride", "")), info.get("color", Color.WHITE)]])
	var mine = Net.roster.get(Net.my_id())
	var my_app = mine.get("appearance", {}) if mine else Net.my_appearance
	var my_level: int = int(mine.get("level", 1)) if mine else 1
	var my_col: Color = mine.get("color", Color.WHITE) if mine else Color.WHITE
	items.append([my_pos.y, "p", [my_pos, my_app, "%s · Sv.%d" % [Net.my_name, my_level], true, my_facing, my_moving, my_ride(), my_col]])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		if it[1] == "n":
			_draw_nature(it[2])
		else:
			var a: Array = it[2]
			_draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7])
	_draw_placement_ghost()


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
	# Tabela SVG'de boş bırakıldı (eski binalarda y=86..118, yenilerde sign_y).
	_text(r.position + Vector2(0, float(b.get("sign_y", 110))), b.label.to_upper(), 22, Color.WHITE, r.size.x)


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


## Ekranda görünen ev içlerini çiz (oda, duvar, kapı, mobilyalar).
func _draw_interiors() -> void:
	var vsize := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200)
	for i in Land.view.size():
		var p: Dictionary = Land.view[i]
		var lvl := int(p.level)
		if lvl < 1:
			continue
		var r := Map.interior_rect(i, lvl)
		if not view.intersects(r):
			continue
		draw_rect(r.grow(28), Color("#3f2d22"))                # duvarlar
		draw_rect(r, Color("#c9a271"))                         # parke
		var off := 0
		for y in range(int(r.position.y), int(r.end.y), 24):
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("#b38b5d"), 1)
			for x in range(int(r.position.x) + off, int(r.end.x), 96):
				draw_line(Vector2(x, y), Vector2(x, y + 24), Color("#b38b5d"), 1)
			off = 48 - off
		draw_rect(Rect2(r.position.x, r.position.y - 28, r.size.x, 28), Color("#e9dcc6"))   # arka duvar
		for wx in range(int(r.position.x) + 60, int(r.end.x) - 60, 200):
			draw_rect(Rect2(wx, r.position.y - 24, 60, 20), Color("#93c5fd") if Env.darkness() < 0.5 else Color("#1e293b"))
		var door := Map.interior_door(i, lvl)
		draw_rect(Rect2(door.position.x, r.end.y - 6, door.size.x, 34), Color("#7c4a1e"))
		draw_rect(Rect2(door.position.x + 8, r.end.y - 30, door.size.x - 16, 24), Color("#9f1239"))   # paspas
		_text(Vector2(r.position.x, r.position.y - 36), "%s'in evi%s" % [p.owner, "  (kapı açık)" if p.get("door_open", false) else ""], 18, Color.WHITE, r.size.x)
		var furn: Array = p.get("furniture", [])
		for floor_pass in [true, false]:
			for f in furn:
				if bool(Homes.FURNITURE[f.k].get("floor", false)) == floor_pass:
					draw_texture_rect(furn_tex[f.k], Homes.furniture_rect(i, lvl, f), false)


func _draw_placement_ghost() -> void:
	if placing == "" or _room < 0:
		return
	var lvl := int(Land.view[_room].level)
	var t := _mouse_tile()
	var sz: Vector2i = Homes.FURNITURE[placing].size
	var f := {"k": placing, "x": t.x - int(sz.x / 2.0), "y": t.y - int(sz.y / 2.0)}
	var fr := Homes.furniture_rect(_room, lvl, f)
	var ok := Map.interior_rect(_room, lvl).encloses(fr)
	draw_texture_rect(furn_tex[placing], fr, false, Color(1, 1, 1, 0.6))
	draw_rect(fr, Color("#22c55e") if ok else Color("#ef4444"), false, 3)


func _draw_vehicle(p: Vector2, ride: String, facing: String, col: Color) -> void:
	var ang: float = FACING_ANGLE.get(facing, 0.0)
	match ride:
		"car":
			draw_set_transform(p + Vector2(4, 6), ang, Vector2.ONE)
			draw_rect(Rect2(-46, -24, 92, 48), Color(0, 0, 0, 0.25))
			draw_set_transform(p, ang, Vector2.ONE)
			draw_texture_rect(CAR_BODY, Rect2(-48, -26, 96, 52), false, col)
			draw_texture_rect(CAR_DETAIL, Rect2(-48, -26, 96, 52), false)
		"bike":
			draw_set_transform(p + Vector2(0, 8), ang, Vector2.ONE)
			draw_texture_rect(BIKE_TEX, Rect2(-32, -12, 64, 24), false)
		"boat":
			var bob := sin(_t * 3.0) * 2.0
			var flip := -1.0 if facing == "left" else 1.0
			draw_set_transform(p + Vector2(0, 10 + bob), sin(_t * 1.7) * 0.05, Vector2(0.8 * flip, 0.8))
			draw_texture_rect(BOAT_TEX, Rect2(-65, -30, 130, 60), false)
	draw_set_transform(Vector2.ZERO)


func _draw_player(p: Vector2, app: Dictionary, pname: String, me: bool, facing: String, moving: bool,
		ride: String = "", col: Color = Color.WHITE) -> void:
	var name_col := Color("#fde68a") if me else Color.WHITE
	match ride:
		"car":
			_draw_vehicle(p, ride, facing, col)
			_text(p + Vector2(-90, -40), pname, 16, name_col, 180)
			return
		"bike":
			_draw_vehicle(p, ride, facing, col)
			Avatar.draw(self, p, app, facing, 0)
			_text(p + Vector2(-90, -56), pname, 16, name_col, 180)
			return
		"boat":
			_draw_vehicle(p, ride, facing, col)
			Avatar.draw(self, p + Vector2(0, -6), app, facing, 0, 1.0, true)
			_text(p + Vector2(-90, -44), pname, 16, name_col, 180)
			return
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
