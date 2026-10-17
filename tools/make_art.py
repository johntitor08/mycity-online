#!/usr/bin/env python3
"""MyCity Online görsellerini (SVG) üretir.

Çalıştır:  python3 tools/make_art.py
Sonra Godot'ta içe aktar (düzenleyiciyi açmak yeterli, ya da `godot --headless --path . --import`).

Tüm çizimler 2x çözünürlükte üretilir (width/height = 2 * viewBox), oyun yarım boyutta çizer;
böylece yakınlaştırınca da keskin kalır. İstersen çıkan SVG'leri Inkscape ile düzenleyebilirsin.
"""
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
OL = "#232634"          # dış çizgi rengi
GLASS = '<linearGradient id="glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e0f2fe"/><stop offset="1" stop-color="#60a5fa"/></linearGradient>'
WARM = '<linearGradient id="warm" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fef3c7"/><stop offset="1" stop-color="#f59e0b"/></linearGradient>'


# ---------------------------------------------------------------- temel şekiller

def _st(sw, stroke):
    if sw == 0:
        return 'stroke="none"'
    return f'stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"'


def rect(x, y, w, h, fill, rx=0, sw=3, stroke=OL, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {_st(sw, stroke)} {extra}/>'


def circle(cx, cy, r, fill, sw=3, stroke=OL, extra=""):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" {_st(sw, stroke)} {extra}/>'


def ellipse(cx, cy, rx, ry, fill, sw=3, stroke=OL, extra=""):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" {_st(sw, stroke)} {extra}/>'


def path(d, fill, sw=3, stroke=OL, extra=""):
    return f'<path d="{d}" fill="{fill}" {_st(sw, stroke)} {extra}/>'


def poly(points, fill, sw=3, stroke=OL):
    pts = " ".join(f"{x},{y}" for x, y in points)
    return f'<polygon points="{pts}" fill="{fill}" {_st(sw, stroke)}/>'


def svg(w, h, parts, defs="", scale=2):
    d = f"<defs>{defs}</defs>" if defs else ""
    body = "\n  ".join(parts)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * scale}" height="{h * scale}" '
            f'viewBox="0 0 {w} {h}">\n  {d}\n  {body}\n</svg>\n')


def save(rel, text):
    p = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
    print("yazıldı:", os.path.relpath(p))


def suit(kind, x, y, s, fill, sw=1.5):
    """Kart simgesi; (x, y) sol üst köşe, s boyut."""
    k = s / 20.0
    if kind == "heart":
        d = "M10 20 C4 15 0 11 0 6 C0 2 3 0 6 0 C8 0 9.5 1.5 10 3 C10.5 1.5 12 0 14 0 C17 0 20 2 20 6 C20 11 16 15 10 20Z"
    elif kind == "diamond":
        d = "M10 0 L19 10 L10 20 L1 10Z"
    elif kind == "spade":
        d = "M10 0 C14 5 20 8 20 13 C20 16.5 17 18 14.5 17 C13 16.5 12 15.5 11 14.5 L13 20 H7 L9 14.5 C8 15.5 7 16.5 5.5 17 C3 18 0 16.5 0 13 C0 8 6 5 10 0Z"
    else:  # club
        d = ("M10 0 C13 0 15 2 15 5 C15 6.5 14.5 7.5 13.8 8.3 C14.5 8 15.3 7.8 16 7.8 C18.5 7.8 20 9.8 20 12.3 "
             "C20 14.8 18 16.6 15.6 16.6 C14 16.6 12.4 15.6 11.4 14.2 L13 20 H7 L8.6 14.2 C7.6 15.6 6 16.6 4.4 16.6 "
             "C2 16.6 0 14.8 0 12.3 C0 9.8 1.5 7.8 4 7.8 C4.7 7.8 5.5 8 6.2 8.3 C5.5 7.5 5 6.5 5 5 C5 2 7 0 10 0Z")
    return path(d, fill, sw / k, OL, f'transform="translate({x} {y}) scale({k})"')


