extends RefCounted
## 2.3: kurum iç mekanları (istemci): odayı, eşyaları ve görevliyi çizer; kapı ve tezgâh E alanlarını kurar.
## Sunucu tarafı: scripts/inside.gd. Odalar Map.INST_AREA'da, ölçüler Map.INST_SIZE (1056 x 624).

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")

var w: Node2D

## Her kurum: zemin iki tonu, duvar, görevli adı ve eşyalar [tür, Rect2 (odanın sol üstüne göre), engel mi].
## Kapıdan tezgâha giden orta koridor (x 400..656) boş bırakılır.
const ROOMS := {
	"hospital": {"floor": ["#f1f5f9", "#e2e8f0"], "wall": "#bfdbfe", "staff": "Hemşire Ayşe", "items": [
		["f:bed", Rect2(40, 210, 96, 144), true], ["f:bed", Rect2(170, 210, 96, 144), true], ["f:bed", Rect2(40, 410, 96, 144), true],
		["curtain", Rect2(146, 200, 14, 170), true], ["f:plant", Rect2(300, 40, 48, 48), true],
		["bench", Rect2(760, 230, 230, 44), true], ["bench", Rect2(760, 330, 230, 44), true], ["f:tv", Rect2(800, 30, 96, 48), false],
		["cross", Rect2(708, 30, 60, 60), false], ["f:plant", Rect2(960, 520, 48, 48), true]]},
	"market": {"floor": ["#fef3c7", "#fde68a"], "wall": "#86efac", "staff": "Kasiyer Ahmet", "items": [
		["shelf", Rect2(40, 230, 300, 46), true], ["shelf", Rect2(40, 370, 300, 46), true], ["shelf", Rect2(40, 500, 300, 46), true],
		["shelf", Rect2(716, 230, 300, 46), true], ["shelf", Rect2(716, 370, 300, 46), true], ["f:fridge", Rect2(720, 470, 48, 48), true],
		["f:fridge", Rect2(776, 470, 48, 48), true], ["f:fridge", Rect2(832, 470, 48, 48), true], ["cart", Rect2(900, 520, 70, 46), true]]},
	"casino": {"floor": ["#7f1d1d", "#991b1b"], "wall": "#581c87", "staff": "Krupiyer Can", "items": [
		["slot", Rect2(40, 200, 60, 80), true], ["slot", Rect2(40, 300, 60, 80), true], ["slot", Rect2(40, 400, 60, 80), true],
		["roulette", Rect2(170, 300, 190, 150), true], ["slot", Rect2(956, 200, 60, 80), true], ["slot", Rect2(956, 300, 60, 80), true],
		["slot", Rect2(956, 400, 60, 80), true], ["cards", Rect2(700, 300, 190, 150), true], ["f:lamp", Rect2(40, 540, 48, 48), true]]},
	"poker": {"floor": ["#14532d", "#166534"], "wall": "#1f2937", "staff": "Dağıtıcı Nuri", "items": [
		["pokertable", Rect2(90, 260, 250, 150), true], ["pokertable", Rect2(716, 260, 250, 150), true],
		["f:armchair", Rect2(40, 500, 48, 48), true], ["f:armchair", Rect2(968, 500, 48, 48), true], ["f:bookshelf", Rect2(60, 30, 96, 48), false]]},
	"realestate": {"floor": ["#e7e5e4", "#d6d3d1"], "wall": "#93c5fd", "staff": "Emlakçı Hakan", "items": [
		["citymap", Rect2(40, 24, 220, 70), false], ["f:desk", Rect2(80, 260, 96, 48), true], ["f:chair", Rect2(104, 320, 48, 48), true],
		["f:desk", Rect2(200, 400, 96, 48), true], ["f:armchair", Rect2(780, 260, 48, 48), true], ["f:armchair", Rect2(860, 260, 48, 48), true],
		["f:table", Rect2(800, 330, 96, 96), true], ["f:plant", Rect2(960, 520, 48, 48), true], ["f:rug", Rect2(740, 440, 144, 96), false]]},
	"galeri": {"floor": ["#e5e7eb", "#d1d5db"], "wall": "#1e3a8a", "staff": "Galerici Selim", "items": [
		["carshow", Rect2(60, 250, 260, 140), true], ["carshow", Rect2(736, 250, 260, 140), true], ["bikeshow", Rect2(100, 450, 140, 90), true],
		["boatshow", Rect2(770, 450, 200, 100), true], ["f:plant", Rect2(40, 30, 48, 48), false]]},
	"mobilya": {"floor": ["#d6b88a", "#c9a271"], "wall": "#fde68a", "staff": "Mobilyacı Osman", "items": [
		["f:sofa", Rect2(50, 230, 144, 48), true], ["f:rug", Rect2(60, 300, 144, 96), false], ["f:tv", Rect2(90, 420, 96, 48), true],
		["f:bed", Rect2(250, 250, 96, 144), true], ["f:lamp", Rect2(250, 420, 48, 48), true], ["f:table", Rect2(760, 240, 96, 96), true],
		["f:chair", Rect2(870, 260, 48, 48), true], ["f:bookshelf", Rect2(880, 380, 96, 48), true], ["f:armchair", Rect2(760, 460, 48, 48), true],
		["f:aquarium", Rect2(860, 500, 96, 48), true]]},
	"petshop": {"floor": ["#ecfccb", "#d9f99d"], "wall": "#fdba74", "staff": "Pet Shop Elif", "items": [
		["cage", Rect2(40, 220, 110, 90), true], ["cage", Rect2(170, 220, 110, 90), true], ["cage", Rect2(40, 360, 110, 90), true],
		["f:aquarium", Rect2(180, 380, 96, 48), true], ["cage", Rect2(776, 220, 110, 90), true], ["cage", Rect2(906, 220, 110, 90), true],
		["petbed", Rect2(800, 400, 120, 80), false], ["f:plant", Rect2(960, 530, 48, 48), true]]},
	"muhtarlik": {"floor": ["#e7e5e4", "#d6d3d1"], "wall": "#fecaca", "staff": "Katip Fikret", "items": [
		["flag", Rect2(300, 20, 90, 64), false], ["f:bookshelf", Rect2(60, 30, 96, 48), false], ["bench", Rect2(60, 260, 240, 44), true],
		["bench", Rect2(60, 360, 240, 44), true], ["board", Rect2(760, 24, 200, 70), false], ["f:desk", Rect2(800, 300, 96, 48), true],
		["f:chair", Rect2(824, 360, 48, 48), true], ["f:plant", Rect2(960, 530, 48, 48), true]]},
	"karakol": {"floor": ["#cbd5e1", "#94a3b8"], "wall": "#1e3a8a", "staff": "Komiser Kemal", "items": [
		["flag", Rect2(300, 20, 90, 64), false], ["f:desk", Rect2(80, 260, 96, 48), true], ["f:chair", Rect2(104, 320, 48, 48), true],
		["f:desk", Rect2(220, 260, 96, 48), true], ["wanted", Rect2(60, 24, 200, 70), false], ["cell", Rect2(740, 220, 276, 160), true],
		["cell", Rect2(740, 400, 276, 160), true]]},
	"banka": {"floor": ["#f5f5f4", "#e7e5e4"], "wall": "#065f46", "staff": "Veznedar Aylin", "items": [
		["vault", Rect2(40, 210, 180, 180), true], ["rope", Rect2(330, 260, 40, 200), true], ["rope", Rect2(686, 260, 40, 200), true],
		["f:desk", Rect2(800, 260, 96, 48), true], ["f:chair", Rect2(824, 320, 48, 48), true], ["f:plant", Rect2(960, 520, 48, 48), true],
		["stocks", Rect2(760, 24, 230, 70), false]]},
	"carsi": {"floor": ["#fdf2f8", "#fce7f3"], "wall": "#be185d", "staff": "Terzi Necla", "items": [
		["rack", Rect2(50, 230, 240, 50), true], ["rack", Rect2(50, 360, 240, 50), true], ["mirror", Rect2(60, 470, 60, 100), true],
		["rack", Rect2(766, 230, 240, 50), true], ["hats", Rect2(780, 360, 200, 60), true], ["f:rug", Rect2(820, 470, 144, 96), false],
		["f:armchair", Rect2(160, 510, 48, 48), true]]},
	"muze": {"floor": ["#e7e5e4", "#d6d3d1"], "wall": "#78350f", "staff": "Rehber Leyla", "items": [
		["exhibit", Rect2(60, 230, 90, 90), true], ["exhibit", Rect2(200, 230, 90, 90), true], ["exhibit", Rect2(60, 400, 90, 90), true],
		["exhibit", Rect2(200, 400, 90, 90), true], ["exhibit", Rect2(766, 230, 90, 90), true], ["exhibit", Rect2(906, 230, 90, 90), true],
		["exhibit", Rect2(766, 400, 90, 90), true], ["exhibit", Rect2(906, 400, 90, 90), true], ["painting", Rect2(60, 26, 160, 68), false],
		["painting", Rect2(836, 26, 160, 68), false]]},
	"okul": {"floor": ["#fef9c3", "#fef08a"], "wall": "#15803d", "staff": "Öğretmen Gül", "items": [
		["blackboard", Rect2(40, 24, 280, 74), false], ["schooldesk", Rect2(60, 240, 110, 60), true], ["schooldesk", Rect2(200, 240, 110, 60), true],
		["schooldesk", Rect2(60, 360, 110, 60), true], ["schooldesk", Rect2(200, 360, 110, 60), true], ["schooldesk", Rect2(746, 240, 110, 60), true],
		["schooldesk", Rect2(886, 240, 110, 60), true], ["schooldesk", Rect2(746, 360, 110, 60), true], ["schooldesk", Rect2(886, 360, 110, 60), true],
		["f:bookshelf", Rect2(900, 520, 96, 48), true]]},
	"spor": {"floor": ["#cbd5e1", "#94a3b8"], "wall": "#b91c1c", "staff": "Antrenör Tolga", "items": [
		["treadmill", Rect2(40, 220, 70, 120), true], ["treadmill", Rect2(130, 220, 70, 120), true], ["weights", Rect2(240, 230, 110, 80), true],
		["mat", Rect2(60, 420, 240, 120), false], ["bench_press", Rect2(740, 220, 140, 70), true], ["bag", Rect2(940, 220, 50, 50), true],
		["weights", Rect2(760, 380, 110, 80), true], ["f:fridge", Rect2(968, 520, 48, 48), true]]},
	"kaplica": {"floor": ["#e0f2fe", "#bae6fd"], "wall": "#0f766e", "staff": "Hamamcı Sevim", "items": [
		["pool", Rect2(40, 220, 330, 320), true], ["pool", Rect2(690, 220, 330, 200), true], ["towels", Rect2(700, 470, 150, 60), true],
		["f:plant", Rect2(960, 520, 48, 48), true], ["f:plant", Rect2(40, 30, 48, 48), false]]},
	"lokanta": {"floor": ["#fed7aa", "#fdba74"], "wall": "#7c2d12", "staff": "Aşçı Hatice", "items": [
		["f:table", Rect2(60, 250, 96, 96), true], ["f:chair", Rect2(160, 274, 48, 48), true], ["f:table", Rect2(60, 420, 96, 96), true],
		["f:chair", Rect2(160, 444, 48, 48), true], ["f:table", Rect2(780, 250, 96, 96), true], ["f:chair", Rect2(880, 274, 48, 48), true],
		["f:table", Rect2(780, 420, 96, 96), true], ["f:chair", Rect2(880, 444, 48, 48), true], ["f:stove", Rect2(60, 30, 96, 48), false],
		["f:stove", Rect2(900, 30, 96, 48), false]]},
	"yk_kafe": {"floor": ["#e0f2fe", "#f0f9ff"], "wall": "#0369a1", "staff": "Kafeci Deniz", "items": [
		["cafetable", Rect2(70, 250, 90, 90), true], ["cafetable", Rect2(220, 250, 90, 90), true], ["cafetable", Rect2(70, 420, 90, 90), true],
		["cafetable", Rect2(746, 250, 90, 90), true], ["cafetable", Rect2(896, 250, 90, 90), true], ["cafetable", Rect2(820, 420, 90, 90), true],
		["f:plant", Rect2(40, 540, 48, 48), true], ["seaview", Rect2(40, 20, 300, 74), false], ["seaview", Rect2(716, 20, 300, 74), false]]},
	"balikhali": {"floor": ["#e2e8f0", "#cbd5e1"], "wall": "#0c4a6e", "staff": "Balıkçı Rıfat", "items": [
		["fishstand", Rect2(40, 220, 300, 80), true], ["fishstand", Rect2(40, 370, 300, 80), true], ["fishstand", Rect2(716, 220, 300, 80), true],
		["crates", Rect2(740, 380, 140, 90), true], ["crates", Rect2(900, 380, 100, 90), true], ["scale", Rect2(60, 510, 70, 60), true]]},
}

