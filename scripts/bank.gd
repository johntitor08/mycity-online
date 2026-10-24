extends Node
## Banka ve borsa.
## Hesap: para yatır/çek; mevduat faiz getirir (bir sınıra kadar) ve soyulamaz. Kredi: seviyeye göre limit,
## %10 masrafla verilir, vadesi geçerse banka borcu önce mevduattan sonra cepten tahsil eder.
## Borsa: altı şehir şirketi. Fiyatlar her dakika rastgele dalgalanır, şehirdeki olaylar (balık, hasat,
## kumar, arsa, araç, alışveriş, hava, festival) yönünü etkiler. Oyuncular hisse alıp satar (%1 komisyon).
## Bu tamamen oyun içi sanal bir borsadır.
## Veri: rec["bank_acc"] = {bal, t, debt, due}, rec["stocks"] = {SEMBOL: {n, cost}}, save_data["stocks"] = {SEMBOL: {p, hist}}

signal changed

const Map = preload("res://scripts/map.gd")
const U = preload("res://scripts/util.gd")

const INTEREST_PER_DAY := 0.03            # oyun günü (48 dk) başına %3
const INTEREST_CAP := 200000              # bu tutarın üstü faiz getirmez
const LOAN_PER_LEVEL := 1000
const LOAN_MAX := 25000
const LOAN_FEE := 0.10
const LOAN_DAYS := 3                      # oyun günü (~2,4 saat)
const STOCK_FEE := 0.01
const MAX_SHARES := 10000
const HISTORY := 60

const STOCKS := {
	"MRKT": {"name": "Şehir Marketleri", "base": 40.0},
	"BALK": {"name": "Hasan Balıkçılık", "base": 25.0},
	"KMRH": {"name": "Altın Kumarhane", "base": 80.0},
	"EMLK": {"name": "Boğaz İnşaat", "base": 120.0},
	"OTO": {"name": "Galeri Otomotiv", "base": 60.0},
	"TARM": {"name": "Bereket Tarım", "base": 18.0},
}

# --- istemci
var account: Dictionary = {}      # {bal, debt, due_in, loan_limit, rate}
var holdings: Dictionary = {}     # {SEMBOL: {n, cost}}
var market: Dictionary = {}       # {SEMBOL: {p, hist}}

# --- sunucu
var _activity := {}               # sembol -> bu dakikadaki olay sayısı
var _acc := 0.0


func reset() -> void:
	account = {}
	holdings = {}
	market = {}
	_activity.clear()


func _now() -> float:
	return Time.get_unix_time_from_system()


# ------------------------------------------------------------------ istemci API

func deposit(amount: int) -> void:
	Net.ask(self, "req_bank", {"op": "deposit", "amount": amount})


func withdraw(amount: int) -> void:
	Net.ask(self, "req_bank", {"op": "withdraw", "amount": amount})


func borrow(amount: int) -> void:
	Net.ask(self, "req_bank", {"op": "loan", "amount": amount})


func repay(amount: int) -> void:
	Net.ask(self, "req_bank", {"op": "repay", "amount": amount})


func trade(sym: String, n: int) -> void:
	Net.ask(self, "req_trade", {"sym": sym, "n": n})      # n > 0 al, n < 0 sat


@rpc("authority", "call_local", "reliable")
func on_account(d: Dictionary) -> void:
	account = d.get("acc", {})
	holdings = d.get("hold", {})
	changed.emit()


@rpc("authority", "call_local", "reliable")
func on_market(d: Dictionary) -> void:
	market = d.get("m", {})
	changed.emit()


func price(sym: String) -> float:
	return float(market.get(sym, {}).get("p", STOCKS[sym].base))


## Son tik ile önceki arasındaki yüzde değişim.
func change_pct(sym: String) -> float:
	var h: Array = market.get(sym, {}).get("hist", [])
	if h.size() < 2:
		return 0.0
	return (float(h[-1]) / maxf(0.01, float(h[-2])) - 1.0) * 100.0


# ------------------------------------------------------------------ sunucu: hesap

func _rec(id: int) -> Dictionary:
	if not Net.players.has(id):
		return {}
	return Net.save_data.players.get(Net.players[id].name, {})


## Faizi işlenmiş hesap (yoksa oluşturur).
static func acc_of(rec: Dictionary) -> Dictionary:
	if not rec.get("bank_acc") is Dictionary:
		rec["bank_acc"] = {"bal": 0.0, "t": Time.get_unix_time_from_system(), "debt": 0, "due": 0.0}
	var a: Dictionary = rec["bank_acc"]
	var now := Time.get_unix_time_from_system()
	var dt := maxf(0.0, now - float(a.t))
	var bal := float(a.bal)
	bal += minf(bal, INTEREST_CAP) * INTEREST_PER_DAY * dt / Env.DAY_SECONDS
	a["bal"] = bal
	a["t"] = now
	return a


