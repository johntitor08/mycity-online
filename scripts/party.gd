extends Node
## Ev ziyaretleri ve partiler.
##  Parti: ev sahibi evinin içindeyken başlatır (ikram masrafı). 10 dakika kapı herkese açık, şehre duyurulur;
##  partideki misafirler XP ve enerji kazanır, ev sahibi her misafir için XP alır. Odada disko ışıkları.
##  Misafir defteri: misafirler not bırakır (son 20 not). Puan: misafirler evi 1-5 yıldızla puanlar (günde bir).
##  Dekor puanı: yerleşik mobilya sayısı ve çeşitliliği. "En Güzel Ev" yarışması (Events) bu ikisini kullanır.
## Veri: plots[i]["party_until"], ["guestbook"] = [{n, t, d}], ["rating"] = {sum, n, by: {ad: tarih}}

signal changed

const U = preload("res://scripts/util.gd")
const Map = preload("res://scripts/map.gd")

const COST := 300
const DURATION := 600.0
const TICK := 30.0
const GUEST_XP := 15
const HOST_XP := 10
const BOOK_SIZE := 20

var _acc := 0.0


static func decor_score(p: Dictionary) -> int:
	var furn: Array = p.get("furniture", [])
	var kinds := {}
	for f in furn:
		kinds[str(f.get("k", ""))] = true
	return mini(80, furn.size() * 3 + kinds.size() * 4 + int(p.get("level", 0)) * 5)


static func rating_of(p: Dictionary) -> float:
	var r: Dictionary = p.get("rating", {})
	return float(r.get("sum", 0)) / maxf(1.0, float(r.get("n", 0)))


static func is_party(p: Dictionary, now: float) -> bool:
	return float(p.get("party_until", 0.0)) > now


# ------------------------------------------------------------------ istemci API

func start_party(plot: int) -> void:
	Net.ask(self, "req_party", {"plot": plot})


func sign_book(plot: int, text: String) -> void:
	Net.ask(self, "req_sign", {"plot": plot, "text": text})


func rate(plot: int, stars: int) -> void:
	Net.ask(self, "req_rate", {"plot": plot, "stars": stars})


# ------------------------------------------------------------------ sunucu

func _inside(id: int, i: int) -> bool:
	return Map.interior_at(Net.positions.get(id, Vector2(-9999, -9999))) == i


func _plot(i: int) -> Dictionary:
	if i < 0 or i >= Land.plots.size():
		return {}
	var p: Dictionary = Land.plots[i]
	if int(p.level) < 1 or str(p.get("kind", "home")) != "home" or p.owner == "":
		return {}
	return p


@rpc("any_peer", "call_remote", "reliable")
func req_party(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _plot(i)
	if p.is_empty() or not Net.players.has(id) or p.owner != Net.players[id].name:
		return
	if not _inside(id, i):
		Net.notify(id, "Partiyi evinin içinden başlat.", false)
		return
	var now := Time.get_unix_time_from_system()
	if is_party(p, now):
		Net.notify(id, "Parti zaten sürüyor!", false)
		return
	if not Net.try_spend(id, COST):
		Net.notify(id, "Parti ikramları %s." % U.money(COST), false)
		return
	p["party_until"] = now + DURATION
	p["door_open"] = true
	Net.mark_dirty()
	Land._broadcast()
	Ach.event(id, "party")
	Net.announce("%s evinde PARTİ veriyor! Arsa #%d — kapı herkese açık, %d dakika sürecek." % [p.owner, i + 1, int(DURATION / 60.0)])


@rpc("any_peer", "call_remote", "reliable")
func req_sign(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _plot(i)
	if p.is_empty() or not Net.players.has(id) or not _inside(id, i):
		return
	var me: String = Net.players[id].name
	if me == p.owner:
		return
	var text := str(d.get("text", "")).strip_edges().replace("[", "").replace("]", "").left(80)
	if text == "":
		return
	if not p.get("guestbook") is Array:
		p["guestbook"] = []
	p.guestbook.append({"n": me, "t": text, "d": Time.get_date_string_from_system()})
	while p.guestbook.size() > BOOK_SIZE:
		p.guestbook.pop_front()
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "Misafir defterine yazdın.")
	var oid := Net.id_by_name(p.owner)
	if oid != 0:
		Net.notify(oid, "%s misafir defterine yazdı: \"%s\"" % [me, text])


@rpc("any_peer", "call_remote", "reliable")
func req_rate(d: Dictionary) -> void:
	var id := Net.sender()
	var i := int(d.get("plot", -1))
	var p := _plot(i)
	if p.is_empty() or not Net.players.has(id) or not _inside(id, i):
		return
	var me: String = Net.players[id].name
	if me == p.owner:
		Net.notify(id, "Kendi evini puanlayamazsın.", false)
		return
	var stars := clampi(int(d.get("stars", 0)), 1, 5)
	if not p.get("rating") is Dictionary:
		p["rating"] = {"sum": 0, "n": 0, "by": {}}
	var today := Time.get_date_string_from_system()
	if str(p.rating.by.get(me, "")) == today:
		Net.notify(id, "Bu evi bugün zaten puanladın.", false)
		return
	p.rating.by[me] = today
	p.rating["sum"] = int(p.rating.sum) + stars
	p.rating["n"] = int(p.rating.n) + 1
	Net.mark_dirty()
	Land._broadcast()
	Net.notify(id, "%s'in evine %d yıldız verdin." % [p.owner, stars])
	var oid := Net.id_by_name(p.owner)
	if oid != 0:
		Net.notify(oid, "%s evine %s verdi!" % [me, "★".repeat(stars)])
		Events.add_score(oid, "ev", stars * 5, "%d puan")


## "En Güzel Ev" yarışması başlarken ev sahiplerine dekor puanlarını yaz.
func seed_contest() -> void:
	for i in mini(Land.plots.size(), Map.PLOT_COUNT):
		var p := _plot(i)
		if p.is_empty():
			continue
		var oid := Net.id_by_name(p.owner)
		if oid != 0:
			Events.add_score(oid, "ev", decor_score(p) + int(round(rating_of(p) * 4)), "%d puan")


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < TICK:
		return
	_acc = 0.0
	var now := Time.get_unix_time_from_system()
	for i in mini(Land.plots.size(), Map.PLOT_COUNT):
		var p := _plot(i)
		if p.is_empty() or not is_party(p, now):
			continue
		var guests := 0
		for id in Net.players:
			if _inside(id, i) and Net.players[id].name != p.owner:
				guests += 1
				Rpg.add_xp(id, "", GUEST_XP)
				var r := Rpg._rec(id)
				Rpg._update_energy(r, Rpg.level_of(int(r.xp)))
				r["energy"] = minf(float(Rpg.max_energy(Rpg.level_of(int(r.xp)), r)), float(r.energy) + 4.0)
				Rpg.send_sheet(id)
		var oid := Net.id_by_name(p.owner)
		if oid != 0 and guests > 0:
			Rpg.add_xp(oid, "", HOST_XP * guests)
			Ach.set_max(oid, "party_guests", guests)
