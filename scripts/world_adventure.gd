extends RefCounted
## 1.8 istemci: mağara zindanı, zombi gecesi, uzay üssü ve Ay, mini golf ve bowling.
## world.gd'nin çizim/bölge/etkileşim kancaları buraya gelir; çizimler world'ün _draw'ı içinde yapılır.

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")
const DungeonPanel = preload("res://scripts/ui/dungeon_panel.gd")
const ShopPanel = preload("res://scripts/ui/combat_shop_panel.gd")
const SpacePanel = preload("res://scripts/ui/space_panel.gd")
const BowlingPanel = preload("res://scripts/ui/bowling_panel.gd")

var w: Node2D                        # world
var ext := ""                        # zindan | ay | uzay | golf | ""
var fx: Array = []                   # {k, p, t0, dmg}
var _drag := false
var _drag_to := Vector2.ZERO
var _mine_acc := 0.0
var _last_zombie := false


func _init(world: Node2D) -> void:
	w = world
	Combat.hit_fx.connect(func(d: Dictionary) -> void:
		fx.append({"k": d.kind, "p": d.p, "t0": w._t, "dmg": d.dmg})
		if d.kind == "hit":
			Sfx.play("pick", -8.0, randf_range(1.3, 1.6))
		elif d.kind == "ouch":
			Sfx.play("splash_small", -8.0, 0.6))
	Zombies.changed.connect(func() -> void:
		if Zombies.active():
			w.hud.show_toast("DOLUNAY! Zombi gecesi başladı — karakol önündeki savunma merkezine koş!", false)
			Sfx.play("bell", -2.0, 0.5)
		else:
			w.hud.show_toast("Gün doğdu, zombiler çekildi.", true))
	Space.trip.connect(_on_rocket)
	Golf.shot.connect(func(_d: Dictionary) -> void: Sfx.play("place", -6.0, 1.6))


static func ext_of(p: Vector2) -> String:
	if Map.DUNGEON.has_point(p):
		return "zindan"
	if Map.MOON.has_point(p):
		return "ay"
	if Map.SPACEPORT.has_point(p):
		return "uzay"
	if Map.GOLF.has_point(p):
		return "golf"
	return ""


func camera_rect() -> Rect2:
	match ext:
		"zindan":
			if not Dungeon.run.is_empty():
				return Dungeon.slot_rect(int(Dungeon.run.slot))
			return Rect2(Map.DUNGEON.position, Vector2(Map.DUNGEON.size.x, Map.DUNGEON_SLOT_H))
		"ay":
			return Map.MOON
		"uzay":
			return Map.SPACEPORT
		"golf":
			return Map.GOLF
	return Map.WORLD


func clamp_pos(p: Vector2) -> Vector2:
	var r := camera_rect().grow(-20)
	return p.clamp(r.position, r.end)


func can_stand(p: Vector2) -> bool:
	var me: Vector2 = w.my_pos
	match ext:
		"zindan":
			return Dungeon.client_free(p) or not Dungeon.client_free(me)
		"uzay":
			return not (_hangar().grow(-6).has_point(p) and not _hangar().grow(-6).has_point(me))
	return true


## Zombi gecesinde barikatlar şehirde yolu keser.
func barricade_at(p: Vector2) -> bool:
	if not Zombies.active():
		return false
	for b in Zombies.state.get("bar", []):
		if Vector2(b[0], b[1]).distance_to(p) < 30.0:
			return true
	return false


static func _hangar() -> Rect2:
	return Rect2(Map.SPACE_SHOP + Vector2(-170, -250), Vector2(340, 210))


# ------------------------------------------------------------------ bölgeler ve ipuçları

func status_line() -> String:
	var parts: Array = []
	if Combat.in_combat():
		var me: Dictionary = Combat.my
		parts.append("❤ %d/%d" % [int(me.hp), int(me.max)])
		parts.append("İksir %d [Q]" % int(me.get("potions", 0)))
		parts.append("Saldırı: tıkla/Boşluk")
	if ext == "ay":
		parts.append("Oksijen %d sn%s" % [int(Space.o2), " — KUBBEYE DÖN!" if Space.o2 < 50.0 else ""])
	if ext == "golf" and Golf.playing():
		var g: Dictionary = Golf.my
		var h := int(g.hole)
		var tot := 0
		for n in g.get("cards", []):
			tot += int(n)
		parts.append("Delik %d/9 · Par %d · Vuruş %d · Toplam %d" % [h + 1, int(Golf.HOLES[h].par), int(g.strokes), tot])
		parts.append("Topu tut, geri çek, bırak")
	return "  ·  ".join(parts)


func decorate(hint: String) -> String:
	var s := status_line()
	if s == "":
		return hint
	return s if hint == "" else hint + "\n" + s


## Kendi bölgelerimde (zindan, Ay, uzay üssü, golf) ipucu ve E alanı.
func update_zone() -> void:
	var me: Vector2 = w.my_pos
	var z := {}
	match ext:
		"zindan":
			var r: Dictionary = Dungeon.run
			if not r.is_empty():
				if me.distance_to(r.exit) < 80.0:
					z = {"type": "adv", "do": "d_leave", "label": "Mağaradan çık (%d. kattasın)" % int(r.floor)}
				elif str(r.state) == "clear":
					if me.distance_to(r.chest) < 80.0 and not bool(r.get("opened", false)):
						z = {"type": "adv", "do": "d_chest", "label": "Hazine sandığını aç"}
					elif me.distance_to(r.stairs) < 90.0:
						z = {"type": "adv", "do": "d_down", "label": "Merdivenden %d. kata in%s" % [int(r.floor) + 1, " (BOSS!)" if (int(r.floor) + 1) % 5 == 0 else ""]}
		"ay":
			if Space.in_dome(me):
				z = {"type": "adv", "do": "s_base", "label": "Ay üssü — bağış, sera, pazar"}
			if me.distance_to(Map.MOON_PAD) < 150.0:
				z = {"type": "adv", "do": "s_launch", "label": "Roketle Dünya'ya dön"}
			var ps := Space.rock_positions()
			for i in mini(ps.size(), Space.rocks.size()):
				if int(Space.rocks[i][2]) > 0 and me.distance_to(ps[i]) < 80.0:
					z = {"type": "adv", "do": "s_mine", "i": i, "label": "Ay taşını kaz (basılı tut)" if bool(Space.my.drill) else "Ay taşı — matkap uzay üssünde"}
			var vs := Space.vent_positions()
			for i in vs.size():
				if me.distance_to(vs[i]) < 80.0:
					z = {"type": "adv", "do": "s_vent", "i": i, "label": "Helyum-3 bacasından topla"}
		"uzay":
			if me.distance_to(Map.SPACE_SHOP) < 150.0:
				z = {"type": "adv", "do": "s_shop", "label": "Roket atölyesi ve uzay pazarı"}
			if me.distance_to(Map.SPACE_PAD) < 150.0:
				z = {"type": "adv", "do": "s_launch", "label": "Roketle Ay'a fırlat (%s yakıt)" % U.money(Space.FUEL_PRICE)}
			if me.distance_to(Map.SPACE_STRIP) < 110.0:
				z = {"type": "terminal", "label": "Uçuşlar (şehre dönüş)"}
		"golf":
			# topun yanındayken E turu yanlışlıkla bitirmesin
			if not Golf.playing() or me.distance_to(Golf.ball_pos(Net.my_name)) > 160.0:
				z = {"type": "adv", "do": "g_leave", "label": "Turu bırak ve gişeye dön" if Golf.playing() else "Gişeye dön"}
	w.zone = z
	w._g_action = g_action()
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	if not w._g_action.is_empty():
		hint += ("\n" if hint != "" else "") + "[%s]  %s" % [Settings.key_name("action"), w._g_action.label]
	w.hud.set_hint("" if w.panel != null else decorate(hint))


## Şehir (zombi gecesi), dağ (mağara) ve fuar (golf, bowling) E alanları.
func extra_zone(z: Dictionary) -> Dictionary:
	var me: Vector2 = w.my_pos
	if w._mount:
		if me.distance_to(Map.DUNGEON_DOOR) < Dungeon.DOOR_R:
			z = {"type": "adv", "do": "d_door", "label": "Mağara Zindanı — sefere çık"}
		if me.distance_to(Map.DUNGEON_SHOP) < 110.0:
			z = {"type": "adv", "do": "c_shop", "label": "Silahçı — silah, zırh, iksir"}
	elif w._fair:
		if (Map.BOWLING.rect as Rect2).grow(30).has_point(me):
			z = {"type": "adv", "do": "b_open", "label": "Bowling Salonu (%s / oyun)" % U.money(Bowling.GAME_PRICE)}
		if me.distance_to(Map.GOLF_BOOTH) < 110.0:
			z = {"type": "adv", "do": "g_enter", "label": "Mini golf — 9 delik (%s)" % U.money(Golf.ENTRY_PRICE)}
	elif Zombies.active() and w._room < 0:
		if me.distance_to(Zombies.defense_pos()) < Zombies.DEFENSE_R:
			z = {"type": "adv", "do": "c_shop", "label": "Savunma merkezi — silah, zırh, iksir"}
		var civ: Array = Zombies.state.get("civ", [])
		for i in civ.size():
			if me.distance_to(Vector2(civ[i][0], civ[i][1])) < 80.0:
				z = {"type": "adv", "do": "z_rescue", "i": i, "label": "Mahsur vatandaşı kurtar (+%s)" % U.money(Zombies.RESCUE_REWARD)}
	return z


