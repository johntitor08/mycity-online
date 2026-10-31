extends RefCounted
## 1.9 istemci: Yeni Mahalle (pazar meydanı, tuning garajı, drift alanı, evcil hayvan parkı), kayarak sürüş ve nitro,
## sokak yarışı ve pist hayaleti, afetler. world.gd'nin kancaları buraya gelir; çizimler world'ün _draw'ı içinde yapılır.

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")
const TuningPanel = preload("res://scripts/ui/tuning_panel.gd")
const StallPanel = preload("res://scripts/ui/stall_panel.gd")
const WantedPanel = preload("res://scripts/ui/wanted_panel.gd")
const PetParkPanel = preload("res://scripts/ui/pet_park_panel.gd")
const FACING := {"right": 0.0, "down": PI / 2.0, "left": PI, "up": -PI / 2.0}

var w: Node2D
var car_vel := Vector2.ZERO
var drift_pts := 0.0
var drifting := false
var _drift_quiet := 0.0
var _drift_show := 0.0                # son drift puanının ekranda kalma süresi
var _drift_last := 0
var skids: Array = []                 # [konum, yerel zaman]
var _hold_acc := 0.0
var _ghost_t0 := -1.0
var _bot_prev := {}
var _bot_face := {}
var _nav_cp := -1


func _init(world: Node2D) -> void:
	w = world
	Disasters.changed.connect(func() -> void:
		var k := str(Disasters.state.get("kind", ""))
		if k != "":
			w.hud.show_toast("%s! Yardım çadırı sahil yolunun başında." % Disasters.KINDS[k].name.to_upper(), false)
			Sfx.play("thunder" if k != "kar" else "wind", 0.0, 0.8))
	Street.changed.connect(_on_street)
	Events.race_changed.connect(_on_lap)
	Tuning.nitro_fired.connect(func(who: String) -> void:
		if who == Net.my_name:
			Sfx.play("engine", 0.0, 1.6))
	PetShow.show_result.connect(func(_d: Dictionary) -> void:
		if w.panel == null:
			var p := PetParkPanel.new()
			p.mode = "show_result"
			_panel(p))


func _on_street() -> void:
	if not Street.in_race(Net.my_name):
		return
	var st := str(Street.st.get("state", ""))
	if st == "countdown":
		w.hud.show_toast("Sokak yarışı başlıyor! Hazır ol...", true)
	elif st == "run":
		Sfx.play("bell", -2.0)
		_nav_cp = -1


func _on_lap() -> void:
	var st := str(Events.race.get("state", ""))
	if st == "running":
		_ghost_t0 = Time.get_ticks_msec() / 1000.0
	elif st != "countdown":
		_ghost_t0 = -1.0


# ------------------------------------------------------------------ bölge

static func in_town(p: Vector2) -> bool:
	return Map.TOWN.has_point(p)


static func blockers() -> Array:
	var out: Array = [Rect2(Map.TUNING.rect.position + Vector2(6, 30), Map.TUNING.rect.size - Vector2(12, 40))]
	for i in Map.STALL_COUNT:
		out.append(Map.stall_rect(i).grow(-6))
	out.append(Rect2(Map.PET_STAGE.position + Vector2(10, 10), Vector2(Map.PET_STAGE.size.x - 20, 60)))
	return out


func can_stand(p: Vector2) -> bool:
	var me: Vector2 = w.my_pos
	for r: Rect2 in blockers():
		if r.has_point(p) and not r.has_point(me):
			return false
	return true


func _panel(p: Control) -> void:
	if w.panel != null:
		return
	w.panel = p
	p.closed.connect(w._close_panel)
	w.ui_layer.add_child(p)
	Sfx.play("open", -4.0)


# ------------------------------------------------------------------ hareket: kayarak sürüş, nitro

## Arabada bir adım: hız istenen yöne lastik tutuşuna göre döner (fazlası kayar = drift).
func car_step(dir: Vector2, top: float, delta: float) -> Vector2:
	var t: Dictionary = Tuning.my
	var speed := top * Tuning.speed_mult(t) * (Tuning.NITRO_MULT if Tuning.nitro_on() else 1.0)
	var want := dir.normalized() * speed
	var grip := Tuning.grip(t)
	if dir == Vector2.ZERO:
		car_vel = car_vel.lerp(Vector2.ZERO, 1.0 - exp(-2.6 * delta))
	else:
		# hız büyüklüğü hızla, yönü tutuşla değişir
		var mag := lerpf(car_vel.length(), speed, 1.0 - exp(-2.2 * delta))
		var d := car_vel.normalized() if car_vel.length() > 5.0 else want.normalized()
		d = d.slerp(want.normalized(), clampf(grip * delta, 0.0, 1.0))
		car_vel = d * mag
	_drift_tick(dir, delta)
	return car_vel * delta


func coasting() -> bool:
	return car_vel.length() > 25.0


func car_bump() -> void:
	car_vel *= 0.35


func car_reset() -> void:
	car_vel = Vector2.ZERO
	_end_drift()


func _drift_tick(dir: Vector2, delta: float) -> void:
	var ang := 0.0
	if dir != Vector2.ZERO and car_vel.length() > 220.0:
		ang = absf(car_vel.angle_to(dir.normalized()))
	if ang > 0.35 and ang < 2.6:
		if not drifting:
			drifting = true
			drift_pts = 0.0
			if Map.DRIFT.has_point(w.my_pos):
				Tuning.drift_start()
		drift_pts += delta * car_vel.length() * ang * 0.35
		_drift_quiet = 0.0
		if randf() < delta * 30.0:
			skids.append([w.my_pos, Time.get_ticks_msec() / 1000.0])
			if skids.size() > 400:
				skids.pop_front()
	elif drifting:
		_drift_quiet += delta
		if _drift_quiet > 0.6:
			_end_drift()


func _end_drift() -> void:
	if not drifting:
		return
	drifting = false
	var pts := int(drift_pts)
	if pts >= 50:
		_drift_last = pts
		_drift_show = 2.5
		if Map.DRIFT.grow(80).has_point(w.my_pos):
			Tuning.drift_end(pts)
	drift_pts = 0.0


## Sel baskınında yürümek ve sürmek yavaştır.
func move_mult(p: Vector2) -> float:
	return 0.5 if Disasters.active() and Disasters.in_flood(p) else 1.0


func blocked_at(p: Vector2) -> bool:
	return Disasters.active() and Disasters.blocked_at(p)


