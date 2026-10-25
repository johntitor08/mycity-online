extends Node
## Oyuncu ayarları (sadece bu bilgisayarda, user://ayarlar.cfg): ses seviyeleri, tam ekran, kamera
## yakınlaştırması, arayüz boyutu, renk körlüğü modu, tuş atamaları ve eğitim turunun durumu.

signal changed

const PATH := "user://ayarlar.cfg"
# eylem -> [varsayılan tuş, ad]
const ACTIONS := {
	"up": [KEY_W, "Yukarı"], "down": [KEY_S, "Aşağı"], "left": [KEY_A, "Sola"], "right": [KEY_D, "Sağa"],
	"interact": [KEY_E, "Gir / konuş / kullan"], "vehicle": [KEY_F, "Araca bin / in"], "action": [KEY_G, "Eylem (G)"],
	"map": [KEY_M, "Harita"], "throw": [KEY_T, "Kartopu at"], "profile": [KEY_C, "Profil"],
}

var keys := {}
var master_vol := 1.0
var music_vol := 0.8
var sfx_vol := 1.0
var fullscreen := false
var zoom := 1.0
var ui_scale := 1.0
var colorblind := false
var tutorial_done := false


func _ready() -> void:
	for a in ACTIONS:
		keys[a] = int(ACTIONS[a][0])
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	master_vol = float(cfg.get_value("ayar", "ses_genel", 1.0))
	music_vol = float(cfg.get_value("ayar", "ses_muzik", 0.8))
	sfx_vol = float(cfg.get_value("ayar", "ses_efekt", 1.0))
	fullscreen = bool(cfg.get_value("ayar", "tam_ekran", false))
	zoom = float(cfg.get_value("ayar", "yakinlastirma", 1.0))
	ui_scale = float(cfg.get_value("ayar", "arayuz", 1.0))
	colorblind = bool(cfg.get_value("ayar", "renk_korlugu", false))
	tutorial_done = bool(cfg.get_value("ayar", "egitim_bitti", false))
	var saved = cfg.get_value("ayar", "tuslar", {})
	if saved is Dictionary:
		for a in saved:
			if keys.has(a):
				keys[a] = int(saved[a])
	apply.call_deferred()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("ayar", "ses_genel", master_vol)
	cfg.set_value("ayar", "ses_muzik", music_vol)
	cfg.set_value("ayar", "ses_efekt", sfx_vol)
	cfg.set_value("ayar", "tam_ekran", fullscreen)
	cfg.set_value("ayar", "yakinlastirma", zoom)
	cfg.set_value("ayar", "arayuz", ui_scale)
	cfg.set_value("ayar", "renk_korlugu", colorblind)
	cfg.set_value("ayar", "egitim_bitti", tutorial_done)
	cfg.set_value("ayar", "tuslar", keys)
	cfg.save(PATH)


## Ayarları uygula (pencere, arayüz boyutu, sesler) ve dinleyenlere haber ver.
func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want and not (not fullscreen and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
		DisplayServer.window_set_mode(want)
	get_window().content_scale_factor = ui_scale
	Sfx.apply_volumes(master_vol, music_vol, sfx_vol)
	changed.emit()


# ------------------------------------------------------------------ tuşlar

func key(a: String) -> int:
	return int(keys.get(a, ACTIONS[a][0]))


func key_name(a: String) -> String:
	return OS.get_keycode_string(key(a))


## Tuş basılı mı? (hareket tuşlarında oklar da her zaman çalışır)
func held(a: String) -> bool:
	if Input.is_physical_key_pressed(key(a)):
		return true
	match a:
		"up":
			return Input.is_physical_key_pressed(KEY_UP)
		"down":
			return Input.is_physical_key_pressed(KEY_DOWN)
		"left":
			return Input.is_physical_key_pressed(KEY_LEFT)
		"right":
			return Input.is_physical_key_pressed(KEY_RIGHT)
	return false


func is_key(e: InputEventKey, a: String) -> bool:
	return e.physical_keycode == key(a)


## Kamera yakınlaştırması (arayüz büyütülünce dünya aynı boyda kalsın).
func world_zoom() -> float:
	return zoom / ui_scale


# ------------------------------------------------------------------ renkler (renk körlüğü modu)

func good_color() -> Color:
	return Color(0.08, 0.28, 0.55, 0.92) if colorblind else Color(0.09, 0.32, 0.18, 0.92)


func bad_color() -> Color:
	return Color(0.62, 0.32, 0.02, 0.92) if colorblind else Color(0.45, 0.10, 0.12, 0.92)


func ok_text() -> Color:
	return Color("#7dd3fc") if colorblind else Color("#86efac")


func bad_text() -> Color:
	return Color("#fdba74") if colorblind else Color("#fca5a5")
