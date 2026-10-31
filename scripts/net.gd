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
signal chat_received(from_name: String, text: String, color: Color, channel: String)
signal toast(text: String, good: bool)
signal probe_done(info: Dictionary)      # 2.2: sunucu listesi sondası bitti ({"ok": false} = yanıt yok)

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")
const Avatar = preload("res://scripts/avatar.gd")

const VERSION := "2.3"
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
var _backup_accum := 0.0
var _status_accum := 0.0
var _started_at := 0.0
var _last_save_at := 0.0
var admins_arg: Array = []          # --yonetici=ad,ad
var speed_check := true             # --hizsiz: testlerde kapatılır (testler oyuncuyu ışınlar)
var _muted := {}                    # ad -> bitiş (unix)
var _pos_t := {}                    # id -> son konum zamanı (hız denetimi)
var _strikes := {}                  # id -> art arda reddedilen konum sayısı
var _status_server: TCPServer
const BACKUP_EVERY := 6 * 3600.0
const BACKUP_KEEP := 14
var status_port := 7780             # oyun portu + 3

# --- 2.2: sunucu listesi ---
const DISCOVERY_PORT := 7779        # yerel ağ duyurusu (UDP yayın)
const PROBE_TIMEOUT_MS := 5000
var server_name := ""               # --ad="..." (boşsa varsayılan)
var server_desc := ""               # --aciklama="..."
var _probe_t0 := 0                  # >0: menüde bir sunucu yoklanıyor (msec)
var _probe_sent := 0
var _lan_udp: PacketPeerUDP
var _lan_accum := 0.0
var _game_port := 0


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
	Phone.add_news(text)


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
	cancel_probe()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		return "Sunucu açılamadı. Port %d kullanımda olabilir (başka bir sunucu açık mı?) (hata %d)." % [port, err]
	_tune(peer)
	dedicated = as_dedicated
	_game_port = port
	# 1.5.1: adanmış sunucu tarayıcı oyuncuları için WebSocket da dinler (varsayılan port+1, TCP).
	var ws_port := _ws_port_arg(port if as_dedicated else 0)
	if ws_port > 0:
		var ws := WebSocketMultiplayerPeer.new()
		_tune_ws(ws)
		var tls := _tls_from_args()
		var werr := ws.create_server(ws_port, "*", tls)
		if werr == OK:
			var dual = preload("res://scripts/dual_peer.gd").new()
			dual.setup(peer, ws)
			multiplayer.multiplayer_peer = dual
			log_line("Tarayıcı oyuncuları için WebSocket%s: %d (TCP)" % [" (TLS)" if tls != null else "", ws_port])
		else:
			log_line("UYARI: WebSocket portu %d açılamadı (hata %d), sadece UDP" % [ws_port, werr])
			multiplayer.multiplayer_peer = peer
	else:
		multiplayer.multiplayer_peer = peer
	dedicated = as_dedicated
	_load()
	_started_at = Time.get_unix_time_from_system()
	for a in admins_arg:
		if not admins().has(a):
			admins().append(a)
	if not as_dedicated and player_name.strip_edges() != "" and not admins().has(_account_key(player_name.strip_edges())):
		admins().append(_account_key(player_name.strip_edges()))      # sunucuyu kuran yöneticidir
	_backup("acilis")
	Land.server_init()
	Env.server_start()
	Events.server_start()
	if dedicated:
		# Ekransız sunucu sınırsız kare hızında dönüp bir çekirdeği %100 kullanmasın.
		Engine.max_fps = 30
		log_line("MyCity Online %s, %d portunda çalışıyor. Kayıt: %s" % [VERSION, port, ProjectSettings.globalize_path(save_path)])
		status_port = port + 3
		_start_status_page()
	else:
		var reason := _register(1, player_name, pass_hash, appearance)
		if reason != "":
			_reset_peer()
			return reason
	return ""


func join(player_name: String, address: String, port: int, pass_hash: String = "", appearance = null) -> String:
	cancel_probe()
	var err := _open_client(address, port)
	if err != "":
		return err
	_pending = {"name": player_name, "pass": pass_hash, "version": VERSION}
	if appearance is Dictionary:
		_pending["appearance"] = appearance
	return ""


## 2.2: menüdeki sunucu listesi için: bağlan, adını/oyuncu sayısını/sürümünü sor, kop. Sonuç probe_done ile gelir.
func probe(address: String, port: int) -> bool:
	if is_online() or _probe_t0 > 0:
		return false
	if _open_client(address, port) != "":
		return false
	_probe_t0 = Time.get_ticks_msec()
	_probe_sent = 0
	return true