static func loan_limit(level: int) -> int:
	return mini(LOAN_MAX, LOAN_PER_LEVEL * level)


func send_state(id: int) -> void:
	var rec := _rec(id)
	if rec.is_empty():
		return
	var a := acc_of(rec)
	var due_in := float(a.due) - _now() if int(a.debt) > 0 else 0.0
	Net.tell(self, id, "on_account", {"acc": {"bal": int(a.bal), "debt": int(a.debt), "due_in": due_in,
		"loan_limit": loan_limit(Rpg.level(id)), "rate": INTEREST_PER_DAY},
		"hold": _holdings(rec).duplicate(true)})
	Net.tell(self, id, "on_market", {"m": _market()})


func _at_bank(id: int) -> bool:
	return Map.building("banka").rect.grow(60).has_point(Net.positions.get(id, Vector2(-9999, -9999)))


@rpc("any_peer", "call_remote", "reliable")
func req_bank(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	if rec.is_empty():
		return
	if not _at_bank(id):
		Net.notify(id, "Banka işlemleri için Banka'ya git.", false)
		return
	var a := acc_of(rec)
	var amount := int(d.get("amount", 0))
	if amount <= 0:
		return
	match str(d.get("op", "")):
		"deposit":
			if not Net.try_spend(id, amount):
				Net.notify(id, "Cebinde o kadar para yok.", false)
				return
			a["bal"] = float(a.bal) + amount
			Net.notify(id, "Hesaba %s yatırıldı." % U.money(amount))
		"withdraw":
			amount = mini(amount, int(a.bal))
			if amount <= 0:
				Net.notify(id, "Hesabında para yok.", false)
				return
			a["bal"] = float(a.bal) - amount
			Net.add_money(id, amount)
			Net.notify(id, "Hesaptan %s çekildi." % U.money(amount))
		"loan":
			if int(a.debt) > 0:
				Net.notify(id, "Önce mevcut kredini kapat.", false)
				return
			var lim := loan_limit(Rpg.level(id))
			if amount > lim:
				Net.notify(id, "Kredi limitin %s." % U.money(lim), false)
				return
			a["debt"] = int(round(amount * (1.0 + LOAN_FEE)))
			a["due"] = _now() + LOAN_DAYS * Env.DAY_SECONDS
			Net.add_money(id, amount)
			Net.notify(id, "%s kredi çekildi. Geri ödeme: %s (%d oyun günü içinde)." % [U.money(amount), U.money(int(a.debt)), LOAN_DAYS])
			Net.log_line("Banka: %s %d TL kredi çekti" % [Net.players[id].name, amount])
		"repay":
			amount = mini(amount, int(a.debt))
			if amount <= 0:
				return
			if not Net.try_spend(id, amount):
				Net.notify(id, "Cebinde o kadar para yok.", false)
				return
			a["debt"] = int(a.debt) - amount
			Net.notify(id, "Kredi borcu ödendi: %s%s" % [U.money(amount), " — borcun kalmadı!" if int(a.debt) == 0 else ""])
		_:
			return
	Net.mark_dirty()
	send_state(id)


## Vadesi geçmiş krediler: önce mevduattan, sonra cepten tahsil (çevrimdışı oyuncular dahil).
func _collect_overdue() -> void:
	var now := _now()
	for pname in Net.save_data.players:
		var rec: Dictionary = Net.save_data.players[pname]
		if not rec.get("bank_acc") is Dictionary or int(rec.bank_acc.get("debt", 0)) <= 0:
			continue
		var a := acc_of(rec)
		if float(a.due) > now:
			continue
		var debt := int(a.debt)
		var from_bal := mini(debt, int(a.bal))
		a["bal"] = float(a.bal) - from_bal
		debt -= from_bal
		var pid := Net.id_by_name(pname)
		var cash := Net.get_money(pid) if pid != 0 else int(rec.get("money", 0))
		var from_cash := mini(debt, cash)
		if from_cash > 0:
			Net.add_money_by_name(pname, -from_cash)
		debt -= from_cash
		a["debt"] = debt
		Net.mark_dirty()
		if pid != 0 and from_bal + from_cash > 0:
			Net.notify(pid, "Kredinin vadesi geçti: banka %s tahsil etti%s." % [U.money(from_bal + from_cash),
				", kalan borç %s" % U.money(debt) if debt > 0 else ""], false)
			send_state(pid)


# ------------------------------------------------------------------ sunucu: borsa

static func _holdings(rec: Dictionary) -> Dictionary:
	if not rec.get("stocks") is Dictionary:
		rec["stocks"] = {}
	return rec["stocks"]


func _market() -> Dictionary:
	if not Net.save_data.get("stocks") is Dictionary:
		Net.save_data["stocks"] = {}
	var m: Dictionary = Net.save_data["stocks"]
	for sym in STOCKS:
		if not m.get(sym) is Dictionary:
			m[sym] = {"p": STOCKS[sym].base, "hist": [STOCKS[sym].base]}
	return m


## Oyun olayları borsayı etkiler (Jobs, Farm, Casino, Land, Garage, Biz çağırır).
func activity(sym: String, n: int = 1) -> void:
	if Net.is_server() and STOCKS.has(sym):
		_activity[sym] = int(_activity.get(sym, 0)) + n


@rpc("any_peer", "call_remote", "reliable")
func req_trade(d: Dictionary) -> void:
	var id := Net.sender()
	var rec := _rec(id)
	var sym := str(d.get("sym", ""))
	var n := int(d.get("n", 0))
	if rec.is_empty() or not STOCKS.has(sym) or n == 0:
		return
	if not _at_bank(id):
		Net.notify(id, "Borsa işlemleri Banka'da yapılır.", false)
		return
	var p := float(_market()[sym].p)
	var hold := _holdings(rec)
	var h: Dictionary = hold.get(sym, {"n": 0, "cost": 0.0})
	if n > 0:
		n = mini(n, MAX_SHARES - int(h.n))
		var cost := int(ceil(n * p * (1.0 + STOCK_FEE)))
		if n <= 0 or not Net.try_spend(id, cost):
			Net.notify(id, "Yeterli paran yok (%d hisse %s)." % [n, U.money(cost)], false)
			return
		h["cost"] = (float(h.cost) * int(h.n) + cost) / float(int(h.n) + n)
		h["n"] = int(h.n) + n
		hold[sym] = h
		Net.notify(id, "%d %s hissesi alındı: %s" % [n, sym, U.money(cost)])
	else:
		var k := mini(-n, int(h.n))
		if k <= 0:
			Net.notify(id, "Elinde %s hissesi yok." % sym, false)
			return
		var gain := int(floor(k * p * (1.0 - STOCK_FEE)))
		h["n"] = int(h.n) - k
		if int(h.n) <= 0:
			hold.erase(sym)
		Net.add_money(id, gain)
		Net.notify(id, "%d %s hissesi satıldı: +%s" % [k, sym, U.money(gain)])
	Net.mark_dirty()
	Net.log_line("Borsa: %s %+d %s @ %.2f" % [Net.players[id].name, n, sym, p])
	send_state(id)


## Dakikalık fiyat güncellemesi.
func tick_market() -> void:
	var m := _market()
	var drift := {}
	for sym in STOCKS:
		drift[sym] = 0.0
	drift.BALK += 0.002 * minf(20.0, float(_activity.get("BALK", 0)))
	drift.TARM += 0.003 * minf(20.0, float(_activity.get("TARM", 0)))
	drift.KMRH += 0.0015 * minf(30.0, float(_activity.get("KMRH", 0)))
	drift.EMLK += 0.01 * minf(5.0, float(_activity.get("EMLK", 0)))
	drift.OTO += 0.015 * minf(4.0, float(_activity.get("OTO", 0)))
	drift.MRKT += 0.002 * minf(20.0, float(_activity.get("MRKT", 0)))
	match Env.weather:
		"storm":
			drift.BALK -= 0.03
			drift.TARM -= 0.02
		"rain":
			drift.TARM += 0.005
	if Env.season == "winter":
		drift.TARM -= 0.005
	if Events.is_active("festival"):
		drift.MRKT += 0.02
		drift.KMRH += 0.02
	var news: Array = []
	for sym in STOCKS:
		var base: float = STOCKS[sym].base
		var p := float(m[sym].p)
		var revert := 0.03 * log(base / p)              # uzun vadede taban fiyata döner
		var shock := randfn(0.0, 0.025)
		var np := clampf(p * exp(float(drift[sym]) + revert + shock), base * 0.2, base * 5.0)
		np = snappedf(np, 0.01)
		var hist: Array = m[sym].hist
		hist.append(np)
		while hist.size() > HISTORY:
			hist.pop_front()
		m[sym]["p"] = np
		var pct := (np / p - 1.0) * 100.0
		if absf(pct) >= 7.0:
			news.append("%s %s%%%.1f" % [sym, "+" if pct > 0 else "-", absf(pct)])
	_activity.clear()
	Net.mark_dirty()
	Net.tell_all(self, "on_market", {"m": m})
	if not news.is_empty():
		Net.announce("Borsada sert hareket: %s" % ", ".join(news))


func _process(delta: float) -> void:
	if not Net.is_server():
		return
	_acc += delta
	if _acc < 60.0:
		return
	_acc = 0.0
	tick_market()
	_collect_overdue()