const LABELS := {"yk_kafe": "Martı Kafe", "lokanta": "Yayla Lokantası", "kaplica": "Kaplıca", "balikhali": "Balık Hali"}


func _init(world: Node2D) -> void:
	w = world


func room() -> String:
	return Map.inst_at(w.my_pos)


func label_of(t: String) -> String:
	var b := Map.any_building(t)
	return str(b.get("label", LABELS.get(t, t)))


## Odanın engelleri (dünya koordinatı): tezgâh ve katı eşyalar.
func blockers(t: String) -> Array:
	var r := Map.inst_rect(t)
	var out: Array = [Map.inst_counter(t)]
	for it in ROOMS.get(t, {}).get("items", []):
		if bool(it[2]):
			out.append(Rect2(r.position + (it[1] as Rect2).position, (it[1] as Rect2).size).grow(-6))
	return out


func clamp_pos(p: Vector2) -> Vector2:
	var t := room()
	if t == "":
		return p
	var r := Map.inst_rect(t)
	return p.clamp(r.position + Vector2(22, 120), r.end - Vector2(22, 22))


func can_stand(p: Vector2) -> bool:
	var t := room()
	if t == "":
		return true
	var me: Vector2 = w.my_pos
	for b in blockers(t):
		if (b as Rect2).has_point(p) and not (b as Rect2).has_point(me):
			return false
	return true


