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
	"futbol": preload("res://scripts/ui/football_panel.gd"),
	"langirt": preload("res://scripts/ui/langirt_panel.gd"),
	"fishing": preload("res://scripts/ui/fish_panel.gd"),
	"fabrika": preload("res://scripts/ui/factory_panel.gd"),
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
	"fabrika": preload("res://assets/buildings/fabrika.svg"),
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
var _blockers: Array = []   # çarpışma kutuları: binalar ve arsalardaki yapılar (Rect2)
var _fish_t := {}           # oyuncu adı -> [olta durumu, başladığı an] (animasyon için)
var nav_target = null       # haritadan seçilen hedef (Vector2) ya da null
var _snowballs: Array = []  # uçan kartopları (istemcide çizim): {from, dir, t0}
var _splats: Array = []     # isabet izleri: {pos, t0}
var minimap: Control
var _walked := 0.0
var _fish_state := "idle"   # olta: idle, waiting, bite
var _fish_since := 0.0
var _spray_acc := 0.0
var _step_acc := 0.0
const INDOOR_PANELS := ["casino", "poker", "market", "hospital", "banka", "carsi", "fabrika", "karakol", "mobilya", "galeri", "pazar", "petshop", "muhtarlik", "realestate"]
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
	camera.zoom = Vector2.ONE * Settings.world_zoom()
	Settings.changed.connect(_on_settings)
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
	Land.plots_changed.connect(_rebuild_blockers)
	_rebuild_blockers()
	npc = NpcSim.new()
	Story.dialog.connect(_on_dialog)
	hud.pet_requested.connect(open_pet_panel)
	hud.clan_requested.connect(open_simple_panel.bind("res://scripts/ui/clan_panel.gd"))
	hud.events_requested.connect(open_simple_panel.bind("res://scripts/ui/event_panel.gd"))
	hud.family_requested.connect(open_simple_panel.bind("res://scripts/ui/family_panel.gd"))
	Family.proposal.connect(_on_proposal)
	hud.achievements_requested.connect(open_simple_panel.bind("res://scripts/ui/ach_panel.gd"))
	hud.map_requested.connect(open_map)
	hud.settings_requested.connect(open_settings)
	hud.league_requested.connect(open_simple_panel.bind("res://scripts/ui/league_panel.gd"))
	Tutorial.start(ui_layer)
	Work.job_changed.connect(_on_job_changed)
	Jobs.fish_event.connect(_on_fish_event)
	Jobs.job_result.connect(func(d): if d.get("ok", false): Tutorial.note("job"))
	Story.dialog.connect(func(_d): Tutorial.note("talk"))
	minimap = preload("res://scripts/ui/minimap.gd").new()
	minimap.world = self
	hud.set_minimap(minimap)
	Seasonal.snowball.connect(func(d): _snowballs.append({"from": d.from, "dir": d.dir, "t0": _t}))
	Seasonal.hit.connect(func(d):
		_splats.append({"pos": d.pos, "t0": _t})
		Sfx.play("splash_small", -6.0, 1.4))
	Family.wedding.connect(func(_d): Sfx.play("success"))
	_make_nature()


func _process(delta: float) -> void:
	_t += delta
	my_moving = false
	if panel == null and not hud.is_typing():
		var dir := Vector2.ZERO
		if Settings.held("up"):
			dir.y -= 1
		if Settings.held("down"):
			dir.y += 1
		if Settings.held("left"):
			dir.x -= 1
		if Settings.held("right"):
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
	_push_from_bus()
	if _fish_state != "idle" and _t - _fish_since > 15.0:
		_fish_state = "idle"        # sunucudan haber gelmedi (ör. olta iptal): takılı kalma
	if panel == null and zone.get("type", "") == "fire" and Settings.held("interact"):
		_spray_acc += delta
		if _spray_acc >= 0.25:
			_spray_acc = 0.0
			Work.spray(int(zone.id))
	Net.update_my_pos(my_pos, delta)
	if my_moving:
		_walked += delta
		if _walked > 1.2:
			Tutorial.note("move")
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
	_update_sound(delta, outside)
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
	if _blocked(p) and not _blocked(my_pos):
		return false              # bina, ev ya da araba (içindeysen çıkabilirsin)
	if Map.in_water(p):
		return false              # göl
	if ride == "boat":
		return Map.in_sea(p)      # tekne karaya çıkamaz
	if ride == "" and Map.in_deep(p) and not Map.in_deep(my_pos):
		return false              # açık denize yüzülmez, tekne gerekir
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
		if Garage.has_boat():
			Garage.ride("boat")
			Sfx.play("splash_small")
		else:
			hud.show_toast("Teknen yok. Galeri'den al ya da deniz iskelesinde kirala.", false)
		return
	# kıyıdan ya da iskeleden: yakındaki suya tekneyi indir ve bin
	if Garage.has_boat():
		var spot = _water_near(my_pos)
		if spot != null:
			my_pos = spot
			Garage.ride("boat", spot)
			Sfx.play("splash_small")
			return
	for k in ["car", "bike"]:
		if Garage.owned.has(k):
			Garage.ride(k)
			Sfx.play("bell" if k == "bike" else "door")
			return
	hud.show_toast("Aracın yok. Galeri'den bisiklet ya da araba alabilirsin.", false)


