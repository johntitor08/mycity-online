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
	"muze": preload("res://scripts/ui/museum_panel.gd"),
	"dagevi": preload("res://scripts/ui/lodge_panel.gd"),
	"stage": preload("res://scripts/ui/band_panel.gd"),
	"hara": preload("res://scripts/ui/hara_panel.gd"),
	"hipodrom": preload("res://scripts/ui/hippo_panel.gd"),
	"teleskop": preload("res://scripts/ui/sky_panel.gd"),
	"okul": preload("res://scripts/ui/school_panel.gd"),
	"terminal": preload("res://scripts/ui/flight_panel.gd"),
	"fair_gise": preload("res://scripts/ui/fair_panel.gd"),
	"gallery": preload("res://scripts/ui/gallery_panel.gd"),
	"spor": preload("res://scripts/ui/gym_panel.gd"),
	"korsan": preload("res://scripts/ui/pirate_panel.gd"),
	"akvaryum": preload("res://scripts/ui/aquarium_panel.gd"),
	"bayram": preload("res://scripts/ui/holiday_panel.gd"),
	"rail": preload("res://scripts/ui/rail_panel.gd"),
	"sinema": preload("res://scripts/ui/cinema_panel.gd"),
	"paint": preload("res://scripts/ui/paint_panel.gd"),
	"isle": preload("res://scripts/ui/isle_panel.gd"),
	"port": preload("res://scripts/ui/port_panel.gd"),
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
	"korsan": preload("res://assets/pets/parrot.svg"),
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
	"muze": preload("res://assets/buildings/muze.svg"),
	"teleferik": preload("res://assets/buildings/teleferik.svg"),
	"teleferik_dag": preload("res://assets/buildings/teleferik.svg"),
	"dagevi": preload("res://assets/buildings/dagevi.svg"),
	"hara": preload("res://assets/buildings/hara.svg"),
	"okul": preload("res://assets/buildings/okul.svg"),
	"terminal": preload("res://assets/buildings/terminal.svg"),
	"spor": preload("res://assets/buildings/spor.svg"),
	"akvaryum": preload("res://assets/buildings/akvaryum.svg"),
	"sinema": preload("res://assets/buildings/sinema.svg"),
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
# sahne önündeki seyirciler (biri çalarken görünür): konum, görünüm
const PADDOCK := Rect2(1322, 3968, 190, 112)       # haranın önündeki padok
const PADDOCK_HORSES := [[Vector2(1380, 4020), 0], [Vector2(1450, 4056), 4]]
const PHOTO_FILTERS := ["Normal", "Siyah-Beyaz", "Sepya", "Sıcak", "Soğuk", "Vintage", "Poster"]
const AUDIENCE := [
	[Vector2(150, 1590), {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
	[Vector2(205, 1606), {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
	[Vector2(262, 1588), {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}],
	[Vector2(318, 1604), {"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5}],
	[Vector2(372, 1592), {"skin": 2, "hair": 0, "hair_color": 2, "shirt": 3, "pants": 2}],
]

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
var _dive := false          # deniz tabanında mıyım (dalış)
var _mount := false         # dağda mıyım (1.2)
var _fair := false          # fuar ve havalimanında mıyım (1.4)
var _ocean := false         # Açık Okyanus'ta mıyım (1.6)
var _ocean_acc := 0.0
var _ocean_flush := 0.0
var _harp_t := -10.0
var _bump_vel := Vector2.ZERO
var _bump_t := {}
var _takeoff_t := -99.0
var _balloon_zoom := Vector2.ONE
var _rock_acc := 0.0
var mountain_nature: Array = []   # dağdaki çamlar [konum, ölçek]
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
var fx: Array = []                 # 1.3 efektler: {k, pos, t0, dur, d}
var _beds_seen := {}               # tarla tarhlarının son durumu (efekt için)
var _rocks_seen := {}              # kayaların son canı
var _last_money := -1
var _last_level := -1
var _dishes_seen := {}
var _trail_acc := 0.0


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
	Land.plots_changed.connect(_fx_from_plots)
	Mountain.changed.connect(_fx_from_rocks)
	Net.roster_changed.connect(_fx_from_roster)
	Rpg.sheet_changed.connect(_fx_from_sheet)
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
	hud.phone_requested.connect(open_phone)
	Gym.marathon.connect(_on_marathon)
	Zoo.task_changed.connect(func():
		if Zoo.task != "":
			set_nav(Zoo.pen_front(Zoo.task)))
	Pirates.dug.connect(func(d):
		add_fx("dirt", d.pos, 0.7)
		if d.get("treasure", false):
			add_fx("level", d.pos, 1.6)
			Sfx.play("cash")
		else:
			hud.show_toast(str(d.get("hint", "")), str(d.get("hint", "")).begins_with("SICAK"))
			Sfx.play("place", -4.0, 0.7))
	Holidays.changed.connect(_rebuild_blockers)
	Zoo.changed.connect(_rebuild_blockers)
	Airport.flight.connect(_on_flight)
	Rail.trip.connect(_on_trip)
	Paint.hit.connect(_on_paint_hit)
	Airport.takeoff.connect(func(): _takeoff_t = _t)
	Airport.balloon_changed.connect(func():
		if Airport.in_balloon():
			_balloon_zoom = camera.zoom
			camera.zoom = Vector2(0.6, 0.6)
		else:
			camera.zoom = _balloon_zoom)
	Trade.invited.connect(_on_trade_invite)
	Trade.opened.connect(_on_trade_open)
	Trade.closed.connect(func(t): hud.show_toast(t, t.contains("tamam")))
	Phone.message.connect(func(d):
		hud.show_toast("📱 %s: %s" % [d.w, str(d.x).left(60)])
		Sfx.play("notify", -4.0))
	_build_photo_layer()
	Mountain.ski_result.connect(func(d):
		hud.show_toast(str(d.get("text", "")), bool(d.get("ok", false)))
		if d.get("ok", false):
			Sfx.play("success"))
	_make_nature()


func _process(delta: float) -> void:
	_t += delta
	_fx_tick(delta)
	_fx_trash()
	my_moving = false
	if my_ride() == "ski":
		_ski_move(delta)
	elif my_ride() == "ferris":
		var seat := int(Net.roster.get(Net.my_id(), {}).get("seat", 0))
		my_pos = Fair.seat_pos(seat, Land.server_now())
	elif my_ride() == "bumper":
		_bumper_move(delta)
	elif my_ride() == "balloon":
		if Airport.in_balloon():
			my_pos = Map.balloon_at(Airport.balloon_elapsed())
			my_moving = true
	elif my_ride() == "train" or Paint.in_match() and Paint.is_out(Net.my_name):
		pass                                   # trende ya da boyanıp oyun dışıyken yürünmez
	elif panel == null and not hud.is_typing():
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
			if (ride == "car" or ride == "bike") and School.has("surucu"):
				mult *= 1.1                            # sürücü diploması
			if ride == "":
				mult *= Gym.walk_mult()                # kondisyon
			if ride == "" and (Map.in_sea(my_pos) or Map.in_water(my_pos)):
				mult = 0.55
			if _ocean and ride == "boat":
				mult *= Ocean.speed_mult(Ocean.my.up, float(Ocean.my.fuel)) * (0.6 if Ocean.storm_at(my_pos) else 1.0)
			if _dive:
				mult = 0.6
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
	if panel == null and zone.get("type", "") == "rock" and Settings.held("interact"):
		_rock_acc += delta
		if _rock_acc >= 0.45:
			_rock_acc = 0.0
			Mountain.hit(int(zone.id))
			Sfx.play("pick", -5.0, randf_range(0.9, 1.1))
	if panel == null and zone.get("type", "") == "fire" and Settings.held("interact"):
		_spray_acc += delta
		if _spray_acc >= 0.25:
			_spray_acc = 0.0
			Work.spray(int(zone.id))
	Net.update_my_pos(my_pos, delta)
	if _ocean:
		_ocean_tick(delta)
		if panel == null and zone.get("type", "") == "ocean_harpoon" and Settings.held("interact"):
			_harpoon()
	if my_moving:
		_walked += delta
		if _walked > 1.2:
			Tutorial.note("move")
	camera.position = my_pos
	_update_area()
	var swimming := (Map.in_sea(my_pos) or Map.in_water(my_pos)) and my_ride() == ""
	if swimming and not _was_swimming:
		Sfx.play("splash", -4.0)
	_was_swimming = swimming
	var outside := _room < 0 and not _jail and not _dive and not _mount and not _fair
	Sfx.set_ambience(1.0 if _ocean else clampf(1.0 - (Map.BEACH.position.y - my_pos.y) / 700.0, 0.0, 1.0) if outside else 0.0)
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
	if _ocean:
		return p.clamp(OM.OCEAN.position + Vector2(20, 20), OM.OCEAN.end - Vector2(20, 20))
	if _fair:
		var fr := Map.FAIR.grow(-20)
		if my_ride() == "bumper":
			fr = Map.BUMPER.grow(-24)
		elif Paint.in_match():
			fr = Map.ARENA.grow(-16)
		return p.clamp(fr.position, fr.end)
	if _mount:
		var m := Map.MOUNTAIN.grow(-20)
		var lo := Vector2(m.position.x, Map.MOUNTAIN_TOP_Y)
		var hi := m.end
		if my_ride() == "ski":
			lo.x = Map.SLOPE.position.x + 12
			hi.x = Map.SLOPE.end.x - 12
		return p.clamp(lo, hi)
	if _dive:
		var b := Map.SEA_BED.grow(-20)
		return p.clamp(b.position, b.end)
	if _jail:
		var j := Map.JAIL.grow(-18)
		return p.clamp(j.position, j.end)
	if _room >= 0:
		var lvl := int(Land.view[_room].level) if _room < Land.view.size() else 1
		var r := Map.interior_rect(_room, lvl).grow(-18)
		return p.clamp(r.position, r.end)
	return p.clamp(Map.WORLD.position + Vector2(20, 20), Map.WORLD.end - Vector2(20, 20))


func _can_stand(p: Vector2, ride: String) -> bool:
	if _room >= 0 or _jail or _dive:
		return true
	if _ocean:
		return _ocean_can_stand(p, ride)
	if _fair and Paint.in_match():
		return Paint.free_at(p) or not Paint.free_at(my_pos)
	if _fair and Map.ARENA.has_point(p) and not Map.ARENA.has_point(my_pos):
		return false                           # arena çitle çevrili: maça gişeden girilir
	if _mount or _fair:
		return not (_blocked(p) and not _blocked(my_pos))
	if _blocked(p) and not _blocked(my_pos):
		return false              # bina, ev ya da araba (içindeysen çıkabilirsin)
	if my_ride() == "kayik" or ride == "kayik":
		return Map.in_lake(p)     # kayık gölde kalır (karaya ve iskeleye çıkmaz)
	if Map.in_water(p):
		if ride != "" or not Map.in_lake(p):
			return false          # göle araçla girilmez; nehirde yüzülmez (köprü var)
		return not (Map.lake_deep(p) and not Map.lake_deep(my_pos))     # yüzerek gölün derin ortasına girilmez
	if ride == "boat":
		# tekne karaya çıkamaz; gövdesi adanın kumsalına ve iskelelere de giremez
		return Map.in_sea(p) and not (Map.boat_blocked(p) and not Map.boat_blocked(my_pos))
	if ride == "" and Map.in_deep(p) and not Map.in_deep(my_pos):
		return false              # açık denize yüzülmez, tekne gerekir
	if ride != "":
		return not Map.in_sea(p)  # bisiklet/araba denize giremez
	return true


func _update_area() -> void:
	var room := Map.interior_at(my_pos)
	var jail := Map.JAIL.has_point(my_pos)
	var dive := Map.SEA_BED.has_point(my_pos)
	var mount := Map.MOUNTAIN.has_point(my_pos)
	var fair := Map.FAIR.has_point(my_pos)
	var ocean := OM.in_ocean(my_pos)
	if room == _room and jail == _jail and dive == _dive and mount == _mount and fair == _fair and ocean == _ocean:
		return
	_fair = fair
	_ocean = ocean
	_room = room
	_jail = jail
	_dive = dive
	_mount = mount
	var r := Map.WORLD
	if dive:
		r = Map.SEA_BED
	elif mount:
		r = Map.MOUNTAIN
	elif fair:
		r = Map.FAIR
	elif ocean:
		r = OM.OCEAN
	elif jail:
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
	if ride == "ski":
		Mountain.ski_stop()
		return
	if _ocean:
		_ocean_toggle_vehicle()
		return
	if _mount:
		hud.show_toast("Dağda araç kullanılmaz. Kayak için telesiyeje git.", false)
		return
	if _fair or ride in ["ferris", "bumper", "balloon"]:
		return
	if ride == "kayik":
		var land = _lake_land_near(my_pos)
		if land == null:
			hud.show_toast("Kayıktan inmek için kıyıya ya da iskeleye yanaş.", false)
			return
		my_pos = land
		Garage.ride("")
		return
	if ride == "" and my_pos.distance_to(Map.KAYIK_SPOT) < 150.0:
		_board_kayik()
		return
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


func _board_kayik() -> void:
	my_pos = Map.KAYIK_SPOT
	Garage.ride("kayik", Map.KAYIK_SPOT)
	Sfx.play("splash_small")


## Kayıktan inerken yakındaki kara (kıyı ya da iskele).
func _lake_land_near(p: Vector2) -> Variant:
	for dist in [40.0, 70.0, 100.0, 130.0]:
		for k in 16:
			var q: Vector2 = p + Vector2.RIGHT.rotated(TAU * k / 16.0) * dist
			if not Map.in_water(q) and not _blocked(q) and Map.WORLD.has_point(q):
				return q
	return null


## Kıyıya/iskeleye yakın bir deniz noktası (tekneye binmek için).
func _water_near(p: Vector2) -> Variant:
	for dist in [50.0, 90.0, 130.0]:
		for d in [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]:
			var q: Vector2 = p + d * dist
			if Map.in_sea(q):
				return q
	return null


func _near_shore() -> bool:
	for off in [Vector2(0, -90), Vector2(70, 0), Vector2(-70, 0), Vector2(0, 80)]:
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
	if photo_mode:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))
		elif event is InputEventKey and event.pressed and not event.echo:
			_photo_input(event)
		return
	if event is InputEventMouseButton and event.pressed and panel == null and Paint.in_match() \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not Paint.is_out(Net.my_name):
			Paint.fire(get_global_mouse_position() - (my_pos + Vector2(0, -16)))
			Sfx.play("splash_small", -10.0, randf_range(1.8, 2.2))
		get_viewport().set_input_as_handled()
		return
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
		if _ocean:
			open_ocean_map()
		else:
			open_map()
	elif Settings.is_key(k, "phone"):
		open_phone()
	elif Settings.is_key(k, "photo"):
		set_photo_mode(true)
	elif Settings.is_key(k, "horse"):
		_toggle_horse()
	elif Settings.is_key(k, "throw") and Env.season == "winter" and _room < 0 and not _jail:
		var aim := get_global_mouse_position() - my_pos
		if aim.length() < 10.0:
			aim = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}.get(my_facing, Vector2.DOWN)
		Seasonal.throw(aim)
	elif Settings.is_key(k, "dive") and (_dive or (my_ride() == "boat" and Map.in_sea(my_pos))):
		if _dive:
			Dive.surface()
		else:
			Dive.dive()
		Sfx.play("splash")
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
	if _dive:
		zone = {}
		for it in Dive.items:
			if my_pos.distance_to(Vector2(float(it.x), float(it.y))) < Dive.PICK_RANGE:
				zone = {"type": "dive_pick", "id": int(it.id), "label": "Sandığı aç" if it.k == "chest" else "İstiridyeyi aç"}
		var hint := "[%s] yüzeye çık  ·  Oksijen %d sn" % [Settings.key_name("dive"), int(Dive.oxygen_left())]
		if not zone.is_empty():
			hint = "[%s]  %s\n%s" % [Settings.key_name("interact"), zone.label, hint]
		hud.set_hint("" if panel != null else hint)
		return
	if _mount:
		_update_mountain_zone()
		return
	if _fair:
		_update_fair_zone()
		return
	if _ocean:
		_update_ocean_zone()
		return
	if my_ride() == "balloon":
		zone = {}
		hud.set_hint("" if panel != null else "BALON TURU  ·  %d sn  ·  [%s] fotoğraf modu" % [int(maxf(0.0, Map.BALLOON_TIME - Airport.balloon_elapsed())), Settings.key_name("photo")])
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
			if b.type == "teleferik":
				z.label = "Teleferikle dağa çık (%s)" % U.money(Mountain.CABLE_PRICE)
	for k in Map.NPCS:
		if my_pos.distance_to(Map.NPCS[k].pos) < Map.NPC_TALK_RANGE:
			z = {"type": "npc", "npc": k, "label": "Konuş: %s" % Map.NPCS[k].name}
	var dz := _detective_zone({})
	if not dz.is_empty():
		z = dz                                 # ipucu/şüpheli NPC konuşmasından da önce gelir
	if z.get("type", "") == "npc":
		zone = z
		_g_action = _find_g_action()
		var nh := "[%s]  %s" % [Settings.key_name("interact"), z.label]
		if not _g_action.is_empty():
			nh += "\n[%s]  %s" % [Settings.key_name("action"), _g_action.label]
		hud.set_hint("" if panel != null else nh)
		return
	var spot := Map.fishing_spot(my_pos)
	if spot == "" and my_ride() == "boat" and Map.in_sea(my_pos):
		spot = "boat"
	if spot == "" and my_ride() == "kayik" and Map.in_lake(my_pos):
		spot = "lake"
	if spot != "":
		var where: String = {"lake": "Göl", "sea": "Deniz İskelesi", "island": "Martı Adası", "boat": "Tekne"}.get(spot, "")
		z = {"type": "fishing", "label": "%s — Balık Tut%s" % [where, ("   ·   [%s] Dal" % Settings.key_name("dive")) if spot == "boat" else ""], "spot": spot}
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
	z = _korsan_zone(z)
	if my_pos.distance_to(Map.SHUTTLE_CITY) < 90.0:
		z = {"type": "shuttle", "fair": true, "label": "Lunapark & Havalimanı servisi (%s)" % U.money(Fair.SHUTTLE_PRICE)}
	if my_pos.distance_to(Map.DETECTIVE) < 80.0:
		z = {"type": "dedektif", "label": "Dedektif Ferhat — vaka dosyası"}
	if not _detective_zone({}).is_empty():
		z = _detective_zone({})               # açık vakanın ipucu/şüphelisi her şeyden önce gelir
	if my_pos.distance_to(Map.HIPPO_BOOTH) < 120.0 or Map.HIPPO_STANDS.grow(70).has_point(my_pos):
		z = {"type": "hipodrom", "label": "Hipodrom — yarış ve bahis"}
	if Map.STAGE.grow(50).has_point(my_pos):
		z = {"type": "stage", "label": "Park Sahnesi — çal, dinle, bahşiş ver"}
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
	if my_ride() == "" and my_pos.distance_to(Map.KAYIK_SPOT) < 110.0:
		z = {"type": "kayik", "label": "Kayığa bin (bedava) — gölün ortasında balık daha nadir"}
	for mb in Map.MOORED_BOATS:
		if my_pos.distance_to(mb) < 100.0 and my_ride() == "":
			z = {"type": "moored", "pos": mb, "label": "Tekneye bin" if Garage.has_boat() else "Tekne kirala ve bin (%s / %d dk)" % [U.money(Garage.RENT_PRICE), int(Garage.RENT_SECONDS / 60.0)]}
	if my_pos.distance_to(Map.BOAT_RENT_SPOT) < 70.0:
		z = {"type": "boatrent", "label": "Tekne kirala (%s / %d dk) — F: bin" % [U.money(Garage.RENT_PRICE), int(Garage.RENT_SECONDS / 60.0)]}
	if my_pos.distance_to(Map.RACE_FLAG) < 80.0 or my_pos.distance_to(Map.RACE_START) < 60.0:
		z = {"type": "race", "label": "Yarış Pisti — tur başlat"}
	z = _rail_zone(z)
	if my_ride() == "boat" and Ocean.GATE.has_point(my_pos):
		z = {"type": "ocean_gate", "label": "AÇIK OKYANUS'a açıl (30 ada, hazineler, Kraken!)"}
	z = _holiday_zone(z)
	if not dz.is_empty():
		z = dz
	zone = z
	_g_action = _find_g_action()
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	if not _g_action.is_empty():
		hint += ("\n" if hint != "" else "") + "[%s]  %s" % [Settings.key_name("action"), _g_action.label]
	hud.set_hint("" if panel != null else hint)


## G tuşu: görevdeki polis için tutuklama; diğerleri için yankesicilik ya da soygun.
func _find_g_action() -> Dictionary:
	var hg := _holiday_g_action()
	if not hg.is_empty():
		return hg
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
	if _g_action.is_empty():
		return
	match _g_action.kind:
		"knock":
			Holidays.knock(str(_g_action.door))
			Sfx.play("door", -4.0, 1.3)
		"hand":
			Holidays.kiss_hand(str(_g_action.npc))
		"rose":
			Holidays.give_rose(int(_g_action.to))
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
	if zone.type == "kayik":
		_board_kayik()
		return
	if _ocean_interact():
		return
	if _isle_interact():
		return
	if zone.type == "moored":
		if Garage.has_boat():
			my_pos = zone.pos
			Garage.ride("boat", zone.pos)
			Sfx.play("splash_small")
		else:
			Garage.rent_boat()
			hud.show_toast("Tekne kiralanınca bir daha E'ye bas (ya da F) ve bin.")
		return
	match str(zone.type):
		"teleferik":
			Mountain.go_up()
			Sfx.play("door", -4.0, 0.8)
			return
		"teleferik_dag":
			Mountain.go_down()
			Sfx.play("door", -4.0, 0.8)
			return
		"rock":
			Mountain.hit(int(zone.id))
			_rock_acc = 0.0
			Sfx.play("pick", -5.0, randf_range(0.9, 1.1))
			return
		"lift":
			Mountain.ski_start()
			return
		"roast":
			Camp.roast(int(zone.i))
			return
		"santa":
			Holidays.santa()
			Sfx.play("bell")
			return
		"gift":
			Holidays.pick_gift(int(zone.id))
			Sfx.play("coin")
			return
		"dig":
			Pirates.dig()
			return
		"zoo_ticket":
			Zoo.buy_ticket()
			return
		"keeper":
			var had_task := Zoo.task != ""
			Zoo.keeper(not had_task)
			if had_task:
				nav_target = null
			return
		"deliver":
			Zoo.deliver()
			Sfx.play("splash_small", -6.0, 0.8)
			return
		"watch":
			Zoo.watch_feeding()
			return
		"shuttle":
			Fair.shuttle(bool(zone.fair))
			Sfx.play("door", -4.0, 0.9)
			return
		"ferris":
			Fair.ride_ferris()
			return
		"bumper":
			Fair.ride_bumper()
			return
		"candy":
			Fair.buy_candy()
			return
		"balloon":
			Airport.ride_balloon()
			return
		"clue":
			Detective.inspect(str(zone.id))
			Sfx.play("open", -6.0, 1.5)
			return
		"suspect":
			Detective.question(str(zone.id))
			return
		"dedektif":
			if panel == null:
				panel = preload("res://scripts/ui/detective_panel.gd").new()
				panel.nav_requested.connect(func(pos):
					_close_panel()
					set_nav(pos))
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
			return
		"fire_light":
			Camp.light(int(zone.i))
			Sfx.play("splash_small", -10.0, 0.5)
			return
		"tent_rest":
			Camp.rest()
			return
		"tent_pitch":
			Camp.pitch()
			Sfx.play("place")
			return
		"forage":
			Camp.pick(int(zone.id))
			Sfx.play("place", -6.0, 1.3)
			return
		"wish_star":
			Camp.wish()
			Sfx.play("success", -4.0)
			return
		"dive_pick":
			Dive.pick(zone.id)
			Sfx.play("coin", -6.0)
			return
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
	if zone.type == "rail":
		panel.here = str(zone.get("here", "sehir"))
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
	if level < 1 or str(p.get("owner", "")) == "" or Farm.is_farm(p) or Farm.is_ranch(p):
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
	for b in Map.MOUNTAIN_BUILDINGS:
		var mr: Rect2 = b.rect
		_blockers.append(Rect2(mr.position.x + 6, mr.position.y + 16, mr.size.x - 12, mr.size.y - 26))
	_blockers.append(Rect2(Map.LIGHTHOUSE.x - 22, Map.LIGHTHOUSE.y - 30, 44, 34))
	for b in Map.ZOO_BUILDINGS:
		var zr: Rect2 = b.rect
		_blockers.append(Rect2(zr.position.x + 6, zr.position.y + 16, zr.size.x - 12, zr.size.y - 26))
	var zoo: Rect2 = Map.ZOO
	var gx := Map.ZOO_GATE.x
	_blockers.append(Rect2(zoo.position.x, zoo.position.y - 6, gx - 50 - zoo.position.x, 12))     # üst çit (turnikenin solu)
	_blockers.append(Rect2(gx + 50, zoo.position.y - 6, zoo.end.x - gx - 50, 12))                # üst çit (sağı)
	_blockers.append(Rect2(zoo.position.x - 6, zoo.position.y, 12, zoo.size.y))
	_blockers.append(Rect2(zoo.end.x - 6, zoo.position.y, 12, zoo.size.y))
	_blockers.append(Rect2(zoo.position.x, zoo.end.y - 6, zoo.size.x, 12))
	if not Zoo.has_ticket():
		_blockers.append(Rect2(gx - 50, zoo.position.y - 6, 100, 12))                            # turnike: biletsiz geçilmez
	for k in Map.ZOO_PENS:
		_blockers.append(Map.ZOO_PENS[k].grow(-4))
	_blockers.append(Rect2(Map.KORSAN_SHIP.x - 120, Map.KORSAN_SHIP.y - 40, 220, 50))
	for b in Map.FAIR_BUILDINGS + [Map.CINEMA]:
		var fr: Rect2 = b.rect
		_blockers.append(Rect2(fr.position.x + 6, fr.position.y + 16, fr.size.x - 12, fr.size.y - 26))
	var fs: Rect2 = Map.FIRE_STATION
	_blockers.append(Rect2(fs.position.x + 4, fs.position.y + 20, fs.size.x - 8, fs.size.y - 34))
	for i in mini(Land.view.size(), Map.PLOT_COUNT):
		if Farm.is_ranch(Land.view[i]) and str(Land.view[i].get("owner", "")) != "":
			var pr := Map.plot_rect(i)
			_blockers.append(Rect2(pr.position.x + 14, pr.position.y + 34, 92, 64))     # ahır binası (kapı önü serbest)
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
	# diğer oyuncuların arabaları ve tekneleri
	for id in shown:
		var info = Net.roster.get(id)
		if info == null:
			continue
		var ride := str(info.get("ride", ""))
		if ride != "car" and ride != "boat":
			continue
		var f: String = anim.get(id, {}).get("facing", "down")
		var half := Vector2(46, 22) if f in ["left", "right"] else Vector2(22, 44)
		if ride == "boat":
			half = Vector2(54, 26) if f in ["left", "right"] else Vector2(26, 50)
		if Rect2(shown[id] - half, half * 2.0).has_point(p):
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
	var hand := p + Vector2(9 * side, -24)
	# oltanın açısı: atışta arkadan öne savrulur, çekişte yukarı kalkar
	var forward := Vector2(dir.x * 0.75 + 0.25 * side, -0.85 + dir.y * 0.35).normalized()
	var back := Vector2(-side * 0.45, -1.0).normalized()
	var rod_dir := forward
	var bend := 0.0
	match st:
		"cast":
			var sw := clampf(k / 0.45, 0.0, 1.0)
			rod_dir = back.slerp(forward, ease(sw, 0.4)) if k < 0.45 else forward.rotated(sin(_t * 1.6) * 0.04)
		"bite":
			bend = 16.0 + sin(_t * 26.0) * 5.0
			rod_dir = forward.rotated(sin(_t * 22.0) * 0.06)
		"caught":
			var up := clampf(k / 0.35, 0.0, 1.0)
			rod_dir = forward.slerp(back, up * 0.85)
			bend = 10.0 * (1.0 - up)
		"escaped":
			rod_dir = forward.rotated(-side * clampf(k * 2.0, 0.0, 0.5) * 0.4)
	var rod_len := 54.0
	var tip_straight := hand + rod_dir * rod_len
	# bükülme: uç suya (şamandıraya) doğru çekilir
	var pull := (tp - tip_straight).normalized() * bend
	var tip := tip_straight + pull
	var ctrl := hand + rod_dir * rod_len * 0.6 + pull * 0.35
	var rod := PackedVector2Array()
	for j in 9:
		var u := j / 8.0
		rod.append(hand.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u))
	draw_polyline(rod, Color("#3b1d0a"), 5.0)
	draw_polyline(rod, Color("#a16207"), 3.0)
	draw_line(rod[6], tip, Color("#fde68a"), 1.5)
	draw_circle(hand + rod_dir * 7.0, 4.0, Color("#1f2937"))           # makara
	draw_circle(hand + rod_dir * 7.0 + Vector2(side * 3, 0), 1.6, Color("#e5e7eb"))
	draw_circle(hand, 3.5, Color("#f1c27d"))                            # el
	# şamandıra / balık
	match st:
		"cast":
			var fly := clampf((k - 0.25) / 0.4, 0.0, 1.0)
			var bob := tp + Vector2(0, sin(_t * 3.0) * 2.0)
			if fly < 1.0:
				bob = tip.lerp(tp, fly) + Vector2(0, -sin(fly * PI) * 60.0)
			_draw_line_sag(tip, bob, 22.0 * fly)
			if fly >= 1.0:
				var land := k - 0.65
				if land < 0.6:
					for d in 6:
						var a := TAU * d / 6.0
						draw_circle(tp + Vector2(cos(a) * land * 40.0, -6.0 + sin(a) * land * 14.0 - land * 30.0 + land * land * 60.0), 2.2, Color(0.85, 0.95, 1.0, 0.9 - land))
					draw_arc(tp + Vector2(0, 3), 6.0 + land * 34.0, 0, TAU, 24, Color(1, 1, 1, 0.8 - land), 2.0)
				draw_arc(tp + Vector2(0, 4), 9.0 + fmod(_t * 6.0, 8.0), 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5)
			draw_circle(bob, 6.0, Color("#ef4444"))
			draw_circle(bob + Vector2(0, -2.5), 3.0, Color("#f8fafc"))
			draw_line(bob + Vector2(0, -5), bob + Vector2(0, -10), Color("#111827"), 1.5)
		"bite":
			var dunk := tp + Vector2(sin(_t * 30.0) * 2.5, 5.0 + sin(_t * 12.0) * 3.0)
			_draw_line_sag(tip, dunk, 3.0)
			for r in 3:
				var rr := fmod(_t * 40.0 + r * 9.0, 27.0)
				draw_arc(tp + Vector2(0, 4), 6.0 + rr, 0, TAU, 24, Color(1, 1, 1, 0.6 * (1.0 - rr / 27.0)), 2.0)
			for d in 4:
				var ph := fmod(_t * 3.0 + d * 0.25, 1.0)
				draw_circle(tp + Vector2((d - 1.5) * 7.0, -ph * 22.0 + ph * ph * 22.0), 2.0, Color(0.85, 0.95, 1.0, 1.0 - ph))
			draw_circle(dunk, 3.5, Color("#ef4444"))
			# "!" baloncuğu
			var ex := p + Vector2(0, -92 + sin(_t * 10.0) * 2.0)
			draw_circle(ex, 13, Color("#facc15"))
			draw_circle(ex, 13, Color("#92400e"), false, 2.0)
			draw_rect(Rect2(ex.x - 2, ex.y - 8, 4, 10), Color("#111827"))
			draw_circle(ex + Vector2(0, 6), 2.2, Color("#111827"))
			_text(tp + Vector2(-60, -30), "VURDU!", 16, Color("#facc15"), 120)
		"caught":
			var u := clampf(k / 0.8, 0.0, 1.0)
			var held := p + Vector2(side * 4, -94)
			var fp := tp.lerp(held, ease(u, 0.6)) + Vector2(0, -sin(u * PI) * 80.0)
			draw_line(tip, fp, Color(1, 1, 1, 0.8), 1.3)
			var flap := sin(_t * 30.0) * (0.5 if u < 1.0 else 0.25)
			draw_set_transform(fp, (k * 10.0 if u < 1.0 else flap) , Vector2(1.3, 1.3))
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(0, -7), Vector2(11, 0), Vector2(0, 7)]), Color("#f59e0b"))
			draw_colored_polygon(PackedVector2Array([Vector2(-11, 0), Vector2(-20, -7 + flap * 4.0), Vector2(-20, 7 + flap * 4.0)]), Color("#d97706"))
			draw_line(Vector2(-2, -6), Vector2(2, 6), Color("#b45309"), 1.0)
			draw_circle(Vector2(6, -2), 1.8, Color("#111827"))
			draw_set_transform(Vector2.ZERO)
			if u < 1.0:
				for d in 3:
					draw_circle(fp + Vector2(-8 - d * 9, 6 + d * 7) * Vector2(side, 1), 2.2 - d * 0.5, Color(0.85, 0.95, 1.0, 0.8 - d * 0.2))
			else:
				for d in 4:
					var a := _t * 4.0 + d * TAU / 4.0
					draw_circle(held + Vector2(cos(a), sin(a)) * 22.0, 2.0, Color("#fde68a"))
			if k < 0.6:
				draw_arc(tp, 8.0 + k * 40.0, 0, TAU, 24, Color(1, 1, 1, 0.7 - k), 2.0)
		"escaped":
			var fall := clampf(k / 0.8, 0.0, 1.0)
			_draw_line_sag(tip, tip.lerp(tp, 0.6) + Vector2(0, 30.0 * fall), 30.0)
			if k < 0.8:
				draw_arc(tp, 6.0 + k * 30.0, 0, TAU, 24, Color(1, 1, 1, 0.7 - k * 0.8), 2.0)
			_text(tp + Vector2(-60, -24 - k * 20.0), "kaçtı...", 14, Color(0.85, 0.85, 0.9, 1.0 - fall), 120)


