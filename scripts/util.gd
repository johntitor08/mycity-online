extends RefCounted
## Ortak yardımcılar.


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out + " TL"


static func name_color(player_name: String) -> Color:
	var h := absi(hash(player_name)) % 360
	return Color.from_hsv(h / 360.0, 0.6, 0.95)


## BBCode içine kullanıcı metni koyarken köşeli parantezleri etkisizleştirir.
## Türkçe büyük harf: i → İ, ı → I (Godot'nun to_upper'ı i'yi I yapar).
static func upper_tr(text: String) -> String:
	return text.replace("i", "İ").to_upper()


static func esc(text: String) -> String:
	return text.replace("[", "[lb]")


## 2.3: basılı tutulan işlerde (kaya, zıpkın) sunucu hız sınırı. Katı aralık yerine ortalama hıza bakar:
## en fazla 2 hak birikir, ağ gecikmesiyle üst üste gelen iki istek reddedilmez; uzun vadede `interval`'dan sık olmaz.
## st: id -> [hak, son kabul zamanı]
static func rate_ok(st: Dictionary, id: int, interval: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var credit := 2.0
	var prev = st.get(id)
	if prev is Array:
		credit = minf(2.0, float(prev[0]) + (now - float(prev[1])) / interval)
	if credit < 1.0:
		return false
	st[id] = [credit - 1.0, now]
	return true
