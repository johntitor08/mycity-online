extends Node
## Ekran görüntüsü alır: godot --path . -- --foto  (user://foto_*.png)

func _ready() -> void:
	Net.save_path = "user://foto_kayit.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Net.save_path))
	get_parent()._build_menu()
	await _wait(0.8)
	_shot("menu")
	Net.host("Eren", 7792, false, Net.hash_password("Eren", "foto1234"))
	await _wait(0.5)
	var w = get_parent().world
	if "--sadece11" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 15000)
		await _shots_11(w)
		get_tree().quit()
		return
	if "--sadece10" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 15000)
		await _shots_10(w)
		get_tree().quit()
		return
	if "--sadece09" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 15000)
		await _shots_09(w)
		get_tree().quit()
		return
	if "--sadece08" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 15000)
		await _shots_08(w)
		get_tree().quit()
		return
	if "--olta" in OS.get_cmdline_user_args():
		await _shots_rod(w)
		get_tree().quit()
		return
	if "--sadece07" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 12000)
		await _shots_07(w)
		get_tree().quit()
		return
	if "--sadece06" in OS.get_cmdline_user_args():
		Net.add_money(1, 200000)
		Rpg.add_xp(1, "", 9000)
		await _shots_06(w)
		get_tree().quit()
		return
	Land.buy(0)
	Net.send_chat("Selam! Pokere gelen var mı?")
	w.my_pos = Vector2(1220, 600)
	await _wait(1.5)
	_shot("sehir")
	w.my_pos = Vector2(1630, 300)
	await _wait(1.0)
	_shot("sehir2")
	# Vitrin: farklı seviyelerde arsalar ve farklı yönlere yürüyen sahte oyuncular
	var owners := ["Ayşe", "Mehmet", "Zeynep", "Can"]
	for i in 4:
		Land.plots[i].owner = owners[i]
		Land.plots[i].level = i
	Land._broadcast()
	var Avatar = preload("res://scripts/avatar.gd")
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5}]
	for k in 4:
		Net.players[9001 + k] = {"name": owners[k], "money": 1000 * (k + 1),
			"color": Avatar.shirt_color(apps[k]), "appearance": apps[k]}
	Net._broadcast_roster()
	var dirs := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	var start := Vector2(1240, 700)
	w.my_pos = Vector2(1160, 700)
	w.camera.zoom = Vector2(1.8, 1.8)
	for f in 40:
		for k in 4:
			Net.positions[9001 + k] = start + Vector2(k * 55, 0) + dirs[k] * f * 1.5
		await get_tree().process_frame
		await get_tree().process_frame
	_shot("karakterler")
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Vector2(1500, 1000)
	await _wait(1.2)
	_shot("arsalar")
	# Plaj: biri yüzüyor, biri kumda, biri iskelede
	Net.positions[9001] = Vector2(1250, 1960)
	Net.positions[9002] = Vector2(1330, 1790)
	Net.positions[9003] = Vector2(1600, 2040)
	Net.positions[9004] = Vector2(1180, 2010)
	w.my_pos = Vector2(1400, 1880)
	await _wait(1.5)
	_shot("plaj")
	w.open_character_editor()
	await _wait(1.0)
	_shot("karakter_duzenle")
	w._close_panel()
	# RPG: biraz XP ve eşya, sonra Karakter Kartı ve market alışverişi
	Rpg.add_xp(1, "fishing", 260)
	Rpg.add_xp(1, "medicine", 120)
	Rpg.use_energy(1, 37)
	Rpg.quest_event(1, Rpg._rec(1).quests.list[0].id)
	for b in preload("res://scripts/map.gd").BUILDINGS:
		if b.type == "market":
			w.my_pos = b.rect.get_center()
	await _wait(0.6)
	Rpg.buy("tost")
	Rpg.buy("tost")
	Rpg.buy("rod")
	await _wait(0.5)
	w.open_profile()
	await _wait(1.0)
	_shot("profil")
	w._close_panel()
	w.zone = {"type": "market", "label": "Market"}
	w._open_panel()
	w.panel._show(true)
	await _wait(0.8)
	_shot("magaza")
	w._close_panel()
	for k in 4:
		Net.players.erase(9001 + k)
		Net.positions.erase(9001 + k)
	Net._broadcast_roster()
	Poker.add_bot()
	Poker.add_bot()
	Poker.sit(1000)
	for k in ["casino", "hospital", "market", "fishing", "realestate"]:
		w.zone = {"type": k, "label": k}
		w._open_panel()
		await _wait(0.4)
		match k:
			"casino": Casino.roulette(100, "red")
			"hospital": Jobs.ask_hospital()
			"market": Jobs.ask_market()
			"fishing": Jobs.cast()
		await _wait(3.4)
		_shot(k)
		w._close_panel()
	w.zone = {"type": "poker", "label": "poker"}
	w._open_panel()
	await _wait(3.0)
	_shot("poker")
	w._close_panel()
	await _shots_04(w)
	await _shots_05(w)
	await _shots_06(w)
	await _shots_07(w)
	get_tree().quit()