## Kıyıya/iskeleye yakın bir deniz noktası (tekneye binmek için).
func _water_near(p: Vector2) -> Variant:
	for dist in [50.0, 90.0, 130.0]:
		for d in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			var q: Vector2 = p + d * dist
			if Map.in_sea(q):
				return q
	return null


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
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.6, 0.6) / Settings.ui_scale, Vector2(2, 2) / Settings.ui_scale)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.6, 0.6) / Settings.ui_scale, Vector2(2, 2) / Settings.ui_scale)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: InputEventKey = event
	if k.physical_keycode == KEY_ESCAPE:
		if panel != null:
			_close_panel()
			get_viewport().set_input_as_handled()
		elif placing != "":
			placing = ""
			get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER:
		if panel == null:
			hud.focus_chat()
			get_viewport().set_input_as_handled()
		return
	if panel != null:
		return
	# tuşlar Ayarlar'dan değiştirilebilir (Settings.keys)
	var handled := true
	if Settings.is_key(k, "interact"):
		_open_panel()
	elif Settings.is_key(k, "profile"):
		open_profile()
	elif Settings.is_key(k, "vehicle"):
		_toggle_vehicle()
	elif Settings.is_key(k, "map"):
		open_map()
	elif Settings.is_key(k, "throw") and Env.season == "winter" and _room < 0 and not _jail:
		var aim := get_global_mouse_position() - my_pos
		if aim.length() < 10.0:
			aim = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}.get(my_facing, Vector2.DOWN)
		Seasonal.throw(aim)
	elif Settings.is_key(k, "action") and not _g_action.is_empty():
		_do_g_action()
	else:
		handled = false
	if handled:
		Tutorial.note("key")
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
		hud.set_hint("" if panel != null or placing != "" else "[%s]  %s" % [Settings.key_name("interact"), z.label])
		return
	# görevdeki itfaiyeci için yangın her şeyden önce gelir
	if Work.on_duty_fire():
		for f in Work.fires:
			if my_pos.distance_to(Vector2(float(f.x), float(f.y))) < 100.0:
				zone = {"type": "fire", "label": "YANGIN — %s basılı tut, söndür!" % Settings.key_name("interact"), "id": int(f.id)}
				hud.set_hint("" if panel != null else "[%s]  %s" % [Settings.key_name("interact"), zone.label])
				return
	for b in Map.BUILDINGS:
		if b.rect.grow(26).has_point(my_pos):
			z = {"type": b.type, "label": b.label}
	for k in Map.NPCS:
		if my_pos.distance_to(Map.NPCS[k].pos) < Map.NPC_TALK_RANGE:
			z = {"type": "npc", "npc": k, "label": "Konuş: %s" % Map.NPCS[k].name}
	if z.get("type", "") == "npc":
		zone = z
		hud.set_hint("" if panel != null else "[%s]  %s" % [Settings.key_name("interact"), z.label])
		return
	var spot := Map.fishing_spot(my_pos)
	if spot == "" and my_ride() == "boat" and Map.in_sea(my_pos):
		spot = "boat"
	if spot != "":
		var where: String = {"lake": "Göl", "sea": "Deniz İskelesi", "island": "Martı Adası", "boat": "Tekne"}.get(spot, "")
		z = {"type": "fishing", "label": "%s — Balık Tut" % where, "spot": spot}
	for i in Map.PLOT_COUNT:
		if Map.plot_rect(i).has_point(my_pos):
			z = {"type": "realestate", "label": "Arsa #%d" % (i + 1), "plot": i}
	var fstop := Work.ferry_stop_near(my_pos)
	if fstop != "":
		z = {"type": "ferry", "label": "Feribot iskelesi — %s" % Map.FERRY_STOPS[fstop][0], "stop": fstop}
	var stop := Work.stop_near(my_pos)
	if stop != "":
		z = {"type": "bus", "label": "Otobüs durağı — %s" % Map.BUS_STOPS[stop][0], "stop": stop}
	if my_pos.distance_to(Map.TAXI_STAND) < 90.0:
		z = {"type": "taxi", "label": "Taksi durağı — iş al (arabayla)" if Work.job.get("kind", "") != "taxi" else "Taksi mesaisini bitir"}
	if my_pos.distance_to(Map.CARGO_DEPOT) < 90.0:
		z = {"type": "cargo", "label": "Kargo deposu — 3 paket al"}
	if Map.FIRE_STATION.grow(50).has_point(my_pos):
		z = {"type": "firestation", "label": "İtfaiye — %s" % ("görevi bırak" if Work.on_duty_fire() else "göreve başla")}
	if my_pos.distance_to(Map.RECYCLE) < 90.0:
		z = {"type": "recycle", "label": "Geri dönüşüm (%d torba elinde)" % Work.carrying}
	if my_pos.distance_to(Map.CHAMPIONS_WALL) < 70.0:
		z = {"type": "league", "label": "Şampiyonlar Duvarı — lig sıralamaları"}
	if my_pos.distance_to(Map.FOUNTAIN) < Map.FOUNTAIN_R + 50.0:
		z = {"type": "wish", "label": "Çeşmeye bozuk para at, dilek tut (1 TL)"}
	if Football.FIELD.grow(70).has_point(my_pos) and not Football.FIELD.grow(-30).has_point(my_pos):
		z = {"type": "futbol", "label": "Plaj Sahası — takım seç"}
	if my_pos.distance_to(Langirt.POS) < 75.0:
		z = {"type": "langirt", "label": "Langırt Masası"}
	if Seasonal.icecream_open() and my_pos.distance_to(Seasonal.ICECREAM_POS) < 80.0:
		z = {"type": "dondurma", "label": "Dondurma al (%s, +%d enerji)" % [U.money(Seasonal.ICECREAM_PRICE), Seasonal.ICECREAM_ENERGY]}
	if z.is_empty() and Env.season == "winter" and Seasonal.can_build_at(my_pos):
		z = {"type": "snowman", "label": "Kardan adam yap (⚡%d)   ·   T: kartopu at" % Seasonal.SNOWMAN_ENERGY}
	if z.is_empty():      # çöp torbası en düşük öncelik (bina kapılarını, kardan adamı kapatmasın)
		for t in Work.trash:
			if my_pos.distance_to(Vector2(float(t.x), float(t.y))) < 60.0:
				z = {"type": "trash", "label": "Çöp torbasını topla", "id": int(t.id)}
				break
	if my_pos.distance_to(Map.BOAT_RENT_SPOT) < 70.0:
		z = {"type": "boatrent", "label": "Tekne kirala (%s / %d dk) — F: bin" % [U.money(Garage.RENT_PRICE), int(Garage.RENT_SECONDS / 60.0)]}
	if my_pos.distance_to(Map.RACE_FLAG) < 80.0 or my_pos.distance_to(Map.RACE_START) < 60.0:
		z = {"type": "race", "label": "Yarış Pisti — tur başlat"}
	zone = z
	_g_action = _find_g_action()
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	if not _g_action.is_empty():
		hint += ("\n" if hint != "" else "") + "[%s]  %s" % [Settings.key_name("action"), _g_action.label]
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
	if zone.type == "boatrent":
		Garage.rent_boat()
		return
	match str(zone.type):
		"league":
			open_simple_panel("res://scripts/ui/league_panel.gd")
			return
		"ferry":
			if panel == null:
				panel = preload("res://scripts/ui/ferry_panel.gd").new()
				panel.here = zone.stop
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
			return
		"bus":
			if panel == null:
				panel = preload("res://scripts/ui/bus_panel.gd").new()
				panel.here = zone.stop
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
			return
		"taxi":
			if Work.job.get("kind", "") == "taxi":
				Work.quit_job()
			else:
				Work.taxi_start()
			return
		"cargo":
			Work.cargo_start()
			return
		"firestation":
			Work.fire_duty(not Work.on_duty_fire())
			return
		"recycle":
			Work.recycle()
			return
		"wish":
			Work.wish()
			Sfx.play("splash_small", -6.0, 1.5)
			return
		"trash":
			Work.pick_trash(zone.id)
			Sfx.play("place", -6.0)
			return
		"fire":
			Work.spray(zone.id)
			return
	if zone.type == "dondurma":
		Seasonal.buy_icecream()
		return
	if zone.type == "snowman":
		Seasonal.build_snowman(my_pos)
		return
	Tutorial.note("panel")
	panel = PANELS[zone.type].new()
	if zone.type == "race":
		panel.at_track = true
	if zone.has("plot"):
		panel.focus_plot = zone.plot
	if zone.type == "fishing":
		panel.spot = str(zone.get("spot", "lake"))
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


# ================================================================== çarpışma

## Yapının görseli için yükseklik ve ayak noktası (çizimle aynı değerler).
func _structure_of(i: int, p: Dictionary) -> Array:
	var c := Map.plot_rect(i).get_center()
	var level := int(p.get("level", 0))
	if level < 1 or str(p.get("owner", "")) == "" or Farm.is_farm(p):
		return []
	if Biz.is_biz(p):
		return [BIZ_TEX[level], Vector2(c.x, c.y + 54), [0, 116, 126, 146][level]]
	return [PLOT_TEX[level], Vector2(c.x, c.y + [0, 42, 50, 60][level]), [0, 120, 130, 158][level]]


func _rebuild_blockers() -> void:
	_blockers = []
	for b in Map.BUILDINGS:
		var r: Rect2 = b.rect
		# kapının önünde (alt kenar) durulabilsin diye alt 10 px serbest
		_blockers.append(Rect2(r.position.x + 6, r.position.y + 16, r.size.x - 12, r.size.y - 26))
	_blockers.append(Rect2(Map.FOUNTAIN - Vector2(Map.FOUNTAIN_R, Map.FOUNTAIN_R * 0.6), Vector2(Map.FOUNTAIN_R * 2, Map.FOUNTAIN_R * 1.2)))
	_blockers.append(Rect2(Map.CLOCK_TOWER + Vector2(-22, -36), Vector2(44, 40)))
	for row in 3:
		_blockers.append(Rect2(Map.CONTAINER_YARD.position.x, Map.CONTAINER_YARD.position.y + row * 100 + 30, 8 * 145 - 15, 50))
	for cr in Map.CRANES:
		_blockers.append(Rect2(cr.x - 40, cr.y - 10, 80, 16))
	var fs: Rect2 = Map.FIRE_STATION
	_blockers.append(Rect2(fs.position.x + 4, fs.position.y + 20, fs.size.x - 8, fs.size.y - 34))
	for i in mini(Land.view.size(), Map.PLOT_COUNT):
		var s := _structure_of(i, Land.view[i])
		if s.is_empty():
			continue
		var tex: Texture2D = s[0]
		var foot: Vector2 = s[1]
		var h: float = s[2]
		var w := tex.get_size().x / tex.get_size().y * h
		_blockers.append(Rect2(foot.x - w * 0.42, foot.y - h * 0.42, w * 0.84, h * 0.42 - 4))


