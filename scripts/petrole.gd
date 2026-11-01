extends Node
## 2.4: başka bir oyuncunun evcil hayvanı olma rolü (rol yapma). İki tarafın onayıyla başlar, iki taraf da
## istediği an bitirir; biri çıkınca kendiliğinden biter. Evcil hayvan seçtiği hayvan olarak çizilir, sesini
## çıkarır, sahibini takip edebilir; araç kullanamaz. Sahip onu sever ya da mama verir.
## Rol oyuncu listesinde görünür: Net.players[id]["petrole"] = {owner, kind, form}
## form: "hayvan" (hayvan olarak çizilir) ya da "insan" (karakter kalır; kedi/köpek kulağı ve kuyruğu takar)

signal asked(from_name: String, kind: String, form: String)
signal acted(d: Dictionary)          # {who, act} — ses, sev, mama

const KINDS := {"cat": "kedi", "dog": "köpek", "parrot": "papağan"}
const SOUNDS := {"cat": "Miyav!", "dog": "Hav hav!", "parrot": "Gaak!"}
const COSTUME_KINDS := ["cat", "dog"]          # insan şeklinde (kulak + kuyruk) olabilenler
const ASK_RANGE := 220.0
const ASK_TTL := 60.0
const FOOD_PRICE := 40
const FOOD_ENERGY := 15.0
const ACT_COOLDOWN := 1.5

var following := false              # istemci: evcil hayvan sahibini kendiliğinden takip ediyor mu
var _asks := {}                     # sunucu: sahip id -> {from, kind, t}
var _last_act := {}                 # sunucu: id -> zaman


func reset() -> void:
	following = false
	_asks.clear()
	_last_act.clear()


func on_player_left(id: int) -> void:
	_asks.erase(id)
	if not Net.players.has(id):
		return
	var pname: String = Net.players[id].name
	for pid in Net.players:
		var r = Net.players[pid].get("petrole")
		if r is Dictionary and not r.is_empty() and str(r.owner) == pname and pid != id:
			_end(pid, "%s oyundan çıktı; evcil hayvan rolü bitti." % pname)


# ------------------------------------------------------------------ istemci API

## Bu oyuncunun rolü (yoksa boş): {owner, kind}
static func role_of(info) -> Dictionary:
	if info is Dictionary:
		var r = info.get("petrole")
		if r is Dictionary:
			return r
	return {}


func my_role() -> Dictionary:
	return role_of(Net.roster.get(Net.my_id(), {}))


## Benim evcil hayvanlarımın adları.
func my_pets() -> Array:
	var out: Array = []
	for id in Net.roster:
		if str(role_of(Net.roster[id]).get("owner", "")) == Net.my_name:
			out.append(str(Net.roster[id].name))
	return out


func ask(owner_name: String, kind: String, form: String = "hayvan") -> void:
	Net.ask(self, "req_ask", {"to": owner_name, "kind": kind, "form": form})


func answer(yes: bool) -> void:
	Net.ask(self, "req_answer", {"yes": yes})


func stop(other: String = "") -> void:
	following = false
	Net.ask(self, "req_stop", {"other": other})


func act(what: String, target: String = "") -> void:
	Net.ask(self, "req_act", {"act": what, "to": target})


func status_line() -> String:
	var r := my_role()
	if r.is_empty():
		return ""
	return "Evcil hayvan (%s) · sahibin: %s · [%s] %s · [%s] takip: %s" % [str(KINDS.get(str(r.kind), "hayvan")), str(r.owner),
		Settings.key_name("action"), SOUNDS.get(str(r.kind), "ses"), Settings.key_name("vehicle"), "AÇIK" if following else "kapalı"]


@rpc("authority", "call_local", "reliable")
func on_ask(d: Dictionary) -> void:
	asked.emit(str(d.get("from", "")), str(d.get("kind", "")), str(d.get("form", "hayvan")))


@rpc("authority", "call_local", "reliable")
func on_act(d: Dictionary) -> void:
	acted.emit(d)


# ------------------------------------------------------------------ sunucu

func _pos(id: int) -> Vector2:
	return Net.positions.get(id, Vector2(-1e6, -1e6))