func g_action() -> Dictionary:
	var me: Dictionary = Combat.my
	var pots := int(me.get("potions", 0))
	var hurt := float(me.get("hp", 100)) < float(me.get("max", 100))
	if Combat.in_combat() and pots > 0 and float(me.get("hp", 100)) < float(me.get("max", 100)) * 0.5:
		return {"kind": "adv", "do": "c_potion", "label": "Can iksiri iç (%d)" % pots}
	if Zombies.active() and ext == "" and w._room < 0 and not w._fair and not w._mount and Map.WORLD.has_point(w.my_pos):
		return {"kind": "adv", "do": "z_bar", "label": "Önüne barikat kur (%s)" % U.money(Zombies.BARRICADE_PRICE)}
	if Combat.in_combat() and pots > 0 and hurt:
		return {"kind": "adv", "do": "c_potion", "label": "Can iksiri iç (%d)" % pots}
	return {}


func do_g(a: Dictionary) -> void:
	_do(a)


## E: true dönerse world başka bir şey yapmaz.
func open(z: Dictionary) -> bool:
	if str(z.get("type", "")) != "adv":
		return false
	_do(z)
	return true


func _do(z: Dictionary) -> void:
	match str(z.get("do", "")):
		"d_door":
			_panel(DungeonPanel.new())
		"c_shop":
			_panel(ShopPanel.new())
		"d_leave":
			Dungeon.leave()
		"d_chest":
			Dungeon.open_chest()
			Sfx.play("cash")
		"d_down":
			Dungeon.descend()
			Sfx.play("door", -4.0, 0.7)
		"c_potion":
			Combat.drink()
			Sfx.play("splash_small", -6.0, 1.8)
		"z_bar":
			var dir: Vector2 = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}.get(w.my_facing, Vector2.DOWN)
			Zombies.barricade(w.my_pos + dir * 50.0)
			Sfx.play("place", -4.0, 0.8)
		"z_rescue":
			Zombies.rescue(int(z.i))
			Sfx.play("success")
		"s_shop":
			var p := SpacePanel.new()
			p.mode = "shop"
			_panel(p)
		"s_base":
			var p2 := SpacePanel.new()
			p2.mode = "base"
			_panel(p2)
		"s_launch":
			Space.launch()
		"s_mine":
			Space.mine(int(z.i))
			Sfx.play("pick", -5.0, randf_range(0.7, 0.8))
		"s_vent":
			Space.vent(int(z.i))
			Sfx.play("splash_small", -6.0, 0.5)
		"g_enter":
			Golf.enter()
		"g_leave":
			Golf.leave()
		"b_open":
			_panel(BowlingPanel.new())


func _panel(p: Control) -> void:
	if w.panel != null:
		return
	w.panel = p
	p.closed.connect(w._close_panel)
	w.ui_layer.add_child(p)
	Sfx.play("open", -4.0)


func tick(delta: float) -> void:
	# Ay taşı: E basılı tutulunca kazılır
	if w.panel == null and str(w.zone.get("do", "")) == "s_mine" and bool(Space.my.drill) and Settings.held("interact"):
		_mine_acc += delta
		if _mine_acc >= 0.45:
			_mine_acc = 0.0
			_do(w.zone)
	var now: float = w._t
	for i in range(fx.size() - 1, -1, -1):
		if now - float(fx[i].t0) > 0.9:
			fx.remove_at(i)
	var t := Time.get_ticks_msec() / 1000.0
	for i in range(Combat.arrows.size() - 1, -1, -1):
		if t - float(Combat.arrows[i].t0) > 0.8:
			Combat.arrows.remove_at(i)


# ------------------------------------------------------------------ girdi

func _aim_dir() -> Vector2:
	var d: Vector2 = w.get_global_mouse_position() - (w.my_pos + Vector2(0, -16))
	if d.length() < 8.0:
		d = {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}.get(w.my_facing, Vector2.DOWN)
	return d


func _attack(d: Vector2) -> void:
	Combat.attack(d)
	var wk := str(Combat.my.get("cur", "yumruk"))
	fx.append({"k": "my_swing", "p": w.my_pos + Vector2(0, -16), "t0": w._t, "dmg": 0, "dir": d.normalized(), "ranged": bool(Combat.WEAPONS.get(wk, {}).get("ranged", false))})
	Sfx.play("splash_small", -12.0, 2.4)


func input(event: InputEvent) -> bool:
	if w.panel != null:
		_drag = false
		return false
	var touch_on: bool = w.touch.visible
	# mini golf: topu sürükleyip bırak (dokunmatikte de fare olayı gelir)
	if ext == "golf" and Golf.playing():
		var ball := Golf.ball_pos(Net.my_name)
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var mp: Vector2 = w.get_global_mouse_position()
			if event.pressed and mp.distance_to(ball) < 60.0 and w.my_pos.distance_to(ball) < 120.0 and not Golf.flying.has(Net.my_name):
				_drag = true
				_drag_to = mp
				return true
			if not event.pressed and _drag:
				_drag = false
				var pull := ball - mp
				if pull.length() > 12.0:
					Golf.hit(pull.limit_length(180.0) / 180.0 * Golf.MAX_SPEED)
				return true
		if event is InputEventMouseMotion and _drag:
			_drag_to = w.get_global_mouse_position()
			return true
	if Combat.in_combat():
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not touch_on:
			_attack(_aim_dir())
			return true
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_SPACE:
				_attack(_aim_dir() if not touch_on else {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}.get(w.my_facing, Vector2.DOWN))
				return true
			if event.physical_keycode == KEY_Q:
				Combat.drink()
				Sfx.play("splash_small", -6.0, 1.8)
				return true
	return false


## Dokunmatik: düğme dışına dokunma savaşta o yöne saldırır.
func touch_tap(wp: Vector2) -> bool:
	if not Combat.in_combat() or (ext == "golf"):
		return false
	_attack(wp - (w.my_pos + Vector2(0, -16)))
	return true


# ------------------------------------------------------------------ roket yolculuğu

