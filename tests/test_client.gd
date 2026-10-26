extends Node
## Otomatik duman testi. Kullanım:
##   godot --headless --path . -- --test-istemci   (127.0.0.1:7777'deki sunucuya bağlanır)
##   godot --headless --path . -- --test-host      (kendi sunucusunu kurar, yerel çağrı yolunu dener)

var errors := 0
var hands := 0
var _last_msg := ""
var _acted_turn := ""
var _phase := "main"        # main -> wrong_pass -> right_pass
var _port := 7777
var _chats: Array = []
const PASS := "test1234"


func check(cond: bool, what: String) -> void:
	if cond:
		print("  OK   ", what)
	else:
		errors += 1
		print("  HATA ", what)


func _ready() -> void:
	_unit_tests()
	Net.connected_ok.connect(_on_ok)
	Net.connection_failed.connect(_on_failed)
	Jobs.fish_event.connect(_on_fish)
	Jobs.hospital_case.connect(func(d): print("[hastane] ", d.symptom, " -> ", d.options); Jobs.answer_hospital(randi() % 4))
	Jobs.market_case.connect(_on_market)
	Jobs.job_result.connect(func(d): print("[iş] ", d.text))
	Casino.result.connect(func(d): print("[kumarhane] ", d))
	Net.toast.connect(func(t, _g): print("[bildirim] ", t))
	Net.chat_received.connect(func(n, t, _c, ch): print("[sohbet:%s] " % ch, n, ": ", t); _chats.append([ch, t]))
	Poker.table_changed.connect(_on_table)
	var args := OS.get_cmdline_user_args()
	var err := ""
	if "--test-host" in args:
		Net.save_path = "user://test_kayit.json"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Net.save_path))
		err = Net.host("EvSahibi", 7791, false, Net.hash_password("EvSahibi", PASS))
	else:
		var port := Net.DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="):
				port = int(a.trim_prefix("--port="))
		_port = port
		err = Net.join("Testci", "127.0.0.1", port, Net.hash_password("Testci", PASS), {"skin": 2, "hair": 1, "hair_color": 4, "shirt": 7, "pants": 1})
	if err != "":
		print(err)
		get_tree().quit(1)


func _unit_tests() -> void:
	print("== El değerlendirme testleri")
	var P = Poker
	check(P.eval5([12, 11, 10, 9, 8]) == [8, 12], "Royal floş")
	check(P.hand_name(P.eval5([12, 11, 10, 9, 8])) == "Royal Floş", "Royal floş adı")
	check(P.eval5([12, 13, 27, 41, 3]) == [4, 3], "A-2-3-4-5 kent (as küçük)")
	check(P.eval5([0, 13, 26, 39, 5])[0] == 7, "Kare")
	check(P.eval5([0, 13, 26, 1, 14]) == [6, 0, 1], "Ful")
	check(P.eval5([0, 2, 4, 6, 9])[0] == 5, "Floş")
	check(P.eval5([0, 13, 1, 14, 30]) == [2, 1, 0, 4], "Döper")
	check(P.cmp(P.eval5([12, 25, 0, 1, 2]), P.eval5([11, 24, 0, 1, 2])) > 0, "As per > Papaz per")
	var seven := [12, 25, 38, 0, 13, 5, 7]   # üç as + iki ikili = ful
	check(P.best_hand(seven) == [6, 12, 0], "7 karttan en iyi el (ful)")
	check(P.cmp(P.best_hand([12, 11, 10, 9, 8, 0, 1]), P.best_hand([12, 25, 38, 51, 0, 1, 2])) > 0, "Royal floş > kare")
	# 7 kartlık rastgele ellerde dağılım (beklenen: yüksek kart ~%17, per ~%44, döper ~%23, kent ~%4.6)
	var counts := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var n := 600
	for _i in n:
		var deck: Array = range(52)
		deck.shuffle()
		counts[P.best_hand(deck.slice(0, 7))[0]] += 1
	var dist := ""
	for c in 9:
		dist += "%s %.1f%%  " % [P.HAND_NAMES[c], 100.0 * counts[c] / n]
	print("  dağılım: ", dist)
	check(counts[4] < n * 0.1 and counts[1] > n * 0.3, "el dağılımı gerçekçi")


func _on_failed(reason: String) -> void:
	if _phase == "wrong_pass":
		check(reason.contains("Şifre yanlış"), "yanlış şifre reddedildi (%s)" % reason)
		_phase = "right_pass"
		await _wait(0.5)
		Net.join("Testci", "127.0.0.1", _port, Net.hash_password("Testci", PASS))
		return
	print("BAĞLANTI HATASI: ", reason)
	get_tree().quit(1)


func _on_ok() -> void:
	if _phase == "right_pass":
		check(true, "doğru şifreyle tekrar girildi")
		await _wait(0.5)
		var app: Dictionary = Net.roster[Net.my_id()].appearance
		check(int(app.shirt) == 3, "karakter görünümü hesapta saklandı")
		_finish()
		return
	print("== Bağlandı: %s, para %d" % [Net.my_name, Net.my_money()])
	if Net.is_server():
		Holidays.force("yok")          # testler takvimden bağımsız (1.5 testi özel günleri tek tek açar)
	# hızlı deneme: --bolum=11,13 sadece o bölümleri çalıştırır
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bolum="):
			await _wait(0.5)
			Rpg.add_xp(Net.my_id(), "", 20000)
			for b in arg.trim_prefix("--bolum=").split(","):
				await call("_test_" + b.pad_zeros(2), get_parent().world)
			_finish()
			return
	check(Net.my_name != "", "isim atandı")
	await _wait(0.6)
	check(Net.my_money() > 0, "başlangıç parası geldi")
	check(Land.view.size() == 12, "12 arsa geldi")
	check(not Poker.view.is_empty(), "poker masası görünümü geldi")
	var w = get_parent().world
	check(w != null, "dünya sahnesi oluştu")

	print("== Karakter")
	var app0: Dictionary = Net.roster[Net.my_id()].get("appearance", {})
	check(app0.size() == 8, "görünüm roster'da var (aksesuarlar dahil)")
	w.open_character_editor()
	await get_tree().process_frame
	check(w.panel != null, "karakter düzenleyici açıldı")
	w._close_panel()
	Net.set_appearance({"skin": 1, "hair": 3, "hair_color": 2, "shirt": 3, "pants": 9})
	await _wait(0.4)
	var app1: Dictionary = Net.roster[Net.my_id()].appearance
	check(int(app1.shirt) == 3 and int(app1.hair) == 3, "görünüm değiştirildi")
	check(int(app1.pants) == 5, "geçersiz değer sunucuda sınırlandı")

	print("== Panelleri aç/kapat")
	for k in w.PANELS:
		w.zone = {"type": k, "label": k}
		w._open_panel()
		await get_tree().process_frame
		await get_tree().process_frame
		check(w.panel != null, "%s paneli açıldı" % k)
		w._close_panel()

	print("== Hareket ve sohbet")
	w.my_pos += Vector2(50, 0)
	Net.send_chat("Merhaba şehir!")
	await _wait(0.5)

	print("== Arsa")
	var m0 := Net.my_money()
	var free_plot := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			free_plot = i
			break
	Land.buy(free_plot)
	await _wait(0.5)
	check(Land.view[free_plot].owner == Net.my_name, "arsa #%d satın alındı" % (free_plot + 1))
	# (görev ödülü / seviye ödülü gelebileceği için tam eşitlik aranmaz)
	check(Net.my_money() < m0, "arsa parası düştü")
	var can_build := Net.my_money() >= Land.BUILD_COST[1]
	Land.build_up(free_plot)
	await _wait(0.5)
	check(int(Land.view[free_plot].level) == (1 if can_build else 0), "inşaat parası kontrolü (para yeterli: %s)" % can_build)

	print("== Kumarhane (panel açıkken)")
	w.zone = {"type": "casino", "label": "x"}
	w._open_panel()
	Casino.roulette(50, "red")
	Casino.dice(50, "seven")
	Casino.horse(50, 0)
	Casino.roulette(10, "num", 17)
	await _wait(5.5)
	w._close_panel()

	print("== Balık")
	w.my_pos = Vector2(-500, -500) + Vector2(600, 600)
	await _wait(0.4)
	Jobs.cast()
	await _wait(0.4)
	check(Jobs._fish.is_empty() or not Net.is_server(), "iskele dışında olta atılamaz")
	var Map = preload("res://scripts/map.gd")
	w.my_pos = Map.DOCK.get_center()
	await _wait(0.4)
	for _k in 2:
		Jobs.cast()
		await _wait(9.5)
	w.my_pos = Map.PIER_END.get_center()
	await _wait(0.4)
	Jobs.cast()
	await _wait(0.5)
	if Rpg.sheet.get("level", 1) < Rpg.LEVEL_GATES.sea:
		check(Jobs._fish.is_empty() or not Net.is_server(), "Sv.%d altında deniz balıkçılığı kilitli" % Rpg.LEVEL_GATES.sea)
	else:
		await _wait(9.0)
	check(Jobs.my_fish.size() >= 2, "balık yakalandı (%d)" % Jobs.my_fish.size())
	w.my_pos = Vector2(1200, 2100)
	await _wait(0.3)
	check(Map.in_sea(w.my_pos), "denizde yüzülebiliyor")
	w.my_pos = Map.SPAWN
	await _wait(0.3)
	Jobs.sell_fish()
	await _wait(0.3)
	check(not Jobs.my_fish.is_empty(), "balık Pazar Yeri dışında satılmıyor")
	w.my_pos = Map.building("pazar").rect.get_center()
	await _wait(0.3)
	Jobs.sell_fish()
	await _wait(0.5)
	check(Jobs.my_fish.is_empty(), "balıklar Pazar Yeri'nde satıldı")

	print("== Hastane ve market")
	for _k in 3:
		Jobs.ask_hospital()
		await _wait(0.4)
	var before := Net.my_money()
	for _k in 3:
		Jobs.ask_market()
		await _wait(0.4)
	check(Net.my_money() > before, "market işinden para kazanıldı")

	print("== RPG")
	await _wait(0.5)
	var sh := Rpg.sheet
	check(not sh.is_empty(), "karakter kartı geldi (Sv.%d, %d XP)" % [sh.get("level", 0), sh.get("xp", 0)])
	check(int(sh.xp) > 0 and int(sh.skills.cashier.xp) > 0, "işlerden XP ve kasiyerlik XP'si kazanıldı")
	# (seviye atlanırsa enerji dolar; o durumda harcamayı ayrıca dene)
	check(float(sh.energy) < float(sh.max_energy) or int(sh.level) > 1, "işler enerji harcadı (%d/%d, Sv.%d)" % [int(sh.energy), sh.max_energy, int(sh.level)])
	if float(Rpg.sheet.energy) >= float(Rpg.sheet.max_energy):
		if Net.is_server():
			Rpg.use_energy(Net.my_id(), 20)
		else:
			Jobs.ask_hospital()
			await _wait(0.4)
			Jobs.answer_hospital(-1)
		await _wait(0.4)
	check(sh.quests.size() == 3, "3 günlük görev var")
	Rpg.buy("simit")
	await _wait(0.4)
	check(not Rpg.sheet.items.has("simit"), "market dışında alışveriş reddedildi")
	for b in Map.BUILDINGS:
		if b.type == "market":
			w.my_pos = b.rect.get_center()
	await _wait(0.4)
	Rpg.buy("simit")
	await _wait(0.4)
	check(int(Rpg.sheet.items.get("simit", 0)) == 1, "markette simit alındı")
	var e0 := float(Rpg.sheet.energy)
	Rpg.use("simit")
	await _wait(0.4)
	check(not Rpg.sheet.items.has("simit") and float(Rpg.sheet.energy) > e0, "simit yendi, enerji arttı")
	w.my_pos = Map.SPAWN

	print("== Poker (2 bot ile, panel açık)")
	w.zone = {"type": "poker", "label": "x"}
	w._open_panel()
	Poker.add_bot()
	Poker.add_bot()
	Poker.sit(Poker.MIN_BUYIN)
	var t0 := Time.get_ticks_msec()
	while hands < 4 and Time.get_ticks_msec() - t0 < 200000:
		await _wait(0.5)
		# Biri fişlerini kaybedip masada tek kişi kalırsa oyun durur: yeni bot çağır.
		if _seat_count() < 2 and Poker.view.get("stage") == "idle":
			Poker.add_bot()
			await _wait(0.5)
	check(hands >= 4, "%d el oynandı" % hands)
	Poker.leave_table()
	Poker.remove_bots()
	await _wait(1.0)
	check(_seat_count() == 0 or Poker.view.stage != "idle", "masa boşaldı")
	w._close_panel()

	Land.sell(free_plot)
	await _wait(0.5)
	check(Land.view[free_plot].owner == "", "arsa satıldı")
	print("== Son para: %d" % Net.my_money())
	if Net.is_server():
		await _test_04(get_parent().world)
		await _test_05(get_parent().world)
		await _test_06(get_parent().world)
		await _test_07(get_parent().world)
		await _test_08(get_parent().world)
		await _test_09(get_parent().world)
		await _test_10(get_parent().world)
		await _test_11(get_parent().world)
		await _test_12(get_parent().world)
		await _test_13(get_parent().world)
		await _test_14(get_parent().world)
		await _test_15(get_parent().world)
		_finish()
		return
	print("== Durum sayfası (adanmış sunucu)")
	var page := await _http_get("127.0.0.1", _port + 3, "/json")
	var js = JSON.parse_string(page.get_slice("\r\n\r\n", 1)) if page.contains("\r\n\r\n") else null
	check(js is Dictionary and str(js.get("version", "")) == Net.VERSION and int(js.get("accounts", 0)) >= 1, "durum sayfası çalışıyor (http://127.0.0.1:%d)" % (_port + 3))
	print("== Şifre")
	_phase = "wrong_pass"
	Net.leave()
	await _wait(0.5)
	Net.join("Testci", "127.0.0.1", _port, Net.hash_password("Testci", "yanlis"))


func _helper_listing():
	for l in Bazaar.listings:
		if l.seller == "Yardimci" and l.kind == "food":
			return l
	return null