def blob(circles, fill, outline=OL, ow=5):
    """Kesişen dairelerden tek dış çizgili yuvarlak şekil (ağaç, çalı)."""
    out = [circle(cx, cy, r + ow / 2, outline, 0) for cx, cy, r in circles]
    out += [circle(cx, cy, r, fill, 0) for cx, cy, r in circles]
    return out


def sign_plate(w, fill, border=OL):
    """Tabela: yazıyı oyun çizer (y = 86..118)."""
    return rect(w / 2 - 92, 86, 184, 32, fill, 7, 3, border)


# ---------------------------------------------------------------- binalar

def hospital():
    W, H = 380, 260
    p = [
        rect(4, 4, W - 8, 80, "#d6dbe4", 8),
        rect(16, 14, W - 32, 60, "#c3c9d4", 5, 2),
        circle(74, 44, 25, "#4b5563"),
        circle(74, 44, 19, "none", 2.5, "#facc15"),
        path("M65 33v22M83 33v22M65 44h18", "none", 4.5, "#f8fafc"),
        path("M180 22h20v12h12v20h-12v12h-20v-12h-12v-20h12z", "#ef4444"),
        rect(282, 28, 28, 22, "#eef0f3", 3, 2), rect(320, 28, 28, 22, "#eef0f3", 3, 2),
        circle(296, 39, 7, "#9ca3af", 1.5), circle(334, 39, 7, "#9ca3af", 1.5),
        rect(4, 82, W - 8, 174, "#f8fafc"),
        rect(4, 236, W - 8, 20, "#cbd5e1"),
        rect(4, 122, W - 8, 5, "#ef4444", 0, 0),
    ]
    for y in (136, 184):
        for x in (18, 62, 106, 238, 282, 326):
            p.append(rect(x, y, 36, 32, "url(#glass)", 3, 2.5))
            p.append(path(f"M{x + 18} {y}v32", "none", 1.5))
    p += [
        rect(146, 172, 88, 14, "#ef4444", 3),
        rect(156, 186, 33, 50, "url(#glass)", 2, 2.5), rect(191, 186, 33, 50, "url(#glass)", 2, 2.5),
        circle(138, 228, 9, "#22c55e", 2.5), circle(242, 228, 9, "#22c55e", 2.5),
        sign_plate(W, "#dc2626"),
    ]
    save("buildings/hospital.svg", svg(W, H, p, GLASS))


def market():
    W, H = 340, 260
    p = [rect(4, 4, W - 8, 80, "#4d7c5a", 8)]
    for y in (24, 44, 64):
        p.append(path(f"M12 {y}H{W - 12}", "none", 2, "#3b6347"))
    p += [
        rect(250, 20, 44, 26, "#d1d5db", 3, 2), path("M256 33h32", "none", 2),
        rect(4, 82, W - 8, 174, "#fdf2d0"),
        rect(4, 236, W - 8, 20, "#d6c39a"),
    ]
    for i, x in enumerate(range(8, W - 8, 20)):
        p.append(rect(x, 124, 20, 22, "#ef4444" if i % 2 == 0 else "#ffffff", 0, 0))
    p.append(rect(8, 124, W - 16, 22, "none", 0, 2.5))
    for i, x in enumerate(range(8, W - 8, 20)):
        p.append(path(f"M{x} 146 a10 9 0 0 0 20 0z", "#ef4444" if i % 2 == 0 else "#ffffff", 2))
    # vitrinler ve meyve kasaları
    for wx, fruits in ((18, ("#dc2626", "#f97316")), (204, ("#65a30d", "#facc15"))):
        p.append(rect(wx, 160, 118, 66, "url(#glass)", 4, 2.5))
        for j, col in enumerate(fruits):
            cx0 = wx + 8 + j * 56
            for k in range(4):
                p.append(circle(cx0 + 6 + k * 11, 206, 6, col, 1.5))
            p.append(rect(cx0, 208, 48, 16, "#a16207", 2, 2))
    p += [
        rect(146, 158, 48, 78, "url(#glass)", 3, 2.5), path("M170 158v78", "none", 2),
        sign_plate(W, "#15803d"),
    ]
    save("buildings/market.svg", svg(W, H, p, GLASS))


