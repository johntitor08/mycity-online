extends Node
## Tanıtım videosu (teaser) çekimi. Godot'nun film kaydıyla çalıştırılır:
##   godot --path . --resolution 1920x1080 --fixed-fps 30 --write-movie build/teaser/kare.png -- --teaser
## Önce siyah ekranda hazırlık yapılır (araç, ahır, ev alınır); "TEASER_BASLA <kare>" satırından
## sonrası asıl videodur, tools/teaser.sh bunu kırpar ve MP4'e çevirir.

const Map = preload("res://scripts/map.gd")
const Avatar = preload("res://scripts/avatar.gd")

var w
var layer: CanvasLayer
var black: ColorRect
var cap_box: VBoxContainer
var cap_band: TextureRect
var cap_tag: Label
var cap_text: Label
var title_box: VBoxContainer
var _g := {}                       # aktif kayma: {from, to, t, dur, fakes: [[id, from, to]]}
var ranch_plot := 6
var home_plot := 7


func _ready() -> void:
	process_priority = 100         # dünyadan sonra işlensin ki yürüme animasyonunu biz açalım
	Net.save_path = "user://teaser_kayit.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Net.save_path))
	_build_overlay()
	Net.host("Eren", 7793, false, Net.hash_password("Eren", "teaser1234"))
	await _wait(0.5)
	w = get_parent().world
	w.hud.visible = false
	Tutorial.finish()
	await _prepare()
	print("TEASER_BASLA %d" % Engine.get_process_frames())
	await _run()
	print("TEASER_BITTI %d" % Engine.get_process_frames())
	get_tree().quit()


func _process(delta: float) -> void:
	if _g.is_empty() or w == null:
		return
	_g.t = float(_g.t) + delta
	var k := clampf(float(_g.t) / float(_g.dur), 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k) if _g.get("ease", true) else k
	var from: Vector2 = _g.from
	var to: Vector2 = _g.to
	# oyundaki gibi çarpışmaya uy: engel varsa eksen boyunca kay, olmazsa dur
	var cur: Vector2 = w.my_pos
	var step: Vector2 = from.lerp(to, e) - cur
	var ride: String = w.my_ride()
	var np := cur + step
	if not w._can_stand(np, ride):
		np = cur
		for s2 in [Vector2(step.x, 0), Vector2(0, step.y)]:
			if w._can_stand(cur + s2, ride):
				np = cur + s2
				break
	w.my_pos = np
	if from != to:
		w.my_moving = true
		w.my_facing = w._facing_of(to - from)
	for f in _g.fakes:
		Net.positions[f[0]] = (f[1] as Vector2).lerp(f[2], k)


# ------------------------------------------------------------------ yardımcılar

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _glide(from: Vector2, to: Vector2, dur: float, fakes: Array = [], smooth := true) -> void:
	_g = {"from": from, "to": to, "t": 0.0, "dur": dur, "fakes": fakes, "ease": smooth}
	await _wait(dur)
	_g = {}


## Sahne değişimi: karart, kur, kamerayı yerine oturt, aç.
func _cut_to(pos: Vector2, zoom: float) -> void:
	w.my_pos = pos
	w.camera.zoom = Vector2(zoom, zoom)
	await get_tree().process_frame
	await get_tree().process_frame
	w.camera.reset_smoothing()


func _fade(to_black: bool, dur := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0 if to_black else 0.0, dur)
	await tw.finished


func _fake(id: int, n: String, app: Dictionary, pos: Vector2, ride := "", level := 8) -> void:
	Net.players[id] = {"name": n, "money": 5000, "color": Avatar.shirt_color(app), "appearance": app, "level": level, "ride": ride}
	Net.positions[id] = pos


## Sahnede NPC arabaları yolumuza çıkmasın: bu x aralığındakileri gidiş yönlerinde ileri al.
func _clear_traffic(x0: float, x1: float) -> void:
	var k := 0
	for c in w.npc.cars:
		var dir := float(Map.TRAFFIC_LANES[c.lane][1])
		if float(c.x) > x0 - 200.0 and float(c.x) < x1 + 200.0:
			c.x = (x1 + 260.0 + k * 140.0) if dir > 0 else (x0 - 260.0 - k * 140.0)
			k += 1


func _clear_fakes() -> void:
	for id in Net.players.keys():
		if int(id) >= 9000:
			Net.players.erase(id)
			Net.positions.erase(id)
	Net._broadcast_roster()