# ------------------------------------------------------------------ bölgeler ve ipuçları

func status_line() -> String:
	var parts: Array = []
	if Disasters.active() and not in_town(w.my_pos):
		var s: Dictionary = Disasters.state
		var k := str(s.kind)
		parts.append("%s · %d/%d görev · %d:%02d" % [Disasters.KINDS[k].name.to_upper(), int(s.done), int(s.total), int(s.left) / 60, int(s.left) % 60])
		if int(s.get("carry", 0)) > 0:
			parts.append("Elinde %d %s" % [int(s.carry), Disasters.KINDS[k].supply_name.to_lower()])
	var st := str(Street.st.get("state", ""))
	if st != "" and st != "idle" and Street.in_race(Net.my_name):
		var list: Array = Street.st.get("racers", [])
		var place := 0
		var mine: Array = []
		for i in list.size():
			if str(list[i][0]) == Net.my_name:
				place = i + 1
				mine = list[i]
		match st:
			"lobby":
				parts.append("Sokak yarışı %d sn sonra · %d araba · havuz %s" % [int(Street.st.left), list.size(), U.money(int(Street.st.pot))])
			"countdown":
				parts.append("HAZIR OL: %d" % int(ceil(float(Street.st.left))))
			"run":
				var cp := int(mine[6]) if mine.size() > 6 else 0
				parts.append("Sokak yarışı: %d./%d · Tur %d/%d · %.1f sn" % [place, list.size(), mini(cp / Map.RACE_CPS.size() + 1, Street.LAPS), Street.LAPS, float(Street.st.left)])
			"done":
				parts.append("Yarış bitti: %d. oldun" % place if mine.size() > 2 and float(mine[2]) >= 0.0 else "Yarış bitti")
	if w.my_ride() == "car":
		if drifting and drift_pts > 20.0:
			parts.append("DRIFT %d" % int(drift_pts))
		elif _drift_show > 0.0:
			parts.append("Drift: %d puan" % _drift_last)
		if int(Tuning.my.get("nitro", 0)) > 0:
			parts.append("Nitro [N]: %d" % int(Tuning.my.get("charges", 0)))
	if in_town(w.my_pos) and str(PetShow.race.get("state", "")) in ["lobby", "run"]:
		parts.append("Parkur yarışı %s" % ("%d sn sonra" % int(PetShow.race.left) if PetShow.race.state == "lobby" else "sürüyor!"))
	return "  ·  ".join(parts)


func update_zone() -> void:
	var me: Vector2 = w.my_pos
	var z := {}
	var si := Stalls.stall_near(me)
	if si >= 0:
		var v: Dictionary = Stalls.view[si] if si < Stalls.view.size() else {}
		if v.is_empty() or not bool(v.get("open", false)):
			z = {"type": "town", "do": "stall", "i": si, "label": "%d numaralı tezgâh — boş, kirala (%s / gün)" % [si + 1, U.money(int(Projects.mahalle.get("rent", Stalls.RENT)))]}
		else:
			z = {"type": "town", "do": "stall", "i": si, "label": "%s%s" % [v.name, "  (senin)" if v.owner == Net.my_name else " — %d çeşit mal" % v.items.size()]}
	if me.distance_to(Map.WANTED_BOARD) < 110.0:
		z = {"type": "town", "do": "wanted", "label": "Alım ilanları panosu (%d ilan)" % Stalls.wanted.size()}
	if (Map.TUNING.rect as Rect2).grow(50).has_point(me):
		z = {"type": "town", "do": "tuning", "label": "Tuning Garajı — motor, lastik, nitro, neon"}
	if me.distance_to(Map.PET_BOOTH) < 110.0:
		var rs := str(PetShow.race.get("state", "idle"))
		z = {"type": "town", "do": "pet_race", "label": "Parkur yarışı — katıl (%s)" % U.money(PetShow.RACE_FEE) if rs in ["", "idle", "lobby"] else "Parkur yarışı — bir sonrakine katıl"}
	if Map.PET_STAGE.grow(70).has_point(me):
		z = {"type": "town", "do": "pet_show", "label": "Güzellik şovu — sahneye çık (%s)" % U.money(PetShow.SHOW_FEE)}
	for k in Map.PET_SPOTS:
		if me.distance_to(Map.PET_SPOTS[k]) < 90.0:
			z = {"type": "town", "do": "pet_train", "spot": k, "label": "Eğit: %s (%s)" % [{"kosu": "koşu bandı", "slalom": "slalom direkleri", "bakim": "bakım masası"}[k], PetShow.STATS[k][1]]}
	if me.distance_to(Map.PET_KIOSK) < 110.0:
		z = {"type": "town", "do": "pet_kiosk", "label": "Evcil hayvan aksesuarları ve kupalar"}
	z = w.v20.extra_zone(z)
	z = w._rail_zone(z)
	w.zone = z
	w._g_action = {}
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	if Map.DRIFT.has_point(me) and w.my_ride() == "car":
		hint += ("\n" if hint != "" else "") + "DRIFT ALANI: hızlıyken keskin dön, kaymayı sürdür! En iyin: %d" % int(Tuning.my.get("drift_best", 0))
	w.hud.set_hint("" if w.panel != null else w.adv.decorate(hint))


## Şehirde afet görevleri (E alanları).
func extra_zone(z: Dictionary) -> Dictionary:
	if not Disasters.active() or w._room >= 0 or w._fair or w._mount:
		return z
	var me: Vector2 = w.my_pos
	var s: Dictionary = Disasters.state
	var k := str(s.kind)
	for b in s.get("bld", []):
		var bd: Dictionary = Map.building(str(b[0]))
		if not bd.is_empty() and (bd.rect as Rect2).grow(30).has_point(me):
			z = {"type": "town", "do": "repair", "t": str(b[0]), "label": "HASARLI: %s — onar (basılı tut) %d/%d" % [bd.label, int(b[1]), int(b[2])]}
	var pools: Array = s.get("pools", [])
	for i in pools.size():
		if me.distance_to(Vector2(pools[i][0], pools[i][1])) < float(pools[i][2]) + 50.0:
			z = {"type": "town", "do": "pool", "i": i, "label": "Su baskını — kum torbası koy (%d/%d)" % [int(pools[i][3]), Disasters.POOL_BAGS]}
	var piles: Array = s.get("piles", [])
	for i in piles.size():
		if me.distance_to(Vector2(piles[i][0], piles[i][1])) < 80.0:
			z = {"type": "town", "do": "pile", "i": i, "label": ("Kar yığınını kürekle" if k == "kar" else "Enkazı temizle") + " (basılı tut)"}
	var people: Array = s.get("people", [])
	for i in people.size():
		if me.distance_to(Vector2(people[i][0], people[i][1])) < 80.0:
			z = {"type": "town", "do": "person", "i": i, "label": {"yarali": "Yaralıya ilk yardım yap", "mahsur": "Mahsur kalanı kurtar", "donuk": "Battaniye ver"}.get(str(people[i][3]), "Yardım et")}
	if me.distance_to(Map.AID_TENT) < Disasters.TENT_R:
		z = {"type": "town", "do": "aid", "label": "Yardım çadırı — %s al" % Disasters.KINDS[k].supply_name.to_lower()}
	return z