## 0.4 özellikleri (yalnızca ev sahibi modunda: test için sunucu tarafından para/XP verilir).
func _test_04(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	print("== 0.4: Gün/gece ve hava")
	check(Env.hour >= 0.0 and Env.hour < 24.0, "oyun saati çalışıyor (%s)" % Env.clock_text())
	Env.force_weather("rain")
	await _wait(0.3)
	check(Env.is_rainy() and Env.clock_text().contains(Env.weather_name()), "yağmur başladı ve saatte görünüyor (%s)" % Env.weather_name())
	Env.force_weather("storm")
	Net.add_money(me, 60000)
	Rpg.add_xp(me, "", 2600)
	await _wait(0.3)
	check(Rpg.level(me) >= 6, "test için seviye 6+ (Sv.%d)" % Rpg.level(me))
	w.my_pos = Map.PIER_END.get_center()
	await _wait(0.3)
	Jobs.cast()
	await _wait(0.3)
	check(not Jobs._fish.has(me), "fırtınada deniz balıkçılığı kapalı")
	Env.force_weather("clear")

	print("== 0.4: Araçlar")
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.3)
	for k in ["bike", "car", "boat"]:
		Garage.buy(k)
	await _wait(0.5)
	check(Garage.owned.size() == 3, "bisiklet, araba ve tekne alındı")
	w.my_pos = Map.SPAWN
	await _wait(0.3)
	Garage.ride("boat")
	await _wait(0.3)
	check(w.my_ride() == "", "karada tekneye binilemiyor")
	Garage.ride("car")
	await _wait(0.3)
	check(w.my_ride() == "car", "arabaya binildi (oyuncu listesinde görünüyor)")
	Garage.ride("")
	await _wait(0.2)
	w.my_pos = Vector2(400, 2150)
	await _wait(0.3)
	Garage.ride("boat")
	await _wait(0.3)
	check(w.my_ride() == "boat", "denizde tekneye binildi")
	Jobs.cast()
	await _wait(0.3)
	check(Jobs._fish.has(me) and Jobs._fish[me].spot == "boat", "tekneden açık deniz balıkçılığı")
	Jobs._fish.erase(me)
	Garage.ride("")
	await _wait(0.2)

	print("== 0.4: Ev ve mobilya")
	var plot := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			plot = i
			break
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot)
	await _wait(0.4)
	check(int(Land.view[plot].level) == 1, "arsaya ev inşa edildi")
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.3)
	for k in ["bed", "chair", "rug", "lamp"]:
		Homes.buy(k)
	await _wait(0.5)
	check(Homes.depot.size() == 4, "4 mobilya depoya geldi")
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Homes.enter(plot)
	await _wait(0.5)
	check(w._room == plot, "eve girildi (ışınlandı)")
	Homes.place(plot, "bed", 1, 1)
	await _wait(0.3)
	Homes.place(plot, "chair", 2, 2)      # yatağın üstü: reddedilmeli
	await _wait(0.3)
	Homes.place(plot, "rug", 0, 2)        # halı başka eşyanın altına girebilir
	await _wait(0.3)
	Homes.place(plot, "lamp", 8, 1)
	await _wait(0.3)
	var furn: Array = Land.view[plot].furniture
	check(furn.size() == 3, "3 eşya yerleşti, çakışan sandalye reddedildi (%d)" % furn.size())
	check(int(Homes.depot.get("chair", 0)) == 1, "reddedilen sandalye depoda kaldı")
	Rpg.use_energy(me, 40)
	await _wait(0.2)
	var e0 := float(Rpg.sheet.energy)
	w.my_pos = Homes.furniture_rect(plot, 1, furn[0]).get_center()
	await _wait(5.8)
	check(float(Rpg.sheet.energy) >= e0 + 4.0, "yatakta enerji hızla doldu (%d → %d)" % [int(e0), int(Rpg.sheet.energy)])
	Homes.set_door(plot, true)
	await _wait(0.3)
	check(bool(Land.view[plot].get("door_open", false)), "kapı misafirlere açıldı")
	Homes.exit_home()
	await _wait(0.5)
	check(w._room == -1, "evden çıkıldı")

	print("== 0.4: Pazar yeri ve para gönderme")
	w.my_pos = Map.building("pazar").rect.get_center()
	await _wait(0.3)
	Bazaar.list_item("furniture", "chair", 500)
	await _wait(0.3)
	var mine: Array = Bazaar.listings.filter(func(l): return l.seller == Net.my_name)
	check(mine.size() == 1 and not Homes.depot.has("chair"), "sandalye ilana çıktı (emanete alındı)")
	Bazaar.cancel(int(mine[0].id))
	await _wait(0.3)
	check(int(Homes.depot.get("chair", 0)) == 1, "ilan kaldırıldı, sandalye geri geldi")
	var helper := 0
	for _k in 60:
		helper = Net.id_by_name("Yardimci")
		if helper != 0 and _helper_listing() != null:
			break
		await _wait(0.5)
	if helper == 0 or _helper_listing() == null:
		print("  (yardımcı istemci yok: oyuncular arası ticaret testleri atlandı)")
	else:
		var l = _helper_listing()
		var hm0 := int(Net.players[helper].money)
		Bazaar.buy(int(l.id))
		await _wait(0.4)
		check(int(Rpg.sheet.items.get("simit", 0)) >= 1, "yardımcının ilanındaki simit satın alındı")
		check(int(Net.players[helper].money) == hm0 + 24, "satıcıya 25 TL - %5 komisyon = 24 TL geçti")
		var hm1 := int(Net.players[helper].money)
		Bazaar.send_money("Yardimci", 300)
		await _wait(0.3)
		check(int(Net.players[helper].money) == hm1 + 300, "yardımcıya 300 TL gönderildi")
	Bazaar.list_item("plot", plot, 9999)
	await _wait(0.3)
	check(Bazaar.plot_listed(plot), "arsa ilana çıktı")
	Land.sell(plot)
	await _wait(0.4)
	check(not Bazaar.plot_listed(plot) and Land.view[plot].owner == "", "arsa bankaya satılınca ilan düştü")
	check(int(Homes.depot.get("bed", 0)) == 1, "satılan evdeki mobilyalar depoya döndü")


## 0.5: satın alma kolaylıkları, evcil hayvanlar, işletmeler, hikâye görevleri, NPC'ler.
func _test_05(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 80000)
	await _wait(0.3)

	print("== 0.5: Mobilya geri satışı")
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.3)
	Homes.buy("chair")
	await _wait(0.3)
	var m0 := Net.my_money()
	var chairs := int(Homes.depot.get("chair", 0))
	Homes.sell_back("chair")
	await _wait(0.3)
	check(Net.my_money() == m0 + 100 and int(Homes.depot.get("chair", 0)) == chairs - 1, "sandalye yarı fiyatına (100 TL) geri satıldı")

	print("== 0.5: Evcil hayvan")
	w.my_pos = Map.building("petshop").rect.get_center()
	await _wait(0.3)
	Pets.buy("dog", "Karabaş")
	await _wait(0.4)
	check(Pets.my_pet.get("kind") == "dog" and Pets.my_pet.get("name") == "Karabaş", "köpek sahiplenildi (Karabaş)")
	check(Net.roster[me].get("pet", {}).get("name") == "Karabaş", "evcil hayvan herkesin listesinde görünüyor")
	check(Pets.bonus(me, "dog"), "tok köpek bonusu aktif")
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	rec.pet.food = 20.0
	check(not Pets.bonus(me, "dog"), "aç köpeğin bonusu durdu")
	Pets.feed(false)
	await _wait(0.3)
	check(float(Pets.my_pet.food) >= 59.0 and Pets.bonus(me, "dog"), "mama verildi, bonus geri geldi (%d)" % int(Pets.my_pet.food))
	var cans := int(Pets.my_pet.cans)
	Pets.buy_food(5)
	await _wait(0.3)
	check(int(Pets.my_pet.cans) == cans + 5, "5 kutu mama alındı")
	await _wait(1.0)
	check(w.npc.pets.has(me), "köpek sahibini takip ediyor")

	print("== 0.5: İşletme")
	var plot := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			plot = i
			break
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot, "biz")
	await _wait(0.4)
	check(Biz.is_biz(Land.view[plot]) and int(Land.view[plot].level) == 1, "boş arsaya büfe açıldı")
	Biz.restock(plot, "wholesale", 3)
	await _wait(0.3)
	check(int(Land.view[plot].biz.stock) == 30, "toptancıdan 30 birim malzeme")
	Biz.configure(plot, 1.2, 1)
	await _wait(0.3)
	check(is_equal_approx(float(Land.view[plot].biz.price), 1.2) and int(Land.view[plot].biz.staff) == 1, "fiyat ×1.2 ve 1 çalışan ayarlandı")
	Env.hour = 12.5
	Env.force_weather("clear")
	for _k in 3:
		Biz._tick()
	await _wait(0.4)
	var b: Dictionary = Land.view[plot].biz
	check(int(b.stock) < 30 and int(b.cash) > 0, "müşteriler geldi: %d birim satıldı, kasada %d TL" % [30 - int(b.stock), int(b.cash)])
	var m1 := Net.my_money()
	var cash := int(b.cash)
	Biz.collect(plot)
	await _wait(0.3)
	check(Net.my_money() >= m1 + cash and int(Land.view[plot].biz.cash) == 0, "kasa toplandı")
	Land.build_up(plot, "biz")
	await _wait(0.4)
	check(int(Land.view[plot].level) == 2, "büfe kafeye büyüdü")
	Biz.configure(plot, 1.0, 0)
	Land.view[plot].biz.stock = 0
	Land.plots[plot].biz.stock = 0
	Biz._tick()
	await _wait(0.3)
	check(int(Land.view[plot].biz.last_customers) == 0, "malzeme yokken satış yok")

	print("== 0.5: Hikâye görevleri")
	var dialogs: Array = []
	var cb := func(d): dialogs.append(d)
	Story.dialog.connect(cb)
	Net.save_data.players[Net.my_name]["story"] = {"step": 0, "count": 0, "accepted": false}
	Story.send_state(me)
	await _wait(0.2)
	check(Story.marker("muhtar") == "!", "muhtarın başında \"!\" var")
	w.my_pos = Map.NPCS.muhtar.pos + Vector2(20, 0)
	await _wait(0.3)
	check(w.zone.get("type") == "npc" and w.zone.get("npc") == "muhtar", "muhtarın yanında konuşma bölgesi")
	Story.talk("muhtar")
	await _wait(0.3)
	check(dialogs.size() > 0 and dialogs[-1].buttons.has("Kabul et"), "muhtar görev teklif etti")
	Story.accept()
	await _wait(0.3)
	check(Story.state.get("accepted", false), "görev kabul edildi")
	Story.event(me, "patient")
	Story.event(me, "patient")
	await _wait(0.3)
	check(Story.state.get("ready", false) and Story.marker("muhtar") == "?", "2 hasta sonrası görev hazır, \"?\" işareti")
	var m2 := Net.my_money()
	Story.talk("muhtar")
	await _wait(0.3)
	check(dialogs[-1].buttons.has("Ödülü al"), "muhtar ödülü veriyor")
	Story.claim()
	await _wait(0.3)
	check(int(Story.state.get("step", 0)) == 2 and Net.my_money() == m2 + 300, "ödül alındı, 2. görev sırada")
	Story.talk("muhtar")
	await _wait(0.2)
	Story.accept()
	await _wait(0.2)
	check(Story.marker("hasan") == "!", "Hasan Amca'nın başında \"!\" (tanış görevi)")
	w.my_pos = Map.NPCS.hasan.pos + Vector2(20, 0)
	await _wait(0.3)
	Story.talk("hasan")
	await _wait(0.3)
	check(dialogs[-1].buttons.has("Ödülü al"), "Hasan Amca'yla tanışıldı")
	Story.claim()
	await _wait(0.3)
	check(int(Story.state.get("step", 0)) == 3 and Story.marker("hasan") == "!", "3. görev Hasan Amca'dan")
	Story.dialog.disconnect(cb)

	print("== 0.5: NPC'ler")
	var p0: Vector2 = w.npc.walkers[0].pos
	var xs: Array = w.npc.cars.map(func(c): return float(c.x))
	await _wait(0.6)
	check(w.npc.walkers.size() >= 20 and w.npc.walkers[0].pos != p0, "%d vatandaş kaldırımda yürüyor" % w.npc.walkers.size())
	var moved := 0
	for i in w.npc.cars.size():
		if float(w.npc.cars[i].x) != float(xs[i]):
			moved += 1
	check(moved * 2 >= w.npc.cars.size(), "NPC arabalar yolda ilerliyor (%d/%d)" % [moved, w.npc.cars.size()])
	# arabalar birbirinin içinden geçmiyor
	var overlap := false
	for ca in w.npc.cars:
		for cb2 in w.npc.cars:
			if ca != cb2 and ca.lane == cb2.lane and absf(float(ca.x) - float(cb2.x)) < 60.0:
				overlap = true
	check(not overlap, "NPC arabalar birbirinin içine girmiyor")
	Land.sell(plot)
	await _wait(0.3)
	check(not Biz.is_biz(Land.view[plot]) and Land.view[plot].owner == "", "işletmeli arsa satıldı, arsa sıfırlandı")