func _shots_11(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.hour = 13.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	# ahır
	var rp := 6
	w.my_pos = Map.plot_rect(rp).get_center()
	await _wait(0.2)
	Land.buy(rp)
	await _wait(0.2)
	Land.build_up(rp, "ranch")
	await _wait(0.3)
	for k in ["chicken", "chicken", "cow", "sheep", "cow"]:
		Farm.buy_animal(rp, k)
	await _wait(0.4)
	var now := Time.get_unix_time_from_system()
	for a in Land.plots[rp].ranch.animals:
		a.last = now - 1300.0
	Land._broadcast()
	w.my_pos = Map.plot_rect(rp).get_center() + Vector2(0, 40)
	w.camera.zoom = Vector2(1.6, 1.6)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("ahir")
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Map.plot_rect(rp).get_center()
	await _wait(0.3)
	w.zone = {"type": "realestate", "label": "x", "plot": rp}
	w._open_panel()
	await _wait(0.8)
	_shot("ahir_panel")
	w._close_panel()
	# boyalı ev ve araba
	var hp := 7
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.2)
	Land.buy(hp)
	await _wait(0.2)
	Land.build_up(hp)
	Land.build_up(hp)
	await _wait(0.3)
	Land.set_tint(hp, 3)
	await _wait(0.3)
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.3)
	Garage.buy("car")
	Garage.buy("bike")
	Garage.buy("boat")
	await _wait(0.3)
	Garage.set_style("car", 6)
	Garage.set_style("rims", 1)
	await _wait(0.3)
	w.zone = {"type": "galeri", "label": "Galeri"}
	w._open_panel()
	await _wait(0.8)
	_shot("galeri_ozellestir")
	w._close_panel()
	w.my_pos = Map.plot_rect(hp).get_center() + Vector2(0, 95)
	await _wait(0.3)
	Garage.ride("car")
	w.camera.zoom = Vector2(1.5, 1.5)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("boyali_ev_araba")
	w.camera.zoom = Vector2(1, 1)
	Garage.ride("")
	await _wait(0.3)
	# mutfak
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.2)
	for k in ["stove", "table", "chair", "rug", "plant"]:
		Homes.buy(k)
	await _wait(0.5)
	w.my_pos = Map.plot_rect(hp).get_center()
	await _wait(0.3)
	Homes.enter(hp)
	await _wait(0.5)
	for fdef in [["stove", 1, 1], ["table", 6, 4], ["chair", 5, 4], ["rug", 5, 6], ["plant", 0, 8]]:
		Homes.place(hp, fdef[0], fdef[1], fdef[2])
		await _wait(0.1)
	var store := Farm.barn(Net.save_data.players["Eren"])
	for k in ["domates", "yumurta", "sut", "bugday", "misir", "kabak", "lahana", "cilek"]:
		store[k] = 6
	Farm.send_state(1)
	Kitchen.cook("menemen")
	await _wait(0.4)
	w.zone = {"type": "home", "label": "x", "plot": hp}
	w.panel = null
	w._open_panel()
	await _wait(0.8)
	_shot("mutfak")
	w._close_panel()
	Rpg.use("menemen")
	await _wait(0.3)
	Homes.exit_home()
	await _wait(0.4)
	# dalış
	w.my_pos = Vector2(1200, 2250)
	await _wait(0.3)
	Garage.ride("boat")
	await _wait(0.3)
	Dive.dive()
	await _wait(0.4)
	for _k in 10:
		Dive._acc = 99.0
		Dive._process(0.1)
	Dive._wreck_at = 0.0
	Dive._process(0.1)
	await _wait(0.3)
	w.my_pos = Vector2(Map.SEA_BED.position.x + 1100, Map.SEA_BED.end.y - 180)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("deniz_alti")
	w.my_pos = Map.WRECK + Vector2(-120, -60)
	await _wait(1.4)
	await _clear_toasts(w)
	_shot("batik_gemi")
	Dive.surface()
	await _wait(0.4)