func open(z: Dictionary) -> bool:
	if str(z.get("type", "")) != "town":
		# hasarlı binanın paneli açılmaz
		if Disasters.active() and Disasters.damaged(str(z.get("type", ""))):
			w.hud.show_toast("Bina depremde hasar gördü; önce onarılmalı.", false)
			return true
		return false
	match str(z.get("do", "")):
		"stall":
			var p := StallPanel.new()
			p.stall = int(z.i)
			_panel(p)
		"wanted":
			_panel(WantedPanel.new())
		"tuning":
			_panel(TuningPanel.new())
		"pet_race":
			PetShow.join_race()
		"pet_show":
			PetShow.enter_show()
		"pet_train":
			PetShow.train(str(z.spot))
			Sfx.play("step", -4.0, 1.4)
		"pet_kiosk":
			_panel(PetParkPanel.new())
		"aid":
			Disasters.take_supply()
			Sfx.play("place", -4.0)
		"pile":
			Disasters.work_pile(int(z.i))
			Sfx.play("pick", -5.0, 0.8)
		"repair":
			Disasters.repair(str(z.t))
			Sfx.play("pick", -5.0, 1.2)
		"person":
			Disasters.help_person(int(z.i))
			Sfx.play("success", -6.0)
		"pool":
			Disasters.bag_pool(int(z.i))
			Sfx.play("splash_small", -4.0, 0.7)
	return true


func tick(delta: float) -> void:
	_drift_show = maxf(0.0, _drift_show - delta)
	var zd := str(w.zone.get("do", ""))
	if w.panel == null and zd in ["pile", "repair"] and Settings.held("interact"):
		_hold_acc += delta
		if _hold_acc >= 0.45:
			_hold_acc = 0.0
			open(w.zone)
	# deprem sarsıntısı
	var since := Time.get_ticks_msec() / 1000.0 - Disasters.shake_t
	if since < 5.0:
		var amp := 14.0 * (1.0 - since / 5.0)
		w.camera.offset = Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
	elif w.camera.offset != Vector2.ZERO:
		w.camera.offset = Vector2.ZERO
	if w.my_ride() != "car" and car_vel != Vector2.ZERO:
		car_reset()
	# sokak yarışında sıradaki kontrol noktasına yön oku (değişince bir kez)
	if str(Street.st.get("state", "")) == "run" and Street.in_race(Net.my_name):
		var cp := Street.next_cp()
		var key := int(cp.x * 7 + cp.y)
		if key != _nav_cp:
			_nav_cp = key
			w.set_nav(cp)
	var now := Time.get_ticks_msec() / 1000.0
	while not skids.is_empty() and now - float(skids[0][1]) > 6.0:
		skids.pop_front()


func input(event: InputEvent) -> bool:
	if w.panel != null:
		return false
	if event is InputEventKey and event.pressed and not event.echo and Settings.is_key(event, "nitro"):
		if w.my_ride() == "car" and int(Tuning.my.get("charges", 0)) > 0 and not Tuning.nitro_on():
			Tuning.fire_nitro()
		return true
	return false


# ------------------------------------------------------------------ çizim: Yeni Mahalle

func draw_region(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#3f6212"))
	var t: Rect2 = Map.TOWN
	w.draw_rect(t, Color("#65a30d"))
	var g := 120
	for gx in range(int(maxf(t.position.x, view.position.x) / g) * g, int(minf(t.end.x, view.end.x)), g):
		for gy in range(int(maxf(t.position.y, view.position.y) / g) * g, int(minf(t.end.y, view.end.y)), g):
			var h := absi((gx * 73856093) ^ (gy * 19349663))
			if h % 4 == 0:
				w.draw_circle(Vector2(gx + h % 100, gy + h % 90), 18 + h % 20, Color(0.35, 0.55, 0.12, 0.35))
			if h % 9 == 0:
				w.draw_circle(Vector2(gx + h % 80, gy + h % 60), 3, Color("#fde047"))
	_road(Map.TOWN_ROAD, true)
	_road(Map.TOWN_AVE, false)
	w._draw_rails()
	_draw_market()
	_draw_tuning()
	_draw_drift()
	_draw_pet_park(items)
	w.v20.draw_town(view)
	for p: Rect2 in [Rect2(t.position.x + 20, 290, 40, 40), Rect2(t.end.x - 70, 300, 40, 40)]:
		w.draw_circle(p.get_center(), 30, Color("#166534"))
	# meydanı dolaşan müşteriler
	var tt: float = w._t
	for k in 7:
		var a := tt * 0.06 + k * 0.9
		var c := Map.MARKET_SQ.get_center() + Vector2(cos(a) * 360.0, sin(a * 1.3) * 120.0 + 20.0)
		var facing := "left" if -sin(a) < 0.0 else "right"
		items.append([c.y, "visitor", [c, k, facing]])


func _road(r: Rect2, horizontal: bool) -> void:
	w.draw_rect(r, Color("#374151"))
	if horizontal:
		for x in range(int(r.position.x) + 20, int(r.end.x), 80):
			w.draw_rect(Rect2(x, r.get_center().y - 2, 40, 4), Color("#f8fafc"))
		w.draw_rect(Rect2(r.position.x, r.position.y - 8, r.size.x, 8), Color("#d6d3d1"))
		w.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 8), Color("#d6d3d1"))
	else:
		for y in range(int(r.position.y) + 20, int(r.end.y), 80):
			w.draw_rect(Rect2(r.get_center().x - 2, y, 4, 40), Color("#f8fafc"))
		w.draw_rect(Rect2(r.position.x - 8, r.position.y, 8, r.size.y), Color("#d6d3d1"))
		w.draw_rect(Rect2(r.end.x, r.position.y, 8, r.size.y), Color("#d6d3d1"))


