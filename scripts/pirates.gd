extends Node
## Korsan Adası ve hazine haritası (1.5). Açık denizde, Martı Adası'nın doğusunda (tekneyle gidilir).
##  Korsan Kaptan Tek Göz Rıza: kürek satar, günde bir harita parçası satar, Korsan Papağanı satar.
##  Harita parçası (4 tane gerekir): adada kazarken, açık denizde balık tutarken ya da batık sandığından çıkar.
##  4 parça birleşince harita: sunucu adada gizli bir nokta seçer; harita kabaca yeri gösterir.
##  Kürekle kaz (E): her kazıda "sıcak / ılık / soğuk" ipucu; doğru yerde sandık → para ve Korsan Altını /
##  Korsan Pusulası (müzeye bağışlanabilir). Kazı izleri herkes tarafından görülür.
## Veri: rec["pirate"] = {pieces, spot: [x, y] | null, found, shovel, piece_day}

signal changed
signal dug(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const SHOVEL_PRICE := 300
const PIECE_PRICE := 400
const PARROT_PRICE := 3000
const PIECES := 4
const DIG_COOLDOWN := 1.1
const FIND_R := 55.0
const HOLES_MAX := 40
const LOOT := [["Korsan Altını", 800, 1400], ["Korsan Pusulası", 600, 900], ["Korsan Yüzüğü", 900, 1600]]

# --- istemci
var state := {"pieces": 0, "has_map": false, "shovel": false, "found": 0}
var map_hint := Vector2.ZERO       # haritadaki X (kaba)
var holes: Array = []              # [[x, y]]

# --- sunucu
var _dig_t := {}
var _holes: Array = []


func reset() -> void:
	state = {"pieces": 0, "has_map": false, "shovel": false, "found": 0}
	holes = []
	_holes.clear()


func on_player_left(id: int) -> void:
	_dig_t.erase(id)


## Hazine saklanabilecek noktalar (adanın içinde; iskele, gemi ve kaptandan uzak).
static func dig_spots() -> Array:
	# adanın içini ızgarayla tara: kıyıdan, gemiden, kaptandan ve iskeleden uzak noktalar
	var out: Array = []
	var k: Rect2 = Map.KORSAN
	var c := k.get_center()
	for gx in range(int(k.position.x) + 40, int(k.end.x) - 30, 70):
		for gy in range(int(k.position.y) + 40, int(k.end.y) - 30, 55):
			var p := Vector2(gx, gy)
			var d := (p - c) / (k.size / 2.0 - Vector2(40, 30))
			if d.length_squared() >= 1.0:
				continue
			if p.distance_to(Map.KORSAN_SHIP) > 140.0 and p.distance_to(Map.KORSAN_CAPTAIN) > 140.0 and not Map.KORSAN_PIER.grow(60).has_point(p):
				out.append(p)
	return out


# ------------------------------------------------------------------ istemci API

func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func combine() -> void:
	Net.ask(self, "req_combine")


func dig() -> void:
	Net.ask(self, "req_dig")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	state = d
	map_hint = d.get("hint", Vector2.ZERO)
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_holes(d: Dictionary) -> void:
	holes = d.get("h", [])


@rpc("authority", "call_local", "reliable")
func on_dug(d: Dictionary) -> void:
	dug.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("pirate") is Dictionary:
		rec["pirate"] = {"pieces": 0, "spot": null, "found": 0, "shovel": false, "piece_day": "", "hint": null}
	return rec.pirate


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var p := _data(rec)
	var d := {"pieces": int(p.pieces), "has_map": p.spot != null, "shovel": bool(p.shovel), "found": int(p.found),
		"piece_today": str(p.get("piece_day", "")) == Time.get_date_string_from_system()}
	if p.spot != null and p.get("hint") != null:
		d["hint"] = Vector2(float(p.hint[0]), float(p.hint[1]))
	Net.tell(self, id, "on_state", d)
	Net.tell(self, id, "on_holes", {"h": _holes})


## Diğer modüller (balıkçılık, dalış) şansla harita parçası verir.
func maybe_piece(id: int, chance: float) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var p := _data(rec)
	if int(p.pieces) >= PIECES or p.spot != null:
		return
	if Pets.is_happy(rec.get("pet", {})) and str(rec.get("pet", {}).get("kind", "")) == "korsan":
		chance *= 2.0
	if randf() < chance:
		p["pieces"] = int(p.pieces) + 1
		Net.mark_dirty()
		send_state(id)
		Net.notify(id, "Bir hazine haritası parçası buldun! (%d/%d) Korsan Adası'ndaki kaptana götür." % [int(p.pieces), PIECES])


func _near_captain(id: int) -> bool:
	return _pos(id).distance_to(Map.KORSAN_CAPTAIN) < 100.0


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _near_captain(id):
		return
	var p := _data(rec)
	match str(d.get("item", "")):
		"shovel":
			if bool(p.shovel):
				return
			if not Net.try_spend(id, SHOVEL_PRICE):
				Net.notify(id, "Kürek %s." % U.money(SHOVEL_PRICE), false)
				return
			p["shovel"] = true
			Net.notify(id, "Kürek senin! Adada E ile kaz.")
		"piece":
			var today := Time.get_date_string_from_system()
			if str(p.get("piece_day", "")) == today:
				Net.notify(id, "Kaptan: \"Arrr! Bugünlük bu kadar, yarın gel.\"", false)
				return
			if int(p.pieces) >= PIECES or p.spot != null:
				Net.notify(id, "Kaptan: \"Senin haritan zaten tamam, git kaz!\"", false)
				return
			if not Net.try_spend(id, PIECE_PRICE):
				Net.notify(id, "Harita parçası %s." % U.money(PIECE_PRICE), false)
				return
			p["piece_day"] = today
			p["pieces"] = int(p.pieces) + 1
			Net.notify(id, "Harita parçası alındı (%d/%d)." % [int(p.pieces), PIECES])
		"parrot":
			if int(p.found) < 1:
				Net.notify(id, "Kaptan: \"Papağanımı ancak bir hazine bulan gerçek bir korsana veririm!\"", false)
				return
			if rec.get("pet") is Dictionary:
				Net.notify(id, "Zaten bir evcil hayvanın var; papağan ancak boş bir omza konar.", false)
				return
			if not Net.try_spend(id, PARROT_PRICE):
				Net.notify(id, "Korsan Papağanı %s." % U.money(PARROT_PRICE), false)
				return
			if not Pets.give(id, "korsan", "Kaptan Gaga"):
				Net.add_money(id, PARROT_PRICE)
				return
			Net.notify(id, "Korsan Papağanı Kaptan Gaga artık seninle! Tokken harita parçası şansını ikiye katlar.")
		_:
			return
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_combine(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _near_captain(id):
		return
	var p := _data(rec)
	if int(p.pieces) < PIECES or p.spot != null:
		return
	var spot: Vector2 = dig_spots().pick_random()
	p["spot"] = [spot.x, spot.y]
	var hint := spot + Vector2(randf_range(-45, 45), randf_range(-30, 30))
	p["hint"] = [hint.x, hint.y]
	p["pieces"] = 0
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Parçalar birleşti: HAZİNE HARİTASI! X'in olduğu yere git ve kaz.")


@rpc("any_peer", "call_remote", "reliable")
func req_dig(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var pos := _pos(id)
	if not Map.on_korsan(pos):
		return
	var p := _data(rec)
	if not bool(p.shovel):
		Net.notify(id, "Kazmak için kürek lazım (kaptan satıyor).", false)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_dig_t.get(id, 0.0)) < DIG_COOLDOWN:
		return
	if not Rpg.use_energy(id, 1):
		Net.notify(id, "Çok yorgunsun.", false)
		return
	_dig_t[id] = now
	_holes.append([snappedf(pos.x, 1.0), snappedf(pos.y + 6.0, 1.0)])
	while _holes.size() > HOLES_MAX:
		_holes.pop_front()
	for pid in Net.players:
		if Map.KORSAN.grow(500).has_point(_pos(pid)):
			Net.tell(self, pid, "on_holes", {"h": _holes})
	var res := {"pos": pos}
	if p.spot != null:
		var spot := Vector2(float(p.spot[0]), float(p.spot[1]))
		var dist := pos.distance_to(spot)
		if dist <= FIND_R:
			var loot: Array = LOOT.pick_random()
			var money := randi_range(1500, 4000)
			Net.add_money(id, money)
			var bag: Array = rec.get("fish", [])
			if bag.size() < Jobs.BAG_SIZE:
				bag.append({"name": loot[0], "price": randi_range(int(loot[1]), int(loot[2]))})
				Jobs.send_inventory(id)
			p["spot"] = null
			p["hint"] = null
			p["found"] = int(p.found) + 1
			Ach.event(id, "pirate_treasure")
			Rpg.add_xp(id, "", 200)
			Net.mark_dirty()
			send_state(id)
			res["treasure"] = true
			Net.tell(self, id, "on_dug", res)
			Net.notify(id, "HAZİNE! Sandıktan %s ve %s çıktı!" % [U.money(money), loot[0]])
			Net.announce("%s Korsan Adası'nda gömülü hazineyi buldu!" % Net.players[id].name)
			return
		res["hint"] = "SICAK! Çok yakındasın!" if dist < 110.0 else ("Ilık... yaklaşıyorsun." if dist < 240.0 else "Soğuk. Haritaya bir daha bak.")
	maybe_piece(id, 0.12)
	var junk := ["Eski bir şişe çıktı.", "Paslı bir çivi...", "Bir yengeç kaçtı!", "Sadece kum.", "Kırık bir tabak parçası."]
	if not res.has("hint"):
		res["hint"] = junk.pick_random()
	Net.tell(self, id, "on_dug", res)