func _clear_toasts(w) -> void:
	for c in w.hud.toast_box.get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _shots_10(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.hour = 13.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	# feribot iskelesi ve gemi
	w.my_pos = Map.FERRY_STOPS.sehir[1] + Vector2(60, -120)
	await _wait(1.5)
	_shot("feribot")
	# Sanayi Limanı: vinçler, konteynerler
	w.my_pos = Map.FERRY_STOPS.liman[1]
	await _wait(0.2)
	Work.ride_ferry("liman")
	await _wait(0.5)
	w.my_pos = Vector2(1900, 3700)
	await _wait(1.5)
	_shot("liman")
	# fabrika
	w.my_pos = Map.building("fabrika").rect.get_center() + Vector2(120, 170)
	await _wait(1.2)
	_shot("fabrika_dis")
	w.zone = {"type": "fabrika", "label": "x"}
	w._open_panel()
	await _wait(0.3)
	w.panel._start()
	await _wait(0.9)
	_shot("fabrika")
	w._close_panel()
	# lig
	League.add(1, "fish", 4200.0)
	League.add(1, "goals", 7.0)
	League.add(1, "xp", 3200.0)
	League.best(1, "race", 24.31)
	var sc: Dictionary = League._data().scores
	for n in ["Ayşe", "Mehmet", "Zeynep", "Can"]:
		sc.fish[n] = randf_range(500, 5000)
		sc.goals[n] = float(randi_range(1, 9))
		sc.xp[n] = randf_range(400, 4000)
		sc.race[n] = randf_range(22.0, 40.0)
	League.force_end()
	League.add(1, "fish", 900.0)
	sc = League._data().scores
	sc.fish["Zeynep"] = 1800.0
	sc.fish["Can"] = 650.0
	await _wait(0.4)
	w.open_simple_panel("res://scripts/ui/league_panel.gd")
	await _wait(0.3)
	w.panel._show("fish")
	await _wait(0.6)
	_shot("lig")
	w.panel._show("wall")
	await _wait(0.6)
	_shot("sampiyonlar")
	w._close_panel()


func _shots_09(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.hour = 12.0
	Env.force_weather("clear")
	Env.force_season("spring")
	w.camera.zoom = Vector2(1, 1)
	# eğitim turu ve nehir/köprü
	Tutorial.finish()
	Tutorial.start(w.ui_layer, true)
	w.my_pos = Vector2(523, 520)
	await _wait(1.5)
	_shot("nehir")
	Tutorial.finish()
	# park, çeşme, saat kulesi
	w.my_pos = Map.FOUNTAIN + Vector2(120, 70)
	Env.hour = 17.5
	await _wait(1.5)
	_shot("park")
	Env.hour = 12.0
	# otobüs: güzergâhta gelirken (saati otobüs durağa yakın olacak şekilde seçemeyiz; otobüsün olduğu yere git)
	var bus := Map.bus_at(Land.server_now() + 2.0)
	w.my_pos = bus[0] + Vector2(0, 70)
	await _wait(1.5)
	_shot("otobus")
	# taksi
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.2)
	Garage.buy("car")
	await _wait(0.2)
	w.my_pos = Map.TAXI_STAND + Vector2(0, 20)
	await _wait(0.3)
	Garage.ride("car")
	await _wait(0.3)
	Work.taxi_start()
	await _wait(0.4)
	var pk: Vector2 = Work.job.target
	w.my_pos = pk + Vector2(170, 30)
	w.my_facing = "left"
	await _wait(1.2)
	_shot("taksi")
	Work.quit_job()
	Garage.ride("")
	await _wait(0.3)
	# itfaiye ve yangın
	w.my_pos = Map.FIRE_STATION.get_center() + Vector2(0, 90)
	await _wait(0.3)
	Work.fire_duty(true)
	await _wait(0.3)
	Work._start_fire()
	await _wait(0.4)
	var f: Dictionary = Work.fires[0]
	w.my_pos = Vector2(float(f.x), float(f.y)) + Vector2(-70, 50)
	w.my_facing = "right"
	await _wait(1.5)
	_shot("yangin")
	for _k in 30:
		Work.spray(int(f.id))
	Work.fire_duty(false)
	await _wait(0.3)
	# çöpçülük ve kargo deposu
	for _k in 8:
		Work._spawn_trash()
	await _wait(0.3)
	w.my_pos = Map.RECYCLE + Vector2(60, -40)
	await _wait(1.2)
	_shot("geri_donusum")
	# parti
	var plot := 4
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.2)
	Land.buy(plot)
	await _wait(0.2)
	Land.build_up(plot)
	Land.build_up(plot)
	await _wait(0.3)
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.2)
	for k in ["bed", "rug", "sofa", "tv", "table", "chair", "plant", "lamp", "aquarium"]:
		Homes.buy(k)
	await _wait(0.5)
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Homes.enter(plot)
	await _wait(0.5)
	for fdef in [["bed", 1, 1], ["rug", 5, 4], ["sofa", 5, 2], ["tv", 6, 7], ["table", 11, 4], ["chair", 10, 4], ["plant", 0, 8], ["lamp", 4, 1], ["aquarium", 11, 0]]:
		Homes.place(plot, fdef[0], fdef[1], fdef[2])
		await _wait(0.1)
	Land.plots[plot]["guestbook"] = [{"n": "Ayşe", "t": "Akvaryum harika, parti süperdi!", "d": "2026-10-25"}, {"n": "Mehmet", "t": "Kanepe çok rahat :)", "d": "2026-10-25"}]
	Land.plots[plot]["rating"] = {"sum": 14, "n": 3, "by": {}}
	Land._broadcast()
	Party.start_party(plot)
	await _wait(0.5)
	w.my_pos = Map.interior_rect(plot, 2).get_center() + Vector2(-40, 60)
	await _wait(1.2)
	_shot("parti")
	w.zone = {"type": "home", "label": "x", "plot": plot}
	w.panel = null
	w._open_panel()
	await _wait(0.6)
	_shot("parti_panel")
	w._close_panel()
	Homes.exit_home()
	await _wait(0.4)
	# ayarlar
	w.open_settings()
	await _wait(0.6)
	_shot("ayarlar")
	w._close_panel()