def casino():
    W, H = 380, 260
    p = [
        rect(4, 4, W - 8, 80, "#2e1065", 8),
        rect(14, 14, W - 28, 60, "none", 6, 3, "#eab308"),
    ]
    for x in range(24, W - 20, 22):
        p += [circle(x, 14, 3, "#fde047", 0), circle(x, 74, 3, "#fde047", 0)]
    p += [
        circle(190, 44, 24, "#dc2626"), circle(190, 44, 15, "#fef2f2", 2), circle(190, 44, 9, "#dc2626", 0),
    ]
    for a in range(0, 360, 45):
        r = math.radians(a)
        p.append(circle(round(190 + 20 * math.cos(r), 1), round(44 + 20 * math.sin(r), 1), 3, "#fef2f2", 0))
    p += [
        rect(4, 82, W - 8, 174, "#581c87"),
        rect(4, 236, W - 8, 20, "#3b0764"),
    ]
    for x in (20, 70, 294, 344):
        p += [rect(x, 126, 16, 110, "#eab308", 0, 2.5), rect(x - 4, 120, 24, 8, "#facc15", 2, 2.5)]
    for x in (42, 316):
        p.append(rect(x, 144, 22, 62, "url(#warm)", 11, 2.5))
    p.append(path("M120 236V178A70 46 0 0 1 260 178V236Z", "#7f1d1d"))
    for k in range(13):
        a = math.pi - k * math.pi / 12
        p.append(circle(round(190 + 70 * math.cos(a), 1), round(178 - 46 * math.sin(a), 1), 3.5, "#fde047", 1.5))
    p += [
        rect(160, 180, 60, 56, "#450a0a", 3), path("M190 180v56", "none", 2, "#eab308"),
        circle(184, 210, 2.5, "#eab308", 0), circle(196, 210, 2.5, "#eab308", 0),
        poly([(162, 236), (218, 236), (232, 256), (148, 256)], "#b91c1c", 2),
        circle(100, 196, 14, "#dc2626"), circle(100, 196, 8, "#fef2f2", 2),
        circle(280, 196, 14, "#111827"), circle(280, 196, 8, "#e5e7eb", 2),
        sign_plate(W, "#a16207", "#fde047"),
    ]
    save("buildings/casino.svg", svg(W, H, p, WARM))


def poker():
    W, H = 360, 260
    p = [
        rect(4, 4, W - 8, 80, "#1f2937", 8),
        ellipse(180, 44, 92, 28, "#7c2d12"),
        ellipse(180, 44, 80, 20, "#15803d", 2),
        rect(160, 36, 12, 16, "#ffffff", 2, 1.5), rect(176, 36, 12, 16, "#ffffff", 2, 1.5), rect(192, 36, 12, 16, "#ffffff", 2, 1.5),
        circle(130, 44, 4, "#dc2626", 1.5), circle(138, 50, 4, "#2563eb", 1.5), circle(226, 40, 4, "#111827", 1.5),
        suit("spade", 22, 30, 16, "#ca8a04"), suit("heart", 322, 30, 16, "#ca8a04"),
        rect(4, 82, W - 8, 174, "#064e3b"),
        rect(4, 122, W - 8, 4, "#ca8a04", 0, 0),
        rect(4, 236, W - 8, 20, "#022c22"),
    ]
    for x, s in ((22, "spade"), (72, "heart"), (252, "diamond"), (302, "club")):
        red = s in ("heart", "diamond")
        p.append(suit(s, x + 10, 130, 16, "#dc2626" if red else "#f8fafc"))
        p.append(path(f"M{x} 214V170A18 18 0 0 1 {x + 36} 170V214Z", "url(#warm)", 2.5))
        p.append(path(f"M{x + 18} 152V214M{x} 186H{x + 36}", "none", 2))
    p += [
        rect(146, 150, 68, 86, "#78350f", 4, 3), rect(152, 156, 56, 80, "none", 2, 2, "#ca8a04"),
        path("M180 156v80", "none", 2), circle(174, 196, 3, "#facc15", 1), circle(186, 196, 3, "#facc15", 1),
        rect(128, 172, 4, 64, "#1f2937", 0, 1.5), circle(130, 168, 7, "#fde68a", 2),
        rect(228, 172, 4, 64, "#1f2937", 0, 1.5), circle(230, 168, 7, "#fde68a", 2),
        sign_plate(W, "#111827", "#ca8a04"),
    ]
    save("buildings/poker.svg", svg(W, H, p, WARM))