## Kapının dışında: binaya gir (şehirde ve kasabalarda).
static func enter_zone(t: String, label: String) -> Dictionary:
	return {"type": "adv", "do": "i_enter", "t": t, "label": "%s — içeri gir" % label}


func update_zone() -> void:
	var t := room()
	var me: Vector2 = w.my_pos
	var z := {}
	if t != "":
		if Map.inst_door(t).grow(16).has_point(me):
			z = {"type": "adv", "do": "i_leave", "label": "Dışarı çık"}
		elif Map.inst_counter(t).grow(80).has_point(me):
			z = service_zone(t)
	w.zone = z
	w._g_action = {}
	var hint := "" if z.is_empty() else "[%s]  %s" % [Settings.key_name("interact"), z.label]
	w.hud.set_hint("" if w.panel != null else w.adv.decorate(hint))


## Tezgâhta E: binanın her zamanki penceresi (kasaba hizmetleri Roads üzerinden).
func service_zone(t: String) -> Dictionary:
	var sv := Roads.service_at(w.my_pos)
	if sv != "":
		var s: Dictionary = Roads.SERVICES[sv]
		var lbl: String = {"hal": "Balık Hali — kovadaki balıkları %%%d fazlasına sat" % int((Roads.HAL_BONUS - 1.0) * 100),
			"kaplica": "Kaplıca (%s): enerji dolar, 15 dk maaş bonusu" % U.money(int(s.price)),
			"lokanta": "Yayla Lokantası: gözleme ve ayran (%s)" % U.money(int(s.price)),
			"kafe": "Martı Kafe: çay ve poğaça (%s)" % U.money(int(s.price))}.get(sv, str(s.name))
		return {"type": "roads", "do": "service", "k": sv, "label": lbl}
	return {"type": t, "label": "%s — %s" % [label_of(t), str(ROOMS.get(t, {}).get("staff", "görevli"))]}