func _draw_line_sag(a: Vector2, b: Vector2, sag: float) -> void:
	var pts := PackedVector2Array()
	for j in 13:
		var u := j / 12.0
		pts.append(a.lerp(b, u) + Vector2(0, sin(u * PI) * sag))
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.4)

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
			if Map.STAGE.grow(10).intersects(Rect2(fx, fy, 70, 18)):
				continue
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
		if absf(x - Map.FOUNTAIN.x) > 90 and absf(x - Map.CLOCK_TOWER.x) > 60 and not Map.STAGE.grow(40).has_point(Vector2(x, Map.PARK.position.y + 18)):
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
	if _ocean:
		_draw_ocean_world()
		_draw_snow_fx()
		labels.items = _label_queue
		labels.queue_redraw()
		return
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
	_draw_stage()
	_draw_race_track()
	_draw_beach()
	_draw_field()
	_draw_lake()
	_draw_interiors()
	_draw_jail()
	_draw_seabed()
	_draw_mountain()
	_draw_hippodrome()
	_draw_fair()
	_draw_zoo()
	_draw_korsan()
	_draw_ocean_gate()
	_draw_rails()
	_draw_arena()
	_draw_city_extras()
	_draw_holiday()
	_draw_marathon()
	for lp in Map.lamp_positions():
		draw_rect(Rect2(lp.x - 2, lp.y - 34, 4, 34), Color("#374151"))
		draw_circle(lp + Vector2(0, -36), 6, Color("#fde68a") if Env.darkness() > 0.2 else Color("#e5e7eb"))
	for i in Map.PLOT_COUNT:
		_draw_plot(i)
	for b in Map.BUILDINGS:
		_draw_building(b)
	if _mount:
		for b in Map.MOUNTAIN_BUILDINGS:
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
		if info and str(info.get("ride", "")) != "train":
			var a: Dictionary = anim.get(id, {"facing": "down", "moving": false})
			items.append([shown[id].y, "p", [shown[id], info.get("appearance", {}), _name_of(info), false, a.facing, a.moving, str(info.get("ride", "")), info.get("color", Color.WHITE), info]])
	var mine = Net.roster.get(Net.my_id())
	var my_app = mine.get("appearance", {}) if mine else Net.my_appearance
	var my_level: int = int(mine.get("level", 1)) if mine else 1
	var my_col: Color = mine.get("color", Color.WHITE) if mine else Color.WHITE
	if my_ride() != "train":
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
			items.append([st.pos.y + (6.0 if st.get("in_boat", false) else 0.0), "pet", [st, info.pet]])
	if _mount:
		for n in mountain_nature:
			items.append([n[0].y, "mp", n])
		for r in Mountain.rocks:
			items.append([float(r.y), "rock", r])
		var gates := Map.ski_gates()
		for gi in gates.size():
			items.append([gates[gi].y, "gate", [gates[gi], gi]])
		for s in Camp.spots:
			items.append([float(s.y), "spot", s])
		for n in Camp.tents:
			items.append([float(Camp.tents[n].y), "tent", [n, Camp.tents[n]]])
		for fi in Map.CAMPFIRES.size():
			items.append([Map.CAMPFIRES[fi].y, "cfire", fi])
		items.append([Map.TELESCOPE.y, "scope", Map.TELESCOPE])
	elif _room < 0 and not Band.performers_seen().is_empty():
		for k in AUDIENCE.size():
			items.append([AUDIENCE[k][0].y, "aud", k])
	if _room < 0:
		var cs := Detective.active_case()
		if not cs.is_empty():
			for s in cs.suspects:
				items.append([s.pos.y, "susp", s])
	if _fair:
		for b in Map.FAIR_BUILDINGS + Map.ZOO_BUILDINGS + [Map.CINEMA]:
			_draw_building(b)
		for bt in Paint.st.get("bots", []):
			items.append([float(bt.y), "pbot", bt])
		for k in Map.ZOO_PENS:
			for a in _zoo_animals(k):
				items.append([a[0].y, "zooa", [k, a]])
	if _room < 0 and Map.in_south(my_pos):
		for li in Horses.race.get("lanes", []).size():
			var l: Dictionary = Horses.race.lanes[li]
			items.append([Map.hippo_lane_y(li), "rh", [l, li]])
		for k in PADDOCK_HORSES.size():
			items.append([PADDOCK_HORSES[k][0].y, "ph", k])
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
		elif it[1] == "mp":
			_draw_mpine(it[2])
		elif it[1] == "spot":
			_draw_forage(it[2])
		elif it[1] == "susp":
			_draw_suspect(it[2])
		elif it[1] == "zooa":
			_draw_zoo_animal(it[2][0], it[2][1])
		elif it[1] == "tent":
			_draw_tent(it[2][0], it[2][1])
		elif it[1] == "cfire":
			_draw_campfire(it[2])
		elif it[1] == "scope":
			_draw_telescope(it[2])
		elif it[1] == "rh":
			_draw_race_horse(it[2][0], it[2][1])
		elif it[1] == "ph":
			var ph: Array = PADDOCK_HORSES[it[2]]
			_draw_horse(ph[0] + Vector2(sin(_t * 0.3 + it[2]) * 30.0, 0), "right" if cos(_t * 0.3 + it[2]) > 0 else "left", true, Horses.COLORS[ph[1]])
		elif it[1] == "rock":
			_draw_rock(it[2])
		elif it[1] == "gate":
			_draw_gate(it[2][0], it[2][1])
		elif it[1] == "aud":
			var ad: Array = AUDIENCE[it[2]]
			Avatar.draw(self, ad[0], ad[1], "up", 0 if fmod(_t * 2.0 + it[2], 2.0) < 1.0 else 1)
		elif it[1] == "fire":
			_draw_fire(Vector2(float(it[2].x), float(it[2].y)), float(it[2].hp))
		elif it[1] == "pax":
			_draw_passenger(it[2])
		elif it[1] == "sm":
			_draw_snowman(Vector2(float(it[2].x), float(it[2].y)), int(it[2].get("style", 0)))
		elif it[1] == "pet":
			_draw_pet(it[2][0], it[2][1])
		elif it[1] == "pbot":
			_draw_paint_bot(it[2])
		else:
			var a: Array = it[2]
			_draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	_draw_sky()
	_draw_fx()
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
	draw_colored_polygon(_ellipse(Map.LAKE.grow(-30)), Color("#2a78b8"))
	var c := Map.LAKE.get_center()
	var hs := Map.LAKE.size / 2.0 * Map.LAKE_DEEP_K
	draw_colored_polygon(_ellipse(Rect2(c - hs, hs * 2.0)), Color("#1e5f99"))          # derin orta (kayıkla)
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
	_draw_moored_kayik()


func _draw_building(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.22))
	draw_texture_rect(BUILDING_TEX[b.type], r, false)
	# Tabela SVG'de boş bırakıldı (eski binalarda y=86..118, yenilerde sign_y).
	_text(r.position + Vector2(0, float(b.get("sign_y", 110))), U.upper_tr(b.label), 22, Color.WHITE, r.size.x)
	if b.type in ["teleferik", "teleferik_dag"]:
		_draw_cable(r, b.type == "teleferik")


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
	elif Farm.is_ranch(p):
		_draw_ranch(r, p)
		level = -1
	if Biz.is_biz(p) and level >= 1:
		var b: Dictionary = p.get("biz", {})
		var heights := [0, 116, 126, 146]
		_draw_tex_at(BIZ_TEX[level], Vector2(c.x, c.y + 54), heights[level], Land.TINTS[int(p.get("tint", 0)) % Land.TINTS.size()])
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
			_draw_tex_at(PLOT_TEX[1], Vector2(c.x, c.y + 42), 120, Land.TINTS[int(p.get("tint", 0)) % Land.TINTS.size()])
		2:
			_draw_tex_at(PLOT_TEX[2], Vector2(c.x, c.y + 50), 130, Land.TINTS[int(p.get("tint", 0)) % Land.TINTS.size()])
		3:
			_draw_tex_at(PLOT_TEX[3], Vector2(c.x, c.y + 60), 158, Land.TINTS[int(p.get("tint", 0)) % Land.TINTS.size()])
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
	if n[1] <= 1 or n[1] == 3:
		# rüzgârda hafif salınım (fırtınada daha çok)
		var wind := 0.05 if Env.weather == "storm" else 0.018
		draw_set_transform(p, sin(_t * 1.3 + p.x * 0.013) * wind, Vector2.ONE)
		_draw_tex_at(prop[0], Vector2.ZERO, h, tint)
		draw_set_transform(Vector2.ZERO)
	else:
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
	# iskeleye bağlı kiralık tekneler (dalgada sallanır) ve kiralama tabelası
	for k in Map.MOORED_BOATS.size():
		var bp: Vector2 = Map.MOORED_BOATS[k] + Vector2(0, sin(_t * 1.2 + k) * 3.0)
		draw_line(bp + Vector2(-50, -6), Vector2(Map.PIER.end.x, bp.y - 10), Color("#a16207"), 2)    # halat
		draw_set_transform(bp, sin(_t * 0.9 + k) * 0.04, Vector2.ONE)
		draw_texture_rect(BOAT_TEX, Rect2(-65, -30, 130, 60), false)
		draw_set_transform(Vector2.ZERO)
	var rs: Vector2 = Map.BOAT_RENT_SPOT + Vector2(-70, -10)
	draw_rect(Rect2(rs.x - 3, rs.y - 70, 6, 70), Color("#5b3a1e"))
	draw_rect(Rect2(rs.x - 64, rs.y - 110, 128, 46), Color("#0369a1"))
	draw_rect(Rect2(rs.x - 64, rs.y - 110, 128, 46), Color("#f8fafc"), false, 3)
	_text(Vector2(rs.x - 64, rs.y - 92), "TEKNE KİRALAMA", 13, Color.WHITE, 128, false)
	_text(Vector2(rs.x - 64, rs.y - 74), "%s / %d dk" % [U.money(Garage.RENT_PRICE), int(Garage.RENT_SECONDS / 60.0)], 12, Color("#fde68a"), 128, false)
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


## Ahır: kırmızı ambar, çitli ağıl, dolaşan hayvanlar (konumlar zamana göre, herkeste aynı).
func _draw_ranch(r: Rect2, p: Dictionary) -> void:
	draw_rect(r.grow(-6), Color("#86a35f"))
	var bx := Rect2(r.position.x + 14, r.position.y + 34, 92, 74)
	draw_rect(Rect2(bx.position + Vector2(4, 6), bx.size), Color(0, 0, 0, 0.2))
	draw_rect(bx, Color("#b91c1c"))
	draw_colored_polygon(PackedVector2Array([bx.position + Vector2(-6, 0), bx.position + Vector2(bx.size.x + 6, 0), bx.position + Vector2(bx.size.x / 2, -26)]), Color("#7f1d1d"))
	draw_rect(Rect2(bx.position.x + 30, bx.end.y - 40, 32, 40), Color("#fef3c7"))
	draw_line(bx.position + Vector2(30, bx.size.y - 40), bx.position + Vector2(62, bx.size.y), Color("#b91c1c"), 3)
	draw_line(bx.position + Vector2(62, bx.size.y - 40), bx.position + Vector2(30, bx.size.y), Color("#b91c1c"), 3)
	var pen := Rect2(r.position.x + 120, r.position.y + 40, r.size.x - 134, r.size.y - 56)
	draw_rect(pen, Color("#a3b86c"))
	draw_rect(pen, Color("#78350f"), false, 3)
	for x in range(int(pen.position.x), int(pen.end.x), 22):
		draw_line(Vector2(x, pen.position.y - 6), Vector2(x, pen.position.y + 4), Color("#78350f"), 2)
	var animals: Array = p.get("ranch", {}).get("animals", [])
	var now := Land.server_now()
	for k in animals.size():
		var a: Dictionary = animals[k]
		var seed_v := float(k * 37 + int(r.position.x))
		var ap := pen.position + Vector2(18 + fposmod(seed_v * 13.0 + sin(_t * 0.4 + k) * 30.0, pen.size.x - 36), 16 + fposmod(seed_v * 7.0 + cos(_t * 0.3 + k * 2.0) * 18.0, pen.size.y - 30))
		var hungry := float(a.fed) < now
		match str(a.k):
			"chicken":
				draw_circle(ap, 6, Color("#f8fafc"))
				draw_circle(ap + Vector2(5, -5), 3.5, Color("#f8fafc"))
				draw_circle(ap + Vector2(6, -8), 1.6, Color("#ef4444"))
				draw_colored_polygon(PackedVector2Array([ap + Vector2(8, -5), ap + Vector2(11, -4), ap + Vector2(8, -3)]), Color("#f59e0b"))
			"cow":
				draw_rect(Rect2(ap - Vector2(13, 8), Vector2(26, 15)), Color("#f8fafc"))
				draw_circle(ap + Vector2(-5, -2), 4, Color("#111827"))
				draw_circle(ap + Vector2(6, 3), 3, Color("#111827"))
				draw_rect(Rect2(ap + Vector2(12, -10), Vector2(9, 9)), Color("#f8fafc"))
				draw_circle(ap + Vector2(18, -4), 2.5, Color("#fda4af"))
				for lx in [-10, -4, 6, 11]:
					draw_line(ap + Vector2(lx, 7), ap + Vector2(lx, 12), Color("#111827"), 2)
			"sheep":
				for c in [Vector2(-6, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3)]:
					draw_circle(ap + c, 6, Color("#f5f5f4"))
				draw_circle(ap + Vector2(10, -3), 4, Color("#44403c"))
		if hungry:
			_text(ap + Vector2(-20, -16), "!", 14, Color("#fca5a5"), 40)
		elif Farm.animal_ready(a, now) > 0:
			draw_circle(ap + Vector2(0, -16 + sin(_t * 3.0 + k) * 2.0), 3.5, Color("#facc15"))
	_text(Vector2(r.position.x, r.position.y + 26), "AHIR", 15, Color("#fde68a"), r.size.x)


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


## Deniz tabanı (dalış): su, ışık huzmeleri, kum, yosun, mercan, balıklar, batık, istiridyeler.
func _draw_seabed() -> void:
	var b: Rect2 = Map.SEA_BED
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200).intersects(b):
		return
	draw_rect(b, Color("#0e5a7a"))
	draw_rect(Rect2(b.position.x, b.position.y, b.size.x, 260), Color(0.2, 0.55, 0.75, 0.35))
	for k in 9:
		var x := b.position.x + 150 + k * 310 + sin(_t * 0.3 + k) * 30.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, b.position.y), Vector2(x + 70, b.position.y), Vector2(x + 220, b.end.y), Vector2(x + 90, b.end.y)]), Color(0.7, 0.9, 1.0, 0.06))
	var floor_y := b.end.y - 170
	var sand := PackedVector2Array()
	for i in 71:
		sand.append(Vector2(b.position.x + i * 40.0, floor_y + sin(i * 0.7) * 14.0))
	sand.append(b.end)
	sand.append(Vector2(b.position.x, b.end.y))
	draw_colored_polygon(sand, Color("#c8b27a"))
	for k in 60:
		var x := b.position.x + fmod(k * 173.0, b.size.x)
		var base := Vector2(x, floor_y + 10 + fmod(k * 37.0, 120.0))
		if k % 3 == 0:
			var sway := sin(_t * 1.5 + k) * 10.0
			draw_polyline(PackedVector2Array([base, base + Vector2(sway * 0.5, -30), base + Vector2(sway, -60)]), Color("#15803d"), 4)
		elif k % 3 == 1:
			var col: Color = [Color("#f472b6"), Color("#fb923c"), Color("#a78bfa"), Color("#f87171")][k % 4]
			draw_circle(base + Vector2(0, -10), 12, col)
			draw_circle(base + Vector2(-10, -18), 8, col.lightened(0.2))
			draw_circle(base + Vector2(9, -20), 7, col.darkened(0.1))
		else:
			draw_circle(base, 10, Color("#78716c"))
	var w := Map.WRECK
	draw_set_transform(w, -0.18, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-180, -30), Vector2(170, -30), Vector2(130, 40), Vector2(-150, 40)]), Color("#57351f"))
	for x in range(-160, 160, 30):
		draw_line(Vector2(x, -28), Vector2(x + 8, 38), Color("#3f2614"), 2)
	draw_rect(Rect2(-40, -150, 10, 120), Color("#3f2614"))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -140), Vector2(40, -110), Vector2(-30, -80)]), Color(0.85, 0.85, 0.75, 0.5))
	draw_set_transform(Vector2.ZERO)
	_text(w + Vector2(-80, -170), "BATIK GEMİ", 15, Color("#fde68a"), 160)
	for g in 6:
		var cx := b.position.x + fposmod(g * 470.0 + _t * (40.0 + g * 8.0) * (1.0 if g % 2 == 0 else -1.0), b.size.x)
		var cy := b.position.y + 200 + g * 110 + sin(_t * 0.8 + g) * 30.0
		var dir := 1.0 if g % 2 == 0 else -1.0
		for f in 7:
			var fp := Vector2(cx + (f % 3) * 22.0 * dir, cy + int(f / 3.0) * 14.0 + sin(_t * 3.0 + f) * 3.0)
			var col: Color = [Color("#facc15"), Color("#38bdf8"), Color("#fb923c")][g % 3]
			draw_colored_polygon(PackedVector2Array([fp + Vector2(8 * dir, 0), fp + Vector2(-4 * dir, -4), fp + Vector2(-4 * dir, 4)]), col)
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-4 * dir, 0), fp + Vector2(-10 * dir, -4), fp + Vector2(-10 * dir, 4)]), col.darkened(0.2))
	for it in Dive.items:
		var ip := Vector2(float(it.x), float(it.y))
		if it.k == "chest":
			draw_rect(Rect2(ip.x - 20, ip.y - 18, 40, 26), Color("#92400e"))
			draw_rect(Rect2(ip.x - 20, ip.y - 26, 40, 10), Color("#b45309"))
			draw_rect(Rect2(ip.x - 4, ip.y - 18, 8, 8), Color("#facc15"))
			draw_circle(ip + Vector2(0, -36 + sin(_t * 3.0) * 3.0), 3, Color(1, 0.95, 0.5, 0.8))
		else:
			draw_colored_polygon(_ellipse(Rect2(ip.x - 14, ip.y - 8, 28, 16), 16), Color("#a8a29e"))
			draw_arc(ip, 10, PI, TAU, 8, Color("#78716c"), 2)
			if fmod(_t + float(it.id), 4.0) < 1.5:
				draw_circle(ip + Vector2(0, -2), 3.5, Color("#f8fafc"))
	for k in 14:
		var bp := Vector2(b.position.x + fmod(k * 211.0, b.size.x), b.end.y - fmod(_t * 60.0 + k * 77.0, b.size.y))
		draw_arc(bp, 3 + k % 3, 0, TAU, 10, Color(1, 1, 1, 0.35), 1.2)


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
	var boat: bool = st.get("in_boat", false)
	var flying: bool = (pet.kind == "parrot" or pet.kind == "korsan") and not boat
	var frame := int(_t * (10.0 if flying else 8.0)) % 2 if (st.moving or flying) else 0
	if boat:
		p += Vector2(0, sin(_t * 2.2) * 1.5)      # teknede dalgayla sallanır
	elif not flying:
		draw_set_transform(p + Vector2(0, 4), 0, Vector2(1, 0.4))
		draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.2))
	var lift := -26.0 + sin(_t * 3.0) * 3.0 if flying else 0.0
	draw_set_transform(p + Vector2(0, lift), 0, Vector2(-1 if st.facing == "left" else 1, 1))
	var mod := Color.WHITE if pet.get("happy", true) else Color(0.7, 0.7, 0.75)
	draw_texture_rect_region(tex, Rect2(-20, -28, 40, 32), Rect2(frame * 80, 0, 80, 64), mod)
	if pet.kind == "korsan":
		# korsan şapkası ve göz bandı
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -27), Vector2(14, -27), Vector2(10, -36), Vector2(4, -40), Vector2(-2, -36)]), Color("#111827"))
		draw_circle(Vector2(4, -32), 2.0, Color.WHITE)
		draw_line(Vector2(-2, -20), Vector2(12, -24), Color("#111827"), 1.5)
		draw_circle(Vector2(8, -21), 2.6, Color("#111827"))
	draw_set_transform(Vector2.ZERO)
	if not boat:            # teknede adı sahibininkiyle çakışmasın
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