func _shots_08(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 12.0
	Env.force_weather("clear")
	Env.force_season("summer")
	w.camera.zoom = Vector2(1, 1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 0, "pants": 1, "hat": 3, "glasses": 1, "neck": 0},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 7, "pants": 0, "hat": 0, "glasses": 0, "neck": 2},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 0, "pants": 4, "hat": 4, "glasses": 0, "neck": 0},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 7, "pants": 5, "hat": 0, "glasses": 1, "neck": 0}]
	var names := ["Ayşe", "Mehmet", "Zeynep", "Can"]
	var teams := ["red", "blue", "red", "blue"]
	var titles := ["Deniz Kurdu", "", "Golcü", "Şampiyon"]
	for k in 4:
		Net.players[9501 + k] = {"name": names[k], "money": 3000 * (k + 1), "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 6 + k, "team": teams[k], "title": titles[k]}
	Net._broadcast_roster()
	# başarımlar ve unvan
	Ach.event(1, "fish", 120)
	Ach.event(1, "goal", 3)
	Ach.set_max(1, "money", 300000)
	Ach.event(1, "shark")
	await _wait(0.6)
	Ach.set_title("shark")
	await _wait(0.4)
	w.open_simple_panel("res://scripts/ui/ach_panel.gd")
	await _wait(0.8)
	_shot("basarim")
	w._close_panel()
	# plaj futbolu
	var f: Rect2 = Football.FIELD
	Football.join("blue")
	Football.score = {"red": 2, "blue": 3}
	Football._broadcast_match()
	for k in 4:
		Net.positions[9501 + k] = f.get_center() + Vector2(-150 + k * 90, -40 + (k % 2) * 70)
	w.my_pos = f.get_center() + Vector2(60, 10)
	Football.ball = f.get_center() + Vector2(110, 20)
	Football.vel = Vector2(120, -40)
	w.camera.zoom = Vector2(1.3, 1.3)
	await _wait(1.5)
	_shot("futbol")
	w.camera.zoom = Vector2(1, 1)
	# langırt
	w.my_pos = Langirt.POS + Vector2(0, 50)
	await _wait(0.3)
	Langirt.sit(0, true)
	await _wait(3.5)
	w.zone = {"type": "langirt", "label": "x"}
	w._open_panel()
	await _wait(1.2)
	_shot("langirt")
	w._close_panel()
	Langirt.leave()
	# dondurmacı ve kiralık tekne
	w.my_pos = Seasonal.ICECREAM_POS + Vector2(60, 50)
	await _wait(0.3)
	Garage.rent_boat()
	w.my_pos = Map.BOAT_RENT_SPOT
	await _wait(0.3)
	Garage.rent_boat()
	await _wait(0.3)
	w.my_pos = Map.PIER_END.get_center()
	await _wait(0.3)
	w._toggle_vehicle()
	await _wait(0.4)
	# Martı Adası, gece, deniz feneri
	Env.hour = 21.5
	w.my_pos = Map.ISLAND_PIER.get_center() + Vector2(-140, -60)
	w.my_facing = "right"
	Net.positions[9501] = Map.ISLAND.get_center() + Vector2(-60, 20)
	Net.positions[9502] = Map.ISLAND_SPOT.get_center()
	Net.players[9502]["fishing"] = "cast"
	Net._broadcast_roster()
	await _wait(2.0)
	_shot("ada")
	Env.hour = 12.0
	Net.players[9502]["fishing"] = ""
	Garage.ride("")
	await _wait(0.3)
	# harita: navigasyon + büyük harita
	w.my_pos = Map.SPAWN
	await _wait(0.3)
	w.set_nav(Map.building("carsi").rect.get_center() + Vector2(0, 130))
	await _wait(1.0)
	_shot("navigasyon")
	w.open_map()
	await _wait(0.8)
	_shot("harita")
	w._close_panel()
	w.nav_target = null
	# kış: kardan adamlar, kartopu, sis
	Env.force_season("winter")
	await _wait(0.3)
	var c := Vector2(260, 545)
	for k in 3:
		w.my_pos = c + Vector2(k * 90, (k % 2) * 30)
		await _wait(0.2)
		Seasonal.build_snowman(w.my_pos)
		await _wait(0.2)
	Rpg.add_xp(1, "", 1)
	w.my_pos = c + Vector2(80, 110)
	Net.positions[9503] = c + Vector2(330, 110)
	Net.positions[9504] = c + Vector2(260, 60)
	await _wait(0.4)
	for k in 3:
		Seasonal.throw(Vector2(1, randf_range(-0.1, 0.1)))
		await _wait(0.75)
	Seasonal._last_throw.clear()
	Seasonal.throw(Vector2(1, 0))
	await _wait(0.25)
	_shot("kis_kartopu")
	Env.force_weather("fog")
	await _wait(1.0)
	_shot("sis")
	Env.force_season("spring")
	Env.force_weather("rainbow")
	w.my_pos = Map.SPAWN + Vector2(300, 600)
	await _wait(1.2)
	_shot("gokkusagi")
	Env.force_weather("clear")
	for k in 4:
		Net.players.erase(9501 + k)
		Net.positions.erase(9501 + k)
	Net._broadcast_roster()


## Olta animasyonu: göl iskelesinde ben (atıldı), komşular (vurdu / yakaladı), deniz iskelesi.
func _shots_rod(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 17.0
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1, "hat": 0, "glasses": 0, "neck": 0},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0, "hat": 5, "glasses": 0, "neck": 2}]
	Net.players[9401] = {"name": "Ayşe", "money": 100, "color": Avatar.shirt_color(apps[0]), "appearance": apps[0], "level": 4, "fishing": "bite"}
	Net.players[9402] = {"name": "Hasan", "money": 100, "color": Avatar.shirt_color(apps[1]), "appearance": apps[1], "level": 6, "fishing": "cast"}
	Net._broadcast_roster()
	var d: Rect2 = Map.DOCK
	Net.positions[9401] = Vector2(d.position.x + 30, d.position.y + 20)
	Net.positions[9402] = Vector2(d.position.x + 30, d.end.y - 8)
	w.my_pos = Vector2(d.position.x + 110, d.get_center().y)
	w.my_facing = "left"
	w.camera.zoom = Vector2(1.8, 1.8)
	await _wait(0.5)
	Jobs.cast()
	await _wait(1.2)
	_shot("olta_gol")
	# yakalama anı
	Net.players[9401]["fishing"] = "caught"
	Net._broadcast_roster()
	await _wait(0.35)
	_shot("olta_yakaladi")
	# deniz iskelesi
	Jobs._fish.clear()
	w.my_pos = Map.PIER_END.get_center() + Vector2(0, 40)
	w.my_facing = "down"
	Net.positions[9402] = Map.PIER_END.get_center() + Vector2(-30, 0)
	Net.players[9402]["fishing"] = "bite"
	Net._broadcast_roster()
	await _wait(0.3)
	Jobs.cast()
	await _wait(1.0)
	_shot("olta_deniz")
	w.camera.zoom = Vector2(1, 1)
	w.zone = {"type": "fishing", "label": "x"}
	w._open_panel()
	await _wait(0.6)
	_shot("olta_panel")
	w._close_panel()


