extends Node
## Özel adalar (1.7). Okyanustaki bazı adalar satılıktır (iskelenin başında "SATILIK" tabelası).
##  Satın alınca adaya yapı kurulur: ev (kulübe → villa → malikâne), tropik bahçe, havuz, deniz feneri,
##  yakıt pompalı büyük iskele. Herkes adayı görür; sahibinin adı tabelada yazar.
##  Sahip ayrıcalıkları: evde dinlen (enerji dolar, 30 dk'da bir), bahçeden günlük hasat, adanın sandığı
##  sahibine 10 dk'da bir dolar ve ada kapalıysa başkası açamaz. Fener çevreyi haritada açar,
##  büyük iskelede yakıt alınır. Herkes en fazla bir ada sahibi olabilir; satınca %60'ı geri gelir.
## Veri: save_data["isles"] = {"ada no": {owner, b: {ev, bahce, havuz, fener, iskele}, open, spent, rest_t, harvest_day}}

signal changed

const OM = preload("res://scripts/ocean_map.gd")
const U = preload("res://scripts/util.gd")

const BUILD := {
	"ev": {"name": "Ev", "levels": ["Kulübe", "Villa", "Malikâne"], "own": ["kulübesi", "villası", "malikânesi"], "price": [8000, 20000, 45000], "desc": "Dinlen: enerji dolar (30 dk'da bir)"},
	"bahce": {"name": "Tropik Bahçe", "levels": ["Bahçe"], "price": [5000], "desc": "Her gün hasat (ev seviyesiyle artar)"},
	"havuz": {"name": "Havuz", "levels": ["Havuz"], "price": [9000], "desc": "Dinlenince +40 XP"},
	"fener": {"name": "Deniz Feneri", "levels": ["Fener"], "price": [6000], "desc": "Çevreyi haritada açar, uzaktan görünür"},
	"iskele": {"name": "Büyük İskele", "levels": ["İskele"], "price": [7000], "desc": "Yakıt pompası: adanda yakıt al"},
}
const REST_COOLDOWN := 1800.0
const OWNER_CHEST := 600.0
const SELL_BACK := 0.6

# --- istemci
var view := {}                       # "ada no" -> {owner, b, open}


func reset() -> void:
	view = {}


func on_player_left(_id: int) -> void:
	pass


## Satılık adalar: yakıt/fener/tersanesi olmayan, Batık Şehir olmayan adalar.
static func for_sale() -> Array:
	var out: Array = []
	for isl in OM.islands():
		if int(isl.id) > 0 and not isl.fuel and not isl.lighthouse and not isl.shipyard and isl.type != "batik" and float(isl.r) >= 230.0:
			out.append(int(isl.id))
	return out


static func price_of(isl: Dictionary) -> int:
	return 25000 + int(float(isl.r)) * 60 + int(isl.tier) * 5000


## Adadaki yapıların yerleri (hepsi karada; sandık ve iskeleden uzak).
static func spots(isl: Dictionary) -> Dictionary:
	var c: Vector2 = isl.c
	var r := float(isl.r)
	var sq := float(isl.sq)
	var d: Vector2 = Vector2(isl.chest) - c
	if d.length() < 1.0:
		d = Vector2.RIGHT
	d = d.normalized()
	var side := d.orthogonal()
	if side.dot(Vector2(isl.dock_dir)) > 0.0:
		side = -side                                        # ev iskelenin karşı yakasında
	var k := Vector2(r, r * sq)
	# dörde böl: sandık yönü (+d) fener, karşısı havuz; iskelenin karşı yakası ev, öbür yakası bahçe
	return {
		"sign": Vector2(isl.dock) - Vector2(isl.dock_dir) * 58.0,
		"house": c + side * k * 0.42,
		"pool": c - d * k * 0.36 + side * k * 0.08,
		"garden": c - side * k * 0.40,
		"light": c + d * k * 0.6 + side * k * 0.12,
		"pump": OM.pier_end(isl),
	}


func owner_of(i: int) -> String:
	return str(view.get(str(i), {}).get("owner", ""))