func _draw_vehicle(p: Vector2, ride: String, facing: String, col: Color, vstyle: Dictionary = {}) -> void:
	var ang: float = FACING_ANGLE.get(facing, 0.0)
	match ride:
		"car":
			if int(vstyle.get("car", -1)) >= 0:
				col = Garage.PAINTS[int(vstyle.car) % Garage.PAINTS.size()]
			draw_set_transform(p + Vector2(4, 6), ang, Vector2.ONE)
			draw_rect(Rect2(-46, -24, 92, 48), Color(0, 0, 0, 0.25))
			draw_set_transform(p, ang, Vector2.ONE)
			draw_texture_rect(CAR_BODY, Rect2(-48, -26, 96, 52), false, col)
			draw_texture_rect(CAR_DETAIL, Rect2(-48, -26, 96, 52), false)
			var rims := int(vstyle.get("rims", 0))
			if rims > 0:      # jantlar (tekerlek göbekleri)
				for wp in [Vector2(-28, -24), Vector2(28, -24), Vector2(-28, 24), Vector2(28, 24)]:
					draw_circle(wp, 4.0, Garage.RIM_COLORS[rims])
					draw_circle(wp, 1.6, Color("#374151"))
		"bike":
			var bcol := Color.WHITE
			if int(vstyle.get("bike", -1)) >= 0:
				bcol = Garage.PAINTS[int(vstyle.bike) % Garage.PAINTS.size()].lightened(0.25)
			draw_set_transform(p + Vector2(0, 8), ang, Vector2.ONE)
			draw_texture_rect(BIKE_TEX, Rect2(-32, -12, 64, 24), false, bcol)
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
			_draw_vehicle(p, ride, facing, col, extra.get("vstyle", {}))
			_name(p, -40, pname, name_col, extra)
			return
		"ski":
			_draw_skier(p, app, moving)
			_name(p, -56, pname, name_col, extra)
			return
		"ferris":
			_draw_gondola(p, app, pname, name_col, extra)
			return
		"bumper":
			_draw_bumper_car(p, Color.from_hsv(fmod(absf(float(hash(pname))) * 0.0001, 1.0), 0.7, 0.95), app, facing)
			_name(p, -52, pname, name_col, extra)
			return
		"balloon":
			# gölge yerde; balonun kendisi en üstte çizilir (_draw_sky)
			draw_set_transform(p + Vector2(40, 30), 0, Vector2(1, 0.4))
			draw_circle(Vector2.ZERO, 46, Color(0, 0, 0, 0.18))
			draw_set_transform(Vector2.ZERO)
			return
		"horse":
			_draw_horse(p, facing, moving, Horses.COLORS[int(extra.get("hc", 0)) % Horses.COLORS.size()])
			Avatar.draw(self, p + Vector2(0, -20), app, facing, 0)
			if facing == "up":
				_draw_horse_head_front(p, facing, Horses.COLORS[int(extra.get("hc", 0)) % Horses.COLORS.size()])
			_name(p, -78, pname, name_col, extra)
			return
		"bike":
			_draw_vehicle(p, ride, facing, col, extra.get("vstyle", {}))
			Avatar.draw(self, p, app, facing, [1, 0, 2, 0][int(_t * 8.0) % 4] if moving else 0)
			_name(p, -56, pname, name_col, extra)
			return
		"kayik":
			_draw_kayik(p, facing, moving)
			Avatar.draw(self, p + Vector2(0, -4), app, facing, 0, 1.0, true)
			if str(extra.get("fishing", "")) != "":
				_draw_rod(p + Vector2(0, -4), facing, extra)
			_name(p, -42, pname, name_col, extra)
			return
		"boat":
			_draw_vehicle(p, ride, facing, col, extra.get("vstyle", {}))
			Avatar.draw(self, p + Vector2(0, -6), app, facing, 0, 1.0, true)
			if str(extra.get("fishing", "")) != "":
				_draw_rod(p + Vector2(0, -6), facing, extra)
			_name(p, -44, pname, name_col, extra)
			return
	var swim := Map.in_sea(p) or Map.in_water(p)
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
	if str(extra.get("playing", "")) != "":
		_draw_instrument(p, str(extra.playing), facing)
	if str(extra.get("costume", "")) != "":
		_draw_costume(p, str(extra.costume))
	if extra.get("roast", false):
		_draw_roast_stick(p)
	if Map.SEA_BED.has_point(p):
		draw_rect(Rect2(p.x - 9, p.y - 35, 18, 9), Color(0.6, 0.85, 1.0, 0.6))
		draw_rect(Rect2(p.x - 9, p.y - 35, 18, 9), Color("#facc15"), false, 2)
		draw_rect(Rect2(p.x - 14, p.y - 30, 6, 18), Color("#334155"))
		for k in 3:
			var by := fmod(_t * 50.0 + k * 20.0, 60.0)
			draw_arc(p + Vector2(6 + sin(_t * 4.0 + k) * 3.0, -40 - by), 3, 0, TAU, 8, Color(1, 1, 1, 0.6 - by / 120.0), 1.2)
	if str(extra.get("fishing", "")) != "":
		_draw_rod(p, facing, extra)
	_name(p, -56 + (22 if swim else 0), pname, name_col, extra)


# ================================================================== 1.2: dağ, kayak, sahne

func _ski_move(delta: float) -> void:
	my_facing = "down"
	my_moving = true
	var steer := 0.0
	var v := 1.2
	if panel == null and not hud.is_typing():
		if Settings.held("left"):
			steer -= 1.0
		if Settings.held("right"):
			steer += 1.0
		if Settings.held("down"):
			v = 1.55
		if Settings.held("up"):
			v = 0.7
	var np := _clamp_to_area(my_pos + Vector2(steer * 1.05, v) * SPEED * delta)
	if np.y >= Map.MOUNTAIN.end.y - 21:
		Mountain.ski_stop()
	my_pos = np


func _update_mountain_zone() -> void:
	var mz := {}
	for b in Map.MOUNTAIN_BUILDINGS:
		if b.rect.grow(26).has_point(my_pos):
			mz = {"type": b.type, "label": "Teleferikle şehre dön" if b.type == "teleferik_dag" else b.label}
	if my_pos.distance_to(Map.LIFT) < 110.0 and my_ride() != "ski":
		mz = {"type": "lift", "label": "Telesiyejle zirveye çık ve kay (%s)" % ("kendi kayağınla" if Mountain.has_skis else "kiralık kayak " + U.money(Mountain.SKI_RENT))}
	var best_d := Mountain.HIT_RANGE
	for r in Mountain.rocks:
		var d := my_pos.distance_to(Vector2(float(r.x), float(r.y)))
		if d < best_d:
			best_d = d
			mz = {"type": "rock", "id": int(r.id), "label": "Kayayı kır (basılı tut)" if Mountain.has_pickaxe else "Kaya — kazma Dağ Evi'nde"}
	mz = _camp_zone(mz)
	mz = _rail_zone(mz)
	mz = _detective_zone(mz)
	zone = mz
	var hint := ""
	if my_ride() == "ski":
		var el := Time.get_ticks_msec() / 1000.0 - Mountain.ski_t0 if Mountain.skiing() else 0.0
		hint = "KAYAK  ·  Kapı %d/12  ·  %.1f sn\n%s/%s: dön   %s: hızlan   %s: yavaşla   [%s] bırak" % [Mountain.ski_gate, el,
			Settings.key_name("left"), Settings.key_name("right"), Settings.key_name("down"), Settings.key_name("up"), Settings.key_name("vehicle")]
	elif not mz.is_empty():
		hint = "[%s]  %s" % [Settings.key_name("interact"), mz.label]
	hud.set_hint("" if panel != null else hint)


func _make_mountain_nature() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var m: Rect2 = Map.MOUNTAIN
	var keep_out: Array = [Rect2(m.position.x, Map.RAIL.dag.y - 110.0, m.size.x, 200), Map.QUARRY.grow(40), Map.SLOPE.grow(70), Rect2(Map.LIFT.x - 50, Map.MOUNTAIN_TOP_Y, 100, Map.LIFT.y - Map.MOUNTAIN_TOP_Y + 80), Map.CAMP.grow(30)]
	for b in Map.MOUNTAIN_BUILDINGS:
		keep_out.append(b.rect.grow(60))
	for seg in _mountain_paths():
		keep_out.append(Rect2(seg[0], Vector2.ZERO).expand(seg[1]).grow(50))
	for _k in 700:
		if mountain_nature.size() >= 170:
			break
		var p := Vector2(rng.randf_range(m.position.x + 40, m.end.x - 40), rng.randf_range(Map.MOUNTAIN_TOP_Y + 60, m.end.y - 30))
		var ok := true
		for r in keep_out:
			if r.has_point(p):
				ok = false
				break
		if ok:
			for n in mountain_nature:
				if n[0].distance_to(p) < 70.0:
					ok = false
					break
		if ok:
			mountain_nature.append([p, rng.randf_range(0.8, 1.25)])


## Dağ yolları (teleferik → Dağ Evi → telesiyej, ve maden ocağına).
func _mountain_paths() -> Array:
	return [[Map.MOUNTAIN_SPAWN, Vector2(8800, 2790)], [Vector2(8800, 2790), Vector2(9930, 2780)],
		[Vector2(9930, 2780), Map.LIFT], [Vector2(8500, 2790), Vector2(8500, Map.QUARRY.end.y)]]


func _snowy(y: float) -> bool:
	return Env.season == "winter" or y < Map.SNOW_LINE


func _draw_mountain() -> void:
	var b: Rect2 = Map.MOUNTAIN
	var vsize := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200)
	if not view.intersects(b):
		return
	if mountain_nature.is_empty():
		_make_mountain_nature()
	var winter := Env.season == "winter"
	var grass: Color = (GRASS.get(Env.season, GRASS.spring) as Color).darkened(0.12)
	var snow := Color("#eef3f7")
	draw_rect(b, snow if winter else grass)
	if not winter:
		var edge := PackedVector2Array([b.position])
		for i in 49:
			edge.append(Vector2(b.position.x + i * 50.0, Map.SNOW_LINE + sin(i * 0.9) * 40.0 + cos(i * 0.37) * 30.0))
		edge.append(Vector2(b.end.x, b.position.y))
		draw_colored_polygon(edge, snow)
	# zirveler
	for k in 13:
		var x := b.position.x - 80 + k * 200.0
		var h := 230.0 + float((k * 73) % 120)
		var base_y := Map.MOUNTAIN_TOP_Y + 30
		draw_colored_polygon(PackedVector2Array([Vector2(x - 170, base_y), Vector2(x, base_y - h), Vector2(x + 170, base_y)]), Color("#7b8794"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, base_y - h), Vector2(x + 170, base_y), Vector2(x + 40, base_y)]), Color("#64707d"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 62, base_y - h + 85), Vector2(x, base_y - h), Vector2(x + 62, base_y - h + 85),
			Vector2(x + 25, base_y - h + 70), Vector2(x, base_y - h + 92), Vector2(x - 28, base_y - h + 72)]), Color("#f8fafc"))
	# yollar
	for seg in _mountain_paths():
		draw_line(seg[0], seg[1], Color("#d6c7a1") if not _snowy(seg[0].y) else Color("#cbd5e1"), 34)
		draw_circle(seg[0], 17, Color("#d6c7a1") if not _snowy(seg[0].y) else Color("#cbd5e1"))
	# maden ocağı
	var q: Rect2 = Map.QUARRY
	var qp := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		qp.append(q.get_center() + Vector2(cos(a) * q.size.x * (0.5 + 0.03 * sin(i * 2.1)), sin(a) * q.size.y * (0.5 + 0.03 * cos(i * 1.7))))
	draw_colored_polygon(qp, Color("#8a7a66"))
	for i in 90:
		var pp := q.position + Vector2(float((i * 337) % int(q.size.x)), float((i * 211) % int(q.size.y)))
		if q.grow(-60).has_point(pp):
			draw_circle(pp, 3.0 + float(i % 4), Color("#6f6252"))
	# mağara ağzı ve raylar
	var c: Vector2 = Map.CAVE
	draw_colored_polygon(PackedVector2Array([c + Vector2(-110, 40), c + Vector2(-80, -60), c + Vector2(0, -95), c + Vector2(80, -60), c + Vector2(110, 40)]), Color("#57534e"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-55, 40), c + Vector2(-45, -20), c + Vector2(0, -45), c + Vector2(45, -20), c + Vector2(55, 40)]), Color("#1c1917"))
	draw_rect(Rect2(c.x - 58, c.y - 30, 10, 70), Color("#92400e"))
	draw_rect(Rect2(c.x + 48, c.y - 30, 10, 70), Color("#92400e"))
	draw_rect(Rect2(c.x - 62, c.y - 36, 124, 12), Color("#78350f"))
	for k in 12:
		draw_rect(Rect2(c.x - 22, c.y + 40 + k * 26, 44, 6), Color("#78350f"))
	draw_line(c + Vector2(-14, 40), c + Vector2(-14, 352), Color("#9ca3af"), 3)
	draw_line(c + Vector2(14, 40), c + Vector2(14, 352), Color("#9ca3af"), 3)
	draw_rect(Rect2(c.x - 26, c.y + 250, 52, 34), Color("#57534e"))
	draw_rect(Rect2(c.x - 22, c.y + 244, 44, 12), Color("#a8a29e"))
	_text(Vector2(c.x - 100, c.y - 104), "MADEN OCAĞI", 18, Color("#fde68a"), 200)
	# kayak pisti
	var sl: Rect2 = Map.SLOPE
	draw_rect(sl, Color("#f8fafc"))
	for y in range(int(sl.position.y) + 10, int(sl.end.y), 14):
		draw_line(Vector2(sl.position.x + 8, y), Vector2(sl.end.x - 8, y), Color(0.82, 0.88, 0.94, 0.5), 1)
	for y in range(int(sl.position.y), int(sl.end.y), 120):
		for x in [sl.position.x, sl.end.x]:
			draw_rect(Rect2(x - 3, y - 18, 6, 22), Color("#2563eb"))
	_text(Vector2(sl.position.x, sl.position.y + 6), "KAYAK PİSTİ — START", 18, Color("#1e3a8a"), sl.size.x)
	var fy := Map.SKI_FINISH_Y
	for k in int(sl.size.x / 20.0):
		draw_rect(Rect2(sl.position.x + k * 20, fy, 20, 10), Color.BLACK if k % 2 == 0 else Color.WHITE)
		draw_rect(Rect2(sl.position.x + k * 20, fy + 10, 20, 10), Color.WHITE if k % 2 == 0 else Color.BLACK)
	_text(Vector2(sl.position.x, fy + 44), "FİNİŞ", 18, Color("#1e3a8a"), sl.size.x)
	# telesiyej: direkler, halat, sandalyeler
	var top := Vector2(Map.LIFT.x, Map.SKI_TOP.y)
	for y in range(int(top.y), int(Map.LIFT.y) + 1, 300):
		draw_rect(Rect2(top.x - 5, y - 70, 10, 74), Color("#475569"))
		draw_rect(Rect2(top.x - 26, y - 74, 52, 6), Color("#334155"))
	draw_line(Vector2(top.x - 22, top.y - 70), Vector2(top.x - 22, Map.LIFT.y - 70), Color("#1f2937"), 2)
	draw_line(Vector2(top.x + 22, top.y - 70), Vector2(top.x + 22, Map.LIFT.y - 70), Color("#1f2937"), 2)
	var span := Map.LIFT.y - top.y
	for k in 14:
		var t := fmod(_t * 40.0 + k * span / 7.0, span * 2.0)
		var up := t < span
		var cy := Map.LIFT.y - 70 - t if up else top.y - 70 + (t - span)
		var cx := top.x + (-22 if up else 22)
		draw_line(Vector2(cx, cy), Vector2(cx, cy + 22), Color("#1f2937"), 2)
		draw_rect(Rect2(cx - 10, cy + 20, 20, 6), Color("#dc2626"))
	for hp in [top, Map.LIFT]:
		draw_rect(Rect2(hp.x - 40, hp.y - 50, 80, 56), Color("#7c2d12"))
		draw_colored_polygon(PackedVector2Array([hp + Vector2(-48, -48), hp + Vector2(0, -80), hp + Vector2(48, -48)]), Color("#e2e8f0"))
	_text(Vector2(Map.LIFT.x - 80, Map.LIFT.y + 30), "TELESİYEJ", 16, Color("#1e293b"), 160)
	# kamp alanı: açıklık, kütükler
	var cp: Rect2 = Map.CAMP
	var camp_poly := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		camp_poly.append(cp.get_center() + Vector2(cos(a) * cp.size.x * (0.52 + 0.03 * sin(i * 1.9)), sin(a) * cp.size.y * (0.52 + 0.03 * cos(i * 2.3))))
	draw_colored_polygon(camp_poly, Color("#c9b98a") if not winter else Color("#dfe7ec"))
	for f in Map.CAMPFIRES:
		for k in 3:
			var a := TAU * k / 3.0 + 0.4
			var lp: Vector2 = f + Vector2(cos(a) * 62.0, sin(a) * 34.0)
			draw_rect(Rect2(lp.x - 22, lp.y - 7, 44, 14), Color("#78350f"))
			draw_circle(lp + Vector2(-22, 0), 7, Color("#a16207"))
			draw_circle(lp + Vector2(22, 0), 7, Color("#a16207"))
	_text(Vector2(cp.position.x, cp.position.y + 4), "KAMP ALANI", 16, Color("#fde68a"), cp.size.x)
	# ateş böcekleri (gece ormanda)
	if Env.darkness() > 0.4:
		for i in 40:
			var fp := Vector2(b.position.x + fmod(i * 233.7, b.size.x), Map.SNOW_LINE + fmod(i * 157.3, b.end.y - Map.SNOW_LINE))
			fp += Vector2(sin(_t * 0.7 + i) * 30.0, cos(_t * 0.9 + i * 1.3) * 20.0)
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + i * 2.1)
			draw_circle(fp, 2.2, Color(1.0, 0.95, 0.4, glow))
			draw_circle(fp, 6.0, Color(1.0, 0.95, 0.4, glow * 0.15))
	# kayan yıldız
	if not Camp.star.is_empty():
		var sk := (Time.get_ticks_msec() / 1000.0 - float(Camp.star.t0)) / 1.4
		if sk < 1.0:
			var a0 := view.position + Vector2(float(Camp.star.a), float(Camp.star.b)) * view.size
			var b0 := a0 + Vector2(view.size.x * 0.35, view.size.y * 0.25)
			var head := a0.lerp(b0, sk)
			draw_line(a0.lerp(b0, maxf(0.0, sk - 0.3)), head, Color(1, 1, 1, 0.85), 4.0)
			draw_circle(head, 5.0, Color.WHITE)
	# kar yağışı (karlı bölgede hafif)
	if view.position.y < Map.SNOW_LINE + 300 or winter:
		for i in 70:
			var sx := view.position.x + fmod(i * 97.3 + sin(_t * 0.6 + i) * 30.0, view.size.x)
			var sy := view.position.y + fmod(i * 53.7 + _t * (40.0 + (i % 5) * 10.0), view.size.y)
			draw_circle(Vector2(sx, sy), 1.6 + (i % 3) * 0.6, Color(1, 1, 1, 0.75))


func _draw_mpine(n: Array) -> void:
	var p: Vector2 = n[0]
	var h: float = 86.0 * float(n[1])
	draw_set_transform(p + Vector2(0, -2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, h * 0.3, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	_draw_tex_at(PROPS[1][0], p, h, Color(0.85, 0.92, 0.88) if _snowy(p.y) else Color.WHITE)
	if _snowy(p.y):
		draw_set_transform(p + Vector2(0, -h * 0.82), 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, h * 0.2, Color(1, 1, 1, 0.92))
		draw_set_transform(Vector2.ZERO)
		draw_set_transform(p + Vector2(0, -h * 0.45), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, h * 0.28, Color(1, 1, 1, 0.75))
		draw_set_transform(Vector2.ZERO)


func _draw_rock(r: Dictionary) -> void:
	var p := Vector2(float(r.x), float(r.y))
	var k := str(r.k)
	var base: Color = {"tas": Color("#78716c"), "maden": Color("#57534e"), "kristal": Color("#4c1d95")}.get(k, Color("#78716c"))
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	var pts := PackedVector2Array([p + Vector2(-30, 0), p + Vector2(-26, -26), p + Vector2(-6, -40), p + Vector2(18, -34), p + Vector2(30, -12), p + Vector2(28, 0)])
	draw_colored_polygon(pts, base)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -40), p + Vector2(18, -34), p + Vector2(30, -12), p + Vector2(4, -18)]), base.lightened(0.18))
	match k:
		"maden":
			for s in [Vector2(-12, -20), Vector2(8, -26), Vector2(16, -10), Vector2(-20, -8)]:
				draw_circle(p + s, 4, Color("#fbbf24") if int(s.x) % 2 == 0 else Color("#e5e7eb"))
		"kristal":
			for s in [[Vector2(-10, -30), 0.2], [Vector2(6, -36), -0.15], [Vector2(16, -22), 0.35]]:
				var c: Vector2 = p + s[0]
				var a: float = s[1]
				draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 8).rotated(a), c + Vector2(0, -14).rotated(a), c + Vector2(5, 8).rotated(a)]),
					Color(0.75, 0.6, 1.0, 0.95) if fmod(_t + s[0].x, 2.0) < 1.6 else Color(0.95, 0.9, 1.0))
	var max_hp := int(Mountain.ROCKS.get(k, [0, 3])[1])
	for i in max_hp - int(r.hp):
		draw_line(p + Vector2(-14 + i * 9, -34), p + Vector2(-8 + i * 9, -14), Color("#1c1917"), 2)


func _draw_gate(g: Vector2, i: int) -> void:
	var col := Color("#dc2626") if i % 2 == 0 else Color("#2563eb")
	if Mountain.skiing() and i < Mountain.ski_gate:
		col = col.lerp(Color(0.8, 0.8, 0.8), 0.6)
	var hw := Map.SKI_GATE_W / 2.0
	for x in [g.x - hw, g.x + hw]:
		draw_rect(Rect2(x - 2, g.y - 46, 4, 48), Color("#374151"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, g.y - 46), Vector2(x + (14 if x < g.x else -14), g.y - 38), Vector2(x, g.y - 30)]), col)
	draw_line(Vector2(g.x - hw, g.y), Vector2(g.x + hw, g.y), Color(col, 0.25), 2)
	_text(Vector2(g.x - 20, g.y - 52), str(i + 1), 13, col, 40)


func _draw_skier(p: Vector2, app: Dictionary, moving: bool) -> void:
	draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
	if moving:
		for k in 4:
			var sp := fmod(_t * 3.0 + k * 0.25, 1.0)
			draw_circle(p + Vector2(-8 + k * 5, -2 - sp * 26), 3.0 * (1.0 - sp), Color(1, 1, 1, 0.8 * (1.0 - sp)))
	for dx in [-7.0, 7.0]:
		draw_line(p + Vector2(dx, -14), p + Vector2(dx, 24), Color("#dc2626"), 4)
		draw_line(p + Vector2(dx - 1, 22), p + Vector2(dx + 1, 26), Color("#7f1d1d"), 3)
	Avatar.draw(self, p, app, "down", 0)
	for dx in [-16.0, 16.0]:
		draw_line(p + Vector2(dx * 0.7, -22), p + Vector2(dx, 14), Color("#1f2937"), 2)
		draw_circle(p + Vector2(dx, 12), 3, Color("#1f2937"), false, 1.5)


func _draw_instrument(p: Vector2, inst: String, facing: String) -> void:
	var bob := sin(_t * 9.0) * 1.5
	match inst:
		"gitar":
			var c := p + Vector2(4, -16 + bob * 0.3)
			draw_line(c + Vector2(4, -2), c + Vector2(-20, -16), Color("#78350f"), 4)
			draw_set_transform(c, 0.5, Vector2(1, 0.75))
			draw_circle(Vector2(6, 2), 10, Color("#b45309"))
			draw_circle(Vector2(6, 2), 3.5, Color("#1c1917"))
			draw_set_transform(Vector2.ZERO)
		"davul":
			var d := p + Vector2(0, 10)
			draw_circle(d + Vector2(0, 4), 14, Color("#1d4ed8"))
			draw_circle(d + Vector2(0, 4), 10, Color("#e5e7eb"))
			draw_set_transform(d + Vector2(-20, -10), 0, Vector2(1, 0.45))
			draw_circle(Vector2.ZERO, 10, Color("#fbbf24"))
			draw_set_transform(Vector2.ZERO)
			draw_line(p + Vector2(-8, -18), p + Vector2(-18, -8 + bob * 2.0), Color("#fef3c7"), 2)
			draw_line(p + Vector2(8, -18), p + Vector2(16, -8 - bob * 2.0), Color("#fef3c7"), 2)
		"klavye":
			var k := p + Vector2(-22, -8)
			draw_rect(Rect2(k.x - 2, k.y + 6, 4, 18), Color("#374151"))
			draw_rect(Rect2(k.x + 42, k.y + 6, 4, 18), Color("#374151"))
			draw_rect(Rect2(k.x, k.y, 44, 10), Color("#111827"))
			for i in 8:
				draw_rect(Rect2(k.x + 2 + i * 5, k.y + 3, 4, 6), Color.WHITE)
	# yükselen notalar
	for i in 3:
		var t := fmod(_t * 0.8 + i * 0.33, 1.0)
		var np := p + Vector2(-14 + i * 14 + sin(_t * 3.0 + i) * 6.0, -64 - t * 46.0)
		_text(np - Vector2(10, 0), "♪" if i % 2 == 0 else "♫", 18, Color(["#f472b6", "#facc15", "#60a5fa"][i]).darkened(0.0) * Color(1, 1, 1, 1.0 - t), 20, false)


func _draw_stage() -> void:
	var s: Rect2 = Map.STAGE
	var live := not Band.performers_seen().is_empty()
	var night := Env.darkness() > 0.3
	# arka duvar ve ışık dizisi
	var wall := Rect2(s.position.x + 10, s.position.y - 46, s.size.x - 20, 46)
	draw_rect(wall, Color("#1f2937"))
	draw_rect(wall, Color("#111827"), false, 3)
	_text(Vector2(wall.position.x, wall.position.y + 26), "PARK SAHNESİ", 16, Color("#facc15"), wall.size.x)
	for i in 12:
		var on := live or night
		var col := Color.from_hsv(fmod(i * 0.13 + (_t * 0.3 if live else 0.0), 1.0), 0.7, 1.0) if on else Color("#4b5563")
		draw_circle(Vector2(wall.position.x + 8 + i * (wall.size.x - 16) / 11.0, wall.position.y + 6), 3.5, col)
	# platform
	draw_rect(Rect2(s.position + Vector2(0, 8), s.size), Color(0, 0, 0, 0.25))
	draw_rect(s, Color("#8b5a2b"))
	for x in range(int(s.position.x) + 24, int(s.end.x), 24):
		draw_line(Vector2(x, s.position.y), Vector2(x, s.end.y), Color("#6b4423"), 1)
	draw_rect(Rect2(s.position.x, s.end.y - 8, s.size.x, 8), Color("#5c3a1a"))
	# hoparlörler
	for x in [s.position.x - 6, s.end.x - 22]:
		draw_rect(Rect2(x, s.position.y - 30, 28, 44), Color("#111827"))
		draw_circle(Vector2(x + 14, s.position.y - 16), 8 + (sin(_t * 18.0) * 1.2 if live else 0.0), Color("#374151"))
		draw_circle(Vector2(x + 14, s.position.y + 4), 5, Color("#374151"))
	# spot ışıkları
	if live:
		for i in 3:
			var from := Vector2(wall.position.x + 30 + i * (wall.size.x - 60) / 2.0, wall.position.y)
			var to := Vector2(s.position.x + 40 + fmod(_t * 60.0 + i * 70.0, s.size.x - 80), s.end.y)
			var col := Color.from_hsv(fmod(_t * 0.2 + i * 0.33, 1.0), 0.6, 1.0, 0.18)
			draw_colored_polygon(PackedVector2Array([from, to + Vector2(-30, 0), to + Vector2(30, 0)]), col)


