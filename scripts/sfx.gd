extends Node
## Ses efektleri, müzik ve dalga ambiyansı (yalnızca bu bilgisayarda çalar, ağdan geçmez).
## Sesler tools/make_sounds.py ile üretilir.

signal settings_changed

const SOUNDS := ["click", "open", "coin", "cash", "lose", "error", "notify", "success", "splash",
	"splash_small", "bite", "catch", "card", "chip", "tick", "dice", "gallop",
	"thunder", "bell", "place", "door"]
const SETTINGS_PATH := "user://ayarlar.cfg"
const MUSIC_DB := -9.0

var muted := false
var music_on := true
var _streams := {}
var _pool: Array = []
var _next := 0
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var rain: AudioStreamPlayer
var crickets: AudioStreamPlayer
var engine: AudioStreamPlayer
var _enabled := true
var _sfx_db := 0.0             # efekt sesi ayarı (dB)
var _music_db := 0.0           # müzik sesi ayarı (dB)


func _ready() -> void:
	# Ekransız sunucuda ses gereksiz.
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	for n in SOUNDS:
		_streams[n] = load("res://assets/sounds/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	music = _looping("res://assets/sounds/music_city.wav", MUSIC_DB)
	ambience = _looping("res://assets/sounds/waves.wav", -80.0)
	ambience.play()
	rain = _looping("res://assets/sounds/rain.wav", -80.0)
	rain.play()
	crickets = _looping("res://assets/sounds/crickets.wav", -80.0)
	crickets.play()
	engine = _looping("res://assets/sounds/engine.wav", -80.0)
	engine.play()
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	muted = cfg.get_value("ses", "sessiz", false)
	music_on = cfg.get_value("ses", "muzik", true)
	AudioServer.set_bus_mute(0, muted)
	if music_on:
		music.play()
	# Her butona tıklama sesi
	get_tree().node_added.connect(_on_node_added)


func _looping(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.finished.connect(p.play)
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(play.bind("click", -8.0))


func play(sound: String, db: float = 0.0, pitch: float = 1.0) -> void:
	if not _enabled or not _streams.has(sound):
		return
	var p: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = db + _sfx_db
	p.pitch_scale = pitch
	p.play()


## Ayarlar: genel, müzik ve efekt seviyeleri (0..1).
func apply_volumes(master: float, music_level: float, sfx_level: float) -> void:
	if not _enabled:
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master, 0.0001, 1.0)))
	_music_db = linear_to_db(clampf(music_level, 0.0001, 1.0))
	_sfx_db = linear_to_db(clampf(sfx_level, 0.0001, 1.0))
	music.volume_db = MUSIC_DB + _music_db


## 0..1 arası: denize yakınlık.
func set_ambience(strength: float) -> void:
	if _enabled:
		ambience.volume_db = linear_to_db(clampf(strength, 0.0001, 1.0)) - 6.0 + _sfx_db


## Dünya sahnesi her karede çağırır: hava ve gece sesleri, motor.
func set_environment(rain_level: float, night_level: float, engine_on: bool, engine_pitch: float = 1.0) -> void:
	if not _enabled:
		return
	rain.volume_db = linear_to_db(clampf(rain_level, 0.0001, 1.0)) - 4.0 + _sfx_db
	crickets.volume_db = linear_to_db(clampf(night_level, 0.0001, 1.0)) - 10.0 + _sfx_db
	engine.volume_db = (-10.0 + _sfx_db) if engine_on else -80.0
	engine.pitch_scale = engine_pitch


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_save()


func toggle_music() -> void:
	music_on = not music_on
	if _enabled:
		if music_on:
			music.play()
		else:
			music.stop()
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("ses", "sessiz", muted)
	cfg.set_value("ses", "muzik", music_on)
	cfg.save(SETTINGS_PATH)
	settings_changed.emit()
