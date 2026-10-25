extends Node
## Evcil hayvanlar: Pet Shop'tan alınır, sahibini takip eder, beslenmesi gerekir.
## Tokluk zamanla (çevrimdışıyken de) azalır; tokken (mutluyken) küçük bir bonus verir.
## Kayıt: rec["pet"] = {kind, name, food, t}. Herkes görsün diye oyuncu listesinde "pet" alanı var.

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PETS := {
	"cat": {"name": "Kedi", "price": 3000, "level": 2, "desc": "Mutluyken enerji harcaman %15 azalır", "fish": true},
	"dog": {"name": "Köpek", "price": 4000, "level": 3, "desc": "Mutluyken nadir balık şansı +%15", "fish": true},
	"parrot": {"name": "Papağan", "price": 5000, "level": 5, "desc": "Mutluyken hastane ve market maaşı +%10", "fish": false},
}
const FOOD_PRICE := 40            # 1 kutu mama
const FOOD_PER_CAN := 40          # tokluk
const FOOD_PER_FISH := 20
const HUNGER_SEC := 120.0         # 120 sn'de 1 tokluk azalır (~3,3 saatte tok → aç)
const HAPPY_AT := 40.0
const MAX_CANS := 20

var my_pet: Dictionary = {}       # istemci: {kind, name, food, cans} ya da {}


static func is_happy(pet: Dictionary) -> bool:
	return not pet.is_empty() and float(pet.get("food", 0)) >= HAPPY_AT


func reset() -> void:
	my_pet = {}


func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


## Tokluğu zamana göre güncelle (kayıt üstünde).
func _tick(pet: Dictionary) -> void:
	var now := Time.get_unix_time_from_system()
	var lost := (now - float(pet.get("t", now))) / HUNGER_SEC
	pet["food"] = clampf(float(pet.get("food", 100)) - maxf(lost, 0.0), 0.0, 100.0)
	pet["t"] = now


## Sunucu: bu oyuncunun hayvanı mutlu ve bu türde mi? (bonuslar için)
func bonus(id: int, kind: String) -> bool:
	if _own_bonus(_rec(id), kind):
		return true
	# evliysen eşinin (çevrimiçi) mutlu hayvanı da sana bonus verir
	var s := Family.spouse_of(id)
	return s != "" and Net.id_by_name(s) != 0 and _own_bonus(Net.save_data.players.get(s, {}), kind)


func _own_bonus(rec: Dictionary, kind: String) -> bool:
	var pet = rec.get("pet")
	if not pet is Dictionary or pet.get("kind") != kind:
		return false
	_tick(pet)
	return is_happy(pet)


# ------------------------------------------------------------------ istemci API

func buy(kind: String, pet_name: String) -> void:
	Net.ask(self, "req_buy_pet", {"kind": kind, "name": pet_name})


func buy_food(n: int) -> void:
	Net.ask(self, "req_buy_food", {"n": n})


func feed(with_fish: bool) -> void:
	Net.ask(self, "req_feed", {"fish": with_fish})


func rename(pet_name: String) -> void:
	Net.ask(self, "req_rename", {"name": pet_name})


func release() -> void:
	Net.ask(self, "req_release")


@rpc("authority", "call_local", "reliable")
func on_pet(d: Dictionary) -> void:
	my_pet = d.get("pet", {})
	changed.emit()


# ------------------------------------------------------------------ sunucu

func send_state(id: int) -> void:
	var rec := _rec(id)
	var pet = rec.get("pet")
	var out := {}
	if pet is Dictionary:
		_tick(pet)
		out = {"kind": pet.kind, "name": pet.name, "food": float(pet.food), "cans": int(pet.get("cans", 0))}
	Net.tell(self, id, "on_pet", {"pet": out})
	_update_roster(id)


func _update_roster(id: int) -> void:
	var pet = _rec(id).get("pet")
	var info := {}
	if pet is Dictionary:
		info = {"kind": pet.kind, "name": pet.name, "happy": is_happy(pet)}
	if Net.players[id].get("pet", {}) != info:
		Net.players[id]["pet"] = info
		Net._broadcast_roster()


