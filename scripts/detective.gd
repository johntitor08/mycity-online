extends Node
## Dedektiflik görevleri (1.4). Karakolun yanındaki Dedektif Ferhat'tan vaka alınır.
## Her vakada 3 ipucu (dünyanın farklı yerlerinde, E ile incele) ve 3 şüpheli (sorgula) vardır.
## Tüm ipuçları ve ifadeler toplanınca dosyadan suçluyu seç. Doğruysa ödül; yanlışsa 3 dk bekle, ödül azalır.
## Şüpheliler ve ipuçları sadece o vakası açık olan oyuncuya görünür. Her şeyi sunucu denetler.
## Veri: rec["detective"] = {case, clues: [], talked: [], solved: [], wrong}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const RANGE := 80.0
const WRONG_COOLDOWN := 180.0

# Vakalar: ad, özet, ödül, ipuçları [{id, pos, text}], şüpheliler [{id, name, pos, app, says}], suçlu
const CASES := [
	{"id": "altin_balik", "name": "Kayıp Altın Balık", "reward": 1500,
		"brief": "Balıkçı Hasan Amca'nın yarışma için sakladığı Altın Balık gece göl iskelesindeki kovasından çalındı. Kim aldı?",
		"clues": [
			{"id": "c1", "pos": Vector2(880, 1050), "text": "Göl iskelesinde ıslak, kocaman bot izleri. Ölçtün: 44 numara."},
			{"id": "c2", "pos": Vector2(880, 372), "text": "Marketin yanında boş bir balık kovası; sapına lacivert bir kaptan şapkasının ipi takılmış."},
			{"id": "c3", "pos": Vector2(1610, 1690), "text": "Kumda balık pulları; izler deniz iskelesine, teknelere doğru gidiyor."}],
		"suspects": [
			{"id": "s1", "name": "Tayfa Bülent", "pos": Vector2(1730, 1790), "app": {"skin": 2, "hair": 3, "hair_color": 0, "shirt": 1, "pants": 1},
				"says": "Bütün gece teknedeydim, iskeleye hiç gitmedim! Botlarım mı? 44... ama herkes giyer bunları. Şapkamı da geçen hafta kaybettim zaten."},
			{"id": "s2", "name": "Balıkçı Kadir", "pos": Vector2(760, 1470), "app": {"skin": 3, "hair": 0, "hair_color": 6, "shirt": 7, "pants": 3},
				"says": "Altın balık mı? Ben sazan tutarım, kovam da hep yanımda. Ayakkabım 41 numara, bak istersen."},
			{"id": "s3", "name": "Turist Mia", "pos": Vector2(1250, 1720), "app": {"skin": 0, "hair": 2, "hair_color": 4, "shirt": 9, "pants": 2},
				"says": "Gece yürüyüşteydim. Lacivert şapkalı, iri botlu biri elinde kovayla deniz iskelesine koşuyordu!"}],
		"culprit": "s1"},
	{"id": "sahte_para", "name": "Bankada Sahte Para", "reward": 2000,
		"brief": "Bankaya sahte 200 TL'likler yatırılmış. Para nerede basıldı, kim dağıtıyor?",
		"clues": [
			{"id": "c1", "pos": Vector2(1170, 372), "text": "Kumarhanenin kapısında düşmüş sahte bir 200 TL; mürekkebi hâlâ ıslak."},
			{"id": "c2", "pos": Vector2(780, 4090), "text": "Fabrikanın arka deposunda yeşil mürekkep lekeleri ve kesilmiş kâğıt şeritleri."},
			{"id": "c3", "pos": Vector2(1345, 3600), "text": "Liman iskelesinde bir yaka kartı: \"Fabrika — Gece Vardiyası — Y.\""}],
		"suspects": [
			{"id": "s1", "name": "Kumarbaz Selim", "pos": Vector2(1310, 400), "app": {"skin": 1, "hair": 4, "hair_color": 0, "shirt": 11, "pants": 0},
				"says": "Ben oynarım, para basmam! Dün gece fabrika tulumlu biri koca tomarlarla masaya oturdu, hep 200'lük."},
			{"id": "s2", "name": "Ustabaşı Nurten", "pos": Vector2(820, 4060), "app": {"skin": 0, "hair": 1, "hair_color": 2, "shirt": 8, "pants": 4},
				"says": "Depo anahtarı sadece bende ve gece vardiyasındaki Yavuz'da. Ben dün akşam altıda evdeydim."},
			{"id": "s3", "name": "Vardiyacı Yavuz", "pos": Vector2(1120, 3725), "app": {"skin": 3, "hair": 2, "hair_color": 1, "shirt": 3, "pants": 1},
				"says": "Yaka kartımı kaybettim, olur öyle. Kumarhane mi? Ben ömrümde kumarhaneye adım atmadım!"}],
		"culprit": "s3"},
	{"id": "dag_erzak", "name": "Dağ Evi'nin Kayıp Erzakı", "reward": 2200,
		"brief": "Dağ Evi'nin kışlık erzak sandığı bir gecede boşaltılmış. Dağda kim ne gördü?",
		"clues": [
			{"id": "c1", "pos": Vector2(8520, 2150), "text": "Maden ocağının girişinde un izi... ama madencilerin ayak izleri ters yöne gidiyor."},
			{"id": "c2", "pos": Vector2(8150, 2600), "text": "Kamp ateşinin küllerinde gözleme kâğıtları ve yanmış bir kayak eldiveni."},
			{"id": "c3", "pos": Vector2(9930, 2610), "text": "Telesiyej kulübesinde Dağ Evi damgalı boş bir sandık."}],
		"suspects": [
			{"id": "s1", "name": "Madenci Rıfat", "pos": Vector2(8720, 2200), "app": {"skin": 4, "hair": 0, "hair_color": 0, "shirt": 5, "pants": 3},
				"says": "Un mu? Biz öğle yemeğimizi evden getiririz. Madende kalın iş eldiveni giyeriz, kayak eldiveni değil."},
			{"id": "s2", "name": "Kayak Hocası Deniz", "pos": Vector2(9820, 2720), "app": {"skin": 1, "hair": 2, "hair_color": 3, "shirt": 10, "pants": 0},
				"says": "Kulübe benim ama o sandığı ben koymadım! Dün gece de... kampa hiç gitmedim, yemin ederim."},
			{"id": "s3", "name": "Kampçı Ece", "pos": Vector2(8020, 2470), "app": {"skin": 0, "hair": 1, "hair_color": 5, "shirt": 2, "pants": 2},
				"says": "Dün gece ateşin başında kayak hocası Deniz'i gördüm, sırtında kocaman bir çanta vardı, gözleme pişiriyordu."}],
		"culprit": "s2"},
	{"id": "muze_fosil", "name": "Müzeden Kaybolan Fosil", "reward": 3000,
		"brief": "Müzenin en değerli parçası Dinozor Kemiği vitrinden kaybolmuş. Sanayi'de iz sür.",
		"clues": [
			{"id": "c1", "pos": Vector2(1290, 3830), "text": "Müzenin yan kapısında saman çöpleri ve taze nal izleri."},
			{"id": "c2", "pos": Vector2(1500, 3990), "text": "Haranın samanlığında gazeteye sarılı uzun bir şeklin izi... ama paket yok."},
			{"id": "c3", "pos": Vector2(1300, 3460), "text": "Feribot iskelesinde bir kargo etiketi: \"Bay V. — Özel Koleksiyon — Kırılacak eşya\"."}],
		"suspects": [
			{"id": "s1", "name": "Bekçi Halil", "pos": Vector2(1000, 4100), "app": {"skin": 2, "hair": 4, "hair_color": 6, "shirt": 4, "pants": 0},
				"says": "Gece nöbetteydim, kimse içeri girmedi. Sadece hara seyisi samanları getirdi, onu da Bay Vural istemiş."},
			{"id": "s2", "name": "Seyis Murat", "pos": Vector2(1470, 4000), "app": {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 1},
				"says": "Bay Vural bana para verdi, \"şu paketi saman arasında limana taşı\" dedi. İçinde ne var bilmiyordum!"},
			{"id": "s3", "name": "Koleksiyoncu Vural", "pos": Vector2(1420, 3720), "app": {"skin": 1, "hair": 0, "hair_color": 6, "shirt": 11, "pants": 4},
				"says": "Ben sadece feribot bekliyorum. Fosil mi? Ben antika halı koleksiyoncusuyum, kemikle ne işim olur?"}],
		"culprit": "s3"},
]