func _draw_market() -> void:
	var sq: Rect2 = Map.MARKET_SQ
	w.draw_rect(sq, Color("#d6c7a8"))
	for x in range(int(sq.position.x), int(sq.end.x), 40):
		w.draw_line(Vector2(x, sq.position.y), Vector2(x, sq.end.y), Color("#c4b393"), 1)
	for y in range(int(sq.position.y), int(sq.end.y), 40):
		w.draw_line(Vector2(sq.position.x, y), Vector2(sq.end.x, y), Color("#c4b393"), 1)
	w._text(sq.position + Vector2(0, 6), "PAZAR MEYDANI", 22, Color("#7c2d12"), sq.size.x, false)
	for i in Map.STALL_COUNT:
		_draw_stall(i)
	# alım ilanları panosu
	var b: Vector2 = Map.WANTED_BOARD
	w.draw_rect(Rect2(b.x - 6, b.y - 20, 6, 40), Color("#78350f"))
	w.draw_rect(Rect2(b.x + 74, b.y - 20, 6, 40), Color("#78350f"))
	w.draw_rect(Rect2(b.x - 10, b.y - 80, 94, 64), Color("#a16207"))
	w.draw_rect(Rect2(b.x - 4, b.y - 74, 82, 52), Color("#fef3c7"))
	for k in mini(6, Stalls.wanted.size()):
		w.draw_rect(Rect2(b.x + (k % 3) * 26, b.y - 70 + (k / 3) * 24, 22, 20), Color("#ffffff"))
		w.draw_line(Vector2(b.x + 3 + (k % 3) * 26, b.y - 62 + (k / 3) * 24), Vector2(b.x + 18 + (k % 3) * 26, b.y - 62 + (k / 3) * 24), Color("#64748b"), 1)
	w._text(b + Vector2(-60, -104), "ALIM İLANLARI", 13, Color("#7c2d12"), 200, false)
	# çeşme
	var f := sq.get_center() + Vector2(0, 30)
	w.draw_circle(f, 42, Color("#a8a29e"))
	w.draw_circle(f, 34, Color("#38bdf8"))
	for k in 3:
		var u := fmod(float(w._t) * 1.2 + k / 3.0, 1.0)
		w.draw_circle(f + Vector2(0, -u * 24.0), 4.0 - u * 2.0, Color(1, 1, 1, 0.7 * (1.0 - u)))


func _draw_stall(i: int) -> void:
	var r := Map.stall_rect(i)
	var v: Dictionary = Stalls.view[i] if i < Stalls.view.size() else {}
	var open := not v.is_empty() and bool(v.get("open", false))
	var col: Color = Stalls.COLORS[int(v.get("color", i)) % Stalls.COLORS.size()] if open else Color("#a8a29e")
	w.draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.2))
	# tezgâh gövdesi
	w.draw_rect(Rect2(r.position.x, r.position.y + 50, r.size.x, r.size.y - 50), Color("#92400e"))
	w.draw_rect(Rect2(r.position.x, r.position.y + 50, r.size.x, 10), Color("#b45309"))
	# tente (çizgili)
	for k in 6:
		var sx := r.position.x + k * r.size.x / 6.0
		w.draw_rect(Rect2(sx, r.position.y, r.size.x / 6.0, 36), col if k % 2 == 0 else Color.WHITE)
	for k in 6:
		w.draw_circle(Vector2(r.position.x + (k + 0.5) * r.size.x / 6.0, r.position.y + 36), r.size.x / 12.0, col if k % 2 == 0 else Color.WHITE)
	w.draw_line(r.position + Vector2(4, 36), r.position + Vector2(4, 110), Color("#57534e"), 3)
	w.draw_line(r.position + Vector2(r.size.x - 4, 36), r.position + Vector2(r.size.x - 4, 110), Color("#57534e"), 3)
	if open:
		var items: Array = v.get("items", [])
		for k in mini(items.size(), 8):
			var ip := r.position + Vector2(18 + (k % 4) * 42, 66 + (k / 4) * 18)
			var kc: Color = {"fish": Color("#60a5fa"), "food": Color("#f59e0b"), "crop": Color("#84cc16")}.get(str(items[k].kind), Color.WHITE)
			w.draw_rect(Rect2(ip - Vector2(12, 6), Vector2(24, 12)), Color("#fef3c7"))
			w.draw_circle(ip, 5, kc)
		w._text(Vector2(r.position.x - 20, r.end.y + 8), str(v.name), 13, Color.WHITE, r.size.x + 40)
	else:
		w.draw_rect(Rect2(r.get_center().x - 46, r.position.y + 66, 92, 26), Color("#fef3c7"))
		w._text(Vector2(r.get_center().x - 46, r.position.y + 70), "KİRALIK", 13, Color("#7c2d12"), 92, false)
	w._text(r.position + Vector2(-10, -22), "#%d" % (i + 1), 12, Color("#78350f"), 40, false)


func _draw_tuning() -> void:
	var r: Rect2 = Map.TUNING.rect
	w.draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.25))
	w.draw_rect(r, Color("#27272a"))
	w.draw_rect(Rect2(r.position, Vector2(r.size.x, 40)), Color("#18181b"))
	var neon := Color(0.95, 0.2, 0.6, 0.75 + 0.25 * sin(float(w._t) * 4.0))
	w._text(r.position + Vector2(0, 4), "TUNING GARAJI", 22, neon, r.size.x)
	w.draw_rect(Rect2(r.position.x + 40, r.end.y - 130, 200, 130), Color("#52525b"))
	for k in 7:
		w.draw_line(Vector2(r.position.x + 40, r.end.y - 130 + k * 18), Vector2(r.position.x + 240, r.end.y - 130 + k * 18), Color("#3f3f46"), 2)
	# lift üstünde araba
	w.draw_rect(Rect2(r.position.x + 270, r.end.y - 60, 120, 10), Color("#facc15"))
	w._draw_vehicle(Vector2(r.position.x + 330, r.end.y - 92), "car", "right", Color("#ef4444"), {"neon": 1, "spoiler": true})


