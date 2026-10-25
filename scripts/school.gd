extends Node
## Okul ve kurslar (1.4). Kurs ücretini öde, 5 soruluk sınava gir (en az 4 doğru), diplomanı al.
## Diplomalar kalıcı bonus verir. Sorular ve doğru cevaplar sunucudadır; istemci sadece seçtiğini gönderir.
## Kalan: 2 dk sonra yarı ücretle tekrar.  Veri: rec.rpg["diplomas"] = [kurs, ...]

signal changed
signal exam(d: Dictionary)
signal result(d: Dictionary)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const PASS := 4
const QUESTIONS := 5
const RETRY_COOLDOWN := 120.0

# kurs: ad, ücret, bonus açıklaması, sorular [soru, [şıklar], doğru indeks]
const COURSES := {
	"asci": {"name": "Aşçılık Kursu", "fee": 800, "perk": "Pişirdiğin yemek %30 ihtimalle 2 porsiyon olur", "qs": [
		["Menemen için hangisi gerekir?", ["Domates ve yumurta", "Süt ve buğday", "Balkabağı"], 0],
		["Sütlaç hangi malzemelerle yapılır?", ["Süt ve buğday (pirinç yerine)", "Domates ve lahana", "Balık ve domates"], 0],
		["Su böreğinde hangisi YOKTUR?", ["Yumurta", "Buğday", "Balık"], 2],
		["Kabak tatlısı hangi mevsimin ürünüyle yapılır?", ["Sonbahar", "Yaz", "İlkbahar"], 0],
		["Mantar sote için ormandan ne toplanır?", ["Çayır mantarı", "Sinek mantarı", "Çam kozalağı"], 0],
		["Sinek mantarı (kırmızı, beyaz benekli) yenir mi?", ["Hayır, zehirlidir", "Evet, çok lezzetlidir", "Sadece pişince"], 0],
		["Ocak olmadan yemek nerede pişirilebilir?", ["Kendi kafende ya da restoranında", "Markette", "Bankada"], 0],
		["Izgara balık hangi bonusu verir?", ["Nadir balık şansı", "XP bonusu", "Hiç bonus vermez"], 0]]},
	"surucu": {"name": "Sürücü Kursu", "fee": 1000, "perk": "Araba ve bisiklet %10 daha hızlı", "qs": [
		["Kırmızı ışıkta ne yapılır?", ["Durulur", "Hızlanılır", "Korna çalınır"], 0],
		["Yaya geçidinde yaya varsa?", ["Durup yol verilir", "Selektör yapılır", "Hızla geçilir"], 0],
		["Emniyet kemeri ne zaman takılır?", ["Her yolculukta", "Sadece otoyolda", "Gece"], 0],
		["Şehir içinde hız sınırı genelde kaçtır?", ["50 km/sa", "120 km/sa", "20 km/sa"], 0],
		["Ambulans sireni duyunca?", ["Sağa çekip yol verilir", "Peşine takılınır", "Durmadan devam edilir"], 0],
		["Yağmurda takip mesafesi nasıl olmalı?", ["Artırılmalı", "Azaltılmalı", "Fark etmez"], 0],
		["Telefonla konuşurken araba kullanmak?", ["Tehlikelidir ve yasaktır", "Serbesttir", "Sadece mesaj yazılabilir"], 0],
		["Otobüs durağında duran otobüsün arkasında?", ["Sabırla beklenir ya da dikkatle geçilir", "Korna çalınır", "Otobüse çarpılır"], 0]]},
	"muzik": {"name": "Müzik Okulu", "fee": 900, "perk": "Sahne kazancı +%20", "qs": [
		["Bir müzik aletinde 'ritim' en çok hangisiyle tutulur?", ["Davul", "Flüt", "Arp"], 0],
		["Do-Re-Mi dizisinde Re'den sonra ne gelir?", ["Mi", "Fa", "Sol"], 0],
		["Metronom ne işe yarar?", ["Tempoyu tutar", "Sesi yükseltir", "Teli akort eder"], 0],
		["BPM ne demektir?", ["Dakikadaki vuruş sayısı", "Ses yüksekliği", "Nota uzunluğu"], 0],
		["Gitarın kaç teli vardır (klasik)?", ["6", "4", "12"], 0],
		["Konserde seyirci ne getirir?", ["Bahşiş ve kazanç bonusu", "Ceza", "Hiçbir şey"], 0],
		["Birlikte çalan müzisyenlere ne denir?", ["Grup", "Takım elbise", "Orkestra şefi"], 0],
		["Piyanonun tuşları hangi renklerdedir?", ["Siyah ve beyaz", "Kırmızı ve mavi", "Yeşil"], 0]]},
	"dalgic": {"name": "Dalgıçlık Kursu", "fee": 1200, "perk": "Dalışta +20 sn oksijen", "qs": [
		["Dalıştan yüzeye nasıl çıkılır?", ["Yavaşça", "Olabildiğince hızlı", "Nefesi tutarak hızla"], 0],
		["Tek başına dalmak mı, eşli dalmak mı güvenlidir?", ["Eşli dalış", "Tek başına", "Fark etmez"], 0],
		["Fırtınada dalış yapılır mı?", ["Hayır", "Evet", "Sadece gece"], 0],
		["Dalış tüpü ne sağlar?", ["Daha uzun süre oksijen", "Daha hızlı yüzme", "Işık"], 0],
		["Mercanlara dokunmak doğru mu?", ["Hayır, zarar verir", "Evet, şans getirir", "Sadece eldivenle"], 0],
		["İstiridyeden ne çıkabilir?", ["İnci", "Altın", "Kömür"], 0],
		["Batık gemide ne bulunabilir?", ["Hazine sandığı", "Ateş", "Kar"], 0],
		["Su altında el işaretiyle 'tamam' nasıl denir?", ["Baş ve işaret parmağıyla halka", "El sallayarak", "Yumrukla"], 0]]},
	"finans": {"name": "Finans Kursu", "fee": 1500, "perk": "Kira gelirlerin +%10", "qs": [
		["Bankaya yatırılan paranın getirdiği kazanca ne denir?", ["Faiz", "Vergi", "Kira"], 0],
		["Hisse senedi neyi temsil eder?", ["Bir şirketin ortaklık payını", "Bir borcu", "Bir faturayı"], 0],
		["Ucuzken alıp pahalıyken satmak?", ["Kâr getirir", "Zarar getirir", "Yasaktır"], 0],
		["Bütçe nedir?", ["Gelir ve giderlerin planı", "Bir banka şubesi", "Bir hisse türü"], 0],
		["Yatırımda riski azaltmanın yolu?", ["Çeşitlendirmek", "Hepsini tek hisseye yatırmak", "Hiç takip etmemek"], 0],
		["Kira geliri hangi mülkten gelir?", ["Evin ya da arsandan", "Arabadan", "Balıktan"], 0],
		["Enflasyon neyi düşürür?", ["Paranın alım gücünü", "Faiz oranını her zaman", "Nüfusu"], 0],
		["Belediye vergisi nereye harcanır?", ["Şehre", "Kumarhaneye", "Hiçbir yere"], 0]]},
	"binicilik": {"name": "Binicilik Okulu", "fee": 1000, "perk": "Hipodromda atın %3 daha hızlı", "qs": [
		["Ata binmeden önce ne yapılır?", ["Beslenip hazırlanır", "Hemen dörtnala sürülür", "Hiçbir şey"], 0],
		["Atın ayağına çakılan demire ne denir?", ["Nal", "Eyer", "Gem"], 0],
		["Yarışta kamçıyı ne zaman kullanmak akıllıcadır?", ["Son düzlükte", "Başlar başlamaz sürekli", "Hiç"], 0],
		["Atlar ne yer?", ["Saman, yem, mısır", "Et", "Balık"], 0],
		["Atın en hızlı koşusuna ne denir?", ["Dörtnala", "Tırıs", "Adım"], 0],
		["Biniciyi atın sırtında tutan takım?", ["Eyer", "Yular", "Kantar"], 0],
		["Yorgun ata ne yapılmalı?", ["Dinlendirilmeli", "Daha çok koşturulmalı", "Kamçılanmalı"], 0],
		["Hipodromda bahiste oran neyi gösterir?", ["Kazanırsa paranın kaç katı döneceğini", "Atın yaşını", "Kulvar sayısını"], 0]]},
	"ilkyardim": {"name": "İlk Yardım Kursu", "fee": 700, "perk": "Hastane maaşı +%15", "qs": [
		["Acil durumda ilk aranan numara?", ["112", "155", "110"], 0],
		["Kanayan yaraya ne yapılır?", ["Temiz bezle bastırılır", "Su dökülür", "Açık bırakılır"], 0],
		["Yanığa ne uygulanır?", ["Soğuk (buz değil) su", "Diş macunu", "Yağ"], 0],
		["Bilinci kapalı ama nefes alan kişi nasıl yatırılır?", ["Yan (koma) pozisyonu", "Yüzüstü", "Ayakta tutulur"], 0],
		["Kırık şüphesinde?", ["Hareket ettirilmez, sabitlenir", "Ovulur", "Yürütülür"], 0],
		["Boğulma (Heimlich) nereye bası uygular?", ["Karın üst kısmına", "Sırta", "Bacağa"], 0],
		["Güneş çarpmasında?", ["Serin yere alınır, su verilir", "Güneşte bekletilir", "Kalın örtülür"], 0],
		["İlk yardımda önce ne kontrol edilir?", ["Çevre güvenliği ve bilinç", "Cüzdan", "Telefon"], 0]]},
}