## Nokta bir binanın, evin ya da NPC arabanın içinde mi?
func _blocked(p: Vector2) -> bool:
	for r in _blockers:
		if r.has_point(p):
			return true
	for c in npc.cars:
		var lane: Array = Map.TRAFFIC_LANES[c.lane]
		if Rect2(float(c.x) - 46, float(lane[0]) - 24, 92, 48).has_point(p):
			return true
	return _in_bus(p) != 0.0


## Otobüsün içinde mi? (0 değilse: otobüsün hangi yanında, ±1)
func _in_bus(p: Vector2) -> float:
	var bus := Map.bus_at(Land.server_now())
	var dir: Vector2 = bus[1]
	var local := (p - Vector2(bus[0])).rotated(-dir.angle())
	if absf(local.x) < 76.0 and absf(local.y) < 30.0:
		return 1.0 if local.y >= 0.0 else -1.0
	return 0.0


## Otobüs üstüne gelirse oyuncuyu kenara iter (otobüs herkeste aynı saatle ilerler, duramaz).
func _push_from_bus() -> void:
	var side := _in_bus(my_pos)
	if side == 0.0 or _room >= 0 or _jail:
		return
	var bus := Map.bus_at(Land.server_now())
	var normal: Vector2 = Vector2(bus[1]).orthogonal() * side
	for k in range(1, 12):
		var np := my_pos + normal * 6.0 * k
		if _in_bus(np) == 0.0:
			my_pos = np
			return


# ================================================================== olta

func _is_water(p: Vector2) -> bool:
	return Map.in_water(p) or Map.in_sea(p)


## Şamandıranın düşeceği yer: önce baktığın yön, sonra diğer yönlerde ilk su.
func _bobber_pos(p: Vector2, facing: String) -> Variant:
	var dirs := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
	var order: Array = [dirs.get(facing, Vector2.DOWN), Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT, Vector2.UP]
	for d in order:
		for dist in [110.0, 80.0, 150.0]:
			var tp: Vector2 = p + d * dist
			if _is_water(tp):
				return tp
	return null


func _draw_rod(p: Vector2, facing: String, info: Dictionary) -> void:
	var st := str(info.get("fishing", ""))
	var key := str(info.get("name", ""))
	if st == "":
		_fish_t.erase(key)
		return
	var prev: Array = _fish_t.get(key, ["", 0.0])
	if prev[0] != st:
		_fish_t[key] = [st, _t]
		prev = _fish_t[key]
	var k := _t - float(prev[1])
	var bp = _bobber_pos(p, facing)
	if bp == null:
		return
	var tp: Vector2 = bp
	var dir := (tp - p).normalized()
	var side := 1.0 if dir.x >= 0.0 else -1.0
	var hand := p + Vector2(10 * side, -26)
	var bend := 9.0 if st == "bite" else 0.0
	var tip := hand + Vector2(dir.x * 26 + 6 * side, -30 + dir.y * 8 + bend)
	draw_line(hand, tip, Color("#78350f"), 3.0)
	draw_line(hand.lerp(tip, 0.6), tip, Color("#a16207"), 2.0)
	draw_circle(hand + (tip - hand) * 0.15, 2.5, Color("#1f2937"))       # makara
	var target := tp
	if st == "cast":
		target += Vector2(0, sin(_t * 3.0) * 2.0)
	elif st == "bite":
		target += Vector2(sin(_t * 30.0) * 2.0, 4.0)
	# misina: uçtan şamandıraya hafif sarkarak
	var pts := PackedVector2Array()
	var sag := 26.0 if st != "bite" else 6.0
	for j in 13:
		var u := j / 12.0
		var q := tip.lerp(target, u) + Vector2(0, sin(u * PI) * sag)
		pts.append(q)
	if st != "caught":
		draw_polyline(pts, Color(1, 1, 1, 0.75), 1.2)
	match st:
		"cast":
			draw_arc(target + Vector2(0, 4), 9.0 + fmod(_t * 6.0, 6.0), 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5)
			draw_circle(target, 5.0, Color("#ef4444"))
			draw_circle(target + Vector2(0, -2), 2.6, Color("#f8fafc"))
		"bite":
			for r in 3:
				var rr := fmod(_t * 40.0 + r * 9.0, 27.0)
				draw_arc(tp + Vector2(0, 4), 6.0 + rr, 0, TAU, 24, Color(1, 1, 1, 0.6 * (1.0 - rr / 27.0)), 2.0)
			draw_circle(target, 3.0, Color("#ef4444"))
			_text(tp + Vector2(-60, -30), "VURDU!", 16, Color("#facc15"), 120)
		"caught":
			var u := clampf(k / 0.9, 0.0, 1.0)
			var fp := tp.lerp(p + Vector2(0, -34), u) + Vector2(0, -sin(u * PI) * 70.0)
			draw_set_transform(fp, k * 9.0, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(0, -6), Vector2(10, 0), Vector2(0, 6)]), Color("#f59e0b"))
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(-19, -6), Vector2(-19, 6)]), Color("#d97706"))
			draw_circle(Vector2(5, -1.5), 1.5, Color("#111827"))
			draw_set_transform(Vector2.ZERO)
			if k < 0.6:
				draw_arc(tp, 8.0 + k * 40.0, 0, TAU, 24, Color(1, 1, 1, 0.7 - k), 2.0)
			draw_polyline(PackedVector2Array([tip, fp]), Color(1, 1, 1, 0.75), 1.2)
		"escaped":
			if k < 0.8:
				draw_arc(tp, 6.0 + k * 30.0, 0, TAU, 24, Color(1, 1, 1, 0.7 - k * 0.8), 2.0)


## Müzik ve ortam sesleri; adımlar.
func _update_sound(delta: float, outside: bool) -> void:
	var t := "city"
	if Env.darkness() > 0.6:
		t = "night"
	elif Env.season == "winter":
		t = "winter"
	elif Env.season == "summer":
		t = "summer"
	Sfx.set_music_track(t)
	var sea := clampf(1.0 - (Map.BEACH.position.y - my_pos.y) / 600.0, 0.0, 1.0)
	if Map.in_south(my_pos) or my_pos.y > Map.SOUTH_COAST_Y - 400:
		sea = 1.0
	var day := 1.0 - Env.darkness()
	var birds := 0.0
	var gulls := 0.0
	var wind := 0.0
	if outside:
		if not Env.is_rainy() and Env.season != "winter":
			birds = day * (1.0 - sea) * (1.0 if Env.season != "autumn" else 0.5)
		gulls = sea * day * (0.0 if Env.weather == "storm" else 1.0)
		if Env.season == "winter" or Env.weather in ["storm", "fog"]:
			wind = 1.0 if Env.weather == "storm" else 0.6
	var indoor := 0.0
	if _room >= 0 or _jail or (panel != null and zone.get("type", "") in INDOOR_PANELS):
		indoor = 0.8
	Sfx.set_ambient2(birds, gulls, wind, indoor)
	# adımlar (yürürken, araçsız, yüzmüyorken)
	if my_moving and my_ride() == "" and not Map.in_sea(my_pos):
		_step_acc += delta
		if _step_acc >= 0.3:
			_step_acc = 0.0
			var pitch := randf_range(0.85, 1.15) * (0.75 if Env.season == "winter" and outside else 1.0)
			Sfx.play("step", -16.0 if Map.BEACH.has_point(my_pos) else -12.0, pitch)
	else:
		_step_acc = 0.3


