extends Node
## İşler: balık tutma, hastane (acil servis doktoru) ve market kasiyerliği.
## Sorular ve doğru cevaplar sunucuda tutulur; istemci sadece cevabını gönderir.

signal fish_event(d: Dictionary)
signal hospital_case(d: Dictionary)
signal market_case(d: Dictionary)
signal job_result(d: Dictionary)
signal inventory_changed

const U = preload("res://scripts/util.gd")
const Map = preload("res://scripts/map.gd")

const BAG_SIZE := 20
const BITE_WINDOW := 2.4      # sunucu toleransı (gecikme payı dahil)
const HOSPITAL_TIME := 12.0
const MARKET_TIME := 25.0

# [ad, ağırlık, en düşük fiyat, en yüksek fiyat]
const LAKE_FISH := [
	["Eski Ayakkabı", 8.0, 1, 3],
	["Yosun", 6.0, 1, 2],
	["Kızılkanat", 26.0, 8, 15],
	["Sazan", 22.0, 15, 28],
	["Alabalık", 14.0, 25, 45],
	["Turna", 8.0, 60, 110],
	["Yayın Balığı", 3.0, 180, 300],
	["Altın Balık", 0.4, 1500, 3000],
]
const SEA_FISH := [
	["Plastik Şişe", 8.0, 1, 2],
	["Deniz Yosunu", 4.0, 1, 3],
	["İstavrit", 20.0, 15, 28],
	["Hamsi", 18.0, 10, 20],
	["Palamut", 14.0, 40, 70],
	["Levrek", 8.0, 50, 90],
	["Lüfer", 10.0, 110, 180],
	["Kalkan", 5.0, 220, 350],
	["Orkinos", 2.5, 500, 900],
	["Kılıç Balığı", 1.2, 900, 1500],
	["Köpekbalığı", 0.4, 2000, 4000],
	["Hazine Sandığı", 0.15, 4000, 8000],
]
const SPOT_NAMES := {"lake": "Göl", "sea": "Deniz", "boat": "Açık Deniz", "island": "Martı Adası"}

# [belirti, doğru tedavi]
const CASES := [
	["Yüksek ateş, öksürük ve halsizlik", "Antibiyotik + ateş düşürücü"],
	["Düşme sonrası kolda şişlik ve şekil bozukluğu", "Röntgen + alçı"],
	["Bıçakla elde derin kesik", "Dikiş atmak"],
	["Arı sokması sonrası yüzde şişlik", "Antihistaminik iğne"],
	["Göğüste baskı tarzı ağrı, sol kola yayılıyor", "EKG + acil kardiyoloji"],
	["Uzun süre güneşte kalmış, baş dönmesi ve kusma", "Serum (sıvı takviyesi)"],
	["Şiddetli baş ağrısı ve ışığa hassasiyet", "Ağrı kesici + karanlık oda"],
	["Maçta ayak bileği burkuldu", "Buz + elastik bandaj"],
	["Sıcak çay döküldü, elde kızarıklık ve su toplama", "Yanık pansumanı"],
	["Bozuk tavuk yemiş, karın ağrısı ve ishal", "Sıvı tedavisi + diyet"],
	["Gözde kızarıklık ve çapaklanma", "Antibiyotikli göz damlası"],
	["Astım hastası, nefes darlığı ve hırıltı", "Nefes açıcı (inhaler)"],
	["Şeker hastası; titreme, terleme (şekeri düşmüş)", "Şekerli gıda / glukoz"],
	["Çocukta kulak ağrısı ve ateş", "Kulak muayenesi + antibiyotik"],
	["Burun kanaması durmuyor", "Burnu sıkıp öne eğilmek + tampon"],
	["Kedi tırmaladı, yara kirli", "Yara temizliği + tetanoz aşısı"],
]
const PATIENTS := ["Ayşe Hanım", "Mehmet Bey", "Küçük Efe", "Fatma Teyze", "Hasan Amca",
	"Zehra", "Burak", "Selin", "Kemal Bey", "Deniz", "Elif", "Murat"]

# [ürün, birim fiyat]
const ITEMS := [
	["Ekmek", 10], ["Süt", 35], ["Yumurta (10'lu)", 65], ["Peynir", 120], ["Çay", 90],
	["Elma (kg)", 30], ["Su", 8], ["Makarna", 25], ["Domates (kg)", 40], ["Çikolata", 45],
	["Zeytin", 110], ["Deterjan", 150], ["Simit", 15], ["Ayran", 12], ["Pirinç", 55],
]
const NOTES := [20, 50, 100, 200, 500, 1000]

