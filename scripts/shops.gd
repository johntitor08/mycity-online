extends Node
## Çarşı: NPC dükkânları. Kuaför (özel saç renkleri), Aksesuarcı (şapka, gözlük, kolye/atkı/papyon),
## Kuyumcu (evlilik yüzüğü). Alınan eşyalar gardıropta durur (rec["wardrobe"]), karakter penceresinden giyilir.
## Sunucu, oyuncunun sahip olmadığı aksesuar/rengi görünümden siler (enforce).

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")

# kimlik -> {name, price, shop, slot, idx, desc}
const ITEMS := {
	"hc8": {"name": "Platin Saç Boyası", "price": 900, "shop": "kuafor", "slot": "hair_color", "idx": 8},
	"hc9": {"name": "Neon Mavi Saç Boyası", "price": 1200, "shop": "kuafor", "slot": "hair_color", "idx": 9},
	"hc10": {"name": "Nane Yeşili Saç Boyası", "price": 1200, "shop": "kuafor", "slot": "hair_color", "idx": 10},
	"hc11": {"name": "Ateş Kırmızısı Saç Boyası", "price": 1500, "shop": "kuafor", "slot": "hair_color", "idx": 11},
	"hc12": {"name": "Lacivert Saç Boyası", "price": 1000, "shop": "kuafor", "slot": "hair_color", "idx": 12},
	"hat1": {"name": "Kasket", "price": 600, "shop": "aksesuar", "slot": "hat", "idx": 1},
	"hat2": {"name": "Fötr Şapka", "price": 1800, "shop": "aksesuar", "slot": "hat", "idx": 2},
	"hat3": {"name": "Beyzbol Şapkası", "price": 500, "shop": "aksesuar", "slot": "hat", "idx": 3},
	"hat4": {"name": "Bere", "price": 400, "shop": "aksesuar", "slot": "hat", "idx": 4},
	"hat5": {"name": "Kovboy Şapkası", "price": 2500, "shop": "aksesuar", "slot": "hat", "idx": 5},
	"hat6": {"name": "Altın Taç", "price": 30000, "shop": "kuyumcu", "slot": "hat", "idx": 6, "level": 10},
	"gl1": {"name": "Güneş Gözlüğü", "price": 700, "shop": "aksesuar", "slot": "glasses", "idx": 1},
	"gl2": {"name": "Numaralı Gözlük", "price": 500, "shop": "aksesuar", "slot": "glasses", "idx": 2},
	"gl3": {"name": "Kalp Gözlük", "price": 900, "shop": "aksesuar", "slot": "glasses", "idx": 3},
	"nk1": {"name": "Altın Kolye", "price": 8000, "shop": "kuyumcu", "slot": "neck", "idx": 1},
	"nk2": {"name": "Kırmızı Atkı", "price": 450, "shop": "aksesuar", "slot": "neck", "idx": 2},
	"nk3": {"name": "Papyon", "price": 650, "shop": "aksesuar", "slot": "neck", "idx": 3},
	"ring": {"name": "Pırlanta Yüzük", "price": 3000, "shop": "kuyumcu", "desc": "Evlenme teklifi için gerekir (teklif kabul edilince harcanır)."},
}
const SHOP_NAMES := {"kuafor": "Kuaför", "aksesuar": "Aksesuarcı", "kuyumcu": "Kuyumcu"}
const MAX_RINGS := 3

var owned: Array = []      # istemci: gardırobum
var rings := 0


static func item_for(slot: String, idx: int) -> String:
	for k in ITEMS:
		if ITEMS[k].get("slot", "") == slot and int(ITEMS[k].get("idx", -1)) == idx:
			return k
	return ""


## Bu görünüm seçeneği (slot, indeks) bu gardırobla kullanılabilir mi?
static func allowed(slot: String, idx: int, wardrobe: Array) -> bool:
	if slot == "hair_color":
		return idx < Avatar.FREE_HAIR_COLORS or wardrobe.has(item_for(slot, idx))
	if slot in Avatar.ACCESSORY_SLOTS:
		return idx == 0 or wardrobe.has(item_for(slot, idx))
	return true


## Sunucu: sahip olunmayan seçenekleri sıfırla.
static func enforce(app: Dictionary, wardrobe: Array) -> Dictionary:
	for slot in ["hair_color"] + Avatar.ACCESSORY_SLOTS:
		if not allowed(slot, int(app.get(slot, 0)), wardrobe):
			app[slot] = 0
	return app


func reset() -> void:
	owned = []
	rings = 0


# ------------------------------------------------------------------ istemci API

func buy(item: String) -> void:
	Net.ask(self, "req_buy", {"item": item})


func my_allowed(slot: String, idx: int) -> bool:
	return allowed(slot, idx, owned)


@rpc("authority", "call_local", "reliable")
func on_wardrobe(d: Dictionary) -> void:
	owned = d.get("owned", [])
	rings = int(d.get("rings", 0))
	changed.emit()


# ------------------------------------------------------------------ sunucu

static func wardrobe(rec: Dictionary) -> Array:
	if not rec.get("wardrobe") is Array:
		rec["wardrobe"] = []
	return rec["wardrobe"]


func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


func send_state(id: int) -> void:
	var rec := _rec(id)
	if not rec.is_empty():
		Net.tell(self, id, "on_wardrobe", {"owned": wardrobe(rec).duplicate(), "rings": int(rec.get("rings", 0))})


func _at_bazaar(id: int) -> bool:
	return Map.at_building("carsi", Net.positions.get(id, Vector2(-9999, -9999)), 60)


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("item", ""))
	if rec.is_empty() or not ITEMS.has(k):
		return
	if not _at_bazaar(id):
		Net.notify(id, "Alışveriş için Çarşı'ya git.", false)
		return
	var it: Dictionary = ITEMS[k]
	if Rpg.level(id) < int(it.get("level", 0)):
		Net.notify(id, "%s için seviye %d gerekli." % [it.name, it.level], false)
		return
	if k == "ring":
		if int(rec.get("rings", 0)) >= MAX_RINGS:
			Net.notify(id, "Yeterince yüzüğün var.", false)
			return
	elif wardrobe(rec).has(k):
		Net.notify(id, "%s zaten gardırobunda." % it.name, false)
		return
	if not Net.try_spend(id, int(it.price)):
		Net.notify(id, "Yeterli paran yok.", false)
		return
	if k == "ring":
		rec["rings"] = int(rec.get("rings", 0)) + 1
		Net.notify(id, "Pırlanta yüzük alındı! Sevdiğin kişinin ismine tıklayıp evlenme teklif edebilirsin.")
	else:
		wardrobe(rec).append(k)
		Ach.set_max(id, "wardrobe", wardrobe(rec).size())
		Net.notify(id, "%s alındı! Karakter penceresinden giyebilirsin." % it.name)
		Bank.activity("MRKT", 2)
	Net.mark_dirty()
	send_state(id)


## Satın alıp hemen giy (dükkân penceresindeki "Giy" butonu): görünümü değiştir.
func wear(slot: String, idx: int) -> void:
	var app: Dictionary = Net.roster.get(Net.my_id(), {}).get("appearance", {}).duplicate()
	if app.is_empty():
		return
	app[slot] = idx
	Net.set_appearance(app)