func _shots_07(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 13.0
	Env.force_weather("clear")
	Env.force_season("summer")
	w.camera.zoom = Vector2(1, 1)
	# çarşı: aksesuar al, dene
	w.my_pos = Map.building("carsi").rect.get_center()
	await _wait(0.3)
	for k in ["hat2", "gl1", "nk3", "hc9", "ring", "ring"]:
		Shops.buy(k)
	await _wait(0.4)
	w.zone = {"type": "carsi", "label": "x"}
	w._open_panel()
	await _wait(0.3)
	w.panel._try_on("hat", 5)
	await _wait(0.8)
	_shot("carsi")
	w._close_panel()
	var app: Dictionary = Net.roster[1].appearance.duplicate()
	app.hat = 2
	app.glasses = 1
	app.neck = 3
	app.hair_color = 9
	Net.set_appearance(app)
	# aksesuarlı sahte oyuncular (yakın plan)
	var apps := [
		{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1, "hat": 3, "glasses": 3, "neck": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0, "hat": 5, "glasses": 0, "neck": 2},
		{"skin": 0, "hair": 2, "hair_color": 11, "shirt": 2, "pants": 4, "hat": 6, "glasses": 2, "neck": 1},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5, "hat": 4, "glasses": 1, "neck": 0}]
	var names := ["Ayşe", "Mehmet", "Zeynep", "Can"]
	for k in 4:
		Net.players[9301 + k] = {"name": names[k], "money": 3000 * (k + 1), "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 6 + k}
	Net.players[9303]["mayor"] = true
	Net._broadcast_roster()
	var c: Vector2 = Map.building("carsi").rect.get_center() + Vector2(-60, 150)
	var dirs := [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, 1)]
	w.my_pos = c + Vector2(-60, 0)
	w.my_facing = "down"
	w.camera.zoom = Vector2(2, 2)
	for f in 30:
		for k in 4:
			Net.positions[9301 + k] = c + Vector2(k * 50, (k % 2) * 20) + dirs[k] * f * 0.8
		await get_tree().process_frame
		await get_tree().process_frame
	await _wait(0.4)
	_shot("aksesuar")
	w.camera.zoom = Vector2(1, 1)
	# banka ve borsa
	w.my_pos = Map.building("banka").rect.get_center()
	await _wait(0.3)
	Bank.deposit(25000)
	Bank.borrow(8000)
	for _k in 40:
		Bank.activity(["BALK", "TARM", "KMRH", "EMLK", "OTO", "MRKT"].pick_random(), randi_range(0, 12))
		Bank.tick_market()
	Bank.trade("BALK", 200)
	Bank.trade("EMLK", 25)
	for _k in 6:
		Bank.tick_market()
	await _wait(0.5)
	w.zone = {"type": "banka", "label": "x"}
	w._open_panel()
	await _wait(0.6)
	_shot("banka")
	w.panel._show("stock")
	await _wait(0.6)
	_shot("borsa")
	w._close_panel()
	# seçim: aday ol, oyla, kazan
	var now := Time.get_unix_time_from_system()
	var base: float = floor(now / Election.CYCLE) * Election.CYCLE + Election.CYCLE
	Election.debug_offset = base + 600.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	w.my_pos = Map.building("muhtarlik").rect.get_center()
	await _wait(0.3)
	Election.apply("Her eve bir tekne!")
	Election._data().candidates["Zeynep"] = {"slogan": "Daha çok park, daha az vergi", "votes": 0}
	Election._data().candidates["Mehmet"] = {"slogan": "Balıkçılara destek!", "votes": 0}
	Election.debug_offset = base + Election.APPLY_END + 400.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	await _wait(0.3)
	w.zone = {"type": "muhtarlik", "label": "x"}
	w._open_panel()
	await _wait(0.3)
	w.panel._show("town")
	await _wait(0.6)
	_shot("secim")
	w._close_panel()
	Election.vote(Net.my_name)
	Election._data().candidates["Zeynep"].votes = 0
	Election.debug_offset = base + Election.VOTE_END + 120.0 - now
	Election._acc = 99.0
	Election._process(0.1)
	Net.players[9303]["mayor"] = false
	await _wait(0.3)
	Election.set_tax(8)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	w.panel._show("town")
	await _wait(0.6)
	_shot("baskan")
	w._close_panel()
	Election.debug_offset = 0.0
	# düğün
	Net.save_data.players["Ayşe"] = {"money": 3000, "fish": [], "rpg": {"xp": 4000}}
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	rec["spouse"] = "Ayşe"
	Net.save_data.players["Ayşe"]["spouse"] = Net.my_name
	Family._store()[Family.key_of(Net.my_name, "Ayşe")] = {"a": Net.my_name, "b": "Ayşe", "bank": 4200, "since": Time.get_date_string_from_system()}
	Family.send_state(1)
	var wp: Vector2 = Map.SPAWN + Vector2(300, 30)
	Net.positions[9301] = wp + Vector2(30, 0)
	w.my_pos = wp + Vector2(-30, 0)
	w.my_facing = "right"
	Net.tell_all(Family, "on_wedding", {"pos": wp, "a": Net.my_name, "b": "Ayşe"})
	w.camera.zoom = Vector2(1.4, 1.4)
	await _wait(2.0)
	_shot("dugun")
	w.camera.zoom = Vector2(1, 1)
	w.open_simple_panel("res://scripts/ui/family_panel.gd")
	await _wait(0.6)
	_shot("aile")
	w._close_panel()
	# yeni binalar
	w.my_pos = Map.building("banka").rect.get_center() + Vector2(-200, 120)
	await _wait(1.5)
	_shot("dogu07")
	for k in 4:
		Net.players.erase(9301 + k)
		Net.positions.erase(9301 + k)
	Net._broadcast_roster()


