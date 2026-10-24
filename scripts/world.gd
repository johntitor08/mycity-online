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
	"petshop": preload("res://scripts/ui/pet_panel.gd"),
	"muhtarlik": preload("res://scripts/ui/story_panel.gd"),
	"karakol": preload("res://scripts/ui/police_panel.gd"),
	"race": preload("res://scripts/ui/event_panel.gd"),
	"banka": preload("res://scripts/ui/bank_panel.gd"),
	"carsi": preload("res://scripts/ui/shop_panel.gd"),
}
const GRASS := {"spring": Color("#5d9c4a"), "summer": Color("#78a443"), "autumn": Color("#8f9645"), "winter": Color("#d6e2e6")}
const BIZ_TEX := [
	null,
	preload("res://assets/plots/bufe.svg"),
	preload("res://assets/plots/kafe.svg"),
	preload("res://assets/plots/restoran.svg"),
]
const PET_TEX := {
	"cat": preload("res://assets/pets/cat.svg"),
	"dog": preload("res://assets/pets/dog.svg"),
	"parrot": preload("res://assets/pets/parrot.svg"),
}
const NpcSim = preload("res://scripts/npc_sim.gd")
const BUILDING_TEX := {
	"hospital": preload("res://assets/buildings/hospital.svg"),
	"market": preload("res://assets/buildings/market.svg"),
	"casino": preload("res://assets/buildings/casino.svg"),
	"poker": preload("res://assets/buildings/poker.svg"),
	"realestate": preload("res://assets/buildings/realestate.svg"),
	"galeri": preload("res://assets/buildings/galeri.svg"),
	"pazar": preload("res://assets/buildings/pazar.svg"),
	"mobilya": preload("res://assets/buildings/mobilya.svg"),
	"petshop": preload("res://assets/buildings/petshop.svg"),
	"muhtarlik": preload("res://assets/buildings/muhtarlik.svg"),
	"karakol": preload("res://assets/buildings/karakol.svg"),
	"banka": preload("res://assets/buildings/banka.svg"),
	"carsi": preload("res://assets/buildings/carsi.svg"),
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
var _jail := false          # hapishanede miyim
var _g_action := {}         # G tuşunun şu anki eylemi (yankesicilik/soygun/tutuklama)
var npc: RefCounted         # şehir canlılığı (yürüyenler, arabalar, müşteriler, evcil hayvanlar)
var labels: Node2D          # yazılar ayrı katmanda: gece karartmasından etkilenmez
var _label_queue: Array = []


## İsimler/tabelalar/işaretler: dünya koordinatında ama CanvasModulate'in dışında çizilir.
class LabelDrawer extends Node2D:
	var items: Array = []
	var font: Font

	func _draw() -> void:
		for it in items:
			var align := HORIZONTAL_ALIGNMENT_CENTER if it[4] > 0 else HORIZONTAL_ALIGNMENT_LEFT
			if it[5]:
				draw_string_outline(font, it[0], it[1], align, it[4], it[2], 5, Color(0, 0, 0, 0.75))
			draw_string(font, it[0], it[1], align, it[4], it[2], it[3])


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
	ui_layer.layer = 3
	var ll := CanvasLayer.new()
	ll.layer = 1
	ll.follow_viewport_enabled = true
	add_child(ll)
	labels = LabelDrawer.new()
	labels.font = font
	labels.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ll.add_child(labels)
	var wl := CanvasLayer.new()
	wl.layer = 2
	add_child(wl)
	weather = WeatherOverlay.new()
	wl.add_child(weather)
	lighting = Lighting.new()
	add_child(lighting)
	for k in Homes.FURNITURE:
		furn_tex[k] = load("res://assets/furniture/%s.svg" % k)
	Homes.teleported.connect(_on_teleport)
	npc = NpcSim.new()
	Story.dialog.connect(_on_dialog)
	hud.pet_requested.connect(open_pet_panel)
	hud.clan_requested.connect(open_simple_panel.bind("res://scripts/ui/clan_panel.gd"))
	hud.events_requested.connect(open_simple_panel.bind("res://scripts/ui/event_panel.gd"))
	hud.family_requested.connect(open_simple_panel.bind("res://scripts/ui/family_panel.gd"))
	Family.proposal.connect(_on_proposal)
	Family.wedding.connect(func(_d): Sfx.play("success"))
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
	var outside := _room < 0 and not _jail
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
	npc.update(delta, Net.roster, shown, Net.my_id(), my_pos)
	_update_zone()
	queue_redraw()


func my_ride() -> String:
	return str(Net.roster.get(Net.my_id(), {}).get("ride", ""))


## Bulunduğum alan: ev içiysem oda, değilsem şehir.
func _clamp_to_area(p: Vector2) -> Vector2:
	if _jail:
		var j := Map.JAIL.grow(-18)
		return p.clamp(j.position, j.end)
	if _room >= 0:
		var lvl := int(Land.view[_room].level) if _room < Land.view.size() else 1
		var r := Map.interior_rect(_room, lvl).grow(-18)
		return p.clamp(r.position, r.end)
	return p.clamp(Map.WORLD.position + Vector2(20, 20), Map.WORLD.end - Vector2(20, 20))


func _can_stand(p: Vector2, ride: String) -> bool:
	if _room >= 0 or _jail:
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
	var jail := Map.JAIL.has_point(my_pos)
	if room == _room and jail == _jail:
		return
	_room = room
	_jail = jail
	var r := Map.WORLD
	if jail:
		r = Map.JAIL.grow(160)
	elif room >= 0:
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
		KEY_G:
			if panel == null and not _g_action.is_empty():
				_do_g_action()
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
	_g_action = {}
	if _jail:
		zone = {}
		hud.set_hint("" if panel != null else "Hapistesin — sol üstten kefalet ödeyebilirsin")
		return
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
	for k in Map.NPCS:
		if my_pos.distance_to(Map.NPCS[k].pos) < Map.NPC_TALK_RANGE:
			z = {"type": "npc", "npc": k, "label": "Konuş: %s" % Map.NPCS[k].name}
	if z.get("type", "") == "npc":
		zone = z
		hud.set_hint("" if panel != null else "[E]  %s" % z.label)
		return
	match Map.fishing_spot(my_pos):
		"lake":
			z = {"type": "fishing", "label": "Göl İskelesi — Balık Tut"}
		"sea":
			z = {"type": "fishing", "label": "Deniz İskelesi — Balık Tut"}
	for i in Map.PLOT_COUNT:
		if Map.plot_rect(i).has_point(my_pos):
			z = {"type": "realestate", "label": "Arsa #%d" % (i + 1), "plot": i}
	if my_pos.distance_to(Map.RACE_FLAG) < 80.0 or my_pos.distance_to(Map.RACE_START) < 60.0:
		z = {"type": "race", "label": "Yarış Pisti — tur başlat"}
	zone = z
	_g_action = _find_g_action()
	var hint := "" if z.is_empty() else "[E]  %s" % z.label
	if not _g_action.is_empty():
		hint += ("\n" if hint != "" else "") + "[G]  %s" % _g_action.label
	hud.set_hint("" if panel != null else hint)


## G tuşu: görevdeki polis için tutuklama; diğerleri için yankesicilik ya da soygun.
func _find_g_action() -> Dictionary:
	var me = Net.roster.get(Net.my_id())
	if me == null or int(me.get("level", 1)) < Police.CRIME_LEVEL:
		return {}
	var best_id := 0
	var best_d := 1e9
	for id in shown:
		var info = Net.roster.get(id)
		if info == null or not Map.WORLD.has_point(shown[id]):
			continue
		var d: float = shown[id].distance_to(my_pos)
		if Police.on_duty():
			if int(info.get("wanted", 0)) > 0 and d < Police.ARREST_RANGE and d < best_d:
				best_id = id
				best_d = d
		elif d < Police.PICK_RANGE and d < best_d and int(info.get("level", 1)) >= Police.CRIME_LEVEL and not info.get("police", false) \
				and str(info.get("spouse", "")) != Net.my_name:
			best_id = id
			best_d = d
	if best_id != 0:
		var nm: String = Net.roster[best_id].name
		if Police.on_duty():
			return {"kind": "arrest", "target": nm, "label": "Tutukla: %s %s" % [nm, "★".repeat(int(Net.roster[best_id].wanted))]}
		return {"kind": "pick", "target": nm, "label": "Cebini yokla: %s (suç!)" % nm}
	if Police.on_duty():
		return {}
	for i in Map.PLOT_COUNT:
		if i < Land.view.size() and Map.plot_rect(i).has_point(my_pos):
			var p: Dictionary = Land.view[i]
			if p.owner != "" and p.owner != Net.my_name and int(p.level) >= 1:
				var what := "tarlayı" if Farm.is_farm(p) else ("kasayı" if Biz.is_biz(p) else "evi")
				return {"kind": "rob", "plot": i, "label": "Soy: %s'in %s (suç!)" % [p.owner, what]}
	return {}


func _do_g_action() -> void:
	match _g_action.kind:
		"arrest":
			Police.arrest(_g_action.target)
		"pick":
			Police.pickpocket(_g_action.target)
		"rob":
			Police.rob(_g_action.plot)
	Sfx.play("open", -8.0, 1.4)


func _open_panel() -> void:
	if zone.is_empty():
		return
	if zone.type == "exit_home":
		Homes.exit_home()
		return
	if zone.type == "npc":
		Story.talk(zone.npc)
		return
	panel = PANELS[zone.type].new()
	if zone.type == "race":
		panel.at_track = true
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


## Sunucudan diyalog gelince konuşma penceresini aç.
func _on_dialog(d: Dictionary) -> void:
	if panel != null:
		_close_panel()
	panel = preload("res://scripts/ui/dialog_panel.gd").new()
	panel.data = d
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -6.0)