func cancel_probe() -> void:
	if _probe_t0 > 0:
		_probe_t0 = 0
		_reset_peer()


func _probe_finish(info: Dictionary) -> void:
	_probe_t0 = 0
	_reset_peer()
	probe_done.emit(info)


func _open_client(address: String, port: int) -> String:
	# Alan adlarında IPv4'ü tercih et: Godot ilk bulduğu adresi (çoğu zaman IPv6) kullanır,
	# IPv6'sı olmayan ağlarda bağlantı takılır.
	# Tarayıcıda (ya da ws:// / wss:// adresinde) WebSocket ile bağlan
	if OS.has_feature("web") or address.begins_with("ws://") or address.begins_with("wss://"):
		var url := address
		if not url.begins_with("ws"):
			url = "%s://%s:%d" % ["wss" if OS.has_feature("web") else "ws", address, port]
		var wpeer := WebSocketMultiplayerPeer.new()
		_tune_ws(wpeer)
		var werr := wpeer.create_client(url)
		if werr != OK:
			return "Bağlantı başlatılamadı (hata %d)." % werr
		multiplayer.multiplayer_peer = wpeer
		return ""
	if not address.is_valid_ip_address():
		var v4 := IP.resolve_hostname(address, IP.TYPE_IPV4)
		if v4 != "":
			address = v4
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return "Bağlantı başlatılamadı (hata %d)." % err
	_tune(peer)
	multiplayer.multiplayer_peer = peer
	return ""


## Paketleri sıkıştır: VPN/tünel yollarında (MTU ~1280) büyük paketler kaybolup bağlantı kopuyordu.
## Sunucu ve istemci aynı ayarı kullanmalı (sürüm kontrolü bunu garanti eder).
func _tune(peer: ENetMultiplayerPeer) -> void:
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)


## WebSocket arabellekleri: arsa/oyuncu listesi gibi büyük paketler sığsın.
func _tune_ws(peer: WebSocketMultiplayerPeer) -> void:
	peer.inbound_buffer_size = 1 << 22
	peer.outbound_buffer_size = 1 << 22
	peer.max_queued_packets = 8192