func _shots_06(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0      # saat gerçek saate dönmesin
	var Avatar = preload("res://scripts/avatar.gd")
	Env.hour = 11.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Garage.ride("")
	w.camera.zoom = Vector2(1, 1)
	# tarla: karışık ekinler
	var plot := 9
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot, "farm")
	await _wait(0.3)
	var crops := ["domates", "misir", "karpuz", "bugday", "cilek", "kabak"]
	var progress := [1.2, 0.7, 0.4, 1.2, 0.15, 1.2]
	var now := Time.get_unix_time_from_system()
	for k in 6:
		var g := Farm.grow_time(crops[k], "summer")
		Land.plots[plot].farm.beds[k] = {"c": crops[k], "t": now - g * progress[k], "g": g, "w": k % 2 == 0, "f": k == 0, "dmg": false}
	Land._broadcast()
	# komşu tarla
	Land.plots[10].owner = "Zeynep"
	Land.plots[10].level = 1
	Land.plots[10]["kind"] = "farm"
	Land.plots[10]["farm"] = Farm.default_data()
	for k in 6:
		Land.plots[10].farm.beds[k] = {"c": "bugday" if k < 3 else "lahana", "t": now - 200.0, "g": 240.0, "w": true, "f": false, "dmg": false}
	Land._broadcast()
	w.my_pos = Map.plot_rect(plot).get_center() + Vector2(130, 110)
	w.camera.zoom = Vector2(1.5, 1.5)
	await _wait(1.5)
	_shot("tarla")
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	w.zone = {"type": "realestate", "label": "x", "plot": plot}
	w._open_panel()
	await _wait(0.8)
	_shot("tarla_panel")
	w._close_panel()
	# mevsimler
	Env.force_season("autumn")
	w.my_pos = Vector2(1500, 300)
	await _wait(1.2)
	_shot("sonbahar")
	Env.force_season("winter")
	Env.force_weather("rain")
	await _wait(1.5)
	_shot("kis")
	Env.force_weather("clear")
	Env.force_season("summer")
	# klanlar ve sohbet
	Clans.create("Boğaz Kartalları", "BGZ")
	await _wait(0.3)
	Clans.deposit(2500)
	Clans._store()["KRT"] = {"name": "Karadeniz Fırtınası", "tag": "KRT", "leader": "Mehmet", "members": ["Mehmet", "Can", "Selin"], "bank": 900, "points": 1900, "open": true, "requests": [], "color": 5}
	Clans._store()["AYZ"] = {"name": "Ayazağa Esnafı", "tag": "AYZ", "leader": "Ayşe", "members": ["Ayşe"], "bank": 0, "points": 320, "open": false, "requests": [], "color": 6}
	Clans._store()["BGZ"]["members"].append("Zeynep")
	Clans._store()["BGZ"]["requests"].append("Kerem")
	Clans.add_points("BGZ", 640)
	Clans._process(5.0)
	await _wait(0.4)
	Net.send_chat("Akşam balık turnuvasına herkes gelsin!", "clan")
	await _wait(0.5)
	Net.send_chat("Burada kimse var mı?", "local")
	await _wait(0.5)
	w.open_simple_panel("res://scripts/ui/clan_panel.gd")
	await _wait(0.8)
	_shot("klan")
	w._close_panel()
	# sahte oyuncular: biri aranıyor, biri klanlı
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}, {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}]
	Net.save_data.players["Kerem"] = {"money": 4200, "fish": [], "crime": {"wanted": 3, "t": Time.get_unix_time_from_system() + 9000.0, "jail_until": 0.0, "crimes": 3, "arrests": 0}}
	Net.players[9201] = {"name": "Kerem", "money": 4200, "color": Avatar.shirt_color(apps[0]), "appearance": apps[0], "level": 7, "wanted": 3, "clan": "", "police": false}
	Net.players[9202] = {"name": "Zeynep", "money": 8800, "color": Avatar.shirt_color(apps[1]), "appearance": apps[1], "level": 9, "wanted": 0, "clan": "BGZ", "clan_color": "#4ade80", "police": false}
	Net._broadcast_roster()
	# yarış
	Garage.buy("car")
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.3)
	Garage.buy("car")
	await _wait(0.3)
	w.my_pos = Map.RACE_START
	await _wait(0.3)
	Garage.ride("car")
	Events.race_start()
	await _wait(3.4)
	w.my_pos = Map.RACE_CPS[0]
	await _wait(0.3)
	w.my_pos = Vector2(1005, 1330)
	w.my_facing = "down"
	Net.positions[9202] = Vector2(1020, 1220)
	await _wait(1.5)
	_shot("yaris")
	Events.race_quit()
	Garage.ride("")
	await _wait(0.3)
	# hazine avı
	Events.start_event("treasure")
	Events._active.pos = Vector2(2200, 1580)
	Events._active.area = Vector2(2120, 1500)
	Events._active.near = {}
	Events._broadcast()
	w.my_pos = Vector2(2000, 1560)
	await _wait(1.5)
	_shot("hazine")
	Events._finish()
	# festival gecesi
	Events.start_event("festival")
	Env.hour = 22.0
	w.my_pos = Map.SPAWN + Vector2(0, 40)
	Net.positions[9201] = Map.SPAWN + Vector2(120, 10)
	Net.positions[9202] = Map.SPAWN + Vector2(-110, 30)
	await _wait(3.0)
	_shot("festival")
	Events._finish()
	Env.hour = 12.0
	# karakol: görevde polis, aranan oyuncu, devriye arabası
	w.my_pos = Map.building("karakol").rect.get_center()
	await _wait(0.3)
	Police.set_duty(true)
	Police.buy_security("lock", plot)
	await _wait(0.3)
	Net.positions[9201] = Map.building("karakol").rect.get_center() + Vector2(130, 190)
	w.my_pos = Map.building("karakol").rect.get_center() + Vector2(-20, 190)
	w.my_facing = "right"
	w.npc.cars[0].lane = 2
	w.npc.cars[0].x = 2300.0
	await _wait(1.5)
	_shot("karakol")
	w.zone = {"type": "karakol", "label": "x"}
	w._open_panel()
	await _wait(0.3)
	w.panel._next_case()
	await _wait(0.8)
	_shot("karakol_panel")
	w._close_panel()
	Police.set_duty(false)
	await _wait(0.3)
	# hapishane
	Police.crime(Net.save_data.players[Net.my_name])["wanted"] = 2
	Police.jail(1, 2, 0)
	await _wait(1.5)
	_shot("hapis")
	Police.bail()
	await _wait(0.5)
	# etkinlik penceresi
	Events.start_event("fish")
	Events.on_fish(1, "Orkinos", 720)
	Events._active.scores["Zeynep"] = [1500.0, "Kılıç Balığı 1.500 TL"]
	Events._active.scores["Kerem"] = [310.0, "Kalkan 310 TL"]
	Events._broadcast()
	await _wait(0.3)
	w.open_simple_panel("res://scripts/ui/event_panel.gd")
	await _wait(0.8)
	_shot("etkinlik")
	w._close_panel()
	w.open_profile()
	await _wait(0.8)
	_shot("profil06")
	w._close_panel()