def realestate():
    W, H = 300, 260
    p = [
        rect(230, 8, 24, 34, "#9a3412", 2),
        rect(4, 18, W - 8, 66, "#1d4ed8", 6),
    ]
    for x in range(22, W - 8, 18):
        p.append(path(f"M{x} 20V82", "none", 1.5, "#1e40af"))
    p += [
        path(f"M6 50H{W - 6}", "none", 3, "#1e3a8a"),
        rect(4, 82, W - 8, 174, "#f1f5f9"),
        rect(4, 222, W - 8, 34, "#b45309"),
    ]
    for y in (230, 240, 250):
        p.append(path(f"M6 {y}H{W - 6}", "none", 1, "#78350f"))
    for x in (20, 200):
        p += [rect(x, 136, 80, 60, "url(#glass)", 3, 2.5), path(f"M{x + 40} 136v60M{x} 166h80", "none", 2)]
    p += [
        rect(126, 146, 48, 76, "#1e3a8a", 3), circle(150, 170, 8, "url(#glass)", 2), circle(166, 190, 2.5, "#facc15", 0),
        rect(118, 222, 64, 8, "#94a3b8", 2, 2),
        rect(258, 210, 4, 22, "#78350f", 0, 1.5),
        rect(238, 192, 44, 22, "#fef3c7", 3, 2.5, "#dc2626"),
        path("M246 199h28M246 206h20", "none", 2, "#dc2626"),
        sign_plate(W, "#1e40af"),
    ]
    save("buildings/realestate.svg", svg(W, H, p, GLASS))


# ---------------------------------------------------------------- arsa yapıları

def house():
    W, H = 130, 120
    p = [
        rect(90, 16, 14, 28, "#9a3412", 1),
        poly([(6, 58), (65, 10), (124, 58)], "#c2410c"),
        path("M24 44L65 12M40 50L65 30M106 44L65 12", "none", 1.5, "#9a3412"),
        rect(16, 56, 98, 58, "#fde68a"),
        rect(55, 78, 22, 36, "#92400e", 2), circle(72, 97, 2, "#facc15", 0),
        rect(24, 68, 22, 20, "url(#glass)", 2, 2.5), path("M35 68v20M24 78h22", "none", 1.5),
        rect(86, 68, 22, 20, "url(#glass)", 2, 2.5), path("M97 68v20M86 78h22", "none", 1.5),
    ]
    p += blob([(10, 110, 9), (20, 113, 7)], "#22a34a") + blob([(120, 110, 9), (110, 113, 7)], "#22a34a")
    save("plots/house.svg", svg(W, H, p, GLASS))


def villa():
    W, H = 220, 130
    p = [
        rect(6, 8, 152, 32, "#d1d5db", 4),
    ]
    p += blob([(20, 22, 7), (32, 20, 6)], "#22a34a", ow=3)
    p += [
        rect(120, 14, 30, 18, "#38bdf8", 3, 2),
        rect(6, 38, 152, 86, "#ffffff"),
        rect(16, 48, 132, 26, "url(#glass)", 2, 2.5),
        path("M49 48v26M82 48v26M115 48v26", "none", 1.5),
        rect(6, 76, 152, 6, "#9ca3af", 0, 2),
        rect(16, 86, 50, 38, "url(#glass)", 2, 2.5), rect(98, 86, 50, 38, "url(#glass)", 2, 2.5),
        rect(72, 92, 20, 32, "#78350f", 2),
        rect(164, 36, 52, 88, "#e5e7eb", 8),
        rect(170, 42, 40, 76, "#38bdf8", 6, 2),
        path("M176 60q5-4 10 0t10 0M176 80q5-4 10 0t10 0M176 100q5-4 10 0t10 0", "none", 2, "#e0f2fe"),
    ]
    save("plots/villa.svg", svg(W, H, p, GLASS))