func _on_rocket(d: Dictionary) -> void:
	if w.panel != null:
		w._close_panel()
	var layer := CanvasLayer.new()
	layer.layer = 6
	w.add_child(layer)
	var art := RocketArt.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.to = str(d.get("to", "ay"))
	layer.add_child(art)
	Sfx.play("engine", -2.0, 0.6)
	var tw := w.create_tween()
	tw.tween_interval(float(d.get("time", 6.0)))
	tw.tween_property(art, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


class RocketArt extends Control:
	var to := "ay"
	var t0 := Time.get_ticks_msec() / 1000.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() / 1000.0 - t0
		var sw := size.x
		var sh := size.y
		var up := clampf(t / 2.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7dd3fc").lerp(Color("#020617"), up))
		for k in 90:
			var sx := fmod(k * 137.5, sw)
			var sy := fmod(k * 71.3 + t * (60.0 + k % 5 * 40.0), sh)
			draw_circle(Vector2(sx, sy), 1.0 + k % 3 * 0.6, Color(1, 1, 1, up * (0.4 + 0.5 * sin(k + t * 3.0))))
		# hedef gezegen büyüyerek yaklaşır
		var grow := clampf((t - 2.5) / 3.5, 0.0, 1.0)
		var pc := Vector2(sw * 0.5, -sh * 0.2 + grow * sh * 0.35)
		var pr := 40.0 + grow * sh * 0.45
		if to == "ay":
			draw_circle(pc, pr, Color("#d1d5db"))
			for k in 7:
				draw_circle(pc + Vector2(cos(k * 2.1), sin(k * 1.7)) * pr * 0.55, pr * (0.08 + k % 3 * 0.04), Color("#9ca3af"))
		else:
			draw_circle(pc, pr, Color("#2563eb"))
			for k in 5:
				draw_circle(pc + Vector2(cos(k * 1.9), sin(k * 2.3)) * pr * 0.5, pr * 0.22, Color("#16a34a"))
			draw_arc(pc, pr, 0, TAU, 64, Color(0.6, 0.85, 1.0, 0.6), 6)
		# roket
		var rc := Vector2(sw * 0.5 + sin(t * 9.0) * 2.0, sh * 0.62)
		var flame := 30.0 + 14.0 * sin(t * 30.0)
		draw_colored_polygon(PackedVector2Array([rc + Vector2(-16, 60), rc + Vector2(16, 60), rc + Vector2(0, 60 + flame * 2.0)]), Color("#f97316"))
		draw_colored_polygon(PackedVector2Array([rc + Vector2(-9, 60), rc + Vector2(9, 60), rc + Vector2(0, 60 + flame * 1.2)]), Color("#fde047"))
		draw_rect(Rect2(rc + Vector2(-22, -50), Vector2(44, 110)), Color("#f8fafc"))
		draw_colored_polygon(PackedVector2Array([rc + Vector2(-22, -50), rc + Vector2(22, -50), rc + Vector2(0, -105)]), Color("#dc2626"))
		draw_colored_polygon(PackedVector2Array([rc + Vector2(-22, 20), rc + Vector2(-46, 64), rc + Vector2(-22, 60)]), Color("#dc2626"))
		draw_colored_polygon(PackedVector2Array([rc + Vector2(22, 20), rc + Vector2(46, 64), rc + Vector2(22, 60)]), Color("#dc2626"))
		draw_circle(rc + Vector2(0, -16), 11, Color("#38bdf8"))
		draw_arc(rc + Vector2(0, -16), 11, 0, TAU, 24, Color("#475569"), 3)
		var msg := "Ay'a yolculuk..." if to == "ay" else "Dünya'ya dönüş..."
		draw_string(ThemeDB.fallback_font, Vector2(0, sh - 60), msg, HORIZONTAL_ALIGNMENT_CENTER, sw, 30, Color("#fde68a"))


# ------------------------------------------------------------------ çizim: ortak

func _players(items: Array) -> void:
	var hop := ext == "ay"
	for id in w.shown:
		var info = Net.roster.get(id)
		if info and str(info.get("ride", "")) != "train":
			var a: Dictionary = w.anim.get(id, {"facing": "down", "moving": false})
			var p: Vector2 = w.shown[id]
			items.append([p.y, "p", [p + _hop(hop and bool(a.moving), int(id)), info.get("appearance", {}), w._name_of(info), false, a.facing, a.moving, str(info.get("ride", "")), info.get("color", Color.WHITE), info]])
	var mine = Net.roster.get(Net.my_id())
	if w.my_ride() != "train":
		var my_app = mine.get("appearance", {}) if mine else Net.my_appearance
		var my_col: Color = mine.get("color", Color.WHITE) if mine else Color.WHITE
		var mp: Vector2 = w.my_pos
		items.append([mp.y, "p", [mp + _hop(hop and bool(w.my_moving), 0), my_app, w._name_of(mine) if mine else Net.my_name, true, w.my_facing, w.my_moving, w.my_ride(), my_col, mine if mine else {}]])


func _hop(on: bool, seed_v: int) -> Vector2:
	if not on:
		return Vector2.ZERO
	return Vector2(0, -absf(sin(float(w._t) * 3.2 + seed_v)) * 22.0)


func _flush(items: Array) -> void:
	items.sort_custom(func(a, b): return a[0] < b[0])
	for it in items:
		match str(it[1]):
			"p":
				var a: Array = it[2]
				w._draw_player(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8])
				if ext == "ay" and not Space.in_dome(a[0]):
					_draw_helmet(a[0])
			"m":
				_draw_monster(it[2])
			"pillar":
				_draw_pillar(it[2])
			"bar":
				_draw_barricade(it[2])
			"civ":
				_draw_civilian(it[2])
			"rocket":
				_draw_rocket(it[2], 1.0)
			"rock":
				_draw_moon_rock(it[2][0], int(it[2][1]))
			"module":
				_draw_module(it[2][0], str(it[2][1]), bool(it[2][2]))
			"windmill":
				_draw_windmill(it[2][0], it[2][1])
			"defense":
				_draw_defense(it[2])
			"hangar":
				_draw_hangar()


func _monster_items(items: Array, wrap: bool = false) -> void:
	for mid in Combat.monsters:
		var m: Array = Combat.monsters[mid]
		items.append([float(m[2]), "adv", ["m", m]] if wrap else [float(m[2]), "m", m])


func _draw_fx() -> void:
	var now: float = w._t
	for f in fx:
		var u := clampf((now - float(f.t0)) / 0.9, 0.0, 1.0)
		var p: Vector2 = f.p
		match str(f.k):
			"hit":
				w._text(p + Vector2(-30, -u * 40.0), str(f.dmg), 20, Color(1, 0.9, 0.3, 1.0 - u), 60)
				w.draw_circle(p, 6.0 + u * 18.0, Color(1, 1, 1, 0.35 * (1.0 - u)))
			"ouch":
				w._text(p + Vector2(-30, -u * 40.0), str(f.dmg), 18, Color(1, 0.35, 0.35, 1.0 - u), 60)
			"swing":
				w.draw_arc(p, 26.0, 0, TAU, 20, Color(1, 1, 1, 0.3 * (1.0 - u)), 3)
			"my_swing":
				if not bool(f.get("ranged", false)) and u < 0.35:
					var dir: Vector2 = f.dir
					var a := dir.angle()
					w.draw_arc(p, 48.0, a - 0.9, a + 0.9, 14, Color(1, 1, 1, 0.8 * (1.0 - u / 0.35)), 5)
	var t := Time.get_ticks_msec() / 1000.0
	for ar in Combat.arrows:
		var ap: Vector2 = ar.p + ar.v * (t - float(ar.t0))
		var dir: Vector2 = (ar.v as Vector2).normalized()
		w.draw_line(ap - dir * 22.0, ap, Color("#78350f"), 3)
		w.draw_colored_polygon(PackedVector2Array([ap + dir * 8.0, ap + dir.orthogonal() * 4.0, ap - dir.orthogonal() * 4.0]), Color("#d6d3d1"))
	# savaşta kendi can çubuğum
	if Combat.in_combat():
		var me: Dictionary = Combat.my
		var hp := clampf(float(me.hp) / maxf(1.0, float(me.max)), 0.0, 1.0)
		var bp: Vector2 = w.my_pos + Vector2(-26, -92)
		w.draw_rect(Rect2(bp, Vector2(52, 7)), Color(0, 0, 0, 0.6))
		w.draw_rect(Rect2(bp + Vector2(1, 1), Vector2(50 * hp, 5)), Color("#22c55e") if hp > 0.35 else Color("#ef4444"))


# ------------------------------------------------------------------ çizim: kendi bölgelerim

func draw_region() -> void:
	var view: Rect2 = w._view_rect().grow(120)
	var items: Array = []
	match ext:
		"zindan":
			_draw_dungeon(view, items)
		"ay":
			_draw_moon(view, items)
		"uzay":
			_draw_spaceport(view, items)
		"golf":
			_draw_golf(view, items)
	_monster_items(items)
	_players(items)
	_flush(items)
	if ext == "ay":
		_draw_glass_dome()
	if ext == "golf":
		_draw_golf_balls()
	_draw_fx()
	w._draw_nav()


func _hash(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663))