func _shots_05(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env.hour = 12.0
	Env.force_weather("clear")
	for id in [9101, 9102, 9103]:
		Net.players.erase(id)
		Net.positions.erase(id)
	Net._broadcast_roster()
	Garage.ride("")
	# evcil hayvan
	w.my_pos = Map.building("petshop").rect.get_center()
	await _wait(0.4)
	Pets.buy("dog", "Karabaş")
	await _wait(0.4)
	w.zone = {"type": "petshop", "label": "x"}
	w._open_panel()
	await _wait(0.8)
	_shot("evcil_panel")
	w._close_panel()
	# işletme: arsaya büfe → kafe, malzeme, müşteriler
	var plot := 6
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot, "biz")
	await _wait(0.3)
	Land.build_up(plot, "biz")
	await _wait(0.3)
	Biz.restock(plot, "wholesale", 10)
	await _wait(0.3)
	for _k in 3:
		Biz._tick()
	await _wait(0.3)
	w.my_pos = Map.plot_rect(plot).get_center() + Vector2(0, 70)
	await _wait(3.5)
	_shot("isletme")
	w.zone = {"type": "realestate", "label": "x", "plot": plot}
	w._open_panel()
	await _wait(0.8)
	_shot("isletme_panel")
	w._close_panel()
	# doğu mahallesi, muhtar ve NPC'ler
	Net.save_data.players[Net.my_name]["story"] = {"step": 0, "count": 0, "accepted": false}
	Story.send_state(1)
	w.my_pos = Map.NPCS.muhtar.pos + Vector2(-90, 30)
	w.my_facing = "right"
	await _wait(2.0)
	_shot("muhtar")
	Story.talk("muhtar")
	await _wait(0.8)
	_shot("diyalog")
	w._close_panel()
	w.my_pos = Vector2(1300, 450)
	await _wait(1.5)
	_shot("sehir_npc")