## HUD "Evcil" butonu: evcil hayvan penceresi (her yerden; satın alma Pet Shop'ta).
func open_pet_panel() -> void:
	if panel != null:
		return
	panel = PANELS["petshop"].new()
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)


## Gelen evlenme teklifi.
func _on_proposal(from_name: String) -> void:
	if panel != null:
		_close_panel()
	panel = preload("res://scripts/ui/proposal_panel.gd").new()
	panel.from_name = from_name
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("notify")


## HUD butonlarından açılan basit pencereler (Klan, Etkinlik, Aile).
func open_simple_panel(path: String) -> void:
	if panel != null:
		return
	panel = load(path).new()
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -4.0)


## HUD'da bir oyuncunun adına tıklanınca: para gönder ya da özel mesaj.
func open_transfer(to_name: String) -> void:
	if panel != null or to_name == Net.my_name:
		return
	panel = preload("res://scripts/ui/transfer_panel.gd").new()
	panel.to_name = to_name
	panel.pm_requested.connect(func(n):
		_close_panel()
		hud.start_pm(n))
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
	blocked.append(Rect2(0, Map.BEACH.position.y - 30, Map.WORLD.size.x, 1000))   # plaj/deniz ayrı yerleşir
	var decor_blocked := blocked.duplicate()   # çim/çiçek arsalara da serpilebilir
	blocked.append(Rect2(Map.PLOT_ORIGIN - Vector2(30, 30), Vector2(1190, 650)))
	for _k in 320:
		var p := Vector2(rng.randf_range(30, Map.WORLD.size.x - 30), rng.randf_range(40, 1590))
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
	for x in range(60, int(Map.WORLD.size.x), 170):
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
		var p := Vector2(rng.randf_range(10, Map.WORLD.size.x - 10), rng.randf_range(10, 1590))
		var ok := true
		for r in decor_blocked:
			if r.has_point(p):
				ok = false
				break
		if ok and not Map.in_water(p):
			decor.append([p, rng.randi_range(0, 9)])


