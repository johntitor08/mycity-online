extends "res://scripts/ui/game_panel.gd"
## Büyük harita (M): bir yere tıkla ya da listeden seç → yön oku seni oraya götürür.

const Map = preload("res://scripts/map.gd")
const MiniMap = preload("res://scripts/ui/minimap.gd")

var world: Node2D
var mapc: Control


func _ready() -> void:
	build("Şehir Haritası", Vector2(860, 0))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	body.add_child(h)
	mapc = MiniMap.new()
	mapc.big = true
	mapc.world = world
	mapc.custom_minimum_size = Vector2(Map.WORLD.size.x, Map.WORLD.size.y) * (580.0 / Map.WORLD.size.y)
	mapc.picked.connect(_go)
	h.add_child(mapc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	h.add_child(v)
	add_label(v, "Haritaya tıkla ya da hedef seç:", 14, Color("#94a3b8"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 470)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	sc.add_child(list)
	var st := Story.state
	if not st.is_empty() and not st.get("finished", false):
		var npc := str(st.get("claim_npc", "")) if st.get("ready", false) else (str(st.get("target", "")) if st.get("accepted", false) and str(st.get("target", "")) != "" else str(st.get("npc", "")))
		if Map.NPCS.has(npc):
			add_button(list, "★ Görev: %s" % Map.NPCS[npc].name, _go.bind(Map.NPCS[npc].pos + Vector2(0, 40)))
	for b in Map.BUILDINGS:
		add_button(list, b.label, _go.bind(Vector2(b.rect.get_center().x, b.rect.end.y + 12)))
	for t in [["Göl İskelesi", Map.DOCK.get_center()], ["Deniz İskelesi / tekne kirala", Map.BOAT_RENT_SPOT],
			["Plaj Sahası (futbol)", Football.FIELD.get_center() + Vector2(0, 110)], ["Langırt Masası", Langirt.POS + Vector2(0, 60)],
			["Yarış Pisti", Map.RACE_FLAG + Vector2(0, 40)], ["Martı Adası (tekneyle)", Map.ISLAND_PIER.get_center()],
			["Feribot İskelesi (şehir)", Map.FERRY_STOPS.sehir[1]], ["Fabrika (Sanayi, feribotla)", Map.building("fabrika").rect.get_center() + Vector2(0, 160)],
			["Park Sahnesi (konser)", Map.STAGE.get_center() + Vector2(0, 70)],
			["Hipodrom (Sanayi, feribotla)", Map.HIPPO_BOOTH + Vector2(40, 30)]]:
		add_button(list, t[0], _go.bind(t[1]))
	add_button(v, "Hedefi temizle", func(): world.nav_target = null; close())


func _go(p: Vector2) -> void:
	world.set_nav(p)
	close()
