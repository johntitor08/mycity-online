extends Node
## Şehir Müzesi (1.2, Sanayi bölgesinde). Herkesin ortak müzesi: balıklar, deniz hazineleri, fosiller,
## mineraller ve çiftlik ürünleri koleksiyonları. Bir parçayı müzeye ilk bağışlayan ödül alır ve adı
## vitrine yazılır. Bir koleksiyon tamamlanınca şehre duyurulur, o koleksiyona katkı veren herkes ödül alır.
## Veri: save_data["museum"] = {anahtar: {"by": ad, "d": tarih}}   (anahtar: "fish:Sazan", "barn:elmas")

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const JobsS = preload("res://scripts/jobs.gd")
const FarmS = preload("res://scripts/farm.gd")
const MountainS = preload("res://scripts/mountain.gd")
const CampS = preload("res://scripts/camp.gd")

const DONATE_MONEY := 200
const DONATE_XP := 30
const SET_REWARD := 1500
const JUNK := ["Eski Ayakkabı", "Yosun", "Plastik Şişe", "Deniz Yosunu", "Hazine Sandığı"]

var view: Dictionary = {}          # istemci: müzedeki parçalar {anahtar: {by, d}}


## Koleksiyonlar: [kimlik, ad, [[anahtar, görünen ad], ...]]
static func sets() -> Array:
	var fish: Array = []
	for f in JobsS.LAKE_FISH + JobsS.SEA_FISH:
		if not str(f[0]) in JUNK:
			fish.append(["fish:" + str(f[0]), str(f[0])])
	var sea: Array = []
	for n in ["İnci", "Siyah İnci", "Batık Hazinesi", "Hazine Sandığı", "Korsan Altını", "Korsan Pusulası", "Korsan Yüzüğü"]:
		sea.append(["fish:" + n, n])
	var ocean: Array = []
	for n in ["Okyanus İncisi", "Kayalık Akiği", "Mangrov Kehribarı", "Volkan Taşı", "Buzul Kristali", "Antik Sikke", "Kraken Dişi"]:
		ocean.append(["fish:" + n, n])
	var fossils: Array = []
	var minerals: Array = []
	for k in MountainS.ORES:
		(fossils if MountainS.is_fossil(k) else minerals).append(["barn:" + k, MountainS.ORES[k].name])
	var farm: Array = []
	for k in FarmS.CROPS:
		farm.append(["barn:" + k, FarmS.CROPS[k].name])
	for k in FarmS.PRODUCTS:
		farm.append(["barn:" + k, FarmS.PRODUCTS[k].name])
	var forest: Array = []
	for k in CampS.FORAGE:
		if k != "odun":
			forest.append(["barn:" + k, CampS.FORAGE[k].name])
	return [["balik", "Balıklar", fish], ["deniz", "Deniz Hazineleri", sea], ["okyanus", "Okyanus", ocean], ["fosil", "Fosiller", fossils],
		["mineral", "Mineraller", minerals], ["orman", "Orman", forest], ["ciftlik", "Çiftlik Ürünleri", farm]]


static func all_keys() -> Array:
	var out: Array = []
	for s in sets():
		for it in s[2]:
			out.append(it[0])
	return out


func reset() -> void:
	view = {}


## İstemci: bu parça bende var mı? (balık kovası ya da ambar)
func i_have(key: String) -> bool:
	if key.begins_with("fish:"):
		var n := key.substr(5)
		for f in Jobs.my_fish:
			if str(f.get("name", "")) == n:
				return true
		return false
	return int(Farm.my_crops.get(key.substr(5), 0)) > 0


func progress() -> Vector2i:
	var keys := all_keys()
	var got := 0
	for k in keys:
		if view.has(k):
			got += 1
	return Vector2i(got, keys.size())


# ------------------------------------------------------------------ istemci API

func donate(key: String) -> void:
	Net.ask(self, "req_donate", {"key": key})


func refresh() -> void:
	Net.ask(self, "req_view")


@rpc("authority", "call_local", "reliable")
func on_view(d: Dictionary) -> void:
	view = d.get("items", {})
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _data() -> Dictionary:
	if not Net.save_data.get("museum") is Dictionary:
		Net.save_data["museum"] = {}
	return Net.save_data["museum"]


func send_state(id: int) -> void:
	if Net.players.has(id):
		Net.tell(self, id, "on_view", {"items": _data()})


@rpc("any_peer", "call_remote", "reliable")
func req_view(_d: Dictionary) -> void:
	send_state(Net.sender())


func _at_museum(id: int) -> bool:
	return Map.building("muze").rect.grow(70).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


@rpc("any_peer", "call_remote", "reliable")
func req_donate(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var key := str(d.get("key", ""))
	if not key in all_keys():
		return
	if not _at_museum(id):
		Net.notify(id, "Bağış için Müze'ye git (Sanayi bölgesi, feribotla).", false)
		return
	var m := _data()
	if m.has(key):
		Net.notify(id, "Bu parça müzede zaten var (%s bağışladı)." % m[key].by, false)
		return
	var me: String = Net.players[id].name
	var rec: Dictionary = Net.save_data.players[me]
	# eşyayı al
	var label := ""
	if key.begins_with("fish:"):
		var bag: Array = rec.get("fish", [])
		var n := key.substr(5)
		var idx := -1
		for i in bag.size():
			if str(bag[i].get("name", "")) == n:
				idx = i
				break
		if idx < 0:
			Net.notify(id, "Kovanda %s yok." % n, false)
			return
		bag.remove_at(idx)
		label = n
		Jobs.send_inventory(id)
	else:
		var k := key.substr(5)
		var store := Farm.barn(rec)
		if int(store.get(k, 0)) <= 0:
			Net.notify(id, "Ambarında bu parça yok.", false)
			return
		store[k] = int(store[k]) - 1
		if int(store[k]) <= 0:
			store.erase(k)
		label = str(Farm.item_info(k).get("name", k))
		Farm.send_state(id)
	m[key] = {"by": me, "d": Time.get_date_string_from_system()}
	Net.add_money(id, DONATE_MONEY)
	Rpg.add_xp(id, "", DONATE_XP)
	Ach.event(id, "donate")
	Net.notify(id, "%s müzeye bağışlandı! Adın vitrine yazıldı. +%s" % [label, U.money(DONATE_MONEY)])
	# koleksiyon tamamlandı mı?
	for s in sets():
		var keys: Array = []
		for it in s[2]:
			keys.append(it[0])
		if not key in keys:
			continue
		var done := true
		for k in keys:
			if not m.has(k):
				done = false
				break
		if done:
			_set_complete(s[1], keys)
	Net.mark_dirty()
	for pid in Net.players:
		send_state(pid)


func _set_complete(set_name: String, keys: Array) -> void:
	var donors := {}
	for k in keys:
		donors[str(_data()[k].by)] = true
	for n in donors:
		Net.add_money_by_name(n, SET_REWARD)
		var pid := Net.id_by_name(n)
		if pid != 0:
			Ach.event(pid, "museum_set")
			Net.notify(pid, "Müzede «%s» koleksiyonu tamamlandı! Katkın için +%s" % [set_name, U.money(SET_REWARD)])
	Net.announce("Müzede «%s» koleksiyonu tamamlandı! %d bağışçıya teşekkürler." % [set_name, donors.size()])
	Net.log_line("Müze koleksiyonu tamamlandı: %s" % set_name)
