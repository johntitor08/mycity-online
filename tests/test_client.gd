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
	Jobs.sell_fish()
	await _wait(0.5)
	check(Jobs.my_fish.is_empty(), "balıklar satıldı")

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
		_finish()
		return
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
	var c0: float = w.npc.cars[0].x
	await _wait(0.6)
	check(w.npc.walkers.size() >= 20 and w.npc.walkers[0].pos != p0, "%d vatandaş kaldırımda yürüyor" % w.npc.walkers.size())
	check(w.npc.cars[0].x != c0, "NPC arabalar yolda ilerliyor")
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
	check(Net.my_money() == m1 + got * Farm.sell_price("domates", "summer") and not Farm.my_crops.has("domates"), "Hal'de domatesler satıldı (+%d TL)" % (Net.my_money() - m1))

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