# --- istemci
var diplomas: Array = []
var current := {}                  # sınav: {course, qs: [{q, opts}]}

# --- sunucu
var _exams := {}                   # id -> {course, picks: [[soru idx, şık sırası]]}


func reset() -> void:
	diplomas = []
	current = {}
	_exams.clear()


func on_player_left(id: int) -> void:
	_exams.erase(id)


func has(k: String) -> bool:
	return k in diplomas


## Sunucu tarafı: oyuncunun diploması var mı?
func has_by_id(id: int, k: String) -> bool:
	var rec: Dictionary = Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}
	return not rec.is_empty() and k in Rpg.ensure(rec).get("diplomas", [])


# ------------------------------------------------------------------ istemci API

func start_exam(k: String) -> void:
	Net.ask(self, "req_exam", {"k": k})


func answer(answers: Array) -> void:
	Net.ask(self, "req_answers", {"a": answers})


@rpc("authority", "call_local", "reliable")
func on_state(d: Dictionary) -> void:
	diplomas = d.get("diplomas", [])
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_exam(d: Dictionary) -> void:
	current = d
	exam.emit(d)


@rpc("authority", "call_local", "reliable")
func on_result(d: Dictionary) -> void:
	current = {}
	result.emit(d)


# ------------------------------------------------------------------ sunucu

