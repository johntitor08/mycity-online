extends Node
## Çiftlik: boş arsaya tarla kurulur (6 tarh). Tohum ek, sula, gübrele, hasat et.
## Ekinler gerçek zamanla büyür (sahip çevrimdışıyken de); mevsimi seven ekin hızlı, kışın çoğu yavaş büyür.
## Yağmur/kar tarlaları kendiliğinden sular, fırtına büyüyen ekinlere zarar verebilir.
## Olgunlaşan ekin uzun süre toplanmazsa çürür. Ürünler Pazar Yeri'ndeki Hal'de satılır,
## pazarda ilana konur ya da işletmeye malzeme olarak verilir.
## Veri: plots[i]["kind"] = "farm", plots[i]["farm"] = {"beds": [{c, t, g, w, f, dmg}, ...]}
##       rec["crops"] = {ekin: adet}

signal crops_changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const BUILD_COST := 1200
const LEVEL_GATE := 2
const BEDS := 6
const MAX_STACK := 99
const ROT_AFTER := 3.0          # olgunlaştıktan sonra büyüme süresinin 3 katı beklerse çürür
const FERTILIZER_PRICE := 25
const SEASON_FAST := 0.75       # mevsimini seven ekin
const WINTER_SLOW := 1.6        # kışa dayanıksız ekinler
const OUT_OF_SEASON_PRICE := 1.3

# grow: saniye (normal mevsimde), yield: [en az, en çok], price: Hal'deki birim fiyat
const CROPS := {
	"bugday": {"name": "Buğday", "seed": 5, "grow": 240, "yield": [4, 6], "price": 10, "season": "autumn", "level": 2, "color": "#eab308"},
	"domates": {"name": "Domates", "seed": 8, "grow": 300, "yield": [3, 5], "price": 18, "season": "summer", "level": 2, "color": "#ef4444"},
	"misir": {"name": "Mısır", "seed": 10, "grow": 480, "yield": [3, 5], "price": 28, "season": "summer", "level": 3, "color": "#facc15"},
	"lahana": {"name": "Lahana", "seed": 12, "grow": 540, "yield": [2, 4], "price": 42, "season": "winter", "level": 3, "color": "#84cc16"},
	"cilek": {"name": "Çilek", "seed": 15, "grow": 420, "yield": [4, 7], "price": 30, "season": "spring", "level": 4, "color": "#e11d48"},
	"kabak": {"name": "Balkabağı", "seed": 25, "grow": 900, "yield": [1, 3], "price": 130, "season": "autumn", "level": 5, "color": "#f97316"},
	"karpuz": {"name": "Karpuz", "seed": 40, "grow": 1200, "yield": [1, 2], "price": 280, "season": "summer", "level": 6, "color": "#16a34a"},
}

var my_crops: Dictionary = {}   # istemci: kendi ambarım


static func is_farm(p: Dictionary) -> bool:
	return str(p.get("kind", "home")) == "farm"


static func empty_bed() -> Dictionary:
	return {"c": "", "t": 0.0, "g": 0.0, "w": false, "f": false, "dmg": false}


static func default_data() -> Dictionary:
	var beds: Array = []
	for _i in BEDS:
		beds.append(empty_bed())
	return {"beds": beds}


## Büyüme süresi (mevsime göre).
static func grow_time(crop: String, season: String) -> float:
	var c: Dictionary = CROPS[crop]
	var g := float(c.grow)
	if c.season == season:
		g *= SEASON_FAST
	elif season == "winter":
		g *= WINTER_SLOW
	return g


## Tarhın durumu: "empty", "growing", "ready", "rotten"; ilerleme 0..1.
static func bed_state(b: Dictionary, now: float) -> Array:
	if str(b.get("c", "")) == "":
		return ["empty", 0.0]
	var g := maxf(1.0, float(b.g))
	var age := now - float(b.t)
	if age < g:
		return ["growing", clampf(age / g, 0.0, 1.0)]
	if age > g * (1.0 + ROT_AFTER):
		return ["rotten", 1.0]
	return ["ready", 1.0]


static func sell_price(crop: String, season: String) -> int:
	var c: Dictionary = CROPS[crop]
	return int(round(float(c.price) * (1.0 if c.season == season else OUT_OF_SEASON_PRICE)))


func _now() -> float:
	return Time.get_unix_time_from_system()


func reset() -> void:
	my_crops = {}


# ------------------------------------------------------------------ istemci API

func plant(plot: int, crop: String, bed: int = -1) -> void:
	Net.ask(self, "req_plant", {"plot": plot, "crop": crop, "bed": bed})


func water(plot: int) -> void:
	Net.ask(self, "req_water", {"plot": plot})


func fertilize(plot: int) -> void:
	Net.ask(self, "req_fertilize", {"plot": plot})


func harvest(plot: int) -> void:
	Net.ask(self, "req_harvest", {"plot": plot})


## Hal'de sat (crop "" ise hepsi).
func sell(crop: String = "") -> void:
	Net.ask(self, "req_sell", {"crop": crop})


