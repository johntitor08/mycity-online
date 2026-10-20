extends Node
## Ağ katmanı: sunucu/istemci bağlantısı, oyuncu listesi, para, sohbet ve kayıt dosyası.
##
## Sunucu yetkilidir: istemciler yalnızca "req_*" istekleri gönderir, sonuçları
## (para, kart, balık, kazanç...) her zaman sunucu belirler. Böylece hile yapılamaz.
## Sunucuyu kuran oyuncu (peer 1) aynı zamanda oynayabilir; bu durumda istekler
## ağ yerine doğrudan çağrılır (bkz. ask / tell).

signal connected_ok
signal connection_failed(reason: String)
signal disconnected(reason: String)
signal roster_changed
signal chat_received(from_name: String, text: String, color: Color)
signal toast(text: String, good: bool)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")

const VERSION := "0.3"
const DEFAULT_PORT := 7777
const MAX_CLIENTS := 32
const START_MONEY := 2500
const DEFAULT_SAVE_PATH := "user://mycity_kayit.json"

# --- sunucu tarafı (yetkili veri) ---
var players := {}     # peer_id -> {name, money, color}
var positions := {}   # peer_id -> Vector2
var save_data := {"players": {}, "plots": []}
var dedicated := false
var save_path := DEFAULT_SAVE_PATH

# --- herkes (sunucudan gelen kopya) ---
var roster := {}      # peer_id -> {name, money, color}
var pos_view := {}    # peer_id -> Vector2
var my_name := ""
var spawn_pos := Map.SPAWN
var my_appearance := {}

var _pending := {}
var _sync_accum := 0.0
var _save_accum := 0.0
var _send_accum := 0.0
var _dirty := false
var _stop_accum := 0.0


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)


# ------------------------------------------------------------------ yardımcılar

func is_online() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and not (p is OfflineMultiplayerPeer) \
		and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_server() -> bool:
	return is_online() and multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


## İsteği gönderen oyuncunun kimliği (yerel çağrıda sunucunun kendisi).
func sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else multiplayer.get_unique_id()


## İstemci -> sunucu isteği.
func ask(node: Node, method: StringName, d: Dictionary = {}) -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		node.call(method, d)
	else:
		node.rpc_id(1, method, d)


## Sunucu -> tek oyuncu.
func tell(node: Node, peer: int, method: StringName, d: Dictionary = {}) -> void:
	if peer <= 0:
		return
	if peer == multiplayer.get_unique_id():
		node.call(method, d)
	elif peer in multiplayer.get_peers():
		node.rpc_id(peer, method, d)


## Sunucu -> herkes (alıcı fonksiyonlar "call_local" olduğu için sunucuda da çalışır).
func tell_all(node: Node, method: StringName, d: Dictionary = {}) -> void:
	node.rpc(method, d)


func notify(id: int, text: String, good: bool = true) -> void:
	tell(self, id, "on_toast", {"text": text, "good": good})


func announce(text: String) -> void:
	tell_all(self, "on_chat", {"name": "Duyuru", "text": text, "color": Color(1, 0.82, 0.3)})


func id_by_name(player_name: String) -> int:
	for id in players:
		if players[id].name == player_name:
			return id
	return 0


## Adanmış sunucuda zaman damgalı log (systemd/journalctl'de görünür).
func log_line(text: String) -> void:
	if dedicated:
		print("[%s] %s" % [Time.get_datetime_string_from_system(false, true), text])


func mark_dirty() -> void:
	_dirty = true


# ------------------------------------------------------------------ bağlantı

## Şifre hiçbir zaman düz metin olarak gönderilmez/saklanmaz: istemci önce isimle birlikte
## özetler (hash), sunucu bu özeti ayrıca tuzlayıp bir kez daha özetleyerek saklar.
static func hash_password(player_name: String, password: String) -> String:
	return ("mycity:%s:%s" % [player_name.strip_edges().to_lower(), password]).sha256_text()