# ------------------------------------------------------------------ çizim

func draw_room(view: Rect2, items: Array) -> void:
	w.draw_rect(view.grow(400), Color("#0b0f17"))
	var t := room()
	if t == "":
		return
	var r := Map.inst_rect(t)
	var st: Dictionary = ROOMS.get(t, {})
	var wall := Color(str(st.get("wall", "#475569")))
	var f0 := Color(str(st.get("floor", ["#e5e7eb", "#d1d5db"])[0]))
	var f1 := Color(str(st.get("floor", ["#e5e7eb", "#d1d5db"])[1]))
	w.draw_rect(r.grow(30), wall.darkened(0.45))
	w.draw_rect(r, f0)
	var tile := 48.0
	for ty in int(r.size.y / tile):
		for tx in int(r.size.x / tile):
			if (tx + ty) % 2 == 0:
				w.draw_rect(Rect2(r.position + Vector2(tx, ty) * tile, Vector2(tile, tile)), f1)
	# arka duvar ve pencereler
	w.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 100), wall)
	w.draw_rect(Rect2(r.position.x, r.position.y + 96, r.size.x, 6), wall.darkened(0.3))
	var night: bool = Env.darkness() > 0.5
	for k in 3:
		var wx := r.position.x + 400.0 + k * 100.0
		if k == 1:
			continue
		w.draw_rect(Rect2(wx - 30, r.position.y + 22, 60, 50), Color("#1e293b") if night else Color("#93c5fd"))
		w.draw_rect(Rect2(wx - 30, r.position.y + 22, 60, 50), Color.WHITE, false, 3)
	w._text(Vector2(r.position.x, r.position.y - 44), label_of(t), 22, Color.WHITE, r.size.x)
	# kapı ve paspas
	var door := Map.inst_door(t)
	w.draw_rect(Rect2(door.position.x - 6, r.end.y - 4, door.size.x + 12, 34), Color("#7c4a1e"))
	w.draw_rect(Rect2(door.position.x + 6, r.end.y - 34, door.size.x - 12, 26), Color("#9f1239"))
	w._text(Vector2(door.position.x - 40, r.end.y + 32), "ÇIKIŞ", 14, Color(1, 1, 1, 0.7), door.size.x + 80)
	# yer eşyaları önce, kalanlar oyuncularla y sırasına göre
	for it in st.get("items", []):
		var rr := Rect2(r.position + (it[1] as Rect2).position, (it[1] as Rect2).size)
		if not bool(it[2]) or str(it[0]) in ["mat", "petbed"]:
			_deco(str(it[0]), rr)
		else:
			items.append([rr.end.y, "inside", [str(it[0]), rr]])
	# görevli tezgâhın arkasında
	var counter := Map.inst_counter(t)
	var sname: String = str(st.get("staff", "Görevli"))
	var sp := Vector2(counter.get_center().x, counter.position.y - 6)
	items.append([sp.y, "inside", ["staff", sp, sname]])
	items.append([counter.end.y, "inside", ["counter", counter, t]])


