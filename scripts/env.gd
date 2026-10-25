extends Node
## Gün/gece döngüsü ve hava durumu. Saat sunucu saatinden hesaplanır (yeniden başlatmada kaymaz),
## hava sunucuda rastgele değişir; ikisi de 10 sn'de bir herkese yayınlanır.

signal changed

const DAY_SECONDS := 48.0 * 60.0          # 1 oyun günü = 48 gerçek dakika
const WEATHER_NAMES := {"clear": "Açık", "cloudy": "Bulutlu", "rain": "Yağmurlu", "storm": "Fırtına",
	"fog": "Sisli", "rainbow": "Gökkuşağı"}
const WEATHER_WEIGHTS := {"clear": 50.0, "cloudy": 25.0, "rain": 18.0, "storm": 7.0}
const NIGHT_FISH := ["Yayın Balığı", "Turna", "Levrek", "Lüfer", "Kalkan", "Köpekbalığı"]
# Mevsimler: her biri 3 oyun günü (~2,4 gerçek saat) sürer.
const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {"spring": "İlkbahar", "summer": "Yaz", "autumn": "Sonbahar", "winter": "Kış"}
const SEASON_DAYS := 3
# Mevsime göre hava olasılıkları (kışın yağış kar olarak görünür)
const SEASON_WEATHER := {
	"spring": {"clear": 42.0, "cloudy": 24.0, "rain": 24.0, "storm": 5.0, "fog": 5.0},
	"summer": {"clear": 68.0, "cloudy": 16.0, "rain": 10.0, "storm": 6.0},
	"autumn": {"clear": 30.0, "cloudy": 28.0, "rain": 22.0, "storm": 8.0, "fog": 12.0},
	"winter": {"clear": 34.0, "cloudy": 28.0, "rain": 22.0, "storm": 6.0, "fog": 10.0},
}

var hour := 9.0           # 0..24
var weather := "clear"
var season := "spring"
var _season_forced := false
var _weather_left := 0.0
var _sync := 0.0


static func hour_from_unix(unix: float) -> float:
	return fmod(unix / (DAY_SECONDS / 24.0), 24.0)


static func season_from_unix(unix: float) -> String:
	return SEASONS[int(floor(unix / (DAY_SECONDS * SEASON_DAYS))) % 4]


func is_snowy() -> bool:
	return season == "winter" and is_rainy()


func weather_name() -> String:
	if season == "winter":
		match weather:
			"rain":
				return "Karlı"
			"storm":
				return "Tipi"
	return WEATHER_NAMES.get(weather, weather)


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
	return "%02d:%02d  %s · %s · %s" % [h, m, part, weather_name(), SEASON_NAMES.get(season, season)]


func reset() -> void:
	weather = "clear"


func server_start() -> void:
	hour = hour_from_unix(Time.get_unix_time_from_system())
	season = season_from_unix(Time.get_unix_time_from_system())
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
		var s := season_from_unix(Time.get_unix_time_from_system())
		if s != season and not _season_forced:
			season = s
			Seasonal.on_season(s)
			Net.announce("%s geldi! %s" % [SEASON_NAMES[s], {"spring": "Çilek ekme zamanı.", "summer": "Domates, mısır ve karpuz bu mevsim hızlı büyür.",
				"autumn": "Buğday ve balkabağı zamanı.", "winter": "Tarlalar yavaşlar; lahana kışı sever."}[s]])
		_broadcast()


func _pick_weather() -> void:
	var weights: Dictionary = SEASON_WEATHER.get(season, WEATHER_WEIGHTS)
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var pick := "clear"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			pick = k
			break
	_weather_left = randf_range(240.0, 600.0)
	# yağmur dinince bazen gökkuşağı çıkar (kışın değil)
	if is_rainy() and pick in ["clear", "cloudy"] and season != "winter" and randf() < 0.5:
		pick = "rainbow"
		_weather_left = randf_range(120.0, 200.0)
	if pick == weather:
		return
	weather = pick
	match pick:
		"rain":
			Net.announce("Kar yağmaya başladı. Tarlalar kendiliğinden sulanıyor." if season == "winter" else "Yağmur başladı. Balıklar daha çabuk vuruyor, tarlalar sulanıyor!")
		"storm":
			Net.announce("Fırtına çıktı! Deniz iskelesi kapandı, denize girmeyin. Ekinler zarar görebilir!")
			Farm.on_storm()
		"clear":
			Net.announce("Hava açtı. Plaj seni bekliyor!")
		"fog":
			Net.announce("Şehri yoğun bir sis kapladı. Gemiciler dikkat!")
		"rainbow":
			Net.announce("Yağmurdan sonra gökkuşağı çıktı! Bu sırada tutulan balıklar şans getirir.")
	Net.log_line("Hava: %s" % weather_name())
	_broadcast()


## Test ve yönetim için: havayı hemen değiştir.
func force_weather(w: String) -> void:
	if Net.is_server() and WEATHER_NAMES.has(w):
		weather = w
		_weather_left = randf_range(240.0, 600.0)
		_broadcast()


## Test için: mevsimi hemen değiştir.
func force_season(s: String) -> void:
	if Net.is_server() and SEASON_NAMES.has(s):
		season = s
		_season_forced = true
		Seasonal.on_season(s)
		_broadcast()


func _broadcast() -> void:
	Net.tell_all(self, "on_env", {"hour": hour, "weather": weather, "season": season})


func send_state(id: int) -> void:
	Net.tell(self, id, "on_env", {"hour": hour, "weather": weather, "season": season})


@rpc("authority", "call_local", "reliable")
func on_env(d: Dictionary) -> void:
	hour = float(d.hour)
	weather = str(d.weather)
	season = str(d.get("season", season))
	changed.emit()