@rpc("authority", "call_local", "reliable")
func on_crops(d: Dictionary) -> void:
	my_crops = d.get("crops", {})
	crops_changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


static func barn(rec: Dictionary) -> Dictionary:
	if not rec.get("crops") is Dictionary:
		rec["crops"] = {}
	return rec["crops"]


func send_state(id: int) -> void:
	var rec := _rec(id)
	if not rec.is_empty():
		Net.tell(self, id, "on_crops", {"crops": barn(rec).duplicate()})


func _owned(id: int, i: int) -> Dictionary:
	if not Net.players.has(id) or i < 0 or i >= Land.plots.size():
		return {}
	var p: Dictionary = Land.plots[i]
	if p.owner != Net.players[id].name or not is_farm(p):
		return {}
	return p


func _near(id: int, i: int) -> bool:
	return Map.plot_rect(i).grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


## Boş arsaya tarla kur (Land.req_build çağırır).
func build(id: int, i: int) -> void:
	var p: Dictionary = Land.plots[i]
	if int(p.level) > 0 or is_farm(p):
		Net.notify(id, "Tarla için boş arsa gerekir.", false)
		return
	if Rpg.level(id) < LEVEL_GATE:
		Net.notify(id, "Tarla için seviye %d gerekli." % LEVEL_GATE, false)
		return
	if not Net.try_spend(id, BUILD_COST):
		Net.notify(id, "Tarla için %s gerekli." % U.money(BUILD_COST), false)
		return
	p["kind"] = "farm"
	p.level = 1
	p["farm"] = default_data()
	Net.mark_dirty()
	Land._broadcast()
	Rpg.add_xp(id, "farming", 80)
	Rpg.quest_event(id, "build")
	Net.notify(id, "Tarla kuruldu! Tohum ek, sula ve hasadı bekle.")


