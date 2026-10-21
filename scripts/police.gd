extends Node
## Polis ve suç: yankesicilik, soygun (ev, dükkân kasası, tarla), aranma yıldızları, hapishane, kefalet;
## Karakol'da polis mesleği (görevdeyken aranan oyuncuları tutuklar, olay vakalarını çözer) ve
## güvenlik ürünleri (cüzdan zinciri, çelik kilit, alarm). Sokaklarda NPC polis de devriye gezer.
## Yeni oyuncular korunur: suç işlemek de suç kurbanı olmak da seviye CRIME_LEVEL ister.
## Veri: rec["crime"] = {wanted, t, jail_until, crimes, arrests}, rec["security"] = ["wallet"],
##       plots[i]["sec"] = {lock, alarm}. Oyuncu listesinde "wanted" ve "police" alanları var.

signal changed
signal patrol_case(d: Dictionary)
signal patrol_result(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const CRIME_LEVEL := 3
const POLICE_LEVEL := 4
const MAX_WANTED := 5
const DECAY_SEC := 180.0           # her 3 dakikada 1 yıldız düşer
const PICK_RANGE := 70.0
const ARREST_RANGE := 90.0
const PICK_COOLDOWN := 60.0
const ROB_COOLDOWN := 120.0
const VICTIM_IMMUNE := 180.0
const PICK_CHANCE := 0.55
const PICK_PCT := 0.08
const PICK_MIN := 20
const PICK_MAX := 400
const ROB_CHANCE := 0.6
const HOUSE_PCT := 0.03
const HOUSE_MAX := 1000
const SHOP_PCT := 0.5
const SHOP_MAX := 3000
const JAIL_PER_STAR := 45.0
const FINE_PER_STAR := 150
const BAIL_PER_SEC := 8
const NPC_EVERY := 20.0
const NPC_CATCH := 0.05            # yıldız başına yakalanma şansı (her 20 sn)
const PATROL_TIME := 14.0
const NPC_OFFICER := "Komiser Kemal"

const SECURITY := {
	"wallet": {"name": "Cüzdan Zinciri", "price": 1500, "plot": false,
		"desc": "Yankesicilerin seni soyma şansı yarıya iner"},
	"lock": {"name": "Çelik Kilit", "price": 2500, "plot": true,
		"desc": "Arsandaki yapı için: soygun şansı ve çalınan miktar yarıya iner"},
	"alarm": {"name": "Alarm Sistemi", "price": 4000, "plot": true,
		"desc": "Arsandaki yapı için: soygun girişimi boşa çıkar, hırsız +2 yıldız alır"},
}

# [olay, doğru müdahale]
const CASES := [
	["Kırmızı ışıkta geçen bir sürücü", "Durdur, ehliyet kontrolü + trafik cezası"],
	["Markette kavga eden iki müşteri", "Tarafları ayır, ifadelerini al"],
	["Kaybolan 6 yaşında bir çocuk", "Anons yap, son görüldüğü yeri ara"],
	["Gece yarısı yüksek sesle müzik şikâyeti", "Uyarı yap, tekrarında tutanak tut"],
	["Park yerinde camı kırılmış araba", "Olay yerini koru, parmak izi al"],
	["Plajda boğulma tehlikesi geçiren yüzücü", "Cankurtaranı çağır, ambulans iste"],
	["Sahte para kullandığı düşünülen müşteri", "Parayı incele, şüpheliyi gözaltına al"],
	["Yolda bozulan ve trafiği tıkayan kamyon", "Şeridi kapat, çekici çağır"],
	["Kapısı zorlanmış bir ev", "İçeriyi kontrol et, ev sahibine haber ver"],
	["Sokakta sahipsiz bir çanta", "Alanı boşalt, bomba imha ekibini çağır"],
	["Hız sınırını 40 km aşan araba", "Radar kaydı + hız cezası"],
	["Kumarhanede hile yaptığı iddia edilen oyuncu", "Kamera kayıtlarını incele"],
	["Göl kıyısında izinsiz ağla balık avı", "Ağlara el koy, tutanak tut"],
	["Fırtınada devrilen ağaç yolu kapattı", "Yolu kapat, belediyeye haber ver"],
]

# --- istemci
var status: Dictionary = {}        # {wanted, police, crimes, arrests, security}
var jail_until := 0.0              # yerel saat (sn); 0 = serbest

# --- sunucu
var _cool := {}                    # "pick:ad" / "rob:ad:arsa" -> unix
var _immune := {}                  # kurban adı -> unix
var _patrol := {}                  # id -> {correct, correct_text, deadline}
var _jailed := {}                  # id -> true (hapiste ve çevrimiçi)
var _acc := 0.0
var _npc_acc := 0.0


func reset() -> void:
	status = {}
	jail_until = 0.0
	_patrol.clear()
	_jailed.clear()


func on_player_left(id: int) -> void:
	_patrol.erase(id)
	_jailed.erase(id)


func _now() -> float:
	return Time.get_unix_time_from_system()


static func local_now() -> float:
	return Time.get_ticks_msec() / 1000.0


func jail_left() -> float:
	return maxf(0.0, jail_until - local_now())


func on_duty() -> bool:
	return bool(status.get("police", false))


# ------------------------------------------------------------------ istemci API

func pickpocket(target: String) -> void:
	Net.ask(self, "req_action", {"kind": "pick", "target": target})


func rob(plot: int) -> void:
	Net.ask(self, "req_action", {"kind": "rob", "plot": plot})


func arrest(target: String) -> void:
	Net.ask(self, "req_action", {"kind": "arrest", "target": target})


func set_duty(on: bool) -> void:
	Net.ask(self, "req_duty", {"on": on})


func bail() -> void:
	Net.ask(self, "req_bail")


func buy_security(item: String, plot: int = -1) -> void:
	Net.ask(self, "req_security", {"item": item, "plot": plot})


func ask_patrol() -> void:
	Net.ask(self, "req_patrol")


func answer_patrol(choice: int) -> void:
	Net.ask(self, "req_patrol_answer", {"choice": choice})


@rpc("authority", "call_local", "reliable")
func on_status(d: Dictionary) -> void:
	status = d
	jail_until = local_now() + float(d.get("jail_left", 0.0)) if float(d.get("jail_left", 0.0)) > 0.0 else 0.0
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_patrol_case(d: Dictionary) -> void:
	patrol_case.emit(d)


@rpc("authority", "call_local", "reliable")
func on_patrol_result(d: Dictionary) -> void:
	patrol_result.emit(d)


# ------------------------------------------------------------------ sunucu: kayıt

func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


## Suç kaydı (yoksa oluşturur) ve yıldızların zamanla düşmesi.
static func crime(rec: Dictionary) -> Dictionary:
	if not rec.get("crime") is Dictionary:
		rec["crime"] = {"wanted": 0, "t": 0.0, "jail_until": 0.0, "crimes": 0, "arrests": 0}
	var c: Dictionary = rec["crime"]
	var now := Time.get_unix_time_from_system()
	if int(c.wanted) > 0:
		var n := int(floor((now - float(c.t)) / DECAY_SEC))
		if n > 0:
			c["wanted"] = maxi(0, int(c.wanted) - n)
			c["t"] = float(c.t) + n * DECAY_SEC
	return c


static func jailed_rec(rec: Dictionary) -> bool:
	return float(crime(rec).jail_until) > Time.get_unix_time_from_system()


func is_jailed(id: int) -> bool:
	var rec := _rec(id)
	return not rec.is_empty() and jailed_rec(rec)


func wanted(id: int) -> int:
	var rec := _rec(id)
	return int(crime(rec).wanted) if not rec.is_empty() else 0


func _security(rec: Dictionary) -> Array:
	if not rec.get("security") is Array:
		rec["security"] = []
	return rec["security"]


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var c := crime(rec)
	var left := maxf(0.0, float(c.jail_until) - _now())
	if left > 0.0:
		_jailed[id] = true
	Net.tell(self, id, "on_status", {"wanted": int(c.wanted), "jail_left": left, "police": bool(Net.players[id].get("police", false)),
		"crimes": int(c.crimes), "arrests": int(c.arrests), "security": _security(rec).duplicate()})
	_update_roster(id)


func _update_roster(id: int) -> void:
	var w := wanted(id)
	if int(Net.players[id].get("wanted", 0)) != w:
		Net.players[id]["wanted"] = w
		Net._broadcast_roster()


func _add_wanted(id: int, n: int) -> void:
	var c := crime(_rec(id))
	if int(c.wanted) == 0:
		c["t"] = _now()
	c["wanted"] = mini(MAX_WANTED, int(c.wanted) + n)
	c["crimes"] = int(c.crimes) + 1
	Net.mark_dirty()
	send_state(id)
	var who: String = Net.players[id].name
	if int(c.wanted) >= 3:
		Net.announce("%s aranıyor! (%s) Görevdeki polisler dikkat." % [who, "★".repeat(int(c.wanted))])
	for pid in Net.players:
		if pid != id and bool(Net.players[pid].get("police", false)):
			Net.notify(pid, "Telsiz: %s suç işledi (%s)." % [who, "★".repeat(int(c.wanted))], false)


## Oyuncu dışarıda mı (ev içinde, hapiste değil)?
func _outdoors(id: int) -> bool:
	var p: Vector2 = Net.positions.get(id, Vector2(-9999, -9999))
	return Map.WORLD.has_point(p)


# ------------------------------------------------------------------ sunucu: suç ve tutuklama

@rpc("any_peer", "call_remote", "reliable")
func req_action(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or is_jailed(id):
		return
	match str(d.get("kind", "")):
		"pick":
			_pickpocket(id, str(d.get("target", "")))
		"rob":
			_rob(id, int(d.get("plot", -1)))
		"arrest":
			_arrest(id, str(d.get("target", "")))


func _can_commit(id: int) -> bool:
	if bool(Net.players[id].get("police", false)):
		Net.notify(id, "Görevdeki polis suç işleyemez!", false)
		return false
	if Rpg.level(id) < CRIME_LEVEL:
		Net.notify(id, "Bunun için en az seviye %d olmalısın." % CRIME_LEVEL, false)
		return false
	return true


func _pickpocket(id: int, target: String) -> void:
	var tid := Net.id_by_name(target)
	if tid == 0 or tid == id or not _can_commit(id):
		return
	var me: String = Net.players[id].name
	var now := _now()
	if not _outdoors(id) or not _outdoors(tid):
		return
	if Net.positions[id].distance_to(Net.positions[tid]) > PICK_RANGE:
		Net.notify(id, "%s çok uzakta." % target, false)
		return
	if Rpg.level(tid) < CRIME_LEVEL or bool(Net.players[tid].get("police", false)):
		Net.notify(id, "%s korunuyor (yeni oyuncu ya da polis)." % target, false)
		return
	if now < float(_cool.get("pick:" + me, 0.0)):
		Net.notify(id, "Biraz bekle, dikkat çekiyorsun. (%d sn)" % int(float(_cool["pick:" + me]) - now), false)
		return
	if now < float(_immune.get(target, 0.0)):
		Net.notify(id, "%s tetikte, şimdi olmaz." % target, false)
		return
	_cool["pick:" + me] = now + PICK_COOLDOWN
	var chance := PICK_CHANCE * (0.5 if _security(_rec(tid)).has("wallet") else 1.0)
	if randf() < chance:
		var amount := mini(clampi(int(Net.get_money(tid) * PICK_PCT), PICK_MIN, PICK_MAX), Net.get_money(tid))
		if amount <= 0:
			Net.notify(id, "%s'in cebi boş çıktı." % target, false)
			return
		Net.add_money(tid, -amount)
		Net.add_money(id, amount)
		_immune[target] = now + VICTIM_IMMUNE
		var seen := randf() < 0.5
		Net.notify(id, "Yankesicilik başarılı: +%s%s" % [U.money(amount), " — ama biri gördü!" if seen else ""], not seen)
		Net.notify(tid, "Cebinden %s çalındı!%s" % [U.money(amount), " Hırsız: %s" % me if seen else ""], false)
		if seen:
			_add_wanted(id, 1)
		Net.log_line("Suç: %s → %s yankesicilik %d TL" % [me, target, amount])
	else:
		Net.notify(id, "Yakalandın! %s elini cebinde fark etti." % target, false)
		Net.notify(tid, "%s cebine uzandı ama fark ettin!" % me)
		_immune[target] = now + VICTIM_IMMUNE
		_add_wanted(id, 1)


func _rob(id: int, i: int) -> void:
	if i < 0 or i >= Land.plots.size() or not _can_commit(id):
		return
	var p: Dictionary = Land.plots[i]
	var me: String = Net.players[id].name
	var owner: String = p.owner
	if owner == "" or owner == me or int(p.level) < 1:
		return
	if not Map.plot_rect(i).grow(40).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Arsaya yaklaşman gerek.", false)
		return
	var orec: Dictionary = Net.save_data.players.get(owner, {})
	if Rpg.level_of_rec(orec) < CRIME_LEVEL:
		Net.notify(id, "%s yeni bir oyuncu, mahalleli onu koruyor." % owner, false)
		return
	var key := "rob:%s:%d" % [me, i]
	var now := _now()
	if now < float(_cool.get(key, 0.0)):
		Net.notify(id, "Burası hâlâ tetikte. (%d sn)" % int(float(_cool[key]) - now), false)
		return
	_cool[key] = now + ROB_COOLDOWN
	var sec: Dictionary = p.get("sec", {})
	var oid := Net.id_by_name(owner)
	if bool(sec.get("alarm", false)):
		Net.notify(id, "ALARM ÇALDI! Soygun başarısız, polis yolda!", false)
		if oid != 0:
			Net.notify(oid, "Alarm: %s arsa #%d'yi soymaya çalıştı!" % [me, i + 1], false)
		_add_wanted(id, 2)
		return
	var lock := bool(sec.get("lock", false))
	if randf() >= ROB_CHANCE * (0.5 if lock else 1.0):
		Net.notify(id, "Soygun başarısız! Kilidi açamadın ve görüldün.", false)
		if oid != 0:
			Net.notify(oid, "%s arsa #%d'yi soymaya çalıştı ama başaramadı." % [me, i + 1], false)
		_add_wanted(id, 1)
		return
	var mult := 0.5 if lock else 1.0
	var what := ""
	if Biz.is_biz(p):
		var take := int(mini(int(int(p.biz.cash) * SHOP_PCT), SHOP_MAX) * mult)
		if take <= 0:
			Net.notify(id, "Kasa boştu!", false)
			_add_wanted(id, 1)
			return
		p.biz["cash"] = int(p.biz.cash) - take
		Net.add_money(id, take)
		Land._broadcast()
		what = "%s kasasından %s" % [Biz.NAMES[int(p.level)], U.money(take)]
	elif Farm.is_farm(p):
		var got := Farm.steal_bed(i, _rec(id))
		if got.is_empty():
			Net.notify(id, "Tarlada toplanacak olgun ürün yoktu.", false)
			return
		Farm.send_state(id)
		what = "tarladan %d %s" % [got[1], Farm.CROPS[got[0]].name]
	else:
		var take := int(mini(int(int(orec.get("money", 0)) * HOUSE_PCT), HOUSE_MAX) * mult)
		if take <= 0:
			Net.notify(id, "Evde değerli bir şey yoktu.", false)
			return
		Net.add_money_by_name(owner, -take)
		Net.add_money(id, take)
		what = "evden %s" % U.money(take)
	Net.notify(id, "Soygun başarılı: %s! Ama polis seni arıyor." % what, false)
	if oid != 0:
		Net.notify(oid, "Arsa #%d soyuldu: %s! Hırsız: %s" % [i + 1, what, me], false)
	_add_wanted(id, 2)
	Net.log_line("Suç: %s → %s soygun (%s)" % [me, owner, what])


func _arrest(id: int, target: String) -> void:
	if not bool(Net.players[id].get("police", false)):
		return
	var tid := Net.id_by_name(target)
	if tid == 0 or tid == id or is_jailed(tid):
		return
	if Net.positions.get(id, Vector2.ZERO).distance_to(Net.positions.get(tid, Vector2(-9999, -9999))) > ARREST_RANGE:
		Net.notify(id, "%s çok uzakta, yaklaş." % target, false)
		return
	var stars := wanted(tid)
	if stars <= 0:
		Net.notify(id, "%s aranmıyor." % target, false)
		return
	jail(tid, stars, id)


## Hapse at (by: tutuklayan polisin id'si; 0 = NPC polis).
func jail(tid: int, stars: int, by: int) -> void:
	var rec := _rec(tid)
	var c := crime(rec)
	var who: String = Net.players[tid].name
	var secs := JAIL_PER_STAR * stars
	var fine := mini(FINE_PER_STAR * stars, Net.get_money(tid))
	Net.add_money(tid, -fine)
	c["wanted"] = 0
	c["jail_until"] = _now() + secs
	Garage.set_ride(tid, "")
	Events.on_player_left(tid)          # yarıştaysa çıkar
	Homes._teleport(tid, Map.jail_spawn())
	_jailed[tid] = true
	var officer := NPC_OFFICER
	if by != 0 and Net.players.has(by):
		officer = Net.players[by].name
		var rc := crime(_rec(by))
		rc["arrests"] = int(rc.arrests) + 1
		Net.add_money(by, fine + 50 * stars)
		Rpg.add_xp(by, "police", 40 * stars)
		Rpg.quest_event(by, "patrol")
		Net.notify(by, "%s tutuklandı! Ödül: %s" % [who, U.money(fine + 50 * stars)])
		send_state(by)
	Net.mark_dirty()
	send_state(tid)
	Net.notify(tid, "%s seni tutukladı! %d sn hapis, %s ceza. (Kefaletle erken çıkabilirsin)" % [officer, int(secs), U.money(fine)], false)
	Net.announce("%s, %s tarafından tutuklandı (%s)." % [who, officer, "★".repeat(stars)])
	Net.log_line("Tutuklama: %s (%d yıldız) — %s" % [who, stars, officer])


func _release(id: int) -> void:
	_jailed.erase(id)
	var c := crime(_rec(id))
	c["jail_until"] = 0.0
	Net.mark_dirty()
	Homes._teleport(id, Map.building("karakol").rect.get_center() + Vector2(0, 130))
	send_state(id)
	Net.notify(id, "Serbestsin. Bir daha yapma!")


@rpc("any_peer", "call_remote", "reliable")
func req_bail(_d: Dictionary) -> void:
	var id := Net.sender()
	if not is_jailed(id):
		return
	var left := float(crime(_rec(id)).jail_until) - _now()
	var cost := int(ceil(left)) * BAIL_PER_SEC
	if not Net.try_spend(id, cost):
		Net.notify(id, "Kefalet için %s gerekli." % U.money(cost), false)
		return
	Net.notify(id, "Kefalet ödendi: %s" % U.money(cost))
	_release(id)


# ------------------------------------------------------------------ sunucu: polislik

func _at_station(id: int) -> bool:
	return Map.building("karakol").rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


@rpc("any_peer", "call_remote", "reliable")
func req_duty(d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id):
		return
	var on := bool(d.get("on", false))
	if on:
		if not _at_station(id):
			Net.notify(id, "Göreve başlamak için Karakol'a git.", false)
			return
		if Rpg.level(id) < POLICE_LEVEL:
			Net.notify(id, "Polis olmak için seviye %d gerekli." % POLICE_LEVEL, false)
			return
		if wanted(id) > 0 or is_jailed(id):
			Net.notify(id, "Sabıkan temizlenmeden polis olamazsın!", false)
			return
	Net.players[id]["police"] = on
	Net._broadcast_roster()
	send_state(id)
	Net.notify(id, "Göreve başladın. Aranan oyunculara yaklaşıp G ile tutukla, Karakol'da olay çöz." if on else "Görevi bıraktın.")


@rpc("any_peer", "call_remote", "reliable")
func req_patrol(_d: Dictionary) -> void:
	var id := Net.sender()
	if not Net.players.has(id) or not bool(Net.players[id].get("police", false)):
		Net.notify(id, "Önce göreve başla.", false)
		return
	if not Rpg.use_energy(id, 3):
		Net.tell(self, id, "on_patrol_result", {"ok": false, "pay": 0, "stop": true, "text": "Çok yorgunsun. Bir şeyler ye ya da dinlen."})
		return
	var c: Array = CASES.pick_random()
	var opts: Array = [c[1]]
	while opts.size() < 4:
		var o: String = CASES.pick_random()[1]
		if not opts.has(o):
			opts.append(o)
	opts.shuffle()
	var limit := PATROL_TIME + Rpg.perk(id, "police_time")
	_patrol[id] = {"correct": opts.find(c[1]), "correct_text": c[1], "deadline": _now() + limit}
	Net.tell(self, id, "on_patrol_case", {"case": c[0], "options": opts, "time": limit})


@rpc("any_peer", "call_remote", "reliable")
func req_patrol_answer(d: Dictionary) -> void:
	var id := Net.sender()
	if not _patrol.has(id):
		return
	var t: Dictionary = _patrol[id]
	_patrol.erase(id)
	var left: float = float(t.deadline) - _now()
	var choice := int(d.get("choice", -1))
	var res := {"ok": false, "pay": 0}
	if choice < 0 or left < -0.5:
		res["text"] = "Geç kaldın, olay yerine başka ekip gitti."
	elif choice == int(t.correct):
		res["ok"] = true
		res["pay"] = int((35 + maxf(left, 0.0) * 2.0) * Rpg.perk(id, "police_pay") * (1.2 if Env.is_night() else 1.0)
			* Events.pay_mult() * Clans.pay_mult(id))
		res["text"] = "Doğru müdahale! Olay çözüldü. +%s" % U.money(res.pay)
		Rpg.add_xp(id, "police", 12)
		Rpg.quest_event(id, "patrol")
	else:
		res["pay"] = -15
		res["text"] = "Yanlış müdahale! Doğrusu: %s. Ceza: %s" % [t.correct_text, U.money(15)]
	if int(res.pay) != 0:
		Net.add_money(id, int(res.pay))
	Net.tell(self, id, "on_patrol_result", res)


@rpc("any_peer", "call_remote", "reliable")
func req_security(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var item := str(d.get("item", ""))
	if rec.is_empty() or not SECURITY.has(item):
		return
	if not _at_station(id):
		Net.notify(id, "Güvenlik ürünleri Karakol'da satılır.", false)
		return
	var info: Dictionary = SECURITY[item]
	if info.plot:
		var i := int(d.get("plot", -1))
		if i < 0 or i >= Land.plots.size() or Land.plots[i].owner != Net.players[id].name:
			return
		var p: Dictionary = Land.plots[i]
		if not p.get("sec") is Dictionary:
			p["sec"] = {"lock": false, "alarm": false}
		if bool(p.sec.get(item, false)):
			Net.notify(id, "Arsa #%d'de zaten %s var." % [i + 1, info.name], false)
			return
		if not Net.try_spend(id, int(info.price)):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		p.sec[item] = true
		Land._broadcast()
		Net.notify(id, "Arsa #%d: %s takıldı." % [i + 1, info.name])
	else:
		if _security(rec).has(item):
			Net.notify(id, "%s zaten sende." % info.name, false)
			return
		if not Net.try_spend(id, int(info.price)):
			Net.notify(id, "Yeterli paran yok.", false)
			return
		_security(rec).append(item)
		Net.notify(id, "%s satın alındı: %s" % [info.name, info.desc])
	Net.mark_dirty()
	send_state(id)


# ------------------------------------------------------------------ sunucu: zamanlayıcılar

func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	_npc_acc += delta
	if _acc >= 1.0:
		_acc = 0.0
		var now := _now()
		for id in _jailed.keys():
			if not Net.players.has(id):
				_jailed.erase(id)
			elif float(crime(_rec(id)).jail_until) <= now:
				_release(id)
		for id in Net.players:
			_update_roster(id)       # yıldızlar zamanla düşer
	if _npc_acc >= NPC_EVERY:
		_npc_acc = 0.0
		for id in Net.players.keys():
			var w := wanted(id)
			if w > 0 and not is_jailed(id) and _outdoors(id) and randf() < NPC_CATCH * w:
				jail(id, w, 0)