## 0.6: çiftlik ve mevsimler, klanlar ve sohbet kanalları, etkinlikler ve yarış, polis ve suç.
func _test_06(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 100000)
	await _wait(0.3)

	print("== 0.6: Mevsimler")
	Env.force_season("summer")
	await _wait(0.3)
	check(Env.season == "summer" and Env.clock_text().contains("Yaz"), "mevsim yaz oldu ve saatte görünüyor (%s)" % Env.clock_text())
	check(Farm.grow_time("domates", "summer") < Farm.grow_time("domates", "spring") and Farm.grow_time("domates", "winter") > Farm.grow_time("domates", "spring"),
		"domates yazın hızlı, kışın yavaş büyür")

	print("== 0.6: Çiftlik")
	Env.force_weather("clear")
	var plot := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			plot = i
			break
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot, "farm")
	await _wait(0.4)
	check(Farm.is_farm(Land.view[plot]) and Land.view[plot].farm.beds.size() == 6, "boş arsaya 6 tarhlı tarla kuruldu")
	var m0 := Net.my_money()
	Farm.plant(plot, "domates")
	await _wait(0.4)
	var beds: Array = Land.view[plot].farm.beds
	check(beds.all(func(b): return b.c == "domates"), "6 tarha domates ekildi")
	check(Net.my_money() < m0, "tohum parası düştü (6 × %d TL)" % Farm.CROPS.domates.seed)
	check(Farm.bed_state(beds[0], Land.server_now())[0] == "growing", "ekin büyüyor")
	Farm.water(plot)
	await _wait(0.3)
	check(Land.view[plot].farm.beds.all(func(b): return b.w), "tarla sulandı")
	Farm.fertilize(plot)
	await _wait(0.3)
	check(Land.view[plot].farm.beds.all(func(b): return b.f), "tarla gübrelendi")
	var now := Time.get_unix_time_from_system()
	for b in Land.plots[plot].farm.beds:
		b.t = now - float(b.g) - 1.0          # zamanı ileri sar: olgunlaştı
	Land._broadcast()
	await _wait(0.3)
	check(Farm.bed_state(Land.view[plot].farm.beds[0], Land.server_now())[0] == "ready", "ekin olgunlaştı")
	Farm.harvest(plot)
	await _wait(0.4)
	var got := int(Farm.my_crops.get("domates", 0))
	check(got >= 6 * 4, "hasat: %d domates (sulama + gübre ile tarh başı 4+)" % got)
	check(Land.view[plot].farm.beds.all(func(b): return b.c == ""), "hasattan sonra tarhlar boşaldı")
	Farm.plant(plot, "bugday")
	await _wait(0.3)
	now = Time.get_unix_time_from_system()
	Land.plots[plot].farm.beds[0].t = now - 100000.0     # unutuldu: çürüdü
	Land._broadcast()
	await _wait(0.2)
	check(Farm.bed_state(Land.view[plot].farm.beds[0], Land.server_now())[0] == "rotten", "uzun süre toplanmayan ekin çürüdü")
	Env.force_weather("rain")
	Farm._acc = 99.0
	Farm._process(0.1)
	await _wait(0.3)
	check(Land.view[plot].farm.beds.slice(1).all(func(b): return b.w), "yağmur tarlayı kendiliğinden suladı")
	Env.force_weather("clear")
	Farm.plant(plot, "karpuz")
	await _wait(0.3)
	check(Land.view[plot].farm.beds[0].c == "karpuz", "çürük tarh temizlenip yeniden ekildi")
	w.my_pos = Map.building("pazar").rect.get_center()
	await _wait(0.3)
	Bazaar.list_item("crop", "domates", 90, 5)
	await _wait(0.3)
	var crop_l: Array = Bazaar.listings.filter(func(l): return l.kind == "crop" and l.seller == Net.my_name)
	check(crop_l.size() == 1 and int(Farm.my_crops.get("domates", 0)) == got - 5, "5 domates pazarda ilana kondu")
	Bazaar.cancel(int(crop_l[0].id))
	await _wait(0.3)
	check(int(Farm.my_crops.get("domates", 0)) == got, "ilan kaldırıldı, domatesler ambara döndü")
	var m1 := Net.my_money()
	Farm.sell("domates")
	await _wait(0.3)
	var hm := 1.5 if Events.is_active("harvest") else 1.0
	check(Net.my_money() == m1 + int(round(got * Farm.sell_price("domates", "summer") * hm)) and not Farm.my_crops.has("domates"), "Hal'de domatesler satıldı (+%d TL)" % (Net.my_money() - m1))

	print("== 0.6: Klan ve sohbet kanalları")
	Clans.create("Test Klanı", "tst")
	await _wait(0.4)
	check(Clans.mine.get("tag") == "TST" and Clans.mine.leader == Net.my_name, "klan kuruldu: [TST] Test Klanı")
	check(Net.roster[me].get("clan") == "TST", "klan etiketi oyuncu listesinde")
	check(Clans.ranking.size() >= 1 and Clans.ranking[0].tag == "TST", "klan sıralamasında görünüyor")
	var m2 := Net.my_money()
	Clans.deposit(1000)
	await _wait(0.3)
	Clans.withdraw(400)
	await _wait(0.3)
	check(int(Clans.mine.bank) == 600 and Net.my_money() == m2 - 600, "kasaya 1000 yatırıldı, lider 400 çekti")
	Rpg.add_xp(me, "", 2500)
	await _wait(3.5)
	check(int(Clans.mine.points) >= 250 and int(Clans.mine.level) >= 2, "üye XP'si klana puan kazandırdı (%d puan, Sv.%d)" % [int(Clans.mine.points), int(Clans.mine.level)])
	check(Clans.pay_mult(me) > 1.0, "klan seviyesi maaş bonusu veriyor (×%.2f)" % Clans.pay_mult(me))
	_chats.clear()
	Net.send_chat("klan selam", "clan")
	await _wait(0.5)
	Net.send_chat("yakındaki selam", "local")
	await _wait(0.5)
	check(_chats.any(func(c): return c[0] == "clan" and c[1] == "klan selam"), "klan kanalında mesaj geldi")
	check(_chats.any(func(c): return c[0] == "local" and c[1] == "yakındaki selam"), "yakın kanalda mesaj geldi")
	w.open_simple_panel("res://scripts/ui/clan_panel.gd")
	await get_tree().process_frame
	check(w.panel != null, "klan penceresi açıldı")
	w._close_panel()

	print("== 0.6: Etkinlikler")
	Events.start_event("fish")
	await _wait(0.3)
	check(Events.current.get("kind") == "fish", "balık turnuvası başladı (herkese yayınlandı)")
	Events.on_fish(me, "Sazan", 25)
	Events.on_fish(me, "Turna", 90)
	Events.on_fish(me, "Hamsi", 12)
	await _wait(0.3)
	var st: Array = Events.current.get("standings", [])
	check(st.size() == 1 and int(st[0].score) == 90, "turnuvada en değerli balık sayıldı (Turna 90 TL)")
	var m3 := Net.my_money()
	Events._finish()
	await _wait(0.3)
	check(Events.current.is_empty() and Net.my_money() >= m3 + Events.PRIZES[0], "turnuva bitti, birinciye %d TL ödül" % Events.PRIZES[0])
	check(Events.next_kind != "" and Events.next_at > Events.local_now(), "sıradaki etkinlik zamanlandı (%s)" % Events.next_kind)
	Events.start_event("festival")
	await _wait(0.2)
	check(is_equal_approx(Events.pay_mult(), Events.FESTIVAL_PAY) and Events.customer_mult() > 1.0, "festivalde maaş ve müşteri artıyor")
	Events.start_event("treasure")
	await _wait(0.3)
	check(Events.current.get("kind") == "treasure" and Events.current.has("area"), "hazine avı başladı, arama alanı geldi")
	var m4 := Net.my_money()
	w.my_pos = Events._active.pos + (Map.SPAWN - Events._active.pos).normalized() * 200.0
	await _wait(0.3)
	check(Events.treasure_pos != null, "sandığa yaklaşınca yeri göründü")
	w.my_pos = Events._active.pos
	await _wait(0.4)
	check(Net.my_money() >= m4 + Events.TREASURE_PRIZE and Events.current.is_empty(), "hazine bulundu (+%d TL), etkinlik bitti" % Events.TREASURE_PRIZE)

	print("== 0.6: Yarış pisti")
	w.my_pos = Map.RACE_START
	await _wait(0.3)
	check(w.zone.get("type") == "race", "başlangıçta yarış bölgesi")
	Events.race_start()
	await _wait(0.3)
	check(Events.race.get("state") == "countdown", "geri sayım başladı")
	await _wait(3.2)
	check(Events.race.get("state") == "running", "yarış başladı")
	for cp in Map.RACE_CPS:
		w.my_pos = cp
		await _wait(0.4)
	check(Events.race.get("state") == "finished" and float(Events.race.last) > 0.0, "tur tamamlandı (%.2f sn)" % float(Events.race.get("last", 0.0)))
	check(Events.records.size() >= 1 and Events.records[0].name == Net.my_name, "pist rekorlarına girildi")
	w.my_pos = Map.RACE_START
	await _wait(0.2)
	Events.race_start()
	await _wait(0.3)
	w.my_pos = Map.SPAWN
	await _wait(0.4)
	check(Events.race.is_empty() or Events.race.get("state") == null, "geri sayımda pistten ayrılınca erken çıkış")

	print("== 0.6: Polis ve suç")
	Police._npc_acc = -100000.0       # testte NPC devriye rastgele yakalamasın
	var rp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			rp = i
			break
	Net.save_data.players["Kurban"] = {"money": 20000, "fish": [], "rpg": {"xp": 3000}}
	Land.plots[rp].owner = "Kurban"
	Land.plots[rp].level = 1
	Land._broadcast()
	w.my_pos = Map.plot_rect(rp).get_center()
	await _wait(0.3)
	check(w._g_action.get("kind") == "rob", "başkasının evinde G: soygun seçeneği")
	for _k in 12:
		Police._cool.clear()
		Police.rob(rp)
		await _wait(0.15)
		if int(Police.status.get("wanted", 0)) >= 2 and int(Net.save_data.players.Kurban.money) < 20000:
			break
	check(int(Police.status.get("wanted", 0)) >= 1 and int(Net.roster[me].get("wanted", 0)) >= 1, "soygun aranma yıldızı verdi (%d★)" % int(Police.status.get("wanted", 0)))
	check(int(Net.save_data.players.Kurban.money) < 20000, "ev soyuldu (kurbanın parası %d)" % int(Net.save_data.players.Kurban.money))
	var vm := int(Net.save_data.players.Kurban.money)
	var wa := int(Police.status.wanted)
	Land.plots[rp]["sec"] = {"lock": false, "alarm": true}
	Police._cool.clear()
	Police.rob(rp)
	await _wait(0.3)
	check(int(Net.save_data.players.Kurban.money) == vm and int(Police.status.wanted) == mini(5, wa + 2), "alarmlı ev soyulamadı, +2 yıldız")
	w.my_pos = Map.building("karakol").rect.get_center()
	await _wait(0.3)
	Police.set_duty(true)
	await _wait(0.3)
	check(not Police.on_duty(), "aranan oyuncu polis olamaz")
	Ach.ach_of(Net.save_data.players[Net.my_name]).got["jailed"] = 1.0     # başarım ödülü cezayı karıştırmasın
	var m5 := Net.my_money()
	var stars := Police.wanted(me)
	Police.jail(me, stars, 0)
	await _wait(0.5)
	check(Police.is_jailed(me) and w._jail and Map.JAIL.has_point(w.my_pos), "NPC polis yakaladı: hapishanedesin")
	check(Police.jail_left() > 0.0 and Police.wanted(me) == 0, "hapis süresi işliyor, yıldızlar sıfırlandı")
	check(Net.my_money() == m5 - stars * Police.FINE_PER_STAR, "para cezası kesildi (%d TL)" % (stars * Police.FINE_PER_STAR))
	check(Map.JAIL.has_point(w._clamp_to_area(Map.SPAWN)), "hapisten yürüyerek çıkılamıyor")
	Jobs.ask_market()
	await _wait(0.3)
	Police.bail()
	await _wait(0.5)
	check(not Police.is_jailed(me) and not w._jail and Map.building("karakol").rect.grow(200).has_point(w.my_pos), "kefalet ödendi, karakolun önünde serbest")
	w.my_pos = Map.building("karakol").rect.get_center()
	await _wait(0.3)
	Police.set_duty(true)
	await _wait(0.3)
	check(Police.on_duty() and Net.roster[me].get("police", false), "polis görevine başlandı")
	var cases: Array = []
	var cbc := func(d): cases.append(d)
	Police.patrol_case.connect(cbc)
	var m6 := Net.my_money()
	Police.ask_patrol()
	await _wait(0.3)
	check(cases.size() == 1 and Police._patrol.has(me), "devriye ihbarı geldi: %s" % (cases[0].case if not cases.is_empty() else "-"))
	Police.answer_patrol(int(Police._patrol[me].correct) if Police._patrol.has(me) else 0)
	await _wait(0.3)
	check(Net.my_money() > m6, "olay doğru çözüldü, maaş alındı (+%d TL)" % (Net.my_money() - m6))
	Police.patrol_case.disconnect(cbc)
	Police.buy_security("wallet")
	Police.buy_security("lock", plot)
	await _wait(0.4)
	check(Police.status.get("security", []).has("wallet") and Land.view[plot].get("sec", {}).get("lock", false), "cüzdan zinciri ve tarlaya kilit alındı")
	var helper := Net.id_by_name("Yardimci")
	if helper != 0:
		var hc: Dictionary = Police.crime(Net.save_data.players.Yardimci)
		hc["t"] = Time.get_unix_time_from_system()
		hc["wanted"] = 2
		Police._update_roster(helper)
		w.my_pos = Net.positions[helper] + Vector2(30, 0)
		await _wait(0.4)
		check(w._g_action.get("kind") == "arrest", "görevdeyken aranan oyuncunun yanında G: tutukla")
		if w._g_action.get("kind") != "arrest":
			print("  [debug] g=", w._g_action, " shown=", w.shown.get(helper), " me=", w.my_pos, " roster=", Net.roster.get(helper), " duty=", Police.on_duty())
		var m7 := Net.my_money()
		Police.arrest("Yardimci")
		await _wait(0.4)
		check(Police.is_jailed(helper) and Net.my_money() > m7, "polis aranan oyuncuyu tutukladı, ödül aldı")
	else:
		print("  (yardımcı istemci yok: tutuklama testi atlandı)")
	Police.set_duty(false)
	await _wait(0.2)
	w.zone = {"type": "karakol", "label": "Karakol"}
	w._open_panel()
	await get_tree().process_frame
	check(w.panel != null, "karakol penceresi açıldı")
	w._close_panel()
	Land.plots[rp].owner = ""
	Land.plots[rp].level = 0
	Land.plots[rp].erase("sec")
	Land._broadcast()
	Land.sell(plot)
	await _wait(0.3)
	check(not Farm.is_farm(Land.view[plot]) and Land.view[plot].owner == "", "tarla satıldı, arsa sıfırlandı")


## 0.7: Çarşı ve aksesuarlar, banka ve borsa, belediye seçimi, düğün ve aile.
func _test_07(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 100000)
	await _wait(0.3)

	print("== 0.7: Çarşı")
	w.my_pos = Map.building("carsi").rect.get_center()
	await _wait(0.3)
	Shops.buy("hat3")
	Shops.buy("gl1")
	Shops.buy("hc9")
	Shops.buy("ring")
	await _wait(0.4)
	check(Shops.owned.has("hat3") and Shops.owned.has("gl1") and Shops.owned.has("hc9") and Shops.rings == 1, "şapka, gözlük, saç boyası ve yüzük alındı")
	Shops.wear("hat", 3)
	await _wait(0.3)
	Shops.wear("glasses", 1)
	await _wait(0.3)
	var app: Dictionary = Net.roster[me].appearance
	check(int(app.hat) == 3 and int(app.glasses) == 1, "aksesuarlar giyildi (herkes görüyor)")
	var fake: Dictionary = app.duplicate()
	fake["hat"] = 6
	fake["neck"] = 1
	fake["hair_color"] = 11
	Net.set_appearance(fake)
	await _wait(0.3)
	app = Net.roster[me].appearance
	check(int(app.hat) == 0 and int(app.neck) == 0 and int(app.hair_color) == 0, "alınmamış taç/kolye/saç rengi sunucuda reddedildi")
	fake["hair_color"] = 9
	fake["hat"] = 3
	Net.set_appearance(fake)
	await _wait(0.3)
	check(int(Net.roster[me].appearance.hair_color) == 9, "alınan özel saç rengi kullanılabiliyor")
	w.my_pos = Map.SPAWN
	await _wait(0.3)
	Shops.buy("hat1")
	await _wait(0.3)
	check(not Shops.owned.has("hat1"), "Çarşı dışında alışveriş reddedildi")

	print("== 0.7: Banka")
	w.my_pos = Map.building("banka").rect.get_center()
	await _wait(0.3)
	var m0 := Net.my_money()
	Bank.deposit(5000)
	await _wait(0.3)
	Bank.withdraw(2000)
	await _wait(0.3)
	check(int(Bank.account.bal) == 3000 and Net.my_money() == m0 - 3000, "5000 yatırıldı, 2000 çekildi")
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	rec.bank_acc.t = Time.get_unix_time_from_system() - Env.DAY_SECONDS
	Bank.send_state(me)
	await _wait(0.3)
	check(int(Bank.account.bal) >= 3089, "bir oyun gününde %%3 faiz işledi (%d TL)" % int(Bank.account.bal))
	Bank.borrow(3000)
	await _wait(0.3)
	check(int(Bank.account.debt) == 3300, "3000 TL kredi çekildi, borç 3300 (%%10 masraf)")
	Bank.borrow(1000)
	await _wait(0.3)
	check(int(Bank.account.debt) == 3300, "borç varken ikinci kredi verilmedi")
	rec.bank_acc.due = Time.get_unix_time_from_system() - 1.0
	Bank._collect_overdue()
	await _wait(0.3)
	check(int(Bank.account.debt) == 0, "vadesi geçen borç tahsil edildi")
	print("== 0.7: Borsa")
	var p0 := Bank.price("MRKT")
	Bank.trade("MRKT", 10)
	await _wait(0.3)
	check(int(Bank.holdings.get("MRKT", {}).get("n", 0)) == 10, "10 MRKT hissesi alındı (%.2f)" % p0)
	var h0: int = Bank.market.MRKT.hist.size()
	Bank.activity("BALK", 20)
	Bank.tick_market()
	await _wait(0.3)
	check(Bank.market.MRKT.hist.size() == mini(h0 + 1, Bank.HISTORY) and Bank.price("MRKT") > 0.0, "borsa fiyatları güncellendi (MRKT %.2f → %.2f)" % [p0, Bank.price("MRKT")])
	var m1 := Net.my_money()
	Bank.trade("MRKT", -10)
	await _wait(0.3)
	check(not Bank.holdings.has("MRKT") and Net.my_money() > m1, "hisseler satıldı (+%d TL)" % (Net.my_money() - m1))
	var bal0 := int(Bank.account.bal)
	w.my_pos = Map.SPAWN
	await _wait(0.3)
	Bank.deposit(100)
	await _wait(0.3)
	check(int(Bank.account.bal) == bal0, "banka dışında işlem yapılamıyor")

	print("== 0.7: Belediye seçimi")
	var now := Time.get_unix_time_from_system()
	var base: float = floor(now / Election.CYCLE) * Election.CYCLE + Election.CYCLE    # gelecek döngü
	Election.debug_offset = base + 60.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	await _wait(0.3)
	check(Election.state.get("phase") == "apply", "yeni seçim dönemi: aday başvuruları")
	w.my_pos = Map.building("muhtarlik").rect.get_center()
	Election.apply("Her eve bir tekne!")
	await _wait(0.3)
	check(Election.state.get("candidate", false) and Election.state.candidates.size() == 1, "aday olundu")
	Election.vote(Net.my_name)
	await _wait(0.3)
	check(not Election.state.get("voted", false), "başvuru döneminde oy verilemez")
	Election.debug_offset = base + Election.APPLY_END + 60.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	await _wait(0.3)
	check(Election.state.get("phase") == "vote", "oylama başladı")
	Election.vote(Net.my_name)
	await _wait(0.3)
	Election.vote(Net.my_name)
	await _wait(0.3)
	check(Election.state.get("voted", false) and int(Election._data().candidates[Net.my_name].votes) == 1, "oy kullanıldı (ikinci oy sayılmadı)")
	Election.debug_offset = base + Election.VOTE_END + 60.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	await _wait(0.4)
	check(Election.state.get("mayor") == Net.my_name and Election.is_mayor(), "seçimi kazanıp belediye başkanı olundu")
	check(Net.roster[me].get("mayor", false), "başkan rozeti oyuncu listesinde")
	Election.set_tax(10)
	await _wait(0.3)
	check(int(Election.state.tax) == 10 and Election.take_tax(1000) == 900, "vergi %%10 yapıldı, kiradan kesiliyor")
	var m2 := Net.my_money()
	var tre := int(Election._data().treasury)
	Election.give_grant()
	await _wait(0.3)
	check(Net.my_money() > m2 and int(Election._data().treasury) < tre, "hibe dağıtıldı (+%d TL)" % (Net.my_money() - m2))
	Election.start_event("festival")
	await _wait(0.3)
	check(Events.is_active("festival"), "başkan festival başlattı")
	Events._finish()
	Election.debug_offset = 0.0

	print("== 0.7: Düğün ve aile")
	var helper := Net.id_by_name("Yardimci")
	if helper == 0:
		print("  (yardımcı istemci yok: düğün testi atlandı)")
	else:
		if Police.is_jailed(helper):
			Police._release(helper)
			await _wait(0.4)
		Rpg.add_xp(helper, "", 3000)
		await _wait(0.3)
		w.my_pos = Net.positions[helper] + Vector2(40, 0)
		await _wait(0.4)
		Family.propose("Yardimci")
		await _wait(1.0)
		check(Family.info.get("spouse") == "Yardimci", "evlenme teklifi kabul edildi: Yardimci ile evli")
		check(Net.roster[me].get("spouse") == "Yardimci" and Shops.rings == 0, "yüzük harcandı, eş oyuncu listesinde")
		check(Family.weddings.size() >= 1, "düğün kutlaması herkese yayınlandı")
		check(is_equal_approx(Family.xp_mult(me), Family.XP_BONUS), "eşinin yanındayken XP bonusu")
		Family.deposit(1000)
		await _wait(0.3)
		check(int(Family.info.bank) == 1000, "aile kasasına 1000 yatırıldı")
		var hplot := -1
		for i in Land.view.size():
			if Land.view[i].owner == "":
				hplot = i
				break
		Land.plots[hplot].owner = "Yardimci"
		Land.plots[hplot].level = 1
		check(Homes.may_be_in(me, hplot), "eşinin evine kapı kapalıyken girilebilir")
		Land.plots[hplot].owner = ""
		Land.plots[hplot].level = 0
		var m3 := Net.my_money()
		Family.divorce()
		await _wait(0.4)
		check(Family.info.is_empty() and Net.my_money() == m3 - Family.DIVORCE_COST + 500, "boşanıldı, aile kasası paylaşıldı")
	w.open_simple_panel("res://scripts/ui/family_panel.gd")
	await get_tree().process_frame
	check(w.panel != null, "aile penceresi açıldı")
	w._close_panel()

	print("== 0.7.1: Çarpışma ve olta animasyonu")
	var mr: Rect2 = Map.building("market").rect
	var outside := Vector2(mr.get_center().x, mr.end.y + 30)
	w.my_pos = outside
	await _wait(0.2)
	check(not w._can_stand(mr.get_center(), ""), "binanın içine yürünemiyor")
	check(w._can_stand(outside + Vector2(0, 8), ""), "binanın önünde serbestçe yürünüyor")
	w.my_pos = Vector2(mr.get_center().x, mr.end.y - 4)
	await _wait(0.2)
	check(w.zone.get("type") == "market", "kapının önünde E bölgesi çalışıyor")
	var hp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			hp = i
			break
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.2)
	Land.buy(hp)
	await _wait(0.3)
	Land.build_up(hp)
	await _wait(0.4)
	var st: Array = w._structure_of(hp, Land.view[hp])
	var hfoot: Vector2 = st[1]
	w.my_pos = Map.plot_front(hp)
	await _wait(0.2)
	check(not w._can_stand(hfoot + Vector2(0, -20), "car"), "evin içinden arabayla geçilemiyor")
	check(w._can_stand(Map.plot_front(hp) + Vector2(10, 0), ""), "evden çıkış noktası serbest")
	Land.sell(hp)
	await _wait(0.3)
	var car: Dictionary = w.npc.cars[1]
	var lane: Array = Map.TRAFFIC_LANES[car.lane]
	car.x = 1500.0
	w.my_pos = Vector2(1500.0 + 60.0 * float(lane[1]), float(lane[0]))
	await _wait(0.4)
	check(is_equal_approx(float(car.x), 1500.0), "NPC araba önündeki oyuncu için durdu")
	check(not w._can_stand(Vector2(1500.0, float(lane[0])), ""), "NPC arabanın içine girilemiyor")
	w.my_pos = Map.SPAWN + Vector2(0, -40)
	await _wait(0.6)
	check(float(car.x) != 1500.0, "yol açılınca araba devam etti")
	w.my_pos = Map.DOCK.get_center()
	await _wait(0.3)
	Jobs.cast()
	await _wait(0.4)
	check(Net.roster[me].get("fishing") == "cast", "olta atıldı: durum herkese yayınlandı")
	check(w._bobber_pos(w.my_pos, "left") != null, "şamandıra için su bulundu")
	var t0 := Time.get_ticks_msec()
	while Net.roster[me].get("fishing") == "cast" and Time.get_ticks_msec() - t0 < 10000:
		await _wait(0.1)
	check(Net.roster[me].get("fishing") in ["bite", "caught"], "balık vurdu (şamandıra battı)")
	await _wait(2.5)
	check(Net.roster[me].get("fishing") == "", "yakalama animasyonundan sonra durum temizlendi")