def tower():
    W, H = 110, 170
    p = [
        rect(53, 2, 4, 14, "#64748b", 0, 1.5), circle(55, 3, 3, "#ef4444", 1),
        rect(10, 14, 90, 18, "#94a3b8", 3),
        rect(10, 30, 90, 136, "#1e3a8a"),
        rect(78, 30, 22, 136, "#000000", 0, 0, OL, 'opacity="0.18"'),
    ]
    lit = "#fde68a"
    for r, y in enumerate(range(38, 146, 14)):
        for c, x in enumerate((18, 36, 54, 72, 86)):
            on = (r * 7 + c * 3) % 5 not in (1, 3)
            p.append(rect(x, y, 10 if x < 86 else 8, 8, lit if on else "#60a5fa", 1, 0))
    p += [rect(40, 146, 30, 20, "url(#glass)", 2, 2.5)]
    save("plots/tower.svg", svg(W, H, p, GLASS))


# ---------------------------------------------------------------- doğa

def trees():
    W, H = 70, 80
    p = [rect(30, 48, 10, 26, "#7c4a1e", 2, 2.5)]
    p += blob([(35, 30, 24), (20, 40, 15), (50, 40, 15)], "#2f7d32")
    p += [circle(27, 22, 9, "#4caf50", 0), circle(45, 30, 6, "#4caf50", 0), circle(20, 38, 5, "#4caf50", 0)]
    save("nature/tree_round.svg", svg(W, H, p))

    W, H = 60, 86
    p = [rect(26, 66, 8, 16, "#7c4a1e", 1, 2.5)]
    tris = [[(30, 4), (50, 32), (10, 32)], [(30, 18), (54, 50), (6, 50)], [(30, 34), (57, 70), (3, 70)]]
    for t in tris:
        p.append(poly(t, OL, 6))
    for t in tris:
        p.append(poly(t, "#166534", 0))
    p += [poly([(30, 8), (36, 18), (26, 22)], "#22803d", 0), poly([(30, 24), (38, 36), (24, 40)], "#22803d", 0)]
    save("nature/tree_pine.svg", svg(W, H, p))

    W, H = 48, 34
    p = blob([(14, 20, 11), (26, 15, 12), (36, 21, 10)], "#3f8a3a")
    p += [circle(22, 11, 4, "#5fb35a", 0), circle(12, 15, 3, "#e11d48", 0), circle(34, 24, 3, "#facc15", 0)]
    save("nature/bush.svg", svg(W, H, p))


# ---------------------------------------------------------------- plaj