## --ws-port=N (0: kapalı). Verilmezse adanmış sunucuda oyun portu + 1.
func _ws_port_arg(game_port: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ws-port="):
			return int(a.trim_prefix("--ws-port="))
	return game_port + 1 if game_port > 0 else 0


## --tls-cert=yol --tls-key=yol verilirse WebSocket doğrudan wss olarak açılır (ters vekil yoksa).
func _tls_from_args() -> TLSOptions:
	var cert_path := ""
	var key_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tls-cert="):
			cert_path = a.trim_prefix("--tls-cert=")
		elif a.begins_with("--tls-key="):
			key_path = a.trim_prefix("--tls-key=")
	if cert_path == "" or key_path == "":
		return null
	var cert := X509Certificate.new()
	var key := CryptoKey.new()
	if cert.load(cert_path) != OK or key.load(key_path) != OK:
		log_line("UYARI: TLS sertifikası yüklenemedi, WebSocket şifresiz açılıyor")
		return null
	return TLSOptions.server(key, cert)


func leave() -> void:
	if is_server():
		_save()
	_reset_peer()
	disconnected.emit("")


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_game_port = 0
	if _lan_udp:
		_lan_udp.close()
		_lan_udp = null
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
	Env.reset()
	Garage.reset()
	Homes.reset()
	Bazaar.reset()
	Pets.reset()
	Story.reset()
	Farm.reset()
	Clans.reset()
	Events.reset()
	Police.reset()
	Shops.reset()
	Bank.reset()
	Election.reset()
	Family.reset()
	Ach.reset()
	Football.reset()
	Langirt.reset()
	Seasonal.reset()
	Work.reset()
	League.reset()
	Factory.reset()
	Dive.reset()
	Mountain.reset()
	Museum.reset()
	Band.reset()
	Phone.reset()
	Trade.reset()
	Horses.reset()
	Camp.reset()
	Fair.reset()
	Airport.reset()
	Detective.reset()
	School.reset()
	Holidays.reset()
	Gym.reset()
	Pirates.reset()
	Zoo.reset()
	Ocean.reset()
	Rail.reset()
	Cinema.reset()
	Isles.reset()
	Cargo.reset()
	Paint.reset()
	Combat.reset()
	Dungeon.reset()
	Zombies.reset()
	Space.reset()
	Golf.reset()
	Bowling.reset()
	Tuning.reset()
	Street.reset()
	PetShow.reset()
	Stalls.reset()
	Disasters.reset()
	Chef.reset()
	Deep.reset()
	Projects.reset()
	Festival.reset()
	Roads.reset()


func _on_connected() -> void:
	if _probe_t0 > 0:
		_probe_sent = Time.get_ticks_msec()
		rpc_id(1, "req_info", {})
		return
	rpc_id(1, "req_register", _pending)


func _on_failed() -> void:
	if _probe_t0 > 0:
		_probe_finish({"ok": false})
		return
	_reset_peer()
	connection_failed.emit("Sunucuya bağlanılamadı. Adres/port doğru mu, sunucu açık mı? Oyunun güncel mi? (itch.io)")


func _on_server_gone() -> void:
	if _probe_t0 > 0:
		_probe_finish({"ok": false})
		return
	_reset_peer()
	disconnected.emit("Sunucu bağlantısı koptu.")


# ------------------------------------------------------------------ yönetim

func admins() -> Array:
	if not save_data.get("admins") is Array:
		save_data["admins"] = []
	return save_data["admins"]


func is_admin(id: int) -> bool:
	return players.has(id) and admins().has(players[id].name)


const HELP := "Komutlar: /duyuru metin · /kick isim · /sustur isim dakika · /hava açık|bulutlu|yağmur|fırtına|sis|gökkuşağı · /etkinlik tür · /kaydet · /yedekle · /oyuncular · /yonetici isim · /ozelgun cadilar|yilbasi|ramazan|kurban|sevgililer|yok|takvim · /zombi başlat|bitir · /afet deprem|sel|kar|bitir · /festival [bitir]"


## Yönetici komutları (sohbetten "/" ile).
func _command(id: int, text: String) -> void:
	var parts := text.substr(1).strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	var arg := " ".join(parts.slice(1))
	if cmd in ["oyuncular", "yardim", "yardım"]:
		var names: Array = []
		for pid in players:
			names.append("%s (Sv.%d)" % [players[pid].name, int(players[pid].get("level", 1))])
		notify(id, ("Çevrimiçi: " + ", ".join(names)) if cmd == "oyuncular" else (HELP if is_admin(id) else "Sohbet: /k klan, /y yakın, /m isim mesaj, /takas isim"))
		return
	if cmd == "takas":
		Trade.invite_from(id, arg)
		return
	if not is_admin(id):
		notify(id, "Bu komut sadece yöneticiler için.", false)
		return
	var who := _account_key(parts[1]) if parts.size() > 1 else ""
	var wid := id_by_name(who)
	match cmd:
		"ozelgun":
			var k := parts[1] if parts.size() > 1 else "takvim"
			if not k in ["cadilar", "yilbasi", "ramazan", "kurban", "sevgililer", "yok", "takvim"]:
				notify(id, "Kullanım: /ozelgun cadilar|yilbasi|ramazan|kurban|sevgililer|yok|takvim", false)
				return
			Holidays.force(k)
			notify(id, "Özel gün: %s" % (Holidays.current() if Holidays.current() != "" else "yok"))
		"festival":
			if parts.size() > 1 and parts[1] == "bitir":
				Festival.force_stop()
				notify(id, "Festival bitirildi.")
			else:
				Festival.force(10.0)
				notify(id, "Festival başladı (10 dk).")
		"afet":
			if parts.size() > 1 and parts[1] == "bitir":
				Disasters.stop(false)
				notify(id, "Afet bitirildi.")
			elif parts.size() > 1 and Disasters.KINDS.has(parts[1]):
				Disasters.start(parts[1])
				notify(id, "%s başlatıldı." % Disasters.KINDS[parts[1]].name)
			else:
				notify(id, "Kullanım: /afet deprem|sel|kar|bitir", false)
		"zombi":
			if parts.size() > 1 and parts[1] == "bitir":
				Zombies.force_stop()
				notify(id, "Zombi gecesi bitirildi.")
			else:
				Zombies.force_start()
				notify(id, "Zombi gecesi başladı (8 dk).")
		"duyuru":
			tell_all(self, "on_chat", {"name": "Duyuru", "text": arg.left(200), "color": Color(1, 0.5, 0.3), "ch": "all"})
		"kick", "at":
			if wid == 0 or wid == id:
				notify(id, "Çevrimiçi oyuncu bulunamadı.", false)
				return
			_kick(wid, "Bir yönetici seni sunucudan çıkardı.")
			announce("%s sunucudan çıkarıldı." % who)
		"sustur":
			var mins := clampi(int(parts[2]) if parts.size() > 2 else 10, 1, 1440)
			_muted[who] = Time.get_unix_time_from_system() + mins * 60.0
			notify(id, "%s %d dakika susturuldu." % [who, mins])
			if wid != 0:
				notify(wid, "Bir yönetici seni %d dakika susturdu." % mins, false)
		"hava":
			var w: String = {"açık": "clear", "acik": "clear", "bulutlu": "cloudy", "yağmur": "rain", "yagmur": "rain",
				"fırtına": "storm", "firtina": "storm", "sis": "fog", "gökkuşağı": "rainbow", "gokkusagi": "rainbow"}.get(arg.to_lower(), "")
			if w == "":
				notify(id, HELP, false)
				return
			Env.force_weather(w)
		"etkinlik":
			if not Events.KINDS.has(arg):
				notify(id, "Türler: %s" % ", ".join(Events.KINDS.keys()), false)
				return
			Events.start_event(arg)
		"kaydet":
			_save()
			notify(id, "Kaydedildi.")
		"yedekle":
			notify(id, "Yedek alındı: %s" % _backup("elle"))
		"yonetici", "yönetici":
			if who == "" or not save_data.players.has(who):
				notify(id, "Böyle bir hesap yok.", false)
				return
			if not admins().has(who):
				admins().append(who)
				mark_dirty()
			notify(id, "%s artık yönetici." % who)
		_:
			notify(id, HELP, false)
	log_line("Yönetici komutu (%s): %s" % [players[id].name, text.left(120)])


## Kayıt dosyasının zaman damgalı yedeği (yedekler/ klasörü, en yeni BACKUP_KEEP tanesi tutulur).
func _backup(reason: String) -> String:
	if not FileAccess.file_exists(save_path):
		return ""
	var dir := save_path.get_base_dir().path_join("yedekler")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "-")
	var dest := dir.path_join("kayit-%s-%s.json" % [stamp, reason])
	DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(dest))
	var files: Array = []
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(dir)):
		if f.begins_with("kayit-") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	while files.size() > BACKUP_KEEP:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(files.pop_front())))
	log_line("Yedek alındı: %s" % dest.get_file())
	return dest.get_file()