## Olta olayları: pencere yok, sonuç ekranda bildirim olarak.
func _on_fish_event(d: Dictionary) -> void:
	_fish_since = _t
	match str(d.state):
		"cast":
			_fish_state = "waiting"
			Sfx.play("splash_small")
		"bite":
			_fish_state = "bite"
			Sfx.play("bite")
		"caught":
			_fish_state = "idle"
			if panel != null:
				return
			hud.show_toast("%s yakaladın! (%s) — kova %d/%d" % [d.fish, U.money(int(d.price)), Jobs.my_fish.size() + 1, Jobs.BAG_SIZE])
			Sfx.play("cash" if int(d.price) >= 500 else "catch")
		"escaped":
			_fish_state = "idle"
			if panel != null:
				return
			hud.show_toast("Geç kaldın, balık kaçtı...", false)
			Sfx.play("error", -6.0)
		"early":
			_fish_state = "idle"
			if panel != null:
				return
			hud.show_toast("Çok erken çektin, balık ürktü.", false)
			Sfx.play("error", -6.0)


## Mesleklerde hedef değişince yön oku oraya döner.
func _on_job_changed() -> void:
	var t = Work.job.get("target")
	if t is Vector2:
		nav_target = t


func _on_settings() -> void:
	camera.zoom = Vector2.ONE * Settings.world_zoom()


## Ayarlar penceresi (HUD).
func open_settings() -> void:
	if panel != null:
		return
	panel = preload("res://scripts/ui/settings_panel.gd").new()
	panel.world = self
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)


## Büyük harita (M).
func open_map() -> void:
	if panel != null:
		return
	Tutorial.note("map")
	panel = preload("res://scripts/ui/map_panel.gd").new()
	panel.world = self
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -6.0)


func set_nav(p: Vector2) -> void:
	nav_target = p
	hud.show_toast("Hedef işaretlendi: yön okunu takip et.")


## Navigasyon oku: oyuncunun etrafında hedefi gösterir; varınca kaybolur.
func _draw_nav() -> void:
	if nav_target == null or _room >= 0 or _jail:
		return
	var t: Vector2 = nav_target
	var d := t - my_pos
	if d.length() < 90.0:
		nav_target = null
		hud.show_toast("Hedefe vardın!")
		return
	var dir := d.normalized()
	var c := my_pos + Vector2(0, -20) + dir * 64.0
	var side := dir.orthogonal()
	var pulse := 1.0 + 0.12 * sin(_t * 6.0)
	draw_colored_polygon(PackedVector2Array([c + dir * 18.0 * pulse, c - dir * 6.0 + side * 11.0, c - dir * 6.0 - side * 11.0]), Color(0.95, 0.27, 0.27, 0.9))
	_text(c + Vector2(-50, -18), "%d m" % int(d.length() / 10.0), 13, Color("#fecaca"), 100)
	# hedefte bayrak
	draw_line(t, t + Vector2(0, -40), Color("#7f1d1d"), 3)
	draw_colored_polygon(PackedVector2Array([t + Vector2(0, -40), t + Vector2(24, -32), t + Vector2(0, -24)]), Color("#ef4444"))


## Plaj sahası: çizgiler, kaleler, skor.
func _draw_field() -> void:
	var f: Rect2 = Football.FIELD
	draw_rect(f, Color(0.95, 0.85, 0.6, 0.6))
	draw_rect(f, Color(1, 1, 1, 0.9), false, 3)
	draw_line(Vector2(f.get_center().x, f.position.y), Vector2(f.get_center().x, f.end.y), Color(1, 1, 1, 0.9), 2)
	draw_arc(f.get_center(), 34, 0, TAU, 32, Color(1, 1, 1, 0.9), 2)
	for side in [-1, 1]:
		var gx: float = f.position.x if side == -1 else f.end.x
		var gy := f.get_center().y
		var col := Color("#ef4444") if side == -1 else Color("#3b82f6")
		draw_rect(Rect2(gx + (-18 if side == -1 else 0), gy - Football.GOAL_HALF, 18, Football.GOAL_HALF * 2), Color(1, 1, 1, 0.35))
		for k in 5:
			var yy := gy - Football.GOAL_HALF + k * Football.GOAL_HALF / 2.0
			draw_line(Vector2(gx, yy), Vector2(gx + 18 * side, yy), Color(1, 1, 1, 0.6), 1)
		draw_line(Vector2(gx, gy - Football.GOAL_HALF), Vector2(gx, gy + Football.GOAL_HALF), col, 5)
	_text(Vector2(f.position.x, f.position.y - 10), "KIRMIZI %d : %d MAVİ" % [int(Football.score.red), int(Football.score.blue)], 18, Color("#fde68a"), f.size.x)


func _draw_ball(p: Vector2) -> void:
	draw_set_transform(p + Vector2(3, 7), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 10, Color(0, 0, 0, 0.25))
	draw_set_transform(p, Football.ball.x * 0.05, Vector2.ONE)
	draw_circle(Vector2.ZERO, Football.BALL_R, Color.WHITE)
	for k in 5:
		var a := TAU * k / 5.0
		draw_circle(Vector2(cos(a), sin(a)) * 5.5, 2.2, Color("#111827"))
	draw_circle(Vector2.ZERO, 2.4, Color("#111827"))
	draw_set_transform(Vector2.ZERO)


func _draw_langirt_table(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-50, -12), Vector2(100, 34)), Color(0, 0, 0, 0.2))
	for lx in [-44, 40]:
		draw_rect(Rect2(p.x + lx, p.y - 6, 6, 26), Color("#451a03"))
	draw_rect(Rect2(p + Vector2(-52, -40), Vector2(104, 40)), Color("#78350f"))
	draw_rect(Rect2(p + Vector2(-46, -36), Vector2(92, 32)), Color("#15803d"))
	for k in 4:
		var x := p.x - 33 + k * 22
		draw_line(Vector2(x, p.y - 46), Vector2(x, p.y + 2), Color("#cbd5e1"), 2)
		draw_circle(Vector2(x, p.y - 20), 3.5, Color("#ef4444") if k % 2 == 0 else Color("#3b82f6"))
	_text(p + Vector2(-60, -54), "LANGIRT", 13, Color("#fde68a"), 120)


func _draw_icecream_cart(p: Vector2) -> void:
	draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(p + Vector2(-34, -40), Vector2(68, 38)), Color("#fef3c7"))
	draw_rect(Rect2(p + Vector2(-34, -40), Vector2(68, 38)), Color("#be185d"), false, 2)
	for k in 3:
		draw_circle(p + Vector2(-16 + k * 16, -48), 8, [Color("#f9a8d4"), Color("#a16207"), Color("#86efac")][k])
	draw_circle(p + Vector2(-22, 0), 7, Color("#374151"))
	draw_circle(p + Vector2(22, 0), 7, Color("#374151"))
	draw_line(p + Vector2(30, -40), p + Vector2(30, -92), Color("#78350f"), 2)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -88), p + Vector2(30, -110), p + Vector2(70, -88)]), Color("#f472b6"))
	_text(p + Vector2(-60, -60), "DONDURMA", 13, Color("#be185d"), 120)


