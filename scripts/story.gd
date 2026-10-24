extends Node
## Hikaye görevleri: şehirdeki NPC'lerin verdiği, sırayla ilerleyen diyaloglu görev zinciri.
## NPC'nin yanına gidip E'ye basılır → sunucu duruma göre diyalog döndürür (kabul / ilerleme / ödül).
## Kayıt: rec["story"] = {step, count, accepted}. İlerleme oyun olaylarından gelir (event()).

signal changed
signal dialog(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

# goal: patient, night_patient, customer, fish (+fish adı), talk (+target), own_plot, own_biz, level (+count)
const STEPS := [
	{"npc": "muhtar", "title": "Şehre Hoş Geldin", "goal": "patient", "count": 2,
		"hint": "Hastanede 2 hastayı iyileştir (Hastane, sol üstte).", "reward": [300, 60],
		"intro": ["Hoş geldin evladım! Ben Muhtar Rıza, bu mahallenin muhtarıyım.",
			"Bu şehirde herkes çalışarak başlar. Hastanede Dr. Selma'nın yardıma ihtiyacı var.",
			"Git, 2 hastayı iyileştir; sonra bana uğra, seni boş göndermem."],
		"done": ["Aferin! İlk maaşını aldın bile. Al bakalım, bu da benden."]},
	{"npc": "muhtar", "title": "Hasan Amca'yla Tanış", "goal": "talk", "target": "hasan", "count": 1,
		"hint": "Göl kenarındaki Balıkçı Hasan Amca'yla konuş.", "reward": [150, 30],
		"intro": ["Gölün kenarında Balıkçı Hasan Amca oturur. Şehrin en eski balıkçısıdır.",
			"Git bir selam ver; sana balık tutmayı o öğretir."],
		"done": ["Hoş geldin delikanlı! Muhtar seni anlattı. Gel otur şöyle..."]},
	{"npc": "hasan", "title": "İlk Avın", "goal": "fish", "count": 3,
		"hint": "Göl iskelesinden 3 balık tut, Hasan Amca'ya dön.", "reward": [350, 70],
		"intro": ["Olta tutmayı bilir misin? Bilmiyorsan da öğrenirsin.",
			"Mantar batınca hemen çek, erken çekersen balık ürker. 3 balık tut, gel anlat."],
		"done": ["İşte bu! Balıkçılık sabır işidir, sende o sabır var."]},
	{"npc": "hasan", "title": "Gece Avcısı", "goal": "fish", "fish": "Yayın Balığı", "count": 1,
		"hint": "Gece (20:00 sonrası) gölden bir Yayın Balığı tut.", "reward": [900, 150],
		"intro": ["Gölün dibinde koca yayın balıkları yaşar ama sadece geceleri yüzeye çıkarlar.",
			"Saat 20'den sonra şansını dene. Bir yayın tutarsan seni gerçek balıkçı sayarım."],
		"done": ["Vay canına, maşallah! Bu yayın benim yıllar önce tuttuğumdan bile büyük!"]},
	{"npc": "ayten", "title": "Kasada Bir Gün", "goal": "customer", "count": 3,
		"hint": "Markette 3 müşteriye doğru para üstü ver.", "reward": [400, 80],
		"intro": ["Merhaba canım! Market bugün çok kalabalık, kasaya geçer misin?",
			"3 müşteriye doğru para üstü ver, gerisini ben hallederim."],
		"done": ["Sen olmasan ne yapardım! Al bakalım, bu da senin hakkın."]},
	{"npc": "selma", "title": "Gece Nöbeti", "goal": "night_patient", "count": 3,
		"hint": "Gece (20:00 sonrası) hastanede 3 hastaya bak.", "reward": [600, 120],
		"intro": ["Gece nöbetçimiz hastalandı, acil serviste kimse yok.",
			"Saat 20'den sonra gelip 3 hastaya bakabilir misin? Gece vardiyası daha iyi öder."],
		"done": ["Nöbet için çok teşekkürler. Hastalar senden çok memnun kaldı."]},
	{"npc": "muhtar", "title": "Ev Sahibi Ol", "goal": "own_plot", "count": 1,
		"hint": "Emlak Ofisi'nden ya da Pazar Yeri'nden bir arsa al.", "reward": [1000, 200],
		"intro": ["Artık bu şehrin bir parçasısın. Kirada oturmak olmaz!",
			"Emlak Ofisi'nden ya da Pazar Yeri'nden kendine bir arsa al."],
		"done": ["Hayırlı olsun komşu! Toprağın bereketli olsun."]},
	{"npc": "rustem", "title": "Açık Denizler", "goal": "fish", "fish": "Lüfer", "count": 1,
		"hint": "Deniz iskelesinden ya da tekneden bir Lüfer tut (Sv.3).", "reward": [1500, 250],
		"intro": ["Ahoy! Deniz göle benzemez evlat, dalgası da var balığı da.",
			"İskelemden ya da kendi teknenle bir Lüfer tut, seni gerçek denizci sayayım."],
		"done": ["Hah! Lüferi tutan adam deniz kurdudur. Rüzgâr hep arkandan essin!"]},
	{"npc": "muhtar", "title": "Esnaf Ol", "goal": "own_biz", "count": 1,
		"hint": "Boş bir arsaya büfe aç (arsa menüsü → Büfe aç).", "reward": [3000, 400],
		"intro": ["Şehrimizin yeni esnafa ihtiyacı var. Bir büfe açsan ne güzel olur!",
			"Boş arsana büfe kur, malzeme koy; müşteriler kendiliğinden gelir."],
		"done": ["İşte şehrimizin yeni esnafı! Bereketli olsun, kasan hiç boş kalmasın."]},
	{"npc": "muhtar", "title": "Şehrin Gururu", "goal": "level", "count": 10,
		"hint": "10. seviyeye ulaş.", "reward": [10000, 0],
		"intro": ["Sana son bir hedef vereceğim: 10. seviyeye ulaş.",
			"O gün geldiğinde seni şehrin gururu ilan edeceğim!"],
		"done": ["Bugün bu şehrin en mutlu günü! Seni 'Şehrin Gururu' ilan ediyorum!"]},
]
const CHATTER := {
	"muhtar": ["Mahallemizde her şey yolunda, çok şükür.", "Muhtarlığın kapısı herkese açık evladım."],
	"hasan": ["Bugün balıklar pek naz yapıyor...", "Yağmur yağınca balıklar daha çabuk vurur, bilir misin?"],
	"selma": ["Sağlıklı günler! Gece vardiyası daha iyi öder, unutma.", "Bol su için, hele plajdaysanız!"],
	"ayten": ["Taze simit geldi canım!", "Toptan malzeme mi lazım? İşletmenin menüsünden sipariş verebilirsin."],
	"rustem": ["Fırtına çıkınca denize açılma, laf dinle.", "Teknen yoksa Galeri'ye bir bak, sürat teknesi satıyorlar."],
}

var state: Dictionary = {}        # istemci: mevcut adım özeti


# ------------------------------------------------------------------ istemci API

func talk(npc: String) -> void:
	Net.ask(self, "req_talk", {"npc": npc})


func accept() -> void:
	Net.ask(self, "req_accept")


func claim() -> void:
	Net.ask(self, "req_claim")


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	state = d
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_dialog(d: Dictionary) -> void:
	dialog.emit(d)


func reset() -> void:
	state = {}


## İstemci: bu NPC'nin başında ne işareti olmalı? "!" yeni görev, "?" ödül hazır, "" yok.
func marker(npc: String) -> String:
	if state.is_empty() or state.get("finished", false):
		return ""
	var target: String = state.get("target", "")
	if state.get("ready", false) and (npc == state.get("claim_npc", "")):
		return "?"
	if not state.get("accepted", false) and npc == state.get("npc", ""):
		return "!"
	if state.get("accepted", false) and target == npc and not state.get("ready", false):
		return "!"
	return ""


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	var rec: Dictionary = Net.save_data.players.get(Net.players[id].name, {})
	if not rec.get("story") is Dictionary:
		rec["story"] = {"step": 0, "count": 0, "accepted": false}
	return rec


func _st(id: int) -> Dictionary:
	var rec := _rec(id)
	return rec.get("story", {}) if not rec.is_empty() else {}


func _claim_npc(step: Dictionary) -> String:
	return str(step.get("target", step.npc)) if step.goal == "talk" else str(step.npc)


func _ready_now(id: int, s: Dictionary, step: Dictionary) -> bool:
	match str(step.goal):
		"own_plot":
			for p in Land.plots:
				if p.owner == Net.players[id].name:
					return true
			return false
		"own_biz":
			for p in Land.plots:
				if p.owner == Net.players[id].name and Biz.is_biz(p):
					return true
			return false
		"level":
			return Rpg.level(id) >= int(step.count)
	return int(s.count) >= int(step.count)


func send_state(id: int) -> void:
	var s := _st(id)
	if s.is_empty():
		return
	var k := int(s.step)
	if k >= STEPS.size():
		Net.tell(self, id, "on_state", {"finished": true})
		return
	var step: Dictionary = STEPS[k]
	var accepted := bool(s.accepted)
	var shown := int(s.count)
	if step.goal == "level":
		shown = Rpg.level(id)
	elif step.goal in ["own_plot", "own_biz"]:
		shown = 1 if _ready_now(id, s, step) else 0
	Net.tell(self, id, "on_state", {"step": k + 1, "total": STEPS.size(), "title": step.title,
		"hint": step.hint, "npc": step.npc, "target": str(step.get("target", "")),
		"claim_npc": _claim_npc(step), "accepted": accepted, "count": mini(shown, int(step.count)),
		"goal": int(step.count), "ready": accepted and _ready_now(id, s, step)})


func _say(id: int, npc: String, lines: Array, buttons: Array) -> void:
	Net.tell(self, id, "on_dialog", {"npc": npc, "name": Map.NPCS[npc].name, "lines": lines, "buttons": buttons})


@rpc("any_peer", "call_remote", "reliable")
func req_talk(d: Dictionary) -> void:
	var id := Net.sender()
	var npc := str(d.get("npc", ""))
	if not Net.players.has(id) or not Map.NPCS.has(npc):
		return
	# Geniş pay: internet gecikmesinde sunucu oyuncuyu birkaç adım geriden görür.
	var dist: float = Net.positions.get(id, Vector2(-9999, -9999)).distance_to(Map.NPCS[npc].pos)
	if dist > Map.NPC_TALK_RANGE + 250:
		Net.notify(id, "%s ile konuşmak için biraz daha yaklaş." % Map.NPCS[npc].name, false)
		return
	var s := _st(id)
	var k := int(s.step)
	if k >= STEPS.size():
		_say(id, npc, ["Hikâyeyi bitirdin, şehrin gururusun! " + CHATTER[npc].pick_random()], ["Tamam"])
		return
	var step: Dictionary = STEPS[k]
	# "Tanış" görevi: hedef NPC'yle konuşmak ilerletir
	if bool(s.accepted) and step.goal == "talk" and step.get("target") == npc:
		s["count"] = 1
	if bool(s.accepted) and _ready_now(id, s, step) and npc == _claim_npc(step):
		_say(id, npc, step.done, ["Ödülü al"])
		send_state(id)
		return
	if not bool(s.accepted) and npc == step.npc:
		_say(id, npc, step.intro, ["Kabul et", "Sonra"])
		return
	if bool(s.accepted) and npc == step.npc:
		var prog := "Durum: %d/%d" % [mini(int(s.count), int(step.count)), int(step.count)]
		if step.goal == "level":
			prog = "Seviyen: %d/%d" % [Rpg.level(id), int(step.count)]
		_say(id, npc, ["Görevin: " + str(step.hint), prog], ["Tamam"])
		return
	_say(id, npc, [CHATTER[npc].pick_random()], ["Tamam"])


@rpc("any_peer", "call_remote", "reliable")
func req_accept(_d: Dictionary) -> void:
	var id := Net.sender()
	var s := _st(id)
	if s.is_empty() or int(s.step) >= STEPS.size() or bool(s.accepted):
		return
	s["accepted"] = true
	s["count"] = 0
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Yeni görev: %s" % STEPS[int(s.step)].title)


@rpc("any_peer", "call_remote", "reliable")
func req_claim(_d: Dictionary) -> void:
	var id := Net.sender()
	var s := _st(id)
	if s.is_empty() or int(s.step) >= STEPS.size():
		return
	var step: Dictionary = STEPS[int(s.step)]
	if not bool(s.accepted) or not _ready_now(id, s, step):
		return
	var money: int = step.reward[0]
	var xp: int = step.reward[1]
	s["step"] = int(s.step) + 1
	s["count"] = 0
	s["accepted"] = false
	Net.add_money(id, money)
	if xp > 0:
		Rpg.add_xp(id, "", xp)
	Net.mark_dirty()
	Net.notify(id, "Görev tamamlandı: %s! +%s%s" % [step.title, U.money(money), (", +%d XP" % xp) if xp > 0 else ""])
	Net.log_line("%s hikâye görevini bitirdi: %s" % [Net.players[id].name, step.title])
	if int(s.step) >= STEPS.size():
		Net.announce("%s tüm hikâyeyi tamamladı ve 'Şehrin Gururu' oldu!" % Net.players[id].name)
	send_state(id)


## Oyun olayları (Rpg.quest_event ve diğerlerinden çağrılır).
func event(id: int, kind: String, data: Dictionary = {}) -> void:
	var s := _st(id)
	if s.is_empty() or int(s.step) >= STEPS.size() or not bool(s.accepted):
		return
	var step: Dictionary = STEPS[int(s.step)]
	var hit := false
	match str(step.goal):
		"patient", "customer":
			hit = kind == step.goal
		"night_patient":
			hit = kind == "patient" and Env.is_night()
		"fish":
			hit = kind == "fish" and (not step.has("fish") or data.get("fish", "") == step.fish)
		"own_plot", "own_biz", "level":
			hit = false       # durum kontrolü: _ready_now
	if hit and int(s.count) < int(step.count):
		s["count"] = int(s.count) + 1
		Net.mark_dirty()
		if int(s.count) >= int(step.count):
			Net.notify(id, "Görev hazır: %s — şimdi %s ile konuş." % [step.title, Map.NPCS[_claim_npc(step)].name])
	send_state(id)