## Teleferik halatı ve gidip gelen kabin (şehirde kuzeydoğuya, dağda yukarı doğru uzanır).
func _draw_cable(r: Rect2, city: bool) -> void:
	var a := r.position + Vector2(r.size.x * 0.5, 8)
	var dir := Vector2(0.12, -1.0).normalized() if city else Vector2(0.3, 1.0).normalized()      # dağda şehre doğru aşağı iner
	var length := 560.0
	# halat uzaklaştıkça solar (dağlara / şehre doğru gider)
	for k in 14:
		var u0 := k / 14.0
		var u1 := (k + 1) / 14.0
		var al := clampf(1.6 - u1 * 1.6, 0.0, 1.0)
		draw_line(a + dir * length * u0, a + dir * length * u1, Color(0.12, 0.16, 0.22, al), 3)
		draw_line(a + dir * length * u0 + Vector2(12, 3), a + dir * length * u1 + Vector2(12, 3), Color(0.22, 0.25, 0.32, al), 2)
	for k in 2:
		var u := fmod(_t * 0.06 + k * 0.5, 1.0)
		var up := k == 0
		var c := a + dir * length * (u if up else 1.0 - u) + (Vector2.ZERO if up else Vector2(12, 3))
		var al := clampf(1.6 - (u if up else 1.0 - u) * 1.6, 0.0, 1.0)
		if al <= 0.02:
			continue
		draw_line(c, c + Vector2(0, 16), Color(0.12, 0.16, 0.22, al), 2)
		draw_rect(Rect2(c.x - 16, c.y + 14, 32, 24), Color(0.86, 0.15, 0.15, al))
		draw_rect(Rect2(c.x - 12, c.y + 18, 24, 9), Color(0.73, 0.9, 0.99, al))



# ================================================================== 1.3: animasyon efektleri

func add_fx(k: String, pos: Vector2, dur: float, d: Dictionary = {}) -> void:
	if fx.size() > 260:
		return
	fx.append({"k": k, "pos": pos, "t0": _t, "dur": dur, "d": d})


func _fx_tick(delta: float) -> void:
	var i := fx.size() - 1
	while i >= 0:
		if _t - float(fx[i].t0) > float(fx[i].dur):
			fx.remove_at(i)
		i -= 1
	# hareket eden araçların izi: arabada egzoz, teknede köpük
	_trail_acc += delta
	if _trail_acc < 0.09:
		return
	_trail_acc = 0.0
	var movers: Array = []
	var me = Net.roster.get(Net.my_id())
	if me and my_moving:
		movers.append([my_pos, my_facing, str(me.get("ride", ""))])
	for id in shown:
		var info = Net.roster.get(id)
		var a: Dictionary = anim.get(id, {})
		if info and a.get("moving", false):
			movers.append([shown[id], str(a.get("facing", "down")), str(info.get("ride", ""))])
	for m in movers:
		var back: Vector2 = {"left": Vector2.RIGHT, "right": Vector2.LEFT, "up": Vector2.DOWN, "down": Vector2.UP}.get(m[1], Vector2.UP)
		match m[2]:
			"car":
				add_fx("smoke", m[0] + back * 44.0 + Vector2(randf_range(-4, 4), 4), 0.7)
			"boat":
				add_fx("wake", m[0] + back * 46.0 + Vector2(randf_range(-6, 6), 6), 1.2)
			"horse":
				add_fx("dust", m[0] + back * 30.0 + Vector2(randf_range(-6, 6), 12), 0.5)


var _trash_seen := {}


## Çöp torbası alınınca küçük bir toz bulutu.
func _fx_trash() -> void:
	if Work.trash.size() == _trash_seen.size():
		return
	var cur := {}
	for t in Work.trash:
		cur[int(t.id)] = Vector2(float(t.x), float(t.y))
	for id in _trash_seen:
		if not cur.has(id):
			add_fx("chips", _trash_seen[id], 0.5)
	_trash_seen = cur


func _bed_rect(r: Rect2, k: int) -> Rect2:
	var bw := 70.0
	var bh := 52.0
	var x0 := r.position.x + (r.size.x - 3 * bw - 2 * 12.0) / 2.0
	return Rect2(x0 + (k % 3) * (bw + 12.0), r.position.y + 42 + int(k / 3.0) * (bh + 10.0), bw, bh)


## Tarhlar değişince: ekim (toprak), sulama (damla), hasat (ürün fırlar).
func _fx_from_plots() -> void:
	for i in mini(Land.view.size(), Map.PLOT_COUNT):
		var p: Dictionary = Land.view[i]
		if not Farm.is_farm(p) or not p.get("farm") is Dictionary:
			continue
		var beds: Array = p.farm.get("beds", [])
		for k in beds.size():
			var b: Dictionary = beds[k]
			var key := "%d:%d" % [i, k]
			var now_s := [str(b.get("c", "")), bool(b.get("w", false)), float(b.get("t", 0.0))]
			var old = _beds_seen.get(key)
			_beds_seen[key] = now_s
			if old == null:
				continue
			var c := _bed_rect(Map.plot_rect(i), k).get_center()
			if old[0] == "" and now_s[0] != "":
				add_fx("dirt", c, 0.7)
			elif old[0] != "" and now_s[0] == "":
				var col := Color(Farm.CROPS.get(old[0], {}).get("color", "#22c55e"))
				add_fx("harvest", c, 1.0, {"col": col})
			elif not old[1] and now_s[1]:
				add_fx("water", c, 0.9)


## Kaya canı azalınca: taş kıymıkları ve en yakındaki oyuncuda kazma savurma.
func _fx_from_rocks() -> void:
	var cur := {}
	for r in Mountain.rocks:
		cur[int(r.id)] = [int(r.hp), Vector2(float(r.x), float(r.y))]
	for id in _rocks_seen:
		var old: Array = _rocks_seen[id]
		var hit := not cur.has(id) or int(cur[id][0]) < int(old[0])
		if not hit:
			continue
		var rp: Vector2 = old[1]
		add_fx("chips", rp + Vector2(0, -18), 0.6 if cur.has(id) else 0.9, {"big": not cur.has(id)})
		var best := my_pos
		var bd := my_pos.distance_to(rp)
		for pid in shown:
			var dd: float = shown[pid].distance_to(rp)
			if dd < bd:
				bd = dd
				best = shown[pid]
		if bd < 120.0:
			add_fx("pick", best, 0.35, {"side": 1.0 if rp.x >= best.x else -1.0})
	_rocks_seen = cur


func _fx_from_roster() -> void:
	var me = Net.roster.get(Net.my_id())
	if me == null:
		return
	var m := int(me.get("money", 0))
	if _last_money >= 0 and m != _last_money:
		add_fx("money", my_pos + Vector2(0, -70), 1.4, {"v": m - _last_money})
	_last_money = m
	var lv := int(me.get("level", 1))
	if _last_level > 0 and lv > _last_level:
		add_fx("level", my_pos, 1.6)
	_last_level = lv


func _fx_from_sheet() -> void:
	var items: Dictionary = Rpg.sheet.get("items", {})
	for k in Kitchen.RECIPES:
		var n := int(items.get(k, 0))
		if n > int(_dishes_seen.get(k, n)):
			add_fx("steam", my_pos + Vector2(0, -30), 1.6)
		_dishes_seen[k] = n


func _draw_fx() -> void:
	for f in fx:
		var u: float = clampf((_t - float(f.t0)) / float(f.dur), 0.0, 1.0)
		var p: Vector2 = f.pos
		match str(f.k):
			"smoke":
				draw_circle(p + Vector2(0, -u * 14.0), 4.0 + u * 8.0, Color(0.55, 0.55, 0.6, 0.45 * (1.0 - u)))
			"harpoon":
				var to: Vector2 = f.d.get("to", p)
				var hp := p.lerp(to, u)
				var dir := (to - p).normalized()
				draw_line(p, hp, Color("#d6d3d1", 0.7), 1.5)
				draw_line(hp - dir * 26.0, hp, Color("#78350f"), 4.0)
				draw_colored_polygon(PackedVector2Array([hp + dir * 10.0, hp + dir.orthogonal() * 6.0, hp - dir.orthogonal() * 6.0]), Color("#9ca3af"))
			"wake":
				draw_set_transform(p, 0, Vector2(1, 0.45))
				draw_arc(Vector2.ZERO, 6.0 + u * 26.0, 0, TAU, 20, Color(1, 1, 1, 0.55 * (1.0 - u)), 2.0)
				draw_set_transform(Vector2.ZERO)
			"dust":
				draw_circle(p + Vector2(0, -u * 8.0), 3.0 + u * 7.0, Color(0.78, 0.68, 0.5, 0.5 * (1.0 - u)))
			"dirt":
				for j in 7:
					var a := -PI * (0.15 + 0.7 * j / 6.0)
					var q := p + Vector2(cos(a), sin(a)) * 30.0 * u + Vector2(0, 40.0 * u * u)
					draw_circle(q, 3.0, Color(0.4, 0.26, 0.13, 1.0 - u))
			"water":
				for j in 8:
					var x := -24.0 + j * 7.0
					var drop := fmod(u * 1.6 + j * 0.13, 1.0)
					draw_line(p + Vector2(x, -40 + drop * 40.0), p + Vector2(x - 1, -34 + drop * 40.0), Color(0.55, 0.8, 1.0, 1.0 - u), 2.0)
				draw_arc(p + Vector2(0, 6), 8.0 + u * 22.0, 0, TAU, 20, Color(0.6, 0.85, 1.0, 0.7 * (1.0 - u)), 2.0)
			"harvest":
				var col: Color = f.d.get("col", Color("#22c55e"))
				for j in 6:
					var a := -PI * (0.2 + 0.6 * j / 5.0)
					var q := p + Vector2(cos(a) * 36.0 * u, sin(a) * 56.0 * u + 70.0 * u * u)
					draw_circle(q, 5.0, Color(col, 1.0 - u * 0.8))
					draw_circle(q + Vector2(-2, -2), 1.6, Color(1, 1, 1, 0.7 * (1.0 - u)))
				for j in 3:
					var q2 := p + Vector2(-12 + j * 12, -10 - u * 40.0)
					draw_colored_polygon(PackedVector2Array([q2, q2 + Vector2(5, -3), q2 + Vector2(2, 4)]), Color(0.2, 0.6, 0.2, 1.0 - u))
			"chips":
				var n := 10 if f.d.get("big", false) else 6
				for j in n:
					var a := -PI * (0.1 + 0.8 * j / float(n - 1))
					var q := p + Vector2(cos(a) * 40.0 * u, sin(a) * 34.0 * u + 60.0 * u * u)
					draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.45, 0.42, 0.4, 1.0 - u))
				if f.d.get("big", false):
					draw_circle(p, 10.0 + u * 30.0, Color(0.7, 0.66, 0.6, 0.4 * (1.0 - u)))
			"pick":
				var side: float = f.d.get("side", 1.0)
				var ang := lerpf(-2.2, 0.6, ease(u, 0.5)) * side
				var hand := p + Vector2(8 * side, -26)
				var head := hand + Vector2(0, -30).rotated(ang)
				draw_line(hand, head, Color("#78350f"), 4.0)
				var perp := (head - hand).normalized().rotated(PI / 2.0)
				draw_line(head - perp * 11.0, head + perp * 11.0, Color("#9ca3af"), 5.0)
				draw_line(head - perp * 11.0, head + perp * 11.0, Color("#4b5563"), 1.5)
			"money":
				var v := int(f.d.get("v", 0))
				var col := Color("#86efac") if v > 0 else Color("#fca5a5")
				_text(p + Vector2(-80, -u * 34.0), ("+%s" if v > 0 else "−%s") % U.money(absi(v)), 17, Color(col, 1.0 - u * u), 160)
			"level":
				for j in 3:
					var rr := 14.0 + (u * 70.0 + j * 14.0)
					draw_arc(p + Vector2(0, -20), rr, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.8 * (1.0 - u)), 3.0)
				for j in 8:
					var a := TAU * j / 8.0 + u * 2.0
					var q := p + Vector2(0, -20) + Vector2(cos(a), sin(a)) * (20.0 + u * 60.0)
					_draw_star(q, 6.0 * (1.0 - u * 0.5), Color(1.0, 0.95, 0.5, 1.0 - u))
			"steam":
				for j in 4:
					var ph := fmod(u * 1.4 + j * 0.25, 1.0)
					draw_circle(p + Vector2(-12 + j * 8 + sin(ph * 6.0 + j) * 4.0, -ph * 40.0), 4.0 + ph * 6.0, Color(1, 1, 1, 0.5 * (1.0 - ph) * (1.0 - u * 0.5)))


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for j in 10:
		var a := -PI / 2.0 + j * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if j % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)



# ================================================================== 1.3: telefon, takas, at, hipodrom, kamp, fotoğraf

func open_phone() -> void:
	if panel != null:
		return
	panel = preload("res://scripts/ui/phone_panel.gd").new()
	panel.camera_requested.connect(func():
		_close_panel()
		set_photo_mode(true))
	panel.nav_requested.connect(func(pos):
		_close_panel()
		set_nav(pos))
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -6.0, 1.3)


func _on_trade_invite(from_id: int, from_name: String) -> void:
	if panel != null:
		_close_panel()
	panel = preload("res://scripts/ui/trade_invite_panel.gd").new()
	panel.from_id = from_id
	panel.from_name = from_name
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("notify")


func _on_trade_open(_d: Dictionary) -> void:
	if panel != null:
		_close_panel()
	panel = preload("res://scripts/ui/trade_panel.gd").new()
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open")


func _toggle_horse() -> void:
	if my_ride() == "horse":
		Garage.ride("")
		return
	if my_ride() != "":
		hud.show_toast("Önce aracından in.", false)
		return
	if _mount or _room >= 0 or _dive or Map.in_sea(my_pos):
		hud.show_toast("Ata sadece şehirde, karada binilir.", false)
		return
	if not Horses.has_horse():
		hud.show_toast("Atın yok. Sanayi'deki Hara'dan at alabilirsin.", false)
		return
	Garage.ride("horse")
	Sfx.play("gallop", -6.0)


## Kamp alanı ve orman etkileşimleri (dağ bölgesinde).
func _camp_zone(mz: Dictionary) -> Dictionary:
	for s in Camp.spots:
		if mz.is_empty() and my_pos.distance_to(Vector2(float(s.x), float(s.y))) < Camp.PICK_RANGE:
			var names := {"mantar": "Mantar topla", "kuzugobegi": "Kuzugöbeği topla!", "sinekmantari": "Mantar topla (kırmızı... zehirli olabilir)",
				"bogurtlen": "Böğürtlen topla", "yabanmersini": "Yaban mersini topla", "kozalak": "Kozalak topla", "dal": "Kuru dal topla (odun)"}
			mz = {"type": "forage", "id": int(s.id), "label": names.get(str(s.k), "Topla")}
	if Map.CAMP.grow(30).has_point(my_pos):
		var mine: Dictionary = Camp.tents.get(Net.my_name, {})
		if Camp.has_tent and mz.is_empty():
			mz = {"type": "tent_pitch", "label": "Çadırını buraya kur" if mine.is_empty() else "Çadırını buraya taşı"}
		if not mine.is_empty() and my_pos.distance_to(Vector2(float(mine.x), float(mine.y))) < 90.0:
			mz = {"type": "tent_rest", "label": "Çadırında dinlen (enerji dolar)"}
		var near_fire := -1
		for i in Map.CAMPFIRES.size():
			if my_pos.distance_to(Map.CAMPFIRES[i]) < 110.0 and (near_fire < 0 or my_pos.distance_to(Map.CAMPFIRES[i]) < my_pos.distance_to(Map.CAMPFIRES[near_fire])):
				near_fire = i
		if near_fire >= 0:
			if Camp.fire_left(near_fire) > 0.0:
				mz = {"type": "roast", "i": near_fire, "label": "Marshmallow kızart (%d çantada)" % int(Rpg.sheet.get("items", {}).get("marshmallow", 0))}
			else:
				mz = {"type": "fire_light", "i": near_fire, "label": "Kamp ateşi yak (2 odun, ambarda %d)" % int(Farm.my_crops.get("odun", 0))}
	if my_pos.distance_to(Map.TELESCOPE) < 100.0:
		mz = {"type": "teleskop", "label": "Teleskop — yıldızları izle"}
	if not Camp.star.is_empty() and Time.get_ticks_msec() / 1000.0 - float(Camp.star.t0) < Camp.STAR_WINDOW and Map.CAMP.grow(150).has_point(my_pos) \
			and (mz.is_empty() or str(mz.get("type", "")) in ["tent_pitch", "forage", "tent_rest", "roast", "fire_light", "teleskop"]):
		mz = {"type": "wish_star", "label": "KAYAN YILDIZ! Dilek tut"}
	return mz


# --- çizimler

## At (yandan ya da önden/arkadan). Ayaklar dörtnala hareket eder.
func _draw_horse(p: Vector2, facing: String, moving: bool, col: Color) -> void:
	var dark := col.darkened(0.35)
	var gal := sin(_t * 16.0) if moving else 0.0
	draw_set_transform(p + Vector2(0, 12), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 30, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)
	if facing in ["left", "right"]:
		var s := 1.0 if facing == "right" else -1.0
		var body := p + Vector2(0, -8 + absf(gal) * -2.0)
		# bacaklar
		for k in 4:
			var lx: float = [-20.0, -12.0, 12.0, 20.0][k] * s
			var sw := gal * (8.0 if k % 2 == 0 else -8.0)
			draw_line(body + Vector2(lx, 6), body + Vector2(lx + sw * s, 22), dark if k % 2 == 0 else col.darkened(0.15), 4.0)
			draw_circle(body + Vector2(lx + sw * s, 22), 2.5, Color("#1f2937"))
		draw_set_transform(body, 0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, 26, col)
		draw_set_transform(Vector2.ZERO)
		# kuyruk
		draw_line(body + Vector2(-24 * s, -4), body + Vector2(-34 * s, 8 + gal * 3.0), dark, 5.0)
		# boyun ve baş
		var neck := body + Vector2(18 * s, -6)
		var head := body + Vector2(32 * s, -22 + gal * 1.5)
		draw_line(neck, head, col, 10.0)
		draw_set_transform(head + Vector2(5 * s, 2), 0.35 * s, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, 9, col)
		draw_set_transform(Vector2.ZERO)
		draw_circle(head + Vector2(2 * s, -2), 1.6, Color("#111827"))
		draw_line(head + Vector2(-2 * s, -6), head + Vector2(-1 * s, -12), dark, 3.0)        # kulak
		draw_line(neck + Vector2(-2 * s, -6), head + Vector2(-6 * s, -6), dark, 3.0)         # yele
		# eyer
		draw_rect(Rect2(body.x - 10, body.y - 14, 20, 8), Color("#7f1d1d"))
	else:
		var front := facing == "down"
		var body2 := p + Vector2(0, -6)
		for k in 2:
			var lx := -8.0 + k * 16.0
			var sw := gal * (5.0 if k == 0 else -5.0)
			draw_line(body2 + Vector2(lx, 6), body2 + Vector2(lx, 22 + sw), dark, 4.0)
		draw_set_transform(body2, 0, Vector2(0.55, 1.0))
		draw_circle(Vector2.ZERO, 22, col)
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(body2.x - 9, body2.y - 12, 18, 8), Color("#7f1d1d"))
		if front:
			draw_circle(body2 + Vector2(0, 16), 9, col)
			draw_circle(body2 + Vector2(-3, 14), 1.4, Color("#111827"))
			draw_circle(body2 + Vector2(3, 14), 1.4, Color("#111827"))
		else:
			draw_line(body2 + Vector2(0, 18), body2 + Vector2(sin(_t * 6.0) * 4.0, 30), dark, 5.0)


func _draw_horse_head_front(p: Vector2, _facing: String, col: Color) -> void:
	# yukarı giderken atın başı binicinin önünde (üstte) görünür
	draw_circle(p + Vector2(0, -50), 9, col)
	draw_line(p + Vector2(-4, -58), p + Vector2(-5, -64), col.darkened(0.35), 3.0)
	draw_line(p + Vector2(4, -58), p + Vector2(5, -64), col.darkened(0.35), 3.0)


func _draw_race_horse(l: Dictionary, lane: int) -> void:
	var x := float(l.x)
	var p := Vector2(x, Map.hippo_lane_y(lane))
	var running := str(Horses.race.get("state", "")) == "run" and int(l.place) == 0 and float(Horses.race.get("left", 0.0)) >= 3.0
	_draw_horse(p, "right", running, Horses.COLORS[int(l.c) % Horses.COLORS.size()])
	var app := {"skin": 1, "hair": 3, "hair_color": 0, "shirt": [1, 4, 7, 10][lane % 4], "pants": 0}
	var pid := int(l.get("pid", 0))
	if pid != 0 and Net.roster.has(pid):
		app = Net.roster[pid].get("appearance", app)
	Avatar.draw(self, p + Vector2(0, -22), app, "right", 0, 0.9)
	if l.get("whip", false):
		draw_line(p + Vector2(-6, -40), p + Vector2(-22, -30 + sin(_t * 30.0) * 6.0), Color("#78350f"), 2.0)
	_text(p + Vector2(-60, -66), "%s%s" % [("%d. " % int(l.place)) if int(l.place) > 0 else "", l.n], 12, Color.WHITE, 120)


func _draw_hippodrome() -> void:
	var h: Rect2 = Map.HIPPODROME
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200).intersects(h.grow(200)):
		return
	draw_rect(h, Color("#a47148"))
	for i in Horses.LANES + 1:
		var y := h.position.y + 4.0 + i * 41.0
		draw_line(Vector2(h.position.x, y), Vector2(h.end.x, y), Color(1, 1, 1, 0.55), 2)
	for x in range(int(h.position.x), int(h.end.x), 60):
		draw_rect(Rect2(x, h.position.y - 4, 4, 10), Color("#f8fafc"))
		draw_rect(Rect2(x, h.end.y - 6, 4, 10), Color("#f8fafc"))
	draw_line(Vector2(h.position.x, h.position.y), Vector2(h.end.x, h.position.y), Color("#f8fafc"), 3)
	draw_line(Vector2(h.position.x, h.end.y), Vector2(h.end.x, h.end.y), Color("#f8fafc"), 3)
	# başlangıç kapıları ve finiş
	for i in Horses.LANES:
		var y := Map.hippo_lane_y(i)
		draw_rect(Rect2(Map.HIPPO_START_X - 34, y - 20, 10, 40), Color("#475569"))
	var fx := Map.HIPPO_FINISH_X
	for k in int(h.size.y / 12.0):
		draw_rect(Rect2(fx, h.position.y + k * 12, 12, 12), Color.WHITE if k % 2 == 0 else Color.BLACK)
	draw_rect(Rect2(fx + 20, h.position.y - 60, 6, 64), Color("#dc2626"))
	_text(Vector2(fx - 40, h.position.y - 66), "FİNİŞ", 16, Color("#fde68a"), 120)
	# tribün ve seyirciler
	var s: Rect2 = Map.HIPPO_STANDS
	draw_rect(s, Color("#334155"))
	var live := str(Horses.race.get("state", "idle")) == "run"
	for i in int(s.size.x / 14.0):
		var c := Color.from_hsv(fmod(i * 0.137, 1.0), 0.6, 0.9)
		var jump := absf(sin(_t * 8.0 + i)) * 4.0 if live else 0.0
		draw_circle(Vector2(s.position.x + 7 + i * 14, s.position.y + 10 - jump), 5, c)
	_text(Vector2(s.position.x, s.position.y - 8), "HİPODROM", 18, Color("#fde68a"), s.size.x)
	# gişe
	var b: Vector2 = Map.HIPPO_BOOTH
	draw_rect(Rect2(b.x - 40, b.y - 56, 80, 56), Color("#7c2d12"))
	draw_rect(Rect2(b.x - 30, b.y - 46, 60, 20), Color("#fde68a"))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-48, -54), b + Vector2(0, -80), b + Vector2(48, -54)]), Color("#b91c1c"))
	_text(Vector2(b.x - 60, b.y - 30), "BAHİS", 13, Color("#7c2d12"), 120, false)
	# padok çiti
	var pd: Rect2 = PADDOCK
	draw_rect(pd, Color("#86a35f"))
	draw_rect(pd, Color("#78350f"), false, 3)
	for x in range(int(pd.position.x), int(pd.end.x), 24):
		draw_line(Vector2(x, pd.position.y - 6), Vector2(x, pd.position.y + 4), Color("#78350f"), 2)


func _draw_forage(s: Dictionary) -> void:
	var p := Vector2(float(s.x), float(s.y))
	match str(s.k):
		"mantar", "kuzugobegi", "sinekmantari":
			var cap: Color = {"mantar": Color("#f5f5f4"), "kuzugobegi": Color("#a16207"), "sinekmantari": Color("#dc2626")}[str(s.k)]
			for k in (3 if s.k == "mantar" else 1):
				var q := p + Vector2(-10 + k * 10, (k % 2) * 4)
				draw_rect(Rect2(q.x - 2, q.y - 8, 4, 8), Color("#f5f5dc"))
				if s.k == "kuzugobegi":
					draw_set_transform(q + Vector2(0, -12), 0, Vector2(0.7, 1.0))
					draw_circle(Vector2.ZERO, 7, cap)
					draw_set_transform(Vector2.ZERO)
					for j in 3:
						draw_line(q + Vector2(-4, -14 + j * 3), q + Vector2(4, -14 + j * 3), cap.darkened(0.4), 1)
				else:
					draw_colored_polygon(PackedVector2Array([q + Vector2(-8, -8), q + Vector2(0, -15), q + Vector2(8, -8)]), cap)
					if s.k == "sinekmantari":
						draw_circle(q + Vector2(-2, -10), 1.2, Color.WHITE)
						draw_circle(q + Vector2(3, -11), 1.2, Color.WHITE)
		"bogurtlen", "yabanmersini":
			draw_circle(p + Vector2(0, -8), 13, Color("#166534"))
			draw_circle(p + Vector2(-8, -4), 9, Color("#15803d"))
			draw_circle(p + Vector2(8, -4), 9, Color("#15803d"))
			var bc := Color("#3b0764") if s.k == "bogurtlen" else Color("#1e40af")
			for j in 6:
				draw_circle(p + Vector2(-9 + (j % 3) * 9, -12 + int(j / 3) * 8), 2.6, bc)
		"kozalak":
			draw_set_transform(p + Vector2(0, -5), 0.3, Vector2(0.7, 1.0))
			draw_circle(Vector2.ZERO, 6, Color("#92400e"))
			draw_set_transform(Vector2.ZERO)
			draw_line(p + Vector2(-4, -8), p + Vector2(4, -2), Color("#78350f"), 1.5)
		"dal":
			draw_line(p + Vector2(-18, -2), p + Vector2(16, -6), Color("#78350f"), 4)
			draw_line(p + Vector2(0, -4), p + Vector2(8, -14), Color("#78350f"), 2.5)
			draw_line(p + Vector2(-10, -3), p + Vector2(-14, -12), Color("#78350f"), 2)


func _draw_tent(owner_name: String, t: Dictionary) -> void:
	var p := Vector2(float(t.x), float(t.y))
	var col: Color = [Color("#dc2626"), Color("#2563eb"), Color("#16a34a"), Color("#f59e0b"), Color("#7c3aed")][int(t.get("c", 0)) % 5]
	draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 46, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-44, 0), p + Vector2(0, -56), p + Vector2(44, 0)]), col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -56), p + Vector2(44, 0), p + Vector2(18, 0)]), col.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 0), p + Vector2(0, -26), p + Vector2(12, 0)]), Color("#1c1917"))
	draw_line(p + Vector2(0, -56), p + Vector2(0, -64), Color("#78350f"), 2)
	_text(p + Vector2(-60, -70), "%s'in çadırı" % owner_name, 12, Color.WHITE, 120)


