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
	get_tree().quit()


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