func _draw_drift() -> void:
	var r: Rect2 = Map.DRIFT
	w.draw_rect(r, Color("#3f3f46"))
	w.draw_rect(r, Color("#facc15"), false, 4)
	for k in 14:
		var a := k * 0.7
		var c := r.get_center() + Vector2(cos(a) * 220.0, sin(a) * 90.0)
		w.draw_arc(c, 40 + k % 3 * 10, a, a + 2.0, 12, Color(0.1, 0.1, 0.1, 0.5), 3)
	for k in 10:
		var cp := r.position + Vector2(40 + k * (r.size.x - 80) / 9.0, r.size.y / 2.0 + (k % 2) * 40 - 20)
		w.draw_colored_polygon(PackedVector2Array([cp + Vector2(-8, 8), cp + Vector2(8, 8), cp + Vector2(0, -12)]), Color("#f97316"))
		w.draw_line(cp + Vector2(-5, 0), cp + Vector2(5, 0), Color.WHITE, 2)
	w._text(r.position + Vector2(0, 6), "DRIFT ALANI", 20, Color("#fde68a"), r.size.x, false)


func _draw_pet_park(items: Array) -> void:
	var r: Rect2 = Map.PET_PARK
	w.draw_rect(r, Color("#4d7c0f"))
	w.draw_rect(r, Color("#a16207"), false, 5)
	for x in range(int(r.position.x), int(r.end.x), 40):
		w.draw_line(Vector2(x, r.position.y - 6), Vector2(x, r.position.y + 6), Color("#a16207"), 3)
	w._text(r.position + Vector2(0, 8), "EVCİL HAYVAN PARKI", 22, Color("#fef9c3"), r.size.x)
	# parkur
	var pts: Array = Map.PET_TRACK
	for i in pts.size() - 1:
		w.draw_line(pts[i], pts[i + 1], Color("#d6b98c"), 54)
		w.draw_circle(pts[i + 1], 27, Color("#d6b98c"))
	w.draw_circle(pts[0], 27, Color("#d6b98c"))
	for k in 6:
		w.draw_rect(Rect2(pts[0].x - 30 + k * 10, pts[0].y - 27, 10, 54), Color.WHITE if k % 2 == 0 else Color.BLACK)
	var fin: Vector2 = pts[-1]
	for k in 6:
		w.draw_rect(Rect2(fin.x - 5, fin.y - 27 + k * 9, 10, 9), Color.WHITE if k % 2 == 0 else Color.BLACK)
	var L := PetShow.track_len()
	for o in PetShow.OBSTACLES:
		var op := PetShow.track_pos(float(o[0]) * L)
		match str(o[1]):
			"cember":
				w.draw_arc(op + Vector2(0, -16), 22, PI, TAU, 16, Color("#ef4444"), 5)
				w.draw_line(op + Vector2(-22, -16), op + Vector2(-22, 14), Color("#e5e7eb"), 3)
				w.draw_line(op + Vector2(22, -16), op + Vector2(22, 14), Color("#e5e7eb"), 3)
			"slalom":
				for k in 5:
					var sp := PetShow.track_pos(float(o[0]) * L - 40 + k * 20) + Vector2(0, (k % 2) * 14 - 7)
					w.draw_line(sp, sp + Vector2(0, -26), Color("#facc15") if k % 2 == 0 else Color("#3b82f6"), 4)
			"engel":
				w.draw_rect(Rect2(op + Vector2(-26, -14), Vector2(52, 6)), Color("#f97316"))
				w.draw_line(op + Vector2(-26, -14), op + Vector2(-26, 14), Color("#e5e7eb"), 3)
				w.draw_line(op + Vector2(26, -14), op + Vector2(26, 14), Color("#e5e7eb"), 3)
			"tunel":
				w.draw_rect(Rect2(op + Vector2(-40, -20), Vector2(80, 34)), Color("#2563eb"))
				for k in 4:
					w.draw_line(op + Vector2(-40 + k * 26, -20), op + Vector2(-40 + k * 26, 14), Color("#1d4ed8"), 2)
				w.draw_circle(op + Vector2(-40, -3), 14, Color("#1e3a8a"))
	# gişe
	var b: Vector2 = Map.PET_BOOTH
	w.draw_rect(Rect2(b.x - 36, b.y - 54, 72, 50), Color("#f59e0b"))
	w.draw_colored_polygon(PackedVector2Array([b + Vector2(-44, -54), b + Vector2(44, -54), b + Vector2(0, -80)]), Color("#b45309"))
	w._text(b + Vector2(-90, -110), "PARKUR YARIŞI", 14, Color("#fef3c7"), 180)
	# eğitim yerleri
	var ks: Vector2 = Map.PET_SPOTS.kosu
	w.draw_rect(Rect2(ks.x - 50, ks.y - 22, 100, 28), Color("#27272a"))
	for k in 6:
		var x := fmod(float(w._t) * 60.0 + k * 18.0, 96.0)
		w.draw_line(Vector2(ks.x - 48 + x, ks.y - 20), Vector2(ks.x - 48 + x, ks.y + 4), Color("#52525b"), 2)
	w._text(ks + Vector2(-70, -54), "KOŞU BANDI", 12, Color.WHITE, 140)
	var sl: Vector2 = Map.PET_SPOTS.slalom
	for k in 6:
		w.draw_line(sl + Vector2(-60 + k * 24, 0), sl + Vector2(-60 + k * 24, -30), Color("#facc15") if k % 2 == 0 else Color("#ef4444"), 4)
	w._text(sl + Vector2(-70, -60), "SLALOM", 12, Color.WHITE, 140)
	var bk: Vector2 = Map.PET_SPOTS.bakim
	w.draw_rect(Rect2(bk.x - 40, bk.y - 24, 80, 26), Color("#e5e7eb"))
	w.draw_rect(Rect2(bk.x - 34, bk.y + 2, 6, 18), Color("#9ca3af"))
	w.draw_rect(Rect2(bk.x + 28, bk.y + 2, 6, 18), Color("#9ca3af"))
	w.draw_circle(bk + Vector2(26, -30), 8, Color("#f472b6"))
	w._text(bk + Vector2(-70, -60), "BAKIM MASASI", 12, Color.WHITE, 140)
	# sahne
	var s: Rect2 = Map.PET_STAGE
	w.draw_rect(Rect2(s.position + Vector2(6, 10), s.size), Color(0, 0, 0, 0.25))
	w.draw_rect(s, Color("#92400e"))
	w.draw_rect(Rect2(s.position, Vector2(s.size.x, 70)), Color("#7f1d1d"))
	for k in 8:
		w.draw_line(Vector2(s.position.x + k * s.size.x / 8.0, s.position.y), Vector2(s.position.x + k * s.size.x / 8.0 + 20, s.position.y + 70), Color("#991b1b"), 6)
	w._text(s.position + Vector2(0, 18), "GÜZELLİK ŞOVU", 18, Color("#fde68a"), s.size.x)
	for k in 3:
		var jp := s.position + Vector2(90 + k * 130, s.end.y + 40)
		w.draw_rect(Rect2(jp.x - 40, jp.y - 10, 80, 20), Color("#78350f"))
		w._text(jp + Vector2(-30, -42), "JÜRİ", 11, Color("#fef3c7"), 60)
	# aksesuar dükkânı
	var kp: Vector2 = Map.PET_KIOSK
	w.draw_rect(Rect2(kp.x - 60, kp.y - 80, 120, 80), Color("#f9a8d4"))
	w.draw_rect(Rect2(kp.x - 66, kp.y - 96, 132, 20), Color("#db2777"))
	w.draw_circle(kp + Vector2(-30, -40), 10, Color("#facc15"))
	w.draw_rect(Rect2(kp.x + 10, kp.y - 50, 30, 10), Color("#ef4444"))
	w._text(kp + Vector2(-90, -130), "AKSESUAR · KUPALAR", 13, Color("#fdf2f8"), 180)
	# yarışan hayvanlar
	for pr in PetShow.race.get("pets", []):
		var d := float(pr[3])
		var pp := PetShow.track_pos(d) + Vector2(0, (hash(str(pr[0])) % 3 - 1) * 12)
		var nxt := PetShow.track_pos(minf(L, d + 10.0))
		var fac := "left" if nxt.x < pp.x - 1.0 else "right"
		items.append([pp.y, "rpet", [{"pos": pp, "facing": fac, "moving": float(pr[4]) < 0.0}, {"kind": str(pr[2]), "name": str(pr[0]), "happy": true}]])