func _draw() -> void:
	_label_queue = []
	var winter := Env.season == "winter"
	draw_rect(Map.WORLD, GRASS.get(Env.season, GRASS.spring))
	for d in decor:
		if winter and d[1] < 3:
			continue      # kışın çiçek yok
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
	_draw_race_track()
	_draw_beach()
	_draw_lake()
	_draw_interiors()
	_draw_jail()
	for lp in Map.lamp_positions():
		draw_rect(Rect2(lp.x - 2, lp.y - 34, 4, 34), Color("#374151"))
		draw_circle(lp + Vector2(0, -36), 6, Color("#fde68a") if Env.darkness() > 0.2 else Color("#e5e7eb"))
	for i in Map.PLOT_COUNT:
		_draw_plot(i)
	for b in Map.BUILDINGS:
		_draw_building(b)
	_draw_event_world()
	_draw_weddings()
	# Ağaçlar ve oyuncular y'ye göre sıralanarak çizilir (önde olan üstte görünür).
	var items: Array = []
	for n in nature:
		items.append([n[0].y, "n", n])
	for id in shown:
		var info = Net.roster.get(id)
		if info:
			var a: Dictionary = anim.get(id, {"facing": "down", "moving": false})
			items.append([shown[id].y, "p", [shown[id], info.get("appearance", {}), _name_of(info), false, a.facing, a.moving, str(info.get("ride", "")), info.get("color", Color.WHITE), info]])
	var mine = Net.roster.get(Net.my_id())
	var my_app = mine.get("appearance", {}) if mine else Net.my_appearance
	var my_level: int = int(mine.get("level", 1)) if mine else 1
	var my_col: Color = mine.get("color", Color.WHITE) if mine else Color.WHITE
	items.append([my_pos.y, "p", [my_pos, my_app, _name_of(mine) if mine else "%s · Sv.%d" % [Net.my_name, my_level], true, my_facing, my_moving, my_ride(), my_col, mine if mine else {}]])
	if _room < 0:
		for w in npc.visible_walkers():
			items.append([w.pos.y, "w", w])
		for c in npc.customers:
			items.append([c.pos.y, "w", c])
		for c in npc.cars:
			var lane: Array = Map.TRAFFIC_LANES[c.lane]
			items.append([lane[0], "c", [Vector2(c.x, lane[0]), "right" if float(lane[1]) > 0 else "left", c.color, c.get("police", false)]])
		for k in Map.NPCS:
			items.append([Map.NPCS[k].pos.y, "q", k])
	for id in npc.pets:
		var info = Net.roster.get(id)
		if info and info.get("pet") is Dictionary and not info.pet.is_empty():
			var st: Dictionary = npc.pets[id]
			items.append([st.pos.y, "pet", [st, info.pet]])
	if Events.treasure_pos != null and Events.current.get("kind", "") == "treasure":
		items.append([Events.treasure_pos.y, "t", Events.treasure_pos])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		if it[1] == "n":
			_draw_nature(it[2])
		elif it[1] == "w":
			var w: Dictionary = it[2]
			draw_set_transform(w.pos + Vector2(0, 10), 0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, 13, Color(0, 0, 0, 0.2))
			draw_set_transform(Vector2.ZERO)
			Avatar.draw(self, w.pos, w.app, w.get("facing", "down"), [1, 0, 2, 0][int(_t * 7.0 + w.pos.x * 0.01) % 4])
		elif it[1] == "c":
			_draw_vehicle(it[2][0], "car", it[2][1], it[2][2])
			if it[2][3]:
				_draw_siren(it[2][0])
		elif it[1] == "q":
			_draw_quest_npc(it[2])
		elif it[1] == "t":
			_draw_chest(it[2])
		elif it[1] == "pet":
			_draw_pet(it[2][0], it[2][1])
		else:
			var a: Array = it[2]
			_draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	_draw_placement_ghost()
	labels.items = _label_queue
	labels.queue_redraw()