const APPS := [
	{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
	{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
	{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
	{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5},
	{"skin": 2, "hair": 0, "hair_color": 2, "shirt": 3, "pants": 2},
	{"skin": 1, "hair": 5, "hair_color": 1, "shirt": 4, "pants": 3},
]
const NAMES := ["Ayşe", "Kerem", "Zeynep", "Mehmet", "Derya", "Can"]


# ------------------------------------------------------------------ başlık katmanı

func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	black = ColorRect.new()
	black.color = Color(0.02, 0.03, 0.06, 1.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	# alt şerit (yazı okunsun diye koyu geçiş)
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	cap_band = TextureRect.new()
	cap_band.texture = gt
	cap_band.stretch_mode = TextureRect.STRETCH_SCALE
	cap_band.position = Vector2(0, 720 - 260)
	cap_band.size = Vector2(1280, 260)
	cap_band.modulate.a = 0.0
	cap_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_band)
	cap_box = VBoxContainer.new()
	cap_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cap_box.position = Vector2(64, 720 - 190)
	cap_box.add_theme_constant_override("separation", 0)
	cap_box.modulate.a = 0.0
	layer.add_child(cap_box)
	cap_tag = _label(cap_box, "", 22, Color("#facc15"), 6)
	cap_text = _label(cap_box, "", 46, Color.WHITE, 12)
	title_box = VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.modulate.a = 0.0
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(title_box)


func _label(parent: Control, text: String, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 3)
	parent.add_child(l)
	return l


func _caption(text: String, tag := "") -> void:
	cap_text.text = text
	cap_tag.text = tag
	cap_tag.visible = tag != ""
	cap_box.position = Vector2(64, 720 - (190 if tag != "" else 160))
	var tw := create_tween().set_parallel()
	tw.tween_property(cap_box, "modulate:a", 1.0, 0.4)
	tw.tween_property(cap_band, "modulate:a", 1.0, 0.4)


func _caption_off() -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(cap_box, "modulate:a", 0.0, 0.3)
	tw.tween_property(cap_band, "modulate:a", 0.0, 0.3)


func _title(lines: Array) -> void:
	for c in title_box.get_children():
		c.queue_free()
	for ln in lines:
		var l := _label(title_box, ln[0], ln[1], ln[2], 14 if int(ln[1]) > 40 else 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_property(title_box, "modulate:a", 1.0, 0.6)


func _title_off(dur := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(title_box, "modulate:a", 0.0, dur)
	await tw.finished


# ------------------------------------------------------------------ hazırlık (videoya girmez)

func _prepare() -> void:
	Net.add_money(1, 300000)
	Rpg.add_xp(1, "", 20000)
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Env.hour = 12.0
	await _wait(0.3)
	# araçlar ve görünüm
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.3)
	for k in ["bike", "car", "boat"]:
		Garage.buy(k)
	await _wait(0.4)
	Garage.set_style("car", 6)
	Garage.set_style("rims", 1)
	await _wait(0.3)
	# ahır
	w.my_pos = Map.plot_rect(ranch_plot).get_center()
	await _wait(0.3)
	Land.buy(ranch_plot)
	await _wait(0.3)
	Land.build_up(ranch_plot, "ranch")
	await _wait(0.3)
	for k in ["chicken", "chicken", "cow", "sheep", "cow", "sheep"]:
		Farm.buy_animal(ranch_plot, k)
	await _wait(0.4)
	# döşenmiş ev
	w.my_pos = Map.plot_rect(home_plot).get_center()
	await _wait(0.3)
	Land.buy(home_plot)
	await _wait(0.3)
	Land.build_up(home_plot)
	Land.build_up(home_plot)
	await _wait(0.3)
	Land.set_tint(home_plot, 3)
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.3)
	for k in ["bed", "rug", "sofa", "tv", "table", "chair", "plant", "lamp", "aquarium", "stove"]:
		Homes.buy(k)
	await _wait(0.5)
	w.my_pos = Map.plot_rect(home_plot).get_center()
	await _wait(0.3)
	Homes.enter(home_plot)
	await _wait(0.5)
	for fdef in [["bed", 1, 1], ["rug", 5, 4], ["sofa", 5, 2], ["tv", 6, 7], ["table", 11, 4], ["chair", 10, 4], ["plant", 0, 8], ["lamp", 4, 1], ["aquarium", 11, 0], ["stove", 8, 0]]:
		Homes.place(home_plot, fdef[0], fdef[1], fdef[2])
		await _wait(0.1)
	Homes.exit_home()
	await _wait(0.5)
	var now := Time.get_unix_time_from_system()
	for a in Land.plots[ranch_plot].ranch.animals:
		a.last = now - 900.0
	Land._broadcast()
	await _wait(0.3)


# ------------------------------------------------------------------ video

func _run() -> void:
	# 1. açılış: şehrin üstünde isim
	Env.hour = 9.5
	var a := Vector2(640, 515)          # üst caddenin güney kaldırımı (hastane/market karşısı)
	_clear_traffic(200, 1800)
	# [kimlik sırası, başlangıç, bitiş, araç]: kaldırımda yürüyenler, yolda bisiklet ve araba
	var opening := [[Vector2(560, 512), Vector2(820, 512), ""], [Vector2(900, 465), Vector2(500, 465), "bike"],
		[Vector2(780, 530), Vector2(620, 530), ""], [Vector2(500, 392), Vector2(760, 392), ""],
		[Vector2(380, 425), Vector2(980, 425), "car"], [Vector2(720, 590), Vector2(770, 590), ""]]
	for k in 6:
		_fake(9001 + k, NAMES[k], APPS[k], opening[k][0], opening[k][2])
	Net._broadcast_roster()
	await _cut_to(a, 1.0)
	_title([["MyCity Online", 92, Color.WHITE], ["arkadaşlarınla kendi şehrini kur", 30, Color("#facc15")]])
	var walkers := []
	for k in 6:
		walkers.append([9001 + k, opening[k][0], opening[k][1]])
	create_tween().tween_property(black, "color:a", 0.45, 1.2)
	await _glide(a, Vector2(900, 515), 4.0, walkers)
	create_tween().tween_property(black, "color:a", 0.0, 0.6)
	await _title_off(0.6)

	# 2. şehir hayatı
	_caption("Çok oyunculu, yaşayan bir şehir")
	var b := Vector2(1420, 515)
	await _glide(w.my_pos, b, 3.2, [[9001, Net.positions[9001], b + Vector2(-70, -4)], [9004, Net.positions[9004], Vector2(1300, 392)]])
	_caption_off()
	await _fade(true)
	_clear_fakes()

	# 3. araba
	_clear_traffic(600, 2100)
	w.my_pos = Vector2(900, 425)
	await _wait(0.05)
	Garage.ride("car")
	_fake(9101, "Derya", APPS[4], Vector2(1090, 425), "car")
	_fake(9102, "Kerem", APPS[1], Vector2(1700, 465), "bike")
	Net._broadcast_roster()
	await _cut_to(Vector2(900, 425), 1.25)
	_fade(false)
	_caption("Arabanı al, boya, yarış", "YENİ: ARAÇ ÖZELLEŞTİRME")
	await _glide(Vector2(900, 425), Vector2(1650, 425), 3.4, [[9101, Vector2(1090, 425), Vector2(1840, 425)], [9102, Vector2(1700, 465), Vector2(1050, 465)]], false)
	_caption_off()
	await _fade(true)
	Garage.ride("")
	_clear_fakes()

	# 4. deniz ve ada (gün batımı)
	Env.hour = 18.6
	var s0: Vector2 = Map.PIER_END.get_center() + Vector2(0, 160)
	w.my_pos = s0
	await _wait(0.1)
	Garage.ride("boat")
	await _wait(0.2)
	var s1: Vector2 = Map.ISLAND_PIER.get_center() + Vector2(-180, -40)
	_fake(9201, "Zeynep", APPS[2], Map.ISLAND_SPOT.get_center())
	Net.players[9201]["fishing"] = "cast"
	_fake(9202, "Can", APPS[5], Map.ISLAND.get_center() + Vector2(-60, 20))
	Net._broadcast_roster()
	await _cut_to(s0, 1.0)
	_fade(false)
	_caption("Teknenle açık denize, adaya git")
	await _glide(s0, s0.lerp(s1, 0.45), 2.0)
	await _fade(true, 0.25)
	await _cut_to(s0.lerp(s1, 0.8), 1.0)
	_fade(false, 0.25)
	await _glide(s0.lerp(s1, 0.8), s1, 1.8)
	Net.players[9201]["fishing"] = "caught"
	Net._broadcast_roster()
	await _wait(0.6)
	_caption_off()

	# 5. dalış
	await _fade(true)
	_clear_fakes()
	Env.hour = 13.0
	w.my_pos = Vector2(1200, 2250)
	await _wait(0.1)
	Dive.dive()
	await _wait(0.3)
	for _k in 12:
		Dive._acc = 99.0
		Dive._process(0.1)
	Dive._wreck_at = 0.0
	Dive._process(0.1)
	var d0 := Vector2(Map.WRECK.x - 900, Map.SEA_BED.end.y - 200)
	await _cut_to(d0, 1.15)
	_fade(false)
	_caption("Dal, inci ve batık hazinesi bul", "YENİ: DALGIÇLIK")
	await _glide(d0, Map.WRECK + Vector2(-60, -40), 4.2)
	_caption_off()
	await _fade(true)
	Dive.surface()
	await _wait(0.15)
	Garage.ride("")

	# 6. ahır
	Env.hour = 10.5
	var r: Vector2 = Map.plot_rect(ranch_plot).get_center()
	await _cut_to(r + Vector2(-120, 90), 1.7)
	_fade(false)
	_caption("Ahırını kur: tavuk, inek, koyun", "YENİ: HAYVAN ÇİFTLİĞİ")
	await _glide(r + Vector2(-120, 90), r + Vector2(60, 40), 3.4)
	_caption_off()
	await _fade(true)

	# 7. ev partisi ve mutfak
	w.my_pos = Map.plot_rect(home_plot).get_center()
	await _wait(0.1)
	Homes.enter(home_plot)
	await _wait(0.25)
	Party.start_party(home_plot)
	await _wait(0.1)
	var room: Rect2 = Map.interior_rect(home_plot, 2)
	for k in 4:
		_fake(9301 + k, NAMES[k], APPS[k], room.get_center() + Vector2(-140 + k * 90, 40 + (k % 2) * 50))
	Net._broadcast_roster()
	await _cut_to(room.get_center() + Vector2(-60, 60), 1.0)
	_fade(false)
	_caption("Evini döşe, yemek pişir, parti ver", "YENİ: MUTFAK VE TARİFLER")
	var dance := []
	for k in 4:
		var p: Vector2 = Net.positions[9301 + k]
		dance.append([9301 + k, p, p + Vector2(30 if k % 2 == 0 else -30, -25)])
	await _glide(room.get_center() + Vector2(-60, 60), room.get_center() + Vector2(20, 40), 3.4, dance)
	_caption_off()
	await _fade(true)
	_clear_fakes()
	Homes.exit_home()
	await _wait(0.15)

	# 8. plaj futbolu
	Env.hour = 15.0
	var f: Rect2 = Football.FIELD
	w.my_pos = f.get_center() + Vector2(-60, 10)
	await _wait(0.15)
	Football.join("blue")
	await _wait(0.1)
	Football.score = {"red": 2, "blue": 3}
	Football._broadcast_match()
	for k in 4:
		_fake(9401 + k, NAMES[k + 1], APPS[k + 1], f.get_center() + Vector2(-150 + k * 90, -40 + (k % 2) * 70))
	Net._broadcast_roster()
	Football.ball = f.get_center() + Vector2(-40, 10)
	Football.vel = Vector2(260, -60)
	await _cut_to(f.get_center() + Vector2(-60, 10), 1.3)
	_fade(false)
	_caption("Plajda futbol, langırt, yarışlar")
	var run := []
	for k in 4:
		var p: Vector2 = Net.positions[9401 + k]
		run.append([9401 + k, p, p + Vector2(120 if k % 2 == 0 else 60, 20 - k * 10)])
	await _glide(f.get_center() + Vector2(-60, 10), f.get_center() + Vector2(110, 0), 3.0, run)
	_caption_off()
	await _fade(true)
	_clear_fakes()
	Football.join("")

	# 9. kış ve kartopu
	Env.force_season("winter")
	Env.hour = 12.0
	var c := Vector2(260, 545)
	for k in 3:
		w.my_pos = c + Vector2(k * 90, (k % 2) * 30)
		await _wait(0.12)
		Seasonal.build_snowman(w.my_pos)
	await _wait(0.2)
	_fake(9501, "Ayşe", APPS[0], c + Vector2(330, 110))
	_fake(9502, "Mehmet", APPS[3], c + Vector2(260, 60))
	Net._broadcast_roster()
	await _cut_to(c + Vector2(80, 110), 1.2)
	_fade(false)
	_caption("Dört mevsim: kar, sis, gökkuşağı")
	for k in 4:
		Seasonal._last_throw.clear()
		Seasonal.throw(Vector2(1, randf_range(-0.12, 0.12)))
		await _wait(0.8)
	_caption_off()
	await _fade(true)
	_clear_fakes()

	# 10. festival gecesi
	Env.force_season("summer")
	Events.start_event("festival")
	Env.hour = 22.0
	for k in 5:
		_fake(9601 + k, NAMES[k], APPS[k], Map.SPAWN + Vector2(-200 + k * 100, -52 + (k % 2) * 10))
	Net._broadcast_roster()
	_clear_traffic(600, 1800)
	await _cut_to(Map.SPAWN + Vector2(0, 40), 1.0)
	_fade(false)
	_caption("Festivaller, etkinlikler, ligler")
	var party := []
	for k in 5:
		var p: Vector2 = Net.positions[9601 + k]
		party.append([9601 + k, p, p + Vector2(40 if k % 2 == 0 else -40, 0)])
	await _glide(Map.SPAWN + Vector2(0, 40), Map.SPAWN + Vector2(0, -40), 3.6, party)
	_caption_off()

	# 11. kapanış
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.82, 0.8)
	_title([["MyCity Online", 92, Color.WHITE], ["Ücretsiz  •  Windows ve Linux  •  Çok oyunculu", 28, Color("#e2e8f0")],
		["johntitortheprog.itch.io/mycity-online", 30, Color("#facc15")]])
	await _wait(4.2)
	await _fade(true, 0.8)
	await _wait(0.3)