func draw_item(kind: String, d) -> bool:
	match kind:
		"visitor":
			var apps := [{"skin": 1, "hair": 2, "hair_color": 1, "shirt": 3, "pants": 2}, {"skin": 3, "hair": 0, "hair_color": 0, "shirt": 7, "pants": 1},
				{"skin": 0, "hair": 4, "hair_color": 3, "shirt": 1, "pants": 4}, {"skin": 2, "hair": 1, "hair_color": 5, "shirt": 9, "pants": 0}]
			Avatar.draw(w, d[0], apps[int(d[1]) % apps.size()], str(d[2]), int(float(w._t) * 4.0 + int(d[1])) % 2)
		"rpet":
			w._draw_pet(d[0], d[1])
		"pile":
			_draw_pile(d)
		"person":
			_draw_person(d)
		_:
			return false
	return true


# ------------------------------------------------------------------ çizim: şehir (afet, yarış, hayalet)

func draw_ground() -> void:
	var view: Rect2 = w._view_rect().grow(200)
	if Disasters.active():
		var s: Dictionary = Disasters.state
		for pl in s.get("pools", []):
			var c := Vector2(pl[0], pl[1])
			var r := float(pl[2])
			if not view.grow(r).has_point(c):
				continue
			w.draw_set_transform(c, 0, Vector2(1, 0.6))
			w.draw_circle(Vector2.ZERO, r, Color(0.35, 0.5, 0.6, 0.75))
			w.draw_circle(Vector2.ZERO, r * 0.8, Color(0.3, 0.45, 0.58, 0.6))
			w.draw_set_transform(Vector2.ZERO)
			for k in int(pl[3]):
				var bp := c + Vector2(-r * 0.6 + k * 26, r * 0.55)
				w.draw_rect(Rect2(bp.x - 12, bp.y - 7, 24, 14), Color("#d6b98c"))
		if view.has_point(Map.AID_TENT):
			_draw_aid_tent(Map.AID_TENT, str(s.kind))
	# pist hayaleti
	if _ghost_t0 > 0.0 and not Events.ghost.is_empty():
		var path: Array = Events.ghost.get("path", [])
		var k := int((Time.get_ticks_msec() / 1000.0 - _ghost_t0) / Events.GHOST_STEP)
		if k * 2 + 1 < path.size():
			var gp := Vector2(path[k * 2], path[k * 2 + 1])
			var nx := Vector2(path[mini(k * 2 + 2, path.size() - 2)], path[mini(k * 2 + 3, path.size() - 1)])
			var fac: String = w._facing_of(nx - gp) if nx.distance_to(gp) > 1.0 else "right"
			_ghost_car(gp, fac)
			w._text(gp + Vector2(-80, -60), "HAYALET: %s (%.2f sn)" % [Events.ghost.get("name", ""), float(Events.ghost.get("time", 0.0))], 12, Color(0.75, 0.9, 1.0, 0.85), 160)
	# sokak yarışı: botlar ve kontrol noktası
	var st := str(Street.st.get("state", ""))
	if st in ["countdown", "run", "done"]:
		for r in Street.st.get("racers", []):
			if bool(r[5]):
				var bp := Vector2(r[3], r[4])
				var prev: Vector2 = _bot_prev.get(str(r[0]), bp)
				if prev.distance_to(bp) > 2.0:
					_bot_face[str(r[0])] = w._facing_of(bp - prev)
				_bot_prev[str(r[0])] = bp
				if view.has_point(bp):
					w._draw_vehicle(bp, "car", str(_bot_face.get(str(r[0]), "right")), Color("#94a3b8"), {"neon": absi(hash(str(r[0]))) % 6})
					w._text(bp + Vector2(-60, -50), str(r[0]), 12, Color("#e2e8f0"), 120)
		if st == "run" and Street.in_race(Net.my_name):
			var cp := Street.next_cp()
			w.draw_arc(cp, Map.RACE_CP_RADIUS, 0, TAU, 40, Color(1.0, 0.85, 0.2, 0.7), 5)


## Binalar çizildikten sonra: depremde hasarlı binaların çatlakları ve iskelesi.
func draw_after_buildings() -> void:
	if not Disasters.active():
		return
	var view: Rect2 = w._view_rect().grow(200)
	for b in Disasters.state.get("bld", []):
		var bd: Dictionary = Map.building(str(b[0]))
		if not bd.is_empty() and view.intersects(bd.rect):
			_draw_damage(bd.rect, float(b[1]) / float(b[2]))