func _draw_campfire(i: int) -> void:
	var p: Vector2 = Map.CAMPFIRES[i]
	for k in 8:
		var a := TAU * k / 8.0
		draw_circle(p + Vector2(cos(a) * 18.0, sin(a) * 8.0), 5, Color("#6b7280"))
	draw_line(p + Vector2(-14, 2), p + Vector2(14, -4), Color("#5b3a1e"), 5)
	draw_line(p + Vector2(-14, -4), p + Vector2(14, 2), Color("#78350f"), 5)
	if Camp.fire_left(i) <= 0.0:
		return
	var glow := 0.8 + 0.2 * sin(_t * 9.0)
	draw_circle(p + Vector2(0, -6), 34.0 * glow, Color(1.0, 0.6, 0.2, 0.12))
	for k in 5:
		var fl := 14.0 + 10.0 * sin(_t * (7.0 + k) + k * 1.7)
		var x := -10.0 + k * 5.0
		draw_colored_polygon(PackedVector2Array([p + Vector2(x - 6, -2), p + Vector2(x + sin(_t * 5.0 + k) * 3.0, -2 - fl - 8.0), p + Vector2(x + 6, -2)]),
			Color(1.0, 0.45 + 0.1 * k, 0.1, 0.85))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5, -2), p + Vector2(0, -16 - sin(_t * 11.0) * 4.0), p + Vector2(5, -2)]), Color("#fde68a"))
	for k in 3:
		var ph := fmod(_t * 0.8 + k * 0.33, 1.0)
		draw_circle(p + Vector2(sin(_t + k * 2.0) * 8.0, -30 - ph * 50.0), 2.0, Color(1.0, 0.7, 0.2, 1.0 - ph))


func _draw_telescope(p: Vector2) -> void:
	draw_line(p, p + Vector2(-12, 20), Color("#374151"), 3)
	draw_line(p, p + Vector2(12, 20), Color("#374151"), 3)
	draw_line(p, p + Vector2(0, 22), Color("#374151"), 3)
	draw_line(p + Vector2(-16, 6), p + Vector2(20, -18), Color("#1e3a8a"), 9)
	draw_line(p + Vector2(16, -16), p + Vector2(22, -20), Color("#93c5fd"), 9)
	_text(p + Vector2(-60, -40), "TELESKOP", 12, Color("#bfdbfe"), 120)


func _draw_roast_stick(p: Vector2) -> void:
	var best: Vector2 = Map.CAMPFIRES[0]
	for f in Map.CAMPFIRES:
		if p.distance_to(f) < p.distance_to(best):
			best = f
	var dir := (best - p).normalized()
	var hand := p + Vector2(8 * signf(dir.x if dir.x != 0.0 else 1.0), -24)
	var tip := hand + dir * 48.0 + Vector2(0, 10)
	draw_line(hand, tip, Color("#92400e"), 2.5)
	var browned := clampf(fmod(_t, 3.0) / 3.0, 0.0, 1.0)
	draw_circle(tip, 5.0, Color(1.0, 1.0 - browned * 0.35, 1.0 - browned * 0.7))


# --- fotoğraf modu

var photo_mode := false
var photo_filter := 0
var _photo_layer: CanvasLayer
var _photo_rect: ColorRect
var _photo_hint: Label
var _photo_flash: ColorRect
var _photo_zoom := Vector2.ONE

