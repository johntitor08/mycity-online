extends Node
## Ticaret testleri için ikinci oyuncu ("Yardimci"). Ev sahibi testine (127.0.0.1:7791) bağlanır,
## markette simit alıp pazarda 25 TL'ye ilana koyar, sonra bekler.
## Kullanım: godot --headless --path . -- --test-yardimci

const Map = preload("res://scripts/map.gd")
var _tries := 0


func _ready() -> void:
	Net.connected_ok.connect(_on_ok)
	Net.connection_failed.connect(_retry)
	Net.disconnected.connect(func(_r): get_tree().quit(0))
	_join()
	get_tree().create_timer(900.0).timeout.connect(func(): get_tree().quit(0))


func _join() -> void:
	Net.join("Yardimci", "127.0.0.1", 7791, Net.hash_password("Yardimci", "yardim123"))


func _retry(_reason: String) -> void:
	_tries += 1
	if _tries > 90:
		get_tree().quit(1)
		return
	await get_tree().create_timer(1.0).timeout
	_join()


func _on_ok() -> void:
	print("[yardımcı] bağlandı")
	var w = get_parent().world
	w.my_pos = Map.building("market").rect.get_center()
	await get_tree().create_timer(0.6).timeout
	Rpg.buy("simit")
	await get_tree().create_timer(0.6).timeout
	w.my_pos = Map.building("pazar").rect.get_center()
	await get_tree().create_timer(0.6).timeout
	Bazaar.list_item("food", "simit", 25)
	print("[yardımcı] simit ilana kondu")