func _ghost_car(p: Vector2, facing: String) -> void:
	var ang: float = FACING.get(facing, 0.0)
	w.draw_set_transform(p, ang, Vector2.ONE)
	w.draw_rect(Rect2(-46, -24, 92, 48), Color(0.6, 0.85, 1.0, 0.35))
	w.draw_rect(Rect2(-46, -24, 92, 48), Color(0.8, 0.95, 1.0, 0.6), false, 2)
	w.draw_rect(Rect2(-10, -18, 30, 36), Color(0.8, 0.95, 1.0, 0.3))
	w.draw_set_transform(Vector2.ZERO)


func add_items(items: Array) -> void:
	if not Disasters.active() or w._room >= 0:
		return
	var s: Dictionary = Disasters.state
	for pl in s.get("piles", []):
		items.append([float(pl[1]), "town", ["pile", pl, str(s.kind)]])
	for pp in s.get("people", []):
		items.append([float(pp[1]), "town", ["person", pp]])


func draw_city_item(d: Array) -> void:
	match str(d[0]):
		"pile":
			_draw_pile([d[1], d[2]])
		"person":
			_draw_person([d[1]])


func _draw_pile(d: Array) -> void:
	var pl: Array = d[0]
	var p := Vector2(pl[0], pl[1])
	var hp := int(pl[2])
	var snow := str(d[1]) == "kar" if d.size() > 1 else false
	var s := 0.55 + 0.12 * hp
	if snow:
		w.draw_set_transform(p, 0, Vector2(1, 0.55))
		w.draw_circle(Vector2.ZERO, 44 * s, Color("#e2e8f0"))
		w.draw_circle(Vector2(-14, -10) * s, 30 * s, Color("#f8fafc"))
		w.draw_set_transform(Vector2.ZERO)
		return
	var rocks := [[-22, -4, 16, "#78716c"], [8, -10, 18, "#a8a29e"], [20, 4, 12, "#57534e"], [-6, 8, 14, "#d6d3d1"], [-30, 10, 10, "#a8a29e"]]
	for rk in rocks.slice(0, 2 + hp):
		w.draw_circle(p + Vector2(rk[0], rk[1]) * s, float(rk[2]) * s, Color(rk[3]))
	w.draw_line(p + Vector2(-34, -16) * s, p + Vector2(30, -26) * s, Color("#6b4423"), 5)
	w.draw_line(p + Vector2(-12, -30) * s, p + Vector2(10, 4) * s, Color("#9ca3af"), 3)


func _draw_person(d: Array) -> void:
	var pp: Array = d[0]
	var p := Vector2(pp[0], pp[1])
	var kind := str(pp[3])
	var t: float = w._t
	match kind:
		"yarali":
			w.draw_set_transform(p + Vector2(0, -6), PI / 2.0, Vector2.ONE)
			Avatar.draw(w, Vector2.ZERO, {"skin": 2, "hair": 3, "hair_color": 1, "shirt": 5, "pants": 2}, "down", 0)
			w.draw_set_transform(Vector2.ZERO)
			w.draw_rect(Rect2(p.x - 10, p.y - 64, 20, 20), Color.WHITE)
			w.draw_rect(Rect2(p.x - 3, p.y - 61, 6, 14), Color("#dc2626"))
			w.draw_rect(Rect2(p.x - 7, p.y - 57, 14, 6), Color("#dc2626"))
		"mahsur":
			w._draw_vehicle(p + Vector2(0, 16), "car", "right", Color("#64748b"))
			Avatar.draw(w, p + Vector2(0, -6), {"skin": 1, "hair": 0, "hair_color": 2, "shirt": 2, "pants": 3}, "down", int(t * 3.0) % 2)
			w.draw_line(p + Vector2(10, -46), p + Vector2(22, -66 + sin(t * 9.0) * 6.0), Color("#e8b48a"), 4)
		"donuk":
			Avatar.draw(w, p, {"skin": 0, "hair": 2, "hair_color": 4, "shirt": 6, "pants": 1}, "down", 0)
			for k in 3:
				w.draw_circle(p + Vector2(-14 + k * 14, -70 - fmod(t * 20.0 + k * 10.0, 20.0)), 3, Color(0.85, 0.95, 1.0, 0.8))
	var bp := p + Vector2(0, -100 + sin(t * 3.0) * 3.0)
	w.draw_circle(bp, 13, Color.WHITE)
	w._text(bp + Vector2(-10, -12), "!", 20, Color("#dc2626"), 20, false)


func _draw_damage(r: Rect2, prog: float) -> void:
	# çatlaklar, dökülen sıva ve iskele
	for k in 4:
		var a := r.position + Vector2(r.size.x * (0.15 + k * 0.22), r.size.y * 0.3)
		w.draw_polyline(PackedVector2Array([a, a + Vector2(10, 24), a + Vector2(-4, 46), a + Vector2(12, 70)]), Color("#1c1917"), 3)
	w.draw_rect(Rect2(r.position.x, r.end.y - 30, r.size.x, 30), Color(0.47, 0.44, 0.42, 0.6))
	for k in int(r.size.x / 40.0):
		w.draw_line(Vector2(r.position.x + k * 40, r.position.y + 40), Vector2(r.position.x + k * 40, r.end.y), Color("#ca8a04"), 3)
	for y in [r.position.y + 60, r.position.y + 140]:
		w.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("#ca8a04"), 3)
	w.draw_rect(Rect2(r.get_center().x - 80, r.end.y + 6, 160, 10), Color(0, 0, 0, 0.6))
	w.draw_rect(Rect2(r.get_center().x - 80, r.end.y + 6, 160 * prog, 10), Color("#22c55e"))
	w._text(Vector2(r.get_center().x - 120, r.end.y + 18), "HASARLI — ONARILIYOR", 13, Color("#fca5a5"), 240)


func _draw_aid_tent(p: Vector2, kind: String) -> void:
	w.draw_circle(p + Vector2(0, -20), 130, Color(1.0, 0.9, 0.6, 0.12))
	w.draw_rect(Rect2(p.x - 70, p.y - 60, 140, 60), Color("#f8fafc"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-80, -60), p + Vector2(80, -60), p + Vector2(0, -110)]), Color("#e2e8f0"))
	w.draw_rect(Rect2(p.x - 10, p.y - 92, 20, 6), Color("#dc2626"))
	w.draw_rect(Rect2(p.x - 3, p.y - 99, 6, 20), Color("#dc2626"))
	w.draw_rect(Rect2(p.x - 18, p.y - 40, 36, 40), Color("#94a3b8"))
	for k in 3:
		var bp := p + Vector2(80 + k * 22, -6)
		var c: Color = {"deprem": Color("#ef4444"), "sel": Color("#d6b98c"), "kar": Color("#3b82f6")}.get(kind, Color.WHITE)
		w.draw_rect(Rect2(bp.x - 10, bp.y - 10 - (k % 2) * 6, 20, 16), c)
	w._text(p + Vector2(-100, -146), "YARDIM ÇADIRI", 16, Color("#fecaca"), 200)