var _fish := {}   # sunucu: id -> {bite_at, bitten, bite_time}
var _hosp := {}   # sunucu: id -> {correct, correct_text, deadline}
var _mkt := {}    # sunucu: id -> {change, deadline}
var my_fish: Array = []


func reset() -> void:
	_fish.clear()
	_hosp.clear()
	_mkt.clear()
	my_fish = []


## Olta animasyonu için balık tutma durumu oyuncu listesinde herkese yayınlanır:
## "cast" (şamandıra suda), "bite" (vurdu), "caught" / "escaped" (1,6 sn sonra temizlenir) ya da "".
func _set_fishing(id: int, s: String) -> void:
	if not Net.players.has(id) or str(Net.players[id].get("fishing", "")) == s:
		return
	Net.players[id]["fishing"] = s
	Net._broadcast_roster()
	if s == "caught" or s == "escaped":
		get_tree().create_timer(1.6).timeout.connect(func():
			if Net.players.has(id) and str(Net.players[id].get("fishing", "")) == s:
				_set_fishing(id, ""))


func on_player_left(id: int) -> void:
	_fish.erase(id)
	_hosp.erase(id)
	_mkt.erase(id)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _player() -> int:
	if not multiplayer.is_server():
		return 0
	var id := Net.sender()
	if not Net.players.has(id):
		return 0
	if Police.is_jailed(id):
		Net.notify(id, "Hapisteyken çalışamazsın.", false)
		return 0
	return id


# ================================================================== istemci API

func cast() -> void:
	Net.ask(self, "req_cast")


func reel() -> void:
	Net.ask(self, "req_reel")


func sell_fish() -> void:
	Net.ask(self, "req_sell_fish")


func ask_hospital() -> void:
	Net.ask(self, "req_hospital")


func answer_hospital(choice: int) -> void:
	Net.ask(self, "req_hospital_answer", {"choice": choice})


func ask_market() -> void:
	Net.ask(self, "req_market")


func answer_market(change: int) -> void:
	Net.ask(self, "req_market_answer", {"change": change})


@rpc("authority", "call_local", "reliable")
func on_fish(d: Dictionary) -> void:
	fish_event.emit(d)


@rpc("authority", "call_local", "reliable")
func on_inventory(d: Dictionary) -> void:
	my_fish = d.get("fish", [])
	inventory_changed.emit()


@rpc("authority", "call_local", "reliable")
func on_hospital_case(d: Dictionary) -> void:
	hospital_case.emit(d)


@rpc("authority", "call_local", "reliable")
func on_market_case(d: Dictionary) -> void:
	market_case.emit(d)


@rpc("authority", "call_local", "reliable")
func on_result(d: Dictionary) -> void:
	job_result.emit(d)


# ================================================================== balık

func _bag(id: int) -> Array:
	return Net.save_data.players[Net.players[id].name]["fish"]