func my_island() -> int:
	for k in view:
		if str(view[k].owner) == Net.my_name:
			return int(k)
	return -1


# ------------------------------------------------------------------ istemci API

func buy(i: int) -> void:
	Net.ask(self, "req_buy", {"i": i})


func build(i: int, k: String) -> void:
	Net.ask(self, "req_build", {"i": i, "k": k})


func rest(i: int) -> void:
	Net.ask(self, "req_rest", {"i": i})


func harvest(i: int) -> void:
	Net.ask(self, "req_harvest", {"i": i})


func set_open(i: int, on: bool) -> void:
	Net.ask(self, "req_open", {"i": i, "on": on})


func sell(i: int) -> void:
	Net.ask(self, "req_sell", {"i": i})


@rpc("authority", "call_local", "reliable")
func on_view(d: Dictionary) -> void:
	view = d.get("v", {})
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _all() -> Dictionary:
	if not Net.save_data.get("isles") is Dictionary:
		Net.save_data["isles"] = {}
	return Net.save_data.isles


func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-9999, -9999))


func _view() -> Dictionary:
	var out := {}
	var a := _all()
	for k in a:
		out[k] = {"owner": a[k].owner, "b": a[k].b, "open": bool(a[k].get("open", true))}
	return out


func send_state(id: int) -> void:
	Net.tell(self, id, "on_view", {"v": _view()})


func _broadcast() -> void:
	Net.tell_all(self, "on_view", {"v": _view()})


func _near(id: int, i: int, what: String, r: float = 120.0) -> bool:
	var isl_list := OM.islands()
	if i < 0 or i >= isl_list.size():
		return false
	return _pos(id).distance_to(spots(isl_list[i])[what]) < r


func _mine(id: int, i: int) -> Dictionary:
	var e = _all().get(str(i))
	if e is Dictionary and Net.players.has(id) and str(e.owner) == Net.players[id].name:
		return e
	return {}


## Ada sandığı: sahibine 10 dk; kapalı adada başkasına kapalı. (Ocean.req_chest çağırır.)
## Döner: -1 yasak, yoksa bekleme süresi (sn).
func chest_rule(id: int, i: int) -> float:
	var e = _all().get(str(i))
	if not e is Dictionary:
		return -2.0
	if str(e.owner) == Net.players[id].name:
		return OWNER_CHEST
	return -1.0 if not bool(e.get("open", true)) else -2.0


func owns_any(player_name: String) -> int:
	var a := _all()
	for k in a:
		if str(a[k].owner) == player_name:
			return int(k)
	return -1


## Sahibin kendi iskelesinde yakıt pompası var mı? (Ocean yakıt için sorar)
func has_pump_near(p: Vector2) -> bool:
	var a := _all()
	var isl_list := OM.islands()
	for k in a:
		if int(a[k].b.get("iskele", 0)) > 0 and p.distance_to(spots(isl_list[int(k)]).pump) < 200.0:
			return true
	return false