func host(player_name: String, port: int, as_dedicated: bool = false, pass_hash: String = "",
		appearance = null) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return "Sunucu açılamadı. Port %d kullanımda olabilir (başka bir sunucu açık mı?) (hata %d)." % [port, err]
	multiplayer.multiplayer_peer = peer
	dedicated = as_dedicated
	_load()
	Land.server_init()
	if dedicated:
		# Ekransız sunucu sınırsız kare hızında dönüp bir çekirdeği %100 kullanmasın.
		Engine.max_fps = 30
		log_line("MyCity Online %s, %d portunda çalışıyor. Kayıt: %s" % [VERSION, port, ProjectSettings.globalize_path(save_path)])
	else:
		var reason := _register(1, player_name, pass_hash, appearance)
		if reason != "":
			_reset_peer()
			return reason
	return ""


func join(player_name: String, address: String, port: int, pass_hash: String = "", appearance = null) -> String:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Bağlantı başlatılamadı (hata %d)." % err
	multiplayer.multiplayer_peer = peer
	_pending = {"name": player_name, "pass": pass_hash, "version": VERSION}
	if appearance is Dictionary:
		_pending["appearance"] = appearance
	return ""


func leave() -> void:
	if is_server():
		_save()
	_reset_peer()
	disconnected.emit("")


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	positions.clear()
	roster.clear()
	pos_view.clear()
	my_name = ""
	dedicated = false
	Land.reset()
	Poker.reset()
	Jobs.reset()
	Rpg.reset()


func _on_connected() -> void:
	rpc_id(1, "req_register", _pending)


func _on_failed() -> void:
	_reset_peer()
	connection_failed.emit("Sunucuya bağlanılamadı. Adres/port doğru mu, sunucu açık mı?")


func _on_server_gone() -> void:
	_reset_peer()
	disconnected.emit("Sunucu bağlantısı koptu.")


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var pname: String = players[id].name
	# Önce oyunlardan çıkar (masadaki fişler paraya dönsün), sonra sil.
	Poker.on_player_left(id)
	Jobs.on_player_left(id)
	players.erase(id)
	positions.erase(id)
	_save()
	_broadcast_roster()
	announce("%s şehirden ayrıldı." % pname)
	log_line("%s çıktı (%d oyuncu çevrimiçi)" % [pname, players.size()])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_server():
		_save()


## systemd durdururken kayıt klasörüne "kapat" dosyası bırakır: kaydet ve düzgünce çık.
## (Godot SIGTERM'de kayıt yapmadan kapandığı için bu yol kullanılıyor.)
func _check_stop_request() -> void:
	var stop_file := save_path.get_base_dir().path_join("kapat")
	if not FileAccess.file_exists(stop_file):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stop_file))
	announce("Sunucu bakım için yeniden başlıyor, birkaç saniye sonra tekrar bağlan.")
	_save()
	log_line("Kapatma isteği alındı, kayıt yazıldı. Çıkılıyor.")
	await get_tree().create_timer(0.5).timeout    # duyuru oyunculara ulaşsın
	get_tree().quit()


func _exit_tree() -> void:
	if is_server():
		_save()
		log_line("Sunucu kapanıyor, kayıt yazıldı.")


# ------------------------------------------------------------------ kayıt olma

