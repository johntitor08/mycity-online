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
	if "--genel" in OS.get_cmdline_user_args():
		Tutorial.finish()
		await _wait(2.0)
		w.hud.visible = false
		Env.hour = 12.0
		Env.force_weather("clear")
		var parts := [[Vector2(1400, 900), "genel_kuzey"], [Vector2(1400, 2400), "genel_orta"], [Vector2(1400, 3800), "genel_guney"]]
		if "--bolgeler" in OS.get_cmdline_user_args():
			parts = [[Vector2(11900, 760), "genel_fuar1"], [Vector2(11900, 2150), "genel_fuar2"], [Vector2(9100, 760), "genel_dag1"], [Vector2(9100, 2150), "genel_dag2"]]
		for part in parts:
			w.camera.limit_left = -99999
			w.camera.limit_right = 99999
			w.camera.limit_top = -99999
			w.camera.zoom = Vector2(0.45, 0.45)
			w.camera.limit_bottom = 99999
			w.my_pos = part[0]
			await _wait(1.0)
			w.camera.reset_smoothing()
			await _wait(0.3)
			_shot(part[1])
		get_tree().quit()
		return
	if "--kapak" in OS.get_cmdline_user_args():
		await _shots_cover(w)
		get_tree().quit()
		return
	if "--dokunmatik" in OS.get_cmdline_user_args():
		var Map = preload("res://scripts/map.gd")
		Tutorial.finish()
		Env.hour = 12.0
		Env.force_weather("clear")
		Settings.touch_mode = "on"
		Settings.hud_collapsed = {}           # telefonda ilk açılış gibi
		w.refresh_touch()
		await _wait(0.5)
		var t: Control = w.touch
		var sz: Vector2 = t.size
		print("[dokunmatik] görünür=", t.visible, " boyut=", sz)
		# joystick: sağa sürükle → oyuncu sağa yürümeli
		var start: Vector2 = w.my_pos
		var jb: Vector2 = t._joy_base()
		_touch(0, jb, true)
		for k in 6:
			_drag(0, jb + Vector2(15 * (k + 1), 0))
			await _wait(0.05)
		await _wait(0.8)
		_touch(0, jb + Vector2(90, 0), false)
		await _wait(0.2)
		print("[dokunmatik] yürüdü: ", start, " -> ", w.my_pos, " (dx=", w.my_pos.x - start.x, ")")
		# E düğmesi: bir binanın önünde panel açmalı
		var b: Dictionary = Map.building("market")
		w.my_pos = Vector2(b.rect.get_center().x, b.rect.end.y + 12)
		await _wait(0.4)
		var e_pos: Vector2 = t._btn_pos(t.BUTTONS[0])
		_touch(1, e_pos, true)
		await _wait(0.1)
		_touch(1, e_pos, false)
		await _wait(0.5)
		print("[dokunmatik] E ile panel: ", w.panel != null)
		if w.panel != null:
			w._close_panel()
		await _wait(0.3)
		_touch(2, jb, true)
		_drag(2, jb + Vector2(-40, -60))
		await _wait(0.3)
		await _clear_toasts(w)
		_shot("dokunmatik")
		_touch(2, jb, false)
		get_tree().quit()
		return
	if "--avatar" in OS.get_cmdline_user_args():
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		var c := AvatarSheet.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(c)
		await _wait(0.8)
		_shot("avatar_tablo")
		get_tree().quit()
		return
	if "--gorsel" in OS.get_cmdline_user_args():
		Tutorial.finish()
		Env._sync = -1000000.0
		Env.force_weather("clear")
		Env.force_season("summer")
		Holidays.force("yok")
		var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
			["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
			["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
		_fake_players(apps)
		for part in [[Vector2(1200, 470), 12.0, "gorsel_gunduz", 1.0], [Vector2(1200, 470), 21.5, "gorsel_gece", 1.0],
				[Vector2(1640, 470), 13.0, "gorsel_yakin", 2.2], [Vector2(560, 1500), 13.0, "gorsel_park", 1.0]]:
			Env.hour = float(part[1])
			w.my_pos = part[0]
			Net.positions[9981] = part[0] + Vector2(60, 20)
			Net.positions[9982] = part[0] + Vector2(-50, 30)
			Net.positions[9983] = part[0] + Vector2(110, -10)
			w.camera.zoom = Vector2.ONE * float(part[3])
			await _wait(1.2)
			await _clear_toasts(w)
			_shot(part[2])
		get_tree().quit()
		return
	if "--tekne" in OS.get_cmdline_user_args():
		var Map = preload("res://scripts/map.gd")
		Tutorial.finish()
		Env.hour = 12.0
		Env.force_weather("clear")
		var rec: Dictionary = Net.save_data.players[Net.my_name]
		if not "boat" in rec.vehicles:
			rec.vehicles.append("boat")
		Garage.send_state(1)
		w.my_pos = Vector2(Map.PIER.end.x + 160, Map.MOORED_BOATS[0].y + 120)
		await _wait(0.4)
		Garage.set_ride(1, "boat")
		for k in 20:
			w.my_pos += Vector2(5, 0)
			await _wait(0.03)
		w.camera.zoom = Vector2(1.4, 1.4)
		await _wait(1.0)
		await _clear_toasts(w)
		_shot("tekne_yeni")
		get_tree().quit()
		return
	if "--hud" in OS.get_cmdline_user_args():
		var Map = preload("res://scripts/map.gd")
		Tutorial.finish()
		Env.hour = 12.0
		Env.force_weather("clear")
		Pets.give(1, "dog", "Karabaş")
		var rec: Dictionary = Net.save_data.players[Net.my_name]
		if not "boat" in rec.vehicles:
			rec.vehicles.append("boat")
		Garage.send_state(1)
		w.my_pos = Map.ISLAND.get_center() + Vector2(0, -260)
		await _wait(0.5)
		Garage.set_ride(1, "boat")
		await _wait(0.4)
		for k in 30:
			w.my_pos += Vector2(6, 0)
			await _wait(0.03)
		await _wait(0.8)
		await _clear_toasts(w)
		_shot("hud_acik")
		for k in ["bilgi", "zenginler", "sohbet", "tuslar", "harita"]:
			w.hud.set_collapsed(k, true)
		await _wait(0.6)
		_shot("hud_kucuk")
		for k in ["bilgi", "zenginler", "sohbet", "tuslar", "harita"]:
			w.hud.set_collapsed(k, false)
		await _wait(0.3)
		get_tree().quit()
		return
	if "--tanitim" in OS.get_cmdline_user_args():
		var Map = preload("res://scripts/map.gd")
		Tutorial.finish()
		await _wait(2.0)
		Env.hour = 12.0
		Env.force_weather("clear")
		Env.force_season("summer")
		_fake_players([["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
			["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
			["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]])
		for spot in [["tanitim_sehir", Vector2(1500, 700)], ["tanitim_sahil", Vector2(1300, 1700)]]:
			Homes._teleport(1, spot[1])
			Net.positions[9981] = spot[1] + Vector2(80, 30)
			Net.positions[9982] = spot[1] + Vector2(-120, 60)
			Net.positions[9983] = spot[1] + Vector2(200, -40)
			w.camera.zoom = Vector2(0.8, 0.8)
			await _wait(1.4)
			w.hud.visible = false
			w.touch.visible = false
			await _wait(0.4)
			_shot(spot[0])
			w.hud.visible = true
		get_tree().quit()
		return
	if "--rehber" in OS.get_cmdline_user_args():
		Tutorial.finish()
		await _wait(1.5)
		w.open_simple_panel("res://scripts/ui/guide_panel.gd")
		await _wait(0.6)
		_shot("rehber")
		w.panel._select(3)
		await _wait(0.4)
		_shot("rehber_ulasim")
		get_tree().quit()
		return
	if "--otogar" in OS.get_cmdline_user_args():
		var Map = preload("res://scripts/map.gd")
		Tutorial.finish()
		Env.hour = 12.0
		Env.force_weather("clear")
		for k in ["camlibel", "yalikent", "sehir"]:
			Homes._teleport(1, Map.OTOGARS[k] + Vector2(0, 90))
			w.camera.zoom = Vector2(1.3, 1.3)
			await _wait(1.2)
			await _clear_toasts(w)
			_shot("otogar_" + k)
		get_tree().quit()
		return
	if "--sadece21" in OS.get_cmdline_user_args():
		Net.add_money(1, 400000)
		Rpg.add_xp(1, "", 60000)
		await _shots_21(w)
		get_tree().quit()
		return
	if "--sadece20" in OS.get_cmdline_user_args():
		Net.add_money(1, 400000)
		Rpg.add_xp(1, "", 60000)
		await _shots_20(w)
		get_tree().quit()
		return
	if "--sadece19" in OS.get_cmdline_user_args():
		Net.add_money(1, 400000)
		Rpg.add_xp(1, "", 60000)
		await _shots_19(w)
		get_tree().quit()
		return
	if "--sadece18" in OS.get_cmdline_user_args():
		Net.add_money(1, 400000)
		Rpg.add_xp(1, "", 60000)
		await _shots_18(w)
		get_tree().quit()
		return
	if "--sadece17" in OS.get_cmdline_user_args():
		Net.add_money(1, 400000)
		Rpg.add_xp(1, "", 20000)
		await _shots_17(w)
		get_tree().quit()
		return
	if "--sadece16" in OS.get_cmdline_user_args():
		Net.add_money(1, 300000)
		Rpg.add_xp(1, "", 20000)
		await _shots_16(w)
		get_tree().quit()
		return
	if "--sadece15" in OS.get_cmdline_user_args():
		Net.add_money(1, 300000)
		Rpg.add_xp(1, "", 20000)
		await _shots_15(w)
		get_tree().quit()
		return
	if "--sadece14" in OS.get_cmdline_user_args():
		Net.add_money(1, 300000)
		Rpg.add_xp(1, "", 20000)
		await _shots_14(w)
		get_tree().quit()
		return
	if "--sadece13" in OS.get_cmdline_user_args():
		Net.add_money(1, 300000)
		Rpg.add_xp(1, "", 20000)
		await _shots_13(w)
		get_tree().quit()
		return
	if "--sadece12" in OS.get_cmdline_user_args():
		Net.add_money(1, 300000)
		Rpg.add_xp(1, "", 20000)
		await _shots_12(w)
		get_tree().quit()
		return
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
	if "--fx" in OS.get_cmdline_user_args():
		Tutorial.finish()
		w.hud.visible = false
		w.my_pos = Vector2(1500, 1000)
		w.camera.zoom = Vector2(1.6, 1.6)
		await _wait(1.0)
		var c: Vector2 = w.my_pos
		var kinds := [["dirt", 0.7, {}], ["water", 0.9, {}], ["harvest", 1.0, {"col": Color("#ef4444")}], ["chips", 0.9, {"big": true}],
			["pick", 0.35, {"side": 1.0}], ["money", 1.4, {"v": 250}], ["level", 1.6, {}], ["steam", 1.6, {}], ["smoke", 0.7, {}], ["wake", 1.2, {}]]
		for i in kinds.size():
			w.add_fx(kinds[i][0], c + Vector2(-300 + (i % 5) * 150, -60 + int(i / 5) * 160), kinds[i][1], kinds[i][2])
		await _wait(0.22)
		_shot("fx")
		get_tree().quit()
		return
	if "--olta3" in OS.get_cmdline_user_args():
		Rpg.add_xp(1, "", 2000)
		Tutorial.finish()
		w.hud.visible = false
		var Map = preload("res://scripts/map.gd")
		w.my_pos = Map.PIER_END.get_center() + Vector2(-20, 0)
		w.my_facing = "left"
		w.camera.zoom = Vector2(2.2, 2.2)
		await _wait(1.0)
		Jobs._set_fishing(1, "cast")
		for t in [0.15, 0.3, 0.5, 0.75, 1.4]:
			await _wait(t - (0.0 if t == 0.15 else 0.0))
			_shot("o3_cast_%d" % int(t * 100))
		Jobs._set_fishing(1, "bite")
		await _wait(0.4)
		_shot("o3_bite")
		Jobs._set_fishing(1, "caught")
		await _wait(0.35)
		_shot("o3_caught_a")
		await _wait(0.8)
		_shot("o3_caught_b")
		Jobs._set_fishing(1, "")
		await _wait(0.2)
		Jobs._set_fishing(1, "cast")
		await _wait(1.0)
		Jobs._set_fishing(1, "escaped")
		await _wait(0.4)
		_shot("o3_escaped")
		get_tree().quit()
		return
	if "--olta2" in OS.get_cmdline_user_args():
		Rpg.add_xp(1, "", 2000)
		Tutorial.finish()
		var Map = preload("res://scripts/map.gd")
		var spots := {"deniz_ucu": Map.PIER_END.get_center(), "deniz_orta": Map.PIER_END.get_center() + Vector2(0, -40),
			"deniz_kenar": Vector2(Map.PIER_END.position.x + 12, Map.PIER_END.get_center().y)}
		for k in spots:
			w.my_pos = spots[k]
			w.my_facing = "down"
			await _wait(0.6)
			w._open_panel()
			await _wait(0.4)
			w.panel._on_action()
			await _wait(1.2)
			_shot("o2_" + k)
			print("O2 ", k, " zone=", w.zone, " fishing=", Net.roster[1].get("fishing", "-"), " pos=", w.my_pos)
			w._close_panel()
			Jobs._fish.clear()
			Jobs._set_fishing(1, "")
			await _wait(0.3)
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


## itch.io kapağı için arayüzsüz, temiz sahneler.
func _shots_cover(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Net.add_money(1, 300000)
	Rpg.add_xp(1, "", 20000)
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Tutorial.finish()
	Holidays.force("yok")
	w.hud.visible = false
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5}]
	var names := ["Ayşe", "Kerem", "Zeynep", "Mehmet"]
	for k in 4:
		Net.players[9971 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 9}
	Net._broadcast_roster()
	# şehir merkezi (gündüz, kalabalık)
	Env.hour = 11.0
	var c := Vector2(1300, 470)
	for k in 4:
		Net.positions[9971 + k] = c + Vector2(-140 + k * 90, 40 + (k % 2) * 20)
	w.my_pos = c
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("kapak_sehir")
	# korsan adası
	Env.hour = 16.5
	w.my_pos = Map.KORSAN.get_center() + Vector2(60, 20)
	Net.positions[9971] = Map.KORSAN.get_center() + Vector2(-60, 60)
	Net.positions[9972] = Map.KORSAN.get_center() + Vector2(140, -20)
	w.camera.zoom = Vector2(1.2, 1.2)
	await _wait(1.6)
	_shot("kapak_korsan")
	# dağ köyü
	Env.hour = 12.0
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(0, 70)
	await _wait(0.3)
	Mountain.go_up()
	await _wait(0.5)
	w.my_pos = Map.MOUNTAIN_SPAWN + Vector2(380, -60)
	Net.positions[9971] = w.my_pos + Vector2(60, 20)
	Net.positions[9972] = w.my_pos + Vector2(-50, 40)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("kapak_dag")
	w.my_pos = Map.MOUNTAIN_BUILDINGS[1].rect.get_center() + Vector2(0, 80)
	await _wait(0.3)
	Mountain.go_down()
	await _wait(0.5)
	# lunapark
	w.my_pos = Map.SHUTTLE_CITY + Vector2(0, 20)
	await _wait(0.3)
	Fair.shuttle(true)
	await _wait(0.5)
	Net.players[9971]["ride"] = "ferris"
	Net.players[9971]["seat"] = 3
	Net.players[9972]["ride"] = "bumper"
	Net._broadcast_roster()
	Net.positions[9972] = Map.BUMPER.get_center() + Vector2(-80, 30)
	w.my_pos = Map.FERRIS + Vector2(320, 160)
	w.camera.zoom = Vector2(0.85, 0.85)
	for _k in 60:
		Net.positions[9971] = Fair.seat_pos(3, Land.server_now())
		await get_tree().process_frame
	await _clear_toasts(w)
	_shot("kapak_luna")


func _shots_15(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("autumn")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]
	var names := ["Ayşe", "Kerem", "Zeynep"]
	# iskeledeki tekneler (gündüz)
	Env.hour = 12.0
	w.my_pos = Vector2(Map.PIER.end.x - 10, Map.MOORED_BOATS[0].y - 60)
	w.camera.zoom = Vector2(1.3, 1.3)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("iskele_tekneler")
	w.camera.zoom = Vector2(1, 1)
	# Cadılar Bayramı gecesi
	Holidays.force("cadilar")
	Env.hour = 21.5
	w.my_pos = Holidays.STALL + Vector2(0, 40)
	await _wait(0.4)
	Holidays.costume("cadi")
	for k in 3:
		Net.players[9961 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 9, "costume": ["hayalet", "vampir", "kabak"][k]}
	var door: Vector2 = Holidays.door_pos("b:market")
	Net.positions[9961] = door + Vector2(-60, 30)
	Net.positions[9962] = door + Vector2(60, 40)
	Net.positions[9963] = door + Vector2(120, 10)
	Net._broadcast_roster()
	w.my_pos = door + Vector2(0, 14)
	w.camera.zoom = Vector2(1.4, 1.4)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("cadilar")
	w.camera.zoom = Vector2(1, 1)
	for k in 3:
		Net.players.erase(9961 + k)
		Net.positions.erase(9961 + k)
	Net._broadcast_roster()
	# yılbaşı
	Holidays.force("yilbasi")
	Env.hour = 18.5
	for _k in 8:
		Holidays._spawn_gift()
	Holidays._gifts.append({"id": 900, "x": Holidays.TREE.x + 90, "y": Holidays.TREE.y + 70})
	Holidays._broadcast_gifts()
	w.my_pos = Holidays.TREE + Vector2(60, 90)
	w.camera.zoom = Vector2(1.5, 1.5)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("yilbasi")
	w.camera.zoom = Vector2(1, 1)
	Holidays.force("yok")
	Env.hour = 13.0
	# spor salonu
	w.my_pos = Map.building("spor").rect.get_center() + Vector2(0, 92)
	await _wait(0.4)
	Gym.buy_pass()
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	Gym.train("strength")
	await _wait(2.4)
	Gym.lift()
	await _wait(0.5)
	_shot("spor_salonu")
	await _wait(9.0)
	w._close_panel()
	# maraton
	w.my_pos = Map.MARATHON[0]
	await _wait(0.3)
	Gym.start_marathon()
	await _wait(0.3)
	w.my_pos = Map.MARATHON[1] + Vector2(-40, 30)
	await _wait(0.5)
	w.my_pos = Map.MARATHON[1] + Vector2(-260, 0)
	w.my_facing = "left"
	for _k in 30:
		w.my_pos += Vector2(-3, 0)
		w.my_moving = true
		await get_tree().process_frame
	await _clear_toasts(w)
	_shot("maraton")
	Gym._runs.clear()
	Gym.run = {}
	w.nav_target = null
	# korsan adası
	Env.hour = 16.5
	var rec: Dictionary = Net.save_data.players["Eren"]
	w.my_pos = Map.KORSAN_CAPTAIN + Vector2(0, 40)
	await _wait(0.4)
	Pirates.buy("shovel")
	for _k in 4:
		Pirates.maybe_piece(1, 1.0)
	await _wait(0.2)
	Pirates.combine()
	await _wait(0.3)
	rec.erase("pet")
	rec.pirate["found"] = 1
	Pirates.buy("parrot")
	await _wait(0.3)
	w._open_panel()
	await _wait(0.6)
	_shot("hazine_haritasi")
	w._close_panel()
	var spot := Vector2(float(rec.pirate.spot[0]), float(rec.pirate.spot[1]))
	for off in [Vector2(-160, 40), Vector2(140, -30), Vector2(60, 80), Vector2(-60, -50)]:
		w.my_pos = Map.KORSAN.get_center() + off
		await _wait(0.2)
		Pirates._dig_t.clear()
		Pirates.dig()
		await _wait(0.2)
	w.my_pos = spot + Vector2(80, 20)
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("korsan_adasi")
	w.camera.zoom = Vector2(1, 1)
	# hayvanat bahçesi ve akvaryum
	Env.hour = 12.0
	w.my_pos = Map.SHUTTLE_CITY + Vector2(0, 20)
	await _wait(0.3)
	Fair.shuttle(true)
	await _wait(0.5)
	w.my_pos = Map.ZOO_GATE + Vector2(0, -50)
	await _wait(0.3)
	Zoo.buy_ticket()
	await _wait(0.4)
	w.my_pos = Map.ZOO_GATE + Vector2(0, 180)
	w.camera.zoom = Vector2(0.8, 0.8)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("hayvanat_bahcesi")
	w.camera.zoom = Vector2(1.6, 1.6)
	w.my_pos = Zoo.pen_front("zurafa") + Vector2(-120, -40)
	await _wait(1.2)
	_shot("zurafa")
	w.camera.zoom = Vector2(1, 1)
	for n in ["Sazan", "Levrek", "Lüfer", "Kalkan", "Alabalık", "Orkinos", "Hamsi", "Kızılkanat", "Turna", "Palamut", "Köpekbalığı"]:
		Museum._data()["fish:" + n] = {"by": "Eren", "d": "2026-10-26"}
	Museum.send_state(1)
	w.my_pos = Map.ZOO_BUILDINGS[0].rect.get_center() + Vector2(0, 190)
	await _wait(0.4)
	w._open_panel()
	await _wait(1.2)
	_shot("akvaryum")
	w._close_panel()


func _shots_14(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 17.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]
	var names := ["Ayşe", "Kerem", "Zeynep"]
	# okul
	w.my_pos = Map.building("okul").rect.get_center() + Vector2(0, 118)
	await _wait(0.5)
	w._open_panel()
	await _wait(0.3)
	School.start_exam("surucu")
	await _wait(0.6)
	_shot("okul_sinav")
	w._close_panel()
	# dedektif: vaka, ipucu ve şüpheli
	w.my_pos = Map.DETECTIVE + Vector2(0, 40)
	await _wait(0.4)
	Detective.take_case()
	await _wait(0.3)
	var cs := Detective.active_case()
	w.my_pos = cs.clues[0].pos + Vector2(0, 30)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	for sp in [cs.suspects[0], cs.suspects[2]]:
		w.my_pos = sp.pos + Vector2(0, 40)
		await _wait(0.3)
		w._open_panel()
		await _wait(0.3)
	w.my_pos = cs.suspects[1].pos + Vector2(60, 40)
	w.camera.zoom = Vector2(1.4, 1.4)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("dedektif_supheli")
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Map.DETECTIVE + Vector2(0, 40)
	await _wait(0.4)
	w._open_panel()
	await _wait(0.6)
	_shot("dedektif_dosya")
	w._close_panel()
	# fuar
	w.my_pos = Map.SHUTTLE_CITY + Vector2(0, 20)
	await _wait(0.3)
	Fair.shuttle(true)
	await _wait(0.5)
	w.my_pos = Map.TICKET_BOOTH + Vector2(0, 50)
	await _wait(0.3)
	for _k in 4:
		Fair.buy_jeton()
	await _wait(0.3)
	# sahte oyuncular: dolapta ve çarpışan arabada
	for k in 3:
		Net.players[9951 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 9}
	Net.players[9951]["ride"] = "ferris"
	Net.players[9951]["seat"] = 2
	Net.positions[9951] = Fair.seat_pos(2, Land.server_now())
	Net.players[9952]["ride"] = "bumper"
	Net.positions[9952] = Map.BUMPER.get_center() + Vector2(-120, 40)
	Net.positions[9953] = Map.GALLERY + Vector2(40, 60)
	Net._broadcast_roster()
	w.my_pos = Vector2(Map.BUMPER.get_center().x, Map.BUMPER.end.y + 40)
	await _wait(0.3)
	Fair.ride_bumper()
	await _wait(0.6)
	w.my_pos = Map.BUMPER.get_center() + Vector2(60, -20)
	w.camera.zoom = Vector2(0.8, 0.8)
	for _k in 40:
		Net.positions[9951] = Fair.seat_pos(2, Land.server_now())
		await get_tree().process_frame
	w.my_pos = Map.BUMPER.get_center() + Vector2(-200, 120)
	await _wait(0.8)
	await _clear_toasts(w)
	_shot("lunapark")
	w.camera.zoom = Vector2(1.4, 1.4)
	w.my_pos = Map.BUMPER.get_center() + Vector2(40, 30)
	await _wait(0.8)
	_shot("carpisan")
	Fair._bumper[1].end = 0.0
	await _wait(0.4)
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Map.FERRIS + Vector2(0, Map.FERRIS_R + 60)
	await _wait(0.3)
	Fair.ride_ferris()
	await _wait(6.0)
	w.camera.zoom = Vector2(1.2, 1.2)
	await _wait(0.8)
	await _clear_toasts(w)
	_shot("donme_dolap")
	Fair._ferris[1] = 0.0
	await _wait(0.4)
	w.camera.zoom = Vector2(1, 1)
	w.my_pos = Map.GALLERY + Vector2(0, 50)
	await _wait(0.3)
	w._open_panel()
	await _wait(0.3)
	Fair.start_gallery()
	await _wait(4.0)
	var g: Dictionary = Fair.gallery
	var tt: float = Time.get_ticks_msec() / 1000.0 - float(g.t0)
	for tg in g.targets:
		if tt > float(tg.t) and tt < float(tg.t) + float(tg.dur) * 0.6:
			w.panel._shot[int(tg.id)] = true
			Fair.shoot(int(tg.id))
			break
	await _wait(0.3)
	_shot("atis_poligonu")
	w._close_panel()
	Fair._data(Net.save_data.players["Eren"])["bilet"] = 64
	Fair.send_state(1)
	w.my_pos = Map.TICKET_BOOTH + Vector2(0, 50)
	await _wait(0.4)
	w._open_panel()
	await _wait(0.5)
	_shot("odul_standi")
	w._close_panel()
	# havalimanı
	w.my_pos = Map.FAIR_BUILDINGS[0].rect.get_center() + Vector2(220, 240)
	Airport.on_takeoff({})
	await _wait(3.0)
	await _clear_toasts(w)
	w.camera.zoom = Vector2(0.75, 0.75)
	await _wait(0.6)
	_shot("havalimani")
	w.camera.zoom = Vector2(1, 1)
	# balon turu
	w.my_pos = Map.BALLOON_FIELD + Vector2(0, 60)
	await _wait(0.3)
	Airport.ride_balloon()
	await _wait(14.0)
	await _clear_toasts(w)
	_shot("balon")
	Airport._balloon[1] = 0.0
	await _wait(0.6)
	# uçuş
	w.my_pos = Map.FAIR_BUILDINGS[0].rect.get_center() + Vector2(0, 130)
	await _wait(0.3)
	Airport.fly("ada")
	await _wait(1.4)
	_shot("ucus")
	await _wait(2.5)


func _shots_13(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 13.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]
	# olta (deniz iskelesi)
	w.my_pos = Map.PIER_END.get_center() + Vector2(-20, 0)
	w.my_facing = "left"
	w.camera.zoom = Vector2(1.8, 1.8)
	await _wait(1.0)
	Jobs._set_fishing(1, "cast")
	await _wait(0.45)
	await _clear_toasts(w)
	_shot("olta_atis")
	Jobs._set_fishing(1, "bite")
	await _wait(0.35)
	_shot("olta_vurdu")
	Jobs._set_fishing(1, "caught")
	await _wait(1.0)
	_shot("olta_cekis")
	Jobs._set_fishing(1, "")
	w.camera.zoom = Vector2(1, 1)
	# telefon
	Net.save_data.players["Ayşe"] = {"money": 100}
	Net.save_data.players["Kerem"] = {"money": 100}
	Phone.send("Ayşe", "Akşam dağa çıkıp kamp ateşi yakalım mı?")
	var box := Phone._box("Eren")
	box.append({"w": "Ayşe", "o": false, "x": "Olur! Marshmallow getiriyorum 🙂", "d": Time.get_unix_time_from_system() - 30, "r": false})
	box.append({"w": "Kerem", "o": false, "x": "Hipodromda yarış var, gel bahse girelim!", "d": Time.get_unix_time_from_system() - 600, "r": false})
	Phone.add_friend("Ayşe")
	Phone.add_friend("Kerem")
	Net.announce("Kerem hipodromda Rüzgâr ile birinci oldu!")
	await _wait(0.3)
	Phone.send_state(1)
	await _wait(0.3)
	w.my_pos = Vector2(1300, 1000)
	await _wait(0.6)
	w.open_phone()
	await _wait(0.4)
	w.panel._open_chat("Ayşe")
	await _wait(0.5)
	_shot("telefon")
	w._close_panel()
	# fotoğraf modu (vintage)
	w.my_pos = Map.FOUNTAIN + Vector2(80, 60)
	Env.hour = 18.2
	await _wait(1.0)
	w.set_photo_mode(true)
	w.photo_filter = 5
	w._update_photo_hint()
	await _wait(0.5)
	_shot("foto_modu")
	w.set_photo_mode(false)
	Env.hour = 13.0
	# takas (örnek görünüm)
	Trade.view = {"tid": 1, "me": "a", "other": "Ayşe", "ok": {"a": false, "b": true},
		"offers": {"a": {"money": 500, "fish": [], "barn": {"domates": 6}, "items": {}}, "b": {"money": 0, "fish": [], "barn": {"elmas": 1, "kuzugobegi": 2}, "items": {"menemen": 1}}},
		"fish_names": {"a": [], "b": []}}
	var st := Farm.barn(Net.save_data.players["Eren"])
	st["domates"] = 10
	Farm.send_state(1)
	await _wait(0.2)
	w._on_trade_open(Trade.view)
	await _wait(0.6)
	_shot("takas")
	Trade.view = {}
	w._close_panel()
	# hara: ata binmiş oyuncu ve padok
	w.my_pos = Map.building("hara").rect.get_center() + Vector2(0, 88)
	await _wait(0.3)
	Horses.buy()
	Horses.buy()
	await _wait(0.4)
	w.my_pos = Map.building("hara").rect.get_center() + Vector2(-150, 150)
	await _wait(0.2)
	Garage.ride("horse")
	w.my_facing = "right"
	await _wait(0.2)
	Net.players[9901] = {"name": "Ayşe", "money": 5000, "color": Avatar.shirt_color(apps[0]), "appearance": apps[0], "level": 9, "ride": "horse", "hc": 2}
	Net.positions[9901] = Map.building("hara").rect.get_center() + Vector2(160, 170)
	Net._broadcast_roster()
	w.camera.zoom = Vector2(1.4, 1.4)
	for k in 40:
		w.my_pos += Vector2(3, 0)
		w.my_moving = true
		await get_tree().process_frame
	await _clear_toasts(w)
	_shot("hara")
	w.camera.zoom = Vector2(1, 1)
	Garage.ride("")
	# hipodrom yarışı
	w.my_pos = Map.HIPPO_BOOTH + Vector2(40, 0)
	await _wait(0.4)
	Horses.join_race()
	await _wait(0.3)
	Horses.bet(0, 300)
	Horses._race.t = 0.0
	await _wait(4.5)
	Horses.whip()
	w.my_pos = Vector2(Horses._race.lanes[0].x + 120, Map.HIPPODROME.position.y - 30)
	await _wait(0.5)
	w.camera.zoom = Vector2(1.2, 1.2)
	await _wait(0.6)
	await _clear_toasts(w)
	_shot("hipodrom")
	w.camera.zoom = Vector2(1, 1)
	w.zone = {"type": "hipodrom", "label": "x"}
	w._open_panel()
	await _wait(0.6)
	_shot("hipodrom_panel")
	w._close_panel()
	await _wait(12.0)
	# kamp (gece)
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(0, 70)
	await _wait(0.3)
	Mountain.go_up()
	await _wait(0.5)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	for k in ["tent", "marshmallow", "marshmallow", "odun", "odun"]:
		Camp.buy(k)
	await _wait(0.4)
	w.my_pos = Vector2(8020, 2280)
	await _wait(0.3)
	Camp.pitch()
	Camp._data().tents["Ayşe"] = {"x": 8380, "y": 2540, "c": 2}
	Camp._data().tents["Kerem"] = {"x": 8000, "y": 2520, "c": 1}
	Camp.send_state(1)
	for i in 2:
		w.my_pos = Map.CAMPFIRES[i] + Vector2(0, 50)
		await _wait(0.25)
		Camp.light(i)
		await _wait(0.2)
	for _k in 8:
		Camp._spawn_spot()
	Camp._broadcast({"spots": Camp._spots})
	Env.hour = 21.8
	w.my_pos = Map.CAMPFIRES[0] + Vector2(40, 46)
	await _wait(0.4)
	Camp.roast(0)
	for k in 2:
		Net.players[9911 + k] = {"name": ["Ayşe", "Kerem"][k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 9, "roast": k == 0}
		Net.positions[9911 + k] = Map.CAMPFIRES[0] + [Vector2(-56, 30), Vector2(-10, -50)][k]
	Net._broadcast_roster()
	w.camera.zoom = Vector2(1.5, 1.5)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("kamp")
	w.camera.zoom = Vector2(1, 1)
	# teleskop
	w.my_pos = Map.TELESCOPE + Vector2(0, 40)
	await _wait(0.4)
	w._open_panel()
	await _wait(0.3)
	Camp.on_star({"a": 0.15, "b": 0.12})
	await _wait(0.5)
	_shot("teleskop")
	w._close_panel()
	# orman ürünleri (gündüz)
	Env.hour = 11.0
	var sp: Dictionary = Camp.spots[0]
	w.my_pos = Vector2(float(sp.x) + 60, float(sp.y) + 30)
	w.camera.zoom = Vector2(1.6, 1.6)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("orman")
	w.camera.zoom = Vector2(1, 1)


func _shots_12(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.hour = 12.0
	Env.force_weather("clear")
	Env.force_season("autumn")
	Tutorial.finish()
	w.camera.zoom = Vector2(1, 1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
		{"skin": 4, "hair": 4, "hair_color": 0, "shirt": 8, "pants": 5}]
	var names := ["Ayşe", "Kerem", "Zeynep", "Mehmet"]
	# teleferik istasyonu (şehir)
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(-60, 120)
	await _wait(1.4)
	await _clear_toasts(w)
	_shot("teleferik")
	# dağ köyü
	w.my_pos = Map.building("teleferik").rect.get_center() + Vector2(0, 70)
	await _wait(0.3)
	Mountain.go_up()
	await _wait(0.5)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.3)
	Mountain.buy("pickaxe")
	Mountain.buy("skis")
	await _wait(0.3)
	for _k in 16:
		Mountain._spawn_rock()
	Mountain._broadcast_rocks()
	w.my_pos = Map.MOUNTAIN_SPAWN + Vector2(330, -40)
	for k in 2:
		Net.players[9701 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 9}
		Net.positions[9701 + k] = Map.MOUNTAIN_SPAWN + Vector2(420 + k * 70, 10 - k * 30)
	Net._broadcast_roster()
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("dag_koyu")
	# maden ocağı
	var r: Dictionary = Mountain.rocks[0]
	for x in Mountain.rocks:
		if x.k == "kristal":
			r = x
	w.my_pos = Vector2(float(r.x) + 40, float(r.y) + 20)
	w.my_facing = "left"
	Net.positions[9701] = Vector2(float(Mountain.rocks[1].x) + 40, float(Mountain.rocks[1].y) + 20)
	Mountain._last_hit.clear()
	Mountain.hit(int(r.id))
	w.camera.zoom = Vector2(1.3, 1.3)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("maden")
	w.camera.zoom = Vector2(1, 1)
	# kayak
	Env.force_season("winter")
	w.my_pos = Map.LIFT + Vector2(0, 40)
	await _wait(0.3)
	Mountain.ski_start()
	await _wait(0.2)
	var g: Array = Map.ski_gates()
	w.my_pos = Vector2(g[3].x + 10, g[3].y - 140)
	Net.players[9702]["ride"] = "ski"
	Net.positions[9702] = Vector2(g[2].x, g[2].y + 60)
	Net._broadcast_roster()
	await _wait(0.6)
	await _clear_toasts(w)
	_shot("kayak")
	Mountain.ski_stop()
	await _wait(0.3)
	Net.players[9702]["ride"] = ""
	Env.force_season("autumn")
	# Dağ Evi paneli
	var store := Farm.barn(Net.save_data.players["Eren"])
	for k in ["komur", "demir", "gumus", "f_trilobit"]:
		store[k] = int(store.get(k, 0)) + 3
	Farm.send_state(1)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[0].rect.get_center() + Vector2(0, 110)
	await _wait(0.4)
	w._open_panel()
	await _wait(0.6)
	_shot("dag_evi")
	w._close_panel()
	for id in [9701, 9702]:
		Net.players.erase(id)
		Net.positions.erase(id)
	w.my_pos = Map.MOUNTAIN_BUILDINGS[1].rect.get_center() + Vector2(0, 80)
	await _wait(0.3)
	Mountain.go_down()
	await _wait(0.5)
	# müze
	var bag: Array = Net.save_data.players["Eren"].get("fish", [])
	for n in ["Sazan", "Levrek", "Lüfer", "Kalkan", "İnci", "Altın Balık", "Kızılkanat", "Hamsi"]:
		bag.append({"name": n, "price": 100})
	Jobs.send_inventory(1)
	w.my_pos = Map.building("muze").rect.get_center() + Vector2(0, 160)
	await _wait(0.4)
	for n in ["Sazan", "Levrek", "Lüfer", "Kalkan", "Altın Balık"]:
		Museum.donate("fish:" + n)
	Museum.donate("barn:f_trilobit")
	Museum.donate("barn:gumus")
	Museum._data()["fish:Turna"] = {"by": "Ayşe", "d": "2026-10-25"}
	Museum._data()["fish:Orkinos"] = {"by": "Kerem", "d": "2026-10-25"}
	Museum.send_state(1)
	await _wait(0.5)
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("muze_dis")
	w.camera.zoom = Vector2(1, 1)
	w._open_panel()
	await _wait(0.8)
	_shot("muze")
	w._close_panel()
	# restoran menüsü
	var bp := 5
	w.my_pos = Map.plot_rect(bp).get_center()
	await _wait(0.3)
	Land.buy(bp)
	await _wait(0.3)
	for _k in 3:
		Land.build_up(bp, "biz")
		await _wait(0.3)
	store = Farm.barn(Net.save_data.players["Eren"])
	for k in ["domates", "yumurta", "sut", "bugday", "misir", "lahana", "kabak"]:
		store[k] = 12
	Farm.send_state(1)
	await _wait(0.2)
	for k in ["menemen", "menemen", "sutlac", "sutlac", "corba", "salata", "borek", "kabak_tatlisi"]:
		Kitchen.cook(k)
		await _wait(0.15)
	for k in ["menemen", "sutlac", "corba", "salata", "borek"]:
		Biz.menu_add(bp, k)
		await _wait(0.1)
	Land.plots[bp].biz["menu_sold"] = 37
	Land.plots[bp].biz["last_menu"] = 3
	Land._broadcast()
	w.zone = {"type": "realestate", "label": "x", "plot": bp}
	w._open_panel()
	await _wait(0.8)
	_shot("restoran_menu")
	w._close_panel()
	# konser (akşam)
	Env.hour = 18.4
	var s: Rect2 = Map.STAGE
	w.my_pos = s.get_center() + Vector2(-85, 0)
	w.my_facing = "down"
	await _wait(0.3)
	for k in ["gitar", "davul", "klavye"]:
		Band.buy(k)
	await _wait(0.3)
	for k in 2:
		Net.players[9801 + k] = {"name": names[k + 2], "money": 5000, "color": Avatar.shirt_color(apps[k + 2]), "appearance": apps[k + 2], "level": 9, "playing": ["davul", "klavye"][k]}
		Net.positions[9801 + k] = s.get_center() + Vector2(10 + k * 70, -4 + k * 6)
	Net.players[9803] = {"name": "Ayşe", "money": 5000, "color": Avatar.shirt_color(apps[0]), "appearance": apps[0], "level": 9}
	Net.positions[9803] = s.get_center() + Vector2(-20, 120)
	Net._broadcast_roster()
	Band.play(0, "gitar")
	await _wait(0.4)
	w.camera.zoom = Vector2(1.5, 1.5)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("konser")
	w.camera.zoom = Vector2(1, 1)
	w.zone = {"type": "stage", "label": "x"}
	w._open_panel()
	await _wait(0.2)
	w.panel._on_start(Band.session)
	# yoğun bir bölümün başına kadar bekle, birkaç notaya doğru zamanda bas
	var st: float = Time.get_ticks_msec() / 1000.0 - float(Band.session.t0)
	var nts: Array = Band.session.notes
	var target := 0
	for i in nts.size():
		if float(nts[i][0]) > st + 1.0 and i + 4 < nts.size() and float(nts[i + 4][0]) - float(nts[i][0]) < 3.0:
			target = i
			break
	for i in range(target, target + 2):
		var wt: float = float(Band.session.t0) + float(nts[i][0]) - Time.get_ticks_msec() / 1000.0
		if wt > 0.0:
			await _wait(wt)
		w.panel._lane_pressed(int(nts[i][1]))
	await _wait(0.12)
	_shot("ritim")
	w._close_panel()


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


func _shots_16(w) -> void:
	var OM = preload("res://scripts/ocean_map.gd")
	var Avatar = preload("res://scripts/avatar.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	if not "boat" in rec.vehicles:
		rec.vehicles.append("boat")
	Garage.send_state(1)
	var apps := [{"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
		{"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0},
		{"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]
	var names := ["Ayşe", "Kerem", "Zeynep"]
	for k in 3:
		Net.players[9971 + k] = {"name": names[k], "money": 5000, "color": Avatar.shirt_color(apps[k]), "appearance": apps[k], "level": 12, "ride": "boat"}
	var isl: Array = OM.islands()
	var home: Dictionary = isl[0]
	Garage.set_ride(1, "boat")
	Homes._teleport(1, OM.ARRIVE)
	await _wait(0.5)
	# Liman Adası: tersane, fener, iskele, yakıt
	Garage.set_ride(1, "")
	Homes._teleport(1, Ocean.lighthouse_pos(home) + Vector2(0, 20))
	await _wait(0.3)
	Ocean.light(0)
	await _wait(0.3)
	var pe: Vector2 = OM.pier_end(home) + Vector2(home.dock_dir) * 70.0
	Net.positions[9971] = pe + Vector2(-140, 30)
	Net.positions[9972] = pe + Vector2(160, 10)
	Net.players[9973].ride = ""
	Net.positions[9973] = OM.pier_end(home) - Vector2(home.dock_dir) * 30.0
	Net._broadcast_roster()
	w.my_pos = home.c + Vector2(40, -60)
	Garage.set_ride(1, "")
	w.camera.zoom = Vector2(0.8, 0.8)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("okyanus_liman")
	# ada çeşitleri
	for t in ["volkanik", "buzul", "batik", "mangrov"]:
		for i in isl:
			if i.type == t:
				var p: Vector2 = Vector2(i.c) + Vector2(0, float(i.r) * float(i.sq) + 120.0)
				Homes._teleport(1, p)
				Garage.set_ride(1, "boat")
				Net.positions[9971] = p + Vector2(-200, 40)
				Net.positions[9972] = p + Vector2(220, 60)
				Net.positions[9973] = p + Vector2(330, -20)
				Net.players[9973].ride = "boat"
				Net._broadcast_roster()
				w.camera.zoom = Vector2(0.75, 0.75)
				await _wait(1.3)
				await _clear_toasts(w)
				_shot("okyanus_" + t)
				break
	# fırtına
	var sp: Vector2 = OM.ARRIVE + Vector2(1600, 1400)
	if OM.island_at(sp, 200.0) >= 0:
		sp += Vector2(600, 0)
	Ocean._storms = [{"p": sp + Vector2(120, -60), "v": Vector2.ZERO, "r": 650.0}]
	Homes._teleport(1, sp)
	Net.positions[9971] = sp + Vector2(-180, 60)
	Net.positions[9972] = sp + Vector2(200, 90)
	await _wait(1.6)
	await _clear_toasts(w)
	_shot("okyanus_firtina")
	Ocean._storms = [{"p": OM.OCEAN.end - Vector2(900, 900), "v": Vector2.ZERO, "r": 300.0}]
	# Kraken
	Ocean.spawn_kraken()
	Ocean._kraken.p = sp + Vector2(0, -60)
	Ocean._broadcast_world()
	Homes._teleport(1, sp + Vector2(-330, 120))
	Net.positions[9971] = sp + Vector2(330, 140)
	Net.positions[9972] = sp + Vector2(40, 260)
	Net.positions[9973] = sp + Vector2(-260, -140)
	Ocean._kraken.hp = int(Ocean._kraken.max * 0.55)
	Ocean._broadcast_world()
	await _wait(1.0)
	w._harp_t = -10.0
	w._harpoon()
	await _wait(0.15)
	await _clear_toasts(w)
	_shot("okyanus_kraken")
	Ocean._kraken = {}
	Ocean._broadcast_world()
	# keşif haritası
	for i in isl.size():
		if i % 3 != 2:
			Ocean.reveal_around(isl[i].c, 1200.0)
	Ocean.flush_seen()
	await _wait(0.6)
	w.open_ocean_map()
	await _wait(0.8)
	_shot("okyanus_harita")
	w._close_panel()
	w.camera.zoom = Vector2(1, 1)
	for k in 3:
		Net.players.erase(9971 + k)
		Net.positions.erase(9971 + k)
	Net._broadcast_roster()


func _fake_players(apps_names: Array) -> void:
	var Avatar = preload("res://scripts/avatar.gd")
	for k in apps_names.size():
		var a: Array = apps_names[k]
		Net.players[9981 + k] = {"name": a[0], "money": 5000, "color": Avatar.shirt_color(a[1]), "appearance": a[1], "level": 14, "ride": ""}
	Net._broadcast_roster()


func _shots_17(w) -> void:
	var Map = preload("res://scripts/map.gd")
	var OM = preload("res://scripts/ocean_map.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	var me := 1
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
		["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
		["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
	_fake_players(apps)
	# --- tren: şehir garı, tren peronda
	Map.rail_shift = 15.0 - fposmod(Time.get_unix_time_from_system(), Map.RAIL_PERIOD)
	var bo: Vector2 = Map.RAIL.sehir.booth
	w.my_pos = bo + Vector2(0, 46)
	Net.positions[9981] = bo + Vector2(110, 2)
	Net.positions[9982] = bo + Vector2(180, -6)
	Net.positions[9983] = bo + Vector2(-140, 0)
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("tren_sehir")
	# --- dağ istasyonu, tren giriyor
	Map.rail_shift = 6.0 - fposmod(Time.get_unix_time_from_system(), Map.RAIL_PERIOD)
	Homes._teleport(me, Map.RAIL.dag.booth + Vector2(-40, 10))
	Net.positions[9981] = Map.RAIL.dag.booth + Vector2(90, 0)
	Net.positions[9982] = Map.RAIL.dag.booth + Vector2(150, -20)
	Net.positions[9983] = Map.RAIL.dag.booth + Vector2(-200, -30)
	w.camera.zoom = Vector2(0.9, 0.9)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("tren_dag")
	# --- yolculuk
	_rail_stop_shot()
	Rail.board("fuar")
	await _wait(2.5)
	_shot("tren_yolculuk")
	await _wait(5.0)
	Map.rail_shift = 0.0
	# --- sinema dışı
	var cr: Rect2 = Map.CINEMA.rect
	Homes._teleport(me, Vector2(cr.get_center().x - 40, cr.end.y + 40))
	Net.positions[9981] = Vector2(cr.get_center().x + 60, cr.end.y + 50)
	Net.positions[9982] = Vector2(cr.get_center().x + 120, cr.end.y + 30)
	Net.positions[9983] = Vector2(cr.get_center().x - 140, cr.end.y + 60)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("sinema_dis")
	# --- film
	Cinema.shift = 4.0 - fposmod(Time.get_unix_time_from_system(), Cinema.SESSION)
	Cinema.buy_ticket()
	await _wait(0.3)
	Cinema.shift += 50.0
	w.zone = {"type": "sinema"}
	w._open_panel()
	await _wait(0.5)
	Cinema.reaction.emit({"who": "Kerem", "k": "kahkaha"})
	Cinema.reaction.emit({"who": "Ayşe", "k": "alkis"})
	await _wait(0.6)
	_shot("sinema_film")
	w._close_panel()
	# --- karaoke
	w.zone = {"type": "sinema"}
	w._open_panel()
	await _wait(0.3)
	Cinema.karaoke_start(1)
	await _wait(6.2)
	_shot("karaoke")
	Cinema.karaoke_finish([])
	w._close_panel()
	Cinema.shift = 0.0
	# --- paintball
	Homes._teleport(me, Map.ARENA_BOOTH + Vector2(0, 20))
	await _wait(0.4)
	Paint.join("kirmizi")
	await _wait(0.3)
	Paint.start()
	await _wait(4.0)
	w.camera.zoom = Vector2(1.0, 1.0)
	Paint.fire(Vector2(1, -0.2))
	await _wait(0.12)
	await _clear_toasts(w)
	_shot("paintball")
	Paint._finish("")
	await _wait(0.5)
	Paint.leave_team()
	for k in 3:
		Net.positions.erase(9981 + k)
	# --- özel ada
	if not "boat" in rec.vehicles:
		rec.vehicles.append("boat")
	Garage.send_state(me)
	var sale: Array = Isles.for_sale()
	var ii: int = sale[0]
	for cand in sale:
		if OM.islands()[cand].type == "tropik":
			ii = cand
			break
	var isl: Dictionary = OM.islands()[ii]
	var sp: Dictionary = Isles.spots(isl)
	if Net.save_data.get("isles") is Dictionary:
		Net.save_data.isles.clear()                 # önceki çekimden kalan ada
	Garage.set_ride(me, "")
	Homes._teleport(me, sp.sign + Vector2(0, 10))
	await _wait(0.6)
	print("[foto] ada: ", isl.name, " konum ", w.my_pos, " okyanus ", w._ocean)
	Isles.buy(ii)
	await _wait(0.3)
	for k in ["ev", "ev", "ev", "bahce", "havuz", "fener", "iskele"]:
		Isles.build(ii, k)
		await _wait(0.15)
	Homes._teleport(me, sp.house + Vector2(60, 70))
	Net.positions[9981] = sp.pool + Vector2(0, 50)
	Net.positions[9982] = sp.garden + Vector2(30, 40)
	w.camera.zoom = Vector2(0.85, 0.85)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("ozel_ada")
	# --- ticaret: liman paneli ve korsan baskını
	var home: Dictionary = OM.islands()[0]
	Homes._teleport(me, OM.pier_end(home) + Vector2(home.dock_dir) * 60.0)
	Garage.set_ride(me, "boat")
	await _wait(0.4)
	Cargo.buy(Cargo.local_good(0), 6)
	await _wait(0.4)
	w.camera.zoom = Vector2(1, 1)
	w.zone = {"type": "ocean_fuel", "port": 0}
	w._open_panel()
	await _wait(0.6)
	_shot("liman_ticaret")
	w._close_panel()
	var far := Vector2(20500, 4200)
	Homes._teleport(me, far)
	await _wait(0.3)
	Net.positions[9981] = far + Vector2(-220, 80)
	Net.players[9981].ride = "boat"
	Net._broadcast_roster()
	Cargo.start_raid(me)
	Cargo._raids[me].p = far + Vector2(330, -120)
	Cargo._raids[me].until += 999.0
	await _wait(0.6)
	Cargo._raids[me].p = far + Vector2(330, -120)
	Cargo._broadcast_raids()
	await _wait(0.4)
	w._harp_t = -10.0
	w.zone = {"type": "ocean_harpoon", "target": "raid", "owner": Net.my_name}
	w._harpoon()
	await _wait(0.15)
	await _clear_toasts(w)
	_shot("korsan_baskini")
	Cargo._raids.clear()
	Cargo._broadcast_raids()
	# --- göl: kayık ve yüzenler
	Homes._teleport(me, Map.DOCK.position + Vector2(30, 40))
	Garage.set_ride(me, "")
	await _wait(0.4)
	Pets.give(me, "dog", "Karabaş")
	w._board_kayik()
	await _wait(0.4)
	var lc: Vector2 = Map.LAKE.get_center()
	for k in 25:
		w.my_pos = w.my_pos.lerp(lc + Vector2(120, -40), 0.12)
		await _wait(0.04)
	Net.players[9981].ride = "kayik"
	Net.positions[9981] = lc + Vector2(-120, 90)
	Net.players[9982].ride = ""
	Net.positions[9982] = lc + Vector2(-Map.LAKE.size.x / 2.0 * 0.78, -60)
	Net.players[9983].ride = ""
	Net.positions[9983] = Map.DOCK.position + Vector2(70, 40)
	Net._broadcast_roster()
	w.camera.zoom = Vector2(0.9, 0.9)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("gol_kayik")
	for k in 3:
		Net.players.erase(9981 + k)
		Net.positions.erase(9981 + k)
	Net._broadcast_roster()
	w.camera.zoom = Vector2(1, 1)


func _rail_stop_shot() -> void:
	var Map = preload("res://scripts/map.gd")
	Map.rail_shift = 0.0
	Map.rail_shift = 15.0 - fposmod(Time.get_unix_time_from_system(), Map.RAIL_PERIOD)


func _shots_18(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	var me := 1
	var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
		["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
		["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
	_fake_players(apps)
	for it in ["kilic", "yay", "armor"]:
		Combat.buy(it)
	# --- mağara girişi ve silahçı (dağ)
	Homes._teleport(me, Map.DUNGEON_DOOR + Vector2(90, 90))
	Net.positions[9981] = Map.DUNGEON_DOOR + Vector2(-60, 70)
	Net.positions[9982] = Map.DUNGEON_SHOP + Vector2(10, 40)
	Net.positions[9983] = Map.DUNGEON_DOOR + Vector2(200, 160)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("zindan_giris")
	# --- zindan katı: dört kişilik ekip
	Combat.buy("kilic")
	Homes._teleport(me, Map.DUNGEON_DOOR + Vector2(0, 40))
	await _wait(0.4)
	Dungeon.start_run()
	await _wait(0.6)
	var slot := int(Dungeon.run.slot)
	var zn := "zindan:%d" % slot
	for k in 3:
		Dungeon._runs[slot].members.append(apps[k][0])
	var st: Vector2 = Dungeon.run.start
	Combat.clear_zone(zn)
	var c := st + Vector2(380, 0)
	Homes._teleport(me, c)
	Net.positions[9981] = c + Vector2(-70, -60)
	Net.positions[9982] = c + Vector2(-90, 70)
	Net.positions[9983] = c + Vector2(30, 110)
	for m in [["slime", Vector2(150, -30)], ["bat", Vector2(110, -110)], ["spider", Vector2(200, 80)], ["skeleton", Vector2(260, -10)], ["slime", Vector2(-20, 170)], ["bat", Vector2(240, -150)]]:
		Combat.spawn(zn, m[0], c + m[1])
	await _wait(0.3)
	for k in Combat._mon:
		Combat._mon[k]["hp"] = int(Combat._mon[k].max * 0.6)
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(0.5)
	Combat.attack(Vector2.RIGHT)
	await _wait(0.15)
	await _clear_toasts(w)
	_shot("zindan_kat")
	# --- boss
	Combat.clear_zone(zn)
	Combat.spawn(zn, "dragon", c + Vector2(260, 0), 1.0)
	Combat.spawn(zn, "skeleton", c + Vector2(160, 120))
	Combat.spawn(zn, "skeleton", c + Vector2(180, -120))
	Combat.equip("yay")
	await _wait(0.6)
	for k in Combat._mon:
		if Combat._mon[k].kind == "dragon":
			Combat._mon[k]["hp"] = int(Combat._mon[k].max * 0.45)
	Combat._atk_t.erase(me)
	Combat.attack(Vector2.RIGHT)
	await _wait(0.12)
	await _clear_toasts(w)
	_shot("zindan_boss")
	Combat.clear_zone(zn)
	Dungeon._runs[slot].members = [Net.my_name]
	Combat._hurt_player(me, 99999.0, zn)
	await _wait(0.6)
	# --- zombi gecesi
	Env.hour = 23.0
	Env.force_season("autumn")
	var dp: Vector2 = Zombies.defense_pos()
	Homes._teleport(me, dp + Vector2(10, 120))
	await _wait(0.4)
	Zombies.force_start(5.0)
	await _wait(0.3)
	Combat.clear_zone("zombi")
	Zombies._civ[0] = dp + Vector2(-40, 330)
	Zombies._bar.append({"p": dp + Vector2(-10, 210), "hp": 90.0, "owner": Net.my_name})
	Zombies._bar.append({"p": dp + Vector2(50, 215), "hp": 50.0, "owner": "Kerem"})
	Zombies._broadcast()
	Net.positions[9981] = dp + Vector2(50, 150)
	Net.positions[9982] = dp + Vector2(-50, 90)
	Net.positions[9983] = dp + Vector2(-40, 160)
	for m in [["zombie", Vector2(-20, 290)], ["zombie", Vector2(40, 300)], ["brute", Vector2(10, 380)], ["zombie", Vector2(-50, 420)], ["zombie", Vector2(60, 440)]]:
		Combat.spawn("zombi", m[0], dp + m[1])
	Combat.equip("kilic")
	w.camera.zoom = Vector2(1.05, 1.05)
	await _wait(0.8)
	w.camera.position = dp + Vector2(0, 160)
	await _clear_toasts(w)
	_shot("zombi_gecesi")
	Zombies.force_stop()
	Env.hour = 12.0
	Env.force_season("summer")
	await _wait(0.5)
	# --- uzay üssü
	Homes._teleport(me, Map.SPACE_PAD + Vector2(-160, 120))
	Net.positions[9981] = Map.SPACE_SHOP + Vector2(40, 40)
	Net.positions[9982] = Map.SPACE_PAD + Vector2(-60, 160)
	Net.positions[9983] = Map.SPACE_STRIP + Vector2(-200, -60)
	for it in ["rocket", "suit", "drill"]:
		Space.buy(it)
	w.camera.zoom = Vector2(0.8, 0.8)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("uzay_ussu")
	# --- roket yolculuğu
	Homes._teleport(me, Map.SPACE_PAD + Vector2(0, 50))
	await _wait(0.4)
	Space.launch()
	await _wait(3.4)
	_shot("roket")
	await _wait(4.0)
	# --- Ay
	Net.save_data["moon_base"] = {"bayrak": {"rocks": 10, "he": 0}, "sera": {"rocks": 30, "he": 10}, "rasathane": {"rocks": 22, "he": 5}}
	Space._broadcast_moon()
	var rp: Vector2 = Space.rock_positions()[0]
	var bc: Vector2 = Map.MOON_BASE.get_center()
	Homes._teleport(me, bc + Vector2(-120, -260))
	Net.positions[9981] = bc + Vector2(40, -20)
	Net.positions[9982] = bc + Vector2(-260, -300)
	Net.positions[9983] = bc + Vector2(200, -330)
	w.camera.zoom = Vector2(0.8, 0.8)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("ay_ussu")
	Homes._teleport(me, rp + Vector2(-30, 50))
	Net.positions[9981] = rp + Vector2(90, 40)
	await _wait(0.8)
	Space.mine(0)
	await _wait(0.3)
	await _clear_toasts(w)
	_shot("ay_madeni")
	Homes._teleport(me, Map.MOON_PAD + Vector2(0, -40))
	await _wait(0.4)
	Space.launch()
	await _wait(Space.TRIP_TIME + 1.0)
	# --- fuar: bowling salonu ve mini golf gişesi
	var br: Rect2 = Map.BOWLING.rect
	Homes._teleport(me, Vector2(br.get_center().x + 40, br.end.y + 130))
	Net.positions[9981] = Map.GOLF_BOOTH + Vector2(-40, 50)
	Net.positions[9982] = Vector2(br.get_center().x - 60, br.end.y + 60)
	Net.positions[9983] = Map.GOLF_BOOTH + Vector2(80, 40)
	w.camera.zoom = Vector2(0.9, 0.9)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("bowling_golf_dis")
	# --- mini golf
	Homes._teleport(me, Map.GOLF_BOOTH + Vector2(0, 40))
	await _wait(0.4)
	Golf.enter()
	await _wait(0.6)
	Golf._finish_hole(me, 0, 2, 0.0)
	Golf._finish_hole(me, 1, 3, 0.0)
	await _wait(0.8)
	var g := 2
	var tee: Vector2 = Golf.tee(g)
	Homes._teleport(me, tee + Vector2(-30, 20))
	await _wait(0.6)
	Net.positions[9981] = Golf.tee(3) + Vector2(-40, 30)
	Net.positions[9982] = Golf.tee(5) + Vector2(-40, 30)
	Net.positions[9983] = Golf.tee(1) + Vector2(60, 40)
	w.adv._drag = true
	w.adv._drag_to = tee + Vector2(-90, -60)
	w.camera.position = Golf.hole_origin(g) + Golf.CELL / 2.0
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(0.8)
	await _clear_toasts(w)
	_shot("mini_golf")
	w.adv._drag = false
	Golf.leave()
	await _wait(0.6)
	# --- bowling paneli
	Homes._teleport(me, Vector2(br.get_center().x, br.end.y + 20))
	await _wait(0.5)
	w.zone = {"type": "adv", "do": "b_open"}
	w._open_panel()
	Bowling.start()
	await _wait(0.5)
	for k in 5:
		Bowling._g[me]["busy"] = 0.0
		Bowling.roll(randf_range(-3, 3), 0.3, 0.8)
		await _wait(0.2)
	Bowling._g[me]["busy"] = 0.0
	w.panel.anim = {}
	w.panel.phase = "aim"
	w.panel.press()
	w.panel.press()
	await _wait(1.25)
	_shot("bowling")
	w._close_panel()


func _shots_19(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	var me := 1
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
		["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
		["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
	_fake_players(apps)
	Garage._list(me).append("car")
	Garage.send_state(me)
	Pets.give(me, "dog", "Karabaş")
	await _wait(0.3)
	# --- pazar meydanı: tezgâhlar dolu
	var goods := [["crop", "domates", 18], ["crop", "misir", 30], ["crop", "yun", 50], ["food", "simit", 20]]
	var names := ["Ayşe'nin Bahçesi", "Kerem Market", "Zeynep Şarküteri", "Eren'in Tezgâhı", "Taze Balık", "Organik Köşe"]
	var now := Time.get_unix_time_from_system()
	for i in 6:
		var items: Array = []
		for k in 3:
			var gd: Array = goods[(i + k) % goods.size()]
			items.append({"kind": gd[0], "item": gd[1], "label": Farm.item_info(gd[1]).get("name", "Simit") if gd[0] == "crop" else "Simit", "price": gd[2], "base": gd[2], "qty": 5})
		Stalls._store()[i] = {"owner": (["Ayşe", "Kerem", "Zeynep", Net.my_name, "Ayşe", "Kerem"])[i], "name": names[i], "color": i, "until": now + 86400.0, "items": items, "till": 0, "sold": 3}
	Net.save_data["wanted"] = [{"id": 1, "buyer": "Kerem", "kind": "crop", "key": "misir", "label": "Mısır", "qty": 10, "price": 32},
		{"id": 2, "buyer": "Ayşe", "kind": "food", "key": "simit", "label": "Simit", "qty": 5, "price": 18}]
	Stalls._broadcast()
	var sq: Rect2 = Map.MARKET_SQ
	Homes._teleport(me, Map.stall_front(1) + Vector2(20, 30))
	Net.positions[9981] = Map.stall_front(0) + Vector2(0, 10)
	Net.positions[9982] = Map.stall_front(2) + Vector2(-30, 20)
	Net.positions[9983] = Map.WANTED_BOARD + Vector2(40, 40)
	w.camera.zoom = Vector2(0.95, 0.95)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("pazar_meydani")
	# --- tuning garajı ve drift alanı
	var t: Dictionary = Tuning._data(rec)
	t["engine"] = 3
	t["tires"] = 2
	t["nitro"] = 1
	t["spoiler"] = true
	Garage._style(me)["neon"] = 0
	Garage._style(me)["spoiler"] = true
	Garage._style(me)["car"] = 5
	Garage.send_state(me)
	Tuning.send_state(me)
	Homes._teleport(me, Map.DRIFT.get_center() + Vector2(-120, 30))
	await _wait(0.5)
	Garage.ride("car")
	await _wait(0.5)
	var dc: Vector2 = Map.DRIFT.get_center() + Vector2(-120, 30)
	for k in 40:
		var a := k * 0.16
		w.town.skids.append([dc + Vector2(cos(a) * 140.0, sin(a) * 60.0), Time.get_ticks_msec() / 1000.0])
	w.town.drifting = true
	w.town.drift_pts = 742.0
	Tuning.fire_nitro()
	await _wait(0.2)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(0.3)
	_shot("tuning_drift")
	w.town.drifting = false
	Garage.ride("")
	# --- evcil hayvan parkı: parkur yarışı
	rec.pet["show"] = {"speed": 70, "agility": 65, "charm": 60, "day": Time.get_date_string_from_system(), "trains": 2, "cups": {"gold": 2, "silver": 1, "bronze": 3},
		"acc": ["tac", "papyon"], "wear": {"head": "tac", "neck": "papyon"}}
	Pets._update_roster(me)
	PetShow.send_state(me)
	Homes._teleport(me, Map.PET_BOOTH + Vector2(60, 60))
	await _wait(0.4)
	PetShow.join_race()
	await _wait(0.3)
	PetShow._race_t -= PetShow.RACE_LOBBY
	await _wait(0.3)
	var ds := [620.0, 560.0, 540.0, 470.0]
	var k2 := 0
	for k in PetShow._runners:
		PetShow._runners[k]["d"] = ds[k2]
		k2 += 1
	Net.positions[9981] = PetShow.track_pos(500.0) + Vector2(-40, -80)
	Net.positions[9982] = PetShow.track_pos(640.0) + Vector2(60, -80)
	Net.positions[9983] = PetShow.track_pos(700.0) + Vector2(0, 90)
	Homes._teleport(me, PetShow.track_pos(560.0) + Vector2(-30, 100))
	w.camera.zoom = Vector2(1.1, 1.1)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("parkur_yarisi")
	# --- güzellik şovu sonucu
	Homes._teleport(me, Vector2(Map.PET_STAGE.get_center().x, Map.PET_STAGE.end.y + 30))
	await _wait(0.6)
	PetShow.enter_show()
	await _wait(0.8)
	_shot("guzellik_sovu")
	w._close_panel()
	await _wait(5.0)
	# --- sokak yarışı
	Homes._teleport(me, Map.RACE_FLAG + Vector2(0, 60))
	await _wait(0.5)
	Garage.ride("car")
	await _wait(0.4)
	Street.join()
	await _wait(0.3)
	Street._t -= Street.LOBBY_TIME
	await _wait(0.4)
	Street._t -= Street.COUNTDOWN
	await _wait(1.6)
	Homes._teleport(me, Street.bot_pos(700.0) + Vector2(60, 0))
	w.town.car_vel = Vector2(-600, 0)
	Tuning.fire_nitro()
	await _wait(0.6)
	await _clear_toasts(w)
	_shot("sokak_yarisi")
	Street._finish()
	Garage.ride("")
	await _wait(1.0)
	# --- deprem
	Disasters.start("deprem")
	await _wait(0.4)
	var b0: Dictionary = Map.building(str(Disasters.state.bld[0][0]))
	Disasters._piles[0]["p"] = Vector2(b0.rect.get_center().x - 120, b0.rect.end.y + 60)
	Disasters._people[0]["p"] = Vector2(b0.rect.get_center().x + 110, b0.rect.end.y + 70)
	Disasters._bld[0]["prog"] = 5
	Disasters._broadcast()
	Homes._teleport(me, Vector2(b0.rect.get_center().x, b0.rect.end.y + 90))
	Net.positions[9981] = Vector2(b0.rect.get_center().x - 60, b0.rect.end.y + 70)
	Net.positions[9982] = Vector2(b0.rect.get_center().x + 60, b0.rect.end.y + 110)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(6.0)
	await _clear_toasts(w)
	_shot("deprem")
	Disasters.stop(false)
	await _wait(0.4)
	# --- sel ve yardım çadırı
	Disasters.start("sel")
	await _wait(0.4)
	Disasters._pools[0]["p"] = Map.AID_TENT + Vector2(330, -60)
	Disasters._people[0]["p"] = Map.AID_TENT + Vector2(330, -60)
	Disasters._broadcast()
	Homes._teleport(me, Map.AID_TENT + Vector2(130, 40))
	Net.positions[9981] = Map.AID_TENT + Vector2(-60, 40)
	Net.positions[9982] = Map.AID_TENT + Vector2(260, 30)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("sel_yardim")
	Disasters.stop(false)
	# --- kar fırtınası
	Disasters.start("kar")
	await _wait(0.4)
	Disasters._piles[0]["p"] = Map.SPAWN + Vector2(-120, 0)
	Disasters._piles[1]["p"] = Map.SPAWN + Vector2(180, 10)
	Disasters._people[0]["p"] = Map.SPAWN + Vector2(60, 70)
	Disasters._broadcast()
	Homes._teleport(me, Map.SPAWN + Vector2(-20, 60))
	Net.positions[9981] = Map.SPAWN + Vector2(-140, 50)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("kar_firtinasi")
	Disasters.stop(false)


func _shots_20(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	var me := 1
	var rec: Dictionary = Net.save_data.players[Net.my_name]
	var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
		["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
		["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
	_fake_players(apps)
	for k in ["bilgi", "zenginler", "sohbet", "tuslar", "harita"]:
		w.hud.set_collapsed(k, false)
	# --- mutfak servisi
	var rp := 0
	Land.plots[rp].owner = Net.my_name
	Land.plots[rp]["kind"] = "biz"
	Land.plots[rp].level = 3
	Land.plots[rp]["biz"] = Biz.default_data(Net.my_name)
	Land._broadcast()
	var pr: Rect2 = Map.plot_rect(rp)
	Homes._teleport(me, Vector2(pr.get_center().x, pr.end.y - 10))
	await _wait(0.5)
	var kp = preload("res://scripts/ui/kitchen_panel.gd").new()
	kp.mode = "shift"
	kp.plot = rp
	w.open_panel_node(kp)
	await _wait(0.5)
	Chef._spawn_order(me)
	Chef._spawn_order(me)
	Chef.send_state(me)
	await _wait(0.4)
	kp._press("dogra")
	if kp.prog.has(kp.active) and kp.prog[kp.active].dish != "":
		var steps: Array = preload("res://scripts/chef.gd").dish_info(kp.prog[kp.active].dish).steps
		kp.prog[kp.active]["step"] = 1
		for st in steps.slice(1):
			if st in ["ocak", "firin", "izgara"]:
				kp._press(st)
				break
	await _wait(1.0)
	_shot("mutfak_servisi")
	w._close_panel()
	Chef._shifts.erase(me)
	Land.plots[rp].owner = ""
	Land.plots[rp]["kind"] = "home"
	Land.plots[rp].level = 0
	Land._broadcast()
	# --- akademi ve mahalle muhtarlığı
	var ar: Rect2 = Map.ACADEMY.rect
	Homes._teleport(me, Vector2(ar.get_center().x - 40, ar.end.y + 120))
	Net.positions[9981] = Vector2(ar.get_center().x + 60, ar.end.y + 60)
	Net.positions[9982] = Vector2(Map.MAHALLE_OFFICE.rect.get_center().x, Map.MAHALLE_OFFICE.rect.end.y + 40)
	Net.positions[9983] = Vector2(ar.position.x - 60, ar.end.y + 200)
	w.camera.zoom = Vector2(0.85, 0.85)
	await _wait(1.5)
	await _clear_toasts(w)
	_shot("akademi")
	# --- denizaltı tersanesi
	Homes._teleport(me, Map.SUB_DOCK + Vector2(-60, 60))
	Net.positions[9981] = Map.SUB_DOCK + Vector2(100, 70)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("denizalti_tersanesi")
	# --- Batık Şehir
	Deep._data(rec)["sub"] = true
	Deep._data(rec)["light_lv"] = 2
	Deep._data(rec)["found"] = ["fener", "denizati", "yengec", "vatoz", "nautilus"]
	Deep.send_state(me)
	await _wait(0.3)
	Deep.dive()
	await _wait(0.8)
	var t := Land.server_now()
	var kc := Deep.creature_pos("kalamar", t + 1.0)
	Homes._teleport(me, kc + Vector2(-160, 40))
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("batik_sehir")
	var dm: Dictionary = Deep.DOMES[0]
	Homes._teleport(me, dm.c + Vector2(-80, 140))
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("hava_kubbesi")
	var sp = preload("res://scripts/ui/sub_panel.gd").new()
	sp.mode = "book"
	w.open_panel_node(sp)
	await _wait(0.5)
	_shot("ansiklopedi")
	w._close_panel()
	Deep.surface()
	Homes._teleport(me, Map.DEEP_GATE + Vector2(20, 20))
	await _wait(0.3)
	Deep.surface()
	await _wait(0.8)
	# --- belediye projeleri: hepsi yapılmış şehir
	for k in Projects.PROJECTS:
		Projects._data().done[k] = {"by": "Kerem" if k != "heykel" else Net.my_name, "at": 0, "look": rec.get("appearance", {"skin": 1, "hair": 2})}
	Projects._broadcast()
	Homes._teleport(me, Map.PROJECT_SITES.heykel + Vector2(-120, 60))
	Net.positions[9981] = Map.PROJECT_SITES.heykel + Vector2(60, 70)
	Net.positions[9982] = Map.PROJECT_SITES.cicek + Vector2(40, 30)
	Net.positions[9983] = Map.PROJECT_SITES.cicek + Vector2(-140, 20)
	w.camera.zoom = Vector2(0.8, 0.8)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("projeler_park")
	Env.hour = 22.0
	Zombies.force_stop()
	Zombies._skipped_night = Zombies._night_key()
	Homes._teleport(me, Vector2(860, 1030))
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("fiskiye_gece")
	Env.hour = 12.0
	Election._data()["mayor"] = Net.my_name
	Election._data()["treasury"] = 8400
	Projects._data().done.erase("kule")
	Projects._data()["cur"] = {"k": "kule", "phase": "butce", "ends": Time.get_unix_time_from_system() + 3600.0, "yes": 6, "no": 1, "voters": [], "funds": 16500,
		"donors": {"Ayşe": 4000, "Kerem": 2500, Net.my_name: 1500}, "by": Net.my_name}
	Projects._broadcast()
	Homes._teleport(me, Map.PROJECT_BOARD + Vector2(0, 40))
	await _wait(0.5)
	w.zone = {"type": "v20", "do": "projects"}
	w._open_panel()
	await _wait(0.6)
	_shot("projeler_paneli")
	w._close_panel()
	# --- festival
	Festival.force(5.0)
	await _wait(1.0)
	Festival.buy_ticket()
	var df: Rect2 = Map.DANCE_FLOOR
	Homes._teleport(me, df.get_center() + Vector2(-60, 10))
	Net.positions[9981] = df.get_center() + Vector2(40, -10)
	Net.positions[9982] = df.get_center() + Vector2(120, 20)
	Net.positions[9983] = Map.DJ_BOOTH + Vector2(-90, 20)
	Festival._hype = 78.0
	w.camera.zoom = Vector2(0.95, 0.95)
	await _wait(2.5)
	var fp = preload("res://scripts/ui/festival_panel.gd").new()
	fp.mode = "dance"
	w.open_panel_node(fp)
	await _wait(1.0)
	_shot("festival_dans")
	w._close_panel()
	Env.hour = 22.5
	w.v20._on_fireworks({"big": true})
	await _wait(1.4)
	await _clear_toasts(w)
	_shot("festival_havai_fisek")
	Festival.force_stop()
	Env.hour = 12.0


func _shots_21(w) -> void:
	var Map = preload("res://scripts/map.gd")
	Env._sync = -1000000.0
	Env.force_weather("clear")
	Env.force_season("summer")
	Holidays.force("yok")
	Tutorial.finish()
	Env.hour = 12.0
	Zombies.natural = false
	Festival.natural = false
	var me := 1
	var apps := [["Ayşe", {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1}],
		["Kerem", {"skin": 3, "hair": 3, "hair_color": 0, "shirt": 6, "pants": 0}],
		["Zeynep", {"skin": 0, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4}]]
	_fake_players(apps)
	Garage._list(me).append("car")
	Garage._style(me)["car"] = 5
	Garage.send_state(me)
	await _wait(0.3)
	# --- şehirde otoyol rampası ve otogar
	Homes._teleport(me, Map.TOWN_RAMPS.sehir + Vector2(140, 0))
	await _wait(0.4)
	Garage.ride("car")
	Net.positions[9981] = Map.OTOGARS.sehir + Vector2(-40, 50)
	Net.positions[9982] = Map.OTOGARS.sehir + Vector2(60, 60)
	Net.positions[9983] = Map.TOWN_RAMPS.sehir + Vector2(260, 90)
	w.camera.zoom = Vector2(1.0, 1.0)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("sehir_otoyol_girisi")
	# --- otoyol
	Roads.enter_highway()
	await _wait(0.6)
	Homes._teleport(me, Vector2(58200, Map.HWY_ROAD.position.y + 60))
	Players_on_highway(Map)
	w.camera.zoom = Vector2(0.75, 0.75)
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("otoyol_sahil")
	Homes._teleport(me, Vector2(66500, Map.HWY_ROAD.position.y + 60))
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("otoyol_dag")
	Homes._teleport(me, Map.HWY_REST.get_center() + Vector2(-200, -150))
	await _wait(1.0)
	await _clear_toasts(w)
	_shot("dinlenme_tesisi")
	# --- Yalıkent
	Homes._teleport(me, Vector2(Map.HWY_RAMPS.yalikent, Map.HWY_ROAD.position.y + 60))
	await _wait(0.5)
	Roads.exit_highway("yalikent")
	await _wait(0.6)
	Homes._teleport(me, Vector2(51745, 2300))
	Net.positions[9981] = Vector2(51650, 2930)
	Net.positions[9982] = Vector2(52430, 3150)
	Net.positions[9983] = Vector2(51900, 1560)
	Land.plots[12].owner = "Ayşe"
	Land.plots[12].level = 2
	Land.plots[13].owner = "Kerem"
	Land.plots[13].level = 1
	Land._broadcast()
	w.camera.zoom = Vector2(0.7, 0.7)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("yalikent")
	Homes._teleport(me, Vector2(51000, 1350))
	w.camera.zoom = Vector2(0.75, 0.75)
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("yalikent_carsi")
	# --- Çamlıbel
	Garage.ride("")
	await _wait(0.3)
	Homes._teleport(me, Map.OTOGARS.camlibel + Vector2(-200, 60))
	Net.positions[9981] = Map.OTOGARS.camlibel + Vector2(-80, 40)
	Net.positions[9982] = Vector2(56200, 1720)
	Net.positions[9983] = Vector2(56500, 1700)
	Land.plots[16].owner = "Zeynep"
	Land.plots[16].level = 3
	Land._broadcast()
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("camlibel")
	Homes._teleport(me, Vector2(57500, 3120))
	await _wait(1.2)
	await _clear_toasts(w)
	_shot("camlibel_kaplica")
	# --- otobüs yolculuğu
	Homes._teleport(me, Map.OTOGARS.camlibel + Vector2(0, 20))
	await _wait(0.4)
	Roads.take_bus("yalikent")
	await _wait(3.0)
	_shot("sehirlerarasi_otobus")
	await _wait(6.0)


func Players_on_highway(Map) -> void:
	Net.positions[9981] = Vector2(58500, Map.HWY_ROAD.position.y + 180)
	Net.positions[9982] = Vector2(57700, Map.HWY_ROAD.position.y + 90)
	Net.positions[9983] = Vector2(58800, Map.HWY_ROAD.position.y + 30)
	for k in [9981, 9982, 9983]:
		Net.players[k]["ride"] = "car"
	Net._broadcast_roster()


func _shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("user://foto_%s.png" % n))


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout



class AvatarSheet extends Control:
	func _draw() -> void:
		var Avatar = preload("res://scripts/avatar.gd")
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7fb069"))
		var apps := [{"skin": 0, "hair": 0, "hair_color": 0, "shirt": 1, "pants": 0}, {"skin": 1, "hair": 1, "hair_color": 4, "shirt": 9, "pants": 1},
			{"skin": 3, "hair": 3, "hair_color": 1, "shirt": 6, "pants": 2}, {"skin": 2, "hair": 2, "hair_color": 5, "shirt": 2, "pants": 4},
			{"skin": 4, "hair": 4, "hair_color": 2, "shirt": 4, "pants": 3, "glasses": 1, "hat": 1}]
		for i in apps.size():
			for j in 3:
				var f: String = ["down", "right", "up"][j]
				Avatar.draw(self, Vector2(130 + i * 240, 200 + j * 220), apps[i], f, 0, 3.2)



func _touch(idx: int, p: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = p
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(idx: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = p
	Input.parse_input_event(ev)