func _draw_snowman(p: Vector2, style: int) -> void:
	draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_circle(p + Vector2(0, -14), 18, Color("#f8fafc"))
	draw_circle(p + Vector2(0, -40), 13, Color("#f8fafc"))
	draw_circle(p + Vector2(0, -60), 10, Color("#f8fafc"))
	draw_circle(p + Vector2(-3, -62), 1.6, Color("#111827"))
	draw_circle(p + Vector2(3, -62), 1.6, Color("#111827"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -59), p + Vector2(11, -57), p + Vector2(0, -56)]), Color("#f97316"))
	for k in 3:
		draw_circle(p + Vector2(0, -46 + k * 7), 1.5, Color("#111827"))
	draw_line(p + Vector2(-12, -42), p + Vector2(-26, -52), Color("#78350f"), 2)
	draw_line(p + Vector2(12, -42), p + Vector2(26, -52), Color("#78350f"), 2)
	match style:
		0:
			draw_rect(Rect2(p.x - 10, p.y - 82, 20, 14), Color("#111827"))
			draw_rect(Rect2(p.x - 14, p.y - 70, 28, 3), Color("#111827"))
		1:
			draw_rect(Rect2(p.x - 12, p.y - 53, 24, 5), Color("#dc2626"))
		2:
			draw_circle(p + Vector2(0, -67), 8, Color("#2563eb"))
			draw_circle(p + Vector2(0, -75), 3, Color("#f8fafc"))


## Kartopları (düz çizgide uçar) ve isabet izleri.
func _draw_snow_fx() -> void:
	var keep: Array = []
	for b in _snowballs:
		var k := _t - float(b.t0)
		var dist := k * Seasonal.SNOWBALL_SPEED
		if dist > Seasonal.SNOWBALL_RANGE:
			continue
		keep.append(b)
		var p: Vector2 = b.from + Vector2(b.dir) * dist
		draw_circle(p + Vector2(0, 18), 4, Color(0, 0, 0, 0.15))
		draw_circle(p, 5, Color.WHITE)
	_snowballs = keep
	var keep2: Array = []
	for sp in _splats:
		var k := _t - float(sp.t0)
		if k > 1.0:
			continue
		keep2.append(sp)
		for j in 7:
			var a := TAU * j / 7.0
			draw_circle(Vector2(sp.pos) + Vector2(cos(a), sin(a)) * (6.0 + k * 22.0), 3.0 * (1.0 - k), Color(1, 1, 1, 1.0 - k))
	_splats = keep2


# ================================================================== 0.9: şehir detayları

func _draw_river() -> void:
	var r: Rect2 = Map.RIVER
	draw_rect(r.grow(6), Color("#c9b57e"))
	draw_rect(r, Color("#2f7fc1"))
	for k in 18:
		var y := fmod(k * 37.0 + _t * 40.0, r.size.y)
		var x := r.position.x + 10 + fmod(k * 13.0, r.size.x - 20)
		draw_line(Vector2(x, r.position.y + y), Vector2(x, r.position.y + y + 10), Color(1, 1, 1, 0.35), 2)


func _draw_bridge() -> void:
	var b: Rect2 = Map.BRIDGE
	draw_rect(Rect2(b.position + Vector2(4, 6), b.size), Color(0, 0, 0, 0.25))
	draw_rect(b, Color("#a8a29e"))
	for y in range(int(b.position.y) + 8, int(b.end.y), 14):
		draw_line(Vector2(b.position.x, y), Vector2(b.end.x, y), Color("#78716c"), 1)
	for x in [b.position.x + 2, b.end.x - 6]:
		draw_rect(Rect2(x, b.position.y, 4, b.size.y), Color("#57534e"))
		for y in range(int(b.position.y), int(b.end.y), 22):
			draw_rect(Rect2(x - 2, y, 8, 8), Color("#44403c"))
	draw_rect(Rect2(b.position.x + 8, 390, b.size.x - 16, 110), Color("#4b5563"))   # yol kısmı


func _draw_park() -> void:
	var p: Rect2 = Map.PARK
	draw_rect(p, Color(0.32, 0.6, 0.3, 0.55))
	draw_rect(p, Color("#4d7c0f"), false, 3)
	var cy := p.get_center().y
	draw_rect(Rect2(p.position.x, cy - 10, p.size.x, 20), Color("#e7d9b0"))               # yürüyüş yolu
	draw_rect(Rect2(Map.FOUNTAIN.x - 10, p.position.y, 20, p.size.y), Color("#e7d9b0"))
	for fx in [p.position.x + 70, p.position.x + 250, p.position.x + 600, p.position.x + 680]:
		for fy in [cy - 46, cy + 30]:
			draw_rect(Rect2(fx, fy, 70, 18), Color("#7c4a1e"))
			for k in 6:
				draw_circle(Vector2(fx + 7 + k * 11, fy + 9), 4, [Color("#f472b6"), Color("#facc15"), Color("#f87171"), Color("#c084fc")][(k + int(fx)) % 4])
	for bx in [p.position.x + 170, p.position.x + 380, p.position.x + 560]:
		draw_rect(Rect2(bx, cy + 14, 40, 8), Color("#92400e"))                            # banklar
		draw_rect(Rect2(bx, cy + 10, 40, 4), Color("#78350f"))
	_text(Vector2(p.position.x, p.position.y + 20), "ŞEHİR PARKI", 16, Color(1, 1, 1, 0.85), p.size.x)
	# Şampiyonlar Duvarı
	var cw := Map.CHAMPIONS_WALL
	draw_rect(Rect2(cw.x - 50, cw.y - 46, 100, 46), Color("#57534e"))
	draw_rect(Rect2(cw.x - 44, cw.y - 40, 88, 34), Color("#78716c"))
	for k in 3:
		draw_circle(Vector2(cw.x - 26 + k * 26, cw.y - 23), 8, [Color("#facc15"), Color("#cbd5e1"), Color("#d97706")][k])
	_text(Vector2(cw.x - 80, cw.y - 52), "ŞAMPİYONLAR DUVARI", 12, Color("#fde68a"), 160)
	# çeşme
	var f := Map.FOUNTAIN
	var rr := Map.FOUNTAIN_R
	draw_set_transform(f, 0, Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, rr + 6, Color("#9ca3af"))
	draw_circle(Vector2.ZERO, rr, Color("#38bdf8"))
	for k in 3:
		var w := fmod(_t * 18.0 + k * 12.0, rr)
		draw_arc(Vector2.ZERO, w, 0, TAU, 24, Color(1, 1, 1, 0.5 * (1.0 - w / rr)), 2)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(f.x - 6, f.y - 34, 12, 30), Color("#d1d5db"))
	for k in 8:
		var a := TAU * k / 8.0 + _t * 0.5
		var tip := f + Vector2(cos(a) * 24.0, -34.0 + sin(_t * 6.0 + k) * 2.0)
		draw_line(f + Vector2(0, -36), f + Vector2(cos(a) * 12.0, -44), Color(0.75, 0.92, 1.0, 0.8), 2)
		draw_line(f + Vector2(cos(a) * 12.0, -44), tip + Vector2(0, 14), Color(0.75, 0.92, 1.0, 0.6), 2)


func _draw_clock_tower(c: Vector2) -> void:
	draw_set_transform(c + Vector2(0, 4), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(c.x - 22, c.y - 150, 44, 150), Color("#b45309"))
	draw_rect(Rect2(c.x - 22, c.y - 150, 44, 150), Color("#78350f"), false, 2)
	for y in range(int(c.y) - 140, int(c.y), 20):
		draw_line(Vector2(c.x - 22, y), Vector2(c.x + 22, y), Color("#92400e"), 1)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-28, -150), c + Vector2(28, -150), c + Vector2(0, -190)]), Color("#1e3a8a"))
	var cc := c + Vector2(0, -122)
	draw_circle(cc, 17, Color("#f8fafc"))
	draw_arc(cc, 17, 0, TAU, 32, Color("#1f2937"), 2)
	for k in 12:
		var a := TAU * k / 12.0
		draw_circle(cc + Vector2(cos(a), sin(a)) * 14.0, 1.0, Color("#1f2937"))
	var h := Env.hour
	var ha := TAU * fmod(h, 12.0) / 12.0 - PI / 2.0
	var ma := TAU * (h - floorf(h)) - PI / 2.0
	draw_line(cc, cc + Vector2(cos(ha), sin(ha)) * 8.0, Color("#111827"), 2.5)
	draw_line(cc, cc + Vector2(cos(ma), sin(ma)) * 13.0, Color("#111827"), 1.5)
	draw_rect(Rect2(c.x - 8, c.y - 26, 16, 26), Color("#451a03"))