func _clean_name(s: String, fallback: String) -> String:
	var n := s.strip_edges().replace("[", "").replace("]", "").left(14)
	return n if n != "" else fallback


func _at_shop(id: int) -> bool:
	return Map.building("petshop").rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


@rpc("any_peer", "call_remote", "reliable")
func req_buy_pet(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var kind := str(d.get("kind", ""))
	if rec.is_empty() or not PETS.has(kind):
		return
	if not _at_shop(id):
		Net.notify(id, "Evcil hayvan almak için Pet Shop'a git.", false)
		return
	if rec.get("pet") is Dictionary:
		Net.notify(id, "Zaten bir evcil hayvanın var.", false)
		return
	var p: Dictionary = PETS[kind]
	if Rpg.level(id) < int(p.level):
		Net.notify(id, "%s için seviye %d gerekli." % [p.name, p.level], false)
		return
	if not Net.try_spend(id, int(p.price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	rec["pet"] = {"kind": kind, "name": _clean_name(str(d.get("name", "")), p.name), "food": 100.0,
		"t": Time.get_unix_time_from_system(), "cans": 2}
	Net.mark_dirty()
	Ach.event(id, "pet")
	send_state(id)
	Net.notify(id, "%s artık seninle! İki kutu mama hediye. (%s)" % [rec.pet.name, p.desc])
	Net.announce("%s bir %s sahiplendi: %s" % [Net.players[id].name, p.name.to_lower(), rec.pet.name])


@rpc("any_peer", "call_remote", "reliable")
func req_buy_food(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var pet = rec.get("pet")
	if not pet is Dictionary:
		return
	if not _at_shop(id):
		Net.notify(id, "Mama almak için Pet Shop'a git.", false)
		return
	var n := clampi(int(d.get("n", 1)), 1, MAX_CANS - int(pet.get("cans", 0)))
	if n <= 0:
		Net.notify(id, "Mama dolabın dolu.", false)
		return
	if not Net.try_spend(id, n * FOOD_PRICE):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	pet["cans"] = int(pet.get("cans", 0)) + n
	Net.mark_dirty()
	send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_feed(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var pet = rec.get("pet")
	if not pet is Dictionary:
		return
	_tick(pet)
	if float(pet.food) >= 95.0:
		Net.notify(id, "%s tok, şimdi yemek istemiyor." % pet.name, false)
		return
	if bool(d.get("fish", false)):
		if not PETS[pet.kind].fish:
			Net.notify(id, "Papağanlar balık yemez!", false)
			return
		var bag: Array = rec.get("fish", [])
		if bag.is_empty():
			Net.notify(id, "Kovanda balık yok.", false)
			return
		bag.pop_front()
		pet["food"] = minf(100.0, float(pet.food) + FOOD_PER_FISH)
		Jobs.send_inventory(id)
	else:
		if int(pet.get("cans", 0)) <= 0:
			Net.notify(id, "Mama kalmadı. Pet Shop'tan alabilirsin.", false)
			return
		pet["cans"] = int(pet.cans) - 1
		pet["food"] = minf(100.0, float(pet.food) + FOOD_PER_CAN)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "%s afiyetle yedi!" % pet.name)


@rpc("any_peer", "call_remote", "reliable")
func req_rename(d: Dictionary) -> void:
	var id := Net.sender()
	var pet = _rec(id).get("pet")
	if pet is Dictionary:
		pet["name"] = _clean_name(str(d.get("name", "")), pet.name)
		Net.mark_dirty()
		send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_release(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.get("pet") is Dictionary:
		var n: String = rec.pet.name
		rec.erase("pet")
		Net.mark_dirty()
		send_state(id)
		Net.notify(id, "%s yeni bir aileye sahiplendirildi." % n)


## Her dakika: çevrimiçi oyuncuların hayvan mutluluğunu güncelle (isim etiketi/görünüm için).
var _acc := 0.0


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 60.0:
		return
	_acc = 0.0
	for id in Net.players.keys():
		if _rec(id).get("pet") is Dictionary:
			send_state(id)