## 0.8: başarımlar/unvanlar, harita, açık deniz ve ada, mevsimlik içerik, futbol ve langırt.
func _test_08(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 50000)
	await _wait(0.3)

	print("== 0.8: Başarımlar ve unvanlar")
	await _wait(0.6)
	var got: Dictionary = Ach.data.get("got", {})
	check(got.has("fish1") and got.has("build1") and got.has("mayor"), "olaylar başarım açtı (%d başarım)" % got.size())
	Ach.set_title("mayor")
	await _wait(0.3)
	check(Net.roster[me].get("title") == "Başkan", "unvan seçildi: «Başkan» (herkes görüyor)")
	Ach.set_title("rich1m")
	await _wait(0.3)
	check(Net.roster[me].get("title") == "Başkan", "kazanılmamış unvan seçilemiyor")
	w.open_simple_panel("res://scripts/ui/ach_panel.gd")
	await get_tree().process_frame
	check(w.panel != null, "başarım penceresi açıldı")
	w._close_panel()

	print("== 0.8: Harita ve navigasyon")
	w.open_map()
	await get_tree().process_frame
	check(w.panel != null, "büyük harita açıldı (M)")
	w.panel._go(Map.building("banka").rect.get_center() + Vector2(0, 140))
	await get_tree().process_frame
	check(w.nav_target != null and w.panel == null, "haritadan hedef seçildi")
	w.my_pos = w.nav_target
	await _wait(0.3)
	check(w.nav_target == null, "hedefe varınca yön oku kalktı")

	print("== 0.8: Açık deniz ve Martı Adası")
	check(Map.in_deep(Vector2(1400, 2500)) and Map.on_island(Map.ISLAND.get_center()) and not Map.in_sea(Map.ISLAND.get_center()), "derin deniz ve ada haritada")
	w.my_pos = Vector2(1400, 2300)
	await _wait(0.2)
	check(not w._can_stand(Vector2(1400, 2420), ""), "açık denize yüzerek gidilemiyor")
	w.my_pos = Map.BOAT_RENT_SPOT
	await _wait(0.3)
	check(w.zone.get("type") == "boatrent", "iskelede tekne kiralama bölgesi")
	var m0 := Net.my_money()
	w._open_panel()
	await _wait(0.4)
	check(Garage.rent_left() > 500.0 and Net.my_money() < m0, "tekne kiralandı (%d sn)" % int(Garage.rent_left()))
	w.my_pos = Map.PIER_END.get_center()
	await _wait(0.3)
	w._toggle_vehicle()
	await _wait(0.4)
	check(w.my_ride() == "boat" and Map.in_sea(w.my_pos), "iskeleden tekneye binildi")
	check(w._can_stand(Vector2(1400, 2600), "boat"), "tekneyle açık denize çıkılabiliyor")
	Garage.ride("")
	await _wait(0.2)
	w.my_pos = Map.ISLAND_SPOT.get_center()
	await _wait(0.3)
	check(Map.fishing_spot(w.my_pos) == "island", "Martı Adası iskelesi balık noktası")
	Jobs.cast()
	await _wait(0.3)
	check(Jobs._fish.has(me) and Jobs._fish[me].spot == "island", "adada olta atıldı (nadir balık şansı yüksek)")
	Jobs._fish.erase(me)
	Jobs._set_fishing(me, "")

	print("== 0.8: Hava ve mevsimler")
	Env.force_weather("fog")
	await _wait(0.2)
	check(Env.clock_text().contains("Sisli"), "sis çöktü (%s)" % Env.clock_text())
	Env.force_weather("rainbow")
	await _wait(0.2)
	check(Env.weather_name() == "Gökkuşağı", "gökkuşağı çıktı")
	Env.force_weather("clear")
	Env.force_season("winter")
	await _wait(0.3)
	var spot := Vector2(600, 560)
	w.my_pos = spot
	await _wait(0.3)
	check(w.zone.get("type") == "snowman", "kışın çimende kardan adam yapılabilir")
	w._open_panel()
	await _wait(0.4)
	check(Seasonal.snowmen.size() >= 1 and int(Ach.data.c.get("snowman", 0)) >= 1, "kardan adam yapıldı")
	var helper := Net.id_by_name("Yardimci")
	if helper != 0:
		if Police.is_jailed(helper):
			Police._release(helper)
			await _wait(0.4)
		Events.start_event("snow")
		await _wait(0.2)
		var hp: Vector2 = Net.positions[helper]
		w.my_pos = hp + Vector2(-140, 24)
		await _wait(0.4)
		Seasonal.throw(Vector2.RIGHT)
		await _wait(0.6)
		check(int(Ach.data.c.get("snowball_hit", 0)) >= 1, "kartopu yardımcıya isabet etti")
		var st: Array = Events.current.get("standings", [])
		check(not st.is_empty() and st[0].name == Net.my_name, "Kartopu Savaşı'nda puan alındı")
		Events._finish()
	else:
		print("  (yardımcı istemci yok: kartopu testi atlandı)")
	Env.force_season("summer")
	await _wait(0.3)
	check(Seasonal.snowmen.is_empty(), "yaz gelince kardan adamlar eridi")
	Rpg.use_energy(me, 30)
	await _wait(0.2)
	var e0 := float(Rpg.sheet.energy)
	w.my_pos = Seasonal.ICECREAM_POS + Vector2(0, 40)
	await _wait(0.3)
	check(w.zone.get("type") == "dondurma", "yazın plajda dondurmacı")
	w._open_panel()
	await _wait(0.8)
	check(float(Rpg.sheet.energy) > e0 and int(Ach.data.c.get("icecream", 0)) >= 1, "dondurma yendi, enerji arttı")

	print("== 0.8: Plaj futbolu")
	var f: Rect2 = Football.FIELD
	w.my_pos = f.get_center() + Vector2(0, 100)
	await _wait(0.3)
	Football.join("red")
	await _wait(0.3)
	check(Net.roster[me].get("team") == "red", "Kırmızı takıma katılındı")
	Football.ball = Vector2(f.end.x - 50, f.get_center().y)
	Football.vel = Vector2.ZERO
	w.my_pos = Football.ball + Vector2(-22, 0)
	await _wait(1.2)
	check(int(Football.score.red) == 1, "gol! Kırmızı 1 - 0 (sağ kaleye)")
	check(int(Ach.data.c.get("goal", 0)) >= 1, "gol başarım sayacına işlendi")
	Football.join("")
	await _wait(0.2)

	print("== 0.8: Langırt")
	w.my_pos = Langirt.POS + Vector2(0, 50)
	await _wait(0.3)
	check(w.zone.get("type") == "langirt", "langırt masası bölgesi")
	Langirt.sit(0, true)
	await _wait(2.2)
	check(Langirt.my_seat() == 0 and Langirt.state.get("n", [])[1] == "Bot", "bota karşı masaya oturuldu")
	check(Langirt.state.get("st") in ["play", "serve"], "langırt maçı başladı")
	Langirt._score = [Langirt.WIN - 1, 0]
	Langirt._scored(0)
	await _wait(0.4)
	check(int(Ach.data.c.get("langirt_win", 0)) >= 1, "langırtta bot yenildi")
	Langirt.leave()
	await _wait(0.2)