func send_inventory(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_inventory", {"fish": _bag(id)})


@rpc("any_peer", "call_remote", "reliable")
func req_cast(_d: Dictionary) -> void:
	var id := _player()
	if id == 0 or _fish.has(id):
		return
	var pos: Vector2 = Net.positions.get(id, Vector2(-1000, -1000))
	var spot := Map.fishing_spot(pos)
	var deep := false
	if spot == "" and str(Net.players[id].get("ride", "")) == "boat" and Map.in_sea(pos):
		spot = "boat"     # teknede açık deniz: deniz balıkları, nadir şansı daha yüksek
		deep = Map.in_deep(pos)   # derin denizde daha da yüksek
	if spot != "lake" and spot != "" and Env.weather == "storm":
		Net.notify(id, "Fırtına var! Denizde balık tutmak tehlikeli, gölde dene.", false)
		return
	if spot == "":
		Net.notify(id, "Balık tutmak için bir iskelenin ucuna git.", false)
		return
	if spot != "lake" and Rpg.level(id) < Rpg.LEVEL_GATES.sea:
		Net.notify(id, "Deniz balıkçılığı için seviye %d gerekli." % Rpg.LEVEL_GATES.sea, false)
		return
	if _bag(id).size() >= BAG_SIZE:
		Net.notify(id, "Kovan dolu! Önce balıkları sat.", false)
		return
	if not Rpg.use_energy(id, 2):
		return
	var wait := randf_range(2.0, 5.0) if Env.is_rainy() else randf_range(3.0, 8.0)
	_fish[id] = {"bite_at": _now() + wait, "bitten": false, "bite_time": 0.0, "spot": spot,
		"window": BITE_WINDOW + Rpg.perk(id, "fish_window"), "deep": deep}
	_set_fishing(id, "cast")
	Net.tell(self, id, "on_fish", {"state": "cast", "spot": spot})


@rpc("any_peer", "call_remote", "reliable")
func req_reel(_d: Dictionary) -> void:
	var id := _player()
	if id == 0 or not _fish.has(id):
		return
	var t: Dictionary = _fish[id]
	_fish.erase(id)
	if not t.bitten:
		Net.tell(self, id, "on_fish", {"state": "early"})
		_set_fishing(id, "")
		return
	var rare: float = Rpg.perk(id, "fish_rare") * {"boat": 1.3, "island": 1.6}.get(t.spot, 1.0) * (1.25 if t.get("deep", false) else 1.0) * (1.15 if Pets.bonus(id, "dog") else 1.0)
	var f := _roll_fish(LAKE_FISH if t.spot == "lake" else SEA_FISH, rare)
	_bag(id).append({"name": f[0], "price": f[1]})
	_set_fishing(id, "caught")
	Net.mark_dirty()
	Net.tell(self, id, "on_fish", {"state": "caught", "fish": f[0], "price": f[1], "spot": t.spot})
	send_inventory(id)
	Rpg.add_xp(id, "fishing", 5 + mini(int(f[1]) / 10, 200))
	Rpg.quest_event(id, "fish")
	Story.event(id, "fish", {"fish": f[0]})
	Events.on_fish(id, f[0], int(f[1]))
	Bank.activity("BALK", 1)
	match f[0]:
		"Altın Balık":
			Ach.event(id, "goldfish")
		"Köpekbalığı":
			Ach.event(id, "shark")
		"Hazine Sandığı":
			Ach.event(id, "chest")
	if f[1] >= 500:
		Net.announce("%s bir %s yakaladı! (%s)" % [Net.players[id].name, f[0], U.money(f[1])])


## rare: >1 ise değerli balıkların (≥100 TL) şansı artar, çöplerinki azalır.
func _roll_fish(table: Array, rare: float = 1.0) -> Array:
	var weights: Array = []
	var total := 0.0
	for f in table:
		var w: float = f[1]
		if Env.is_night() and Env.NIGHT_FISH.has(f[0]):
			w *= 2.0      # gece balıkları
		if f[3] >= 100:
			w *= rare * (1.2 if Env.weather == "rainbow" else 1.0)
		elif f[3] <= 3:
			w /= rare
		weights.append(w)
		total += w
	var r := randf() * total
	for i in table.size():
		var f: Array = table[i]
		r -= weights[i]
		if r <= 0.0:
			return [f[0], randi_range(f[2], f[3])]
	return [table[2][0], table[2][2]]


@rpc("any_peer", "call_remote", "reliable")
func req_sell_fish(_d: Dictionary) -> void:
	var id := _player()
	if id == 0:
		return
	var bag := _bag(id)
	if bag.is_empty():
		Net.notify(id, "Satacak balığın yok.", false)
		return
	var sum := 0
	for f in bag:
		sum += int(f.price)
	var count := bag.size()
	bag.clear()
	Net.add_money(id, sum)
	Net.notify(id, "%d balık satıldı: +%s" % [count, U.money(sum)])
	send_inventory(id)


func _process(_delta: float) -> void:
	if not Net.is_server():
		return
	var now := _now()
	for id in _fish.keys():
		var t: Dictionary = _fish[id]
		if not t.bitten and now >= t.bite_at:
			t.bitten = true
			t.bite_time = now
			Net.tell(self, id, "on_fish", {"state": "bite"})
			_set_fishing(id, "bite")
		elif t.bitten and now > t.bite_time + float(t.get("window", BITE_WINDOW)):
			_fish.erase(id)
			Net.tell(self, id, "on_fish", {"state": "escaped"})
			_set_fishing(id, "escaped")


# ================================================================== hastane

@rpc("any_peer", "call_remote", "reliable")
func req_hospital(_d: Dictionary) -> void:
	var id := _player()
	if id == 0:
		return
	if not Rpg.use_energy(id, 3):
		Net.tell(self, id, "on_result", {"job": "hospital", "ok": false, "pay": 0, "stop": true,
			"text": "Çok yorgunsun. Bir şeyler ye ya da plajda dinlen."})
		return
	var c: Array = CASES.pick_random()
	var opts: Array = [c[1]]
	while opts.size() < 4:
		var o: String = CASES.pick_random()[1]
		if not opts.has(o):
			opts.append(o)
	opts.shuffle()
	var limit := HOSPITAL_TIME + Rpg.perk(id, "medicine_time")
	_hosp[id] = {"correct": opts.find(c[1]), "correct_text": c[1], "deadline": _now() + limit}
	Net.tell(self, id, "on_hospital_case", {"patient": PATIENTS.pick_random(), "symptom": c[0],
		"options": opts, "time": limit})


@rpc("any_peer", "call_remote", "reliable")
func req_hospital_answer(d: Dictionary) -> void:
	var id := _player()
	if id == 0 or not _hosp.has(id):
		return
	var t: Dictionary = _hosp[id]
	_hosp.erase(id)
	var left: float = t.deadline - _now()
	var choice := int(d.get("choice", -1))
	var res := {"job": "hospital", "ok": false, "pay": 0}
	if choice < 0 or left < -0.5:
		res["text"] = "Süre doldu, hasta başka doktora gitti."
	elif choice == t.correct:
		res["ok"] = true
		res["pay"] = int((25 + maxf(left, 0.0) * 2.0) * Rpg.perk(id, "medicine_pay") * (1.2 if Env.is_night() else 1.0) * (1.1 if Pets.bonus(id, "parrot") else 1.0)
			* Events.pay_mult() * Clans.pay_mult(id))
		res["text"] = "Doğru tedavi! Hasta iyileşti. +%s" % U.money(res.pay)
		Rpg.add_xp(id, "medicine", 10)
		Rpg.quest_event(id, "patient")
		Story.event(id, "patient")
	else:
		res["pay"] = -15
		res["text"] = "Yanlış tedavi! Doğrusu: %s. Ceza: %s" % [t.correct_text, U.money(15)]
	if res.pay != 0:
		Net.add_money(id, res.pay)
	Net.tell(self, id, "on_result", res)


# ================================================================== market

@rpc("any_peer", "call_remote", "reliable")
func req_market(_d: Dictionary) -> void:
	var id := _player()
	if id == 0:
		return
	if not Rpg.use_energy(id, 3):
		Net.tell(self, id, "on_result", {"job": "market", "ok": false, "pay": 0, "stop": true,
			"text": "Çok yorgunsun. Bir şeyler ye ya da plajda dinlen."})
		return
	var pool: Array = ITEMS.duplicate()
	pool.shuffle()
	var items: Array = []
	var total := 0
	for k in randi_range(2, 4):
		var qty := randi_range(1, 3)
		items.append({"name": pool[k][0], "qty": qty, "price": pool[k][1]})
		total += qty * int(pool[k][1])
	var paid: int = NOTES[-1] * int(ceil(total / float(NOTES[-1])))
	for i in NOTES.size():
		if NOTES[i] >= total:
			paid = NOTES[i]
			if randf() < 0.3 and i + 1 < NOTES.size():
				paid = NOTES[i + 1]
			break
	var limit := MARKET_TIME + Rpg.perk(id, "cashier_time")
	_mkt[id] = {"change": paid - total, "deadline": _now() + limit}
	Net.tell(self, id, "on_market_case", {"items": items, "paid": paid, "time": limit})


@rpc("any_peer", "call_remote", "reliable")
func req_market_answer(d: Dictionary) -> void:
	var id := _player()
	if id == 0 or not _mkt.has(id):
		return
	var t: Dictionary = _mkt[id]
	_mkt.erase(id)
	var left: float = t.deadline - _now()
	var change := int(d.get("change", -1))
	var res := {"job": "market", "ok": false, "pay": 0}
	if change < 0 or left < -0.5:
		res["text"] = "Müşteri beklemekten sıkılıp gitti."
	elif change == t.change:
		res["ok"] = true
		res["pay"] = int((50 + maxf(left, 0.0) * 3.0) * Rpg.perk(id, "cashier_pay") * (1.2 if Env.is_night() else 1.0) * (1.1 if Pets.bonus(id, "parrot") else 1.0)
			* Events.pay_mult() * Clans.pay_mult(id))
		res["text"] = "Doğru para üstü! +%s" % U.money(res.pay)
		Rpg.add_xp(id, "cashier", 12)
		Rpg.quest_event(id, "customer")
		Story.event(id, "customer")
		Bank.activity("MRKT", 1)
	else:
		res["pay"] = -20
		res["text"] = "Yanlış! Doğru para üstü %s idi. Kasa açığı: %s" % [U.money(t.change), U.money(20)]
	if res.pay != 0:
		Net.add_money(id, res.pay)
	Net.tell(self, id, "on_result", res)