def beach():
    # Palmiye
    W, H = 90, 120
    p = [path("M44 116C46 92 40 70 48 40", "none", 11, OL), path("M44 116C46 92 40 70 48 40", "none", 7, "#a16207")]
    for y in (100, 86, 72, 58):
        p.append(path(f"M{39 + (y - 40) * 0.0} {y}h10", "none", 1.5, "#713f12"))
    leaves = ["M48 40C36 28 18 30 6 42C20 36 34 38 48 42Z", "M48 40C60 26 78 28 88 40C74 34 62 36 48 42Z",
              "M48 40C42 22 30 10 16 8C30 16 40 28 46 42Z", "M48 40C56 22 68 12 82 12C68 20 58 30 50 42Z",
              "M48 40C48 26 50 14 56 4C54 18 52 30 50 42Z"]
    for d in leaves:
        p.append(path(d, "#16a34a", 2.5))
    p += [circle(44, 44, 4.5, "#78350f", 2), circle(52, 45, 4.5, "#78350f", 2)]
    save("beach/palm.svg", svg(W, H, p))

    # Şemsiyeler (üstten 3/4 görünüm)
    for name, col in (("umbrella_red", "#ef4444"), ("umbrella_blue", "#3b82f6"), ("umbrella_yellow", "#f59e0b")):
        W, H = 96, 100
        cx, cy, rx, ry = 48, 36, 44, 30
        p = [rect(46, 36, 4, 60, "#e5e7eb", 1, 2)]
        for k in range(8):
            a1, a2 = k * math.pi / 4, (k + 1) * math.pi / 4
            x1, y1 = cx + rx * math.cos(a1), cy + ry * math.sin(a1)
            x2, y2 = cx + rx * math.cos(a2), cy + ry * math.sin(a2)
            p.append(path(f"M{cx} {cy}L{x1:.1f} {y1:.1f}A{rx} {ry} 0 0 1 {x2:.1f} {y2:.1f}Z",
                          col if k % 2 == 0 else "#ffffff", 2))
        p.append(circle(cx, cy, 3.5, "#e5e7eb", 1.5))
        save(f"beach/{name}.svg", svg(W, H, p))

    # Şezlong + havlu
    W, H = 44, 76
    p = [rect(4, 4, 36, 68, "#d6b47a", 5), rect(9, 9, 26, 22, "#ffffff", 4, 2)]
    for y in range(34, 68, 8):
        p.append(path(f"M6 {y}h32", "none", 1.5, "#a07a3f"))
    p.append(rect(10, 36, 24, 30, "#38bdf8", 3, 2))
    p.append(path("M10 44h24M10 52h24M10 60h24", "none", 2, "#ffffff"))
    save("beach/sunbed.svg", svg(W, H, p))

    # Cankurtaran kulesi
    W, H = 90, 130
    p = [
        path("M22 128L32 70M68 128L58 70M26 104H64", "none", 5, "#a16207"),
        rect(20, 62, 50, 10, "#e5e7eb", 2),
        rect(24, 26, 42, 38, "#ef4444", 3), rect(24, 38, 42, 10, "#ffffff", 0, 2),
        poly([(18, 28), (45, 10), (72, 28)], "#ffffff"),
        rect(44, 2, 3, 12, "#374151", 0, 1.5), poly([(47, 2), (62, 6), (47, 10)], "#ef4444", 1.5),
        path("M30 104L36 128M60 104L54 128", "none", 3, "#a16207"),
    ]
    save("beach/lifeguard.svg", svg(W, H, p))

    # Sandal
    W, H = 130, 60
    p = [
        path("M6 22C30 12 100 12 124 22C118 46 100 54 65 54C30 54 12 46 6 22Z", "#b45309"),
        path("M16 24C38 18 92 18 114 24C108 40 94 46 65 46C36 46 22 40 16 24Z", "#f5deb3", 2),
        rect(40, 22, 6, 24, "#92400e", 1, 1.5), rect(84, 22, 6, 24, "#92400e", 1, 1.5),
        path("M30 30L2 4M100 30L128 4", "none", 4, "#78350f"),
        path("M6 22C30 12 100 12 124 22", "none", 3, "#ffffff"),
    ]
    save("beach/boat.svg", svg(W, H, p))

    # Kumdan kale
    W, H = 64, 54
    p = [rect(6, 26, 52, 24, "#e9c97c", 2)]
    for x in (4, 24, 44):
        p += [rect(x, 12, 16, 38, "#f0d48f", 1), path(f"M{x} 12v-5h4v5h4v-5h4v5", "#f0d48f", 2)]
    p += [rect(28, 34, 8, 16, "#a07a3f", 4, 1.5), path("M32 7V0", "none", 1.5), poly([(32, 0), (42, 3), (32, 6)], "#ef4444", 1)]
    save("beach/sandcastle.svg", svg(W, H, p))


# ---------------------------------------------------------------- karakterler
# Sayfa: 3 sütun (kare: 0 durma, 1 ve 2 adım) x 3 satır (0 aşağı/ön, 1 yukarı/arka, 2 sağa/yan).
# Hücre 48x64. Katmanlar beyaza yakın çizilir; oyun her birini seçilen renkle çarparak boyar:
#   legs  (pantolon rengi; ayakkabılar koyu kalır)
#   skin  (ten rengi; yüz ayrıntıları dahil)
#   shirt (tişört rengi)
#   hair_short / hair_long / hair_bun / hair_spiky (saç rengi; "kel" için hiç çizilmez)
# Sola bakış, yan satırın aynalanmasıdır.

CW, CH = 48, 64
WHITE = "#fbfbfc"
SHADE = "#cdd3dc"
SHOE = "#2a2f3a"
CSW = 1.4
HAIR_STYLES = ("short", "long", "bun", "spiky")

