extends RefCounted
## tools/make_art.py üretir: binaların pencere dikdörtgenleri (SVG birimi). Gece ışıkları için.

const DATA := {
	"res://assets/buildings/banka.svg": [Vector2(320.0, 220.0), [Rect2(100, 136, 18, 30), Rect2(202, 136, 18, 30)]],
	"res://assets/buildings/carsi.svg": [Vector2(320.0, 220.0), [Rect2(20, 128, 44, 44), Rect2(122, 128, 44, 44), Rect2(224, 128, 44, 44)]],
	"res://assets/buildings/fabrika.svg": [Vector2(440.0, 280.0), [Rect2(24, 150, 52, 40), Rect2(92, 150, 52, 40), Rect2(300, 150, 52, 40), Rect2(368, 150, 52, 40)]],
	"res://assets/buildings/galeri.svg": [Vector2(320.0, 220.0), [Rect2(16, 120, 288, 76)]],
	"res://assets/buildings/hospital.svg": [Vector2(380.0, 260.0), [Rect2(18, 136, 36, 32), Rect2(62, 136, 36, 32), Rect2(106, 136, 36, 32), Rect2(238, 136, 36, 32), Rect2(282, 136, 36, 32), Rect2(326, 136, 36, 32), Rect2(18, 184, 36, 32), Rect2(62, 184, 36, 32), Rect2(106, 184, 36, 32), Rect2(238, 184, 36, 32), Rect2(282, 184, 36, 32), Rect2(326, 184, 36, 32), Rect2(156, 186, 33, 50), Rect2(191, 186, 33, 50)]],
	"res://assets/buildings/karakol.svg": [Vector2(320.0, 220.0), [Rect2(22, 126, 38, 50), Rect2(72, 126, 38, 50), Rect2(212, 126, 38, 50), Rect2(262, 126, 38, 50)]],
	"res://assets/buildings/market.svg": [Vector2(340.0, 260.0), [Rect2(18, 160, 118, 66), Rect2(204, 160, 118, 66), Rect2(146, 158, 48, 78)]],
	"res://assets/buildings/mobilya.svg": [Vector2(320.0, 220.0), [Rect2(16, 120, 120, 76), Rect2(184, 120, 120, 76)]],
	"res://assets/buildings/muhtarlik.svg": [Vector2(320.0, 220.0), [Rect2(24, 126, 40, 52), Rect2(70, 126, 40, 52), Rect2(210, 126, 40, 52), Rect2(256, 126, 40, 52)]],
	"res://assets/buildings/muze.svg": [Vector2(420.0, 280.0), [Rect2(150, 160, 20, 40), Rect2(250, 160, 20, 40)]],
	"res://assets/buildings/okul.svg": [Vector2(168.0, 200.0), [Rect2(18, 78, 34, 30), Rect2(18, 128, 34, 30), Rect2(116, 78, 34, 30), Rect2(116, 128, 34, 30)]],
	"res://assets/buildings/petshop.svg": [Vector2(320.0, 260.0), [Rect2(18, 134, 110, 82), Rect2(192, 134, 110, 82)]],
	"res://assets/buildings/realestate.svg": [Vector2(300.0, 260.0), [Rect2(20, 136, 80, 60), Rect2(200, 136, 80, 60)]],
	"res://assets/buildings/spor.svg": [Vector2(168.0, 156.0), [Rect2(14, 62, 44, 30), Rect2(110, 62, 44, 30)]],
	"res://assets/buildings/teleferik.svg": [Vector2(180.0, 116.0), [Rect2(22, 58, 36, 26), Rect2(122, 58, 36, 26)]],
	"res://assets/buildings/terminal.svg": [Vector2(420.0, 230.0), [Rect2(20, 100, 380, 70)]],
	"res://assets/plots/bufe.svg": [Vector2(130.0, 120.0), [Rect2(22, 60, 86, 30)]],
	"res://assets/plots/house.svg": [Vector2(130.0, 120.0), [Rect2(24, 68, 22, 20), Rect2(86, 68, 22, 20)]],
	"res://assets/plots/kafe.svg": [Vector2(200.0, 130.0), [Rect2(22, 40, 96, 40)]],
	"res://assets/plots/tower.svg": [Vector2(110.0, 170.0), [Rect2(40, 146, 30, 20)]],
	"res://assets/plots/villa.svg": [Vector2(220.0, 130.0), [Rect2(16, 48, 132, 26), Rect2(16, 86, 50, 38), Rect2(98, 86, 50, 38)]],
}