# ------------------------------------------------------------------ durum sayfası (http://127.0.0.1:7780)

func _start_status_page() -> void:
	_status_server = TCPServer.new()
	if _status_server.listen(status_port, "127.0.0.1") != OK:
		log_line("Durum sayfası açılamadı (port %d)" % status_port)
		_status_server = null
	else:
		log_line("Durum sayfası: http://127.0.0.1:%d" % status_port)


func status_data() -> Dictionary:
	var online: Array = []
	for pid in players:
		online.append({"name": players[pid].name, "level": int(players[pid].get("level", 1)), "money": int(players[pid].money)})
	var backups := 0
	var dir := ProjectSettings.globalize_path(save_path.get_base_dir().path_join("yedekler"))
	if DirAccess.dir_exists_absolute(dir):
		backups = DirAccess.get_files_at(dir).size()
	return {"version": VERSION, "uptime_min": int((Time.get_unix_time_from_system() - _started_at) / 60.0),
		"online": online, "accounts": save_data.players.size(), "weather": Env.weather_name(), "season": Env.SEASON_NAMES.get(Env.season, ""),
		"clock": Env.clock_text(), "event": Events.current.get("name", "-") if not Events._active.is_empty() else "-",
		"last_save_sec": int(Time.get_unix_time_from_system() - _last_save_at) if _last_save_at > 0.0 else -1, "backups": backups}


func _serve_status() -> void:
	if _status_server == null or not _status_server.is_connection_available():
		return
	var c := _status_server.take_connection()
	var d := status_data()
	var rows := ""
	for p in d.online:
		rows += "<tr><td>%s</td><td>Sv.%d</td><td>%s</td></tr>" % [str(p.name).xml_escape(), p.level, U.money(p.money)]
	var html := "<!doctype html><meta charset=utf-8><meta http-equiv=refresh content=10><title>MyCity Online durum</title>" + \
		"<body style='font-family:sans-serif;background:#151a26;color:#e2e8f0;padding:20px'>" + \
		"<h1 style='color:#facc15'>MyCity Online %s</h1><p>Açık: %d dk · Hesap: %d · %s · Etkinlik: %s</p>" % [d.version, d.uptime_min, d.accounts, d.clock, d.event] + \
		"<p>Son kayıt: %s sn önce · Yedek sayısı: %d</p>" % [d.last_save_sec, d.backups] + \
		"<h2>Çevrimiçi (%d)</h2><table cellpadding=6>%s</table></body>" % [d.online.size(), rows]
	var want_json := false
	if c.get_available_bytes() > 0:
		want_json = c.get_utf8_string(c.get_available_bytes()).begins_with("GET /json")
	var body := (JSON.stringify(d) if want_json else html).to_utf8_buffer()
	var head := "HTTP/1.0 200 OK\r\nContent-Type: %s; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % ["application/json" if want_json else "text/html", body.size()]
	c.put_data(head.to_utf8_buffer())
	c.put_data(body)
	c.disconnect_from_host()