func _draw_dungeon(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#0c0a09"))
	var r: Dictionary = Dungeon.run
	if r.is_empty():
		return
	var slot := int(r.slot)
	var a := Dungeon.arena(slot)
	w.draw_rect(a, Color("#3b332d"))
	var g := 80
	for gx in range(int(maxf(a.position.x, view.position.x) / g) * g, int(minf(a.end.x, view.end.x)), g):
		for gy in range(int(maxf(a.position.y, view.position.y) / g) * g, int(minf(a.end.y, view.end.y)), g):
			var h := _hash(gx, gy)
			var cell := Rect2(gx, gy, g, g).intersection(a)
			if cell.size.x <= 0 or cell.size.y <= 0:
				continue
			if h % 4 == 0:
				w.draw_rect(cell.grow(-3), Color(0.27, 0.23, 0.2, 0.6))
			if h % 7 == 0:
				var pp := Vector2(gx + h % 60 + 10, gy + h % 50 + 15)
				w.draw_circle(pp, 4 + h % 5, Color("#57534e"))
			if h % 11 == 0:
				var bp := Vector2(gx + h % 70, gy + h % 40 + 20)
				w.draw_line(bp, bp + Vector2(14, 4), Color("#d6d3d1", 0.5), 3)       # kemik
				w.draw_circle(bp, 3, Color("#d6d3d1", 0.5))
	# duvarlar: arenanın dışı kaba kaya
	var wall := Color("#1c1917")
	var sr := Dungeon.slot_rect(slot)
	w.draw_rect(Rect2(sr.position.x, sr.position.y, sr.size.x, a.position.y - sr.position.y), wall)
	w.draw_rect(Rect2(sr.position.x, a.end.y, sr.size.x, sr.end.y - a.end.y), wall)
	w.draw_rect(Rect2(sr.position.x, a.position.y, a.position.x - sr.position.x, a.size.y), wall)
	w.draw_rect(Rect2(a.end.x, a.position.y, sr.end.x - a.end.x, a.size.y), wall)
	for k in int(a.size.x / 60.0):
		var x := a.position.x + k * 60.0 + 30.0
		var hh := 18.0 + float(_hash(k, slot) % 26)
		w.draw_colored_polygon(PackedVector2Array([Vector2(x - 16, a.position.y), Vector2(x + 16, a.position.y), Vector2(x, a.position.y + hh)]), Color("#292524"))
		w.draw_colored_polygon(PackedVector2Array([Vector2(x - 14, a.end.y), Vector2(x + 14, a.end.y), Vector2(x + 2, a.end.y - hh * 0.7)]), Color("#292524"))
	# meşaleler
	var dk := 1.0
	for k in int(a.size.x / 320.0) + 1:
		var tp := Vector2(a.position.x + 100 + k * 320.0, a.position.y + 4)
		var fl := 0.8 + 0.2 * sin(float(w._t) * 9.0 + k * 1.7)
		w.draw_circle(tp + Vector2(0, 20), 120.0 * fl, Color(1.0, 0.6, 0.2, 0.07 * dk))
		w.draw_rect(Rect2(tp.x - 3, tp.y, 6, 22), Color("#78350f"))
		w.draw_circle(tp + Vector2(0, -2), 7 * fl, Color("#f97316"))
		w.draw_circle(tp + Vector2(0, -4), 4 * fl, Color("#fde047"))
	# çıkış kapısı (mavi ışık)
	var ex: Vector2 = r.exit
	for k in 3:
		w.draw_arc(ex + Vector2(0, -26), 30.0 + k * 8.0 + sin(float(w._t) * 3.0) * 3.0, 0, TAU, 32, Color(0.4, 0.75, 1.0, 0.5 - k * 0.14), 4)
	w.draw_circle(ex + Vector2(0, -26), 22, Color(0.5, 0.8, 1.0, 0.45))
	w._text(ex + Vector2(-80, -86), "ÇIKIŞ", 16, Color("#bae6fd"), 160)
	if str(r.state) == "clear":
		var st: Vector2 = r.stairs
		for k in 5:
			w.draw_rect(Rect2(st.x - 46 + k * 4, st.y - 40 + k * 12, 92 - k * 8, 12), Color(0.45 - k * 0.08, 0.4 - k * 0.07, 0.35 - k * 0.06))
		w.draw_rect(Rect2(st.x - 30, st.y + 20, 60, 16), Color.BLACK)
		w._text(st + Vector2(-90, -76), "MERDİVEN ↓", 16, Color("#fde68a"), 180)
		if not bool(r.get("opened", false)):
			w._draw_ocean_chest(r.chest, true)
	for q in r.pillars:
		items.append([(q as Rect2).end.y, "pillar", q])
	w._text(a.position + Vector2(0, 20), "%d. KAT%s" % [int(r.floor), "  ·  KAT TEMİZ!" if str(r.state) == "clear" else ""], 26, Color("#fde68a") if str(r.state) == "clear" else Color("#fca5a5"), a.size.x)


func _draw_pillar(q: Rect2) -> void:
	w.draw_rect(Rect2(q.position + Vector2(8, 10), q.size), Color(0, 0, 0, 0.35))
	w.draw_rect(q, Color("#57534e"))
	w.draw_rect(Rect2(q.position, Vector2(q.size.x, q.size.y * 0.35)), Color("#78716c"))
	w.draw_line(q.position + Vector2(q.size.x * 0.3, q.size.y * 0.4), q.position + Vector2(q.size.x * 0.45, q.size.y * 0.8), Color("#44403c"), 2)
	w.draw_line(q.position + Vector2(q.size.x * 0.7, q.size.y * 0.5), q.position + Vector2(q.size.x * 0.6, q.size.y * 0.95), Color("#44403c"), 2)
	w.draw_rect(q, Color("#292524"), false, 2)


func _draw_monster(m: Array) -> void:
	var kind := str(m[0])
	var p := Vector2(float(m[1]), float(m[2]))
	var hp := float(m[3]) / maxf(1.0, float(m[4]))
	var f := float(m[5]) if m.size() > 5 else 1.0
	var cfg: Dictionary = Combat.MONSTERS.get(kind, Combat.MONSTERS.slime)
	var r := float(cfg.r)
	var col := Color(str(cfg.col))
	var t: float = w._t + float(int(p.x) % 7)
	w.draw_set_transform(p + Vector2(0, 2), 0, Vector2(1, 0.4))
	w.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	w.draw_set_transform(Vector2.ZERO)
	match kind:
		"slime":
			var sq := 1.0 + 0.12 * sin(t * 6.0)
			w.draw_set_transform(p + Vector2(0, -r * 0.6), 0, Vector2(sq, 1.0 / sq))
			w.draw_circle(Vector2.ZERO, r, col)
			w.draw_circle(Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.4))
			w.draw_set_transform(Vector2.ZERO)
			_eyes(p + Vector2(0, -r * 0.7), 5.0, f, Color.BLACK)
		"bat":
			var by := p + Vector2(0, -34 + sin(t * 4.0) * 6.0)
			var flap := sin(t * 18.0) * 10.0
			for s in [-1.0, 1.0]:
				w.draw_colored_polygon(PackedVector2Array([by, by + Vector2(s * 26, -10 - flap), by + Vector2(s * 18, 6), by + Vector2(s * 8, 2)]), col)
			w.draw_circle(by, 9, col.darkened(0.3))
			_eyes(by + Vector2(0, -2), 3.0, f, Color("#f87171"))
		"spider":
			for s in [-1.0, 1.0]:
				for k in 4:
					var la := (k - 1.5) * 0.45 + sin(t * 10.0 + k) * 0.15
					var kn := p + Vector2(s * 14, -10) + Vector2(s * cos(la), sin(la)) * 14.0
					w.draw_line(p + Vector2(s * 6, -10), kn, col, 3)
					w.draw_line(kn, kn + Vector2(s * 8, 12), col, 2.5)
			w.draw_circle(p + Vector2(0, -12), r * 0.75, col)
			w.draw_circle(p + Vector2(f * 9, -16), 7, col.lightened(0.15))
			_eyes(p + Vector2(f * 11, -18), 2.5, f, Color("#ef4444"))
		"skeleton":
			var wob := sin(t * 8.0) * 2.0
			w.draw_line(p + Vector2(-6, 0), p + Vector2(-4, -18), col, 4)
			w.draw_line(p + Vector2(6, 0), p + Vector2(4, -18), col, 4)
			w.draw_rect(Rect2(p.x - 9, p.y - 38, 18, 20), Color(0, 0, 0, 0))
			for k in 4:
				w.draw_line(p + Vector2(-9, -22 - k * 5), p + Vector2(9, -22 - k * 5), col, 2.5)
			w.draw_line(p + Vector2(0, -18), p + Vector2(0, -42), col, 3)
			w.draw_line(p + Vector2(-10, -38), p + Vector2(-18 + wob, -24), col, 3)
			w.draw_line(p + Vector2(10, -38), p + Vector2(18 * f, -30 + wob), col, 3)
			w.draw_line(p + Vector2(18 * f, -30 + wob), p + Vector2(30 * f, -46 + wob), Color("#a8a29e"), 3)     # kemik kılıç
			w.draw_circle(p + Vector2(0, -52), 11, col)
			w.draw_circle(p + Vector2(-4 + f * 2, -54), 3, Color.BLACK)
			w.draw_circle(p + Vector2(4 + f * 2, -54), 3, Color.BLACK)
		"golem":
			var bob := sin(t * 2.0) * 2.0
			var c := p + Vector2(0, -r - bob)
			w.draw_circle(c + Vector2(-r * 0.95, r * 0.2), r * 0.4, col.darkened(0.2))
			w.draw_circle(c + Vector2(r * 0.95, r * 0.2), r * 0.4, col.darkened(0.2))
			w.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.8), Vector2(r * 1.5, r * 1.6)), col)
			w.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 1.3), Vector2(r * 0.9, r * 0.6)), col.lightened(0.1))
			w.draw_line(c + Vector2(-r * 0.4, -r * 0.2), c + Vector2(r * 0.1, r * 0.5), Color("#44403c"), 3)
			w.draw_circle(c + Vector2(-r * 0.2, -r * 1.05), 5, Color("#fb923c"))
			w.draw_circle(c + Vector2(r * 0.2, -r * 1.05), 5, Color("#fb923c"))
			w.draw_circle(c + Vector2(0, -r * 0.1), 9, Color(1.0, 0.5, 0.1, 0.5 + 0.4 * sin(t * 4.0)))
		"dragon":
			var c2 := p + Vector2(0, -r * 0.9)
			var flap2 := sin(t * 5.0) * 16.0
			for s in [-1.0, 1.0]:
				w.draw_colored_polygon(PackedVector2Array([c2 + Vector2(s * 10, -10), c2 + Vector2(s * r * 2.0, -r * 0.9 - flap2), c2 + Vector2(s * r * 1.6, r * 0.1), c2 + Vector2(s * r * 0.9, r * 0.3)]), col.darkened(0.35))
			w.draw_line(c2 + Vector2(-f * r * 0.6, r * 0.3), c2 + Vector2(-f * r * 1.6, r * 0.8 + sin(t * 3.0) * 8.0), col, 10)
			w.draw_set_transform(c2, 0, Vector2(1.25, 0.9))
			w.draw_circle(Vector2.ZERO, r * 0.7, col)
			w.draw_set_transform(Vector2.ZERO)
			var head := c2 + Vector2(f * r * 0.9, -r * 0.55)
			w.draw_circle(head, r * 0.38, col)
			w.draw_colored_polygon(PackedVector2Array([head + Vector2(-8, -14), head + Vector2(-4, -30), head + Vector2(2, -14)]), Color("#fde68a"))
			w.draw_colored_polygon(PackedVector2Array([head + Vector2(6, -14), head + Vector2(12, -28), head + Vector2(14, -10)]), Color("#fde68a"))
			w.draw_circle(head + Vector2(f * 6, -4), 4, Color("#facc15"))
			if fmod(t, 3.0) < 0.6:
				for k in 5:
					w.draw_circle(head + Vector2(f * (24 + k * 14), 6 + sin(t * 20 + k) * 4), 8 - k, Color(1.0, 0.5 - k * 0.08, 0.1, 0.8))
		"zombie", "brute":
			var s2 := 1.0 if kind == "zombie" else 1.45
			var lurch := sin(t * 4.0) * 3.0
			var skin := col
			var shirt := Color("#57534e") if kind == "zombie" else Color("#7f1d1d")
			w.draw_line(p + Vector2(-5 * s2, 0), p + Vector2(-5 * s2, -16 * s2 + lurch), Color("#292524"), 6 * s2)
			w.draw_line(p + Vector2(5 * s2, 0), p + Vector2(5 * s2, -16 * s2 - lurch), Color("#292524"), 6 * s2)
			w.draw_rect(Rect2(p + Vector2(-10, -40) * s2, Vector2(20, 26) * s2), shirt)
			w.draw_line(p + Vector2(-8, -36) * s2, p + Vector2(f * 26 - 8, -34 + lurch) * s2, skin, 5 * s2)
			w.draw_line(p + Vector2(8, -36) * s2, p + Vector2(f * 26 + 8, -32 - lurch) * s2, skin, 5 * s2)
			w.draw_circle(p + Vector2(f * 2, -50) * s2, 11 * s2, skin)
			w.draw_circle(p + Vector2(f * 6 - 3, -52) * s2, 2.2 * s2, Color("#fef08a"))
			w.draw_circle(p + Vector2(f * 6 + 3, -52) * s2, 2.2 * s2, Color("#fef08a"))
			w.draw_line(p + Vector2(f * 2 - 4, -44) * s2, p + Vector2(f * 2 + 5, -45) * s2, Color("#1c1917"), 2)
	# can çubuğu
	var top := p + Vector2(-r - 6, -r * 2.0 - 34)
	if bool(cfg.get("boss", false)):
		top = p + Vector2(-60, -r * 2.4 - 40)
		w.draw_rect(Rect2(top, Vector2(120, 10)), Color(0, 0, 0, 0.7))
		w.draw_rect(Rect2(top + Vector2(1, 1), Vector2(118 * hp, 8)), Color("#dc2626"))
		w._text(top + Vector2(-40, -20), str(cfg.name).to_upper(), 16, Color("#fca5a5"), 200)
	elif hp < 1.0:
		w.draw_rect(Rect2(top, Vector2(r * 2 + 12, 5)), Color(0, 0, 0, 0.6))
		w.draw_rect(Rect2(top, Vector2((r * 2 + 12) * hp, 5)), Color("#ef4444"))