# --- istemci
var state := {}                    # {case, clues, talked, solved, says: {sid: metin}, wrong_until}


func reset() -> void:
	state = {}


func active_case() -> Dictionary:
	var c := int(state.get("case", -1))
	return CASES[c] if c >= 0 and c < CASES.size() else {}


func has_clue(cid: String) -> bool:
	return cid in state.get("clues", [])


func talked(sid: String) -> bool:
	return sid in state.get("talked", [])


# ------------------------------------------------------------------ istemci API

func take_case() -> void:
	Net.ask(self, "req_take")


func inspect(cid: String) -> void:
	Net.ask(self, "req_clue", {"c": cid})


func question(sid: String) -> void:
	Net.ask(self, "req_talk", {"s": sid})


func accuse(sid: String) -> void:
	Net.ask(self, "req_accuse", {"s": sid})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	state = d
	changed.emit()


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func _data(rec: Dictionary) -> Dictionary:
	if not rec.get("detective") is Dictionary:
		rec["detective"] = {"case": -1, "clues": [], "talked": [], "solved": [], "wrong": 0, "wrong_until": 0.0}
	return rec.detective


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var d := _data(rec)
	var says := {}
	var c := int(d.case)
	if c >= 0 and c < CASES.size():
		for s in CASES[c].suspects:
			if s.id in d.talked:
				says[s.id] = s.says
	Net.tell(self, id, "on_state", {"case": c, "clues": d.clues, "talked": d.talked, "solved": d.solved, "says": says,
		"wrong": int(d.wrong), "wrong_left": maxf(0.0, float(d.get("wrong_until", 0.0)) - Time.get_unix_time_from_system())})