# Saç: (ön, arka, yan) şekilleri
HAIR = {
    "short": (
        "M11.8 19C10.5 8 17 4 24 4C31 4 37.5 8 36.2 19C34 13.5 30 11 26 11.5C23 12 20 14.5 18 14C15.5 13.5 13.5 16 11.8 19Z",
        "M11.6 17.5C11.6 7 17.5 4 24 4C30.5 4 36.4 7 36.4 17.5C36.4 23.5 31 27 24 27C17 27 11.6 23.5 11.6 17.5Z",
        "M13.4 18.5C12.6 7.5 18.5 4 25 4C32 4 37.6 8 37 15C33.5 12 30 11.2 27.2 12.3C26 15.5 24 17 21.8 19C20.6 23 18 25.5 15.6 24.4C14.2 23 13.6 21 13.4 18.5Z",
    ),
    "long": (
        "M11.5 19C10.5 8 17 4 24 4C31 4 37.5 8 36.5 19L37.5 33C35 35 33 34 32.5 31L32 20C30 14 27 12.5 24 12.5C21 12.5 18 14 16 20L15.5 31C15 34 13 35 10.5 33Z",
        "M11.6 17.5C11.6 7 17.5 4 24 4C30.5 4 36.4 7 36.4 17.5L37.5 33C33 36 15 36 10.5 33Z",
        "M13.4 18.5C12.6 7.5 18.5 4 25 4C32 4 37.6 8 37 15C33.5 12 30 11.2 27.2 12.3C26 15.5 24 17 22.5 20L22.5 32C19 34.5 15 34 12.5 32Z",
    ),
    "bun": (
        "M11.8 19C10.5 8 17 5 24 5C31 5 37.5 8 36.2 19C34 13.5 30 11.5 24 11.5C18 11.5 14 13.5 11.8 19Z",
        "M11.6 17.5C11.6 7 17.5 5 24 5C30.5 5 36.4 7 36.4 17.5C36.4 23.5 31 27 24 27C17 27 11.6 23.5 11.6 17.5Z",
        "M13.4 18.5C12.6 7.5 18.5 5 25 5C32 5 37.6 8 37 15C33.5 12 30 11.2 27 12C24 13 22 16 20.5 20C19 23.5 15.5 24 14 22C13.6 21 13.4 19.8 13.4 18.5Z",
    ),
    "spiky": (
        "M12 18L10.5 9.5L15 11.5L14.5 4.5L19.5 8.5L22.5 1.5L25.5 8L30 2.5L30.5 9.5L35.5 5.5L34.5 12L37.5 11.5L36.2 19C34 14 30 12 26 12.5C23 13 19.5 15 17.5 14.5C15 14 13.5 16 12 18Z",
        "M11.6 17.5L10.5 9.5L15 10.5L15 3.5L20 7.5L24 1.5L28 7.5L33 3.5L33 10.5L37.5 9.5L36.4 17.5C36.4 23.5 31 27 24 27C17 27 11.6 23.5 11.6 17.5Z",
        "M13.4 18.5L11 11L15.5 11.5L14.5 5L20 8L22.5 1.5L26.5 7.5L31 3L31.5 9L37 9.5L37 15C33.5 12 30 11.2 27.2 12.3C26 15.5 24 17 21.8 19C20.6 23 18 25.5 15.6 24.4C14.2 23 13.6 21 13.4 18.5Z",
    ),
}