func _eyes(c: Vector2, r: float, f: float, col: Color) -> void:
	w.draw_circle(c + Vector2(-r * 1.3 + f * r * 0.4, 0), r, Color.WHITE if col == Color.BLACK else col)
	w.draw_circle(c + Vector2(r * 1.3 + f * r * 0.4, 0), r, Color.WHITE if col == Color.BLACK else col)
	if col == Color.BLACK:
		w.draw_circle(c + Vector2(-r * 1.3 + f * r * 0.8, 0), r * 0.5, col)
		w.draw_circle(c + Vector2(r * 1.3 + f * r * 0.8, 0), r * 0.5, col)


func _draw_moon(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#020617"))
	for k in 60:
		var sp := view.position + Vector2(fmod(k * 211.7, view.size.x), fmod(k * 97.3, view.size.y))
		w.draw_circle(sp, 1.4, Color(1, 1, 1, 0.6))
	var m: Rect2 = Map.MOON
	w.draw_rect(m, Color("#a1a1aa"))
	var g := 90
	for gx in range(int(maxf(m.position.x, view.position.x) / g) * g, int(minf(m.end.x, view.end.x)), g):
		for gy in range(int(maxf(m.position.y, view.position.y) / g) * g, int(minf(m.end.y, view.end.y)), g):
			var h := _hash(gx, gy)
			if h % 3 == 0:
				w.draw_circle(Vector2(gx + h % 80, gy + h % 70), 3 + h % 4, Color("#8b8b93"))
			if h % 5 == 0:
				w.draw_circle(Vector2(gx + h % 50, gy + h % 90), 2, Color("#d4d4d8"))
	for c in Space.craters():
		var cp: Vector2 = c[0]
		var cr: float = c[1]
		if not view.grow(cr).has_point(cp):
			continue
		w.draw_set_transform(cp, 0, Vector2(1, 0.7))
		w.draw_circle(Vector2.ZERO, cr, Color("#71717a"))
		w.draw_circle(Vector2(cr * 0.08, cr * 0.1), cr * 0.85, Color("#8b8b93"))
		w.draw_arc(Vector2.ZERO, cr, PI * 0.9, PI * 1.9, 24, Color("#d4d4d8"), 4)
		w.draw_set_transform(Vector2.ZERO)
	# Dünya gökte (Ay ufkunda, sahanın üst kenarında)
	var ep := m.position + Vector2(m.size.x * 0.7, 120)
	if view.has_point(ep):
		w.draw_circle(ep, 70, Color("#1d4ed8"))
		w.draw_circle(ep + Vector2(-20, -10), 26, Color("#16a34a"))
		w.draw_circle(ep + Vector2(24, 18), 18, Color("#15803d"))
		w.draw_arc(ep, 70, 0, TAU, 48, Color(0.6, 0.85, 1.0, 0.6), 5)
		w._text(ep + Vector2(-80, 80), "DÜNYA", 14, Color("#bfdbfe"), 160)
	# Helyum bacaları
	for v in Space.vent_positions():
		w.draw_set_transform(v, 0, Vector2(1, 0.6))
		w.draw_circle(Vector2.ZERO, 30, Color("#3f3f46"))
		w.draw_circle(Vector2.ZERO, 16, Color("#18181b"))
		w.draw_set_transform(Vector2.ZERO)
		for k in 4:
			var u := fmod(float(w._t) * 0.5 + k * 0.25, 1.0)
			w.draw_circle(v + Vector2(sin(k * 2.0 + float(w._t)) * 8.0, -u * 70.0), 6 + u * 10, Color(0.75, 0.95, 0.5, 0.35 * (1.0 - u)))
	# üs kubbesi
	var b: Rect2 = Map.MOON_BASE
	var bc := b.get_center()
	w.draw_set_transform(bc, 0, Vector2(1, b.size.y / b.size.x))
	w.draw_circle(Vector2.ZERO, b.size.x / 2.0 + 10, Color("#52525b"))
	w.draw_circle(Vector2.ZERO, b.size.x / 2.0, Color("#e2e8f0"))
	w.draw_set_transform(Vector2.ZERO)
	for k in 5:
		w.draw_line(bc + Vector2(-b.size.x / 2.0 + 30, -80 + k * 40), bc + Vector2(b.size.x / 2.0 - 30, -80 + k * 40), Color("#cbd5e1"), 2)
	w._text(bc + Vector2(-150, -b.size.y / 2.0 - 30), "AY ÜSSÜ (oksijen dolar)", 18, Color("#bae6fd"), 300)
	for k in Space.MODULES:
		items.append([bc.y + float(Space.MODULE_POS[k].y) + 30.0, "module", [bc + Space.MODULE_POS[k], k, Space.module_done(Space.base, k)]])
	# iniş rampası
	_draw_pad(Map.MOON_PAD)
	items.append([Map.MOON_PAD.y + 10.0, "rocket", Map.MOON_PAD + Vector2(90, 0)])
	var ps := Space.rock_positions()
	for i in mini(ps.size(), Space.rocks.size()):
		items.append([ps[i].y, "rock", [ps[i], int(Space.rocks[i][2])]])


func _draw_glass_dome() -> void:
	var b: Rect2 = Map.MOON_BASE
	w.draw_set_transform(b.get_center(), 0, Vector2(1, b.size.y / b.size.x))
	w.draw_circle(Vector2.ZERO, b.size.x / 2.0, Color(0.6, 0.85, 1.0, 0.13))
	w.draw_arc(Vector2.ZERO, b.size.x / 2.0, 0, TAU, 64, Color(0.8, 0.95, 1.0, 0.7), 4)
	w.draw_arc(Vector2.ZERO, b.size.x / 2.0 - 30, PI * 1.1, PI * 1.5, 20, Color(1, 1, 1, 0.5), 6)
	w.draw_set_transform(Vector2.ZERO)


func _draw_helmet(p: Vector2) -> void:
	w.draw_circle(p + Vector2(0, -56), 19, Color(0.75, 0.9, 1.0, 0.28))
	w.draw_arc(p + Vector2(0, -56), 19, 0, TAU, 28, Color(0.9, 0.97, 1.0, 0.8), 2.5)
	w.draw_arc(p + Vector2(0, -56), 14, PI * 1.15, PI * 1.45, 8, Color(1, 1, 1, 0.8), 2.5)


func _draw_moon_rock(p: Vector2, hp: int) -> void:
	if hp <= 0:
		for k in 4:
			w.draw_circle(p + Vector2(-14 + k * 9, 4 - k % 2 * 4), 4, Color("#71717a"))
		return
	var s := 0.7 + 0.1 * hp
	w.draw_set_transform(p + Vector2(4, 4), 0, Vector2(1, 0.45))
	w.draw_circle(Vector2.ZERO, 30 * s, Color(0, 0, 0, 0.3))
	w.draw_set_transform(Vector2.ZERO)
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-30, 0) * s, p + Vector2(-22, -26) * s, p + Vector2(4, -36) * s, p + Vector2(28, -18) * s, p + Vector2(30, 0) * s]), Color("#6b7280"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-22, -26) * s, p + Vector2(4, -36) * s, p + Vector2(10, -20) * s, p + Vector2(-12, -14) * s]), Color("#9ca3af"))
	for k in 3:
		var cp := p + Vector2(-12 + k * 12, -14 - k % 2 * 8) * s
		w.draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -9), cp + Vector2(4, 0), cp + Vector2(0, 5), cp + Vector2(-4, 0)]), Color("#c084fc"))
	w.draw_circle(p + Vector2(8, -28) * s, 2.5 * (0.5 + 0.5 * sin(float(w._t) * 4.0 + p.x)), Color.WHITE)