func _text(pos: Vector2, text: String, size: int, color: Color, width: float = -1, outline: bool = true) -> void:
	_label_queue.append([pos, text, size, color, width, outline])


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
	for x in range(0, int(Map.WORLD.size.x), 70):
		draw_rect(Rect2(x, 442, 34, 6), line)
	for y in range(520, 1600, 70):
		draw_rect(Rect2(1002, y, 6, 34), line)
	for x in range(1070, int(Map.WORLD.size.x), 70):
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
	if Farm.is_farm(p) and p.get("farm") is Dictionary:
		_draw_farm(r, p)
		level = -1
	if Biz.is_biz(p) and level >= 1:
		var b: Dictionary = p.get("biz", {})
		var heights := [0, 116, 126, 146]
		_draw_tex_at(BIZ_TEX[level], Vector2(c.x, c.y + 54), heights[level])
		var open := int(b.get("stock", 0)) > 0
		_text(Vector2(r.position.x, r.position.y + 26), "%s  %s" % [Biz.NAMES[level], "★%.1f" % float(b.get("rating", 3.0))], 15,
			Color("#fde68a") if open else Color("#94a3b8"), r.size.x)
		if not open:
			_text(Vector2(r.position.x, c.y + 4), "KAPALI (malzeme yok)", 15, Color("#fca5a5"), r.size.x)
		level = -1
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
	var tint := Color.WHITE
	if n[1] <= 2:
		match Env.season:
			"autumn":
				tint = Color(1.0, 0.72, 0.42) if n[1] != 1 else Color(0.9, 0.95, 0.85)
			"winter":
				tint = Color(0.82, 0.86, 0.9)
	_draw_tex_at(prop[0], p, h, tint)
	if Env.season == "winter" and n[1] <= 1:
		draw_set_transform(p + Vector2(0, -h * 0.82), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, h * 0.22, Color(1, 1, 1, 0.9))     # karlı tepe
		draw_set_transform(Vector2.ZERO)