@rpc("any_peer", "call_remote", "reliable")
func req_register(d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	if str(d.get("version", "")) != VERSION:
		_kick(id, "Sürüm uyuşmuyor (sunucu %s). Oyunu güncelle." % VERSION)
		return
	var reason := _register(id, str(d.get("name", "")), str(d.get("pass", "")), d.get("appearance"))
	if reason != "":
		log_line("Giriş reddedildi (%s): %s" % [str(d.get("name", "")).left(16), reason])
		await get_tree().create_timer(1.0).timeout    # şifre denemelerini yavaşlat
		_kick(id, reason)


func _kick(id: int, reason: String) -> void:
	if not id in multiplayer.get_peers():
		return
	rpc_id(id, "kicked", {"reason": reason})
	get_tree().create_timer(0.5).timeout.connect(func():
		if id in multiplayer.get_peers():
			multiplayer.multiplayer_peer.disconnect_peer(id)
	)


## Hesap adını büyük/küçük harf duyarsız bulur (kayıttaki yazılışı döner).
func _account_key(player_name: String) -> String:
	var low := player_name.to_lower()
	for k in save_data.players:
		if str(k).to_lower() == low:
			return k
	return player_name


## Başarılıysa "" döner, değilse ret sebebi.
func _register(id: int, raw_name: String, pass_hash: String, appearance) -> String:
	var pname := raw_name.strip_edges().replace("[", "").replace("]", "").left(16)
	if pname.length() < 2 or pname.to_lower() == "duyuru":
		return "Geçersiz oyuncu adı."
	if pass_hash.length() != 64:
		return "Şifre gerekli."
	pname = _account_key(pname)
	if id_by_name(pname) != 0:
		return "Bu hesap şu anda oyunda."
	var is_new: bool = not save_data.players.has(pname)
	if is_new:
		save_data.players[pname] = {"money": START_MONEY, "fish": []}
	var rec: Dictionary = save_data.players[pname]
	if not rec.has("pass"):
		# Yeni hesap (ya da şifresiz eski kayıt): bu şifre hesaba bağlanır.
		var salt := "%08x%08x" % [randi(), randi()]
		rec["pass"] = {"salt": salt, "hash": (salt + pass_hash).sha256_text()}
	elif (str(rec["pass"]["salt"]) + pass_hash).sha256_text() != str(rec["pass"]["hash"]):
		return "Şifre yanlış."
	if not rec.has("fish"):
		rec["fish"] = []
	if appearance is Dictionary:
		rec["appearance"] = Avatar.sanitize(appearance)
	elif not rec.has("appearance"):
		rec["appearance"] = Avatar.default_for(pname)
	var app := Avatar.sanitize(rec["appearance"])
	players[id] = {"name": pname, "money": int(rec.get("money", START_MONEY)),
		"color": Avatar.shirt_color(app), "appearance": app, "level": Rpg.level_of_rec(rec)}
	positions[id] = Map.SPAWN + Vector2(randf_range(-120, 120), randf_range(-30, 30))
	_dirty = true
	tell(self, id, "welcome", {"name": pname, "pos": positions[id], "appearance": app, "new": is_new})
	_broadcast_roster()
	Land.send_state(id)
	Poker.send_state(id)
	Jobs.send_inventory(id)
	Rpg.send_sheet(id)
	announce(("%s şehre taşındı. Hoş geldin!" if is_new else "%s şehre geldi.") % pname)
	log_line("%s %s (%d oyuncu çevrimiçi)" % [pname, "yeni hesap açtı" if is_new else "girdi", players.size()])
	return ""


## Oyun içinde karakter görünümünü değiştir.
func set_appearance(app: Dictionary) -> void:
	ask(self, "req_appearance", {"appearance": app})


@rpc("any_peer", "call_remote", "reliable")
func req_appearance(d: Dictionary) -> void:
	var id := sender()
	if not players.has(id):
		return
	var app := Avatar.sanitize(d.get("appearance"))
	players[id]["appearance"] = app
	players[id]["color"] = Avatar.shirt_color(app)
	save_data.players[players[id].name]["appearance"] = app
	_dirty = true
	_broadcast_roster()


@rpc("authority", "call_remote", "reliable")
func welcome(d: Dictionary) -> void:
	my_name = d.name
	my_appearance = d.appearance
	spawn_pos = d.pos
	connected_ok.emit()


@rpc("authority", "call_remote", "reliable")
func kicked(d: Dictionary) -> void:
	_reset_peer()
	connection_failed.emit(str(d.get("reason", "Sunucu bağlantıyı reddetti.")))


# ------------------------------------------------------------------ para

func get_money(id: int) -> int:
	return int(players[id].money) if players.has(id) else 0


func try_spend(id: int, amount: int) -> bool:
	if amount < 0 or not players.has(id) or int(players[id].money) < amount:
		return false
	players[id].money = int(players[id].money) - amount
	_money_changed(id)
	return true


func add_money(id: int, amount: int) -> void:
	if not players.has(id):
		return
	players[id].money = maxi(0, int(players[id].money) + amount)
	_money_changed(id)


## Oyuncu çevrimdışıysa bile (ör. kira geliri) kayıt dosyasına işler.
func add_money_by_name(player_name: String, amount: int) -> void:
	var id := id_by_name(player_name)
	if id != 0:
		add_money(id, amount)
	elif save_data.players.has(player_name):
		var rec: Dictionary = save_data.players[player_name]
		rec["money"] = maxi(0, int(rec.get("money", 0)) + amount)
		_dirty = true


func _money_changed(id: int) -> void:
	save_data.players[players[id].name]["money"] = players[id].money
	_dirty = true
	_broadcast_roster()


func _broadcast_roster() -> void:
	tell_all(self, "on_roster", {"players": players})


@rpc("authority", "call_local", "reliable")
func on_roster(d: Dictionary) -> void:
	roster = d.players.duplicate(true)
	roster_changed.emit()


func my_money() -> int:
	var me = roster.get(my_id())
	return int(me.money) if me else 0


# ------------------------------------------------------------------ hareket

## Dünya sahnesi her karede yerel oyuncunun konumunu buraya verir.
func update_my_pos(p: Vector2, delta: float) -> void:
	if not is_online():
		return
	if multiplayer.is_server():
		positions[my_id()] = p
		return
	_send_accum += delta
	if _send_accum >= 0.066:
		_send_accum = 0.0
		rpc_id(1, "send_pos", p)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_pos(p: Vector2) -> void:
	var id := sender()
	if players.has(id):
		positions[id] = p.clamp(Map.WORLD.position, Map.WORLD.end)


@rpc("authority", "call_local", "unreliable_ordered")
func sync_positions(p: Dictionary) -> void:
	pos_view = p


func _process(delta: float) -> void:
	if not is_server():
		return
	_sync_accum += delta
	if _sync_accum >= 0.1:
		_sync_accum = 0.0
		if not positions.is_empty():
			rpc("sync_positions", positions.duplicate())
	_save_accum += delta
	if dedicated:
		_stop_accum += delta
		if _stop_accum >= 1.0:
			_stop_accum = 0.0
			_check_stop_request()
	if _save_accum >= (2.0 if dedicated else 5.0):
		_save_accum = 0.0
		if _dirty:
			_save()


# ------------------------------------------------------------------ sohbet

func send_chat(text: String) -> void:
	ask(self, "req_chat", {"text": text})


@rpc("any_peer", "call_remote", "reliable")
func req_chat(d: Dictionary) -> void:
	var id := sender()
	if not players.has(id):
		return
	var text := str(d.get("text", "")).strip_edges().left(200)
	if text == "":
		return
	tell_all(self, "on_chat", {"name": players[id].name, "text": text, "color": players[id].color})


@rpc("authority", "call_local", "reliable")
func on_chat(d: Dictionary) -> void:
	chat_received.emit(d.name, d.text, d.color)


@rpc("authority", "call_local", "reliable")
func on_toast(d: Dictionary) -> void:
	toast.emit(d.text, d.good)


# ------------------------------------------------------------------ kayıt dosyası

func _save() -> void:
	save_data["plots"] = Land.plots
	# Önce geçici dosyaya yaz, sonra yerine taşı: yazarken kapanırsa kayıt bozulmaz.
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		log_line("UYARI: kayıt yazılamadı: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(save_data, "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(save_path))
	if err == OK:
		_dirty = false
	else:
		log_line("UYARI: kayıt taşınamadı: %s" % error_string(err))


func _load() -> void:
	save_data = {"players": {}, "plots": []}
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		if parsed.get("players") is Dictionary:
			save_data["players"] = parsed["players"]
		if parsed.get("plots") is Array:
			save_data["plots"] = parsed["plots"]