func _draw_module(p: Vector2, k: String, done: bool) -> void:
	if not done:
		w.draw_rect(Rect2(p + Vector2(-40, -40), Vector2(80, 60)), Color(1, 1, 1, 0.08))
		for i in 8:
			var a := Vector2(-40 + i * 10, -40)
			w.draw_line(a, a + Vector2(5, 0), Color("#facc15"), 2)
		w.draw_rect(Rect2(p + Vector2(-40, -40), Vector2(80, 60)), Color("#facc15", 0.6), false, 2)
		w._text(p + Vector2(-70, -64), "%s (yapılıyor)" % Space.MODULES[k].name, 13, Color("#fde68a"), 140)
		return
	match k:
		"bayrak":
			w.draw_line(p, p + Vector2(0, -80), Color("#d4d4d8"), 4)
			var wave := sin(float(w._t) * 2.0) * 3.0
			w.draw_colored_polygon(PackedVector2Array([p + Vector2(2, -80), p + Vector2(56, -76 + wave), p + Vector2(56, -46 + wave), p + Vector2(2, -50)]), Color("#2563eb"))
			w._text(p + Vector2(-10, -82), "MyCity", 13, Color.WHITE, 80)
		"sera":
			w.draw_rect(Rect2(p + Vector2(-56, -50), Vector2(112, 60)), Color(0.55, 0.9, 0.6, 0.35))
			for i in 5:
				w.draw_circle(p + Vector2(-44 + i * 22, -10), 8, Color("#16a34a"))
				w.draw_circle(p + Vector2(-44 + i * 22, -14), 3, Color("#ef4444"))
			w.draw_rect(Rect2(p + Vector2(-56, -50), Vector2(112, 60)), Color("#e2e8f0"), false, 3)
			w._text(p + Vector2(-60, -74), "SERA", 13, Color("#bbf7d0"), 120)
		"rasathane":
			w.draw_rect(Rect2(p + Vector2(-34, -30), Vector2(68, 40)), Color("#e5e7eb"))
			w.draw_circle(p + Vector2(0, -30), 34, Color("#cbd5e1"))
			w.draw_line(p + Vector2(0, -40), p + Vector2(40, -76), Color("#334155"), 8)
			w._text(p + Vector2(-60, -90), "RASATHANE", 13, Color("#e0e7ff"), 120)
		"anten":
			w.draw_line(p, p + Vector2(0, -60), Color("#9ca3af"), 5)
			w.draw_arc(p + Vector2(0, -70), 30, PI * 0.15 + sin(float(w._t) * 0.5) * 0.3, PI * 0.85 + sin(float(w._t) * 0.5) * 0.3, 16, Color("#e5e7eb"), 6)
			w.draw_circle(p + Vector2(0, -70), 4, Color("#ef4444") if fmod(float(w._t), 1.0) < 0.5 else Color("#7f1d1d"))
			w._text(p + Vector2(-60, -110), "UYDU ANTENİ", 13, Color("#e0e7ff"), 120)


func _draw_pad(p: Vector2) -> void:
	w.draw_set_transform(p, 0, Vector2(1, 0.55))
	w.draw_circle(Vector2.ZERO, 110, Color("#52525b"))
	w.draw_circle(Vector2.ZERO, 96, Color("#71717a"))
	w.draw_arc(Vector2.ZERO, 80, 0, TAU, 40, Color("#facc15"), 5)
	w.draw_set_transform(Vector2.ZERO)
	w._text(p + Vector2(-20, -18), "H", 36, Color("#facc15"), 40)


func _draw_rocket(p: Vector2, s: float) -> void:
	w.draw_set_transform(p + Vector2(8, 4), 0, Vector2(1, 0.4))
	w.draw_circle(Vector2.ZERO, 40 * s, Color(0, 0, 0, 0.3))
	w.draw_set_transform(Vector2.ZERO)
	var c := p + Vector2(0, -90 * s)
	w.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, 50) * s, c + Vector2(-48, 92) * s, c + Vector2(-22, 88) * s]), Color("#dc2626"))
	w.draw_colored_polygon(PackedVector2Array([c + Vector2(22, 50) * s, c + Vector2(48, 92) * s, c + Vector2(22, 88) * s]), Color("#dc2626"))
	w.draw_rect(Rect2(c + Vector2(-22, -60) * s, Vector2(44, 150) * s), Color("#f8fafc"))
	w.draw_rect(Rect2(c + Vector2(-22, -60) * s, Vector2(12, 150) * s), Color("#e2e8f0"))
	w.draw_colored_polygon(PackedVector2Array([c + Vector2(-22, -60) * s, c + Vector2(22, -60) * s, c + Vector2(0, -120) * s]), Color("#dc2626"))
	w.draw_circle(c + Vector2(0, -24) * s, 11 * s, Color("#38bdf8"))
	w.draw_arc(c + Vector2(0, -24) * s, 11 * s, 0, TAU, 24, Color("#475569"), 3)
	w.draw_rect(Rect2(c + Vector2(-14, 88) * s, Vector2(28, 10) * s), Color("#334155"))
	w._text(c + Vector2(-40, 30) * s, "MYC-1", 12, Color("#1e293b"), 80, false)


func _draw_spaceport(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#475569"))
	var s: Rect2 = Map.SPACEPORT
	w.draw_rect(s, Color("#cbd5e1"))
	var g := 100
	for gx in range(int(s.position.x / g) * g, int(s.end.x), g):
		w.draw_line(Vector2(gx, s.position.y), Vector2(gx, s.end.y), Color("#b6c2d1"), 2)
	for gy in range(int(s.position.y / g) * g, int(s.end.y), g):
		w.draw_line(Vector2(s.position.x, gy), Vector2(s.end.x, gy), Color("#b6c2d1"), 2)
	# pist
	var st: Vector2 = Map.SPACE_STRIP
	w.draw_rect(Rect2(st.x - 420, st.y - 40, 800, 80), Color("#334155"))
	for k in 12:
		w.draw_rect(Rect2(st.x - 400 + k * 68, st.y - 3, 38, 6), Color.WHITE)
	w._text(st + Vector2(-140, 44), "PİST — şehre uçuş (E)", 14, Color("#1e293b"), 280, false)
	_draw_plane(st + Vector2(220, 0))
	# fırlatma kulesi
	var pad: Vector2 = Map.SPACE_PAD
	_draw_pad(pad)
	w.draw_rect(Rect2(pad.x + 70, pad.y - 260, 26, 260), Color("#f97316"))
	for k in 9:
		w.draw_line(Vector2(pad.x + 70, pad.y - k * 30), Vector2(pad.x + 96, pad.y - k * 30 - 30), Color("#9a3412"), 2)
	w.draw_line(Vector2(pad.x + 70, pad.y - 200), Vector2(pad.x + 22, pad.y - 200), Color("#9a3412"), 6)
	items.append([pad.y + 5.0, "rocket", pad])
	w._text(pad + Vector2(-140, 70), "FIRLATMA RAMPASI — Ay'a git (E)", 15, Color("#1e293b"), 280, false)
	items.append([_hangar().end.y, "hangar", null])
	# uyarı çizgileri
	for k in 10:
		w.draw_rect(Rect2(s.position.x + 40 + k * 60, s.end.y - 40, 30, 12), Color("#facc15"))


func _draw_hangar() -> void:
	var h := _hangar()
	w.draw_rect(Rect2(h.position + Vector2(10, 14), h.size), Color(0, 0, 0, 0.25))
	w.draw_rect(h, Color("#e2e8f0"))
	w.draw_colored_polygon(PackedVector2Array([h.position, h.position + Vector2(h.size.x, 0), h.position + Vector2(h.size.x - 30, -50), h.position + Vector2(30, -50)]), Color("#94a3b8"))
	w.draw_rect(Rect2(h.position.x + 110, h.end.y - 110, 120, 110), Color("#475569"))
	for k in 6:
		w.draw_line(Vector2(h.position.x + 110, h.end.y - 110 + k * 18), Vector2(h.position.x + 230, h.end.y - 110 + k * 18), Color("#334155"), 2)
	for k in 2:
		w.draw_rect(Rect2(h.position.x + 24 + k * 230, h.position.y + 40, 60, 40), Color("#38bdf8"))
	w._text(h.position + Vector2(0, 6), "ROKET ATÖLYESİ · UZAY PAZARI", 16, Color("#1e293b"), h.size.x, false)


func _draw_plane(p: Vector2) -> void:
	w.draw_rect(Rect2(p.x - 60, p.y - 9, 120, 18), Color("#f8fafc"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -8), p + Vector2(20, -8), p + Vector2(-6, -60), p + Vector2(-22, -60)]), Color("#e2e8f0"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, 8), p + Vector2(20, 8), p + Vector2(-6, 60), p + Vector2(-22, 60)]), Color("#e2e8f0"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-60, -8), p + Vector2(-44, -8), p + Vector2(-56, -26)]), Color("#2563eb"))
	w.draw_circle(p + Vector2(60, 0), 9, Color("#f8fafc"))