func _draw_beach() -> void:
	var b := Map.BEACH
	draw_rect(Rect2(b.position.x, b.position.y - 10, b.size.x, 14), Color("#c9b57e"))   # çimden kuma geçiş
	draw_rect(Rect2(b.position, Vector2(b.size.x, b.size.y + 40)), Color("#f0dba5"))
	for i in 160:
		var x := float((i * 397) % int(Map.WORLD.size.x))
		var y := b.position.y + 10 + float((i * 211) % int(b.size.y - 20))
		draw_circle(Vector2(x, y), 1.6, Color("#d8c08a"))
	# deniz
	var sea := Map.SEA
	draw_rect(Rect2(sea.position.x, sea.position.y - 10, sea.size.x, sea.size.y + 10), Color("#1f78b8"))
	var shallow := PackedVector2Array()
	var foam := PackedVector2Array()
	var n := int(Map.WORLD.size.x / 40.0)
	for i in n + 1:
		var x := i * 40.0
		var y := sea.position.y + sin(x / 60.0) * 6.0 + sin(x / 90.0 + _t * 1.3) * 5.0
		foam.append(Vector2(x, y))
		shallow.append(Vector2(x, y))
	for i in range(n, -1, -1):
		shallow.append(Vector2(i * 40.0, sea.position.y + 70 + sin(i * 0.7 + _t * 0.8) * 8.0))
	draw_colored_polygon(shallow, Color("#4fb0dd"))
	draw_polyline(foam, Color(1, 1, 1, 0.85), 5)
	for i in 30:
		var sp := Vector2(float((i * 571) % int(Map.WORLD.size.x)), sea.position.y + 100 + float((i * 137) % 320))
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
		if lvl < 1 or str(p.get("kind", "home")) != "home":
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


## Tarla: çit, korkuluk ve 6 tarh (ekinler büyüme durumuna göre).
func _draw_farm(r: Rect2, p: Dictionary) -> void:
	draw_rect(r.grow(-6), Color("#a47148"))
	var now := Land.server_now()
	var bw := 70.0
	var bh := 52.0
	var x0 := r.position.x + (r.size.x - 3 * bw - 2 * 12.0) / 2.0
	for k in Farm.BEDS:
		var b: Dictionary = p.farm.beds[k]
		var br := Rect2(x0 + (k % 3) * (bw + 12.0), r.position.y + 42 + int(k / 3.0) * (bh + 10.0), bw, bh)
		var st: Array = Farm.bed_state(b, now)
		draw_rect(br, Color("#5b3a1e") if b.get("w", false) else Color("#7c4f2a"))
		for fy in range(int(br.position.y) + 9, int(br.end.y), 13):
			draw_line(Vector2(br.position.x + 3, fy), Vector2(br.end.x - 3, fy), Color(0, 0, 0, 0.18), 2)
		if st[0] == "empty":
			continue
		var crop: Dictionary = Farm.CROPS.get(str(b.c), {})
		var fruit := Color(crop.get("color", "#22c55e"))
		for j in 6:
			var c := br.position + Vector2(12 + (j % 3) * 23, 14 + int(j / 3.0) * 24)
			match st[0]:
				"growing":
					var g: float = st[1]
					if g < 0.35:
						draw_circle(c, 2.5, Color("#86efac"))
						draw_line(c, c + Vector2(-3, -4), Color("#4ade80"), 2)
					else:
						var leaf := Color("#65a30d") if not b.get("dmg", false) else Color("#a16207")
						draw_circle(c, 4.0 + 5.0 * g, leaf)
						draw_circle(c + Vector2(-3, -2), 2.5 + 3.0 * g, leaf.lightened(0.2))
				"ready":
					if b.c == "bugday":
						for dx in [-5, 0, 5]:
							draw_line(c + Vector2(dx, 6), c + Vector2(dx, -9), Color("#ca8a04"), 2)
							draw_circle(c + Vector2(dx, -10), 2.5, fruit)
					else:
						draw_circle(c, 9.0, Color("#4d7c0f"))
						var fr := 6.0 if b.c in ["kabak", "karpuz"] else 3.0
						draw_circle(c + Vector2(2, 2), fr, fruit)
						if fr < 5.0:
							draw_circle(c + Vector2(-4, -1), fr, fruit)
				"rotten":
					draw_circle(c, 6.0, Color("#57534e"))
		if st[0] == "ready":
			var bob := sin(_t * 3.0 + k) * 2.0
			draw_circle(br.position + Vector2(bw - 8, 6 + bob), 5, Color("#facc15"))
	# çit
	var fence := Color("#78350f")
	draw_rect(r.grow(-4), fence, false, 3)
	for x in range(int(r.position.x) + 4, int(r.end.x), 26):
		draw_rect(Rect2(x - 2, r.position.y, 4, 10), fence)
		draw_rect(Rect2(x - 2, r.end.y - 10, 4, 10), fence)
	# korkuluk
	var sc := r.position + Vector2(r.size.x - 70, 22)
	draw_line(sc + Vector2(0, -8), sc + Vector2(0, 18), Color("#5b3a1e"), 3)
	draw_line(sc + Vector2(-12, 0), sc + Vector2(12, 0), Color("#5b3a1e"), 3)
	draw_circle(sc + Vector2(0, -10), 5, Color("#fde68a"))
	draw_rect(Rect2(sc.x - 7, sc.y - 18, 14, 4), Color("#92400e"))