## Şehrin üstüne: kar fırtınası beyazlığı, sel ve deprem tozu.
func draw_overlay() -> void:
	var view: Rect2 = w._view_rect().grow(50)
	var k := str(Disasters.state.get("kind", "")) if Disasters.active() else ""
	if k == "kar" and w._room < 0 and not w._fair and not w._mount:
		w.draw_rect(view, Color(0.92, 0.95, 1.0, 0.22))
		var t: float = w._t
		for n in 90:
			var x := fposmod(n * 97.0 + t * (220.0 + n % 5 * 30.0), view.size.x)
			var y := fposmod(n * 53.0 + t * (90.0 + n % 7 * 20.0), view.size.y)
			w.draw_line(view.position + Vector2(x, y), view.position + Vector2(x - 14, y + 5), Color(1, 1, 1, 0.8), 2)
	elif k == "deprem" and Time.get_ticks_msec() / 1000.0 - Disasters.shake_t < 8.0:
		w.draw_rect(view, Color(0.6, 0.55, 0.45, 0.18))
	# kayma izleri
	var now := Time.get_ticks_msec() / 1000.0
	for s in skids:
		var a := clampf(1.0 - (now - float(s[1])) / 6.0, 0.0, 1.0) * 0.5
		w.draw_circle(s[0] + Vector2(-20, 14), 4, Color(0.1, 0.1, 0.1, a))
		w.draw_circle(s[0] + Vector2(20, 14), 4, Color(0.1, 0.1, 0.1, a))


## Arabanın altına neon, arkasına spoyler (world._draw_vehicle çağırır).
func draw_car_under(vstyle: Dictionary) -> void:
	var n := int(vstyle.get("neon", -1))
	if n >= 0 and n < Tuning.NEONS.size():
		var c: Color = Tuning.NEONS[n]
		var pulse := 0.16 + 0.06 * sin(float(w._t) * 5.0)
		for x in [-30.0, -10.0, 10.0, 30.0]:
			w.draw_circle(Vector2(x, 0), 40, Color(c, pulse * 0.6))
			w.draw_circle(Vector2(x, 0), 30, Color(c, pulse))


func draw_car_over(vstyle: Dictionary) -> void:
	if bool(vstyle.get("spoiler", false)):
		w.draw_rect(Rect2(-50, -22, 7, 44), Color("#111827"))
		w.draw_rect(Rect2(-44, -16, 6, 4), Color("#374151"))
		w.draw_rect(Rect2(-44, 12, 6, 4), Color("#374151"))


## Nitro alevi (oyuncunun adına göre).
func draw_flame(p: Vector2, facing: String, who: String) -> void:
	if float(Tuning.flames.get(who, 0.0)) < Time.get_ticks_msec() / 1000.0:
		return
	var ang: float = FACING.get(facing, 0.0)
	w.draw_set_transform(p, ang, Vector2.ONE)
	var fl := 18.0 + 10.0 * sin(float(w._t) * 40.0)
	for s in [-12.0, 12.0]:
		w.draw_colored_polygon(PackedVector2Array([Vector2(-48, s - 6), Vector2(-48, s + 6), Vector2(-48 - fl * 1.6, s)]), Color("#3b82f6"))
		w.draw_colored_polygon(PackedVector2Array([Vector2(-48, s - 3), Vector2(-48, s + 3), Vector2(-48 - fl, s)]), Color("#e0f2fe"))
	w.draw_set_transform(Vector2.ZERO)


## Evcil hayvan aksesuarları (world._draw_pet'in dönüşümü içinde: yerel koordinat).
func draw_pet_wear(kind: String, wear: Dictionary) -> void:
	var head := Vector2(10, -24) if kind in ["cat", "dog"] else Vector2(6, -26)
	for slot in wear:
		var k := str(wear[slot])
		if not PetShow.ACCESSORIES.has(k):
			continue
		var c := Color(str(PetShow.ACCESSORIES[k].color))
		match k:
			"kurdele":
				w.draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -4), head + Vector2(0, 0), head + Vector2(-6, 4)]), c)
				w.draw_colored_polygon(PackedVector2Array([head + Vector2(6, -4), head + Vector2(0, 0), head + Vector2(6, 4)]), c)
			"parti":
				w.draw_colored_polygon(PackedVector2Array([head + Vector2(-6, 0), head + Vector2(6, 0), head + Vector2(0, -16)]), c)
				w.draw_circle(head + Vector2(0, -16), 2.5, Color("#facc15"))
			"tac":
				w.draw_colored_polygon(PackedVector2Array([head + Vector2(-8, 0), head + Vector2(8, 0), head + Vector2(8, -9), head + Vector2(4, -4),
					head + Vector2(0, -11), head + Vector2(-4, -4), head + Vector2(-8, -9)]), c)
				w.draw_circle(head + Vector2(0, -5), 1.6, Color("#ef4444"))
			"papyon", "fular", "altin":
				var n := head + Vector2(-4, 12)
				if k == "papyon":
					w.draw_colored_polygon(PackedVector2Array([n + Vector2(-6, -4), n, n + Vector2(-6, 4)]), c)
					w.draw_colored_polygon(PackedVector2Array([n + Vector2(6, -4), n, n + Vector2(6, 4)]), c)
				else:
					w.draw_line(n + Vector2(-8, 0), n + Vector2(8, 0), c, 4 if k == "fular" else 3)
					if k == "altin":
						w.draw_circle(n + Vector2(0, 4), 2.5, c)
			"gozluk", "kalp":
				var e := head + Vector2(2, 6)
				if k == "gozluk":
					w.draw_rect(Rect2(e + Vector2(-8, -3), Vector2(7, 5)), c)
					w.draw_rect(Rect2(e + Vector2(1, -3), Vector2(7, 5)), c)
				else:
					w.draw_circle(e + Vector2(-4, 0), 3.5, c)
					w.draw_circle(e + Vector2(4, 0), 3.5, c)