## 0.9: nehir/park/otobüs, meslekler (taksi, kargo, itfaiye, çöpçülük), parti, ayarlar ve eğitim.
func _test_09(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 50000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 0.9: Ayarlar ve eğitim")
	check(Settings.key("interact") == KEY_E and Settings.key_name("map") == "M", "varsayılan tuşlar")
	var old := Settings.ui_scale
	Settings.ui_scale = 1.25
	check(is_equal_approx(Settings.world_zoom(), Settings.zoom / 1.25), "arayüz büyütülünce dünya yakınlaştırması dengeleniyor")
	Settings.ui_scale = old
	Settings.keys["interact"] = KEY_R
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	check(Settings.is_key(ev, "interact"), "tuş atanabiliyor (E → R)")
	Settings.keys["interact"] = KEY_E
	w.open_settings()
	await get_tree().process_frame
	check(w.panel != null, "ayarlar penceresi açıldı")
	w._close_panel()
	Tutorial.finish()
	Tutorial.start(w.ui_layer, true)
	check(Tutorial.active() and Tutorial.step == 0, "eğitim turu başladı")
	Tutorial.note("move")
	Tutorial.note("panel")
	check(Tutorial.step == 2, "eğitim adımları ilerliyor")
	Tutorial.finish()
	check(not Tutorial.active() and Settings.tutorial_done, "eğitim bitti/atlandı")

	print("== 1.0.1: Balık paneli ve suya yakınlık; otobüs çarpışması")
	w._fish_state = "idle"
	check(Map.water_near(Map.DOCK.get_center()) and Map.water_near(Map.PIER_END.get_center()) and not Map.water_near(Vector2(1500, 700)), "suya yakınlık doğru hesaplanıyor")
	w.my_pos = Map.DOCK.get_center()
	await _wait(0.3)
	check(w.zone.get("type") == "fishing", "iskelede balık tutma bölgesi")
	w._open_panel()
	await get_tree().process_frame
	check(w.panel != null and w.panel.has_method("_on_action"), "E ile balık paneli açıldı")
	var nf := Jobs.my_fish.size()
	w.panel._on_action()
	await _wait(0.4)
	check(w.panel.state == "waiting", "panelden olta atıldı (animasyon yanda görünür)")
	var t1 := Time.get_ticks_msec()
	while Jobs.my_fish.size() == nf and Time.get_ticks_msec() - t1 < 12000:
		await _wait(0.2)
	check(Jobs.my_fish.size() == nf + 1, "şamandıra battı, çekildi, balık kovada")
	w._close_panel()
	var bus := Map.bus_at(Land.server_now())
	check(w._blocked(Vector2(bus[0])), "otobüsün içine girilemiyor")
	w.my_pos = Vector2(bus[0])
	w._push_from_bus()
	check(w._in_bus(w.my_pos) == 0.0, "otobüs oyuncuyu kenara itti")

	print("== 0.9: Nehir, köprü, park, otobüs")
	check(Map.in_water(Vector2(523, 200)) and not Map.in_water(Vector2(523, 445)), "nehir suyu ve üstündeki köprü")
	w.my_pos = Vector2(470, 200)
	await _wait(0.2)
	check(not w._can_stand(Vector2(523, 200), ""), "nehirde yürünemiyor")
	w.my_pos = Map.BUS_STOPS.merkez[1]
	await _wait(0.3)
	check(w.zone.get("type") == "bus", "otobüs durağı bölgesi")
	var m0 := Net.my_money()
	Work.ride_bus("plaj")
	await _wait(0.5)
	check(w.my_pos.distance_to(Map.BUS_STOPS.plaj[1]) < 60.0 and int(Ach.data.c.get("bus", 0)) >= 1, "otobüsle plaja gidildi")
	w.my_pos = Map.FOUNTAIN + Vector2(0, 70)
	await _wait(0.3)
	check(w.zone.get("type") == "wish", "çeşmede dilek bölgesi")
	w._open_panel()
	await _wait(0.4)
	check(int(Ach.data.c.get("wish", 0)) >= 1, "dilek tutuldu")

	print("== 0.9: Taksi")
	w.my_pos = Map.TAXI_STAND
	await _wait(0.3)
	Garage.ride("car")
	await _wait(0.3)
	Work.taxi_start()
	await _wait(0.4)
	check(Work.job.get("kind") == "taxi" and Work.job.get("stage") == "pickup", "taksi işi alındı: yolcuyu al")
	check(w.nav_target != null, "yön oku yolcuyu gösteriyor")
	w.my_pos = Work.job.target
	await _wait(0.4)
	check(Work.job.get("stage") == "drop", "yolcu bindi")
	var m1 := Net.my_money()
	w.my_pos = Work.job.target
	await _wait(0.5)
	check(Net.my_money() > m1 and int(Ach.data.c.get("taxi", 0)) >= 1, "yolcu indi, ücret alındı (+%d TL)" % (Net.my_money() - m1))
	check(Work.job.get("stage") == "pickup", "sıradaki yolcu atandı")
	Work.quit_job()
	await _wait(0.3)
	check(Work.job.get("kind", "") == "", "taksi mesaisi bitti")
	Garage.ride("")
	await _wait(0.2)

	print("== 0.9: Kargo")
	w.my_pos = Map.CARGO_DEPOT
	await _wait(0.3)
	Work.cargo_start()
	await _wait(0.4)
	check(Work.job.get("kind") == "cargo", "3 paket alındı")
	var m2 := Net.my_money()
	for _k in 3:
		w.my_pos = Work.job.get("target", Map.SPAWN)
		await _wait(0.4)
	check(Net.my_money() >= m2 + 3 * Work.CARGO_PAY + Work.CARGO_BONUS and Work.job.get("kind", "") == "", "paketler teslim, hız ikramiyesi alındı (+%d TL)" % (Net.my_money() - m2))

	print("== 0.9: İtfaiye")
	w.my_pos = Map.FIRE_STATION.get_center() + Vector2(0, 90)
	await _wait(0.3)
	check(w.zone.get("type") == "firestation", "itfaiye bölgesi")
	Work.fire_duty(true)
	await _wait(0.3)
	check(Work.on_duty_fire(), "itfaiye görevine başlandı")
	Work._start_fire()
	await _wait(0.4)
	check(Work.fires.size() >= 1, "yangın çıktı (herkese yayınlandı)")
	var f: Dictionary = Work.fires[0]
	w.my_pos = Vector2(float(f.x), float(f.y)) + Vector2(0, 60)
	await _wait(0.3)
	check(w.zone.get("type") == "fire", "yangının yanında söndürme bölgesi")
	if w.zone.get("type") != "fire":
		print("  [debug] zone=", w.zone, " fire=", f, " me=", w.my_pos, " duty=", Work.on_duty_fire(), " job=", Work.job)
	var m3 := Net.my_money()
	for _k in 30:
		Work.spray(int(f.id))
		await get_tree().process_frame
	await _wait(0.4)
	check(Work.fires.is_empty() and Net.my_money() > m3, "yangın söndürüldü (+%d TL)" % (Net.my_money() - m3))
	Work.fire_duty(false)
	await _wait(0.2)

	print("== 0.9: Çöpçülük")
	for _k in 5:
		Work._spawn_trash()
	await _wait(0.4)
	check(not Work.trash.is_empty(), "sokakta çöp torbaları var (%d)" % Work.trash.size())
	var tr: Dictionary = Work.trash[0]
	w.my_pos = Vector2(float(tr.x), float(tr.y))
	await _wait(0.3)
	Work.pick_trash(int(tr.id))
	await _wait(0.3)
	check(Work.carrying == 1, "çöp torbası toplandı")
	if Work.carrying != 1:
		print("  [debug] trash=", tr, " me=", w.my_pos, " srv=", Net.positions.get(me), " carry=", Work._carry, " n=", Work._trash.size())
	var m4 := Net.my_money()
	w.my_pos = Map.RECYCLE + Vector2(0, -20)
	await _wait(0.3)
	Work.recycle()
	await _wait(0.3)
	check(Work.carrying == 0 and Net.my_money() == m4 + Work.TRASH_PAY, "geri dönüşüme götürüldü (+%d TL)" % Work.TRASH_PAY)

	print("== 0.9: Ev partisi ve En Güzel Ev")
	var hp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			hp = i
			break
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.3)
	Land.buy(hp)
	await _wait(0.3)
	Land.build_up(hp)
	await _wait(0.3)
	Homes.enter(hp)
	await _wait(0.5)
	for k in ["bed", "rug", "lamp"]:
		if int(Homes.depot.get(k, 0)) > 0:
			Homes.place(hp, k, 1 + ["bed", "rug", "lamp"].find(k) * 3, 1)
			await _wait(0.2)
	Party.start_party(hp)
	await _wait(0.4)
	check(Party.is_party(Land.view[hp], Land.server_now()) and bool(Land.view[hp].get("door_open", false)), "parti başladı, kapı herkese açık")
	check(int(Ach.data.c.get("party", 0)) >= 1, "parti başarım sayacına işlendi")
	Events.start_event("ev")
	await _wait(0.5)
	var st: Array = Events.current.get("standings", [])
	check(not st.is_empty() and st[0].name == Net.my_name and float(st[0].score) >= Party.decor_score(Land.view[hp]), "En Güzel Ev yarışmasında dekor puanı sayıldı (%s)" % (st[0].text if not st.is_empty() else "-"))
	Events._finish()
	Homes.exit_home()
	await _wait(0.4)
	Land.sell(hp)
	await _wait(0.3)


func _http_get(host: String, port: int, path: String) -> String:
	var c := StreamPeerTCP.new()
	if c.connect_to_host(host, port) != OK:
		return ""
	var t0 := Time.get_ticks_msec()
	while c.get_status() == StreamPeerTCP.STATUS_CONNECTING and Time.get_ticks_msec() - t0 < 3000:
		c.poll()
		await get_tree().process_frame
	if c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return ""
	c.put_data(("GET %s HTTP/1.0\r\nHost: %s\r\n\r\n" % [path, host]).to_utf8_buffer())
	var out := ""
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		c.poll()
		var n := c.get_available_bytes()
		if n > 0:
			out += c.get_utf8_string(n)
		elif c.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		await get_tree().process_frame
	return out


## 1.0: yönetim, yedek, hız denetimi, lig, feribot ve Sanayi/fabrika, sesler.
func _test_10(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 50000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.0: Yedekleme ve yönetim")
	var f := Net._backup("test")
	check(f != "" and FileAccess.file_exists(Net.save_path.get_base_dir().path_join("yedekler").path_join(f)), "kayıt yedeği alındı (%s)" % f)
	check(Net.is_admin(me), "sunucuyu kuran yönetici")
	Net.send_chat("/hava sis")
	await _wait(0.6)
	check(Env.weather == "fog", "/hava sis komutu çalıştı")
	_chats.clear()
	Net.send_chat("/duyuru Bakım yok, iyi oyunlar!")
	await _wait(0.6)
	check(_chats.any(func(c): return c[1] == "Bakım yok, iyi oyunlar!"), "/duyuru herkese gitti")
	Env.force_weather("clear")
	var helper := Net.id_by_name("Yardimci")
	if helper != 0:
		Net.send_chat("/sustur Yardimci 1")
		await _wait(0.6)
		check(float(Net._muted.get("Yardimci", 0.0)) > Time.get_unix_time_from_system(), "/sustur çalıştı")
		Net._muted.erase("Yardimci")
	var sd := Net.status_data()
	check(sd.version == Net.VERSION and sd.has("online") and sd.has("backups"), "durum bilgisi hazır")
	print("== 1.0: Hız denetimi")
	Net._pos_t.erase(me)
	w.my_pos = Map.SPAWN
	await _wait(0.2)
	Net._pos_t.erase(me)
	check(not Net._speed_ok(me, Map.SPAWN + Vector2(0, 1200)), "ışınlanma hilesi reddedildi")
	check(Net._speed_ok(me, Net.positions[me] + Vector2(20, 0)), "normal yürüyüş kabul edildi")

	print("== 1.0: Lig ve sezonlar")
	League.add(me, "fish", 500.0)
	League.add(me, "goals", 2.0)
	League.refresh()
	await _wait(0.4)
	var boards: Dictionary = League.view.get("boards", {})
	check(not boards.get("fish", []).is_empty() and boards.fish[0][0] == Net.my_name, "balık liginde birinci")
	check(not boards.get("wealth", []).is_empty(), "zenginlik sıralaması hesaplandı")
	var m0 := Net.my_money()
	League.force_end()
	await _wait(0.5)
	check(not League.view.get("history", []).is_empty() and not League.view.get("badges", []).is_empty(), "sezon bitti: Şampiyonlar Duvarı ve rozet")
	check(Net.my_money() >= m0 + League.PRIZES[0], "sezon ödülü alındı")
	w.open_simple_panel("res://scripts/ui/league_panel.gd")
	await get_tree().process_frame
	check(w.panel != null, "lig penceresi açıldı")
	w._close_panel()

	print("== 1.0: Feribot ve Sanayi Limanı")
	check(Map.in_south(Vector2(1000, 3700)) and not Map.in_sea(Vector2(1000, 3700)) and Map.in_sea(Vector2(1000, 3400)), "güneyde Sanayi kıyısı")
	w.my_pos = Map.FERRY_STOPS.sehir[1]
	await _wait(0.3)
	check(w.zone.get("type") == "ferry", "şehirde feribot iskelesi")
	Work.ride_ferry("liman")
	await _wait(0.5)
	check(w.my_pos.distance_to(Map.FERRY_STOPS.liman[1]) < 60.0, "feribotla Sanayi Limanı'na gidildi")
	w.my_pos = Map.building("fabrika").rect.get_center() + Vector2(0, 150)
	await _wait(0.3)
	check(w.zone.get("type") == "fabrika", "fabrika bölgesi")
	var items: Array = []
	var res: Array = []
	var cb1 := func(d): items.append(d)
	var cb2 := func(d): res.append(d)
	Factory.item.connect(cb1)
	Factory.result.connect(cb2)
	Factory.start()
	await _wait(0.4)
	check(items.size() == 1, "üretim bandında parça geldi")
	var m1 := Net.my_money()
	Factory.sort(int(items[-1].id), int(Factory._shift[me].cur.color))
	await _wait(0.2)
	check(not res.is_empty() and res[-1].ok and Net.my_money() > m1, "doğru kutu: para kazanıldı")
	var t2 := Time.get_ticks_msec()
	while items.size() < 2 and Time.get_ticks_msec() - t2 < 3000:
		await get_tree().process_frame
	Factory.sort(int(items[-1].id), int(Factory._shift[me].cur.color))
	await _wait(0.2)
	check(not res[-1].ok, "çok hızlı (insan dışı) cevap sayılmadı")
	t2 = Time.get_ticks_msec()
	while items.size() < 3 and Time.get_ticks_msec() - t2 < 3000:
		await get_tree().process_frame
	await _wait(0.4)
	Factory.sort(int(items[-1].id), (int(Factory._shift[me].cur.color) + 1) % 3 if not Factory._shift[me].cur.is_empty() else 0)
	await _wait(0.2)
	check(not res[-1].ok, "yanlış kutu sayılmadı")
	Factory.stop()
	Factory.item.disconnect(cb1)
	Factory.result.disconnect(cb2)
	check(int(Ach.data.c.get("factory", 0)) >= 1, "fabrika başarım sayacı")
	w.my_pos = Map.FERRY_STOPS.liman[1]
	await _wait(0.3)
	Work.ride_ferry("sehir")
	await _wait(0.5)
	check(w.my_pos.distance_to(Map.FERRY_STOPS.sehir[1]) < 60.0, "feribotla şehre dönüldü")

	print("== 1.0: Müzik")
	check(Sfx.MUSIC.has("night") and Sfx.MUSIC.has("winter") and Sfx.MUSIC.has("summer"), "gece/kış/yaz müzikleri tanımlı")


## 1.1: araç/bina özelleştirme, ahır, mutfak ve yemek bonusları, dalış.
func _test_11(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	Net.add_money(me, 80000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.1: Özelleştirme")
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.3)
	Garage.set_style("car", 5)
	await _wait(0.3)
	Garage.set_style("rims", 1)
	await _wait(0.3)
	check(int(Garage.vstyle.get("car", -1)) == 5 and int(Garage.vstyle.get("rims", 0)) == 1, "araba maviye boyandı, altın jant takıldı")
	check(int(Net.roster[me].get("vstyle", {}).get("car", -1)) == 5, "araç görünümü herkese yayınlandı")
	w.my_pos = Vector2(1500, 1000)      # yoldan uzak (otobüs itmesin)
	await _wait(0.3)
	Garage.set_style("car", 2)
	await _wait(0.3)
	if int(Garage.vstyle.car) != 5:
		print("  [debug] konum=", Net.positions[me], " my_pos=", w.my_pos, " galeri=", Map.building("galeri").rect)
	check(int(Garage.vstyle.car) == 5, "Galeri dışında boyanamıyor")

	print("== 1.1: Ahır")
	var rp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			rp = i
			break
	w.my_pos = Map.plot_rect(rp).get_center()
	await _wait(0.3)
	Land.buy(rp)
	await _wait(0.3)
	Land.build_up(rp, "ranch")
	await _wait(0.4)
	check(Farm.is_ranch(Land.view[rp]), "boş arsaya ahır kuruldu")
	Farm.buy_animal(rp, "chicken")
	Farm.buy_animal(rp, "cow")
	await _wait(0.4)
	check(Land.view[rp].ranch.animals.size() == 2, "tavuk ve inek alındı")
	var now := Time.get_unix_time_from_system()
	for a in Land.plots[rp].ranch.animals:
		a.last = now - 1000.0
		a.fed = now + 900.0
	Land._broadcast()
	await _wait(0.2)
	var eggs0 := int(Farm.my_crops.get("yumurta", 0))
	Farm.collect_animals(rp)
	await _wait(0.4)
	check(int(Farm.my_crops.get("yumurta", 0)) > eggs0 and int(Farm.my_crops.get("sut", 0)) >= 2, "yumurta ve süt toplandı")
	for a in Land.plots[rp].ranch.animals:
		a.fed = now - 5000.0
		a.last = now - 5000.0
	Land._broadcast()
	await _wait(0.2)
	check(Farm.animal_ready(Land.view[rp].ranch.animals[0], Land.server_now()) == 0, "aç hayvan üretmiyor")
	var m0 := Net.my_money()
	Farm.feed_animals(rp, false)
	await _wait(0.4)
	check(float(Land.view[rp].ranch.animals[0].fed) > Land.server_now() and Net.my_money() == m0 - 2 * Farm.FEED_PRICE, "hayvanlar yemle beslendi")
	w.my_pos = Map.building("pazar").rect.get_center()
	await _wait(0.3)
	var m1 := Net.my_money()
	Farm.sell("yumurta")
	await _wait(0.3)
	check(Net.my_money() > m1 and not Farm.my_crops.has("yumurta"), "yumurtalar Hal'de satıldı")

	print("== 1.1: Mutfak")
	var hp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			hp = i
			break
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.3)
	Land.buy(hp)
	await _wait(0.3)
	Land.build_up(hp)
	await _wait(0.3)
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.3)
	Homes.buy("stove")
	await _wait(0.3)
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.3)
	Homes.enter(hp)
	await _wait(0.5)
	Homes.place(hp, "stove", 4, 1)
	await _wait(0.3)
	check(Kitchen.has_stove(Land.view[hp]), "evde ocak var")
	var store := Farm.barn(Net.save_data.players[Net.my_name])
	store["domates"] = int(store.get("domates", 0)) + 2
	store["yumurta"] = int(store.get("yumurta", 0)) + 2
	Farm.send_state(me)
	await _wait(0.2)
	Kitchen.cook("menemen")
	await _wait(0.4)
	check(int(Rpg.sheet.items.get("menemen", 0)) == 1, "menemen pişti")
	Rpg.use_energy(me, 50)
	await _wait(0.2)
	var e0 := float(Rpg.sheet.energy)
	Rpg.use("menemen")
	await _wait(0.4)
	check(float(Rpg.sheet.energy) > e0 + 30 and Rpg.buff(me, "work") and Rpg.sheet.get("buffs", {}).has("work"), "menemen yendi: enerji ve iş bonusu")
	Kitchen.cook("pasta")
	await _wait(0.3)
	check(int(Rpg.sheet.items.get("pasta", 0)) == 0, "malzeme yokken pasta pişmedi")
	w.open_simple_panel("res://scripts/ui/profile_panel.gd")
	await get_tree().process_frame
	w._close_panel()
	Homes.exit_home()
	await _wait(0.4)

	print("== 1.1: Dalış")
	w.my_pos = Vector2(1200, 2250)
	await _wait(0.3)
	Garage.ride("boat")
	await _wait(0.3)
	Dive.dive()
	await _wait(0.5)
	check(Dive.state == "down" and w._dive and Map.SEA_BED.has_point(w.my_pos), "tekneden denize dalındı")
	Dive._acc = 99.0
	Dive._process(0.1)
	await _wait(0.3)
	check(not Dive.items.is_empty(), "deniz tabanında istiridye var")
	var it: Dictionary = {}
	for x in Dive.items:
		if x.k == "oyster":
			it = x
	w.my_pos = Vector2(float(it.x), float(it.y))
	await _wait(0.3)
	var nb := Jobs.my_fish.size()
	w._open_panel()
	await _wait(0.4)
	check(Jobs.my_fish.size() == nb + 1 and str(Jobs.my_fish[-1].name).contains("İnci"), "inci toplandı: %s" % (Jobs.my_fish[-1].name if Jobs.my_fish.size() > nb else "-"))
	Dive.surface()
	await _wait(0.5)
	check(Dive.state == "" and not w._dive and w.my_ride() == "boat" and Map.in_sea(w.my_pos), "yüzeye çıkıldı, tekneye dönüldü")
	Dive.dive()
	await _wait(0.4)
	Dive._divers[me].until = Time.get_unix_time_from_system() - 1.0
	await _wait(0.4)
	check(Dive.state == "", "oksijen bitince otomatik yüzeye çıkıldı")
	Garage.ride("")
	await _wait(0.2)
	Land.sell(rp)
	Land.sell(hp)
	await _wait(0.3)