## Yarış pisti: damalı başlangıç çizgisi, hakem bayrağı; yarıştayken sıradaki kontrol noktası.
func _draw_race_track() -> void:
	var st := Map.RACE_START
	for row in 11:
		for col in 2:
			var c := Color.WHITE if (row + col) % 2 == 0 else Color("#111827")
			draw_rect(Rect2(st.x - 10 + col * 10, 390 + row * 10, 10, 10), c)
	var f := Map.RACE_FLAG
	draw_rect(Rect2(f.x - 2, f.y - 50, 4, 52), Color("#374151"))
	for row in 3:
		for col in 4:
			draw_rect(Rect2(f.x + 2 + col * 7, f.y - 50 + row * 7, 7, 7), Color.WHITE if (row + col) % 2 == 0 else Color("#111827"))
	_text(f + Vector2(-80, -58), "YARIŞ PİSTİ", 15, Color("#fde68a"), 160)
	var r := Events.race
	var racing := str(r.get("state", "")) in ["countdown", "running"]
	for k in Map.RACE_CPS.size() - 1:
		var cp: Vector2 = Map.RACE_CPS[k]
		var active := racing and int(r.get("next", 0)) == k
		var a := 0.35 + 0.25 * sin(_t * 5.0) if active else 0.15
		draw_arc(cp, Map.RACE_CP_RADIUS * (0.9 if active else 0.5), 0, TAU, 48, Color(1, 0.8, 0.1, a), 6 if active else 3)
		draw_circle(cp + Vector2(-26, 0), 6, Color("#f97316"))
		draw_circle(cp + Vector2(26, 0), 6, Color("#f97316"))
		if active:
			_text(cp + Vector2(-80, -Map.RACE_CP_RADIUS - 6), "KONTROL %d" % (k + 1), 18, Color("#facc15"), 160)
	if racing:
		var nxt: Vector2 = Map.RACE_CPS[int(r.get("next", 0))]
		if int(r.get("next", 0)) == Map.RACE_CPS.size() - 1:
			_text(nxt + Vector2(-80, -70), "BİTİŞ", 22, Color("#facc15"), 160)
		var dir := (nxt - my_pos)
		if dir.length() > 160.0:
			var tip := my_pos + dir.normalized() * 70.0
			var side := dir.normalized().orthogonal() * 12.0
			draw_colored_polygon(PackedVector2Array([tip + dir.normalized() * 20.0, tip + side, tip - side]), Color(1, 0.8, 0.1, 0.9))


## Etkinliklere göre dünya süsleri: hazine arama alanı ve sandık, festival bayrakları ve konfeti.
func _draw_event_world() -> void:
	var cur := Events.current
	if cur.get("kind", "") == "treasure" and cur.has("area"):
		var c: Vector2 = cur.area
		var rad := float(cur.get("area_r", 300.0))
		draw_circle(c, rad, Color(1, 0.85, 0.2, 0.10))
		draw_arc(c, rad, 0, TAU, 64, Color(1, 0.85, 0.2, 0.6), 4)
		_text(c + Vector2(-100, -rad - 8), "HAZİNE BURADA BİR YERDE", 16, Color("#fde68a"), 200)
	if cur.get("kind", "") == "festival":
		var cols := [Color("#ef4444"), Color("#facc15"), Color("#22c55e"), Color("#3b82f6"), Color("#a855f7")]
		var lamps := Map.lamp_positions()
		for k in lamps.size() - 1:
			var a: Vector2 = lamps[k] + Vector2(0, -34)
			var b: Vector2 = lamps[k + 1] + Vector2(0, -34)
			if a.distance_to(b) > 300.0:
				continue
			for j in 8:
				var q := a.lerp(b, (j + 0.5) / 8.0) + Vector2(0, sin((j + 0.5) / 8.0 * PI) * 14.0)
				draw_colored_polygon(PackedVector2Array([q + Vector2(-6, 0), q + Vector2(6, 0), q + Vector2(0, 12)]), cols[(j + k) % cols.size()])
			draw_line(a, b, Color(0, 0, 0, 0.4), 1)
		for k in 60:
			var px := Map.SPAWN.x + fmod(k * 97.0, 700.0) - 350.0
			var py := Map.SPAWN.y - 120.0 + fmod(k * 53.0 + _t * (40.0 + k % 7 * 10.0), 260.0)
			draw_rect(Rect2(px + sin(_t * 3.0 + k) * 8.0, py, 5, 3), cols[k % cols.size()])