func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server() or not players.has(id):
		return
	var pname: String = players[id].name
	# Önce oyunlardan çıkar (masadaki fişler paraya dönsün), sonra sil.
	Poker.on_player_left(id)
	Jobs.on_player_left(id)
	Events.on_player_left(id)
	Police.on_player_left(id)
	Work.on_player_left(id)
	Langirt.on_player_left(id)
	Factory.on_player_left(id)
	Dive.on_player_left(id)
	Mountain.on_player_left(id)
	Band.on_player_left(id)
	Trade.on_player_left(id)
	Horses.on_player_left(id)
	Camp.on_player_left(id)
	Fair.on_player_left(id)
	Airport.on_player_left(id)
	School.on_player_left(id)
	Gym.on_player_left(id)
	Pirates.on_player_left(id)
	Zoo.on_player_left(id)
	Ocean.on_player_left(id)
	Rail.on_player_left(id)
	Cinema.on_player_left(id)
	Isles.on_player_left(id)
	Cargo.on_player_left(id)
	Paint.on_player_left(id)
	Combat.on_player_left(id)
	Dungeon.on_player_left(id)
	Zombies.on_player_left(id)
	Space.on_player_left(id)
	Golf.on_player_left(id)
	Bowling.on_player_left(id)
	Tuning.on_player_left(id)
	Street.on_player_left(id)
	PetShow.on_player_left(id)
	Stalls.on_player_left(id)
	Disasters.on_player_left(id)
	Chef.on_player_left(id)
	Deep.on_player_left(id)
	Projects.on_player_left(id)
	Festival.on_player_left(id)
	Roads.on_player_left(id)
	Bank.on_player_left(id)
	if _deleting.has(pname):
		_deleting.erase(pname)
		save_data.players.erase(pname)          # 2.1: hesap silme (çıkış işlemlerinden sonra)
		log_line("%s hesabını sildi" % pname)
	players.erase(id)
	positions.erase(id)
	_save()
	_broadcast_roster()
	Clans.on_presence(pname)
	Family.on_presence(pname)
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


# ------------------------------------------------------------------ 2.2: sunucu bilgisi (sunucu listesi)

func server_info() -> Dictionary:
	var nm := server_name
	if nm == "":
		nm = "MyCity Sunucusu" if dedicated else "%s kuruyor" % str(players.get(1, {}).get("name", "Oyuncu"))
	return {"ok": true, "name": nm.left(40), "desc": server_desc.left(120), "players": players.size(),
		"max": MAX_CLIENTS, "version": VERSION, "weather": Env.weather_name()}