const PHOTO_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform int mode = 0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	if (mode == 1) { c = vec3(g); }
	else if (mode == 2) { c = vec3(g * 1.07 + 0.08, g * 0.95 + 0.03, g * 0.75); }
	else if (mode == 3) { c = c * vec3(1.1, 1.0, 0.86) + vec3(0.03, 0.01, 0.0); }
	else if (mode == 4) { c = c * vec3(0.88, 1.0, 1.12); }
	else if (mode == 5) { c = mix(c, vec3(g), 0.35) * vec3(1.06, 0.98, 0.84); float v = distance(SCREEN_UV, vec2(0.5)); c *= 1.0 - v * v * 1.3; }
	else if (mode == 6) { c = floor(c * 4.0 + 0.5) / 4.0; }
	COLOR = vec4(c, 1.0);
}
"""


func _build_photo_layer() -> void:
	_photo_layer = CanvasLayer.new()
	_photo_layer.layer = 4
	_photo_layer.visible = false
	add_child(_photo_layer)
	_photo_rect = ColorRect.new()
	_photo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_photo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = PHOTO_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_photo_rect.material = mat
	_photo_layer.add_child(_photo_rect)
	_photo_hint = Label.new()
	_photo_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_photo_hint.position = Vector2(0, -60)
	_photo_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_photo_hint.add_theme_font_size_override("font_size", 16)
	_photo_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_photo_hint.add_theme_constant_override("outline_size", 6)
	_photo_layer.add_child(_photo_hint)
	_photo_flash = ColorRect.new()
	_photo_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_photo_flash.color = Color(1, 1, 1, 0)
	_photo_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_layer.add_child(_photo_flash)


func set_photo_mode(on: bool) -> void:
	if on == photo_mode:
		return
	if on and panel != null:
		_close_panel()
	photo_mode = on
	ui_layer.visible = not on
	_photo_layer.visible = on
	if on:
		_photo_zoom = camera.zoom
		_update_photo_hint()
	else:
		camera.zoom = _photo_zoom


func _update_photo_hint() -> void:
	(_photo_rect.material as ShaderMaterial).set_shader_parameter("mode", photo_filter)
	_photo_rect.visible = photo_filter != 0
	var w := get_viewport_rect().size.x
	_photo_hint.size = Vector2(w, 30)
	_photo_hint.position = Vector2(0, get_viewport_rect().size.y - 46)
	_photo_hint.text = "FOTOĞRAF MODU  ·  Boşluk: çek  ·  1-7: filtre (%s)  ·  tekerlek: yakınlaş  ·  N: isimler  ·  Esc: çık" % PHOTO_FILTERS[photo_filter]


func _photo_input(k: InputEventKey) -> void:
	match k.physical_keycode:
		KEY_ESCAPE:
			set_photo_mode(false)
		KEY_SPACE, KEY_ENTER:
			_take_photo()
		KEY_N:
			labels.visible = not labels.visible
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			photo_filter = k.physical_keycode - KEY_1
			_update_photo_hint()
		_:
			if Settings.is_key(k, "photo"):
				set_photo_mode(false)
	get_viewport().set_input_as_handled()


func _take_photo() -> void:
	_photo_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_photo_hint.visible = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://album"))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://album/foto_%s_%d.png" % [stamp, Time.get_ticks_msec() % 1000]
	img.save_png(path)
	Phone.photo_taken()
	Sfx.play("click", 0.0, 0.6)
	_photo_flash.color = Color(1, 1, 1, 0.8)
	create_tween().tween_property(_photo_flash, "color:a", 0.0, 0.35)
	hud.show_toast("Fotoğraf albüme kaydedildi (Telefon → Albüm).")



# ================================================================== 1.4: fuar, havalimanı, dedektif, okul

## Çarpışan araba: ataletli sürüş, duvardan ve diğer arabalardan seker; çarptığını sunucuya bildirir.
func _bumper_move(delta: float) -> void:
	var dir := Vector2.ZERO
	if panel == null and not hud.is_typing():
		if Settings.held("up"):
			dir.y -= 1
		if Settings.held("down"):
			dir.y += 1
		if Settings.held("left"):
			dir.x -= 1
		if Settings.held("right"):
			dir.x += 1
	_bump_vel += dir.normalized() * 700.0 * delta
	_bump_vel *= 1.0 - 1.6 * delta
	_bump_vel = _bump_vel.limit_length(330.0)
	var np := my_pos + _bump_vel * delta
	var r := Map.BUMPER.grow(-24)
	if np.x < r.position.x or np.x > r.end.x:
		_bump_vel.x = -_bump_vel.x * 0.8
	if np.y < r.position.y or np.y > r.end.y:
		_bump_vel.y = -_bump_vel.y * 0.8
	my_pos = np.clamp(r.position, r.end)
	if _bump_vel.length() > 20.0:
		my_moving = true
		my_facing = _facing_of(_bump_vel)
	var others: Array = []
	for id in shown:
		var info = Net.roster.get(id)
		if info and str(info.get("ride", "")) == "bumper":
			others.append([str(id), shown[id]])
	for k in Fair.npcs.size():
		others.append(["npc:%d" % k, Vector2(float(Fair.npcs[k].x), float(Fair.npcs[k].y))])
	for o in others:
		var op: Vector2 = o[1]
		if my_pos.distance_to(op) < 48.0:
			var away := (my_pos - op).normalized()
			if _bump_vel.dot(-away) > 30.0 and _t - float(_bump_t.get(o[0], -9.0)) > 0.8:
				_bump_t[o[0]] = _t
				Fair.bump(o[0])
				Sfx.play("chip", -2.0, 0.6)
				add_fx("chips", (my_pos + op) / 2.0, 0.4)
			_bump_vel = away * maxf(160.0, _bump_vel.length())
			my_pos = op + away * 49.0


func _update_fair_zone() -> void:
	var z := {}
	var ride := my_ride()
	if ride == "ferris":
		zone = {}
		hud.set_hint("" if panel != null else "Dönme dolaptasın — manzaranın tadını çıkar! (%s: fotoğraf)" % Settings.key_name("photo"))
		return
	if ride == "bumper":
		zone = {}
		var left := maxf(0.0, Fair.bumper_end - Time.get_ticks_msec() / 1000.0)
		hud.set_hint("" if panel != null else "ÇARPIŞAN ARABA  ·  %d sn  ·  %d çarpışma  ·  yön tuşlarıyla sür, başkalarına çarp!" % [int(left), Fair.bumper_pts])
		return
	for b in Map.FAIR_BUILDINGS:
		if b.rect.grow(26).has_point(my_pos):
			z = {"type": b.type, "label": "Havalimanı — uçuşlar"}
	if my_pos.distance_to(Map.SHUTTLE_FAIR) < 100.0:
		z = {"type": "shuttle", "fair": false, "label": "Şehre dönüş servisi (%s)" % U.money(Fair.SHUTTLE_PRICE)}
	if my_pos.distance_to(Map.TICKET_BOOTH) < 110.0:
		z = {"type": "fair_gise", "label": "Jeton gişesi ve ödül standı (jeton %d, bilet %d)" % [Fair.jeton, Fair.bilet]}
	if my_pos.distance_to(Map.GALLERY) < 120.0:
		z = {"type": "gallery", "label": "Atış poligonu (%d jeton)" % Fair.RIDE_COST}
	if my_pos.distance_to(Map.CANDY) < 100.0:
		z = {"type": "candy", "label": "Pamuk şeker al (%s)" % U.money(int(Fair.FAIR_FOODS.pamuk_seker.price))}
	if my_pos.distance_to(Map.FERRIS + Vector2(0, Map.FERRIS_R + 60)) < 110.0:
		z = {"type": "ferris", "label": "Dönme dolaba bin (%d jeton)" % Fair.RIDE_COST}
	if my_pos.distance_to(Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y + 40)) < 110.0:
		z = {"type": "bumper", "label": "Çarpışan arabalar (%d jeton, 60 sn)" % Fair.RIDE_COST}
	if my_pos.distance_to(Map.BALLOON_FIELD) < 140.0:
		z = {"type": "balloon", "label": "Sıcak hava balonu turu (%s, 45 sn)" % U.money(Airport.BALLOON_PRICE)}
	z = _zoo_zone(z)
	if Map.CINEMA.rect.grow(26).has_point(my_pos):
		z = {"type": "sinema", "label": "Sinema — film ve karaoke"}
	if my_pos.distance_to(Map.ARENA_BOOTH) < 110.0:
		z = {"type": "paint", "label": "Paintball Arenası — takım seç"}
	z = _rail_zone(z)
	zone = z
	if Paint.in_match():
		zone = {}
		hud.set_hint("" if panel != null else _paint_hint())
		return
	hud.set_hint("" if panel != null or z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label])


## Açık vakanın ipuçları ve şüphelileri (her bölgede).
func _detective_zone(z: Dictionary) -> Dictionary:
	var cs := Detective.active_case()
	if cs.is_empty():
		return z
	for cl in cs.clues:
		if not Detective.has_clue(cl.id) and my_pos.distance_to(cl.pos) < Detective.RANGE:
			z = {"type": "clue", "id": cl.id, "label": "İpucunu incele"}
	for s in cs.suspects:
		if my_pos.distance_to(s.pos) < Detective.RANGE:
			z = {"type": "suspect", "id": s.id, "label": "Sorgula: %s" % s.name}
	return z


func _on_flight(d: Dictionary) -> void:
	if panel != null:
		_close_panel()
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var sky := ColorRect.new()
	sky.color = Color("#7dd3fc")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(sky)
	var art := FlightArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.dest = str(d.get("name", ""))
	layer.add_child(art)
	Sfx.play("door", -4.0, 0.6)
	var tw := create_tween()
	tw.tween_interval(float(d.get("time", 3.0)) + 0.2)
	tw.tween_property(sky, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(art, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


class FlightArt extends Control:
	var dest := ""
	var t0 := Time.get_ticks_msec() / 1000.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		for i in 9:
			var cx := fposmod(size.x - (t * (180.0 + i * 30.0) + i * 230.0), size.x + 300.0) - 150.0
			var cy := 80.0 + fmod(i * 97.0, size.y - 160.0)
			for j in 3:
				draw_circle(Vector2(cx + j * 34.0, cy + (j % 2) * 10.0), 26.0 + j * 4.0, Color(1, 1, 1, 0.85))
		var p := Vector2(size.x * 0.45, size.y * 0.5 + sin(t * 2.0) * 10.0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-120, -14), p + Vector2(110, -14), p + Vector2(140, 0), p + Vector2(110, 14), p + Vector2(-120, 14)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-20, 0), p + Vector2(30, 0), p + Vector2(-40, 90), p + Vector2(-70, 90)]), Color("#cbd5e1"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-20, 0), p + Vector2(30, 0), p + Vector2(-40, -90), p + Vector2(-70, -90)]), Color("#e2e8f0"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-120, -14), p + Vector2(-100, -14), p + Vector2(-130, -60), p + Vector2(-145, -60)]), Color("#dc2626"))
		for k in 7:
			draw_circle(p + Vector2(-70 + k * 24, -4), 4, Color("#38bdf8"))
		draw_line(p + Vector2(-120, 8), p + Vector2(110, 8), Color("#dc2626"), 3)
		draw_string(ThemeDB.fallback_font, Vector2(0, size.y - 60), "✈  %s'na uçuluyor..." % dest, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color("#0f172a"))


func _draw_gondola(p: Vector2, app: Dictionary, pname: String, name_col: Color, extra: Dictionary) -> void:
	draw_line(p + Vector2(0, -48), p + Vector2(0, -30), Color("#475569"), 3)
	Avatar.draw(self, p + Vector2(0, -4), app, "down", 0, 0.9)
	draw_rect(Rect2(p.x - 22, p.y - 14, 44, 26), Color("#ef4444"))
	draw_rect(Rect2(p.x - 22, p.y - 14, 44, 26), Color("#7f1d1d"), false, 2)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-26, -34), p + Vector2(26, -34), p + Vector2(18, -44), p + Vector2(-18, -44)]), Color("#facc15"))
	_name(p, -70, pname, name_col, extra)


func _draw_bumper_car(p: Vector2, col: Color, app: Dictionary, facing: String) -> void:
	draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.7))
	draw_circle(Vector2.ZERO, 26, Color("#111827"))
	draw_circle(Vector2.ZERO, 22, col)
	draw_set_transform(Vector2.ZERO)
	draw_line(p + Vector2(-12, -6), p + Vector2(-12, -60), Color("#9ca3af"), 2)
	draw_circle(p + Vector2(-12, -62), 3, Color("#fde68a") if fmod(_t * 8.0, 1.0) < 0.5 else Color("#f59e0b"))
	Avatar.draw(self, p + Vector2(0, -8), app, facing, 0, 0.85)


func _draw_sky() -> void:
	# balondakiler (her şeyin üstünde)
	var riders: Array = []
	for id in shown:
		var info = Net.roster.get(id)
		if info and str(info.get("ride", "")) == "balloon":
			riders.append([shown[id], info.get("appearance", {}), _name_of(info)])
	var me = Net.roster.get(Net.my_id())
	if me and str(me.get("ride", "")) == "balloon":
		riders.append([my_pos, me.get("appearance", {}), _name_of(me)])
	for r in riders:
		var p: Vector2 = r[0] + Vector2(0, -170 + sin(_t * 1.2) * 6.0)
		var cols := [Color("#ef4444"), Color("#facc15"), Color("#3b82f6"), Color("#22c55e")]
		draw_set_transform(p + Vector2(0, -80), 0, Vector2(1.0, 1.15))
		draw_circle(Vector2.ZERO, 66, cols[0])
		for k in 4:
			draw_colored_polygon(PackedVector2Array([Vector2(-66 + k * 33, -10), Vector2(-50 + k * 33, -60), Vector2(-34 + k * 33, -10), Vector2(-50 + k * 33, 50)]), cols[(k + 1) % 4])
		draw_set_transform(Vector2.ZERO)
		for dx in [-20.0, 20.0]:
			draw_line(p + Vector2(dx * 1.6, -14), p + Vector2(dx * 0.8, 10), Color("#78350f"), 2)
		Avatar.draw(self, p + Vector2(0, 14), r[1], "down", 0, 0.85)
		draw_rect(Rect2(p.x - 22, p.y + 8, 44, 26), Color("#a16207"))
		draw_rect(Rect2(p.x - 22, p.y + 8, 44, 26), Color("#78350f"), false, 2)
		if fmod(_t, 2.0) < 0.3:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-6, -10), p + Vector2(0, -30), p + Vector2(6, -10)]), Color("#f97316"))
		_text(p + Vector2(-100, 44), r[2], 13, Color.WHITE, 200)


func _draw_suspect(s: Dictionary) -> void:
	var p: Vector2 = s.pos
	draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	Avatar.draw(self, p, s.app, _facing_of(my_pos - p) if my_pos.distance_to(p) < 160 else "down", 0)
	_text(p + Vector2(-100, -56), s.name, 14, Color("#fca5a5"), 200)
	if not Detective.talked(s.id):
		draw_circle(p + Vector2(0, -72), 10, Color("#f97316"))
		_text(p + Vector2(-10, -64), "?", 14, Color.WHITE, 20, false)


## Şehirdeki 1.4 eklentileri: servis durağı, dedektif ve açık vakanın ipuçları.
func _draw_city_extras() -> void:
	var sp: Vector2 = Map.SHUTTLE_CITY
	draw_rect(Rect2(sp.x - 3, sp.y - 64, 6, 64), Color("#374151"))
	draw_rect(Rect2(sp.x - 34, sp.y - 92, 68, 30), Color("#7c3aed"))
	_text(Vector2(sp.x - 70, sp.y - 72), "LUNAPARK ✈", 12, Color.WHITE, 140, false)
	var d: Vector2 = Map.DETECTIVE
	draw_set_transform(d + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	Avatar.draw(self, d, {"skin": 2, "hair": 4, "hair_color": 0, "shirt": 11, "pants": 0}, _facing_of(my_pos - d) if my_pos.distance_to(d) < 160 else "down", 0)
	draw_rect(Rect2(d.x - 15, d.y - 52, 30, 6), Color("#78350f"))       # şapka
	draw_rect(Rect2(d.x - 9, d.y - 62, 18, 11), Color("#78350f"))
	_text(d + Vector2(-100, -76), "Dedektif Ferhat", 15, Color("#fde68a"), 200)
	if Detective.active_case().is_empty() and Detective.state.get("solved", []).size() < Detective.CASES.size():
		draw_circle(d + Vector2(0, -94), 11, Color("#facc15"))
		_text(d + Vector2(-10, -86), "!", 15, Color("#111827"), 20, false)
	var cs := Detective.active_case()
	for cl in cs.get("clues", []):
		if Detective.has_clue(cl.id):
			continue
		var cp: Vector2 = cl.pos
		for k in 4:
			var a := _t * 2.0 + k * TAU / 4.0
			draw_circle(cp + Vector2(cos(a), sin(a) * 0.5) * 16.0, 2.5, Color(1.0, 0.9, 0.3, 0.9))
		draw_circle(cp, 9, Color(1.0, 0.85, 0.2, 0.35 + 0.25 * sin(_t * 4.0)))
		_text(cp + Vector2(-10, -26), "?", 16, Color("#fde68a"), 20)


func _draw_fair() -> void:
	var b: Rect2 = Map.FAIR
	var vsize := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200)
	if not view.intersects(b):
		return
	draw_rect(b, GRASS.get(Env.season, GRASS.spring))
	# lunapark zemini ve yollar
	draw_rect(Rect2(10620, 180, 1240, 1400), Color("#d6c7a1"))
	draw_rect(Rect2(10620, 1480, 2560, 120), Color("#9ca3af"))
	draw_rect(Rect2(11270, 1500, 60, 120), Color("#6b7280"))
	_text(Vector2(10620, 210), "LUNAPARK", 30, Color("#f472b6"), 1240)
	# ışık zincirleri
	for i in 40:
		var x := 10640.0 + i * 30.0
		var col := Color.from_hsv(fmod(i * 0.11 + _t * 0.2, 1.0), 0.7, 1.0)
		draw_circle(Vector2(x, 240 + sin(i * 0.8) * 8.0), 4, col)
	# dönme dolap
	var f: Vector2 = Map.FERRIS
	var R := Map.FERRIS_R
	draw_line(f, f + Vector2(-120, R + 60), Color("#475569"), 10)
	draw_line(f, f + Vector2(120, R + 60), Color("#475569"), 10)
	var ang := Fair.ferris_angle(Land.server_now())
	draw_arc(f, R, 0, TAU, 64, Color("#e5e7eb"), 6)
	draw_arc(f, R - 30, 0, TAU, 64, Color("#cbd5e1"), 3)
	for k in Fair.FERRIS_SEATS:
		var a := ang + k * TAU / Fair.FERRIS_SEATS
		var sp := f + Vector2(cos(a), sin(a)) * R
		draw_line(f, sp, Color("#94a3b8"), 3)
		draw_circle(sp, 6, Color("#fde68a") if Env.darkness() > 0.3 else Color("#94a3b8"))
	draw_circle(f, 18, Color("#64748b"))
	# boş koltuklar (biniciler kendi çizilir)
	var taken := {}
	for id in Net.roster:
		if str(Net.roster[id].get("ride", "")) == "ferris":
			taken[int(Net.roster[id].get("seat", -1))] = true
	for k in Fair.FERRIS_SEATS:
		if taken.has(k):
			continue
		var gp := Fair.seat_pos(k, Land.server_now())
		draw_line(gp + Vector2(0, -48), gp + Vector2(0, -30), Color("#475569"), 3)
		draw_rect(Rect2(gp.x - 22, gp.y - 30, 44, 42), [Color("#ef4444"), Color("#3b82f6"), Color("#22c55e"), Color("#f59e0b")][k % 4])
		draw_colored_polygon(PackedVector2Array([gp + Vector2(-26, -34), gp + Vector2(26, -34), gp + Vector2(18, -44), gp + Vector2(-18, -44)]), Color("#facc15"))
	_text(f + Vector2(-100, R + 96), "DÖNME DOLAP", 16, Color("#fde68a"), 200)
	# çarpışan araba pisti
	var a2: Rect2 = Map.BUMPER
	draw_rect(a2, Color("#334155"))
	for x in range(int(a2.position.x), int(a2.end.x), 40):
		draw_line(Vector2(x, a2.position.y), Vector2(x, a2.end.y), Color(1, 1, 1, 0.05), 1)
	draw_rect(a2, Color("#facc15"), false, 8)
	draw_rect(a2.grow(-8), Color("#111827"), false, 4)
	_text(Vector2(a2.position.x, a2.position.y - 14), "ÇARPIŞAN ARABALAR", 18, Color("#fde68a"), a2.size.x)
	for k in Fair.npcs.size():
		var np := Vector2(float(Fair.npcs[k].x), float(Fair.npcs[k].y))
		_draw_bumper_car(np, [Color("#22c55e"), Color("#f97316"), Color("#a855f7")][k % 3], {"skin": k, "hair": k, "hair_color": k, "shirt": 3 + k, "pants": k}, "down")
	# tezgâhlar
	for st in [[Map.GALLERY, "ATIŞ POLİGONU", Color("#dc2626")], [Map.TICKET_BOOTH, "JETON • ÖDÜL", Color("#7c3aed")], [Map.CANDY, "PAMUK ŞEKER", Color("#ec4899")]]:
		var c: Vector2 = st[0]
		draw_rect(Rect2(c.x - 80, c.y - 70, 160, 70), Color("#fef3c7"))
		for k in 8:
			draw_rect(Rect2(c.x - 84 + k * 21, c.y - 92, 21, 24), st[2] if k % 2 == 0 else Color.WHITE)
		draw_rect(Rect2(c.x - 80, c.y - 70, 160, 70), Color("#78350f"), false, 3)
		_text(Vector2(c.x - 90, c.y - 40), st[1], 14, Color("#7c2d12"), 180, false)
	# havalimanı: pist, kule, uçaklar
	var rw: Rect2 = Map.RUNWAY
	draw_rect(rw, Color("#374151"))
	for x in range(int(rw.position.x) + 20, int(rw.end.x) - 20, 80):
		draw_rect(Rect2(x, rw.get_center().y - 3, 44, 6), Color("#f8fafc"))
	for k in 8:
		draw_rect(Rect2(rw.position.x + 8, rw.position.y + 8 + k * 12, 30, 6), Color("#f8fafc"))
	_text(Vector2(rw.position.x, rw.position.y - 10), "PİST 09", 14, Color("#e5e7eb"), 200, false)
	var tk := _t - _takeoff_t
	var cyc := fmod(_t, 40.0)
	var plane_u := -1.0
	if tk < 5.0:
		plane_u = tk / 5.0
	elif cyc < 5.0:
		plane_u = cyc / 5.0
	if plane_u >= 0.0:
		var pp := Vector2(lerpf(rw.position.x + 60, rw.end.x + 300, plane_u * plane_u), rw.get_center().y - maxf(0.0, plane_u - 0.55) * 500.0)
		var sc := 1.0 + maxf(0.0, plane_u - 0.55) * 0.8
		draw_set_transform(pp, -maxf(0.0, plane_u - 0.55) * 0.5, Vector2(sc, sc))
		draw_colored_polygon(PackedVector2Array([Vector2(-60, -8), Vector2(56, -8), Vector2(70, 0), Vector2(56, 8), Vector2(-60, 8)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(14, 0), Vector2(-20, 46), Vector2(-34, 46)]), Color("#cbd5e1"))
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(14, 0), Vector2(-20, -46), Vector2(-34, -46)]), Color("#e2e8f0"))
		draw_colored_polygon(PackedVector2Array([Vector2(-60, -8), Vector2(-48, -8), Vector2(-64, -30), Vector2(-72, -30)]), Color("#dc2626"))
		draw_set_transform(Vector2.ZERO)
	# balon alanı
	var bf: Vector2 = Map.BALLOON_FIELD
	draw_circle(bf, 70, Color("#a3e635"))
	for k in 3:
		var bp := bf + Vector2(-150 + k * 150, -40 + (k % 2) * 30)
		if k == 1:
			bp = bf
		var cols := [Color("#ef4444"), Color("#3b82f6"), Color("#a855f7")]
		draw_set_transform(bp + Vector2(0, -110 + sin(_t * 1.5 + k) * 5.0), 0, Vector2(1.0, 1.15))
		draw_circle(Vector2.ZERO, 48, cols[k])
		draw_colored_polygon(PackedVector2Array([Vector2(-16, -46), Vector2(16, -46), Vector2(10, 46), Vector2(-10, 46)]), Color("#facc15"))
		draw_set_transform(Vector2.ZERO)
		draw_line(bp + Vector2(-16, -50), bp + Vector2(-12, -12), Color("#78350f"), 2)
		draw_line(bp + Vector2(16, -50), bp + Vector2(12, -12), Color("#78350f"), 2)
		draw_rect(Rect2(bp.x - 16, bp.y - 14, 32, 20), Color("#a16207"))
	_text(bf + Vector2(-100, 70), "BALON TURU", 16, Color("#fde68a"), 200)
	# servis otobüsü
	var sh: Vector2 = Map.SHUTTLE_FAIR
	draw_rect(Rect2(sh.x - 90, sh.y - 36, 180, 56), Color("#7c3aed"))
	for k in 5:
		draw_rect(Rect2(sh.x - 80 + k * 32, sh.y - 28, 24, 18), Color("#bae6fd"))
	draw_circle(sh + Vector2(-55, 22), 10, Color("#111827"))
	draw_circle(sh + Vector2(55, 22), 10, Color("#111827"))
	_text(sh + Vector2(-100, -50), "ŞEHİR SERVİSİ", 14, Color("#fde68a"), 200)



# ================================================================== 1.5: özel günler, spor, korsan adası, hayvanat bahçesi

func _holiday_g_action() -> Dictionary:
	match Holidays.active:
		"cadilar":
			for b in Map.BUILDINGS:
				var door := "b:" + str(b.type)
				if my_pos.distance_to(Holidays.door_pos(door)) < 80.0:
					return {"kind": "knock", "door": door, "label": "Kapıyı çal: Şeker mi şaka mı?"}
			for i in mini(Land.view.size(), Map.PLOT_COUNT):
				var p: Dictionary = Land.view[i]
				if int(p.level) >= 1 and str(p.get("kind", "home")) == "home" and my_pos.distance_to(Holidays.door_pos("p:%d" % i)) < 80.0:
					return {"kind": "knock", "door": "p:%d" % i, "label": "Kapıyı çal: Şeker mi şaka mı?"}
		"ramazan", "kurban":
			for k in Map.NPCS:
				if my_pos.distance_to(Map.NPCS[k].pos) < 90.0:
					return {"kind": "hand", "npc": k, "label": "%s'nın elini öp (harçlık)" % Map.NPCS[k].name}
		"sevgililer":
			for id in shown:
				if shown[id].distance_to(my_pos) < 100.0 and Net.roster.has(id):
					return {"kind": "rose", "to": id, "label": "%s'e gül ver ♥" % Net.roster[id].name}
	return {}


func _holiday_zone(z: Dictionary) -> Dictionary:
	var h := Holidays.active
	if h == "":
		return z
	if my_pos.distance_to(Holidays.STALL) < 90.0:
		z = {"type": "bayram", "label": "%s tezgâhı" % Holidays.NAMES[h]}
	if h == "yilbasi":
		if my_pos.distance_to(Holidays.SANTA) < 90.0:
			z = {"type": "santa", "label": "Noel Baba'dan günlük hediyeni al"}
		for g in Holidays.gifts:
			if my_pos.distance_to(Vector2(float(g.x), float(g.y))) < 80.0:
				z = {"type": "gift", "id": int(g.id), "label": "Hediye kutusunu aç"}
	return z


func _korsan_zone(z: Dictionary) -> Dictionary:
	if not Map.on_korsan(my_pos) and not Map.KORSAN_PIER.grow(30).has_point(my_pos):
		return z
	if my_pos.distance_to(Map.KORSAN_CAPTAIN) < 75.0:
		return {"type": "korsan", "label": "Korsan Kaptan Tek Göz Rıza"}
	if Map.on_korsan(my_pos) and z.is_empty():
		return {"type": "dig", "label": "Kürekle kaz" + (" (haritadaki X'i ara!)" if Pirates.state.get("has_map", false) else "") if Pirates.state.get("shovel", false) else "Kazmak için kaptandan kürek al"}
	return z


func _zoo_zone(z: Dictionary) -> Dictionary:
	if my_pos.distance_to(Map.ZOO_GATE + Vector2(0, -50)) < 90.0 and not Zoo.has_ticket():
		z = {"type": "zoo_ticket", "label": "Hayvanat bahçesi bileti (%s, 1 saat; akvaryum dahil)" % U.money(Zoo.TICKET_PRICE)}
	if my_pos.distance_to(Map.ZOO_KEEPER) < 100.0:
		z = {"type": "keeper", "label": "Gönüllü bakıcılık: %s" % ("bırak" if Zoo.task != "" else "iş al (yem taşı)")}
	if Zoo.task != "" and my_pos.distance_to(Zoo.pen_front(Zoo.task)) < 100.0:
		z = {"type": "deliver", "label": "Yemi %s bölmesine ver" % Zoo.ANIMALS[Zoo.task]}
	var fp := Zoo.feeding(Land.server_now())
	if fp != "" and my_pos.distance_to(Zoo.pen_front(fp)) < 140.0 and z.is_empty():
		z = {"type": "watch", "label": "Besleme saati: %s! İzle (+XP)" % Zoo.ANIMALS[fp]}
	for b in Map.ZOO_BUILDINGS:
		if b.rect.grow(26).has_point(my_pos):
			z = {"type": "akvaryum", "label": "Akvaryum" + ("" if Zoo.has_ticket() else " (bilet gerekir)")}
	return z


func _on_marathon(d: Dictionary) -> void:
	match str(d.get("state", "")):
		"start", "cp":
			var cp := int(Gym.run.get("cp", 1))
			if cp < Map.MARATHON.size():
				set_nav(Map.MARATHON[cp])
			if d.state == "cp":
				Sfx.play("tick", 0.0, 1.5)
		"end":
			nav_target = null
			if d.get("ok", false):
				Sfx.play("success")


## Bölmedeki hayvanlar: [[konum, yön, hareket]] (zamana bağlı, herkeste aynı).
func _zoo_animals(pen: String) -> Array:
	var r: Rect2 = Map.ZOO_PENS[pen]
	var n: int = {"aslan": 2, "fil": 2, "zurafa": 2, "penguen": 5, "maymun": 4, "ayi": 2}[pen]
	var feeding := Zoo.feeding(Land.server_now()) == pen
	var out: Array = []
	for i in n:
		var ph: float = i * 1.7 + pen.length()
		var sp: float = 0.15 + 0.05 * i
		var p := r.get_center() + Vector2(sin(_t * sp + ph) * r.size.x * 0.32, cos(_t * sp * 0.7 + ph) * r.size.y * 0.25)
		if feeding:
			p = Vector2(r.get_center().x - 50 + i * 30, r.end.y - 40)
		var vx := cos(_t * sp + ph)
		out.append([p, vx >= 0.0, absf(vx) > 0.2 and not feeding])
	return out


func _draw_zoo_animal(pen: String, a: Array) -> void:
	var p: Vector2 = a[0]
	var s := 1.0 if a[1] else -1.0
	var bob := sin(_t * 8.0) * 1.5 if a[2] else 0.0
	draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 22, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO)
	match pen:
		"aslan":
			draw_set_transform(p + Vector2(0, -14 + bob), 0, Vector2(1.3, 0.8))
			draw_circle(Vector2.ZERO, 16, Color("#d97706"))
			draw_set_transform(Vector2.ZERO)
			draw_circle(p + Vector2(18 * s, -24 + bob), 13, Color("#92400e"))
			draw_circle(p + Vector2(20 * s, -24 + bob), 8, Color("#f59e0b"))
			draw_circle(p + Vector2(23 * s, -26 + bob), 1.5, Color.BLACK)
			draw_line(p + Vector2(-20 * s, -16), p + Vector2(-32 * s, -26), Color("#d97706"), 3)
		"fil":
			draw_set_transform(p + Vector2(0, -22 + bob), 0, Vector2(1.4, 1.0))
			draw_circle(Vector2.ZERO, 22, Color("#9ca3af"))
			draw_set_transform(Vector2.ZERO)
			draw_circle(p + Vector2(26 * s, -30 + bob), 14, Color("#9ca3af"))
			draw_circle(p + Vector2(20 * s, -30 + bob), 10, Color("#d1d5db"))
			draw_line(p + Vector2(36 * s, -26 + bob), p + Vector2(40 * s, -6 + bob), Color("#9ca3af"), 6)
			for lx in [-16, -6, 8, 18]:
				draw_line(p + Vector2(lx * s, -6), p + Vector2(lx * s, 6), Color("#6b7280"), 7)
		"zurafa":
			draw_set_transform(p + Vector2(0, -22 + bob), 0, Vector2(1.2, 0.8))
			draw_circle(Vector2.ZERO, 15, Color("#fbbf24"))
			draw_set_transform(Vector2.ZERO)
			draw_line(p + Vector2(10 * s, -26), p + Vector2(18 * s, -70 + bob), Color("#fbbf24"), 7)
			draw_circle(p + Vector2(22 * s, -72 + bob), 7, Color("#fbbf24"))
			for sp in [Vector2(-6, -24), Vector2(4, -18), Vector2(14, -48)]:
				draw_circle(p + Vector2(sp.x * s, sp.y), 3, Color("#b45309"))
			for lx in [-10, 10]:
				draw_line(p + Vector2(lx * s, -12), p + Vector2(lx * s, 6), Color("#d97706"), 3)
		"penguen":
			draw_set_transform(p + Vector2(0, -12), (sin(_t * 6.0 + p.x) * 0.15 if a[2] else 0.0), Vector2(0.8, 1.2))
			draw_circle(Vector2.ZERO, 10, Color("#111827"))
			draw_circle(Vector2(0, 2), 7, Color("#f8fafc"))
			draw_set_transform(Vector2.ZERO)
			draw_colored_polygon(PackedVector2Array([p + Vector2(4 * s, -22), p + Vector2(10 * s, -20), p + Vector2(4 * s, -18)]), Color("#f59e0b"))
		"maymun":
			var jump := absf(sin(_t * 3.0 + p.x)) * 10.0 if a[2] else 0.0
			draw_circle(p + Vector2(0, -14 - jump), 10, Color("#78350f"))
			draw_circle(p + Vector2(0, -28 - jump), 8, Color("#92400e"))
			draw_circle(p + Vector2(2 * s, -27 - jump), 5, Color("#fcd34d"))
			draw_arc(p + Vector2(-10 * s, -10 - jump), 10, 0, PI, 10, Color("#78350f"), 3)
		"ayi":
			draw_set_transform(p + Vector2(0, -16 + bob), 0, Vector2(1.3, 0.9))
			draw_circle(Vector2.ZERO, 18, Color("#78350f"))
			draw_set_transform(Vector2.ZERO)
			draw_circle(p + Vector2(20 * s, -24 + bob), 11, Color("#78350f"))
			draw_circle(p + Vector2(26 * s, -22 + bob), 5, Color("#a16207"))
			draw_circle(p + Vector2(16 * s, -34 + bob), 4, Color("#78350f"))


func _draw_zoo() -> void:
	var z: Rect2 = Map.ZOO
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(200).intersects(z):
		return
	draw_rect(z, Color("#86a35f"))
	draw_rect(Rect2(z.position.x, z.get_center().y + 40, z.size.x, 40), Color("#d6c7a1"))
	draw_rect(Rect2(Map.ZOO_GATE.x - 30, z.position.y, 60, z.size.y), Color("#d6c7a1"))
	var terrain := {"aslan": Color("#d9b26a"), "fil": Color("#b8a06a"), "zurafa": Color("#c9b56a"), "penguen": Color("#e0f2fe"), "maymun": Color("#4d7c0f"), "ayi": Color("#6b8e4e")}
	for k in Map.ZOO_PENS:
		var r: Rect2 = Map.ZOO_PENS[k]
		draw_rect(r, terrain[k])
		if k == "penguen":
			draw_rect(Rect2(r.position.x + 20, r.position.y + 20, r.size.x * 0.5, r.size.y * 0.45), Color("#38bdf8"))
		if k == "maymun":
			for t in 3:
				draw_line(Vector2(r.position.x + 60 + t * 110, r.end.y - 20), Vector2(r.position.x + 60 + t * 110, r.position.y + 30), Color("#78350f"), 6)
		if k == "fil":
			draw_circle(r.position + Vector2(70, 70), 40, Color("#7dd3fc"))
		draw_rect(r, Color("#57534e"), false, 5)
		for x in range(int(r.position.x), int(r.end.x), 20):
			draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + 6), Color("#44403c"), 2)
		var label: String = Zoo.ANIMALS[k]
		if Zoo.feeding(Land.server_now()) == k:
			label += " — BESLEME SAATİ!"
			for j in 3:
				draw_circle(Vector2(r.get_center().x - 40 + j * 40, r.end.y - 14), 7, Color("#a16207"))
		_text(Vector2(r.position.x, r.end.y + 20), label, 14, Color("#fde68a"), r.size.x)
	# çit ve turnike
	draw_rect(z, Color("#44403c"), false, 6)
	var gx := Map.ZOO_GATE.x
	draw_rect(Rect2(gx - 50, z.position.y - 8, 100, 16), Color("#16a34a") if Zoo.has_ticket() else Color("#dc2626"))
	draw_rect(Rect2(gx - 80, z.position.y - 90, 160, 50), Color("#166534"))
	_text(Vector2(gx - 80, z.position.y - 60), "HAYVANAT BAHÇESİ", 14, Color("#fde68a"), 160, false)
	# bakıcı ofisi
	var kp: Vector2 = Map.ZOO_KEEPER
	draw_rect(Rect2(kp.x - 70, kp.y - 80, 140, 70), Color("#a16207"))
	draw_colored_polygon(PackedVector2Array([kp + Vector2(-80, -78), kp + Vector2(0, -110), kp + Vector2(80, -78)]), Color("#7c2d12"))
	_text(Vector2(kp.x - 70, kp.y - 40), "BAKICI", 13, Color.WHITE, 140, false)
	for j in 3:
		draw_rect(Rect2(kp.x + 76 + j * 18, kp.y - 24, 14, 18), Color("#6b7280"))


func _draw_korsan() -> void:
	var k: Rect2 = Map.KORSAN
	var vsize := get_viewport_rect().size / camera.zoom
	if not Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(300).intersects(k):
		return
	var c := k.get_center()
	draw_set_transform(c, 0, Vector2(1, k.size.y / k.size.x))
	draw_circle(Vector2.ZERO, k.size.x / 2.0 + 30, Color(0.55, 0.85, 0.95, 0.5))
	draw_circle(Vector2.ZERO, k.size.x / 2.0, Color("#e9d29c"))
	draw_circle(Vector2(-30, -10), k.size.x * 0.32, Color("#5a8f3c"))
	draw_set_transform(Vector2.ZERO)
	# iskele
	var pr: Rect2 = Map.KORSAN_PIER
	draw_rect(pr, Color("#7c5a2b"))
	for y in range(int(pr.position.y), int(pr.end.y), 14):
		draw_line(Vector2(pr.position.x, y), Vector2(pr.end.x, y), Color("#5b3a1e"), 2)
	# kafatası kayası
	var sk := c + Vector2(-60, 120)
	draw_circle(sk, 34, Color("#a8a29e"))
	draw_circle(sk + Vector2(-12, -6), 8, Color("#292524"))
	draw_circle(sk + Vector2(12, -6), 8, Color("#292524"))
	draw_rect(Rect2(sk.x - 10, sk.y + 12, 20, 14), Color("#a8a29e"))
	# karaya oturmuş korsan gemisi
	var sh: Vector2 = Map.KORSAN_SHIP
	draw_set_transform(sh, -0.12, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-120, -30), Vector2(110, -30), Vector2(90, 10), Vector2(-100, 10)]), Color("#5b3a1e"))
	for x in range(-110, 100, 24):
		draw_line(Vector2(x, -30), Vector2(x + 8, 10), Color("#3f2a14"), 2)
	draw_line(Vector2(-10, -30), Vector2(-14, -150), Color("#3f2a14"), 6)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -140), Vector2(60, -126), Vector2(54, -76), Vector2(-12, -86)]), Color("#e7e5e4"))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -150), Vector2(-50, -144), Vector2(-14, -136)]), Color("#111827"))
	draw_circle(Vector2(-30, -143), 3, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	_text(sh + Vector2(-100, -170), "BATIK KORSAN GEMİSİ", 13, Color("#fde68a"), 200)
	# kazı izleri
	for hpos in Pirates.holes:
		var hp := Vector2(float(hpos[0]), float(hpos[1]))
		draw_set_transform(hp, 0, Vector2(1, 0.5))
		draw_circle(Vector2.ZERO, 14, Color("#7c5a2b"))
		draw_circle(Vector2.ZERO, 9, Color("#5b3a1e"))
		draw_set_transform(Vector2.ZERO)
	# kaptan
	var cp: Vector2 = Map.KORSAN_CAPTAIN
	draw_set_transform(cp + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 15, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	Avatar.draw(self, cp, {"skin": 2, "hair": 4, "hair_color": 0, "shirt": 1, "pants": 3}, _facing_of(my_pos - cp) if my_pos.distance_to(cp) < 160 else "down", 0)
	draw_colored_polygon(PackedVector2Array([cp + Vector2(-18, -48), cp + Vector2(18, -48), cp + Vector2(12, -60), cp + Vector2(0, -66), cp + Vector2(-12, -60)]), Color("#111827"))
	draw_circle(cp + Vector2(0, -56), 3, Color.WHITE)
	draw_line(cp + Vector2(-8, -42), cp + Vector2(8, -38), Color("#111827"), 2)
	draw_circle(cp + Vector2(4, -38), 3, Color("#111827"))
	_text(cp + Vector2(-100, -84), "Korsan Kaptan Tek Göz Rıza", 13, Color("#fde68a"), 200)
	# hazine haritası varsa haritadaki X (kaba)
	if Pirates.state.get("has_map", false) and my_pos.distance_to(Pirates.map_hint) < 400.0:
		var x: Vector2 = Pirates.map_hint
		draw_line(x + Vector2(-14, -8), x + Vector2(14, 8), Color(0.8, 0.1, 0.1, 0.35), 4)
		draw_line(x + Vector2(-14, 8), x + Vector2(14, -8), Color(0.8, 0.1, 0.1, 0.35), 4)


func _draw_costume(p: Vector2, c: String) -> void:
	match c:
		"cadi":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -44), p + Vector2(18, -44), p + Vector2(4, -80), p + Vector2(10, -74)]), Color("#1e1b4b"))
			draw_rect(Rect2(p.x - 22, p.y - 46, 44, 5), Color("#1e1b4b"))
			draw_rect(Rect2(p.x - 14, p.y - 50, 28, 4), Color("#a855f7"))
		"hayalet":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -50), p + Vector2(18, -50), p + Vector2(20, 8), p + Vector2(10, 2), p + Vector2(0, 8), p + Vector2(-10, 2), p + Vector2(-20, 8)]), Color(0.97, 0.97, 1.0, 0.92))
			draw_circle(p + Vector2(-6, -34), 3, Color.BLACK)
			draw_circle(p + Vector2(6, -34), 3, Color.BLACK)
			draw_circle(p + Vector2(0, -24), 4, Color(0, 0, 0, 0.6))
		"vampir":
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -26), p + Vector2(16, -26), p + Vector2(24, 4), p + Vector2(-24, 4)]), Color("#111827"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-16, -26), p + Vector2(-22, -40), p + Vector2(-8, -28)]), Color("#991b1b"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(16, -26), p + Vector2(22, -40), p + Vector2(8, -28)]), Color("#991b1b"))
		"kabak":
			draw_circle(p + Vector2(0, -36), 15, Color("#f97316"))
			draw_rect(Rect2(p.x - 2, p.y - 56, 4, 6), Color("#166534"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -40), p + Vector2(-3, -40), p + Vector2(-5, -34)]), Color("#111827"))
			draw_colored_polygon(PackedVector2Array([p + Vector2(3, -40), p + Vector2(8, -40), p + Vector2(5, -34)]), Color("#111827"))
			draw_line(p + Vector2(-8, -30), p + Vector2(8, -30), Color("#111827"), 2)


func _draw_pumpkin(p: Vector2) -> void:
	draw_set_transform(p, 0, Vector2(1.2, 1.0))
	draw_circle(Vector2.ZERO, 11, Color("#ea580c"))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(p.x - 2, p.y - 15, 4, 5), Color("#166534"))
	var glow := Env.darkness() > 0.3
	var eye := Color("#fde047") if glow else Color("#111827")
	draw_colored_polygon(PackedVector2Array([p + Vector2(-7, -3), p + Vector2(-2, -3), p + Vector2(-4, 2)]), eye)
	draw_colored_polygon(PackedVector2Array([p + Vector2(2, -3), p + Vector2(7, -3), p + Vector2(4, 2)]), eye)
	draw_line(p + Vector2(-6, 5), p + Vector2(6, 5), eye, 2)
	if glow:
		draw_circle(p, 22, Color(1.0, 0.6, 0.1, 0.12))


func _draw_holiday() -> void:
	var h := Holidays.active
	if h == "" or _room >= 0 or _dive or _mount or _fair:
		return
	var vsize := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize).grow(100)
	# tezgâh
	var st: Vector2 = Holidays.STALL
	var col: Color = {"cadilar": Color("#7c3aed"), "yilbasi": Color("#dc2626"), "sevgililer": Color("#ec4899")}.get(h, Color("#dc2626"))
	draw_rect(Rect2(st.x - 60, st.y - 60, 120, 56), Color("#fef3c7"))
	for k in 6:
		draw_rect(Rect2(st.x - 64 + k * 21, st.y - 80, 21, 22), col if k % 2 == 0 else Color.WHITE)
	_text(Vector2(st.x - 70, st.y - 34), U.upper_tr(Holidays.NAMES[h]), 11, Color("#7c2d12"), 140, false)
	match h:
		"cadilar":
			for b in Map.BUILDINGS:
				var d: Vector2 = Holidays.door_pos("b:" + str(b.type)) + Vector2(-50, -6)
				if view.has_point(d):
					_draw_pumpkin(d)
			for i in mini(Land.view.size(), Map.PLOT_COUNT):
				if int(Land.view[i].level) >= 1:
					var pd := Map.plot_front(i) + Vector2(36, 10)
					if view.has_point(pd):
						_draw_pumpkin(pd)
			if Env.darkness() > 0.3:
				for k in 10:
					var bp := view.position + Vector2(fposmod(k * 211.0 + _t * (60.0 + k * 9.0), view.size.x), fmod(k * 97.0, view.size.y * 0.6) + sin(_t * 3.0 + k) * 20.0)
					var flap := sin(_t * 18.0 + k) * 6.0
					draw_colored_polygon(PackedVector2Array([bp, bp + Vector2(-14, -6 + flap), bp + Vector2(-8, 2)]), Color("#111827"))
					draw_colored_polygon(PackedVector2Array([bp, bp + Vector2(14, -6 + flap), bp + Vector2(8, 2)]), Color("#111827"))
					draw_circle(bp, 3, Color("#111827"))
		"yilbasi":
			var t: Vector2 = Holidays.TREE
			draw_rect(Rect2(t.x - 6, t.y - 14, 12, 16), Color("#78350f"))
			for k in 4:
				var w := 46.0 - k * 9.0
				var y := t.y - 14 - k * 26.0
				draw_colored_polygon(PackedVector2Array([Vector2(t.x - w, y), Vector2(t.x + w, y), Vector2(t.x, y - 40)]), Color("#166534"))
			for k in 14:
				var a := float(k) * 1.7
				var lp := t + Vector2(sin(a) * (30.0 - k * 1.5), -24.0 - k * 7.0)
				draw_circle(lp, 3, Color.from_hsv(fmod(k * 0.13 + _t * 0.3, 1.0), 0.8, 1.0))
			_draw_star(t + Vector2(0, -132), 10, Color("#facc15"))
			var sa: Vector2 = Holidays.SANTA
			Avatar.draw(self, sa, {"skin": 1, "hair": 0, "hair_color": 6, "shirt": 1, "pants": 1}, "down", 0)
			draw_colored_polygon(PackedVector2Array([sa + Vector2(-14, -46), sa + Vector2(14, -46), sa + Vector2(12, -66)]), Color("#dc2626"))
			draw_circle(sa + Vector2(12, -66), 4, Color.WHITE)
			draw_circle(sa + Vector2(0, -28), 10, Color(1, 1, 1, 0.95))
			_text(sa + Vector2(-60, -84), "Noel Baba", 14, Color("#fde68a"), 120)
			draw_rect(Rect2(sa.x + 18, sa.y - 22, 22, 26), Color("#7c2d12"))
			for g in Holidays.gifts:
				var gp := Vector2(float(g.x), float(g.y))
				if view.has_point(gp):
					draw_rect(Rect2(gp.x - 11, gp.y - 18, 22, 18), Color("#dc2626"))
					draw_rect(Rect2(gp.x - 2, gp.y - 18, 4, 18), Color("#facc15"))
					draw_rect(Rect2(gp.x - 11, gp.y - 11, 22, 4), Color("#facc15"))
					draw_circle(gp + Vector2(0, -20), 4, Color("#facc15"))
			for lp in Map.lamp_positions():
				if view.has_point(lp):
					for k in 4:
						draw_circle(lp + Vector2(-9 + k * 6, -30 + (k % 2) * 4), 2.5, Color.from_hsv(fmod(k * 0.25 + _t * 0.5, 1.0), 0.8, 1.0))
			if Env.season != "winter":
				for i in 50:
					var sx := view.position.x + fmod(i * 97.3 + sin(_t * 0.6 + i) * 30.0, view.size.x)
					var sy := view.position.y + fmod(i * 53.7 + _t * (40.0 + (i % 5) * 10.0), view.size.y)
					draw_circle(Vector2(sx, sy), 1.8, Color(1, 1, 1, 0.75))
		"ramazan", "kurban":
			for lp in Map.lamp_positions():
				if view.has_point(lp):
					draw_rect(Rect2(lp.x + 2, lp.y - 34, 18, 12), Color("#dc2626"))
					draw_circle(lp + Vector2(9, -28), 3, Color.WHITE)
		"sevgililer":
			for k in 12:
				var hp := view.position + Vector2(fmod(k * 173.0, view.size.x), view.size.y - fmod(_t * 25.0 + k * 77.0, view.size.y))
				draw_circle(hp + Vector2(-4, 0), 5, Color(0.93, 0.28, 0.6, 0.6))
				draw_circle(hp + Vector2(4, 0), 5, Color(0.93, 0.28, 0.6, 0.6))
				draw_colored_polygon(PackedVector2Array([hp + Vector2(-9, 1), hp + Vector2(9, 1), hp + Vector2(0, 11)]), Color(0.93, 0.28, 0.6, 0.6))


## Maraton noktaları (koşu sürerken).
func _draw_marathon() -> void:
	if not Gym.run.is_empty():
		for i in range(1, Map.MARATHON.size()):
			var mp: Vector2 = Map.MARATHON[i]
			var done := i < int(Gym.run.get("cp", 1))
			draw_rect(Rect2(mp.x - 2, mp.y - 60, 4, 60), Color("#374151"))
			draw_colored_polygon(PackedVector2Array([mp + Vector2(2, -60), mp + Vector2(30, -52), mp + Vector2(2, -44)]), Color("#94a3b8") if done else Color("#22c55e"))
			_text(mp + Vector2(-20, -68), str(i), 13, Color.WHITE, 40)


# ================================================================== 1.6: Açık Okyanus

const OM = preload("res://scripts/ocean_map.gd")
const OCEAN_WATER := Color("#12558c")
const ISLAND_TREE := {"tropik": 3, "kayalik": 1, "mangrov": 2, "volkanik": -1, "buzul": 1, "batik": 0}


func _ocean_can_stand(p: Vector2, ride: String) -> bool:
	if ride == "boat":
		# tekne karaya ve iskeleye giremez (kıyıdan 20 px açıkta kalır)
		return OM.island_at(p, 20.0) < 0 or OM.island_at(my_pos, 20.0) >= 0      # karaya oturduysan kurtulabilirsin
	return OM.is_land(p) or OM.on_pier(p)


func _ocean_tick(delta: float) -> void:
	_ocean_acc += delta
	if _ocean_acc >= 0.4:
		_ocean_acc = 0.0
		Ocean.reveal_around(my_pos, 950.0)
	_ocean_flush += delta
	if _ocean_flush >= 2.0:
		_ocean_flush = 0.0
		Ocean.flush_seen()
	if my_ride() == "boat" and my_moving and randf() < delta * 4.0 and Ocean.storm_at(my_pos):
		add_fx("water", my_pos + Vector2(randf_range(-40, 40), randf_range(-20, 10)), 0.8)


## Okyanusta F: iskeleden/kıyıdan tekneye bin ya da kıyıya/iskeleye in.
func _ocean_toggle_vehicle() -> void:
	var ride := my_ride()
	if ride == "boat":
		var spot = _ocean_land_near(my_pos)
		if spot == null:
			hud.show_toast("Tekneden inmek için bir adanın kıyısına ya da iskelesine yanaş.", false)
			return
		my_pos = spot
		Garage.ride("")
		return
	if ride != "":
		Garage.ride("")
		return
	if not Garage.owned.has("boat"):
		hud.show_toast("Okyanusta kendi teknen gerekli (Galeri'den Sürat Teknesi).", false)
		return
	var w = _ocean_water_near(my_pos)
	if w == null:
		hud.show_toast("Tekneye binmek için iskelenin ucuna ya da kıyıya git.", false)
		return
	my_pos = w
	Garage.ride("boat", w)
	Sfx.play("splash_small")


func _ocean_water_near(p: Vector2) -> Variant:
	for dist in [40.0, 70.0, 100.0, 130.0]:
		for k in 12:
			var q: Vector2 = p + Vector2.RIGHT.rotated(TAU * k / 12.0) * dist
			if OM.in_ocean(q) and OM.island_at(q, 20.0) < 0:
				return q
	return null


func _ocean_land_near(p: Vector2) -> Variant:
	for dist in [20.0, 45.0, 70.0, 95.0, 120.0]:
		for k in 16:
			var q: Vector2 = p + Vector2.RIGHT.rotated(TAU * k / 16.0) * dist
			if OM.on_pier(q) or OM.is_land(q):
				return q
	return null


func _update_ocean_zone() -> void:
	var z := {}
	var boat := my_ride() == "boat"
	var isl_list := OM.islands()
	for isl in isl_list:
		var c: Vector2 = isl.c
		if c.distance_to(my_pos) > float(isl.r) + 400.0:
			continue
		if not boat and my_pos.distance_to(isl.chest) < 80.0:
			var last := float(Ocean.my.chest.get(str(int(isl.id)), 0.0))
			var left := Ocean.CHEST_COOLDOWN - (Time.get_unix_time_from_system() - last)
			z = {"type": "ocean_chest", "i": int(isl.id), "label": ("%s sandığını aç" % isl.name) if left <= 0.0 else "Sandık boş (%d dk sonra dolar)" % int(ceil(left / 60.0))}
		if isl.lighthouse and not boat and my_pos.distance_to(Ocean.lighthouse_pos(isl)) < 100.0:
			z = {"type": "ocean_light", "i": int(isl.id), "label": "Feneri yak (çevre haritada açılır)" if not int(isl.id) in Ocean.my.lit else "Fener yanıyor ✓"}
		if (isl.fuel or isl.shipyard) and my_pos.distance_to(isl.dock) < 200.0:
			z = {"type": "ocean_fuel", "port": int(isl.id), "label": "Liman: yakıt ve ticaret (%s satılır)" % Cargo.GOODS[Cargo.local_good(int(isl.id))].name}
		z = _isle_zone(isl, z, boat)
		if isl.shipyard and my_pos.distance_to(_shipyard_pos()) < 150.0:
			z = {"type": "tersane", "label": "Tersane — yükseltme ve tamir"}
		if isl.shipyard and not boat and my_pos.distance_to(Airport.AIRSTRIP) < 110.0:
			z = {"type": "terminal", "label": "Pist — şehre uç"}
	if boat and my_pos.distance_to(OM.ARRIVE) < 240.0:
		z = {"type": "ocean_exit", "label": "Şehrin açıklarına dön"}
	if boat and not Ocean.kraken.is_empty() and my_pos.distance_to(_kraken_pos()) < Ocean.HARPOON_RANGE:
		z = {"type": "ocean_harpoon", "target": "kraken", "label": "ZIPKIN AT! (basılı tut)"}
	if boat:
		for o in Cargo.raids:
			if my_pos.distance_to(_raid_pos(o)) < Ocean.HARPOON_RANGE:
				z = {"type": "ocean_harpoon", "target": "raid", "owner": o, "label": "Korsan gemisine zıpkın! (%d/%d)" % [int(Cargo.raids[o].hits), Cargo.RAID_HITS]}
	zone = z
	var o: Dictionary = Ocean.my
	var st := "Yakıt %d/%d L   ·   Gövde %d%%" % [int(o.fuel), int(Ocean.max_fuel(o.up)), int(o.hp)]
	if float(o.fuel) <= 0.0:
		st += "   ·   YAKIT BİTTİ (kürek hızı)"
	if boat and Ocean.storm_at(my_pos):
		st += "   ·   FIRTINA!"
	if not Ocean.kraken.is_empty():
		st += "   ·   KRAKEN %d/%d" % [int(Ocean.kraken.hp), int(Ocean.kraken.max)]
	if Cargo.used() > 0:
		st += "   ·   Ambar %d/%d" % [Cargo.used(), Cargo.capacity(o.up)]
	if Cargo.raids.has(Net.my_name):
		st += "   ·   KORSANLAR PEŞİNDE!"
	var hint := st if z.is_empty() else "[%s]  %s\n%s" % [Settings.key_name("interact"), z.label, st]
	hud.set_hint("" if panel != null else hint)


func _shipyard_pos() -> Vector2:
	return OM.HOME + Vector2(-150, 60)


func _kraken_pos() -> Vector2:
	var k: Dictionary = Ocean.kraken
	return Vector2(float(k.get("x", 0.0)), float(k.get("y", 0.0))) + Vector2(sin(_t * 0.5) * 30.0, cos(_t * 0.4) * 18.0)


## Okyanus bölgesinin E işlemleri. true: işlendi.
func _ocean_interact() -> bool:
	match str(zone.get("type", "")):
		"ocean_gate":
			Ocean.enter()
			Sfx.play("splash")
		"ocean_exit":
			Ocean.leave()
			Sfx.play("splash")
		"ocean_fuel":
			if panel == null:
				panel = PANELS["port"].new()
				panel.port = int(zone.get("port", -1))
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
		"ocean_chest":
			Ocean.open_chest(int(zone.i))
			Sfx.play("open")
		"ocean_light":
			Ocean.light(int(zone.i))
			Sfx.play("success", -4.0)
		"ocean_harpoon":
			_harpoon()
		"tersane":
			if panel == null:
				panel = preload("res://scripts/ui/shipyard_panel.gd").new()
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
		_:
			return false
	return true


func _harpoon() -> void:
	if _t - _harp_t < Ocean.HARPOON_COOLDOWN:
		return
	_harp_t = _t
	var kp := _kraken_pos()
	if str(zone.get("target", "")) == "raid":
		Cargo.harpoon_raid(str(zone.owner))
		kp = _raid_pos(str(zone.owner))
	else:
		Ocean.harpoon()
	add_fx("harpoon", my_pos + Vector2(0, -20), 0.35, {"to": kp})
	add_fx("water", kp + Vector2(randf_range(-40, 40), randf_range(-20, 20)), 0.7)
	Sfx.play("splash_small", -4.0, 1.4)


func open_ocean_map() -> void:
	if panel != null:
		return
	panel = preload("res://scripts/ui/ocean_map_panel.gd").new()
	panel.world = self
	panel.closed.connect(_close_panel)
	ui_layer.add_child(panel)
	Sfx.play("open", -6.0)


func _view_rect() -> Rect2:
	var vsize := get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - vsize / 2.0, vsize)


func _scaled_shape(isl: Dictionary, k: float, add: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var c: Vector2 = isl.c
	for pt in isl.shape:
		var d: Vector2 = pt - c
		out.append(c + d * k + d.normalized() * add)
	return out


func _draw_ocean_world() -> void:
	var view := _view_rect().grow(200)
	draw_rect(view.intersection(OM.OCEAN.grow(3000)), OCEAN_WATER)
	if not OM.OCEAN.encloses(view):
		# okyanusun kenarı: sis duvarı
		var edge := Color(0.75, 0.82, 0.9, 0.85)
		for r in [Rect2(view.position.x, view.position.y, OM.OCEAN.position.x - view.position.x, view.size.y),
				Rect2(OM.OCEAN.end.x, view.position.y, view.end.x - OM.OCEAN.end.x, view.size.y),
				Rect2(view.position.x, view.position.y, view.size.x, OM.OCEAN.position.y - view.position.y),
				Rect2(view.position.x, OM.OCEAN.end.y, view.size.x, view.end.y - OM.OCEAN.end.y)]:
			if r.size.x > 0 and r.size.y > 0:
				draw_rect(r, edge)
	# dalga çizgileri (görünen alanda, sabit ızgaraya bağlı)
	var g := 140
	for gx in range(int(view.position.x / g) * g, int(view.end.x), g):
		for gy in range(int(view.position.y / g) * g, int(view.end.y), g):
			var hsh := absi(int(gx * 73856093) ^ int(gy * 19349663))
			if hsh % 3 != 0:
				continue
			var wp := Vector2(gx + (hsh % 97), gy + (hsh % 61))
			var a := 0.12 + 0.12 * sin(_t * 1.6 + float(hsh % 100))
			draw_line(wp, wp + Vector2(18, 0), Color(1, 1, 1, a), 2)
			draw_line(wp + Vector2(18, 0), wp + Vector2(26, -3), Color(1, 1, 1, a * 0.7), 2)
	var items: Array = []
	for isl in OM.islands():
		var c: Vector2 = isl.c
		if not view.grow(float(isl.r) * 1.4).has_point(c):
			continue
		_draw_ocean_island(isl, items)
	# fırtınalar (yağmur halkası ve koyu bulut)
	for s in Ocean.storm_positions():
		var sp: Vector2 = s[0]
		var sr: float = s[1]
		if not view.grow(sr).has_point(sp):
			continue
		draw_circle(sp, sr, Color(0.06, 0.09, 0.16, 0.35))
		draw_circle(sp, sr * 0.7, Color(0.05, 0.07, 0.12, 0.25))
		for k in 40:
			var a := float(k) * 2.39
			var rr := sr * fmod(float(k) * 0.37 + _t * 0.15, 1.0)
			var rp := sp + Vector2(cos(a), sin(a)) * rr
			draw_line(rp, rp + Vector2(-6, 18), Color(0.75, 0.85, 1.0, 0.45), 1.5)
		if fmod(_t + sp.x * 0.001, 6.0) < 0.12:
			draw_circle(sp, sr, Color(1, 1, 1, 0.12))       # şimşek
	# Kraken ve korsan gemileri
	if not Ocean.kraken.is_empty():
		var kp := _kraken_pos()
		if view.grow(300).has_point(kp):
			items.append([kp.y, "kraken", kp])
	for o in Cargo.raids:
		var rp := _raid_pos(o)
		if view.grow(200).has_point(rp):
			items.append([rp.y, "raid", [rp, o]])
	# oyuncular
	for id in shown:
		var info = Net.roster.get(id)
		if info and OM.in_ocean(shown[id]):
			var a: Dictionary = anim.get(id, {"facing": "down", "moving": false})
			items.append([shown[id].y, "p", [shown[id], info.get("appearance", {}), _name_of(info), false, a.facing, a.moving, str(info.get("ride", "")), info.get("color", Color.WHITE), info]])
	var mine = Net.roster.get(Net.my_id())
	if mine:
		items.append([my_pos.y, "p", [my_pos, mine.get("appearance", {}), _name_of(mine), true, my_facing, my_moving, my_ride(), mine.get("color", Color.WHITE), mine]])
	for id in npc.pets:
		var pinfo = Net.roster.get(id)
		var pst: Dictionary = npc.pets[id]
		if pinfo and pinfo.get("pet") is Dictionary and not pinfo.pet.is_empty() and OM.in_ocean(pst.pos):
			items.append([pst.pos.y + (6.0 if pst.get("in_boat", false) else 0.0), "pet", [pst, pinfo.pet]])
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match str(it[1]):
			"palm", "tree", "bush":
				_draw_tex_at(PROPS[int(it[2][1])][0], it[2][0], PROPS[int(it[2][1])][1] * float(it[2][2]),
					Color(0.85, 0.95, 1.0) if it[2][3] == "buzul" else Color.WHITE)
			"rock":
				var rp: Vector2 = it[2][0]
				var rs: float = it[2][1]
				draw_colored_polygon(PackedVector2Array([rp + Vector2(-rs, 0), rp + Vector2(-rs * 0.6, -rs * 0.9), rp + Vector2(rs * 0.3, -rs * 1.1), rp + Vector2(rs, -rs * 0.2), rp + Vector2(rs * 0.8, 0)]), it[2][2])
				draw_line(rp + Vector2(-rs * 0.6, -rs * 0.9), rp + Vector2(rs * 0.3, -rs * 1.1), Color(1, 1, 1, 0.25), 2)
			"column":
				var cp: Vector2 = it[2][0]
				var ch: float = it[2][1]
				draw_rect(Rect2(cp.x - 9, cp.y - ch, 18, ch), Color("#e7e0c9"))
				draw_rect(Rect2(cp.x - 13, cp.y - ch - 6, 26, 7), Color("#d6cfb4"))
				draw_rect(Rect2(cp.x - 13, cp.y - 5, 26, 6), Color("#d6cfb4"))
				for k in 3:
					draw_line(Vector2(cp.x - 5 + k * 5, cp.y - ch + 2), Vector2(cp.x - 5 + k * 5, cp.y - 6), Color(0, 0, 0, 0.12), 1.5)
			"lighthouse":
				_draw_ocean_lighthouse(it[2][0], bool(it[2][1]))
			"chest":
				_draw_ocean_chest(it[2][0], bool(it[2][1]))
			"shipyard":
				_draw_shipyard(it[2])
			"pump":
				_draw_fuel_pump(it[2])
			"kraken":
				_draw_kraken(it[2])
			"raid":
				_draw_raid_ship(it[2][0], it[2][1])
			"house":
				_draw_isle_house(it[2][0], int(it[2][1]), str(it[2][2]))
			"isign":
				_draw_isle_sign(it[2])
			"pet":
				_draw_pet(it[2][0], it[2][1])
			"p":
				var a: Array = it[2]
				_draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
	for isl in OM.islands():
		var c: Vector2 = isl.c
		if view.has_point(c):
			var seen_it: bool = int(isl.id) in Ocean.my.found
			var top := c + Vector2(-140, -float(isl.r) * float(isl.sq) * 1.25 - 52)
			if Vector2(isl.dock_dir).y < -0.5:
				top = c + Vector2(-140, float(isl.r) * float(isl.sq) * 1.25 + 20)       # iskele kuzeydeyse ad güneyde
			_text(top, str(isl.name) + ("" if seen_it else " (yeni!)"), 20, Color(1, 1, 1, 0.95), 280)
			_text(top + Vector2(0, 20), OM.TYPES[isl.type].name + "  " + "★".repeat(int(isl.tier)), 14, Color("#fde68a"), 280)
	if view.has_point(OM.ARRIVE):
		_text(OM.ARRIVE + Vector2(-120, 60), "← ŞEHRE DÖNÜŞ (E)", 14, Color("#fde68a"), 240)
		for k in 6:
			var bp := OM.ARRIVE + Vector2(-150 + k * 60, 40 + sin(_t * 1.5 + k) * 3.0)
			draw_circle(bp, 7, Color("#f97316"))
			draw_circle(bp + Vector2(0, -3), 3, Color.WHITE)
	_draw_fx()
	_draw_nav()


func _draw_ocean_island(isl: Dictionary, items: Array) -> void:
	var t: String = isl.type
	var ty: Dictionary = OM.TYPES[t]
	var c: Vector2 = isl.c
	var r: float = isl.r
	var sq: float = isl.sq
	var shallow := Color("#3aa0c8") if t != "buzul" else Color("#9fd3e6")
	if t == "batik":
		shallow = Color("#3fc1c9")
	draw_colored_polygon(_scaled_shape(isl, 1.0, 60.0 + sin(_t * 0.8 + c.x) * 4.0), Color(shallow, 0.55))
	draw_colored_polygon(_scaled_shape(isl, 1.0, 26.0), shallow)
	draw_colored_polygon(_scaled_shape(isl, 1.0, 6.0 + sin(_t * 1.4 + c.y) * 2.0), Color(1, 1, 1, 0.55))
	draw_colored_polygon(isl.shape, ty.sand)
	draw_colored_polygon(_scaled_shape(isl, 0.78), ty.land)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(isl.id) * 7919 + 13
	match t:
		"volkanik":
			var cr := c + Vector2(0, -r * 0.08 * sq)
			draw_colored_polygon(_ellipse(Rect2(cr - Vector2(r * 0.42, r * 0.3 * sq), Vector2(r * 0.84, r * 0.6 * sq)), 24), Color("#57483f"))
			draw_colored_polygon(_ellipse(Rect2(cr - Vector2(r * 0.22, r * 0.15 * sq), Vector2(r * 0.44, r * 0.3 * sq)), 20), Color("#7f1d1d"))
			draw_colored_polygon(_ellipse(Rect2(cr - Vector2(r * 0.15, r * 0.1 * sq), Vector2(r * 0.3, r * 0.2 * sq)), 20),
				Color(1.0, 0.45 + 0.15 * sin(_t * 2.0), 0.1))
			for k in 4:
				var u := fmod(_t * 0.25 + k * 0.25, 1.0)
				draw_circle(cr + Vector2(sin(k * 1.7 + _t * 0.3) * 20.0, -u * 200.0), 18.0 + u * 30.0, Color(0.35, 0.33, 0.33, 0.45 * (1.0 - u)))
			for k in 6:
				var a := rng.randf() * TAU
				items.append([c.y + sin(a) * r * 0.6 * sq, "rock", [c + Vector2(cos(a) * r * 0.6, sin(a) * r * 0.6 * sq), rng.randf_range(14, 26), Color("#2b2522")]])
		"buzul":
			for k in 7:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.2, 0.65)
				var ip := c + Vector2(cos(a) * r * d, sin(a) * r * d * sq)
				items.append([ip.y, "rock", [ip, rng.randf_range(16, 30), Color("#cfe8f5")]])
			for k in 8:
				var a := rng.randf() * TAU
				var fp := c + Vector2(cos(a), sin(a) * sq) * (r + 90.0 + rng.randf() * 60.0)
				draw_colored_polygon(_ellipse(Rect2(fp - Vector2(24, 10), Vector2(48, 20)), 10), Color("#f1f8fb"))   # yüzen buz
		"batik":
			for k in 7:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.15, 0.6)
				var cp := c + Vector2(cos(a) * r * d, sin(a) * r * d * sq)
				items.append([cp.y, "column", [cp, rng.randf_range(30, 70)]])
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.2 * sq), Vector2(r * 0.6, r * 0.12)), Color("#b9ae8c"))
			for k in 6:
				var a := rng.randf() * TAU
				var wp := c + Vector2(cos(a), sin(a) * sq) * (r + 40.0)
				draw_rect(Rect2(wp - Vector2(10, 6), Vector2(20, 12)), Color(0.8, 0.76, 0.6, 0.6))   # sudaki harabe
		"mangrov":
			for k in 4:
				var a := rng.randf() * TAU
				var mp := c + Vector2(cos(a) * r * 0.35, sin(a) * r * 0.35 * sq)
				draw_colored_polygon(_ellipse(Rect2(mp - Vector2(40, 14), Vector2(80, 28)), 12), Color("#2f6f8f"))   # bataklık gölcükleri
		"kayalik":
			for k in 6:
				var a := rng.randf() * TAU
				var d := rng.randf_range(0.2, 0.75)
				var kp := c + Vector2(cos(a) * r * d, sin(a) * r * d * sq)
				items.append([kp.y, "rock", [kp, rng.randf_range(14, 32), Color("#8b8578")]])
	var own: Dictionary = Isles.view.get(str(int(isl.id)), {})
	var spots := {}
	if int(isl.id) in _sale_ids():
		spots = Isles.spots(isl)
		items.append([spots.sign.y, "isign", isl])
		if not own.is_empty():
			_draw_isle_ground(isl, own, spots, items)
	var tree: int = ISLAND_TREE[t]
	if tree >= 0:
		for k in isl.deco.size():
			var dp: Vector2 = isl.deco[k]
			if not own.is_empty() and (dp.distance_to(spots.house) < 110.0 or dp.distance_to(spots.pool) < 80.0 or dp.distance_to(spots.garden) < 70.0):
				continue
			if dp.distance_to(isl.chest) < 50.0 or isl.lighthouse and dp.distance_to(Ocean.lighthouse_pos(isl)) < 60.0:
				continue
			if isl.shipyard and (dp.distance_to(_shipyard_pos()) < 130.0 or dp.distance_to(Airport.AIRSTRIP) < 120.0):
				continue
			if k % (2 if t == "buzul" or t == "batik" else 1) != 0:
				continue
			var kind := tree if k % 3 != 0 or t != "tropik" else 2
			items.append([dp.y, "palm", [dp, kind, 0.8 + 0.25 * float((k * 37) % 10) / 10.0, t]])
	# iskele
	var a0: Vector2 = Vector2(isl.dock) - Vector2(isl.dock_dir) * 40.0
	var b0 := OM.pier_end(isl)
	var side: Vector2 = Vector2(isl.dock_dir).orthogonal() * 16.0
	draw_colored_polygon(PackedVector2Array([a0 + side, b0 + side, b0 - side, a0 - side]), Color("#a0703c"))
	for k in 8:
		var pp := a0.lerp(b0, k / 7.0)
		draw_line(pp + side, pp - side, Color("#6b4423"), 2)
	draw_polyline(PackedVector2Array([a0 + side, b0 + side, b0 - side, a0 - side, a0 + side]), Color("#232634"), 2)
	if isl.fuel:
		items.append([b0.y - 10.0, "pump", b0 + side * 1.6])
	if isl.lighthouse:
		var lp := Ocean.lighthouse_pos(isl)
		items.append([lp.y, "lighthouse", [lp, int(isl.id) in Ocean.my.lit]])
	var last := float(Ocean.my.chest.get(str(int(isl.id)), 0.0))
	items.append([float(isl.chest.y), "chest", [isl.chest, Time.get_unix_time_from_system() - last >= Ocean.CHEST_COOLDOWN]])
	if isl.shipyard:
		items.append([_shipyard_pos().y, "shipyard", _shipyard_pos()])
		var ap: Vector2 = Airport.AIRSTRIP
		draw_rect(Rect2(ap.x - 110, ap.y - 22, 220, 44), Color("#3f4148"))
		for k in 6:
			draw_rect(Rect2(ap.x - 95 + k * 36, ap.y - 2, 20, 4), Color.WHITE)
		_text(ap + Vector2(-110, -30), "PİST — şehre uçuş", 12, Color.WHITE, 220)


func _draw_ocean_lighthouse(l: Vector2, lit: bool) -> void:
	draw_set_transform(l + Vector2(0, 6), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 26, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([l + Vector2(-20, 0), l + Vector2(20, 0), l + Vector2(12, -100), l + Vector2(-12, -100)]), Color("#f8fafc"))
	for k in 3:
		var y0 := -16.0 - k * 30.0
		draw_rect(Rect2(l.x - 18 + k * 2.5, l.y + y0 - 12, 36 - k * 5.0, 12), Color("#dc2626"))
	draw_rect(Rect2(l.x - 15, l.y - 118, 30, 18), Color("#334155"))
	draw_rect(Rect2(l.x - 10, l.y - 114, 20, 11), Color("#fde68a") if lit else Color("#64748b"))
	draw_colored_polygon(PackedVector2Array([l + Vector2(-18, -118), l + Vector2(18, -118), l + Vector2(0, -134)]), Color("#991b1b"))
	if lit:
		var ang := _t * 0.9
		var src := l + Vector2(0, -108)
		var dir := Vector2(cos(ang), sin(ang) * 0.45)
		var sd := dir.orthogonal() * 0.18
		draw_colored_polygon(PackedVector2Array([src, src + (dir + sd) * 520.0, src + (dir - sd) * 520.0]), Color(1, 0.95, 0.7, 0.1 + 0.15 * Env.darkness()))


func _draw_ocean_chest(p: Vector2, full: bool) -> void:
	draw_set_transform(p + Vector2(0, 6), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(p.x - 18, p.y - 16, 36, 22), Color("#92400e"))
	if full:
		draw_rect(Rect2(p.x - 18, p.y - 24, 36, 10), Color("#b45309"))
		draw_rect(Rect2(p.x - 3, p.y - 16, 6, 7), Color("#facc15"))
		for k in 4:
			var a := _t * 1.8 + k * TAU / 4.0
			draw_circle(p + Vector2(cos(a), sin(a) * 0.5) * 26.0 + Vector2(0, -10), 2.5, Color(1, 0.95, 0.4, 0.5 + 0.4 * sin(_t * 5 + k)))
	else:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-18, -16), p + Vector2(18, -16), p + Vector2(14, -34), p + Vector2(-14, -34)]), Color("#78350f"))
	draw_rect(Rect2(p.x - 18, p.y - 16, 36, 22), Color("#451a03"), false, 2)


func _draw_fuel_pump(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 10, p.y - 40, 20, 40), Color("#dc2626"))
	draw_rect(Rect2(p.x - 7, p.y - 34, 14, 10), Color("#fef3c7"))
	draw_line(p + Vector2(10, -24), p + Vector2(18, -10), Color("#111827"), 3)
	_text(p + Vector2(-50, -50), "YAKIT", 12, Color("#fde68a"), 100)


func _draw_shipyard(p: Vector2) -> void:
	draw_rect(Rect2(p.x - 80, p.y - 70, 160, 70), Color("#475569"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-90, -70), p + Vector2(90, -70), p + Vector2(60, -100), p + Vector2(-60, -100)]), Color("#1e293b"))
	draw_rect(Rect2(p.x - 30, p.y - 44, 60, 44), Color("#0f172a"))
	draw_line(p + Vector2(70, 0), p + Vector2(70, -150), Color("#f59e0b"), 5)       # vinç
	draw_line(p + Vector2(70, -150), p + Vector2(150, -150), Color("#f59e0b"), 4)
	draw_line(p + Vector2(140, -150), p + Vector2(140, -90 + sin(_t) * 6.0), Color("#111827"), 2)
	_text(p + Vector2(-90, -112), "TERSANE", 15, Color.WHITE, 180)


func _draw_kraken(p: Vector2) -> void:
	var k: Dictionary = Ocean.kraken
	draw_circle(p, 150, Color(0.02, 0.05, 0.1, 0.35))
	for i in 8:
		var a := TAU * i / 8.0 + sin(_t * 0.6) * 0.2
		var pts := PackedVector2Array()
		for s in 9:
			var u := s / 8.0
			var wav := sin(_t * 3.0 + i + u * 5.0) * 22.0 * u
			pts.append(p + Vector2(cos(a), sin(a) * 0.6) * (40.0 + u * 170.0) + Vector2(cos(a), sin(a)).orthogonal() * wav + Vector2(0, -u * 30.0 * absf(sin(_t * 1.5 + i))))
		draw_polyline(pts, Color("#7e22ce"), 18.0 - 0.0)
		draw_polyline(pts, Color("#a855f7"), 9.0)
		for s in range(2, 9, 2):
			draw_circle(pts[s], 3.0, Color("#f5d0fe"))
	draw_colored_polygon(_ellipse(Rect2(p + Vector2(-60, -110), Vector2(120, 130)), 24), Color("#6b21a8"))
	draw_circle(p + Vector2(-24, -40), 13, Color("#fef08a"))
	draw_circle(p + Vector2(24, -40), 13, Color("#fef08a"))
	draw_rect(Rect2(p.x - 26, p.y - 48, 5, 16), Color.BLACK)
	draw_rect(Rect2(p.x + 22, p.y - 48, 5, 16), Color.BLACK)
	var mx := float(k.get("max", 1))
	var frac := clampf(float(k.get("hp", 0)) / maxf(1.0, mx), 0.0, 1.0)
	draw_rect(Rect2(p.x - 100, p.y - 150, 200, 14), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(p.x - 98, p.y - 148, 196 * frac, 10), Color("#ef4444"))
	_text(p + Vector2(-100, -160), "KRAKEN  %d / %d" % [int(k.get("hp", 0)), int(mx)], 15, Color("#fecaca"), 200)


## Şehirde: okyanusa açılma şeridi (şamandıralar ve tabela).
func _draw_ocean_gate() -> void:
	var g: Rect2 = Ocean.GATE
	if not _view_rect().grow(300).intersects(g):
		return
	for y in range(int(g.position.y), int(g.end.y), 70):
		var bp := Vector2(g.position.x, y + sin(_t * 1.5 + y) * 3.0)
		draw_circle(bp, 7, Color("#22c55e"))
		draw_circle(bp + Vector2(0, -3), 3, Color.WHITE)
	var sp := Vector2(g.get_center().x, g.position.y + 40)
	draw_rect(Rect2(sp.x - 3, sp.y - 60, 6, 60), Color("#5b3a1e"))
	draw_rect(Rect2(sp.x - 80, sp.y - 104, 160, 48), Color("#0c4a6e"))
	draw_rect(Rect2(sp.x - 80, sp.y - 104, 160, 48), Color("#f8fafc"), false, 3)
	_text(Vector2(sp.x - 80, sp.y - 86), "AÇIK OKYANUS →", 14, Color.WHITE, 160, false)
	_text(Vector2(sp.x - 80, sp.y - 68), "kendi teknenle (E)", 12, Color("#fde68a"), 160, false)


# ================================================================== 1.7: tren, sinema, paintball, özel ada, ticaret

func _rail_zone(z: Dictionary) -> Dictionary:
	var k := Rail.station_at(my_pos)
	if k == "":
		return z
	var ts := Map.train_state(Land.server_now())
	var when := "tren peronda!" if ts.stopped else "tren %d sn sonra" % int(ceil(float(ts.get("next", 0.0))))
	return {"type": "rail", "here": k, "label": "%s — bilet (%s)" % [Map.RAIL[k].name, when]}


func _draw_rails() -> void:
	var view := _view_rect().grow(300)
	var ts := Map.train_state(Land.server_now())
	for k in Map.RAIL:
		var st: Dictionary = Map.RAIL[k]
		var y := float(st.y)
		if y < view.position.y - 80 or y > view.end.y + 80:
			continue
		var x0 := maxf(float(st.x0), view.position.x)
		var x1 := minf(float(st.x1), view.end.x)
		if x0 >= x1:
			continue
		# traversler ve raylar
		draw_rect(Rect2(x0, y - 10, x1 - x0, 22), Color("#8b8178"))
		for x in range(int(x0 / 26.0) * 26, int(x1), 26):
			draw_rect(Rect2(x, y - 12, 10, 26), Color("#5b3a1e"))
		draw_line(Vector2(x0, y - 6), Vector2(x1, y - 6), Color("#9ca3af"), 3)
		draw_line(Vector2(x0, y + 8), Vector2(x1, y + 8), Color("#9ca3af"), 3)
		# peron ve gişe
		var b: Vector2 = st.booth
		draw_rect(Rect2(float(st.stop) - 260, y + 16, 520, 30), Color("#d6d3d1"))
		draw_rect(Rect2(float(st.stop) - 260, y + 16, 520, 4), Color("#facc15"))
		draw_rect(Rect2(b.x - 34, b.y - 30, 68, 40), Color("#7c2d12"))
		draw_rect(Rect2(b.x - 26, b.y - 22, 52, 18), Color("#fde68a"))
		draw_colored_polygon(PackedVector2Array([b + Vector2(-42, -30), b + Vector2(42, -30), b + Vector2(0, -50)]), Color("#991b1b"))
		_text(b + Vector2(-110, 30), U.upper_tr(st.name), 14, Color.WHITE, 220)
		# tren
		if ts.visible:
			_draw_train(Map.train_x(st, float(ts.k)), y, k)


func _draw_train(cx: float, y: float, key: String) -> void:
	var cars := 4
	var car := Map.TRAIN_LEN / cars
	var left := cx - Map.TRAIN_LEN / 2.0
	var cols := {"sehir": Color("#dc2626"), "dag": Color("#2563eb"), "fuar": Color("#9333ea")}
	var col: Color = cols.get(key, Color("#dc2626"))
	for i in cars:
		var x := left + i * car
		var r := Rect2(x + 4, y - 40, car - 8, 44)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, Color("#f8fafc") if i > 0 else col)
		draw_rect(Rect2(r.position.x, r.position.y + 30, r.size.x, 8), col)
		for w in 4:
			draw_rect(Rect2(r.position.x + 10 + w * (r.size.x - 20) / 4.0, r.position.y + 8, (r.size.x - 20) / 4.0 - 6, 14), Color("#7dd3fc"))
		draw_rect(r, Color("#1f2937"), false, 2)
		draw_circle(Vector2(r.position.x + 16, y + 6), 6, Color("#111827"))
		draw_circle(Vector2(r.end.x - 16, y + 6), 6, Color("#111827"))
	# lokomotif burnu
	var nose := left + Map.TRAIN_LEN
	draw_colored_polygon(PackedVector2Array([Vector2(nose - 4, y - 40), Vector2(nose + 26, y - 14), Vector2(nose + 26, y + 4), Vector2(nose - 4, y + 4)]), col)
	draw_circle(Vector2(nose + 18, y - 8), 4, Color("#fef08a"))


func _on_trip(d: Dictionary) -> void:
	if panel != null:
		_close_panel()
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var art := TrainArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.dest = str(d.get("name", ""))
	art.to = str(d.get("to", ""))
	layer.add_child(art)
	Sfx.play("bell", -6.0, 0.7)
	var tw := create_tween()
	tw.tween_interval(float(d.get("time", 6.0)))
	tw.tween_property(art, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


## Tren penceresinden manzara: hedefe göre (dağ: karlı zirveler, fuar: dönme dolap, şehir: binalar).
class TrainArt extends Control:
	var dest := ""
	var to := ""
	var t0 := Time.get_ticks_msec() / 1000.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7dd3fc"))
		# uzak tepeler (yavaş), yakın tepeler (hızlı)
		for layer in 2:
			var sp := 60.0 if layer == 0 else 220.0
			var base_y := h * (0.55 if layer == 0 else 0.68)
			var col := Color("#86b98a") if layer == 0 else Color("#5d9c4a")
			if to == "dag" and layer == 0:
				col = Color("#94a3b8")
			var pts := PackedVector2Array([Vector2(0, h)])
			for i in 41:
				var x := w * i / 40.0
				var wx := x + t * sp
				var hh := 40.0 + 30.0 * sin(wx / 140.0) + 20.0 * sin(wx / 53.0 + layer)
				if to == "dag" and layer == 0:
					hh *= 2.4
				pts.append(Vector2(x, base_y - hh))
			pts.append(Vector2(w, h))
			draw_colored_polygon(pts, col)
			if to == "dag" and layer == 0:
				for i in 41:
					var x2 := w * i / 40.0
					var wx2 := x2 + t * sp
					var hh2 := (40.0 + 30.0 * sin(wx2 / 140.0) + 20.0 * sin(wx2 / 53.0)) * 2.4
					if hh2 > 150.0:
						draw_circle(Vector2(x2, base_y - hh2 + 8), 10, Color.WHITE)
		# direkler
		for i in 6:
			var px := fposmod(w - (t * 520.0 + i * 260.0), w + 200.0) - 100.0
			draw_rect(Rect2(px, h * 0.3, 8, h * 0.5), Color("#57534e"))
		if to == "fuar":
			var fx := fposmod(w * 0.8 - t * 60.0, w + 400.0) - 200.0
			draw_arc(Vector2(fx, h * 0.38), 90, 0, TAU, 32, Color.WHITE, 4)
			for k in 8:
				var a := TAU * k / 8.0 + t * 0.4
				draw_line(Vector2(fx, h * 0.38), Vector2(fx, h * 0.38) + Vector2(cos(a), sin(a)) * 90, Color(1, 1, 1, 0.8), 2)
		elif to == "sehir":
			for k in 8:
				var bx := fposmod(k * 210.0 - t * 90.0, w + 300.0) - 150.0
				var bh := 90.0 + float((k * 53) % 90)
				draw_rect(Rect2(bx, h * 0.6 - bh, 90, bh), Color("#64748b"))
				for wy in 3:
					draw_rect(Rect2(bx + 14, h * 0.6 - bh + 14 + wy * 26, 60, 10), Color("#fde68a"))
		# pencere çerçevesi
		var fr := Color("#7c2d12")
		draw_rect(Rect2(0, 0, w, 70), fr)
		draw_rect(Rect2(0, h - 110, w, 110), fr)
		draw_rect(Rect2(0, 0, 50, h), fr)
		draw_rect(Rect2(w - 50, 0, 50, h), fr)
		draw_rect(Rect2(w / 2.0 - 14, 0, 28, h), fr)
		draw_string(ThemeDB.fallback_font, Vector2(0, h - 48), "Tren yolculuğu: %s" % dest, HORIZONTAL_ALIGNMENT_CENTER, w, 28, Color("#fde68a"))


func _paint_hint() -> String:
	var st: Dictionary = Paint.st
	var sc: Dictionary = st.get("score", {})
	var mode := "ilk %d vuruş" % Paint.WIN_HITS if st.get("mode", "") == "hits" else "bayrak: %d" % Paint.WIN_FLAGS
	var left := float(st.get("left", 0.0))
	var line := "PAINTBALL (%s)   Kırmızı %d – %d Mavi   ·   %d:%02d" % [mode, int(sc.get("kirmizi", 0)), int(sc.get("mavi", 0)), int(left) / 60, int(left) % 60]
	if Paint.is_out(Net.my_name):
		return line + "\nBOYANDIN! %d sn sonra üssünde doğarsın" % int(ceil(float(st.out[Net.my_name])))
	return line + "\nSol tık: boya topu at (fareye doğru)"


func _on_paint_hit(d: Dictionary) -> void:
	var p: Vector2 = d.p
	if _view_rect().grow(200).has_point(p):
		add_fx("water", p, 0.5)
		Sfx.play("splash_small", -8.0, 1.6)
	if str(d.get("victim", "")) == Net.my_name:
		hud.show_toast("%s seni boyadı!" % d.by, false)


func _draw_arena() -> void:
	var a: Rect2 = Map.ARENA
	if not _view_rect().grow(300).intersects(a):
		return
	draw_rect(a.grow(14), Color("#3f3f46"))
	draw_rect(a, Color("#a3b18a"))
	for gx in range(int(a.position.x), int(a.end.x), 40):
		draw_line(Vector2(gx, a.position.y), Vector2(gx, a.end.y), Color(0, 0, 0, 0.05), 1)
	# çit
	for x in range(int(a.position.x) - 14, int(a.end.x) + 14, 24):
		draw_rect(Rect2(x, a.position.y - 14, 6, 14), Color("#78716c"))
		draw_rect(Rect2(x, a.end.y, 6, 14), Color("#78716c"))
	# üsler
	for t in Paint.TEAMS:
		var bp: Vector2 = Map.ARENA_BASE[t]
		draw_circle(bp, 52, Color(Paint.TEAM_COLOR[t], 0.25))
		draw_arc(bp, 52, 0, TAU, 32, Paint.TEAM_COLOR[t], 3)
	# lekeler
	for sp in Paint.splats:
		var c: Color = Paint.TEAM_COLOR.get(sp.team, Color.WHITE)
		var sp_p: Vector2 = sp.p
		draw_circle(sp_p, 9, c)
		for k in 5:
			draw_circle(sp_p + Vector2.RIGHT.rotated(k * 1.3 + sp_p.x) * 11.0, 3.5, c)
	# engeller (saman balyası ve tahta)
	for c in Map.ARENA_COVER:
		var r: Rect2 = c
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.25))
		draw_rect(r, Color("#d4a656"))
		for k in range(int(r.position.y) + 6, int(r.end.y), 10):
			draw_line(Vector2(r.position.x + 2, k), Vector2(r.end.x - 2, k), Color("#b7852f"), 1.5)
		draw_rect(r, Color("#7c5a2b"), false, 2)
	# bayraklar
	var fl: Dictionary = Paint.st.get("flags", {})
	for t in fl:
		var fp := Vector2(float(fl[t].x), float(fl[t].y))
		draw_line(fp, fp + Vector2(0, -44), Color("#1f2937"), 3)
		draw_colored_polygon(PackedVector2Array([fp + Vector2(0, -44), fp + Vector2(30, -36), fp + Vector2(0, -28)]), Paint.TEAM_COLOR[t])
	# toplar
	var now := Time.get_ticks_msec() / 1000.0
	var keep: Array = []
	for b in Paint.balls:
		var age := now - float(b.t0)
		if age > Paint.BALL_LIFE:
			continue
		keep.append(b)
		var bp2: Vector2 = b.p + b.v * age
		draw_circle(bp2, Paint.BALL_R, Paint.TEAM_COLOR.get(b.team, Color.WHITE))
		draw_circle(bp2 + Vector2(-2, -2), 2, Color(1, 1, 1, 0.7))
	Paint.balls = keep
	# takım halkaları (oyuncuların ayağında)
	var teams: Dictionary = Paint.st.get("teams", {})
	if Paint.st.get("phase", "") == "play":
		for id in Net.roster:
			var nm: String = Net.roster[id].name
			if teams.has(nm):
				var pp: Vector2 = my_pos if id == Net.my_id() else shown.get(id, Vector2(-9999, -9999))
				draw_set_transform(pp + Vector2(0, 8), 0, Vector2(1, 0.4))
				draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Paint.TEAM_COLOR[teams[nm]], 4)
				draw_set_transform(Vector2.ZERO)
	var bp3 := Map.ARENA_BOOTH
	draw_rect(Rect2(bp3.x - 50, bp3.y - 40, 100, 44), Color("#1f2937"))
	draw_rect(Rect2(bp3.x - 50, bp3.y - 40, 50, 8), Paint.TEAM_COLOR.kirmizi)
	draw_rect(Rect2(bp3.x, bp3.y - 40, 50, 8), Paint.TEAM_COLOR.mavi)
	_text(bp3 + Vector2(-110, -54), "PAINTBALL", 18, Color("#fde68a"), 220)
	_text(Vector2(a.position.x, a.position.y - 40), "PAINTBALL ARENASI", 20, Color.WHITE, a.size.x)


func _draw_paint_bot(bt: Dictionary) -> void:
	var p := Vector2(float(bt.x), float(bt.y))
	var outd: bool = Paint.is_out(str(bt.name))
	draw_set_transform(p + Vector2(0, 8), 0, Vector2(1, 0.4))
	draw_arc(Vector2.ZERO, 22, 0, TAU, 24, Paint.TEAM_COLOR[bt.team], 4)
	draw_set_transform(Vector2.ZERO)
	var app: Dictionary = bt.get("app", {})
	Avatar.draw(self, p, app, "right" if bt.get("f", "right") == "right" else "left", [1, 0, 2, 0][int(_t * 7.0 + p.x * 0.01) % 4])
	draw_rect(Rect2(p.x - 13, p.y - 40, 26, 14), Color(Paint.TEAM_COLOR[bt.team], 0.85))       # takım yeleği
	if outd:
		draw_circle(p + Vector2(0, -30), 26, Color(Paint.TEAM_COLOR["mavi" if bt.team == "kirmizi" else "kirmizi"], 0.55))
	_text(p + Vector2(-70, -66), str(bt.name), 12, Paint.TEAM_COLOR[bt.team].lightened(0.4), 140)


var _sale_cache: Array = []


func _sale_ids() -> Array:
	if _sale_cache.is_empty():
		_sale_cache = Isles.for_sale()
	return _sale_cache


func _isle_zone(isl: Dictionary, z: Dictionary, boat: bool) -> Dictionary:
	var i := int(isl.id)
	if not i in _sale_ids():
		return z
	var sp := Isles.spots(isl)
	var own: Dictionary = Isles.view.get(str(i), {})
	var mine := str(own.get("owner", "")) == Net.my_name
	if mine and int(own.b.get("iskele", 0)) > 0 and my_pos.distance_to(sp.pump) < 200.0:
		z = {"type": "ocean_fuel", "port": -1, "label": "Kendi iskelende yakıt al"}
	if boat:
		return z
	if my_pos.distance_to(sp.sign) < 80.0:
		if own.is_empty():
			z = {"type": "isle", "i": i, "label": "SATILIK ADA: %s (%s)" % [isl.name, U.money(Isles.price_of(isl))]}
		elif mine:
			z = {"type": "isle", "i": i, "label": "Adanı yönet: yapı kur, sat"}
		else:
			z = {"type": "isle", "i": i, "label": "%s'in adası%s" % [own.owner, "" if own.get("open", true) else " (özel)"]}
	if mine and int(own.b.get("ev", 0)) > 0 and my_pos.distance_to(sp.house) < 120.0:
		z = {"type": "isle_rest", "i": i, "label": "Evinde dinlen (enerji dolar)"}
	if mine and int(own.b.get("bahce", 0)) > 0 and my_pos.distance_to(sp.garden) < 140.0:
		z = {"type": "isle_harvest", "i": i, "label": "Bahçeni hasat et"}
	return z


func _isle_interact() -> bool:
	match str(zone.get("type", "")):
		"isle":
			if panel == null:
				panel = PANELS["isle"].new()
				panel.island = int(zone.get("i", Isles.for_sale()[0]))
				panel.closed.connect(_close_panel)
				ui_layer.add_child(panel)
		"isle_rest":
			Isles.rest(int(zone.get("i", -1)))
			Sfx.play("success", -6.0)
		"isle_harvest":
			Isles.harvest(int(zone.get("i", -1)))
			Sfx.play("coin", -6.0)
		_:
			return false
	return true


## Sahibi olan adada yapılar (yer seviyesindekiler hemen çizilir; ev ve fener y'ye göre sıralanır).
func _draw_isle_ground(isl: Dictionary, own: Dictionary, sp: Dictionary, items: Array) -> void:
	var b: Dictionary = own.get("b", {})
	if int(b.get("bahce", 0)) > 0:
		var g: Vector2 = sp.garden
		draw_colored_polygon(_ellipse(Rect2(g - Vector2(70, 34), Vector2(140, 68)), 20), Color("#6b4f2a"))
		for k in 6:
			var gp := g + Vector2(-48 + (k % 3) * 48, -14 + int(k / 3) * 28)
			draw_circle(gp, 10, Color("#16a34a"))
			draw_circle(gp + Vector2(4, -3), 3.5, Color("#facc15") if k % 2 == 0 else Color("#f97316"))
	if int(b.get("havuz", 0)) > 0:
		var pp: Vector2 = sp.pool
		draw_rect(Rect2(pp - Vector2(48, 24), Vector2(96, 48)), Color("#f8fafc"))
		draw_rect(Rect2(pp - Vector2(41, 18), Vector2(82, 36)), Color("#22d3ee"))
		for k in 2:
			var wy := pp.y - 6 + k * 12
			draw_line(Vector2(pp.x - 34, wy + sin(_t * 2.0 + k) * 2.0), Vector2(pp.x + 34, wy + sin(_t * 2.0 + k + 1) * 2.0), Color(1, 1, 1, 0.5), 2)
	if int(b.get("iskele", 0)) > 0:
		var a0: Vector2 = Vector2(isl.dock) - Vector2(isl.dock_dir) * 40.0
		var b0 := OM.pier_end(isl)
		var side: Vector2 = Vector2(isl.dock_dir).orthogonal() * 34.0
		draw_colored_polygon(PackedVector2Array([a0 + side, b0 + side, b0 - side, a0 - side]), Color("#8b5a2b"))
		items.append([b0.y - 10.0, "pump", b0 + side * 0.9])
	if int(b.get("ev", 0)) > 0:
		items.append([float(sp.house.y), "house", [sp.house, int(b.ev), str(own.owner)]])
	if int(b.get("fener", 0)) > 0:
		items.append([float(sp.light.y), "lighthouse", [sp.light, true]])


func _draw_isle_house(p: Vector2, lvl: int, owner_name: String) -> void:
	var w: float = [0.0, 90.0, 140.0, 200.0][lvl]
	var h: float = [0.0, 60.0, 80.0, 100.0][lvl]
	draw_rect(Rect2(p.x - w / 2.0 + 8, p.y - 4, w, 12), Color(0, 0, 0, 0.2))
	var wall: Color = [Color.WHITE, Color("#d6b88c"), Color("#fef3c7"), Color("#f8fafc")][lvl]
	var roof: Color = [Color.WHITE, Color("#a16207"), Color("#dc2626"), Color("#1e3a8a")][lvl]
	draw_rect(Rect2(p.x - w / 2.0, p.y - h, w, h), wall)
	draw_colored_polygon(PackedVector2Array([Vector2(p.x - w / 2.0 - 12, p.y - h), Vector2(p.x + w / 2.0 + 12, p.y - h), Vector2(p.x, p.y - h - h * 0.6)]), roof)
	draw_rect(Rect2(p.x - 12, p.y - 34, 24, 34), Color("#7c2d12"))
	for k in lvl + 1:
		var wx := p.x - w / 2.0 + 12 + k * (w - 24) / maxf(1.0, float(lvl)) - (12 if k == lvl else 0)
		if absf(wx - p.x) > 20:
			draw_rect(Rect2(wx, p.y - h + 14, 18, 16), Color("#7dd3fc"))
	if lvl >= 3:
		draw_rect(Rect2(p.x - w / 2.0 - 4, p.y - h - 4, w + 8, 6), Color("#facc15"))
	draw_rect(Rect2(p.x - w / 2.0, p.y - h, w, h), Color("#1f2937"), false, 2)
	_text(p + Vector2(-100, -h - h * 0.6 - 22), "%s'in %s" % [owner_name, Isles.BUILD.ev.own[lvl - 1]], 13, Color("#fde68a"), 200)


func _draw_isle_sign(isl: Dictionary) -> void:
	var sp: Vector2 = Isles.spots(isl).sign
	var own: Dictionary = Isles.view.get(str(int(isl.id)), {})
	draw_rect(Rect2(sp.x - 3, sp.y - 46, 6, 46), Color("#5b3a1e"))
	draw_rect(Rect2(sp.x - 54, sp.y - 76, 108, 34), Color("#fef3c7") if own.is_empty() else Color("#1e3a8a"))
	draw_rect(Rect2(sp.x - 54, sp.y - 76, 108, 34), Color("#7c2d12"), false, 2)
	if own.is_empty():
		_text(Vector2(sp.x - 54, sp.y - 70), "SATILIK", 13, Color("#b91c1c"), 108, false)
		_text(Vector2(sp.x - 54, sp.y - 54), U.money(Isles.price_of(isl)), 11, Color("#1f2937"), 108, false)
	else:
		_text(Vector2(sp.x - 54, sp.y - 70), str(own.owner), 12, Color.WHITE, 108, false)
		_text(Vector2(sp.x - 54, sp.y - 54), "ÖZEL ADA" if not own.get("open", true) else "ADASI", 10, Color("#fde68a"), 108, false)


var _raid_shown := {}


func _raid_pos(owner_name: String) -> Vector2:
	var r: Dictionary = Cargo.raids.get(owner_name, {})
	if r.is_empty():
		return Vector2(-99999, -99999)
	var target := Vector2(float(r.x), float(r.y))
	var cur: Vector2 = _raid_shown.get(owner_name, target)
	cur = cur.lerp(target, 0.15)
	_raid_shown[owner_name] = cur
	return cur


func _draw_raid_ship(p: Vector2, owner_name: String) -> void:
	var r: Dictionary = Cargo.raids.get(owner_name, {})
	draw_set_transform(p + Vector2(0, 10), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 70, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)
	var rock := sin(_t * 1.8) * 0.04
	draw_set_transform(p, rock, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-80, -10), Vector2(80, -10), Vector2(60, 18), Vector2(-64, 18)]), Color("#3f2a1a"))
	draw_rect(Rect2(-74, -16, 148, 8), Color("#5b3a1e"))
	draw_line(Vector2(0, -12), Vector2(0, -110), Color("#2b1a10"), 5)
	draw_colored_polygon(PackedVector2Array([Vector2(4, -104), Vector2(56, -96), Vector2(52, -40), Vector2(4, -34)]), Color("#1f2937"))
	draw_circle(Vector2(30, -72), 10, Color("#f8fafc"))
	draw_line(Vector2(22, -58), Vector2(38, -50), Color("#f8fafc"), 3)
	draw_line(Vector2(38, -58), Vector2(22, -50), Color("#f8fafc"), 3)
	draw_rect(Rect2(-2, -126, 26, 14), Color("#111827"))
	draw_set_transform(Vector2.ZERO)
	_text(p + Vector2(-90, -150), "KORSANLAR (%d/%d)" % [int(r.get("hits", 0)), Cargo.RAID_HITS], 13, Color("#fecaca"), 180)
	if randf() < 0.1:
		add_fx("wake", p + Vector2(-80, 16), 1.2)



# ================================================================== 1.7: göl kayığı

## Küçük ahşap kayık; kürekler yol alırken çekilir.
func _draw_kayik(p: Vector2, facing: String, moving: bool) -> void:
	var side := facing == "left" or facing == "right"
	var k := 1.0 if side else 0.75
	var rock := sin(_t * 2.0 + p.x * 0.01) * 0.04
	draw_set_transform(p + Vector2(0, 8), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 40, Color(0, 0, 0, 0.15))
	draw_set_transform(p, rock, Vector2(k, 1.0 if side else 1.25))
	var hull := PackedVector2Array([Vector2(-46, -6), Vector2(46, -6), Vector2(36, 12), Vector2(-36, 12)])
	draw_colored_polygon(hull, Color("#92400e"))
	draw_colored_polygon(PackedVector2Array([Vector2(-42, -6), Vector2(42, -6), Vector2(34, 2), Vector2(-34, 2)]), Color("#d6a26a"))
	draw_line(Vector2(-46, -6), Vector2(46, -6), Color("#451a03"), 2)
	draw_line(Vector2(-14, -6), Vector2(-14, 2), Color("#78350f"), 2)
	draw_line(Vector2(14, -6), Vector2(14, 2), Color("#78350f"), 2)
	var a := sin(_t * 6.0) * 0.5 if moving else 0.0
	for sgn in [-1.0, 1.0]:
		var o := Vector2(0, -2)
		var tip := o + Vector2(sgn * 10.0, 26.0).rotated(a * sgn)
		draw_line(o, tip, Color("#a16207"), 3)
		draw_line(tip, tip + Vector2(sgn * 3.0, 8.0).rotated(a * sgn), Color("#a16207"), 6)
	draw_set_transform(Vector2.ZERO)
	if moving and randf() < 0.2:
		add_fx("wake", p + Vector2(randf_range(-30, 30), 10), 1.0)


## İskelede bağlı bedava kayık ve tabelası.
func _draw_moored_kayik() -> void:
	var kp: Vector2 = Map.KAYIK_SPOT + Vector2(0, sin(_t * 1.2) * 2.0)
	draw_line(kp + Vector2(40, -4), Vector2(Map.DOCK.position.x + 4, Map.DOCK.position.y + 40), Color("#a16207"), 2)
	_draw_kayik(kp, "right", false)
	var sp := Vector2(Map.DOCK.end.x - 24, Map.DOCK.position.y - 6)
	draw_rect(Rect2(sp.x - 2, sp.y - 34, 4, 34), Color("#5b3a1e"))
	draw_rect(Rect2(sp.x - 46, sp.y - 58, 92, 26), Color("#fef3c7"))
	draw_rect(Rect2(sp.x - 46, sp.y - 58, 92, 26), Color("#7c2d12"), false, 2)
	_text(Vector2(sp.x - 46, sp.y - 52), "KAYIK (bedava)", 11, Color("#7c2d12"), 92, false)