@rpc("any_peer", "call_remote", "reliable")
func req_plant(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	var crop := str(d.get("crop", ""))
	if p.is_empty() or not CROPS.has(crop):
		return
	if not _near(id, i):
		Net.notify(id, "Ekim için tarlanın başında olmalısın.", false)
		return
	var c: Dictionary = CROPS[crop]
	if Rpg.level(id) < int(c.level):
		Net.notify(id, "%s için seviye %d gerekli." % [c.name, c.level], false)
		return
	var now := _now()
	var targets: Array = []
	var beds: Array = p.farm.beds
	var only := int(d.get("bed", -1))
	for k in beds.size():
		if (only < 0 or only == k) and bed_state(beds[k], now)[0] in ["empty", "rotten"]:
			targets.append(k)
	if targets.is_empty():
		Net.notify(id, "Boş tarh yok. Önce hasat et.", false)
		return
	var n := targets.size()
	while n > 0 and Net.get_money(id) < n * int(c.seed):
		n -= 1
	if n == 0 or not Net.try_spend(id, n * int(c.seed)):
		Net.notify(id, "Tohum için yeterli paran yok.", false)
		return
	var g := grow_time(crop, Env.season)
	for k in targets.slice(0, n):
		beds[k] = {"c": crop, "t": now, "g": g, "w": Env.is_rainy(), "f": false, "dmg": false}
	Net.mark_dirty()
	Land._broadcast()
	Rpg.add_xp(id, "farming", 2 * n)
	Net.notify(id, "%d tarha %s ekildi (%s). Hasat: %d dk sonra." % [n, c.name, U.money(n * int(c.seed)), int(ceil(g / 60.0))])


@rpc("any_peer", "call_remote", "reliable")
func req_water(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not _near(id, i):
		return
	var dry: Array = []
	var now := _now()
	for b in p.farm.beds:
		if bed_state(b, now)[0] == "growing" and not b.w:
			dry.append(b)
	if dry.is_empty():
		Net.notify(id, "Sulanacak tarh yok.", false)
		return
	if not Rpg.use_energy(id, 1):
		return
	for b in dry:
		b["w"] = true
	var n := dry.size()
	Net.mark_dirty()
	Land._broadcast()
	Rpg.add_xp(id, "farming", n)
	Net.notify(id, "%d tarh sulandı. Sulanan ekin tam verim verir." % n)


@rpc("any_peer", "call_remote", "reliable")
func req_fertilize(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not _near(id, i):
		return
	var targets: Array = []
	var now := _now()
	for b in p.farm.beds:
		if bed_state(b, now)[0] == "growing" and not b.f:
			targets.append(b)
	if targets.is_empty():
		Net.notify(id, "Gübrelenecek tarh yok.", false)
		return
	if not Net.try_spend(id, targets.size() * FERTILIZER_PRICE):
		Net.notify(id, "Gübre için %s gerekli." % U.money(targets.size() * FERTILIZER_PRICE), false)
		return
	for b in targets:
		b["f"] = true
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "%d tarh gübrelendi: her biri +1 ürün verecek." % targets.size())


## Bir tarhın ürününü hesapla (sulama, gübre, hasar, yetenek).
func _yield(id: int, b: Dictionary) -> int:
	var c: Dictionary = CROPS[b.c]
	var n := float(randi_range(int(c.yield[0]), int(c.yield[1])))
	if not b.w:
		n *= 0.5
	if b.dmg:
		n *= 0.5
	n *= Rpg.perk(id, "farm_yield")
	if b.f:
		n += 1.0
	return maxi(1, int(round(n)))


@rpc("any_peer", "call_remote", "reliable")
func req_harvest(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _owned(id, i)
	if p.is_empty() or not _near(id, i):
		return
	var rec := _rec(id)
	var store := barn(rec)
	var now := _now()
	var got := {}
	var rotten := 0
	var beds: Array = p.farm.beds
	for k in beds.size():
		var st: String = bed_state(beds[k], now)[0]
		if st == "rotten":
			rotten += 1
			beds[k] = empty_bed()
		elif st == "ready":
			var crop: String = beds[k].c
			var n := mini(_yield(id, beds[k]), MAX_STACK - int(store.get(crop, 0)))
			if n <= 0:
				continue      # ambar dolu: tarhta kalsın
			store[crop] = int(store.get(crop, 0)) + n
			got[crop] = int(got.get(crop, 0)) + n
			beds[k] = empty_bed()
	if got.is_empty() and rotten == 0:
		Net.notify(id, "Toplanacak olgun ürün yok.", false)
		return
	var parts: Array = []
	var total := 0
	for k in got:
		parts.append("%d %s" % [got[k], CROPS[k].name])
		total += int(got[k]) * int(CROPS[k].price)
	Net.mark_dirty()
	Land._broadcast()
	send_state(id)
	if not got.is_empty():
		Rpg.add_xp(id, "farming", 5 + mini(200, int(total / 8.0)))
		Rpg.quest_event(id, "harvest")
		Bank.activity("TARM", got.size() * 2)
		var n_crops := 0
		for kk in got:
			n_crops += int(got[kk])
		Events.add_score(id, "harvest", n_crops, "%d ürün")
		Net.notify(id, "Hasat: %s" % ", ".join(parts))
	if rotten > 0:
		Net.notify(id, "%d tarhtaki ekin çürümüştü, temizlendi." % rotten, false)


## Hırsızlık (Police): olgun bir tarhı hırsıza ver. Ürün adı ve adet döner ya da [].
func steal_bed(i: int, thief_rec: Dictionary) -> Array:
	var p: Dictionary = Land.plots[i]
	if not is_farm(p):
		return []
	var now := _now()
	for k in p.farm.beds.size():
		var b: Dictionary = p.farm.beds[k]
		if bed_state(b, now)[0] == "ready":
			var crop: String = b.c
			var c: Dictionary = CROPS[crop]
			var n := randi_range(int(c.yield[0]), int(c.yield[1]))
			var store := barn(thief_rec)
			store[crop] = mini(MAX_STACK, int(store.get(crop, 0)) + n)
			p.farm.beds[k] = empty_bed()
			Net.mark_dirty()
			Land._broadcast()
			return [crop, n]
	return []


@rpc("any_peer", "call_remote", "reliable")
func req_sell(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	if not Map.building("pazar").rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Ürün satmak için Pazar Yeri'ndeki Hal'e git.", false)
		return
	var store := barn(rec)
	var only := str(d.get("crop", ""))
	var sum := 0
	var count := 0
	for k in store.keys():
		if (only == "" or only == k) and CROPS.has(k):
			sum += int(round(int(store[k]) * sell_price(k, Env.season) * (1.5 if Events.is_active("harvest") else 1.0)))
			count += int(store[k])
			store.erase(k)
	if count == 0:
		Net.notify(id, "Satacak ürünün yok.", false)
		return
	Net.add_money(id, sum)
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Hal'de %d ürün satıldı: +%s" % [count, U.money(sum)])


## Yağmurda tarlalar kendiliğinden sulanır.
var _acc := 0.0


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 10.0:
		return
	_acc = 0.0
	if not Env.is_rainy():
		return
	var now := _now()
	var changed := false
	for p in Land.plots:
		if is_farm(p) and p.get("farm") is Dictionary:
			for b in p.farm.beds:
				if not b.w and bed_state(b, now)[0] == "growing":
					b["w"] = true
					changed = true
	if changed:
		Net.mark_dirty()
		Land._broadcast()


## Fırtına başlayınca büyüyen ekinlerin bir kısmı zarar görür (sulamadan bağımsız, ürün yarıya iner).
func on_storm() -> void:
	if not Net.is_server():
		return
	var now := _now()
	var hit := {}
	for p in Land.plots:
		if not is_farm(p) or not p.get("farm") is Dictionary:
			continue
		for b in p.farm.beds:
			if bed_state(b, now)[0] == "growing" and not b.dmg and randf() < 0.25:
				b["dmg"] = true
				hit[p.owner] = int(hit.get(p.owner, 0)) + 1
	for owner in hit:
		var oid := Net.id_by_name(owner)
		if oid != 0:
			Net.notify(oid, "Fırtına %d tarhına zarar verdi! (ürün yarıya düşecek)" % hit[owner], false)
	if not hit.is_empty():
		Net.mark_dirty()
		Land._broadcast()