func _shots_04(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Net.add_money(1, 80000)
	Rpg.add_xp(1, "", 2600)
	w.my_pos = Map.building("galeri").rect.get_center()
	await _wait(0.4)
	for k in ["bike", "car", "boat"]:
		Garage.buy(k)
	# sahte oyuncular araçlarda
	var fakes := {9101: ["Selin", "car", Vector2(1300, 450), {"skin": 1, "hair": 1, "hair_color": 3, "shirt": 0, "pants": 1}],
		9102: ["Kerem", "bike", Vector2(1480, 470), {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 7, "pants": 0}],
		9103: ["Derya", "car", Vector2(1004, 640), {"skin": 0, "hair": 2, "hair_color": 4, "shirt": 9, "pants": 2}]}
	for id in fakes:
		var f: Array = fakes[id]
		Net.players[id] = {"name": f[0], "money": 5000, "color": Avatar.shirt_color(f[3]), "appearance": f[3], "level": 7, "ride": f[1]}
		Net.positions[id] = f[2]
	Net._broadcast_roster()
	await _wait(0.5)
	Garage.ride("car")
	w.my_pos = Vector2(1200, 470)
	w.my_facing = "right"
	await _wait(1.2)
	_shot("araclar")
	# gece
	Env.hour = 22.0
	await _wait(1.0)
	_shot("gece")
	# fırtına
	Env.hour = 15.0
	Env.force_weather("storm")
	Garage.ride("")
	w.my_pos = Vector2(1400, 1800)
	await _wait(1.5)
	_shot("firtina")
	Env.force_weather("clear")
	# ev içi: ev kur, mobilya al ve yerleştir
	var plot := 5
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Land.buy(plot)
	await _wait(0.3)
	Land.build_up(plot)
	Land.build_up(plot)
	await _wait(0.4)
	w.my_pos = Map.building("mobilya").rect.get_center()
	await _wait(0.3)
	for k in ["bed", "rug", "sofa", "tv", "table", "chair", "chair", "plant", "plant", "lamp", "bookshelf", "aquarium", "fridge", "desk", "armchair"]:
		Homes.buy(k)
	await _wait(0.6)
	w.my_pos = Map.plot_rect(plot).get_center()
	await _wait(0.3)
	Homes.enter(plot)
	await _wait(0.6)
	for f in [["bed", 1, 1], ["rug", 5, 4], ["sofa", 5, 2], ["tv", 6, 7], ["table", 11, 4], ["chair", 10, 4], ["chair", 13, 5],
			["plant", 0, 8], ["plant", 15, 0], ["lamp", 4, 1], ["bookshelf", 8, 0], ["aquarium", 11, 0], ["fridge", 14, 8], ["desk", 1, 6], ["armchair", 9, 5]]:
		Homes.place(plot, f[0], f[1], f[2])
		await _wait(0.12)
	Homes.set_door(plot, true)
	await _wait(0.4)
	Net.positions[9102] = Map.interior_rect(plot, 2).get_center() + Vector2(120, 60)
	Net.players[9102]["ride"] = ""
	Net._broadcast_roster()
	w.my_pos = Map.interior_rect(plot, 2).get_center() + Vector2(-60, 40)
	await _wait(1.2)
	_shot("ev")
	Env.hour = 23.0
	await _wait(0.8)
	_shot("ev_gece")
	Env.hour = 13.0
	w.panel = null
	Homes.exit_home()
	await _wait(0.5)
	# pazar
	w.my_pos = Map.building("pazar").rect.get_center()
	await _wait(0.3)
	Bazaar.list_item("furniture", "chair", 450)
	Bazaar._store().append({"id": 900, "seller": "Selin", "kind": "fish", "item": {"name": "Orkinos", "price": 720}, "label": "Orkinos (değeri 720 TL)", "price": 650})
	Bazaar._store().append({"id": 901, "seller": "Kerem", "kind": "plot", "item": 11, "label": "Arsa #12 (Boş arsa)", "price": 18000})
	Bazaar._broadcast()
	await _wait(0.4)
	w.zone = {"type": "pazar", "label": "Pazar"}
	w._open_panel()
	await _wait(0.8)
	_shot("pazar")
	w._close_panel()
	w.zone = {"type": "galeri", "label": "Galeri"}
	w._open_panel()
	await _wait(0.6)
	_shot("galeri")
	w._close_panel()


func _shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://foto_%s.png" % n))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