## Hapishane koğuşu (harita dışında).
func _draw_jail() -> void:
	var j := Map.JAIL
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200).intersects(j):
		return
	draw_rect(j.grow(28), Color("#1f2937"))
	draw_rect(j, Color("#6b7280"))
	for x in range(int(j.position.x), int(j.end.x), 48):
		draw_line(Vector2(x, j.position.y), Vector2(x, j.end.y), Color("#4b5563"), 1)
	for y in range(int(j.position.y), int(j.end.y), 48):
		draw_line(Vector2(j.position.x, y), Vector2(j.end.x, y), Color("#4b5563"), 1)
	for x in range(int(j.position.x) + 10, int(j.end.x), 22):
		draw_rect(Rect2(x, j.position.y - 28, 6, 36), Color("#9ca3af"))      # parmaklıklar
	for k in 4:
		draw_rect(Rect2(j.position.x + 60 + k * 200, j.end.y - 70, 120, 34), Color("#78350f"))   # sıralar
	draw_rect(Rect2(j.end.x - 70, j.position.y + 30, 40, 40), Color("#e5e7eb"))
	_text(Vector2(j.position.x, j.position.y - 36), "HAPİSHANE — süren dolunca serbest kalırsın", 18, Color("#fca5a5"), j.size.x)


## Hazine sandığı (ağaçlarla birlikte y'ye göre sıralanarak çizilir).
func _draw_chest(tp: Vector2) -> void:
	draw_set_transform(tp + Vector2(0, 8), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(tp.x - 20, tp.y - 18, 40, 26), Color("#92400e"))
	draw_rect(Rect2(tp.x - 20, tp.y - 26, 40, 10), Color("#b45309"))
	draw_rect(Rect2(tp.x - 20, tp.y - 26, 40, 34), Color("#451a03"), false, 2)
	draw_rect(Rect2(tp.x - 4, tp.y - 18, 8, 8), Color("#facc15"))
	for k in 6:
		var a := _t * 2.0 + k * TAU / 6.0
		draw_circle(tp + Vector2(cos(a), sin(a) * 0.6) * 32.0 + Vector2(0, -10), 3.0, Color(1, 0.95, 0.4, 0.6 + 0.4 * sin(_t * 6 + k)))
	_text(tp + Vector2(-60, -36), "HAZİNE!", 16, Color("#facc15"), 120)


## Düğün kutlaması: kalpler ve konfeti (25 sn).
func _draw_weddings() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	Family.weddings = Family.weddings.filter(func(w): return float(w.until) > now)
	for w in Family.weddings:
		var c: Vector2 = w.pos
		var k := float(w.until) - now
		for j in 14:
			var a := TAU * j / 14.0 + _t * 0.6
			var r := 60.0 + 20.0 * sin(_t * 2.0 + j)
			var hp := c + Vector2(cos(a), sin(a) * 0.6) * r + Vector2(0, -40)
			_draw_heart(hp, 7.0, Color(1.0, 0.45 + 0.1 * (j % 3), 0.7, minf(1.0, k / 3.0)))
		for j in 40:
			var px := c.x + fmod(j * 37.0, 240.0) - 120.0
			var py := c.y - 140.0 + fmod(j * 23.0 + _t * (50.0 + j % 5 * 12.0), 200.0)
			draw_rect(Rect2(px + sin(_t * 3.0 + j) * 6.0, py, 4, 3), [Color("#f9a8d4"), Color("#ffffff"), Color("#fde68a")][j % 3])
		_text(c + Vector2(-140, -120), "%s ♥ %s" % [w.a, w.b], 20, Color("#f9a8d4"), 280)