func _draw_golf(view: Rect2, items: Array) -> void:
	w.draw_rect(view, Color("#365314"))
	w.draw_rect(Map.GOLF, Color("#3f6212"))
	var t := fmod(Land.server_now(), 1000.0)
	for i in Golf.HOLES.size():
		var f := Golf.field(i)
		if not view.intersects(f.grow(60)):
			continue
		var cell := Rect2(Golf.hole_origin(i), Golf.CELL)
		for k in 6:
			w.draw_circle(cell.position + Vector2(20 + k * 113, 18 + (k % 2) * 360), 14, Color("#166534"))
		w.draw_rect(f.grow(10), Color("#78350f"))
		w.draw_rect(f, Color("#65a30d"))
		for k in int(f.size.x / 40.0):
			if k % 2 == 0:
				w.draw_rect(Rect2(f.position.x + k * 40, f.position.y, 40, f.size.y), Color(1, 1, 1, 0.05))
		for s: Rect2 in Golf.rects(i, "s"):
			w.draw_rect(s, Color("#fde68a"))
			w.draw_rect(s.grow(-6), Color("#fcd34d"))
		for x: Rect2 in Golf.rects(i, "x"):
			w.draw_rect(x, Color("#0ea5e9"))
			for k in 3:
				var wp := x.position + Vector2(16 + k * 34, 20 + k * 26)
				w.draw_line(wp, wp + Vector2(18 + sin(float(w._t) * 2.0 + k) * 4, 0), Color(1, 1, 1, 0.5), 2)
		for wr: Rect2 in Golf.rects(i, "w"):
			w.draw_rect(Rect2(wr.position + Vector2(4, 5), wr.size), Color(0, 0, 0, 0.25))
			w.draw_rect(wr, Color("#92400e"))
			w.draw_rect(Rect2(wr.position, Vector2(wr.size.x, 5)), Color("#b45309"))
		var tee := Golf.tee(i)
		w.draw_rect(Rect2(tee - Vector2(18, 12), Vector2(36, 24)), Color("#15803d"))
		var cp := Golf.cup(i)
		w.draw_circle(cp, Golf.CUP_R + 3, Color("#4d7c0f"))
		w.draw_circle(cp, Golf.CUP_R, Color("#111827"))
		w.draw_line(cp, cp + Vector2(0, -52), Color("#e5e7eb"), 2)
		var wave := sin(float(w._t) * 3.0 + i) * 3.0
		w.draw_colored_polygon(PackedVector2Array([cp + Vector2(1, -52), cp + Vector2(26, -46 + wave), cp + Vector2(1, -38)]), Color("#ef4444"))
		w._text(cell.position + Vector2(0, 8), "%d. DELİK  ·  PAR %d" % [i + 1, int(Golf.HOLES[i].par)], 16, Color("#fef9c3"), Golf.CELL.x)
		for m in Golf.HOLES[i].m:
			items.append([Golf.hole_origin(i).y + (m as Vector2).y + 10.0, "windmill", [Golf.hole_origin(i) + m, Golf.blades(i, t)]])
	if Golf.my.get("done", false):
		var cards: Array = Golf.my.get("cards", [])
		w._text(w.my_pos + Vector2(-200, -150), "TUR BİTTİ: %d vuruş (par %d) — ödül %s" % [int(Golf.my.get("total", 0)), Golf.par_total(), U.money(int(Golf.my.get("reward", 0)))], 20, Color("#fde68a"), 400)
		w._text(w.my_pos + Vector2(-200, -124), "  ".join(PackedStringArray(cards.map(func(n): return str(n)))), 16, Color.WHITE, 400)


func _draw_windmill(c: Vector2, blades: Array) -> void:
	w.draw_rect(Rect2(c.x - 22, c.y - 30, 44, 40), Color("#fef3c7"))
	w.draw_colored_polygon(PackedVector2Array([c + Vector2(-28, -30), c + Vector2(28, -30), c + Vector2(0, -60)]), Color("#b91c1c"))
	for b in blades:
		w.draw_line(b[0], b[1], Color("#f8fafc"), 9)
		w.draw_line(b[0], b[1], Color("#78350f"), 3)
	w.draw_circle(c, 8, Color("#44403c"))


func _draw_golf_balls() -> void:
	var cols := [Color.WHITE, Color("#fde047"), Color("#f9a8d4"), Color("#93c5fd"), Color("#fdba74")]
	var k := 0
	for who in Golf.balls:
		var p := Golf.ball_pos(str(who))
		k += 1
		var col: Color = Color.WHITE if who == Net.my_name else cols[k % cols.size()]
		w.draw_circle(p + Vector2(2, 3), Golf.BALL_R, Color(0, 0, 0, 0.3))
		w.draw_circle(p, Golf.BALL_R, col)
		w.draw_arc(p, Golf.BALL_R, 0, TAU, 16, Color(0, 0, 0, 0.35), 1)
		if who != Net.my_name:
			w._text(p + Vector2(-50, -26), str(who), 11, Color(1, 1, 1, 0.8), 100)
	if Golf.playing():
		var mb := Golf.ball_pos(Net.my_name)
		if not _drag and not Golf.flying.has(Net.my_name):
			w.draw_arc(mb, 16 + sin(float(w._t) * 4.0) * 3.0, 0, TAU, 20, Color(1, 1, 1, 0.6), 2)
		if _drag:
			var pull := (mb - _drag_to).limit_length(180.0)
			var pw := pull.length() / 180.0
			var col2 := Color("#22c55e").lerp(Color("#ef4444"), pw)
			w.draw_line(mb, _drag_to, Color(1, 1, 1, 0.4), 2)
			var dir := pull.normalized()
			for d in 8:
				w.draw_circle(mb + dir * (18.0 + d * 14.0 * (0.4 + pw)), 3.0, Color(col2, 1.0 - d * 0.1))
			w._text(mb + Vector2(-40, 18), "%%%d" % int(pw * 100), 14, col2, 80)


# ------------------------------------------------------------------ çizim: şehir, dağ, fuar eklemeleri

func draw_ground() -> void:
	var view: Rect2 = w._view_rect().grow(200)
	if view.has_point(Map.DUNGEON_DOOR):
		_draw_cave(Map.DUNGEON_DOOR)
	if view.has_point(Map.DUNGEON_SHOP):
		_draw_weapon_tent(Map.DUNGEON_SHOP)
	if view.intersects(Map.BOWLING.rect):
		_draw_bowling_hall(Map.BOWLING.rect)
	if view.has_point(Map.GOLF_BOOTH):
		_draw_golf_booth(Map.GOLF_BOOTH)


func add_items(items: Array) -> void:
	if not Zombies.active() or w._room >= 0:
		return
	_monster_items(items, true)
	for b in Zombies.state.get("bar", []):
		items.append([float(b[1]), "adv", ["bar", b]])
	for c in Zombies.state.get("civ", []):
		items.append([float(c[1]), "adv", ["civ", c]])
	var dp := Zombies.defense_pos()
	items.append([dp.y, "adv", ["defense", dp]])


func draw_item(d: Array) -> void:
	match str(d[0]):
		"bar":
			_draw_barricade(d[1])
		"civ":
			_draw_civilian(d[1])
		"defense":
			_draw_defense(d[1])
		"m":
			_draw_monster(d[1])