func _draw_bus(p: Vector2, dir: Vector2) -> void:
	var ang := dir.angle()
	draw_set_transform(p + Vector2(4, 8), ang, Vector2.ONE)
	draw_rect(Rect2(-70, -24, 140, 48), Color(0, 0, 0, 0.25))
	draw_set_transform(p, ang, Vector2.ONE)
	draw_rect(Rect2(-72, -26, 144, 52), Color("#facc15"))
	draw_rect(Rect2(-72, -26, 144, 52), Color("#854d0e"), false, 3)
	for k in 5:
		draw_rect(Rect2(-60 + k * 26, -20, 18, 40), Color("#bae6fd"))
	draw_rect(Rect2(56, -22, 12, 44), Color("#1e293b"))
	draw_set_transform(Vector2.ZERO)
	_text(p + Vector2(-40, -36), "OTOBÜS", 12, Color("#fde68a"), 80)


func _draw_fire(p: Vector2, hp: float) -> void:
	var s := clampf(hp / Work.FIRE_HP, 0.3, 1.6)
	for k in 7:
		var off := Vector2(sin(k * 1.7) * 26.0 * s, 0)
		var h := (34.0 + 14.0 * sin(_t * 9.0 + k)) * s
		var base := p + off
		draw_colored_polygon(PackedVector2Array([base + Vector2(-12 * s, 0), base + Vector2(12 * s, 0), base + Vector2(sin(_t * 7.0 + k) * 5.0, -h)]), Color(1.0, 0.45 + 0.1 * (k % 3), 0.05, 0.85))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-6 * s, 0), base + Vector2(6 * s, 0), base + Vector2(0, -h * 0.6)]), Color(1.0, 0.9, 0.3, 0.9))
	for k in 5:
		var sy := fmod(_t * 40.0 + k * 30.0, 140.0)
		draw_circle(p + Vector2(sin(_t + k) * 16.0, -50.0 * s - sy), 10.0 + sy * 0.12, Color(0.3, 0.3, 0.3, 0.35 * (1.0 - sy / 140.0)))
	_text(p + Vector2(-60, -70.0 * s - 20), "YANGIN %d%%" % int(hp), 14, Color("#fca5a5"), 120)


func _draw_passenger(p: Vector2) -> void:
	Avatar.draw(self, p, {"skin": 2, "hair": 1, "hair_color": 3, "shirt": 5, "pants": 2, "hat": 0, "glasses": 0, "neck": 0}, "down", 0)
	var wave := sin(_t * 8.0) * 6.0
	draw_line(p + Vector2(10, -34), p + Vector2(18 + wave, -52), Color("#f2c39b"), 4)
	_text(p + Vector2(-60, -72), "TAKSİ!", 15, Color("#facc15"), 120)


## İtfaiye, taksi durağı, kargo deposu, duraklar, geri dönüşüm, çöp torbaları.
func _draw_work_world() -> void:
	var fs: Rect2 = Map.FIRE_STATION
	draw_rect(Rect2(fs.position + Vector2(6, 8), fs.size), Color(0, 0, 0, 0.2))
	draw_rect(fs, Color("#b91c1c"))
	draw_rect(Rect2(fs.position.x, fs.position.y, fs.size.x, 26), Color("#7f1d1d"))
	for k in 2:
		var gx := fs.position.x + 14 + k * 70
		draw_rect(Rect2(gx, fs.position.y + 44, 58, fs.size.y - 44), Color("#e5e7eb"))
		for y in range(int(fs.position.y) + 52, int(fs.end.y), 12):
			draw_line(Vector2(gx, y), Vector2(gx + 58, y), Color("#9ca3af"), 1)
	_text(Vector2(fs.position.x, fs.position.y + 18), "İTFAİYE", 15, Color.WHITE, fs.size.x)
	# taksi durağı
	var t := Map.TAXI_STAND
	draw_rect(Rect2(t.x - 3, t.y - 60, 6, 60), Color("#374151"))
	draw_rect(Rect2(t.x - 30, t.y - 80, 60, 24), Color("#facc15"))
	draw_rect(Rect2(t.x - 30, t.y - 80, 60, 24), Color("#111827"), false, 2)
	_text(Vector2(t.x - 30, t.y - 62), "TAKSİ", 13, Color("#111827"), 60, false)
	# kargo deposu
	var c := Map.CARGO_DEPOT
	for k in 3:
		draw_rect(Rect2(c.x - 40 + k * 26, c.y - 20 - (k % 2) * 10, 24, 20 + (k % 2) * 10), Color("#b45309"))
		draw_rect(Rect2(c.x - 40 + k * 26, c.y - 20 - (k % 2) * 10, 24, 20 + (k % 2) * 10), Color("#78350f"), false, 1.5)
	_text(Vector2(c.x - 60, c.y - 40), "KARGO", 13, Color("#fde68a"), 120)
	# geri dönüşüm
	var r := Map.RECYCLE
	for k in 3:
		draw_rect(Rect2(r.x - 36 + k * 24, r.y - 30, 22, 30), [Color("#16a34a"), Color("#2563eb"), Color("#ca8a04")][k])
	_text(Vector2(r.x - 70, r.y - 40), "GERİ DÖNÜŞÜM", 12, Color("#bbf7d0"), 140)
	# duraklar
	for k in Map.BUS_STOPS:
		var sp: Vector2 = Map.BUS_STOPS[k][1]
		draw_rect(Rect2(sp.x - 34, sp.y - 40, 68, 6), Color("#1e3a8a"))
		draw_rect(Rect2(sp.x - 32, sp.y - 34, 3, 34), Color("#374151"))
		draw_rect(Rect2(sp.x + 29, sp.y - 34, 3, 34), Color("#374151"))
		draw_rect(Rect2(sp.x - 26, sp.y - 12, 52, 6), Color("#92400e"))
		_text(Vector2(sp.x - 70, sp.y - 48), "DURAK: %s" % Map.BUS_STOPS[k][0], 11, Color("#bfdbfe"), 140)
	# çöp torbaları
	for tr in Work.trash:
		var tp := Vector2(float(tr.x), float(tr.y))
		draw_circle(tp + Vector2(0, -6), 8, Color("#1f2937"))
		draw_circle(tp + Vector2(0, -15), 4, Color("#374151"))


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
	blocked.append(Map.RIVER.grow(24))
	blocked.append(Map.PARK.grow(10))
	blocked.append(Map.FIRE_STATION.grow(30))
	for k in Map.BUS_STOPS:
		blocked.append(Rect2(Map.BUS_STOPS[k][1] - Vector2(60, 50), Vector2(120, 80)))
	for p in [Map.TAXI_STAND, Map.CARGO_DEPOT, Map.RECYCLE]:
		blocked.append(Rect2(p - Vector2(60, 60), Vector2(120, 100)))
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
		if Football.FIELD.grow(40).has_point(Vector2(x, by + 60)) or absf(x - Langirt.POS.x) < 90 or absf(x - Seasonal.ICECREAM_POS.x) < 70:
			continue      # saha, langırt masası, dondurmacı
		nature.append([Vector2(x + rng.randf_range(-30, 30), by + 55 + rng.randf_range(0, 25)), 3, rng.randf_range(0.9, 1.15)])
	var k := 0
	for x in [140, 430, 720, 1240, 1820, 2120]:
		nature.append([Vector2(x, by + 150), 4 + k % 3, 1.0])
		nature.append([Vector2(x + 52, by + 175), 7, 1.0])
		nature.append([Vector2(x - 50, by + 178), 7, 1.0])
		k += 1
	nature.append([Vector2(1420, by + 190), 8, 1.0])
	nature.append([Vector2(880, by + 200), 9, 1.0])
	# Martı Adası palmiyeleri ve şezlongları
	var ic := Map.ISLAND.get_center()
	for j in 9:
		var a := TAU * j / 9.0 + 0.3
		var pp := ic + Vector2(cos(a) * Map.ISLAND.size.x * 0.36, sin(a) * Map.ISLAND.size.y * 0.33)
		if pp.distance_to(Map.LIGHTHOUSE) > 70 and absf(pp.x - Map.ISLAND_PIER.get_center().x) > 50:
			nature.append([pp, 3, rng.randf_range(0.85, 1.1)])
	nature.append([ic + Vector2(-170, 60), 5, 1.0])
	nature.append([ic + Vector2(-120, 82), 7, 1.0])
	# park ağaçları (kenarlarda)
	for x in range(int(Map.PARK.position.x) + 30, int(Map.PARK.end.x) - 20, 95):
		if absf(x - Map.FOUNTAIN.x) > 90 and absf(x - Map.CLOCK_TOWER.x) > 60:
			nature.append([Vector2(x, Map.PARK.position.y + 18), 0 if (x / 95) % 2 == 0 else 2, rng.randf_range(0.8, 1.0)])
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
	_draw_river()
	_draw_roads()
	_draw_bridge()
	_draw_park()
	_draw_race_track()
	_draw_beach()
	_draw_field()
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
	_draw_work_world()
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
	if _room < 0:
		var bp := Football.ball_now()
		items.append([bp.y, "ball", bp])
		items.append([Langirt.POS.y, "lt", Langirt.POS])
		if Seasonal.icecream_open():
			items.append([Seasonal.ICECREAM_POS.y, "ic", Seasonal.ICECREAM_POS])
		for sm in Seasonal.snowmen:
			items.append([float(sm.y), "sm", sm])
		var bus := Map.bus_at(Land.server_now())
		items.append([bus[0].y, "bus", bus])
		items.append([Map.CLOCK_TOWER.y, "clock", Map.CLOCK_TOWER])
		for cr in Map.CRANES:
			items.append([cr.y, "crane", cr])
		for f in Work.fires:
			items.append([float(f.y) + 1.0, "fire", f])
		if Work.job.get("passenger") is Vector2:
			items.append([Work.job.passenger.y, "pax", Work.job.passenger])
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
		elif it[1] == "ball":
			_draw_ball(it[2])
		elif it[1] == "lt":
			_draw_langirt_table(it[2])
		elif it[1] == "ic":
			_draw_icecream_cart(it[2])
		elif it[1] == "bus":
			_draw_bus(it[2][0], it[2][1])
		elif it[1] == "crane":
			_draw_crane(it[2])
		elif it[1] == "clock":
			_draw_clock_tower(it[2])
		elif it[1] == "fire":
			_draw_fire(Vector2(float(it[2].x), float(it[2].y)), float(it[2].hp))
		elif it[1] == "pax":
			_draw_passenger(it[2])
		elif it[1] == "sm":
			_draw_snowman(Vector2(float(it[2].x), float(it[2].y)), int(it[2].get("style", 0)))
		elif it[1] == "pet":
			_draw_pet(it[2][0], it[2][1])
		else:
			var a: Array = it[2]
			_draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	_draw_placement_ghost()
	_draw_snow_fx()
	_draw_nav()
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
	# derin deniz (sadece tekneyle): koyu mavi, sınırda şamandıra sırası
	var deep_poly := PackedVector2Array()
	for i in n + 1:
		deep_poly.append(Vector2(i * 40.0, Map.DEEP_Y + sin(i * 0.5 + _t * 0.6) * 10.0))
	deep_poly.append(Vector2(Map.WORLD.size.x, Map.SOUTH_COAST_Y))
	deep_poly.append(Vector2(0, Map.SOUTH_COAST_Y))
	draw_colored_polygon(deep_poly, Color("#165d94"))
	for x in range(60, int(Map.WORLD.size.x), 180):
		var by := Map.DEEP_Y + sin(_t * 1.5 + x) * 3.0
		draw_circle(Vector2(x, by), 7, Color("#f97316"))
		draw_circle(Vector2(x, by - 3), 3, Color("#ffffff"))
	_text(Vector2(80, Map.DEEP_Y - 18), "AÇIK DENİZ — sadece tekneyle", 14, Color(1, 1, 1, 0.8))
	for i in 70:
		var sp := Vector2(float((i * 571) % int(Map.WORLD.size.x)), sea.position.y + 100 + float((i * 137) % int(sea.size.y - 120)))
		var a := 0.25 + 0.25 * sin(_t * 2.0 + i)
		draw_line(sp, sp + Vector2(14, 0), Color(1, 1, 1, a), 2)
	_draw_island()
	_draw_south()
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