func draw_item(kind: String, d) -> bool:
	if kind != "inside":
		return false
	var a: Array = d
	match str(a[0]):
		"staff":
			var p: Vector2 = a[1]
			var app := Avatar.sanitize(Avatar.default_for(str(a[2])))
			w._draw_player(p, app, str(a[2]), false, "down", false)
		"counter":
			var c: Rect2 = a[1]
			w.draw_rect(Rect2(c.position + Vector2(0, 8), c.size), Color(0, 0, 0, 0.2))
			w.draw_rect(c, Color("#78350f"))
			w.draw_rect(Rect2(c.position, Vector2(c.size.x, 12)), Color("#a16207"))
			if str(a[2]) == "market":
				w.draw_rect(Rect2(c.position + Vector2(20, 16), Vector2(50, 30)), Color("#1f2937"))       # yazar kasa
		_:
			_deco(str(a[0]), a[1])
	return true


func _deco(kind: String, r: Rect2) -> void:
	if kind.begins_with("f:"):
		var tex = w.furn_tex.get(kind.substr(2))
		if tex != null:
			w.draw_texture_rect(tex, r, false)
		return
	var c := r.get_center()
	match kind:
		"curtain":
			w.draw_rect(r, Color("#7dd3fc"))
			for k in 6:
				w.draw_line(Vector2(r.position.x + 2, r.position.y + k * 28), Vector2(r.end.x - 2, r.position.y + k * 28 + 14), Color("#38bdf8"), 2)
		"bench":
			w.draw_rect(r, Color("#475569"))
			for k in int(r.size.x / 56.0):
				w.draw_rect(Rect2(r.position + Vector2(4 + k * 56, 4), Vector2(48, r.size.y - 8)), Color("#60a5fa"))
		"cross":
			w.draw_rect(Rect2(c - Vector2(8, 26), Vector2(16, 52)), Color("#dc2626"))
			w.draw_rect(Rect2(c - Vector2(26, 8), Vector2(52, 16)), Color("#dc2626"))
		"shelf":
			w.draw_rect(r, Color("#a16207"))
			for k in int(r.size.x / 22.0):
				w.draw_rect(Rect2(r.position + Vector2(4 + k * 22, 6), Vector2(16, 14)), Color.from_hsv(fmod(k * 0.17, 1.0), 0.65, 0.95))
				w.draw_rect(Rect2(r.position + Vector2(4 + k * 22, 26), Vector2(16, 14)), Color.from_hsv(fmod(k * 0.29 + 0.5, 1.0), 0.6, 0.9))
		"cart":
			w.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y - 12)), Color("#94a3b8"), false, 3)
			w.draw_circle(Vector2(r.position.x + 12, r.end.y - 6), 6, Color("#334155"))
			w.draw_circle(Vector2(r.end.x - 12, r.end.y - 6), 6, Color("#334155"))
		"slot":
			w.draw_rect(r, Color("#facc15"))
			w.draw_rect(Rect2(r.position + Vector2(8, 12), Vector2(r.size.x - 16, 30)), Color("#111827"))
			for k in 3:
				w.draw_circle(r.position + Vector2(16 + k * 14, 27), 5, [Color("#ef4444"), Color("#22c55e"), Color("#3b82f6")][(k + int(w._t * 4.0)) % 3])
			w.draw_line(Vector2(r.end.x, r.position.y + 20), Vector2(r.end.x + 10, r.position.y + 6), Color("#9ca3af"), 3)
		"roulette":
			w.draw_rect(r, Color("#15803d"))
			w.draw_rect(r, Color("#78350f"), false, 6)
			var rc := Vector2(r.position.x + 60, c.y)
			w.draw_circle(rc, 44, Color("#78350f"))
			for k in 12:
				w.draw_arc(rc, 34, w._t * 2.0 + k * TAU / 12.0, w._t * 2.0 + (k + 1) * TAU / 12.0, 4, Color("#dc2626") if k % 2 == 0 else Color("#111827"), 16)
			w.draw_circle(rc, 10, Color("#facc15"))
			for k in 6:
				w.draw_rect(Rect2(r.position + Vector2(120 + (k % 2) * 30, 20 + int(k / 2.0) * 36), Vector2(26, 30)), Color("#dc2626") if k % 3 == 0 else Color("#111827"))
		"cards", "pokertable":
			w.draw_circle(c, minf(r.size.x, r.size.y) * 0.52, Color("#78350f"))
			w.draw_circle(c, minf(r.size.x, r.size.y) * 0.46, Color("#15803d"))
			for k in 5:
				w.draw_rect(Rect2(c + Vector2(-60 + k * 25, -14), Vector2(20, 28)), Color.WHITE)
			for k in 6:
				var cp := c + Vector2.RIGHT.rotated(TAU * k / 6.0) * minf(r.size.x, r.size.y) * 0.62
				w.draw_circle(cp, 13, Color("#7f1d1d"))
		"citymap":
			w.draw_rect(r, Color("#fef3c7"))
			w.draw_rect(r, Color("#78350f"), false, 3)
			for k in 8:
				w.draw_rect(Rect2(r.position + Vector2(12 + (k % 4) * 52, 10 + int(k / 4.0) * 30), Vector2(40, 22)), Color("#86efac") if k % 3 else Color("#fca5a5"))
		"carshow", "bikeshow", "boatshow":
			w.draw_rect(r, Color("#cbd5e1"))
			w.draw_rect(r, Color("#94a3b8"), false, 3)
			var col := Color.from_hsv(fmod(r.position.x * 0.0007, 1.0), 0.7, 0.85)
			if kind == "carshow":
				w.draw_rect(Rect2(c - Vector2(80, 26), Vector2(160, 52)), col)
				w.draw_rect(Rect2(c - Vector2(40, 22), Vector2(70, 44)), Color("#bae6fd"))
				for o in [Vector2(-55, -30), Vector2(45, -30), Vector2(-55, 22), Vector2(45, 22)]:
					w.draw_rect(Rect2(c + o, Vector2(20, 10)), Color("#111827"))
			elif kind == "bikeshow":
				w.draw_arc(c + Vector2(-28, 8), 18, 0, TAU, 20, Color("#111827"), 4)
				w.draw_arc(c + Vector2(28, 8), 18, 0, TAU, 20, Color("#111827"), 4)
				w.draw_line(c + Vector2(-28, 8), c + Vector2(0, -12), col, 4)
				w.draw_line(c + Vector2(0, -12), c + Vector2(28, 8), col, 4)
			else:
				w.draw_colored_polygon(PackedVector2Array([c + Vector2(-80, -14), c + Vector2(70, -14), c + Vector2(90, 0), c + Vector2(70, 18), c + Vector2(-80, 18)]), Color.WHITE)
				w.draw_rect(Rect2(c + Vector2(-30, -26), Vector2(50, 14)), Color("#0ea5e9"))
		"cage":
			w.draw_rect(r, Color("#fef3c7"))
			var hue := fmod(r.position.x * 0.0013 + r.position.y * 0.0007, 1.0)
			w.draw_circle(c + Vector2(0, 10), 18, Color.from_hsv(hue, 0.45, 0.85))
			w.draw_circle(c + Vector2(0, -12), 12, Color.from_hsv(hue, 0.45, 0.85))
			for k in int(r.size.x / 14.0) + 1:
				w.draw_line(Vector2(r.position.x + k * 14, r.position.y), Vector2(r.position.x + k * 14, r.end.y), Color("#64748b"), 2)
			w.draw_rect(r, Color("#475569"), false, 3)
		"petbed":
			w.draw_circle(c, r.size.y * 0.5, Color("#f9a8d4"))
			w.draw_circle(c, r.size.y * 0.32, Color("#fce7f3"))
		"flag":
			w.draw_line(Vector2(r.position.x + 4, r.end.y), Vector2(r.position.x + 4, r.position.y), Color("#d1d5db"), 4)
			w.draw_rect(Rect2(r.position + Vector2(8, 2), Vector2(r.size.x - 10, r.size.y * 0.6)), Color("#e30a17"))
			w.draw_circle(r.position + Vector2(r.size.x * 0.42, r.size.y * 0.3), 11, Color.WHITE)
			w.draw_circle(r.position + Vector2(r.size.x * 0.46, r.size.y * 0.3), 9, Color("#e30a17"))
		"board", "wanted", "stocks", "blackboard", "painting", "seaview":
			var bg: Color = {"board": Color("#fef3c7"), "wanted": Color("#fef3c7"), "stocks": Color("#0f172a"), "blackboard": Color("#14532d"),
				"painting": Color("#1e3a8a"), "seaview": Color("#38bdf8")}.get(kind, Color.WHITE)
			w.draw_rect(r, bg)
			w.draw_rect(r, Color("#78350f"), false, 5)
			match kind:
				"wanted":
					for k in 3:
						w.draw_rect(Rect2(r.position + Vector2(12 + k * 64, 8), Vector2(52, 54)), Color("#fde68a"))
						w.draw_circle(r.position + Vector2(38 + k * 64, 30), 12, Color("#78350f"))
				"stocks":
					var pts := PackedVector2Array()
					for k in 12:
						pts.append(r.position + Vector2(10 + k * 19, r.size.y * 0.5 + sin(k * 1.3 + w._t) * 18.0))
					w.draw_polyline(pts, Color("#22c55e"), 3)
				"blackboard":
					w._text(r.position + Vector2(0, 28), "2 + 2 = 4", 20, Color(1, 1, 1, 0.85), r.size.x, false)
				"painting":
					w.draw_circle(r.position + Vector2(40, 30), 14, Color("#facc15"))
					w.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y), r.position + Vector2(r.size.x * 0.5, 20), r.end]), Color("#15803d"))
				"seaview":
					w.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.55, r.size.x, r.size.y * 0.45), Color("#0369a1"))
					w.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color.WHITE, 4)
				_:
					for k in 4:
						w.draw_rect(Rect2(r.position + Vector2(14 + k * 46, 12 + (k % 2) * 10), Vector2(36, 30)), Color("#fca5a5") if k % 2 else Color("#93c5fd"))
		"cell":
			w.draw_rect(r, Color("#475569"))
			w.draw_rect(Rect2(r.position + Vector2(20, 20), Vector2(70, 30)), Color("#64748b"))     # ranza
			for k in int(r.size.x / 20.0) + 1:
				w.draw_line(Vector2(r.position.x + k * 20, r.position.y), Vector2(r.position.x + k * 20, r.end.y), Color("#cbd5e1"), 4)
			w.draw_rect(r, Color("#1f2937"), false, 5)
		"vault":
			w.draw_rect(r, Color("#6b7280"))
			w.draw_circle(c, r.size.x * 0.42, Color("#9ca3af"))
			w.draw_circle(c, r.size.x * 0.42, Color("#4b5563"), false, 6)
			for k in 6:
				w.draw_line(c, c + Vector2.RIGHT.rotated(k * TAU / 6.0 + w._t * 0.2) * r.size.x * 0.32, Color("#374151"), 6)
			w.draw_circle(c, 14, Color("#facc15"))
		"rope":
			w.draw_circle(Vector2(c.x, r.position.y + 8), 8, Color("#facc15"))
			w.draw_circle(Vector2(c.x, r.end.y - 8), 8, Color("#facc15"))
			w.draw_line(Vector2(c.x, r.position.y + 8), Vector2(c.x, r.end.y - 8), Color("#b91c1c"), 6)
		"rack":
			w.draw_line(r.position + Vector2(0, 8), Vector2(r.end.x, r.position.y + 8), Color("#9ca3af"), 4)
			for k in int(r.size.x / 26.0):
				w.draw_rect(Rect2(r.position + Vector2(4 + k * 26, 10), Vector2(22, r.size.y - 12)), Color.from_hsv(fmod(k * 0.13 + r.position.y * 0.001, 1.0), 0.6, 0.9))
		"hats":
			for k in 4:
				var hc := r.position + Vector2(25 + k * 50, r.size.y * 0.6)
				w.draw_rect(Rect2(hc - Vector2(20, 4), Vector2(40, 8)), Color.from_hsv(k * 0.23, 0.6, 0.7))
				w.draw_rect(Rect2(hc - Vector2(12, 22), Vector2(24, 20)), Color.from_hsv(k * 0.23, 0.6, 0.7))
		"mirror":
			w.draw_rect(r, Color("#78350f"))
			w.draw_rect(r.grow(-6), Color("#e0f2fe"))
			w.draw_line(r.position + Vector2(14, 20), r.position + Vector2(30, 4), Color.WHITE, 3)
		"exhibit":
			w.draw_rect(Rect2(r.position + Vector2(10, r.size.y * 0.45), Vector2(r.size.x - 20, r.size.y * 0.55)), Color("#e7e5e4"))
			w.draw_rect(Rect2(r.position + Vector2(10, r.size.y * 0.45), Vector2(r.size.x - 20, r.size.y * 0.55)), Color("#a8a29e"), false, 2)
			var hue2 := fmod(r.position.x * 0.0019 + r.position.y * 0.0031, 1.0)
			w.draw_circle(Vector2(c.x, r.position.y + r.size.y * 0.3), 18, Color.from_hsv(hue2, 0.55, 0.9))
			w.draw_rect(r.grow(4), Color(1, 1, 1, 0.15), false, 2)
		"schooldesk":
			w.draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), Color("#a16207"))
			w.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.3, 38), Vector2(r.size.x * 0.4, 20)), Color("#1d4ed8"))
		"treadmill":
			w.draw_rect(r, Color("#1f2937"))
			w.draw_rect(Rect2(r.position + Vector2(8, 30), Vector2(r.size.x - 16, r.size.y - 38)), Color("#4b5563"))
			w.draw_rect(Rect2(r.position + Vector2(10, 6), Vector2(r.size.x - 20, 18)), Color("#22c55e"))
		"weights":
			w.draw_rect(r, Color("#374151"), false, 4)
			for k in 4:
				w.draw_circle(r.position + Vector2(18 + k * 25, r.size.y * 0.5), 10, Color("#111827"))
		"mat":
			w.draw_rect(r, Color("#2563eb"))
			w.draw_rect(r, Color("#1e40af"), false, 4)
		"bench_press":
			w.draw_rect(Rect2(r.position + Vector2(40, 20), Vector2(60, 34)), Color("#991b1b"))
			w.draw_line(r.position + Vector2(0, 12), Vector2(r.end.x, r.position.y + 12), Color("#9ca3af"), 5)
			w.draw_circle(r.position + Vector2(8, 12), 14, Color("#111827"))
			w.draw_circle(Vector2(r.end.x - 8, r.position.y + 12), 14, Color("#111827"))
		"bag":
			w.draw_rect(r, Color("#b91c1c"))
			w.draw_line(Vector2(c.x, r.position.y - 30), Vector2(c.x, r.position.y), Color("#9ca3af"), 3)
		"pool":
			w.draw_rect(r, Color("#e7e5e4"))
			w.draw_rect(r.grow(-12), Color("#5eead4"))
			for k in 5:
				var wy := r.position.y + 30 + k * (r.size.y - 60) / 4.0
				w.draw_line(Vector2(r.position.x + 24, wy + sin(w._t * 1.5 + k) * 4.0), Vector2(r.end.x - 24, wy + cos(w._t * 1.5 + k) * 4.0), Color(1, 1, 1, 0.35), 3)
			for k in 4:
				var sx := r.position.x + 40 + k * (r.size.x - 80) / 3.0
				var u := fposmod(w._t * 0.35 + k * 0.27, 1.0)
				w.draw_circle(Vector2(sx + sin(w._t + k) * 10.0, r.position.y + r.size.y * 0.5 - u * 120.0), 18 + u * 20.0, Color(1, 1, 1, 0.22 * (1.0 - u)))
		"towels":
			for k in 4:
				w.draw_rect(Rect2(r.position + Vector2(k * 38, 0), Vector2(32, r.size.y)), Color.from_hsv(k * 0.2 + 0.5, 0.35, 0.95))
		"cafetable":
			w.draw_circle(c, r.size.x * 0.32, Color("#f5f5f4"))
			w.draw_circle(c, r.size.x * 0.32, Color("#a8a29e"), false, 3)
			w.draw_circle(c + Vector2(-8, -4), 7, Color("#dc2626"))         # çay bardağı
			for o in [Vector2(-r.size.x * 0.48, 0), Vector2(r.size.x * 0.48, 0)]:
				w.draw_circle(c + o, 12, Color("#0369a1"))
		"fishstand":
			w.draw_rect(r, Color("#94a3b8"))
			w.draw_rect(r.grow(-6), Color("#e0f2fe"))
			for k in int(r.size.x / 36.0):
				var fp := r.position + Vector2(20 + k * 36, r.size.y * 0.5 + (k % 2) * 8 - 4)
				w.draw_colored_polygon(PackedVector2Array([fp + Vector2(-14, 0), fp + Vector2(0, -7), fp + Vector2(12, 0), fp + Vector2(0, 7)]), Color("#64748b") if k % 3 else Color("#f97316"))
				w.draw_colored_polygon(PackedVector2Array([fp + Vector2(12, 0), fp + Vector2(18, -6), fp + Vector2(18, 6)]), Color("#475569"))
		"crates":
			for k in int(r.size.x / 50.0):
				w.draw_rect(Rect2(r.position + Vector2(k * 50, 0), Vector2(46, r.size.y)), Color("#a16207"))
				w.draw_rect(Rect2(r.position + Vector2(k * 50, 0), Vector2(46, r.size.y)), Color("#78350f"), false, 3)
		"scale":
			w.draw_rect(r, Color("#9ca3af"))
			w.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 18)), Color("#111827"))
			w._text(r.position + Vector2(0, 23), "2,4 kg", 12, Color("#22c55e"), r.size.x, false)
		_:
			w.draw_rect(r, Color("#9ca3af"))