## Şehir çiziminin en sonunda: kızıl dolunay tonu ve savaş efektleri.
func draw_overlay() -> void:
	if Zombies.active() and w._room < 0 and not w._fair and not w._mount:
		w.draw_rect(w._view_rect().grow(50), Color(0.55, 0.0, 0.05, 0.13))
	_draw_fx()


func _draw_cave(p: Vector2) -> void:
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-170, 30), p + Vector2(-140, -90), p + Vector2(-60, -150), p + Vector2(40, -160),
		p + Vector2(130, -110), p + Vector2(175, 30)]), Color("#57534e"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-140, -90), p + Vector2(-60, -150), p + Vector2(40, -160), p + Vector2(10, -110), p + Vector2(-80, -100)]), Color("#e7e5e4"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, 30), p + Vector2(-60, -50), p + Vector2(-20, -84), p + Vector2(28, -84), p + Vector2(64, -50), p + Vector2(74, 30)]), Color("#0c0a09"))
	for s in [-1.0, 1.0]:
		var tp := p + Vector2(s * 100, -10)
		w.draw_rect(Rect2(tp.x - 3, tp.y - 30, 6, 40), Color("#78350f"))
		var fl := 0.8 + 0.2 * sin(float(w._t) * 9.0 + s)
		w.draw_circle(tp + Vector2(0, -36), 9 * fl, Color("#f97316"))
		w.draw_circle(tp + Vector2(0, -38), 5 * fl, Color("#fde047"))
	for k in 3:
		var u := fmod(float(w._t) * 0.3 + k / 3.0, 1.0)
		w.draw_circle(p + Vector2(0, -20 - u * 30), 4 + u * 6, Color(0.6, 0.6, 0.6, 0.15 * (1.0 - u)))
	w._text(p + Vector2(-150, -196), "MAĞARA ZİNDANI", 20, Color("#fca5a5"), 300)


func _draw_weapon_tent(p: Vector2) -> void:
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-70, 20), p + Vector2(0, -70), p + Vector2(70, 20)]), Color("#991b1b"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-16, 20), p + Vector2(0, -20), p + Vector2(16, 20)]), Color("#450a0a"))
	w.draw_line(p + Vector2(0, -70), p + Vector2(0, -92), Color("#78350f"), 3)
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -92), p + Vector2(22, -86), p + Vector2(0, -80)]), Color("#facc15"))
	# silah rafı
	w.draw_rect(Rect2(p.x + 76, p.y - 40, 8, 60), Color("#78350f"))
	w.draw_line(p + Vector2(90, 20), p + Vector2(90, -40), Color("#cbd5e1"), 4)
	w.draw_line(p + Vector2(82, -26), p + Vector2(98, -26), Color("#a16207"), 4)
	w.draw_arc(p + Vector2(110, -10), 26, -PI / 2.0, PI / 2.0, 12, Color("#92400e"), 3)
	w._text(p + Vector2(-80, -126), "SİLAHÇI", 16, Color("#fde68a"), 160)


func _draw_bowling_hall(r: Rect2) -> void:
	w.draw_rect(Rect2(r.position + Vector2(10, 14), r.size), Color(0, 0, 0, 0.22))
	w.draw_rect(r, Color("#4c1d95"))
	w.draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), Color("#2e1065"))
	for k in 6:
		w.draw_rect(Rect2(r.position.x + 20 + k * 70, r.position.y + 120, 44, 50), Color("#fde68a") if Env.darkness() > 0.3 else Color("#93c5fd"))
	w.draw_rect(Rect2(r.get_center().x - 34, r.end.y - 70, 68, 70), Color("#1e1b4b"))
	w.draw_rect(Rect2(r.get_center().x - 30, r.end.y - 66, 28, 66), Color("#60a5fa"))
	w.draw_rect(Rect2(r.get_center().x + 2, r.end.y - 66, 28, 66), Color("#60a5fa"))
	# neon lobut ve top
	var nc := Color(1.0, 0.3, 0.7, 0.75 + 0.25 * sin(float(w._t) * 3.0))
	var lp := r.position + Vector2(r.size.x - 70, 64)
	w.draw_circle(lp + Vector2(0, -26), 9, nc)
	w.draw_circle(lp, 15, nc)
	w.draw_circle(lp + Vector2(-34, 6), 14, Color(0.3, 0.8, 1.0, nc.a))
	w._text(r.position + Vector2(0, 58), "BOWLING", 26, Color("#f0abfc"), r.size.x - 80)


func _draw_golf_booth(p: Vector2) -> void:
	w.draw_rect(Rect2(p.x - 50, p.y - 70, 100, 70), Color("#15803d"))
	w.draw_rect(Rect2(p.x - 58, p.y - 84, 116, 18), Color("#fef3c7"))
	w.draw_rect(Rect2(p.x - 36, p.y - 54, 72, 28), Color("#bbf7d0"))
	w.draw_line(p + Vector2(70, 10), p + Vector2(70, -80), Color("#e5e7eb"), 3)
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(71, -80), p + Vector2(100, -72), p + Vector2(71, -62)]), Color("#ef4444"))
	w.draw_circle(p + Vector2(40, 18), 5, Color.WHITE)
	w._text(p + Vector2(-80, -112), "MİNİ GOLF", 16, Color("#bbf7d0"), 160)


func _draw_barricade(b: Array) -> void:
	var p := Vector2(b[0], b[1])
	var hp := clampf(float(b[2]) / Zombies.BARRICADE_HP, 0.0, 1.0)
	w.draw_rect(Rect2(p.x - 32, p.y - 8, 64, 10), Color(0, 0, 0, 0.25))
	w.draw_line(p + Vector2(-28, -2), p + Vector2(28, -30), Color("#92400e"), 7)
	w.draw_line(p + Vector2(-28, -30), p + Vector2(28, -2), Color("#a16207"), 7)
	w.draw_rect(Rect2(p.x - 30, p.y - 20, 60, 8), Color("#78350f"))
	for k in 3:
		w.draw_colored_polygon(PackedVector2Array([p + Vector2(-24 + k * 24, -30), p + Vector2(-20 + k * 24, -46), p + Vector2(-16 + k * 24, -30)]), Color("#d6d3d1"))
	w.draw_rect(Rect2(p.x - 26, p.y - 56, 52, 4), Color(0, 0, 0, 0.6))
	w.draw_rect(Rect2(p.x - 26, p.y - 56, 52 * hp, 4), Color("#f59e0b"))


func _draw_civilian(c: Array) -> void:
	var p := Vector2(c[0], c[1])
	Avatar.draw(w, p, {"skin": 2, "hair": 1, "hair_color": 2, "shirt": 4, "pants": 1}, "down", 0)
	var wave := sin(float(w._t) * 8.0) * 6.0
	w.draw_line(p + Vector2(10, -40), p + Vector2(22, -62 + wave), Color("#e8b48a"), 4)
	var bp := p + Vector2(0, -96 + sin(float(w._t) * 3.0) * 3.0)
	w.draw_circle(bp, 13, Color.WHITE)
	w._text(bp + Vector2(-10, -12), "!", 20, Color("#dc2626"), 20, false)
	w._text(p + Vector2(-60, 8), "İMDAT!", 12, Color("#fde68a"), 120)


func _draw_defense(p: Vector2) -> void:
	w.draw_circle(p + Vector2(0, -20), 150, Color(1.0, 0.75, 0.4, 0.10))
	w.draw_circle(p + Vector2(0, -20), 80, Color(1.0, 0.75, 0.4, 0.10))
	for k in 8:
		var a := PI + k * PI / 7.0
		var sp := p + Vector2(cos(a), sin(a) * 0.5) * 80.0 + Vector2(0, 30)
		w.draw_rect(Rect2(sp.x - 16, sp.y - 8, 32, 14), Color("#a8a29e"))
		w.draw_rect(Rect2(sp.x - 16, sp.y - 8, 32, 14), Color("#57534e"), false, 1)
	w.draw_rect(Rect2(p.x - 40, p.y - 50, 80, 50), Color("#65a30d"))
	w.draw_colored_polygon(PackedVector2Array([p + Vector2(-48, -50), p + Vector2(48, -50), p + Vector2(0, -86)]), Color("#84cc16"))
	w.draw_line(p + Vector2(-8, -64), p + Vector2(8, -64), Color("#dc2626"), 5)
	w.draw_line(p + Vector2(0, -72), p + Vector2(0, -56), Color("#dc2626"), 5)
	w.draw_rect(Rect2(p.x - 12, p.y - 30, 24, 30), Color("#1a2e05"))
	var bl := 0.5 + 0.5 * sin(float(w._t) * 6.0)
	w.draw_circle(p + Vector2(-56, -60), 6, Color(1, 0.1, 0.1, bl))
	w.draw_circle(p + Vector2(56, -60), 6, Color(0.2, 0.4, 1, 1.0 - bl))
	w._text(p + Vector2(-120, -120), "SAVUNMA MERKEZİ", 16, Color("#fca5a5"), 240)