## 1.0: Sanayi/Liman bölgesi: rıhtım, yol, konteynerler, vinçler, liman ve feribot iskeleleri, feribot.
func _draw_south() -> void:
	var vsize := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(300)
	# feribot iskelesi (şehir) her zaman
	var fp: Rect2 = Map.FERRY_PIER
	if view.intersects(fp):
		draw_rect(Rect2(fp.position + Vector2(5, 6), fp.size), Color(0, 0, 0, 0.2))
		draw_rect(fp, Color("#78716c"))
		for y in range(int(fp.position.y), int(fp.end.y), 18):
			draw_line(Vector2(fp.position.x, y), Vector2(fp.end.x, y), Color("#57534e"), 2)
		draw_rect(fp, Color("#232634"), false, 3)
		_text(Vector2(fp.position.x - 60, fp.end.y + 24), "FERİBOT İSKELESİ", 15, Color.WHITE, fp.size.x + 120)
	# feribot gemisi
	var fr := Map.ferry_at(Land.server_now())
	var fpos: Vector2 = fr[0]
	if view.has_point(fpos):
		var ang := Vector2(fr[1]).angle()
		var bob := sin(_t * 1.4) * 2.0
		draw_set_transform(fpos + Vector2(6, 10 + bob), ang, Vector2.ONE)
		draw_rect(Rect2(-90, -30, 180, 60), Color(0, 0, 0, 0.25))
		draw_set_transform(fpos + Vector2(0, bob), ang, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-90, -30), Vector2(70, -30), Vector2(100, 0), Vector2(70, 30), Vector2(-90, 30)]), Color("#f8fafc"))
		draw_rect(Rect2(-90, -30, 190, 8), Color("#1e3a8a"))
		draw_rect(Rect2(-60, -18, 100, 36), Color("#e2e8f0"))
		for k in 5:
			draw_rect(Rect2(-54 + k * 19, -12, 12, 10), Color("#7dd3fc"))
		draw_rect(Rect2(-10, -26, 16, 24), Color("#dc2626"))
		draw_set_transform(Vector2.ZERO)
		_text(fpos + Vector2(-60, -48), "FERİBOT", 13, Color("#bfdbfe"), 120)
	var sy := Map.SOUTH_COAST_Y
	if view.end.y < sy - 200:
		return
	# kara ve rıhtım
	var coast := PackedVector2Array()
	var n := int(Map.WORLD.size.x / 40.0)
	for i in n + 1:
		coast.append(Vector2(i * 40.0, sy + sin(i * 40.0 / 70.0) * 6.0))
	coast.append(Vector2(Map.WORLD.size.x, Map.WORLD.end.y))
	coast.append(Vector2(0, Map.WORLD.end.y))
	draw_colored_polygon(coast, Color("#a8a29e"))
	draw_rect(Rect2(0, sy + 90, Map.WORLD.size.x, Map.WORLD.end.y - sy - 90), GRASS.get(Env.season, GRASS.spring).darkened(0.1))
	draw_rect(Rect2(0, sy + 4, Map.WORLD.size.x, 86), Color("#9ca3af"))                   # beton rıhtım
	for x in range(0, int(Map.WORLD.size.x), 60):
		draw_line(Vector2(x, sy + 4), Vector2(x, sy + 90), Color("#8b949e"), 1)
	draw_line(Vector2(0, sy + 6), Vector2(Map.WORLD.size.x, sy + 6), Color("#facc15"), 3)
	var r: Rect2 = Map.PORT_ROAD
	draw_rect(r.grow(6), Color("#9ca3af"))
	draw_rect(r, Color("#3f4148"))
	for x in range(0, int(Map.WORLD.size.x), 70):
		draw_rect(Rect2(x, r.get_center().y - 3, 34, 6), Color(1, 1, 1, 0.6))
	# liman iskelesi
	var pp: Rect2 = Map.PORT_PIER
	draw_rect(pp, Color("#78716c"))
	for y in range(int(pp.position.y), int(pp.end.y), 18):
		draw_line(Vector2(pp.position.x, y), Vector2(pp.end.x, y), Color("#57534e"), 2)
	draw_rect(pp, Color("#232634"), false, 3)
	_text(Vector2(pp.position.x - 70, pp.position.y - 12), "LİMAN İSKELESİ (FERİBOT)", 14, Color.WHITE, pp.size.x + 140)
	# konteyner sahası
	var cy: Rect2 = Map.CONTAINER_YARD
	var cols := [Color("#dc2626"), Color("#2563eb"), Color("#16a34a"), Color("#f59e0b"), Color("#7c3aed"), Color("#0891b2")]
	for row in 3:
		for k in 8:
			var c := Rect2(cy.position.x + k * 145, cy.position.y + row * 100, 130, 80)
			var col: Color = cols[(row * 3 + k * 5) % cols.size()]
			draw_rect(Rect2(c.position + Vector2(4, 6), c.size), Color(0, 0, 0, 0.25))
			draw_rect(c, col)
			for x in range(int(c.position.x) + 8, int(c.end.x), 12):
				draw_line(Vector2(x, c.position.y + 4), Vector2(x, c.end.y - 4), col.darkened(0.25), 2)
			draw_rect(c, col.darkened(0.45), false, 2)
	_text(Vector2(cy.position.x, cy.position.y - 12), "KONTEYNER SAHASI", 16, Color("#fde68a"), cy.size.x)
	_text(Vector2(0, sy + 52), "SANAYİ LİMANI", 26, Color(1, 1, 1, 0.85), Map.WORLD.size.x)


