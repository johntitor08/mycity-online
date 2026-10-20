extends Node
## Gün/gece döngüsü ve hava durumu. Saat sunucu saatinden hesaplanır (yeniden başlatmada kaymaz),
## hava sunucuda rastgele değişir; ikisi de 10 sn'de bir herkese yayınlanır.

signal changed

const DAY_SECONDS := 48.0 * 60.0          # 1 oyun günü = 48 gerçek dakika
const WEATHER_NAMES := {"clear": "Açık", "cloudy": "Bulutlu", "rain": "Yağmurlu", "storm": "Fırtına"}
const WEATHER_WEIGHTS := {"clear": 50.0, "cloudy": 25.0, "rain": 18.0, "storm": 7.0}
const NIGHT_FISH := ["Yayın Balığı", "Turna", "Levrek", "Lüfer", "Kalkan", "Köpekbalığı"]

var hour := 9.0           # 0..24
var weather := "clear"
var _weather_left := 0.0
var _sync := 0.0


static func hour_from_unix(unix: float) -> float:
	return fmod(unix / (DAY_SECONDS / 24.0), 24.0)


func is_night() -> bool:
	return hour >= 20.0 or hour < 6.0


func is_rainy() -> bool:
	return weather == "rain" or weather == "storm"


## 0 = gündüz, 1 = gece; akşam 18-20.5 ve sabah 5-7 arası yumuşak geçiş.
func darkness() -> float:
	if hour >= 20.5 or hour < 5.0:
		return 1.0
	if hour >= 18.0:
		return (hour - 18.0) / 2.5
	if hour < 7.0:
		return 1.0 - (hour - 5.0) / 2.0
	return 0.0


func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0)
	var part := "Gece" if is_night() else ("Akşam" if hour >= 17.0 else ("Sabah" if hour < 11.0 else "Öğlen"))
	return "%02d:%02d  %s · %s" % [h, m, part, WEATHER_NAMES.get(weather, weather)]


func reset() -> void:
	weather = "clear"


func server_start() -> void:
	hour = hour_from_unix(Time.get_unix_time_from_system())
	weather = "clear"
	_weather_left = randf_range(240.0, 600.0)


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / DAY_SECONDS, 24.0)
	if not Net.is_server():
		return
	_weather_left -= delta
	if _weather_left <= 0.0:
		_pick_weather()
	_sync += delta
	if _sync >= 10.0:
		_sync = 0.0
		hour = hour_from_unix(Time.get_unix_time_from_system())
		_broadcast()


func _pick_weather() -> void:
	var total := 0.0
	for k in WEATHER_WEIGHTS:
		total += WEATHER_WEIGHTS[k]
	var r := randf() * total
	var pick := "clear"
	for k in WEATHER_WEIGHTS:
		r -= WEATHER_WEIGHTS[k]
		if r <= 0.0:
			pick = k
			break
	_weather_left = randf_range(240.0, 600.0)
	if pick == weather:
		return
	weather = pick
	match pick:
		"rain":
			Net.announce("Yağmur başladı. Balıklar daha çabuk vuruyor!")
		"storm":
			Net.announce("Fırtına çıktı! Deniz iskelesi kapandı, denize girmeyin.")
		"clear":
			Net.announce("Hava açtı. Plaj seni bekliyor!")
	Net.log_line("Hava: %s" % WEATHER_NAMES[pick])
	_broadcast()


## Test ve yönetim için: havayı hemen değiştir.
func force_weather(w: String) -> void:
	if Net.is_server() and WEATHER_NAMES.has(w):
		weather = w
		_weather_left = randf_range(240.0, 600.0)
		_broadcast()


func _broadcast() -> void:
	Net.tell_all(self, "on_env", {"hour": hour, "weather": weather})


func send_state(id: int) -> void:
	Net.tell(self, id, "on_env", {"hour": hour, "weather": weather})


@rpc("authority", "call_local", "reliable")
func on_env(d: Dictionary) -> void:
	hour = float(d.hour)
	weather = str(d.weather)
	changed.emit()