func _rec(id: int) -> Dictionary:
	return Net.save_data.players.get(Net.players[id].name, {}) if Net.players.has(id) else {}


func send_state(id: int) -> void:
	var rec := _rec(id)
	if not rec.is_empty():
		Net.tell(self, id, "on_state", {"diplomas": Rpg.ensure(rec).get("diplomas", [])})


@rpc("any_peer", "call_remote", "reliable")
func req_exam(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var k := str(d.get("k", ""))
	if rec.is_empty() or not COURSES.has(k) or _exams.has(id):
		return
	if not Map.building("okul").rect.grow(70).has_point(Net.positions.get(id, Vector2(-9999, -9999))):
		Net.notify(id, "Sınava okulda girilir.", false)
		return
	var r := Rpg.ensure(rec)
	if not r.get("diplomas") is Array:
		r["diplomas"] = []
	if k in r.diplomas:
		Net.notify(id, "Bu kursun diploması zaten sende.", false)
		return
	if not r.get("exam_fail") is Dictionary:
		r["exam_fail"] = {}
	var now := Time.get_unix_time_from_system()
	var failed_at := float(r.exam_fail.get(k, 0.0))
	if now - failed_at < RETRY_COOLDOWN:
		Net.notify(id, "Tekrar sınava girmek için %d sn bekle." % int(RETRY_COOLDOWN - (now - failed_at)), false)
		return
	var fee := int(COURSES[k].fee) / (2 if failed_at > 0.0 else 1)
	if not Net.try_spend(id, fee):
		Net.notify(id, "Kurs ücreti %s." % U.money(fee), false)
		return
	var idx: Array = range(COURSES[k].qs.size())
	idx.shuffle()
	var picks: Array = []
	var out: Array = []
	for qi in idx.slice(0, QUESTIONS):
		var q: Array = COURSES[k].qs[qi]
		var order: Array = range(q[1].size())
		order.shuffle()
		picks.append([qi, order])
		out.append({"q": q[0], "opts": order.map(func(o): return q[1][o])})
	_exams[id] = {"course": k, "picks": picks}
	Net.tell(self, id, "on_exam", {"course": k, "name": COURSES[k].name, "qs": out})


@rpc("any_peer", "call_remote", "reliable")
func req_answers(d: Dictionary) -> void:
	var id := Net.sender()
	if not _exams.has(id):
		return
	var e: Dictionary = _exams[id]
	_exams.erase(id)
	var answers: Array = d.get("a", [])
	var k: String = e.course
	var right := 0
	for i in e.picks.size():
		var qi: int = e.picks[i][0]
		var order: Array = e.picks[i][1]
		var correct: int = COURSES[k].qs[qi][2]
		if i < answers.size() and int(answers[i]) >= 0 and int(answers[i]) < order.size() and int(order[int(answers[i])]) == correct:
			right += 1
	var r := Rpg.ensure(_rec(id))
	var ok := right >= PASS
	if ok:
		r.diplomas.append(k)
		r.exam_fail.erase(k)
		Ach.event(id, "diplomas")
		Rpg.add_xp(id, "", 100)
		Net.announce("%s %s diplomasını aldı!" % [Net.players[id].name, COURSES[k].name])
	else:
		r.exam_fail[k] = Time.get_unix_time_from_system()
	Net.mark_dirty()
	send_state(id)
	Rpg.send_sheet(id)
	Net.tell(self, id, "on_result", {"ok": ok, "right": right, "course": k,
		"text": ("Tebrikler! %d/%d doğru — %s diploması senin. Bonus: %s" % [right, QUESTIONS, COURSES[k].name, COURSES[k].perk]) if ok
			else "%d/%d doğru, geçmek için %d gerekli. 2 dk sonra yarı ücretle tekrar dene." % [right, QUESTIONS, PASS]})