func _draw_crane(base: Vector2) -> void:
	var swing := sin(_t * 0.3 + base.x) * 30.0
	for dx in [-30, 30]:
		draw_line(base + Vector2(dx, 0), base + Vector2(dx * 0.4, -170), Color("#f59e0b"), 6)
	draw_rect(Rect2(base.x - 40, base.y - 6, 80, 12), Color("#78350f"))
	draw_line(base + Vector2(-70, -170), base + Vector2(150, -170), Color("#f59e0b"), 8)
	draw_rect(Rect2(base.x - 16, base.y - 196, 32, 26), Color("#fbbf24"))
	var hook := base + Vector2(80 + swing, -170)
	draw_line(hook, hook + Vector2(0, 90), Color("#374151"), 2)
	draw_rect(Rect2(hook.x - 30, hook.y + 90, 60, 34), Color("#2563eb"))


## Martı Adası: kumsal, çim, iskele, deniz feneri (gece döner ışık).
func _draw_island() -> void:
	var r := Map.ISLAND
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(400).intersects(r.grow(200)):
		return
	draw_colored_polygon(_ellipse(r.grow(26)), Color("#4fb0dd"))         # sığ su
	draw_colored_polygon(_ellipse(r.grow(8)), Color(1, 1, 1, 0.5))       # köpük
	draw_colored_polygon(_ellipse(r), Color("#f0dba5"))
	draw_colored_polygon(_ellipse(r.grow(-60)), GRASS.get(Env.season, GRASS.spring))
	var pr := Map.ISLAND_PIER
	draw_rect(Rect2(pr.position + Vector2(5, 6), pr.size), Color(0, 0, 0, 0.2))
	draw_rect(pr, Color("#a0703c"))
	for y in range(int(pr.position.y), int(pr.end.y), 16):
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), Color("#6b4423"), 2)
	draw_rect(pr, Color("#232634"), false, 3)
	_text(Vector2(r.position.x, r.get_center().y + 10), "MARTI ADASI", 22, Color(1, 1, 1, 0.9), r.size.x)
	# deniz feneri
	var l := Map.LIGHTHOUSE
	draw_set_transform(l + Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([l + Vector2(-24, 0), l + Vector2(24, 0), l + Vector2(14, -120), l + Vector2(-14, -120)]), Color("#f8fafc"))
	for k in 3:
		var y0 := -20.0 - k * 36.0
		var w0 := 24.0 - (k * 36.0 + 20.0) / 120.0 * 10.0
		draw_colored_polygon(PackedVector2Array([l + Vector2(-w0, y0), l + Vector2(w0, y0), l + Vector2(w0 - 1.5, y0 - 14), l + Vector2(-w0 + 1.5, y0 - 14)]), Color("#dc2626"))
	draw_rect(Rect2(l.x - 18, l.y - 140, 36, 22), Color("#334155"))
	draw_rect(Rect2(l.x - 12, l.y - 136, 24, 14), Color("#fde68a") if Env.darkness() > 0.2 else Color("#bae6fd"))
	draw_colored_polygon(PackedVector2Array([l + Vector2(-22, -140), l + Vector2(22, -140), l + Vector2(0, -160)]), Color("#991b1b"))
	if Env.darkness() > 0.2:
		var ang := _t * 0.9
		var src := l + Vector2(0, -129)
		var dir := Vector2(cos(ang), sin(ang) * 0.45)
		var side := dir.orthogonal() * 0.18
		draw_colored_polygon(PackedVector2Array([src, src + (dir + side) * 420.0, src + (dir - side) * 420.0]), Color(1, 0.95, 0.7, 0.18 * Env.darkness()))
	_text(l + Vector2(-80, -176), "DENİZ FENERİ", 13, Color("#fde68a"), 160)


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
		if Party.is_party(p, Land.server_now()):
			for k in 10:
				var lp := r.position + Vector2(fposmod(k * 151.0 + _t * (60.0 + k * 9.0), r.size.x), fposmod(k * 97.0 + _t * (45.0 + k * 7.0), r.size.y))
				draw_circle(lp, 34, Color.from_hsv(fmod(_t * 0.3 + k * 0.1, 1.0), 0.8, 1.0, 0.18))
			_text(Vector2(r.position.x, r.position.y - 58), "♪ PARTİ ♪", 18, Color("#f9a8d4"), r.size.x)
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
	if str(extra.get("title", "")) != "":
		_text(p + Vector2(-90, y - 16), "«%s»" % extra.title, 12, Color("#fcd34d"), 180)
		y -= 14
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
			if str(extra.get("fishing", "")) != "":
				_draw_rod(p + Vector2(0, -6), facing, extra)
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
		# gölge (ve kendi karakterinde beyaz halka; futbol takımındaysa takım rengi)
		draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
		var team := str(extra.get("team", ""))
		if team != "" and Football.FIELD.grow(120).has_point(p):
			draw_arc(Vector2.ZERO, 22, 0, TAU, 32, Color("#ef4444") if team == "red" else Color("#3b82f6"), 4)
		if me:
			draw_arc(Vector2.ZERO, 19, 0, TAU, 32, Color(1, 1, 1, 0.85), 3)
		draw_set_transform(Vector2.ZERO)
	var frame := 0
	if moving:
		frame = [1, 0, 2, 0][int(_t * (6.0 if swim else 9.0)) % 4]
	Avatar.draw(self, p, app, facing, frame, 1.0, swim)
	if str(extra.get("fishing", "")) != "":
		_draw_rod(p, facing, extra)
	_name(p, -56 + (22 if swim else 0), pname, name_col, extra)