## Giriş yapmamış bir bağlantı sunucunun adını, oyuncu sayısını ve sürümünü sorar; yanıttan sonra bağlantı kesilir.
@rpc("any_peer", "call_remote", "reliable")
func req_info(_d: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	rpc_id(id, "on_info", server_info())
	get_tree().create_timer(2.0).timeout.connect(func():
		if id in multiplayer.get_peers() and not players.has(id):
			multiplayer.multiplayer_peer.disconnect_peer(id)
	)


@rpc("authority", "call_remote", "reliable")
func on_info(d: Dictionary) -> void:
	if _probe_t0 <= 0:
		return
	var info := d.duplicate()
	info["ok"] = true
	info["ping"] = Time.get_ticks_msec() - (_probe_sent if _probe_sent > 0 else _probe_t0)
	_probe_finish(info)


## Yerel ağdaki oyuncular menüde bu sunucuyu kendiliğinden görsün (2 sn'de bir UDP yayın).
func _lan_announce() -> void:
	if OS.has_feature("web") or _game_port <= 0:
		return
	if _lan_udp == null:
		_lan_udp = PacketPeerUDP.new()
		_lan_udp.set_broadcast_enabled(true)
		if _lan_udp.set_dest_address("255.255.255.255", DISCOVERY_PORT) != OK:
			return
	var info := server_info()
	info["mycity"] = 1
	info["port"] = _game_port
	_lan_udp.put_packet(JSON.stringify(info).to_utf8_buffer())


# ------------------------------------------------------------------ 2.1: hesap silme (Play Store şartı)
var _deleting := {}


## İstemci: şifreyle onaylayıp hesabı ve bütün verileri sil.
func delete_account(password: String) -> void:
	rpc_id(1, "req_delete_account", {"h": hash_password(my_name, password)})


@rpc("any_peer", "call_remote", "reliable")
func req_delete_account(d: Dictionary) -> void:
	var id := sender()
	if not players.has(id):
		return
	var pname: String = players[id].name
	var rec: Dictionary = save_data.players.get(pname, {})
	if rec.is_empty() or not rec.get("pass") is Dictionary:
		return
	if (str(rec.pass.salt) + str(d.get("h", ""))).sha256_text() != str(rec.pass.hash):
		notify(id, "Şifre yanlış; hesap silinmedi.", false)
		return
	_wipe_account(id, pname)
	_kick(id, "Hesabın ve bütün oyun verilerin silindi. Görüşmek üzere!")


## Hesabın dünyadaki izlerini temizle; kayıt oyuncu çıkınca silinir.
func _wipe_account(id: int, pname: String) -> void:
	var c: Dictionary = Clans.clan_of(id) if players.has(id) else {}
	if not c.is_empty():
		Clans._remove(c, pname)
	for i in Land.plots.size():
		if Land.plots[i].owner == pname:
			Homes.clear_plot(i, pname)
			Land.plots[i].owner = ""
			Land.plots[i].level = 0
			Land.plots[i]["kind"] = "home"
			for k in ["biz", "farm", "ranch"]:
				Land.plots[i].erase(k)
	if save_data.get("bazaar") is Array:
		save_data["bazaar"] = save_data.bazaar.filter(func(l): return str(l.get("seller", "")) != pname)
	if save_data.get("stalls") is Array:
		for i in save_data.stalls.size():
			if save_data.stalls[i] is Dictionary and str(save_data.stalls[i].get("owner", "")) == pname:
				save_data.stalls[i] = {}
	if save_data.get("wanted") is Array:
		save_data["wanted"] = save_data.wanted.filter(func(w): return str(w.get("buyer", "")) != pname)
	_deleting[pname] = true
	Land._broadcast()
	Bazaar._broadcast()
	Stalls._broadcast()
	mark_dirty()


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
	var app := Shops.enforce(Avatar.sanitize(rec["appearance"]), Shops.wardrobe(rec))
	rec["appearance"] = app
	players[id] = {"name": pname, "money": int(rec.get("money", START_MONEY)),
		"color": Avatar.shirt_color(app), "appearance": app, "level": Rpg.level_of_rec(rec), "ride": "", "pet": {},
		"clan": "", "clan_color": "", "wanted": 0, "police": false, "spouse": "", "mayor": false, "fishing": "", "title": "", "team": ""}
	positions[id] = Map.SPAWN + Vector2(randf_range(-120, 120), randf_range(-30, 30))
	if Police.jailed_rec(rec):
		positions[id] = Map.jail_spawn()
	_dirty = true
	tell(self, id, "welcome", {"name": pname, "pos": positions[id], "appearance": app, "new": is_new})
	_broadcast_roster()
	Land.send_state(id)
	Poker.send_state(id)
	Jobs.send_inventory(id)
	Rpg.send_sheet(id)
	Env.send_state(id)
	Garage.send_state(id)
	Homes.send_state(id)
	Bazaar.send_state(id)
	Pets.send_state(id)
	Story.send_state(id)
	Farm.send_state(id)
	Clans.send_state(id)
	Clans.on_presence(pname)
	Events.send_state(id)
	Police.send_state(id)
	Shops.send_state(id)
	Bank.send_state(id)
	Election.on_join(id)
	Family.send_state(id)
	Family.on_presence(pname)
	Ach.on_join(id)
	Seasonal.send_state(id)
	Football.send_state(id)
	Work.send_state(id)
	League.send_state(id)
	Dive.send_state(id)
	Mountain.send_state(id)
	Museum.send_state(id)
	Band.send_state(id)
	Phone.send_state(id)
	Horses.send_state(id)
	Camp.send_state(id)
	Fair.send_state(id)
	Detective.send_state(id)
	School.send_state(id)
	Holidays.send_state(id)
	Gym.send_state(id)
	Pirates.send_state(id)
	Zoo.send_state(id)
	Ocean.send_state(id)
	Rail.send_state(id)
	Cinema.send_state(id)
	Isles.send_state(id)
	Cargo.send_state(id)
	Paint.send_state(id)
	Combat.send_state(id)
	Dungeon.send_state(id)
	Zombies.send_state(id)
	Space.send_state(id)
	Golf.send_state(id)
	Bowling.send_state(id)
	Tuning.send_state(id)
	Street.send_state(id)
	PetShow.send_state(id)
	Stalls.send_state(id)
	Disasters.send_state(id)
	Chef.send_state(id)
	Deep.send_state(id)
	Projects.send_state(id)
	Festival.send_state(id)
	Roads.send_state(id)
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
	var app := Shops.enforce(Avatar.sanitize(d.get("appearance")), Shops.wardrobe(save_data.players[players[id].name]))
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
	if _probe_t0 > 0:          # eski sürüm sunucular bilgi isteğini tanımaz, sürüm uyarısıyla atar
		_probe_finish({"ok": false, "reason": str(d.get("reason", ""))})
		return
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
	Ach.set_max(id, "money", int(players[id].money))
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
	if not players.has(id):
		return
	if Police.is_jailed(id):
		positions[id] = p.clamp(Map.JAIL.position, Map.JAIL.end)     # hapisten çıkılamaz
		return
	if speed_check and not _speed_ok(id, p):
		return
	# dalış: deniz tabanı sadece dalgıçlara; dalgıç da yüzeye ancak sunucu çıkarınca döner
	if Map.SEA_BED.has_point(p):
		if Dive.is_diving(id):
			positions[id] = p.clamp(Map.SEA_BED.position, Map.SEA_BED.end)
		return
	if Dive.is_diving(id):
		return
	if Map.JAIL.has_point(p):
		return
	# bölgeler arasında (şehir / dağ / fuar) ancak sunucu ışınlamasıyla geçilir (teleferik, servis, uçak)
	var last: Vector2 = positions.get(id, p)
	if Map.region_of(p) != Map.region_of(last):
		return
	if Map.MOUNTAIN.has_point(p):
		positions[id] = p.clamp(Map.MOUNTAIN.position, Map.MOUNTAIN.end)
		return
	if Map.FAIR.has_point(p):
		positions[id] = p.clamp(Map.FAIR.position, Map.FAIR.end)
		return
	if Map.OCEAN.has_point(p):
		positions[id] = p.clamp(Map.OCEAN.position, Map.OCEAN.end)
		return
	for r in [Map.DUNGEON, Map.MOON, Map.SPACEPORT, Map.GOLF, Map.TOWN, Map.DEEP, Map.HIGHWAY, Map.YALIKENT, Map.CAMLIBEL]:
		if (r as Rect2).has_point(p):
			positions[id] = p.clamp(r.position, r.end)
			return
	if Map.INST_AREA.has_point(p):
		# 2.3: kurum odaları: sadece içinde bulunulan odada yürünür (girip çıkmayı sunucu ışınlar)
		var inst := Map.inst_at(p)
		if inst != "" and inst == Map.inst_at(last):
			var ir := Map.inst_rect(inst)
			positions[id] = p.clamp(ir.position, ir.end)
		return
	var room := Map.interior_at(p)
	if Map.INTERIOR_AREA.has_point(p) or Map.INTERIOR2_AREA.has_point(p):
		# Ev içleri harita dışında: sadece izinli olunan odada bulunulabilir.
		if room >= 0 and Homes.may_be_in(id, room):
			positions[id] = p
		return
	positions[id] = p.clamp(Map.WORLD.position, Map.WORLD.end)


## Hız/ışınlanma denetimi: bir önceki konumdan bu kadar uzağa bu sürede gidilemez.
## Sunucunun yaptığı ışınlanmalar positions'ı değiştirdiği için sorun olmaz.
func _speed_ok(id: int, p: Vector2) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var last: Vector2 = positions.get(id, p)
	var dt := clampf(now - float(_pos_t.get(id, now - 1.0)), 0.03, 2.0)
	var ride := str(players[id].get("ride", ""))
	var speed := 300.0 * Garage.speed_of(ride)
	if ride == "car":
		speed *= Tuning.max_mult(id)          # 1.9: motor, spoyler ve nitro
	elif ride == "bike" and Projects.done("bisiklet"):
		speed *= 1.15                         # 2.0: bisiklet yolu
	var allowed := speed * dt * 1.6 + 90.0
	if Map.interior_at(p) != Map.interior_at(last) or Map.inst_at(p) != Map.inst_at(last) or Map.JAIL.has_point(last):
		allowed = 1e9          # ev kapısı / hapisten çıkış: sunucu ışınladı
	if last.distance_to(p) <= allowed:
		_pos_t[id] = now
		_strikes.erase(id)
		return true
	_strikes[id] = int(_strikes.get(id, 0)) + 1
	if int(_strikes[id]) >= 4:
		_strikes.erase(id)
		log_line("UYARI: %s çok hızlı hareket etti (%.0f px), geri alındı" % [players[id].name, last.distance_to(p)])
		Homes._teleport(id, last)
		_pos_t[id] = now
	return false


@rpc("authority", "call_local", "unreliable_ordered")
func sync_positions(p: Dictionary) -> void:
	pos_view = p


func _process(delta: float) -> void:
	if _probe_t0 > 0 and Time.get_ticks_msec() - _probe_t0 > PROBE_TIMEOUT_MS:
		_probe_finish({"ok": false})
	if not is_server():
		return
	_lan_accum += delta
	if _lan_accum >= 2.0:
		_lan_accum = 0.0
		_lan_announce()
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
	_backup_accum += delta
	if _backup_accum >= BACKUP_EVERY:
		_backup_accum = 0.0
		_backup("otomatik")
	if dedicated:
		_status_accum += delta
		if _status_accum >= 0.25:
			_status_accum = 0.0
			_serve_status()
	if _save_accum >= (2.0 if dedicated else 5.0):
		_save_accum = 0.0
		if _dirty:
			_save()


# ------------------------------------------------------------------ sohbet

## channel: "all" (herkes), "clan" (klan üyeleri), "local" (yakındakiler), "pm" (to: oyuncu adı)
func send_chat(text: String, channel: String = "all", to: String = "") -> void:
	ask(self, "req_chat", {"text": text, "ch": channel, "to": to})


const LOCAL_CHAT_RANGE := 700.0
var _chat_t := {}


@rpc("any_peer", "call_remote", "reliable")
func req_chat(d: Dictionary) -> void:
	var id := sender()
	if not players.has(id):
		return
	var text := str(d.get("text", "")).strip_edges().left(200)
	if text == "":
		return
	var now := Time.get_ticks_msec()
	if now - int(_chat_t.get(id, -10000)) < 400:
		return            # sel koruması
	_chat_t[id] = now
	var me: String = players[id].name
	if float(_muted.get(me, 0.0)) > Time.get_unix_time_from_system():
		notify(id, "Susturuldun; bir süre sohbete yazamazsın.", false)
		return
	if text.begins_with("/"):
		_command(id, text)
		return
	var msg := {"name": me, "text": text, "color": players[id].color, "ch": "all"}
	match str(d.get("ch", "all")):
		"clan":
			var tag := Clans.tag_of_name(me)
			if tag == "":
				notify(id, "Bir klanda değilsin. Klan penceresinden kurabilir ya da katılabilirsin.", false)
				return
			msg.ch = "clan"
			for mid in Clans.online_members(tag):
				tell(self, mid, "on_chat", msg)
		"local":
			msg.ch = "local"
			var here: Vector2 = positions.get(id, Vector2.ZERO)
			for pid in players:
				if positions.get(pid, Vector2(-1e6, -1e6)).distance_to(here) <= LOCAL_CHAT_RANGE:
					tell(self, pid, "on_chat", msg)
		"pm":
			var to := _account_key(str(d.get("to", "")))
			var tid := id_by_name(to)
			if tid == 0 or tid == id:
				notify(id, "Özel mesaj için çevrimiçi bir oyuncu adı yaz: /m isim mesaj", false)
				return
			msg.ch = "pm"
			msg["to"] = to
			tell(self, tid, "on_chat", msg)
			tell(self, id, "on_chat", msg)
		_:
			tell_all(self, "on_chat", msg)


@rpc("authority", "call_local", "reliable")
func on_chat(d: Dictionary) -> void:
	var ch := str(d.get("ch", "all"))
	var nm := str(d.name)
	if ch == "pm" and nm == my_name:
		nm = "→ %s" % d.get("to", "")
	chat_received.emit(nm, d.text, d.color, ch)


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
		_last_save_at = Time.get_unix_time_from_system()
	else:
		log_line("UYARI: kayıt taşınamadı: %s" % error_string(err))


func _load() -> void:
	save_data = {"players": {}, "plots": []}
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		# Bilinmeyen/yeni bölümler (klanlar, yarış rekorları...) olduğu gibi korunur.
		for k in parsed:
			if not k in ["players", "plots"]:
				save_data[k] = parsed[k]
		if parsed.get("players") is Dictionary:
			save_data["players"] = parsed["players"]
			# 2.1: sunucu kapalıyken/oyuncular yokken faiz işlemez (herkes "çevrimdışı" başlar)
			for pn in save_data.players:
				var pr = save_data.players[pn]
				if pr is Dictionary and pr.get("bank_acc") is Dictionary:
					pr.bank_acc["off"] = true
		if parsed.get("plots") is Array:
			save_data["plots"] = parsed["plots"]
		if not save_data.get("bazaar") is Array:
			save_data.erase("bazaar")
		save_data["bazaar_next"] = int(parsed.get("bazaar_next", 1))