## 1.2: dağ (teleferik, maden, kayak), müze, restoran menüsü, konser.
func _test_12(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	Net.add_money(me, 80000)
	Rpg.add_xp(me, "", 20000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.2: Teleferik ve maden")
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(0, 70)
	await _wait(0.3)
	var m0 := Net.my_money()
	w._open_panel()
	await _wait(0.5)
	check(Map.MOUNTAIN.has_point(w.my_pos) and w._mount and Net.my_money() == m0 - Mountain.CABLE_PRICE, "teleferikle dağa çıkıldı (%s)" % w.my_pos)
	Garage.ride("car")
	await _wait(0.3)
	check(w.my_ride() == "", "dağda araca binilmiyor")
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	Mountain.buy("pickaxe")
	await _wait(0.3)
	check(Mountain.has_pickaxe and bool(rec.get("pickaxe", false)), "Dağ Evi'nden kazma alındı")
	Mountain._spawn_rock()
	Mountain._broadcast_rocks()
	await _wait(0.3)
	check(not Mountain.rocks.is_empty(), "maden ocağında kaya var")
	var r: Dictionary = Mountain.rocks[0]
	w.my_pos = Vector2(float(r.x), float(r.y) + 30)
	await _wait(0.3)
	check(w.zone.get("type", "") == "rock", "kayanın yanında kırma bölgesi")
	var before := 0
	for k in Farm.my_crops:
		if Mountain.ORES.has(k):
			before += int(Farm.my_crops[k])
	for _k in 8:
		Mountain._last_hit.clear()
		Mountain.hit(int(r.id))
		await _wait(0.15)
	var after := 0
	for k in Farm.my_crops:
		if Mountain.ORES.has(k):
			after += int(Farm.my_crops[k])
	var gone := true
	for x in Mountain.rocks:
		if int(x.id) == int(r.id):
			gone = false
	check(gone and after == before + 1, "kaya kırıldı, ambara maden girdi")
	check(Rpg.skill(me, "mining") >= 1 and int(rec.rpg.skills.get("mining", 0)) > 0, "madencilik XP'si arttı")
	var store := Farm.barn(rec)
	store["altin"] = int(store.get("altin", 0)) + 2
	store["f_ammonit"] = int(store.get("f_ammonit", 0)) + 1
	Farm.send_state(me)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	var m1 := Net.my_money()
	Mountain.sell_all(false)
	await _wait(0.3)
	check(Net.my_money() > m1 + 300 and not Farm.my_crops.has("altin") and Farm.my_crops.has("f_ammonit"), "madenler satıldı, fosil kaldı")

	print("== 1.2: Kayak")
	w.my_pos = Map.LIFT + Vector2(0, 40)
	await _wait(0.3)
	check(w.zone.get("type", "") == "lift", "telesiyej bölgesi")
	rec.ach.got["summit"] = 1
	var m2 := Net.my_money()
	w._open_panel()
	await _wait(0.1)
	check(w.my_ride() == "ski" and w.my_pos.distance_to(Map.SKI_TOP) < 200 and Net.my_money() == m2 - Mountain.SKI_RENT, "kiralık kayakla zirvede")
	var gates: Array = Map.ski_gates()
	var res := {}
	Mountain.ski_result.connect(func(d): res.merge(d, true), CONNECT_ONE_SHOT)
	for g in gates:
		w.my_pos = Vector2(g.x, g.y - 40)
		await _wait(0.2)
	w.my_pos = Vector2(Map.SLOPE.get_center().x, Map.SKI_FINISH_Y + 10)
	await _wait(0.5)
	check(res.get("ok", false) and int(res.get("missed", -1)) == 0 and int(res.get("pay", 0)) > 0, "pist temiz bitti: %s" % res.get("text", "-"))
	check(not Mountain.best.is_empty() and rec.ach.got.has("ski_clean"), "pist rekoru yazıldı, Kusursuz İniş başarımı")
	check(w.my_ride() == "", "finişte kayak çıkarıldı")
	# kapı kaçırma cezası
	w.my_pos = Map.LIFT + Vector2(0, 40)
	await _wait(0.3)
	Mountain.ski_start()
	await _wait(0.1)
	var res2 := {}
	Mountain.ski_result.connect(func(d): res2.merge(d, true), CONNECT_ONE_SHOT)
	for gi in gates.size():
		var g: Vector2 = gates[gi]
		w.my_pos = Vector2(Map.SLOPE.position.x + 20 if gi == 3 else g.x, g.y - 40)
		await _wait(0.2)
	w.my_pos = Vector2(Map.SLOPE.get_center().x, Map.SKI_FINISH_Y + 10)
	await _wait(0.5)
	check(int(res2.get("missed", 0)) == 1, "kaçan kapı sayıldı (+3 sn): %s" % res2.get("text", "-"))
	var ls: Dictionary = League._data().scores.get("ski", {})
	check(ls.has(Net.my_name), "kayak ligine süre yazıldı")
	# dağdan dön
	w.my_pos = Map.MOUNTAIN_BUILDINGS[1].rect.get_center() + Vector2(0, 80)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.5)
	check(not w._mount and Map.WORLD.has_point(w.my_pos), "teleferikle şehre dönüldü")

	print("== 1.2: Müze")
	var bag: Array = rec.get("fish", [])
	for n in ["Sazan", "İnci", "Siyah İnci", "Batık Hazinesi", "Hazine Sandığı", "Korsan Altını", "Korsan Pusulası", "Korsan Yüzüğü"]:
		bag.append({"name": n, "price": 100})
	Jobs.send_inventory(me)
	w.my_pos = Map.building("muze").rect.get_center() + Vector2(0, 160)
	await _wait(0.3)
	check(w.zone.get("type", "") == "muze", "müze kapısında")
	w._open_panel()
	await _wait(0.4)
	var m3 := Net.my_money()
	Museum.donate("fish:Sazan")
	await _wait(0.3)
	check(Museum.view.has("fish:Sazan") and str(Museum.view["fish:Sazan"].by) == Net.my_name and Net.my_money() == m3 + Museum.DONATE_MONEY, "Sazan bağışlandı, ad vitrinde")
	bag.append({"name": "Sazan", "price": 20})
	Jobs.send_inventory(me)
	await _wait(0.2)
	var m4 := Net.my_money()
	Museum.donate("fish:Sazan")
	await _wait(0.3)
	check(Net.my_money() == m4, "aynı parça ikinci kez bağışlanmıyor")
	Museum.donate("barn:f_ammonit")
	await _wait(0.3)
	check(Museum.view.has("barn:f_ammonit"), "fosil bağışlandı")
	var m5 := Net.my_money()
	for n in ["İnci", "Siyah İnci", "Batık Hazinesi", "Hazine Sandığı", "Korsan Altını", "Korsan Pusulası", "Korsan Yüzüğü"]:
		Museum.donate("fish:" + n)
		await _wait(0.2)
	await _wait(0.2)
	check(Net.my_money() >= m5 + 7 * Museum.DONATE_MONEY + Museum.SET_REWARD, "Deniz Hazineleri koleksiyonu tamamlandı, ödül alındı")
	check(Museum.progress().x == 9, "müze ilerlemesi 9 parça")
	await get_tree().process_frame
	w._close_panel()

	print("== 1.2: Restoran menüsü")
	var bp := -1
	for i in Land.view.size():
		if Land.view[i].owner == "":
			bp = i
			break
	w.my_pos = Map.plot_rect(bp).get_center()
	await _wait(0.3)
	Land.buy(bp)
	await _wait(0.3)
	Land.build_up(bp, "biz")
	await _wait(0.3)
	Land.build_up(bp, "biz")
	await _wait(0.4)
	check(Biz.is_biz(Land.view[bp]) and int(Land.view[bp].level) == 2, "kafe açıldı")
	store = Farm.barn(rec)
	store["domates"] = int(store.get("domates", 0)) + 8
	store["yumurta"] = int(store.get("yumurta", 0)) + 8
	Farm.send_state(me)
	await _wait(0.2)
	for _k in 3:
		Kitchen.cook("menemen")
		await _wait(0.25)
	check(int(Rpg.sheet.items.get("menemen", 0)) >= 3, "kafenin mutfağında menemen pişti")
	Biz.menu_add(bp, "menemen")
	await _wait(0.3)
	var menu: Dictionary = Biz.menu_of(Land.view[bp])
	check(menu.has("menemen") and int(menu.menemen.n) >= 3 and int(Rpg.sheet.items.get("menemen", 0)) == 0, "menemen menüye kondu")
	var v := Kitchen.dish_value("menemen")
	Biz.menu_price(bp, "menemen", int(v * 0.5))
	await _wait(0.3)
	check(int(Biz.menu_of(Land.view[bp]).menemen.price) == int(v * 0.5), "fiyat ayarlandı")
	w.zone = {"type": "realestate", "label": "x", "plot": bp}
	w._open_panel()
	await _wait(0.4)
	w._close_panel()
	var cash0 := int(Land.plots[bp].biz.cash)
	var got := Biz._menu_tick(bp, Land.plots[bp], 6.0)
	Land.plots[bp].biz["cash"] = int(Land.plots[bp].biz.cash) + got
	Land._broadcast()
	await _wait(0.3)
	check(got > 0 and int(Land.plots[bp].biz.get("menu_sold", 0)) > 0, "NPC müşteriler menüden sipariş verdi (+%d)" % got)
	if Biz.menu_of(Land.plots[bp]).has("menemen"):
		Rpg.use_energy(me, 60)
		await _wait(0.2)
		var e0 := float(Rpg.sheet.energy)
		Biz.order(bp, "menemen")
		await _wait(0.3)
		check(float(Rpg.sheet.energy) > e0 + 30, "restoranda menemen yendi")
	Land.sell(bp)
	await _wait(0.3)

	print("== 1.2: Konser")
	w.my_pos = Map.STAGE.get_center()
	await _wait(0.3)
	check(w.zone.get("type", "") == "stage", "sahne bölgesi")
	Band.buy("gitar")
	await _wait(0.3)
	check("gitar" in Band.owned, "gitar alındı")
	w._open_panel()
	await _wait(0.3)
	Band.play(0, "gitar")
	await _wait(0.3)
	check(Band.is_playing() and str(Net.roster[me].get("playing", "")) == "gitar", "sahnede gitar çalınıyor")
	# testi kısa tutmak için şarkıyı ilk 6 notaya indir (sunucu ve istemci aynı)
	Band._play[me].notes = Band._play[me].notes.slice(0, 6)
	Band.session.notes = Band.session.notes.slice(0, 6)
	var notes: Array = Band.session.notes
	for i in notes.size():
		var wait_t: float = float(Band.session.t0) + float(notes[i][0]) - Time.get_ticks_msec() / 1000.0
		if wait_t > 0.0:
			await _wait(wait_t)
		w.panel._lane_pressed(int(notes[i][1]))
	var endres := {}
	Band.song_ended.connect(func(d): endres.merge(d, true), CONNECT_ONE_SHOT)
	await _wait(1.0)
	check(endres.get("ok", false) and float(endres.get("acc", 0)) >= 0.99 and int(endres.get("pay", 0)) > 0, "şarkı bitti: %s" % endres.get("text", "-"))
	check(str(Net.roster[me].get("playing", "")) == "", "çalma bitti, kadro güncellendi")
	w._close_panel()
	await _wait(0.2)


## 1.3: telefon, takas, at ve hipodrom, kamp, animasyon efektleri.
func _test_13(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	Net.add_money(me, 50000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.3: Telefon")
	Net.save_data.players["Uzakta"] = {"money": 100}
	Phone.send("Uzakta", "Merhaba, çevrimdışıyken de gelsin!")
	await _wait(0.3)
	var box: Array = Net.save_data.inbox.get("Uzakta", [])
	check(box.size() == 1 and str(box[0].w) == Net.my_name and not box[0].r, "çevrimdışı oyuncuya mesaj kutusuna düştü")
	check(Phone.inbox.size() >= 1 and Phone.inbox[-1].get("o", false), "giden mesaj telefonda görünüyor")
	Phone.add_friend("Uzakta")
	await _wait(0.3)
	check(Phone.friends.size() == 1 and not Phone.friends[0].mutual and not Phone.friends[0].has("pos"), "arkadaş eklendi; karşılıklı değilken konum gizli")
	Net.announce("Test haberi: şehre yeni teleferik!")
	Phone.refresh()
	await _wait(0.3)
	check(not Phone.news.is_empty() and str(Phone.news[-1].x).contains("teleferik"), "şehir haberleri telefonda")
	var helper := Net.id_by_name("Yardimci")
	if helper != 0:
		Phone.send("Yardimci", "Selam yardımcı")
		await _wait(0.4)
		var hb: Array = Net.save_data.inbox.get("Yardimci", [])
		check(not hb.is_empty() and str(hb[-1].x) == "Selam yardımcı", "çevrimiçi oyuncuya mesaj iletildi")
	w.set_photo_mode(true)
	await get_tree().process_frame
	check(w.photo_mode and not w.ui_layer.visible, "fotoğraf modu: arayüz gizlendi")
	w.set_photo_mode(false)
	await get_tree().process_frame
	check(not w.photo_mode and w.ui_layer.visible, "fotoğraf modundan çıkıldı")
	w.open_phone()
	await _wait(0.3)
	for t in ["friends", "news", "album", "msg"]:
		w.panel._show(t)
		await get_tree().process_frame
	w._close_panel()

	print("== 1.3: Takas")
	if helper == 0:
		print("  (yardımcı yok, takas testi atlandı)")
	else:
		w.my_pos = Net.positions[helper] + Vector2(40, 0)
		await _wait(0.4)
		var bag: Array = rec.get("fish", [])
		bag.append({"name": "Takas Levreği", "price": 77})
		Jobs.send_inventory(me)
		var store := Farm.barn(rec)
		store["domates"] = int(store.get("domates", 0)) + 3
		Farm.send_state(me)
		await _wait(0.2)
		var hrec: Dictionary = Net.save_data.players["Yardimci"]
		var hfish0: int = hrec.get("fish", []).size()
		var hdom0 := int(Farm.barn(hrec).get("domates", 0))
		var m0 := Net.my_money()
		Trade.invite("Yardimci")
		await _wait(1.2)
		check(Trade.active(), "takas penceresi açıldı (yardımcı kabul etti)")
		if Trade.active():
			check(w.panel != null and w.panel.has_method("_push"), "takas paneli ekranda")
			Trade.offer({"money": 999999999, "fish": [], "barn": {}, "items": {}})
			await _wait(0.3)
			check(int(Trade.view.offers[Trade.view.me].money) == 0, "sahip olunmayan para teklif edilemiyor")
			var fi := Jobs.my_fish.size() - 1
			Trade.offer({"money": 0, "fish": [fi], "barn": {"domates": 2}, "items": {}})
			await _wait(0.6)
			var other := "a" if Trade.view.me == "b" else "b"
			check(int(Trade.view.offers[other].money) == 40, "yardımcı 40 TL koydu")
			Trade.confirm()
			await _wait(1.0)
			check(not Trade.active() and Net.my_money() - m0 in [40, 340], "takas tamamlandı: +40 TL")
			check(hrec.fish.size() == hfish0 + 1 and str(hrec.fish[-1].name) == "Takas Levreği" and int(Farm.barn(hrec).get("domates", 0)) == hdom0 + 2, "balık ve 2 domates yardımcıya geçti")
		if w.panel != null:
			w._close_panel()

	print("== 1.3: At ve hipodrom")
	w.my_pos = Map.building("hara").rect.get_center() + Vector2(0, 88)
	await _wait(0.4)
	check(w.zone.get("type", "") == "hara", "hara kapısında")
	Horses.buy()
	await _wait(0.4)
	check(Horses.my_horses.size() == 1 and rec.horses.size() == 1, "at alındı: %s" % (Horses.my_horses[0].n if Horses.has_horse() else "-"))
	var h0: Dictionary = rec.horses[0]
	var spd0 := int(h0.spd) + int(h0.sta)
	Horses.train(0, "spd")
	await _wait(0.3)
	var tot1 := int(rec.horses[0].spd) + int(rec.horses[0].sta)
	check(tot1 > spd0, "antrenmanla at gelişti")
	Horses.train(0, "sta")
	await _wait(0.3)
	check(int(rec.horses[0].spd) + int(rec.horses[0].sta) == tot1, "antrenman bekleme süresi (5 dk)")
	w.my_pos = Map.building("hara").rect.get_center() + Vector2(0, 200)
	await _wait(0.3)
	w._toggle_horse()
	await _wait(0.4)
	check(w.my_ride() == "horse" and int(Net.roster[me].get("hc", -1)) == int(rec.horses[0].c), "ata binildi")
	w._toggle_horse()
	await _wait(0.3)
	check(w.my_ride() == "", "attan inildi")
	rec.horses[0]["fed"] = 0.0
	Horses.send_state(me)
	w._toggle_horse()
	await _wait(0.4)
	check(w.my_ride() == "", "aç ata binilmiyor")
	w.my_pos = Map.building("hara").rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	Horses.feed(0, false)
	await _wait(0.3)
	check(float(rec.horses[0].fed) > Time.get_unix_time_from_system(), "at beslendi")
	w.my_pos = Map.HIPPO_BOOTH + Vector2(40, 0)
	await _wait(0.4)
	check(w.zone.get("type", "") == "hipodrom", "hipodrom gişesi")
	w._open_panel()
	await _wait(0.3)
	Horses.join_race()
	await _wait(0.4)
	check(str(Horses.race.get("state", "")) == "lobby" and Horses.race.lanes.size() == 1, "yarışa katılındı (bekleme)")
	var m1 := Net.my_money()
	Horses.bet(0, 200)
	await _wait(0.3)
	check(Net.my_money() == m1 - 200, "kendi atına bahis")
	Horses._race.t = 0.0
	await _wait(0.4)
	check(str(Horses._race.state) == "run" and Horses._race.lanes.size() == 4, "yarış başladı, NPC atlar katıldı")
	var odds := float(Horses._race.lanes[0].odds)
	await _wait(3.2)
	Horses.whip()
	await _wait(0.2)
	check(float(Horses._race.lanes[0].st) < float(Horses._race.lanes[0].stmax), "kamçı dayanıklılık harcadı")
	Horses._race.lanes[0].x = Map.HIPPO_FINISH_X - 10.0
	for li in range(1, 4):
		Horses._race.lanes[li].x = Map.HIPPO_START_X
	var m2 := Net.my_money()
	await _wait(0.5)
	for li in range(1, 4):
		Horses._race.lanes[li].x = Map.HIPPO_FINISH_X + 1.0
	await _wait(0.6)
	check(int(Horses._race.lanes[0].get("place", 0)) == 1, "atımız birinci geldi")
	check(Net.my_money() >= m2 + Horses.PRIZES[0] + int(round(200 * odds)) and int(rec.horses[0].wins) == 1, "ödül ve bahis kazancı alındı")
	w._close_panel()

	print("== 1.3: Kamp ve orman")
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(0, 70)
	await _wait(0.3)
	Mountain.go_up()
	await _wait(0.5)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	Camp.buy("tent")
	Camp.buy("marshmallow")
	Camp.buy("marshmallow")
	Camp.buy("odun")
	await _wait(0.4)
	check(Camp.has_tent and int(Rpg.sheet.items.get("marshmallow", 0)) == 2 and int(Farm.my_crops.get("odun", 0)) >= 2, "çadır, marshmallow ve odun alındı")
	w.my_pos = Vector2(8020, 2280)
	await _wait(0.4)
	check(w.zone.get("type", "") == "tent_pitch", "kamp alanında çadır kurma bölgesi")
	w._open_panel()
	await _wait(0.4)
	check(Camp.tents.has(Net.my_name), "çadır kuruldu")
	Rpg.use_energy(me, 40)
	rec["tent_rest"] = 0.0
	await _wait(0.2)
	w._open_panel()
	await _wait(0.4)
	check(float(Rpg.sheet.energy) >= float(Rpg.sheet.max_energy) - 1.0, "çadırda dinlenince enerji doldu")
	w.my_pos = Map.CAMPFIRES[0] + Vector2(0, 60)
	await _wait(0.4)
	check(w.zone.get("type", "") == "fire_light", "ateş yakma bölgesi")
	w._open_panel()
	await _wait(0.4)
	if Camp.fire_left(0) <= 200.0:
		print("  [debug] fires=", Camp.fires, " srv=", Camp._fire_until, " left=", Camp.fire_left(0))
	check(Camp.fire_left(0) > 200.0, "kamp ateşi yandı")
	w._update_zone()
	check(w.zone.get("type", "") == "roast", "yanan ateşte marshmallow bölgesi")
	w._open_panel()
	await _wait(0.4)
	check(Net.roster[me].get("roast", false), "marshmallow kızarıyor")
	await _wait(3.2)
	var it: Dictionary = Rpg.sheet.items
	check(int(it.get("kizarmis_marshmallow", 0)) + int(it.get("yanik_marshmallow", 0)) == 1 and not Net.roster[me].get("roast", false), "marshmallow kızardı")
	Camp._spawn_spot()
	Camp._spawn_spot()
	Camp._broadcast({"spots": Camp._spots})
	await _wait(0.3)
	var sp: Dictionary = Camp.spots[0]
	w.my_pos = Vector2(float(sp.x), float(sp.y) + 20)
	await _wait(0.3)
	var before := 0
	for k in Farm.my_crops:
		before += int(Farm.my_crops[k])
	w._open_panel()
	await _wait(0.4)
	var after := 0
	for k in Farm.my_crops:
		after += int(Farm.my_crops[k])
	check(after > before, "ormandan ürün toplandı")
	var m3 := Net.my_money()
	Camp._star_until = Time.get_ticks_msec() / 1000.0 + 5.0
	Camp._wished.clear()
	w.my_pos = Map.CAMP.get_center()
	await _wait(0.2)
	Camp.wish()
	await _wait(0.3)
	var m4 := Net.my_money()
	Camp.wish()
	await _wait(0.3)
	check(m4 >= m3 + Camp.STAR_REWARD and Net.my_money() == m4, "kayan yıldıza dilek tutuldu (bir kez)")
	check(Kitchen.RECIPES.has("mantar_sote") and Kitchen.dish_value("orman_turtasi") > 0, "orman tarifleri")
	check(Museum.all_keys().has("barn:kuzugobegi"), "müzede Orman koleksiyonu")
	w.my_pos = Map.TELESCOPE + Vector2(0, 40)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	check(w.panel != null, "teleskop paneli açıldı")
	w._close_panel()
	w.my_pos = Map.MOUNTAIN_BUILDINGS[1].rect.get_center() + Vector2(0, 80)
	await _wait(0.3)
	Mountain.go_down()
	await _wait(0.5)

	print("== 1.3: Animasyon efektleri")
	w.fx.clear()
	Net.add_money(me, 5)
	await _wait(0.3)
	var kinds: Array = w.fx.map(func(f): return f.k)
	check("money" in kinds, "para değişince yüzen tutar efekti")
	w.add_fx("chips", w.my_pos, 0.1)
	await _wait(0.3)
	check(not w.fx.any(func(f): return f.k == "chips"), "süresi dolan efekt silindi")


## 1.4: okul, dedektif, lunapark, havalimanı ve balon.
func _test_14(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	Net.add_money(me, 50000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.4: Okul")
	w.my_pos = Map.building("okul").rect.get_center() + Vector2(0, 118)
	await _wait(0.4)
	check(w.zone.get("type", "") == "okul", "okul kapısında")
	var med0 := Rpg.perk(me, "medicine_pay")
	School.start_exam("ilkyardim")
	await _wait(0.4)
	check(School.current.get("qs", []).size() == 5 and not School.current.qs[0].has("answer"), "sınav geldi (5 soru, cevaplar gizli)")
	var ex: Dictionary = School._exams.get(me, {})
	var ans: Array = []
	for pk in ex.get("picks", []):
		ans.append((pk[1] as Array).find(int(School.COURSES.ilkyardim.qs[int(pk[0])][2])))
	var res := {}
	School.result.connect(func(d): res.merge(d, true), CONNECT_ONE_SHOT)
	School.answer(ans)
	await _wait(0.4)
	check(res.get("ok", false) and School.has("ilkyardim"), "ilk yardım diploması alındı: %s" % res.get("text", "-"))
	check(absf(Rpg.perk(me, "medicine_pay") - med0 - 0.15) < 0.001, "diploma hastane maaşına +%15 ekledi")
	School.start_exam("finans")
	await _wait(0.4)
	var res2 := {}
	School.result.connect(func(d): res2.merge(d, true), CONNECT_ONE_SHOT)
	School.answer([-1, -1, -1, -1, -1])
	await _wait(0.4)
	check(not res2.get("ok", true) and not School.has("finans"), "boş sınav kaldı")
	var m0 := Net.my_money()
	School.start_exam("finans")
	await _wait(0.3)
	check(Net.my_money() == m0 and School._exams.get(me, {}).is_empty(), "kalınca 2 dk tekrar girilemiyor")

	print("== 1.4: Dedektif")
	w.my_pos = Map.DETECTIVE + Vector2(0, 40)
	await _wait(0.4)
	check(w.zone.get("type", "") == "dedektif", "dedektif bürosu")
	w._open_panel()
	await _wait(0.3)
	Detective.take_case()
	await _wait(0.4)
	check(not Detective.active_case().is_empty() and Detective.active_case().id == "altin_balik", "ilk vaka alındı")
	w.panel._refresh()
	w._close_panel()
	var cs := Detective.active_case()
	Detective.accuse("s1")
	await _wait(0.3)
	check(int(Detective.state.get("case", -1)) == 0, "delil toplamadan suçlanamıyor")
	for cl in cs.clues:
		w.my_pos = cl.pos + Vector2(0, 6)
		await _wait(0.35)
		w._open_panel()
		await _wait(0.3)
	check(Detective.state.clues.size() == 3, "3 ipucu bulundu")
	for sp in cs.suspects:
		w.my_pos = sp.pos + Vector2(0, 40)
		await _wait(0.35)
		w._open_panel()
		await _wait(0.3)
	check(Detective.state.talked.size() == 3 and Detective.state.says.has("s1"), "3 şüpheli sorgulandı")
	Detective.accuse("s2")
	await _wait(0.3)
	check(float(Detective.state.get("wrong_left", 0.0)) > 0.0, "yanlış suçlama: bekleme")
	rec.detective["wrong_until"] = 0.0
	var m1 := Net.my_money()
	Detective.accuse("s1")
	await _wait(0.4)
	check(Detective.state.get("solved", []).has("altin_balik") and Net.my_money() >= m1 + int(1500 * 0.7), "vaka çözüldü, ödül (bir yanlışla %70)")

	print("== 1.4: Lunapark")
	w.my_pos = Map.SHUTTLE_CITY + Vector2(0, 20)
	await _wait(0.4)
	check(w.zone.get("type", "") == "shuttle", "servis durağı")
	var m2 := Net.my_money()
	w._open_panel()
	await _wait(0.5)
	check(w._fair and Map.FAIR.has_point(w.my_pos) and Net.my_money() <= m2 - Fair.SHUTTLE_PRICE + 200, "servisle fuara gelindi")
	w.my_pos = Map.TICKET_BOOTH + Vector2(0, 50)
	await _wait(0.3)
	Fair.buy_jeton()
	Fair.buy_jeton()
	await _wait(0.4)
	check(Fair.jeton == 10, "10 jeton alındı")
	w.my_pos = Map.FERRIS + Vector2(0, Map.FERRIS_R + 60)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.5)
	check(w.my_ride() == "ferris" and w.my_pos.distance_to(Map.FERRIS) < Map.FERRIS_R + 5 and Fair.jeton == 8, "dönme dolaba binildi")
	await _wait(0.5)
	var seatp: Vector2 = w.my_pos
	await _wait(0.6)
	check(w.my_pos.distance_to(seatp) > 3.0, "dolap dönüyor")
	Fair._ferris[me] = 0.0
	await _wait(0.4)
	check(w.my_ride() == "" and w.my_pos.distance_to(Map.FERRIS) > Map.FERRIS_R, "dolaptan inildi")
	w.my_pos = Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y + 40)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.5)
	check(w.my_ride() == "bumper" and Map.BUMPER.has_point(w.my_pos) and Fair.npcs.size() == Fair.BUMPER_NPCS, "çarpışan arabaya binildi, NPC arabalar var")
	var npc0: Vector2 = Fair._npcs[0].p
	w.my_pos = npc0 + Vector2(30, 0)
	Net.positions[me] = w.my_pos
	Fair.bump("npc:0")
	await _wait(0.1)
	w.my_pos = Map.BUMPER.position + Vector2(40, 40)      # boş köşe (gerçek çarpışma kodu tekrar saymasın)
	for n in Fair._npcs:
		n.p = Map.BUMPER.end - Vector2(60, 60)
		n.v = Vector2.ZERO
	await _wait(0.2)
	check(Fair.bumper_pts == 1, "NPC arabaya çarpınca puan")
	Net.positions[me] = npc0 + Vector2(30, 0)
	Fair.bump("npc:0")
	Net.positions[me] = w.my_pos
	await _wait(0.3)
	check(Fair.bumper_pts == 1, "aynı arabaya hemen tekrar sayılmaz")
	var b0 := Fair.bilet
	Fair._bumper[me].end = 0.0
	await _wait(0.4)
	check(w.my_ride() == "" and Fair.bilet == b0 + 2, "tur bitti, 2 bilet")
	w.my_pos = Map.GALLERY + Vector2(0, 50)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	Fair.start_gallery()
	await _wait(0.3)
	check(not Fair.gallery.is_empty() and Fair.gallery.targets.size() > 10, "atış poligonu başladı")
	var tg: Dictionary = Fair.gallery.targets[0]
	var wt: float = float(Fair.gallery.t0) + float(tg.t) + 0.3 - Time.get_ticks_msec() / 1000.0
	if wt > 0.0:
		await _wait(wt)
	Fair.shoot(0)
	Fair.shoot(Fair.gallery.targets.size() - 1)
	await _wait(0.3)
	check(int(Fair.gallery.get("pts", 0)) == Fair.target_points(tg), "ekrandaki ördek vuruldu, henüz çıkmayan sayılmadı")
	var b1 := Fair.bilet
	Fair._gallery[me].t0 = -1000.0
	await _wait(0.4)
	if Fair.bilet != b1 + Fair.target_points(tg):
		print("  [debug] bilet=", Fair.bilet, " b1=", b1, " g=", Fair._gallery.get(me, "yok"), " cl=", Fair.gallery.get("pts", "-"))
	check(Fair.bilet == b1 + Fair.target_points(tg), "atış bitti, puan kadar bilet")
	w._close_panel()
	w.my_pos = Map.TICKET_BOOTH + Vector2(0, 50)
	await _wait(0.3)
	Fair._data(rec)["bilet"] = 30
	Fair.send_state(me)
	Fair.prize("pelus_ayi")
	await _wait(0.4)
	check(int(Homes.depot.get("pelus_ayi", 0)) == 1 and Fair.bilet == 5, "peluş ayı kazanıldı (depoda)")
	w.my_pos = Map.CANDY + Vector2(0, 40)
	await _wait(0.3)
	Fair.buy_candy()
	await _wait(0.3)
	check(int(Rpg.sheet.items.get("pamuk_seker", 0)) == 1, "pamuk şeker alındı")

	print("== 1.4: Balon ve uçuş")
	w.my_pos = Map.BALLOON_FIELD + Vector2(0, 60)
	await _wait(0.3)
	check(w.zone.get("type", "") == "balloon", "balon alanı")
	w._open_panel()
	await _wait(0.5)
	check(w.my_ride() == "balloon" and Airport.in_balloon() and Map.WORLD.has_point(w.my_pos), "balon şehrin üstünde")
	var bp0: Vector2 = w.my_pos
	await _wait(0.6)
	check(w.my_pos.distance_to(bp0) > 20.0, "balon güzergâhta ilerliyor")
	Airport._balloon[me] = 0.0
	await _wait(0.5)
	check(w.my_ride() == "" and w._fair and not Airport.in_balloon(), "balon indi, fuara dönüldü")
	w.my_pos = Map.FAIR_BUILDINGS[0].rect.get_center() + Vector2(0, 130)
	await _wait(0.3)
	check(w.zone.get("type", "") == "terminal", "havalimanı terminali")
	var flights := []
	Airport.flight.connect(func(d): flights.append(d), CONNECT_ONE_SHOT)
	Airport.fly("sehir")
	await _wait(0.4)
	check(flights.size() == 1 and w._fair, "uçuş başladı (animasyon)")
	await _wait(3.3)
	check(not w._fair and Map.WORLD.has_point(w.my_pos) and w.my_pos.distance_to(Map.SPAWN) < 150, "şehre inildi")


## 1.5: özel günler, spor salonu ve maraton, korsan adası, hayvanat bahçesi, iskeledeki tekneler.
func _test_15(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var me := Net.my_id()
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	Net.add_money(me, 60000)
	Env.force_weather("clear")
	await _wait(0.3)

	print("== 1.5: Özel günler")
	check(Holidays.by_date({"year": 2026, "month": 10, "day": 31}) == "cadilar" and Holidays.by_date({"year": 2026, "month": 12, "day": 31}) == "yilbasi"
		and Holidays.by_date({"year": 2026, "month": 3, "day": 21}) == "ramazan" and Holidays.by_date({"year": 2026, "month": 7, "day": 1}) == "", "takvim doğru")
	Holidays.force("cadilar")
	await _wait(0.3)
	check(Holidays.active == "cadilar", "Cadılar Bayramı açıldı")
	w.my_pos = Holidays.STALL + Vector2(0, 40)
	await _wait(0.3)
	check(w.zone.get("type", "") == "bayram", "bayram tezgâhı")
	Holidays.costume("cadi")
	await _wait(0.3)
	check(str(Net.roster[me].get("costume", "")) == "cadi", "cadı kostümü giyildi (herkes görür)")
	var got := 0
	for b in ["market", "hospital", "casino", "poker", "galeri", "pazar"]:
		w.my_pos = Holidays.door_pos("b:" + b) + Vector2(0, 10)
		await _wait(0.3)
		if w._g_action.get("kind", "") == "knock":
			w._do_g_action()
			await _wait(0.3)
		got = int(Rpg.sheet.items.get("seker", 0))
		if got > 0:
			break
	check(got > 0, "kapı çalındı, şeker toplandı (%d)" % got)
	var g0 := int(Rpg.sheet.items.get("seker", 0))
	w._do_g_action()
	await _wait(0.3)
	check(int(Rpg.sheet.items.get("seker", 0)) == g0, "aynı kapı bugün tekrar çalınmaz")
	Holidays.force("yilbasi")
	await _wait(0.3)
	check(not Net.roster[me].has("costume"), "bayram bitince kostüm çıktı")
	Holidays._spawn_gift()
	Holidays._broadcast_gifts()
	await _wait(0.3)
	var gf: Dictionary = Holidays.gifts[0]
	w.my_pos = Vector2(float(gf.x), float(gf.y) + 20)
	await _wait(0.3)
	var m0 := Net.my_money()
	var k0 := int(Rpg.sheet.items.get("kurabiye", 0))
	w._open_panel()
	await _wait(0.4)
	check(Holidays.gifts.size() == 0 and (Net.my_money() > m0 or int(Rpg.sheet.items.get("kurabiye", 0)) > k0), "hediye kutusu açıldı")
	w.my_pos = Holidays.SANTA + Vector2(0, 40)
	await _wait(0.3)
	var m1 := Net.my_money()
	var dep0 := int(Homes.depot.get("yilbasi_agaci", 0))
	w._open_panel()
	await _wait(0.4)
	check(Net.my_money() > m1 or int(Homes.depot.get("yilbasi_agaci", 0)) > dep0, "Noel Baba hediye verdi")
	var m2 := Net.my_money()
	Holidays.santa()
	await _wait(0.3)
	check(Net.my_money() == m2, "Noel Baba günde bir hediye")
	Holidays.force("ramazan")
	await _wait(0.3)
	w.my_pos = Map.NPCS.muhtar.pos + Vector2(0, 50)
	await _wait(0.4)
	check(w._g_action.get("kind", "") == "hand", "bayram: el öpme eylemi")
	var m3 := Net.my_money()
	w._do_g_action()
	await _wait(0.4)
	check(Net.my_money() >= m3 + 100 and int(Rpg.sheet.items.get("lokum", 0)) == 1, "harçlık ve lokum alındı")
	var m4 := Net.my_money()
	w._do_g_action()
	await _wait(0.3)
	check(Net.my_money() == m4, "aynı büyükten bir bayramda bir kez")
	var helper := Net.id_by_name("Yardimci")
	Holidays.force("sevgililer")
	await _wait(0.3)
	w.my_pos = Holidays.STALL + Vector2(0, 40)
	await _wait(0.3)
	Holidays.buy_rose()
	await _wait(0.3)
	check(int(rec.holiday.get("roses", 0)) == 1, "gül alındı")
	if helper != 0:
		w.my_pos = Net.positions[helper] + Vector2(40, 0)
		await _wait(0.5)
		check(w._g_action.get("kind", "") == "rose", "yanındaki oyuncuya gül verme eylemi")
		w._do_g_action()
		await _wait(0.3)
		check(int(rec.holiday.get("roses", 0)) == 0 and rec.ach.got.has("roses"), "gül verildi")
	Holidays.force("yok")
	await _wait(0.3)
	check(Holidays.active == "", "özel gün kapandı")

	print("== 1.5: Spor salonu ve maraton")
	w.my_pos = Map.building("spor").rect.get_center() + Vector2(0, 92)
	await _wait(0.4)
	check(w.zone.get("type", "") == "spor", "spor salonu kapısı")
	var maxe0 := int(Rpg.sheet.max_energy)
	Gym.buy_pass()
	await _wait(0.3)
	check(Gym.has_pass, "günlük giriş alındı")
	Gym.train("cardio")
	await _wait(1.1)
	check(Gym.current.get("kind", "") == "cardio", "koşu bandı başladı")
	var k := 0
	var t_end := Time.get_ticks_msec() / 1000.0 + 15.2
	while Time.get_ticks_msec() / 1000.0 < t_end:
		Gym.step(k % 2)
		k += 1
		await _wait(0.18)
	await _wait(0.6)
	check(int(Gym.fitness.cardio) >= 3, "ideal tempoda koşuldu, kondisyon %d" % int(Gym.fitness.cardio))
	Gym.train("strength")
	await _wait(0.2)
	var t0: float = Gym.current.get("t0", 0.0)
	for i in Gym.LIFT_REPS:
		var target := t0 + Gym.LIFT_PERIOD * (0.25 + 0.5 * (i + 1))
		var wt: float = target - Time.get_ticks_msec() / 1000.0
		if wt > 0.0:
			await _wait(wt)
		Gym.lift()
	await _wait(0.5)
	check(int(Gym.fitness.strength) >= 3, "zamanlı kaldırıldı, kuvvet %d" % int(Gym.fitness.strength))
	check(int(Rpg.sheet.max_energy) == maxe0 + int(int(Gym.fitness.cardio) / 5.0), "kondisyon maksimum enerjiyi artırdı")
	w.my_pos = Map.MARATHON[0]
	await _wait(0.3)
	Gym.start_marathon()
	await _wait(0.3)
	check(not Gym.run.is_empty() and w.nav_target != null, "maraton başladı, yol tarifi var")
	for i in range(1, Map.MARATHON.size()):
		w.my_pos = Map.MARATHON[i]
		await _wait(0.3)
	await _wait(0.3)
	check(Gym.run.is_empty() and not Gym.best.is_empty() and League._data().scores.get("marathon", {}).has(Net.my_name), "maraton bitti, rekor ve lig")

	print("== 1.5: Korsan Adası")
	w.my_pos = Map.KORSAN_CAPTAIN + Vector2(0, 40)
	await _wait(0.4)
	check(Map.on_korsan(w.my_pos) and w.zone.get("type", "") == "korsan", "korsan kaptanın yanında")
	w._open_panel()
	await _wait(0.3)
	Pirates.buy("shovel")
	await _wait(0.3)
	Pirates.maybe_piece(me, 1.0)
	Pirates.maybe_piece(me, 1.0)
	Pirates.maybe_piece(me, 1.0)
	Pirates.buy("piece")
	await _wait(0.4)
	check(Pirates.state.shovel and int(Pirates.state.pieces) == 4, "kürek ve 4 harita parçası")
	Pirates.combine()
	await _wait(0.4)
	check(Pirates.state.has_map and Pirates.map_hint != Vector2.ZERO, "parçalar birleşti, harita var")
	w._close_panel()
	var spot := Vector2(float(rec.pirate.spot[0]), float(rec.pirate.spot[1]))
	var far: Vector2 = Map.KORSAN.get_center() + (Map.KORSAN.get_center() - spot).normalized() * 150.0
	if not Map.on_korsan(far):
		far = Map.KORSAN.get_center()
	w.my_pos = far
	await _wait(0.3)
	var hints := []
	Pirates.dug.connect(func(d): hints.append(d), CONNECT_ONE_SHOT)
	w._open_panel()
	await _wait(0.4)
	check(not hints.is_empty() and str(hints[0].get("hint", "")) != "" and not Pirates.holes.is_empty(), "kazıldı, ipucu: %s" % (hints[0].get("hint", "") if not hints.is_empty() else "-"))
	w.my_pos = spot + Vector2(10, 0)
	await _wait(1.3)
	var m5 := Net.my_money()
	w._open_panel()
	await _wait(0.4)
	check(Net.my_money() >= m5 + 1500 and int(Pirates.state.found) == 1 and not Pirates.state.has_map, "HAZİNE bulundu")
	check(str(rec.fish[-1].name).begins_with("Korsan"), "korsan eşyası kovada (müzeye bağışlanabilir)")
	w.my_pos = Map.KORSAN_CAPTAIN + Vector2(0, 40)
	await _wait(0.3)
	if rec.get("pet") is Dictionary:
		rec.erase("pet")
	Pirates.buy("parrot")
	await _wait(0.4)
	check(str(rec.get("pet", {}).get("kind", "")) == "korsan", "Korsan Papağanı alındı")

	print("== 1.5: Hayvanat bahçesi ve akvaryum")
	w.my_pos = Map.SHUTTLE_CITY + Vector2(0, 20)
	await _wait(0.3)
	Fair.shuttle(true)
	await _wait(0.5)
	w.my_pos = Map.ZOO_GATE + Vector2(0, -50)
	await _wait(0.4)
	check(w.zone.get("type", "") == "zoo_ticket", "turnike: bilet bölgesi")
	check(w._blocked(Map.ZOO_GATE), "biletsiz turnike kapalı")
	w._open_panel()
	await _wait(0.4)
	check(Zoo.has_ticket() and not w._blocked(Map.ZOO_GATE), "bilet alındı, turnike açıldı")
	w.my_pos = Map.ZOO_KEEPER + Vector2(0, 30)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.4)
	check(Zoo.task != "" and w.nav_target != null, "bakıcı işi alındı: %s" % Zoo.task)
	w.my_pos = Zoo.pen_front(Zoo.task)
	await _wait(0.3)
	var m6 := Net.my_money()
	w._open_panel()
	await _wait(0.4)
	check(Net.my_money() >= m6 + Zoo.KEEPER_PAY, "yem teslim edildi, ödeme")
	w.my_pos = Map.ZOO_BUILDINGS[0].rect.get_center() + Vector2(0, 190)
	await _wait(0.3)
	check(w.zone.get("type", "") == "akvaryum", "akvaryum kapısı")
	w._open_panel()
	await _wait(0.5)
	check(w.panel != null and rec.ach.got.has("aquarium"), "akvaryum gezildi")
	w._close_panel()
	w.my_pos = Map.SHUTTLE_FAIR + Vector2(0, 20)
	await _wait(0.3)
	Fair.shuttle(false)
	await _wait(0.5)

	print("== 1.5: İskeledeki tekneler")
	rec.vehicles.erase("boat")
	Garage.send_state(me)
	w.my_pos = Vector2(Map.PIER.end.x - 10, Map.MOORED_BOATS[0].y)
	await _wait(0.4)
	check(w.zone.get("type", "") == "moored", "iskelede bağlı tekne görünüyor ve kiralanabiliyor")
	var m7 := Net.my_money()
	w._open_panel()
	await _wait(0.4)
	check(Net.my_money() <= m7 - Garage.RENT_PRICE + 300 and Garage.has_boat(), "tekne kiralandı")
	w._open_panel()
	await _wait(0.4)
	check(w.my_ride() == "boat", "bağlı tekneye binildi")
	Garage.ride("")
	await _wait(0.2)


func _finish() -> void:
	print("== SONUÇ: %s (%d hata)" % ["BAŞARILI" if errors == 0 else "BAŞARISIZ", errors])
	Net.leave()
	get_tree().quit(0 if errors == 0 else 1)


func _seat_count() -> int:
	var n := 0
	for s in Poker.view.get("seats", []):
		if s != null:
			n += 1
	return n


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _on_fish(d: Dictionary) -> void:
	print("[balık] ", d)
	if d.state == "bite":
		await _wait(0.3)
		Jobs.reel()


func _on_market(d: Dictionary) -> void:
	var total := 0
	for it in d.items:
		total += int(it.qty) * int(it.price)
	print("[market] sepet %d, verilen %d" % [total, d.paid])
	Jobs.answer_market(int(d.paid) - total)


func _on_table() -> void:
	var v := Poker.view
	if v.msg != "" and v.msg != _last_msg:
		hands += 1
		var shown := ""
		for st in v.seats:
			if st != null and not st.shown.is_empty():
				shown += "%s:%s " % [st.name, " ".join(st.shown.map(func(c): return Poker.card_text(c)))]
		print("[poker] ", v.msg, "  | masa: ", " ".join(v.board.map(func(c): return Poker.card_text(c))), "  | ", shown)
	_last_msg = v.msg
	var mi := -1
	for i in v.seats.size():
		if v.seats[i] != null and int(v.seats[i].id) == Net.my_id():
			mi = i
	var key := "%s-%d-%d" % [v.stage, v.board.size(), v.current_bet]
	if mi >= 0 and int(v.turn) == mi and key != _acted_turn:
		_acted_turn = key
		var r := randf()
		var s = v.seats[mi]
		await _wait(0.2)
		print("[poker] sıra bende (%s, masada %d, fiş %d)" % [v.stage, v.current_bet, s.chips])
		if r < 0.15:
			Poker.act("raise", int(v.current_bet) + int(v.min_raise))
		elif int(v.current_bet) > int(s.bet):
			Poker.act("call")
		else:
			Poker.act("check")