def char_cell(layer, row, frame):
    step = [0, 1, -1][frame]
    p = []
    if layer.startswith("hair_"):
        style = layer[5:]
        p.append(path(HAIR[style][row], WHITE, CSW))
        if style == "bun":
            bx, by = ((24, 4.5), (24, 4.5), (15, 7.5))[row]
            p.append(circle(bx, by, 4.6, WHITE, CSW))
        if row != 1 and style != "spiky":
            p.append(path("M18 7.5Q23 5.5 28 7.5" if row == 0 else "M20 8Q26 6 31 8.5", "none", 1, SHADE))
        return p
    if row in (0, 1):            # ön ve arka görünüm
        dl, dr = (-2, 0) if step == 1 else ((0, -2) if step == -1 else (0, 0))
        al, ar = (2, -1) if step == 1 else ((-1, 2) if step == -1 else (0, 0))
        if row == 1:
            al, ar = ar, al
        if layer == "legs":
            p += [
                rect(17, 44 + dl, 6, 12, WHITE, 2, CSW), rect(25, 44 + dr, 6, 12, WHITE, 2, CSW),
                ellipse(20, 57 + dl, 4.2, 2.6, SHOE, CSW), ellipse(28, 57 + dr, 4.2, 2.6, SHOE, CSW),
            ]
        elif layer == "skin":
            p += [
                circle(11.5, 45 + al, 3, WHITE, CSW), circle(36.5, 45 + ar, 3, WHITE, CSW),
                rect(21, 26, 6, 5, WHITE, 0, CSW),
                circle(12.5, 18, 2.6, WHITE, CSW), circle(35.5, 18, 2.6, WHITE, CSW),
                circle(24, 17, 12, WHITE, CSW),
            ]
            if row == 0:
                p += [
                    ellipse(19.5, 19, 1.8, 2.3, OL, 0), ellipse(28.5, 19, 1.8, 2.3, OL, 0),
                    ellipse(16, 23, 2.2, 1.3, "#f472b6", 0, extra='opacity="0.45"'),
                    ellipse(32, 23, 2.2, 1.3, "#f472b6", 0, extra='opacity="0.45"'),
                    path("M21.5 24Q24 26.5 26.5 24", "none", 1.2),
                ]
        elif layer == "shirt":
            p += [
                rect(8.5, 30 + al, 6, 12, WHITE, 3, CSW), rect(33.5, 30 + ar, 6, 12, WHITE, 3, CSW),
                rect(13, 29, 22, 17, WHITE, 5, CSW),
                path("M15 41h18", "none", 1.2, SHADE),
            ]
            if row == 0:
                p.append(path("M20 29.5L24 33.5L28 29.5", "none", 1.2, SHADE))
    else:                        # sağa bakan yan görünüm
        back, front = (-3, 3) if step == 1 else ((3, -3) if step == -1 else (0, 0))
        swing = [0, -3, 3][frame]
        if layer == "legs":
            p += [
                rect(20 + back, 44, 6, 12, SHADE, 2, CSW), ellipse(24 + back, 57, 4.6, 2.6, SHOE, CSW),
                rect(22 + front, 44, 6, 12, WHITE, 2, CSW), ellipse(26 + front, 57, 4.6, 2.6, SHOE, CSW),
            ]
        elif layer == "skin":
            p += [
                rect(22, 26, 6, 5, WHITE, 0, CSW),
                circle(25, 17, 12, WHITE, CSW),
                path("M36.5 17.5Q39 19 36.6 20.5", WHITE, CSW),
                ellipse(31.5, 18.6, 1.6, 2.2, OL, 0),
                ellipse(30, 23, 2, 1.2, "#f472b6", 0, extra='opacity="0.45"'),
                path("M31 24.5Q33 25.5 34.5 24", "none", 1.2),
                circle(25 + swing * 0.9, 47.5, 2.8, WHITE, CSW),
            ]
        elif layer == "shirt":
            p += [
                rect(16, 29, 17, 17, WHITE, 5, CSW),
                path("M18 41h13", "none", 1.2, SHADE),
                rect(21.5 + swing * 0.7, 30, 6, 15, "#e3e7ee", 3, CSW),
            ]
    return p


def characters():
    old = os.path.join(ROOT, "characters")
    for f in ("base.svg", "base.svg.import", "hair.svg", "hair.svg.import"):
        if os.path.exists(os.path.join(old, f)):
            os.remove(os.path.join(old, f))
    for layer in ("legs", "skin", "shirt") + tuple("hair_" + h for h in HAIR_STYLES):
        parts = []
        for row in range(3):
            for frame in range(3):
                g = char_cell(layer, row, frame)
                parts.append(f'<g transform="translate({frame * CW} {row * CH})">' + "".join(g) + "</g>")
        save(f"characters/{layer}.svg", svg(CW * 3, CH * 3, parts))


if __name__ == "__main__":
    hospital()
    market()
    casino()
    poker()
    realestate()
    house()
    villa()
    tower()
    trees()
    beach()
    characters()