@rpc("any_peer", "call_remote", "reliable")
func req_ask(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var kind := str(d.get("kind", ""))
	var form := "insan" if str(d.get("form", "")) == "insan" else "hayvan"
	var to := str(d.get("to", ""))
	var oid := Net.id_by_name(to)
	if not KINDS.has(kind) or (form == "insan" and not kind in COSTUME_KINDS):
		return
	if oid == 0 or oid == id:
		Net.notify(id, "Çevrimiçi bir oyuncu seç.", false)
		return
	if not role_of(Net.players[id]).is_empty():
		Net.notify(id, "Zaten bir evcil hayvan rolündesin.", false)
		return
	if not role_of(Net.players[oid]).is_empty():
		Net.notify(id, "%s şu an kendisi bir evcil hayvan rolünde." % to, false)
		return
	if _pos(id).distance_to(_pos(oid)) > ASK_RANGE:
		Net.notify(id, "Önce yanına git (%s)." % to, false)
		return
	_asks[oid] = {"from": Net.players[id].name, "kind": kind, "form": form, "t": Time.get_unix_time_from_system()}
	Net.tell(self, oid, "on_ask", {"from": Net.players[id].name, "kind": kind, "form": form})
	Net.notify(id, "İsteğin gönderildi (%s), cevap bekleniyor..." % to)


@rpc("any_peer", "call_remote", "reliable")
func req_answer(d: Dictionary) -> void:
	var oid := Net.sender()
	if not _asks.has(oid) or not Net.players.has(oid):
		return
	var a: Dictionary = _asks[oid]
	_asks.erase(oid)
	var pid := Net.id_by_name(str(a.from))
	if pid == 0 or Time.get_unix_time_from_system() - float(a.t) > ASK_TTL:
		Net.notify(oid, "İsteğin süresi geçti.", false)
		return
	if not bool(d.get("yes", false)):
		Net.notify(pid, "%s isteğini kabul etmedi." % Net.players[oid].name, false)
		return
	if not role_of(Net.players[pid]).is_empty() or not role_of(Net.players[oid]).is_empty():
		return
	start(pid, Net.players[oid].name, str(a.kind), str(a.get("form", "hayvan")))


## Rolü başlat (sunucu; testler de doğrudan çağırır).
func start(pid: int, owner_name: String, kind: String, form: String = "hayvan") -> void:
	Garage.set_ride(pid, "")
	Net.players[pid]["petrole"] = {"owner": owner_name, "kind": kind, "form": form}
	Net._broadcast_roster()
	var oid := Net.id_by_name(owner_name)
	Net.notify(pid, "Evcil hayvan rolündesin (%s) — sahibin: %s. G ile ses çıkar, F ile takip et. Rolü istediğin an bitirebilirsin." % [KINDS[kind], owner_name])
	Net.notify(oid, "%s artık senin evcil hayvanın (%s)! Adına tıklayıp sevebilir ya da mama verebilirsin." % [Net.players[pid].name, KINDS[kind]])


func _end(pid: int, msg: String) -> void:
	if not Net.players.has(pid):
		return
	Net.players[pid]["petrole"] = {}
	Net._broadcast_roster()
	Net.notify(pid, msg)


@rpc("any_peer", "call_remote", "reliable")
func req_stop(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var me: String = Net.players[id].name
	var mine := role_of(Net.players[id])
	if not mine.is_empty():
		var oid := Net.id_by_name(str(mine.owner))
		_end(id, "Evcil hayvan rolünü bitirdin.")
		if oid != 0:
			Net.notify(oid, "%s evcil hayvan rolünü bitirdi." % me)
		return
	# sahip: belirli birini ya da hepsini bırak
	var other := str(d.get("other", ""))
	for pid in Net.players.keys():
		var r := role_of(Net.players[pid])
		if str(r.get("owner", "")) == me and (other == "" or Net.players[pid].name == other):
			_end(pid, "%s evcil hayvan rolünü bitirdi." % me)
			Net.notify(id, "%s artık senin evcil hayvanın değil." % Net.players[pid].name)


@rpc("any_peer", "call_remote", "reliable")
func req_act(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_act.get(id, -99.0)) < ACT_COOLDOWN:
		return
	var what := str(d.get("act", ""))
	var me: String = Net.players[id].name
	match what:
		"ses":
			var r := role_of(Net.players[id])
			if r.is_empty():
				return
			_last_act[id] = now
			Net.tell_all(self, "on_act", {"who": me, "act": "ses", "text": SOUNDS.get(str(r.kind), "!"), "p": _pos(id)})
		"sev", "mama":
			var pid := Net.id_by_name(str(d.get("to", "")))
			if pid == 0 or str(role_of(Net.players[pid]).get("owner", "")) != me:
				return
			if _pos(id).distance_to(_pos(pid)) > ASK_RANGE:
				Net.notify(id, "Evcil hayvanının yanına git.", false)
				return
			if what == "mama":
				if not Net.try_spend(id, FOOD_PRICE):
					Net.notify(id, "Mama için %d TL gerek." % FOOD_PRICE, false)
					return
				Rpg.add_energy(pid, FOOD_ENERGY)
			_last_act[id] = now
			Net.tell_all(self, "on_act", {"who": Net.players[pid].name, "act": what, "by": me, "p": _pos(pid)})
