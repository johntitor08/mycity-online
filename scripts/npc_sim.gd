extends RefCounted
## Şehir canlılığı (yalnızca istemcide, ağ trafiği yok): kaldırımda yürüyen vatandaşlar,
## yollarda NPC arabalar, işletmelere giden müşteriler ve evcil hayvanların sahiplerini takibi.
## Dünya sahnesi her karede update() çağırır, çizilecek nesneleri items() ile alır.

const Map = preload("res://scripts/map.gd")
const Avatar = preload("res://scripts/avatar.gd")

const WALKERS_PER_ROUTE := [9, 5, 7, 6]
const CARS_PER_LANE := 2
const WALK_SPEED := 70.0

var walkers: Array = []     # {route, d (yol üzerindeki mesafe), speed, app, dir}
var cars: Array = []        # {lane, x, speed, color}
var customers: Array = []   # {pos, target, app, t}
var pets := {}              # peer_id -> {pos, facing, moving}
var _route_len: Array = []
var _rng := RandomNumberGenerator.new()
var _cust_timer := 0.0


func _init() -> void:
	_rng.seed = 2026
	for r in Map.WALK_ROUTES:
		var total := 0.0
		for i in r.size():
			total += r[i].distance_to(r[(i + 1) % r.size()])
		_route_len.append(total)
	for ri in Map.WALK_ROUTES.size():
		for k in WALKERS_PER_ROUTE[ri]:
			walkers.append({"route": ri, "d": _rng.randf() * _route_len[ri], "speed": _rng.randf_range(0.7, 1.2) * WALK_SPEED,
				"app": Avatar.random(), "dir": 1.0 if _rng.randf() < 0.5 else -1.0, "pos": Vector2.ZERO, "facing": "down"})
	for li in Map.TRAFFIC_LANES.size():
		for k in CARS_PER_LANE:
			cars.append({"lane": li, "x": _rng.randf() * Map.WORLD.size.x, "speed": _rng.randf_range(150.0, 230.0),
				"color": Color.from_hsv(_rng.randf(), 0.55, 0.9), "police": false})
	cars[0].police = true                 # devriye arabası
	cars[0].color = Color("#e5e7eb")


func _route_point(ri: int, d: float) -> Array:
	var r: Array = Map.WALK_ROUTES[ri]
	d = fposmod(d, _route_len[ri])
	for i in r.size():
		var a: Vector2 = r[i]
		var b: Vector2 = r[(i + 1) % r.size()]
		var seg := a.distance_to(b)
		if d <= seg:
			return [a.lerp(b, d / seg), b - a]
		d -= seg
	return [r[0], Vector2.RIGHT]


static func _facing(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func update(delta: float, roster: Dictionary, positions: Dictionary, my_id: int, my_pos: Vector2) -> void:
	for w in walkers:
		w.d += w.speed * w.dir * delta
		var pt := _route_point(w.route, w.d)
		w.pos = pt[0]
		w.facing = _facing(pt[1] * w.dir)
	var bus := Map.bus_at(Land.server_now())
	var bus_pos: Vector2 = bus[0]
	for c in cars:
		var lane: Array = Map.TRAFFIC_LANES[c.lane]
		# önünde yaya, oyuncu, başka araba ya da otobüs varsa dur
		var blocked := false
		for pp in [my_pos] + positions.values():
			var ahead: float = (pp.x - float(c.x)) * float(lane[1])
			if absf(pp.y - float(lane[0])) < 36.0 and ahead > 0.0 and ahead < 105.0:
				blocked = true
				break
		if not blocked:
			for o in cars:
				if o != c and o.lane == c.lane:
					var ahead2: float = (float(o.x) - float(c.x)) * float(lane[1])
					if ahead2 > 0.0 and ahead2 < 110.0:
						blocked = true
						break
		var speed: float = c.speed
		if absf(bus_pos.y - float(lane[0])) < 30.0:
			var bus_ahead: float = (bus_pos.x - float(c.x)) * float(lane[1])
			if bus_ahead > 0.0 and bus_ahead < 150.0:
				blocked = true                       # otobüsün arkasında bekle
			elif bus_ahead < 0.0 and bus_ahead > -170.0 and not blocked:
				speed = maxf(speed, Map.BUS_SPEED + 10.0)  # otobüs arkadan geliyor: yol ver
		if blocked:
			continue
		c.x += speed * float(lane[1]) * delta
		var x0 := 0.0 if c.lane < 2 else 1060.0       # alttaki yol 1050'den başlar
		var x1 := Map.WORLD.size.x
		if c.x > x1 + 60:
			c.x = x0 - 60
		elif c.x < x0 - 60:
			c.x = x1 + 60
	# işletme müşterileri: açık ve malzemesi olan işletmelere ara ara biri yürür
	_cust_timer -= delta
	if _cust_timer <= 0.0:
		_cust_timer = 1.5
		for i in Land.view.size():
			var p: Dictionary = Land.view[i]
			if Biz.is_biz(p) and int(p.biz.stock) > 0 and _rng.randf() < 0.12 * maxf(1.0, float(p.biz.last_customers)):
				var door := Map.plot_front(i) + Vector2(0, -60)
				customers.append({"pos": Vector2(door.x + _rng.randf_range(-160, 160), Map.plot_rect(i).end.y + 30),
					"target": door, "app": Avatar.random(), "t": 0.0})
	for c in customers:
		var to: Vector2 = c.target - c.pos
		c.t += delta
		if to.length() > 4.0:
			c.pos += to.normalized() * WALK_SPEED * delta
			c.facing = _facing(to)
	customers = customers.filter(func(c): return c.t < 6.0 and c.pos.distance_to(c.target) > 4.0)
	# evcil hayvanlar sahibini takip eder
	for id in roster:
		var pet = roster[id].get("pet", {})
		if not pet is Dictionary or pet.is_empty():
			pets.erase(id)
			continue
		var owner: Vector2 = my_pos if id == my_id else positions.get(id, Vector2(-9999, -9999))
		var st: Dictionary = pets.get(id, {"pos": owner + Vector2(-30, 10), "facing": "right", "moving": false})
		var target: Vector2 = owner + Vector2(-34 if st.facing == "right" else 34, 12)
		var to: Vector2 = target - st.pos
		st.moving = to.length() > 6.0
		if st.moving:
			st.pos += to * minf(1.0, delta * 4.0)
			if absf(to.x) > 3.0:
				st.facing = "right" if to.x > 0 else "left"
		pets[id] = st
	for id in pets.keys():
		if not roster.has(id):
			pets.erase(id)


## Gece ve yağmurda sokaklar tenhalaşır.
func visible_walkers() -> Array:
	var keep := 1.0
	if Env.is_night():
		keep = 0.35
	if Env.is_rainy():
		keep *= 0.5
	var out: Array = []
	for i in walkers.size():
		if float(i % 20) / 20.0 < keep:
			out.append(walkers[i])
	return out