func _draw_heart(p: Vector2, s: float, col: Color) -> void:
	draw_circle(p + Vector2(-s * 0.5, 0), s * 0.55, col)
	draw_circle(p + Vector2(s * 0.5, 0), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 1.02, s * 0.15), p + Vector2(s * 1.02, s * 0.15), p + Vector2(0, s * 1.3)]), col)


func _draw_siren(p: Vector2) -> void:
	var on := int(_t * 4.0) % 2 == 0
	draw_circle(p + Vector2(-6, 0), 5, Color("#ef4444") if on else Color("#7f1d1d"))
	draw_circle(p + Vector2(6, 0), 5, Color("#3b82f6") if not on else Color("#1e3a8a"))


func _draw_quest_npc(k: String) -> void:
	var n: Dictionary = Map.NPCS[k]
	var p: Vector2 = n.pos
	draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var facing := "down"
	if my_pos.distance_to(p) < 160:
		facing = _facing_of(my_pos - p)
	Avatar.draw(self, p, n.app, facing, 0)
	_text(p + Vector2(-100, -56), n.name, 15, Color("#fde68a"), 200)
	var m := Story.marker(k)
	if m != "":
		var bob := sin(_t * 4.0) * 4.0
		_text(p + Vector2(-20, -74 + bob), m, 30, Color("#facc15") if m == "!" else Color("#4ade80"), 40)


func _draw_pet(st: Dictionary, pet: Dictionary) -> void:
	var tex: Texture2D = PET_TEX.get(pet.kind)
	if tex == null:
		return
	var p: Vector2 = st.pos
	var flying: bool = pet.kind == "parrot"
	var frame := int(_t * (10.0 if flying else 8.0)) % 2 if (st.moving or flying) else 0
	if not flying:
		draw_set_transform(p + Vector2(0, 4), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.2))
	var lift := -26.0 + sin(_t * 3.0) * 3.0 if flying else 0.0
	draw_set_transform(p + Vector2(0, lift), 0, Vector2(-1 if st.facing == "left" else 1, 1))
	var mod := Color.WHITE if pet.get("happy", true) else Color(0.7, 0.7, 0.75)
	draw_texture_rect_region(tex, Rect2(-20, -28, 40, 32), Rect2(frame * 80, 0, 80, 64), mod)
	draw_set_transform(Vector2.ZERO)
	_text(p + Vector2(-60, -30 + lift), pet.name, 12, Color("#e0f2fe") if pet.get("happy", true) else Color("#94a3b8"), 120)


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


## İsim etiketi: [KLAN] Ad · Sv.N
func _name_of(info: Dictionary) -> String:
	var t := "%s · Sv.%d" % [info.get("name", ""), int(info.get("level", 1))]
	if str(info.get("clan", "")) != "":
		t = "[%s] %s" % [info.clan, t]
	return t


## İsim + üstünde rozetler (aranma yıldızları, polis).
func _name(p: Vector2, y: float, pname: String, col: Color, extra: Dictionary) -> void:
	_text(p + Vector2(-90, y), pname, 16, col, 180)
	var badge := ""
	var bcol := Color("#f87171")
	if bool(extra.get("mayor", false)):
		badge = "BAŞKAN"
		bcol = Color("#facc15")
	elif bool(extra.get("police", false)):
		badge = "POLİS"
		bcol = Color("#60a5fa")
	elif int(extra.get("wanted", 0)) > 0:
		badge = "★".repeat(int(extra.wanted))
	if badge != "":
		_text(p + Vector2(-90, y - 18), badge, 15, bcol, 180)


func _draw_player(p: Vector2, app: Dictionary, pname: String, me: bool, facing: String, moving: bool,
		ride: String = "", col: Color = Color.WHITE, extra: Dictionary = {}) -> void:
	var name_col := Color("#fde68a") if me else Color.WHITE
	match ride:
		"car":
			_draw_vehicle(p, ride, facing, col)
			_name(p, -40, pname, name_col, extra)
			return
		"bike":
			_draw_vehicle(p, ride, facing, col)
			Avatar.draw(self, p, app, facing, 0)
			_name(p, -56, pname, name_col, extra)
			return
		"boat":
			_draw_vehicle(p, ride, facing, col)
			Avatar.draw(self, p + Vector2(0, -6), app, facing, 0, 1.0, true)
			_name(p, -44, pname, name_col, extra)
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
	_name(p, -56 + (22 if swim else 0), pname, name_col, extra)