@rpc("any_peer", "call_remote", "reliable")
func req_buy(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	if not Net.players.has(id) or not i in for_sale() or not _near(id, i, "sign"):
		return
	var me: String = Net.players[id].name
	if _all().has(str(i)):
		Net.notify(id, "Bu ada artık satılık değil.", false)
		return
	if owns_any(me) >= 0:
		Net.notify(id, "Zaten bir adan var. Yenisini almak için önce onu sat.", false)
		return
	var isl: Dictionary = OM.islands()[i]
	var price := price_of(isl)
	if not Net.try_spend(id, price):
		Net.notify(id, "%s %s." % [isl.name, U.money(price)], false)
		return
	_all()[str(i)] = {"owner": me, "b": {"ev": 0, "bahce": 0, "havuz": 0, "fener": 0, "iskele": 0}, "open": true,
		"spent": price, "rest_t": 0.0, "harvest_day": ""}
	Ach.event(id, "island")
	Net.mark_dirty()
	_broadcast()
	Net.announce("%s, okyanusta %s'nı satın aldı!" % [me, isl.name])


@rpc("any_peer", "call_remote", "reliable")
func req_build(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	var k := str(d.get("k", ""))
	var e := _mine(id, i)
	if e.is_empty() or not BUILD.has(k) or not _near(id, i, "sign", 260.0) and not _near(id, i, "house", 260.0):
		return
	var lvl := int(e.b.get(k, 0))
	var prices: Array = BUILD[k].price
	if lvl >= prices.size():
		return
	if k != "ev" and int(e.b.ev) < 1:
		Net.notify(id, "Önce bir ev (kulübe) kur.", false)
		return
	var price: int = prices[lvl]
	if not Net.try_spend(id, price):
		Net.notify(id, "%s %s." % [BUILD[k].levels[lvl], U.money(price)], false)
		return
	e.b[k] = lvl + 1
	e["spent"] = int(e.get("spent", 0)) + price
	if k == "fener":
		_reveal(id, i)
	var built := 0
	for bk in e.b:
		built += int(e.b[bk])
	Ach.set_max(id, "island_build", built)
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "%s kuruldu!" % BUILD[k].levels[lvl])


func _reveal(id: int, i: int) -> void:
	var rec: Dictionary = Net.save_data.players.get(Net.players[id].name, {})
	var o: Dictionary = Ocean._data(rec)
	var b := Marshalls.base64_to_raw(str(o.seen))
	if b.size() != OM.COLS * OM.ROWS:
		b.resize(OM.COLS * OM.ROWS)
	for c in OM.cells_around(OM.islands()[i].c, 2600.0):
		b[c] = 1
	o["seen"] = Marshalls.raw_to_base64(b)
	Ocean._check_found(id, o, b)
	Ocean.send_state(id)


@rpc("any_peer", "call_remote", "reliable")
func req_rest(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	var e := _mine(id, i)
	if e.is_empty() or int(e.b.ev) < 1 or not _near(id, i, "house", 140.0):
		return
	var now := Time.get_unix_time_from_system()
	var left := REST_COOLDOWN - (now - float(e.get("rest_t", 0.0)))
	if left > 0.0:
		Net.notify(id, "Az önce dinlendin; %d dk sonra yine." % int(ceil(left / 60.0)), false)
		return
	e["rest_t"] = now
	Rpg.add_energy(id, 999.0)
	if int(e.b.havuz) > 0:
		Rpg.add_xp(id, "", 40)
	Net.mark_dirty()
	Net.notify(id, "Adanda güzelce dinlendin. Enerjin doldu!%s" % (" Havuzda yüzdün (+40 XP)." if int(e.b.havuz) > 0 else ""))


@rpc("any_peer", "call_remote", "reliable")
func req_harvest(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	var e := _mine(id, i)
	if e.is_empty() or int(e.b.bahce) < 1 or not _near(id, i, "garden", 160.0):
		return
	var today := Time.get_date_string_from_system()
	if str(e.get("harvest_day", "")) == today:
		Net.notify(id, "Bahçeni bugün topladın; yarın yine gel.", false)
		return
	e["harvest_day"] = today
	var money := 400 + 300 * int(e.b.ev)
	Net.add_money(id, money)
	Net.mark_dirty()
	Net.notify(id, "Bahçeden muz, ananas ve hindistan cevizi topladın: %s" % U.money(money))


@rpc("any_peer", "call_remote", "reliable")
func req_open(d: Dictionary) -> void:
	var id := Net.sender()
	var e := _mine(id, int(d.get("i", -1)))
	if e.is_empty():
		return
	e["open"] = bool(d.get("on", true))
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "Adan artık %s." % ("herkese açık" if e.open else "özel: sandığını sadece sen açarsın"))


@rpc("any_peer", "call_remote", "reliable")
func req_sell(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("i", -1))
	var e := _mine(id, i)
	if e.is_empty() or not _near(id, i, "sign", 260.0) and not _near(id, i, "house", 260.0):
		return
	var back := int(float(e.get("spent", 0)) * SELL_BACK)
	_all().erase(str(i))
	Net.add_money(id, back)
	Net.mark_dirty()
	_broadcast()
	Net.notify(id, "%s satıldı: %s geri aldın." % [OM.islands()[i].name, U.money(back)])