func _near(id: int, p: Vector2, r := RANGE) -> bool:
	return Net.positions.get(id, Vector2(-9999, -9999)).distance_to(p) <= r + 40.0


@rpc("any_peer", "call_remote", "reliable")
func req_take(_d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty() or not _near(id, Map.DETECTIVE, 90.0):
		return
	var d := _data(rec)
	if int(d.case) >= 0:
		return
	var next: int = d.solved.size()
	if next >= CASES.size():
		Net.notify(id, "Bütün vakaları çözdün, Baş Dedektif! Yeni vakalar yakında.")
		return
	d["case"] = next
	d["clues"] = []
	d["talked"] = []
	d["wrong"] = 0
	Net.mark_dirty()
	send_state(id)
	Net.notify(id, "Yeni vaka: %s. İpuçlarını ve şüphelileri haritada işaretleyebilirsin (dosya)." % CASES[next].name)


@rpc("any_peer", "call_remote", "reliable")
func req_clue(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var dd := _data(rec)
	var c := int(dd.case)
	if c < 0:
		return
	var cid := str(d.get("c", ""))
	for cl in CASES[c].clues:
		if cl.id == cid and not cid in dd.clues and _near(id, cl.pos):
			dd.clues.append(cid)
			Rpg.add_xp(id, "", 20)
			Net.mark_dirty()
			send_state(id)
			Net.notify(id, "İpucu bulundu: %s" % cl.text)
			return


@rpc("any_peer", "call_remote", "reliable")
func req_talk(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var dd := _data(rec)
	var c := int(dd.case)
	if c < 0:
		return
	var sid := str(d.get("s", ""))
	for s in CASES[c].suspects:
		if s.id == sid and _near(id, s.pos):
			if not sid in dd.talked:
				dd.talked.append(sid)
				Net.mark_dirty()
			send_state(id)
			Net.notify(id, "%s: \"%s\"" % [s.name, s.says])
			return


@rpc("any_peer", "call_remote", "reliable")
func req_accuse(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	var dd := _data(rec)
	var c := int(dd.case)
	if c < 0:
		return
	var cs: Dictionary = CASES[c]
	if dd.clues.size() < cs.clues.size() or dd.talked.size() < cs.suspects.size():
		Net.notify(id, "Suçlamak için önce bütün ipuçlarını topla ve herkesi sorgula.", false)
		return
	var now := Time.get_unix_time_from_system()
	if now < float(dd.get("wrong_until", 0.0)):
		Net.notify(id, "Komiser biraz düşünmeni istiyor (%d sn)." % int(float(dd.wrong_until) - now), false)
		return
	var sid := str(d.get("s", ""))
	if sid != str(cs.culprit):
		dd["wrong"] = int(dd.wrong) + 1
		dd["wrong_until"] = now + WRONG_COOLDOWN
		Net.mark_dirty()
		send_state(id)
		Net.notify(id, "Yanlış kişi! Delillere bir daha bak. (%d dk sonra tekrar suçlayabilirsin, ödül azalır)" % int(WRONG_COOLDOWN / 60.0), false)
		return
	var mult := maxf(0.4, 1.0 - 0.3 * int(dd.wrong))
	var reward := int(round(int(cs.reward) * mult))
	dd.solved.append(cs.id)
	dd["case"] = -1
	dd["clues"] = []
	dd["talked"] = []
	dd["wrong"] = 0
	Net.add_money(id, reward)
	Rpg.add_xp(id, "police", 120)
	Rpg.add_xp(id, "", 150)
	Ach.event(id, "cases")
	Net.mark_dirty()
	send_state(id)
	var culprit := ""
	for s in cs.suspects:
		if s.id == sid:
			culprit = s.name
	Net.notify(id, "Vaka çözüldü: %s! Suçlu %s. Ödül: %s" % [cs.name, culprit, U.money(reward)])
	Net.announce("Dedektif %s \"%s\" vakasını çözdü!" % [Net.players[id].name, cs.name])
