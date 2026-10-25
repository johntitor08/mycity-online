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


# ---------------------------------------------------------------- 0.4: yeni binalar

def galeri():
    W, H = 320, 220
    p = [
        rect(4, 4, W - 8, 70, "#334155", 8),
        path(f"M14 40H{W - 14}", "none", 3, "#facc15"),
        rect(4, 72, W - 8, 144, "#e2e8f0"),
        rect(4, 196, W - 8, 20, "#94a3b8"),
        rect(16, 120, 288, 76, "url(#glass)", 4, 3),
        path("M112 120v76M208 120v76", "none", 2),
    ]
    # vitrindeki araba (yandan)
    p += [path("M40 180C42 160 60 152 80 150L104 140C116 134 132 134 142 140L160 152C172 154 178 162 178 180Z", "#ef4444", 2.5),
          rect(96, 144, 20, 10, "#bae6fd", 2, 1.5), rect(120, 144, 18, 10, "#bae6fd", 2, 1.5),
          circle(70, 182, 9, "#1f2937", 2), circle(150, 182, 9, "#1f2937", 2),
          circle(70, 182, 3, "#9ca3af", 0), circle(150, 182, 3, "#9ca3af", 0)]
    # bisiklet
    p += [circle(230, 182, 11, "none", 2.5), circle(268, 182, 11, "none", 2.5),
          path("M230 182L246 162L268 182M246 162L258 162M240 158h10", "none", 2.5, "#2563eb")]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#0f172a", 7, 3, "#facc15"))
    save("buildings/galeri.svg", svg(W, H, p, GLASS))


def mobilya():
    W, H = 320, 220
    p = [
        poly([(4, 74), (40, 6), (280, 6), (316, 74)], "#a16207"),
        path("M40 6L60 74M100 6L110 74M160 6V74M220 6L210 74M280 6L260 74", "none", 1.5, "#78350f"),
        rect(4, 72, W - 8, 144, "#fef3c7"),
        rect(4, 196, W - 8, 20, "#d6c39a"),
        rect(16, 120, 120, 76, "url(#glass)", 4, 3),
        rect(184, 120, 120, 76, "url(#glass)", 4, 3),
        # vitrin: koltuk ve lamba
        rect(28, 162, 70, 24, "#8b5cf6", 6, 2), rect(28, 150, 70, 16, "#7c3aed", 6, 2),
        rect(110, 140, 4, 46, "#374151", 0, 1.5), path("M100 140h24l-6-14h-12z", "#fde68a", 2),
        # vitrin: saksı ve kitaplık
        rect(196, 132, 44, 56, "#92400e", 2, 2), path("M200 148h36M200 166h36", "none", 2),
        rect(262, 170, 18, 18, "#b45309", 3, 2), circle(271, 160, 12, "#22c55e", 2),
        rect(142, 140, 36, 76, "#78350f", 3, 3), circle(170, 180, 2.5, "#facc15", 0),
    ]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#78350f", 7, 3))
    save("buildings/mobilya.svg", svg(W, H, p, GLASS))


def pazar():
    W, H = 320, 220
    p = [rect(4, 70, W - 8, 146, "#fde7c4", 6), rect(4, 196, W - 8, 20, "#d6b98a")]
    # tenteli tezgâhlar
    for i, (x, col) in enumerate(((14, "#ef4444"), (116, "#22c55e"), (218, "#3b82f6"))):
        p.append(rect(x + 6, 134, 76, 56, "#a16207", 3, 2.5))
        for k in range(4):
            p.append(rect(x + k * 22, 112, 22, 22, col if k % 2 == 0 else "#ffffff", 0, 0))
        p.append(rect(x, 112, 88, 22, "none", 0, 2.5))
        for k in range(4):
            p.append(path(f"M{x + k * 22} 134a11 8 0 0 0 22 0z", col if k % 2 == 0 else "#ffffff", 2))
        goods = (("#f97316", "#dc2626"), ("#84cc16", "#facc15"), ("#38bdf8", "#e879f9"))[i]
        for k in range(5):
            p.append(circle(x + 16 + k * 14, 150 - (k % 2) * 4, 6, goods[k % 2], 1.5))
    p += [rect(4, 4, W - 8, 64, "#9a3412", 8), path(f"M14 34H{W - 14}", "none", 2, "#fdba74")]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#9a3412", 7, 3))
    # tabela y=86..118 kuralına uymak için tabelayı aşağı kaydır
    p[-1] = rect(W / 2 - 92, 76, 184, 32, "#9a3412", 7, 3)
    save("buildings/pazar.svg", svg(W, H, p))


# ---------------------------------------------------------------- 0.4: araçlar (üstten, sağa bakar)

def vehicles():
    # Araba gövdesi (beyaz: oyuncu rengiyle boyanır) + sabit ayrıntılar
    W, H = 96, 52
    body = [rect(6, 6, 84, 40, "#f8fafc", 14, 3), path("M20 10h40M20 42h40", "none", 1.5, "#cbd5e1")]
    save("vehicles/car_body.svg", svg(W, H, body))
    det = [
        rect(10, 2, 16, 8, "#111827", 3, 1.5), rect(66, 2, 16, 8, "#111827", 3, 1.5),
        rect(10, 42, 16, 8, "#111827", 3, 1.5), rect(66, 42, 16, 8, "#111827", 3, 1.5),
        path("M58 12L70 16V36L58 40Z", "#7dd3fc", 2),            # ön cam
        path("M22 14L30 16V36L22 38Z", "#7dd3fc", 2),             # arka cam
        rect(32, 15, 24, 22, "#000000", 4, 0, OL, 'opacity="0.12"'),  # tavan gölgesi
        rect(86, 10, 5, 8, "#fef08a", 2, 1), rect(86, 34, 5, 8, "#fef08a", 2, 1),
        rect(5, 10, 4, 8, "#ef4444", 1, 1), rect(5, 34, 4, 8, "#ef4444", 1, 1),
    ]
    save("vehicles/car_detail.svg", svg(W, H, det))
    # Bisiklet (üstten)
    W, H = 64, 24
    p = [rect(2, 9, 18, 6, "#1f2937", 3, 1.5), rect(44, 9, 18, 6, "#1f2937", 3, 1.5),
         path("M12 12H52", "none", 3, "#2563eb"), path("M46 4V20", "none", 3, "#374151"),
         rect(22, 8, 10, 8, "#111827", 3, 1.5)]
    save("vehicles/bike.svg", svg(W, H, p))


# ---------------------------------------------------------------- 0.4: mobilyalar (üstten, 1 karo = 48 birim)

T = 48


def furniture():
    items = {}
    # yatak 2x3
    w, h = 2 * T, 3 * T
    items["bed"] = (w, h, [rect(3, 3, w - 6, h - 6, "#92400e", 6), rect(9, 9, w - 18, h - 18, "#f8fafc", 4, 2),
                           rect(14, 14, w - 28, 26, "#e0e7ff", 6, 2), rect(9, 52, w - 18, h - 61, "#60a5fa", 4, 2),
                           path(f"M9 60H{w - 9}", "none", 2, "#93c5fd")])
    # koltuk 3x1 (+derinlik için 3x1.4)
    w, h = 3 * T, int(1.4 * T)
    items["sofa"] = (w, h, [rect(3, 3, w - 6, h - 6, "#7c3aed", 10), rect(14, 18, w - 28, h - 24, "#a78bfa", 6, 2),
                            path(f"M{w / 3} 20V{h - 8}M{2 * w / 3} 20V{h - 8}", "none", 2, "#7c3aed")])
    w = h = T
    items["armchair"] = (w, h, [rect(3, 3, w - 6, h - 6, "#b45309", 10), rect(11, 14, w - 22, h - 20, "#f59e0b", 6, 2)])
    w = h = 2 * T
    items["table"] = (w, h, [ellipse(w / 2, h / 2, w / 2 - 6, h / 2 - 6, "#a16207"),
                             ellipse(w / 2, h / 2, w / 2 - 16, h / 2 - 16, "none", 1.5, "#78350f"),
                             circle(w / 2 - 12, h / 2 - 6, 7, "#f8fafc", 1.5), circle(w / 2 + 14, h / 2 + 8, 5, "#ef4444", 1.5)])
    w = h = T
    items["chair"] = (w, h, [rect(8, 8, w - 16, h - 16, "#a16207", 4), rect(8, 6, w - 16, 9, "#78350f", 3, 2)])
    w, h = 2 * T, T
    items["tv"] = (w, h, [rect(8, 22, w - 16, 20, "#57534e", 3, 2), rect(10, 6, w - 20, 16, "#111827", 2, 2.5),
                          rect(14, 9, w - 28, 10, "#38bdf8", 1, 0, OL, 'opacity="0.7"')])
    w = h = T
    items["plant"] = (w, h, [circle(w / 2, h / 2, 14, "#b45309"), circle(w / 2 - 6, h / 2 - 4, 11, "#16a34a", 2),
                             circle(w / 2 + 7, h / 2 - 2, 10, "#22c55e", 2), circle(w / 2, h / 2 + 6, 9, "#15803d", 2)])
    w, h = 3 * T, 2 * T
    items["rug"] = (w, h, [rect(4, 4, w - 8, h - 8, "#be123c", 8, 2), rect(14, 14, w - 28, h - 28, "none", 6, 2.5, "#fde68a"),
                           ellipse(w / 2, h / 2, 26, 16, "#fde68a", 2)])
    w, h = 2 * T, T
    items["bookshelf"] = (w, h, [rect(3, 6, w - 6, h - 12, "#78350f", 3)] +
                          [rect(8 + k * 11, 10, 9, h - 20, c, 1, 1.2) for k, c in
                           enumerate(["#ef4444", "#3b82f6", "#22c55e", "#facc15", "#a855f7", "#f97316", "#14b8a6", "#e11d48"])])
    w = h = T
    items["fridge"] = (w, h, [rect(5, 5, w - 10, h - 10, "#e5e7eb", 5), path(f"M5 {h / 2 - 2}H{w - 5}", "none", 2),
                              rect(w - 14, 10, 4, 10, "#9ca3af", 2, 1)])
    items["lamp"] = (w, h, [circle(w / 2, h / 2, 16, "#fde68a"), circle(w / 2, h / 2, 9, "#fef9c3", 2),
                            circle(w / 2, h / 2, 3, "#78350f", 0)])
    w, h = 2 * T, T
    items["aquarium"] = (w, h, [rect(4, 6, w - 8, h - 12, "#0ea5e9", 4), rect(8, 10, w - 16, h - 20, "#7dd3fc", 3, 1.5),
                                path("M20 22q4-4 8 0q-4 4-8 0zM52 18q4-4 8 0q-4 4-8 0zM66 28q4-4 8 0q-4 4-8 0z", "#f97316", 1),
                                path("M14 34q3-8 0-14M80 34q3-8 0-14", "none", 2, "#16a34a")])
    items["desk"] = (w, h, [rect(3, 8, w - 6, h - 14, "#a16207", 4), rect(26, 10, 36, 20, "#111827", 3, 2),
                            rect(29, 13, 30, 14, "#60a5fa", 2, 0), rect(30, 32, 28, 6, "#374151", 2, 1.5),
                            circle(70, 34, 3, "#e5e7eb", 1)])
    # 1.1: ocak ve tezgâh 2x1
    w, h = 2 * T, T
    items["stove"] = (w, h, [rect(3, 6, w - 6, h - 10, "#e5e7eb", 4), rect(8, 10, w / 2 - 12, h - 20, "#374151", 3, 2),
                             circle(w / 4, 18, 6, "#111827", 1.5), circle(w / 4, 32, 6, "#111827", 1.5),
                             circle(w / 4, 18, 3, "#ef4444", 0), rect(w / 2 + 4, 10, w / 2 - 12, h - 20, "#a16207", 3, 2),
                             ellipse(w * 0.75, h / 2, 9, 6, "#94a3b8", 1.5)])
    # 1.4: lunapark ödülleri
    w = h = T
    items["pelus_ayi"] = (w, h, [circle(w / 2, h * 0.62, 15, "#b45309", 2.5), circle(w / 2, h * 0.32, 11, "#b45309", 2.5),
                                 circle(w / 2 - 9, h * 0.18, 5, "#b45309", 2), circle(w / 2 + 9, h * 0.18, 5, "#b45309", 2),
                                 ellipse(w / 2, h * 0.37, 5, 4, "#fde68a", 1.5), circle(w / 2 - 4, h * 0.29, 1.6, "#111827", 0),
                                 circle(w / 2 + 4, h * 0.29, 1.6, "#111827", 0), ellipse(w / 2, h * 0.65, 8, 9, "#fde68a", 1.5),
                                 path(f"M{w / 2 - 6} {h * 0.47}l6 4l6 -4", "#ef4444", 1.5)])
    w, h = T, 2 * T
    items["pelus_zurafa"] = (w, h, [rect(w / 2 - 5, 14, 10, h * 0.55, "#fbbf24", 4, 2), ellipse(w / 2, h * 0.75, 17, 13, "#fbbf24", 2.5),
                                    ellipse(w / 2 + 4, 12, 10, 7, "#fbbf24", 2), circle(w / 2 + 7, 10, 1.6, "#111827", 0),
                                    circle(w / 2 - 6, h * 0.72, 3, "#b45309", 0), circle(w / 2 + 7, h * 0.78, 3, "#b45309", 0),
                                    circle(w / 2, h * 0.4, 2.5, "#b45309", 0), circle(w / 2, h * 0.25, 2.5, "#b45309", 0),
                                    path(f"M{w / 2 - 2} 5v-4M{w / 2 + 6} 5v-4", "none", 2)])
    w = h = T
    items["lunapark_feneri"] = (w, h, [rect(w / 2 - 3, 18, 6, h - 22, "#374151", 1, 1.5), ellipse(w / 2, h - 5, 12, 4, "#374151", 1.5),
                                       circle(w / 2, 14, 11, "#f472b6", 2), circle(w / 2 - 4, 11, 3, "#fde68a", 0),
                                       circle(w / 2 + 5, 16, 3, "#a5f3fc", 0), circle(w / 2 + 2, 7, 2.5, "#bbf7d0", 0)])
    for name, (w, h, parts) in items.items():
        save(f"furniture/{name}.svg", svg(w, h, parts))


# ---------------------------------------------------------------- 0.5: pet shop, muhtarlık, işletmeler, hayvanlar

def petshop():
    W, H = 320, 260
    p = [
        rect(4, 4, W - 8, 80, "#0d9488", 8),
        rect(4, 82, W - 8, 174, "#ccfbf1"),
        rect(4, 236, W - 8, 20, "#5eead4"),
    ]
    # çatıda kemik ve pati
    p += [path("M120 30h80", "none", 12, OL), path("M120 30h80", "none", 7, "#f8fafc"),
          circle(118, 24, 7, "#f8fafc", 2), circle(118, 36, 7, "#f8fafc", 2), circle(202, 24, 7, "#f8fafc", 2), circle(202, 36, 7, "#f8fafc", 2)]
    for (cx, cy) in ((50, 44), (270, 44)):
        p += [ellipse(cx, cy + 6, 12, 10, "#fef3c7", 2)] + [circle(cx + dx, cy - 10 + dy, 4.5, "#fef3c7", 1.5) for dx, dy in ((-11, 2), (-4, -4), (4, -4), (11, 2))]
    # vitrin: kedi ve balık kâsesi
    p += [rect(18, 134, 110, 82, "url(#glass)", 4, 2.5), rect(192, 134, 110, 82, "url(#glass)", 4, 2.5),
          ellipse(60, 196, 22, 14, "#f97316", 2), circle(82, 186, 11, "#f97316", 2), path("M76 177l3-8 5 6M86 177l3-8 3 8", "#f97316", 2),
          ellipse(248, 196, 30, 16, "#7dd3fc", 2), path("M236 194q6-5 12 0q-6 5-12 0z", "#f97316", 1.5),
          rect(136, 150, 48, 86, "#0f766e", 3), circle(172, 192, 2.5, "#facc15", 0)]
    p.append(sign_plate(W, "#0f766e"))
    save("buildings/petshop.svg", svg(W, H, p, GLASS))


def muhtarlik():
    W, H = 320, 220
    p = [
        poly([(4, 74), (160, 8), (316, 74)], "#b91c1c"),
        rect(4, 72, W - 8, 144, "#f5f5f4"),
        rect(4, 196, W - 8, 20, "#a8a29e"),
        rect(150, 2, 3, 30, "#374151", 0, 1.5), rect(153, 4, 30, 18, "#dc2626", 1, 1.5),
        circle(165, 13, 4, "#ffffff", 0), path("M171 10l3 3-3 3", "none", 1.2, "#ffffff"),
    ]
    for x in (24, 70, 210, 256):
        p += [rect(x, 126, 40, 52, "url(#glass)", 3, 2.5), path(f"M{x + 20} 126v52", "none", 1.5)]
    p += [rect(132, 122, 56, 74, "#7c2d12", 4), path("M160 122v74", "none", 2), circle(152, 162, 2.5, "#facc15", 0), circle(168, 162, 2.5, "#facc15", 0),
          rect(120, 196, 80, 8, "#d6d3d1", 2, 2)]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#7f1d1d", 7, 3))
    save("buildings/muhtarlik.svg", svg(W, H, p, GLASS))


def businesses():
    # Büfe (130x120)
    W, H = 130, 120
    p = [rect(14, 50, 102, 64, "#fde68a"), rect(22, 60, 86, 30, "url(#glass)", 3, 2.5)]
    for i, x in enumerate(range(8, 122, 19)):
        p.append(rect(x, 34, 19, 18, "#ef4444" if i % 2 == 0 else "#ffffff", 0, 0))
    p += [rect(8, 34, 114, 18, "none", 0, 2.5), rect(18, 92, 94, 8, "#92400e", 2, 2),
          circle(40, 72, 7, "#a16207", 1.5), circle(60, 72, 7, "#f97316", 1.5), rect(78, 64, 10, 16, "#38bdf8", 2, 1.5),
          rect(30, 14, 70, 20, "#111827", 4, 2.5)]
    save("plots/bufe.svg", svg(W, H, p, GLASS))
    # Kafe (200x130): şemsiyeli masalar
    W, H = 200, 130
    p = [rect(10, 20, 120, 96, "#fef3c7"), rect(10, 6, 120, 18, "#78350f", 3), rect(22, 40, 96, 40, "url(#glass)", 3, 2.5),
         rect(56, 84, 28, 32, "#78350f", 2), rect(30, 26, 80, 12, "#111827", 3, 2)]
    for cx, cy, col in ((160, 50, "#22c55e"), (160, 100, "#ef4444")):
        p += [ellipse(cx, cy + 10, 16, 7, "#a16207", 2), circle(cx, cy, 18, col, 2), circle(cx, cy, 5, "#ffffff", 1.5),
              circle(cx - 22, cy + 12, 5, "#92400e", 1.5), circle(cx + 22, cy + 12, 5, "#92400e", 1.5)]
    save("plots/kafe.svg", svg(W, H, p, GLASS))
    # Restoran (220x150)
    W, H = 220, 150
    p = [rect(8, 8, 204, 36, "#7f1d1d", 4), rect(8, 42, 204, 102, "#fef2f2"), rect(8, 128, 204, 16, "#a8a29e"),
         rect(70, 14, 80, 22, "#111827", 3, 2)]
    for x in (20, 62, 136, 178):
        p.append(path(f"M{x} 110V72A12 12 0 0 1 {x + 24} 72V110Z", "url(#warm)", 2.5))
    p += [rect(96, 74, 28, 54, "#7c2d12", 3), circle(118, 102, 2, "#facc15", 0),
          path("M20 52h180", "none", 3, "#facc15")]
    for x in (24, 60, 96, 132, 168, 196):
        p.append(circle(x, 52, 3, "#fde047", 1))
    save("plots/restoran.svg", svg(W, H, p, WARM))


def pets():
    # Sağa bakan yan görünüm; 2 kare (adım). Kare: 40x32.
    def sheet(name, frames):
        W, H = 80, 32
        parts = []
        for i, fr in enumerate(frames):
            parts.append(f'<g transform="translate({i * 40} 0)">' + "".join(fr) + "</g>")
        save(f"pets/{name}.svg", svg(W, H, parts))

    def cat(step):
        a, b = (2, -2) if step else (-2, 2)
        col = "#f59e0b"
        return [path("M8 16q-6-10 2-14", "none", 3, col), ellipse(18, 18, 11, 7, col, 1.6),
                rect(10 + a, 22, 4, 8, col, 2, 1.4), rect(22 + b, 22, 4, 8, col, 2, 1.4),
                circle(29, 13, 7, col, 1.6), path("M24 9l1-7 5 5M30 7l4-5 1 7", col, 1.4),
                circle(31, 12, 1.2, OL, 0), path("M33 15l3 0", "none", 0.8, OL)]

    def dog(step):
        a, b = (2, -2) if step else (-2, 2)
        col = "#92400e"
        return [path("M6 14q-4-6 0-10", "none", 3, col), ellipse(18, 17, 12, 7, col, 1.6),
                rect(9 + a, 21, 4, 9, col, 2, 1.4), rect(23 + b, 21, 4, 9, col, 2, 1.4),
                circle(30, 12, 7, col, 1.6), ellipse(35, 15, 4, 3, "#78350f", 1.2), circle(36, 14, 1.2, OL, 0),
                ellipse(27, 9, 3, 6, "#451a03", 1.2, extra='transform="rotate(-20 27 9)"'), circle(31, 10, 1.2, OL, 0)]

    def parrot(step):
        wing = -4 if step else 2
        return [ellipse(18, 18, 7, 9, "#22c55e", 1.6), path(f"M14 16q-8 {wing} -4 10", "#16a34a", 1.4),
                path("M18 26l-2 6M20 26l2 6", "none", 1.5, "#a16207"), circle(21, 9, 6, "#ef4444", 1.6),
                path("M26 9l4 2-4 2z", "#facc15", 1.2), circle(22, 8, 1.3, OL, 0), path("M12 22l-6 6", "none", 3, "#3b82f6")]

    sheet("cat", [cat(0), cat(1)])
    sheet("dog", [dog(0), dog(1)])
    sheet("parrot", [parrot(0), parrot(1)])


# ---------------------------------------------------------------- 0.6: karakol

def karakol():
    W, H = 320, 220
    p = [
        rect(4, 8, W - 8, 66, "#1e3a8a", 6),
        path(f"M4 40H{W - 4}", "none", 4, "#f8fafc"),
        rect(4, 72, W - 8, 144, "#e0e7ff"),
        rect(4, 196, W - 8, 20, "#94a3b8"),
        # tepe lambaları
        rect(118, 0, 36, 12, "#ef4444", 4, 2), rect(166, 0, 36, 12, "#3b82f6", 4, 2),
    ]
    for x in (22, 72, 212, 262):
        p += [rect(x, 126, 38, 50, "url(#glass)", 3, 2.5), path(f"M{x} 151h38", "none", 1.5), path(f"M{x + 6} 126v50M{x + 13} 126v50M{x + 19} 126v50M{x + 26} 126v50M{x + 32} 126v50", "none", 1.2, "#475569")]
    # kapı ve rozet
    p += [rect(130, 120, 60, 76, "#1e40af", 4), path("M160 120v76", "none", 2), circle(152, 160, 2.5, "#facc15", 0), circle(168, 160, 2.5, "#facc15", 0),
          rect(120, 196, 80, 8, "#cbd5e1", 2, 2),
          path("M160 14l14 6v10c0 9-6 14-14 18c-8-4-14-9-14-18v-10z", "#facc15", 2.5), circle(160, 30, 4, "#1e3a8a", 0)]   # çatıda rozet
    p.append(rect(W / 2 - 92, 78, 184, 32, "#172554", 7, 3, "#facc15"))
    save("buildings/karakol.svg", svg(W, H, p, GLASS))


# ---------------------------------------------------------------- 0.7: banka ve çarşı

def banka():
    W, H = 320, 220
    p = [
        poly([(4, 72), (160, 6), (316, 72)], "#e7e5e4"),
        poly([(40, 66), (160, 18), (280, 66)], "#d6d3d1", 2),
        circle(160, 46, 13, "#facc15", 2.5), path("M155 40h10M155 46h10M160 36v20", "none", 2, "#a16207"),
        rect(4, 70, W - 8, 146, "#f5f5f4"),
        rect(4, 196, W - 8, 20, "#a8a29e"),
        rect(10, 112, W - 20, 6, "#d6d3d1", 0, 1.5),
    ]
    for x in (22, 62, 226, 266):         # sütunlar
        p += [rect(x, 118, 22, 78, "#fafaf9", 2, 2), rect(x - 3, 116, 28, 6, "#e7e5e4", 1, 1.5), rect(x - 3, 190, 28, 6, "#e7e5e4", 1, 1.5)]
    p += [rect(126, 122, 68, 74, "#1e3a8a", 4), path("M160 122v74", "none", 2, "#93c5fd"), circle(152, 160, 2.5, "#facc15", 0), circle(168, 160, 2.5, "#facc15", 0),
          rect(100, 136, 18, 30, "url(#glass)", 2, 2), rect(202, 136, 18, 30, "url(#glass)", 2, 2),
          rect(116, 196, 88, 8, "#d6d3d1", 2, 2)]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#1c1917", 7, 3, "#facc15"))
    save("buildings/banka.svg", svg(W, H, p, GLASS))


def carsi():
    W, H = 320, 220
    p = [rect(4, 68, W - 8, 148, "#fff7ed", 6), rect(4, 196, W - 8, 20, "#d6b98a")]
    # üç dükkân: kuaför (makas), aksesuarcı (şapka), kuyumcu (yüzük)
    shops = ((10, "#db2777"), (112, "#7c3aed"), (214, "#ca8a04"))
    for i, (x, col) in enumerate(shops):
        p.append(rect(x, 116, 96, 80, "#fef3c7", 3, 2.5))
        for k in range(6):
            p.append(rect(x + k * 16, 104, 16, 14, col if k % 2 == 0 else "#ffffff", 0, 0))
        p += [rect(x, 104, 96, 14, "none", 0, 2.5), rect(x + 10, 128, 44, 44, "url(#glass)", 3, 2), rect(x + 62, 132, 26, 64, col, 2, 2)]
        cx, cy = x + 32, 150
        if i == 0:
            p += [circle(cx - 6, cy + 8, 5, "none", 2.5), circle(cx + 6, cy + 8, 5, "none", 2.5), path(f"M{cx - 4} {cy + 4}L{cx + 8} {cy - 12}M{cx + 4} {cy + 4}L{cx - 8} {cy - 12}", "none", 2.5, "#475569")]
        elif i == 1:
            p += [ellipse(cx, cy + 6, 16, 4, "#7c3aed", 2), path(f"M{cx - 9} {cy + 5}Q{cx - 9} {cy - 10} {cx} {cy - 10}Q{cx + 9} {cy - 10} {cx + 9} {cy + 5}Z", "#8b5cf6", 2)]
        else:
            p += [circle(cx, cy + 4, 9, "none", 3, "#facc15"), path(f"M{cx - 6} {cy - 8}l6 -7l6 7l-6 6z", "#bae6fd", 2)]
    p += [rect(4, 8, W - 8, 62, "#9a3412", 6), path(f"M14 36H{W - 14}", "none", 2, "#fdba74")]
    p.append(rect(W / 2 - 92, 78, 184, 32, "#7c2d12", 7, 3))
    save("buildings/carsi.svg", svg(W, H, p, GLASS))


# ---------------------------------------------------------------- 1.0: fabrika

def fabrika():
    W, H = 440, 280
    p = []
    # testere dişi çatı
    for i in range(5):
        x = 8 + i * 84
        p.append(poly([(x, 80), (x + 84, 80), (x + 84, 30), (x, 80)], "#64748b", 2.5))
        p.append(poly([(x + 84, 30), (x + 84, 80), (x + 70, 80), (x + 70, 44)], "#bae6fd", 1.5))
    p += [rect(8, 78, W - 16, 198, "#cbd5e1"), rect(8, 256, W - 16, 20, "#94a3b8"),
          rect(360, 0, 34, 80, "#78716c", 3), rect(356, 0, 42, 12, "#57534e", 3),
          circle(377, -6, 10, "#e5e7eb", 0, extra='opacity="0.6"')]
    for x in (24, 92, 300, 368):
        p += [rect(x, 150, 52, 40, "url(#glass)", 3, 2), path(f"M{x + 26} 150v40M{x} 170h52", "none", 1.5)]
    # yükleme kapısı
    p += [rect(160, 140, 120, 136, "#475569", 4), path("M160 160h120M160 180h120M160 200h120M160 220h120M160 240h120", "none", 1.5, "#334155"),
          poly([(150, 140), (290, 140), (280, 128), (160, 128)], "#f59e0b", 2)]
    p.append(rect(W / 2 - 92, 82, 184, 32, "#1e293b", 7, 3, "#f59e0b"))
    save("buildings/fabrika.svg", svg(W, H, p, GLASS))


# ---------------------------------------------------------------- 1.2: müze, teleferik, dağ evi

def muze():
    W, H = 420, 280
    p = [
        poly([(4, 92), (210, 8), (416, 92)], "#e7e5e4"),
        poly([(52, 86), (210, 24), (368, 86)], "#d6d3d1", 2),
        rect(4, 90, W - 8, 186, "#f5f5f4"),
        rect(4, 252, W - 8, 24, "#a8a29e"), rect(30, 240, W - 60, 14, "#d6d3d1", 0, 2),
        rect(10, 132, W - 20, 8, "#d6d3d1", 0, 1.5),
    ]
    # alınlıkta ammonit
    p += [circle(210, 62, 18, "#fde68a", 2.5), path("M210 62m-10 0a10 10 0 1 1 10 10a6 6 0 1 1 -6 -6a3 3 0 1 1 3 3", "none", 2, "#92400e")]
    for x in (24, 74, 124, 274, 324, 374):     # sütunlar
        p += [rect(x, 140, 22, 100, "#fafaf9", 2, 2), rect(x - 3, 138, 28, 6, "#e7e5e4", 1, 1.5), rect(x - 3, 234, 28, 6, "#e7e5e4", 1, 1.5)]
    # kapı ve vitrinler
    p += [path("M178 240V172a32 32 0 0 1 64 0V240Z", "#7c2d12"), path("M210 142v98", "none", 2, "#fdba74"),
          circle(202, 206, 2.5, "#facc15", 0), circle(218, 206, 2.5, "#facc15", 0),
          rect(150, 160, 20, 40, "url(#glass)", 2, 2), rect(250, 160, 20, 40, "url(#glass)", 2, 2)]
    # basamaklar
    p += [rect(150, 240, 120, 6, "#e7e5e4", 1, 1.5), rect(140, 246, 140, 6, "#d6d3d1", 1, 1.5)]
    p.append(rect(W / 2 - 92, 96, 184, 32, "#1c1917", 7, 3, "#d6d3d1"))
    save("buildings/muze.svg", svg(W, H, p, GLASS))


def teleferik():
    W, H = 180, 116
    p = [rect(10, 40, W - 20, 72, "#e2e8f0", 4), rect(10, 98, W - 20, 14, "#94a3b8"),
         poly([(2, 44), (90, 8), (178, 44)], "#dc2626"), rect(68, 62, 44, 50, "#334155", 3),
         rect(22, 58, 36, 26, "url(#glass)", 3, 2), rect(122, 58, 36, 26, "url(#glass)", 3, 2)]
    p.append(rect(W / 2 - 64, 14, 128, 26, "#1e293b", 6, 2.5, "#fca5a5"))
    save("buildings/teleferik.svg", svg(W, H, p, GLASS))


def dagevi():
    W, H = 300, 200
    p = [rect(14, 70, W - 28, 126, "#92400e", 4)]
    for y in range(80, 190, 16):            # kütük duvar
        p.append(path(f"M18 {y}H{W - 18}", "none", 2, "#78350f"))
    p += [poly([(0, 78), (150, 4), (300, 78)], "#7c2d12"),
          path("M8 74L150 10L292 74", "none", 10, "#f8fafc"),       # çatıda kar
          rect(214, 20, 26, 46, "#57534e", 3), rect(210, 14, 34, 10, "#f8fafc", 3, 2),
          rect(122, 120, 56, 76, "#451a03", 4), circle(168, 160, 3, "#facc15", 0),
          rect(36, 118, 50, 40, "url(#warm)", 3, 2.5), path("M61 118v40M36 138h50", "none", 2, "#78350f"),
          rect(214, 118, 50, 40, "url(#warm)", 3, 2.5), path("M239 118v40M214 138h50", "none", 2, "#78350f")]
    p.append(rect(W / 2 - 80, 82, 160, 30, "#292524", 6, 3, "#fdba74"))
    save("buildings/dagevi.svg", svg(W, H, p, WARM + GLASS))


# ---------------------------------------------------------------- 1.3: hara

def hara():
    W, H = 196, 150
    p = [rect(8, 48, W - 16, 98, "#b45309", 4)]
    for y in range(58, 140, 12):
        p.append(path(f"M12 {y}H{W - 12}", "none", 1.5, "#92400e"))
    p += [poly([(0, 54), (98, 4), (196, 54)], "#7f1d1d"), path("M98 4V54", "none", 2, "#450a0a"),
          rect(70, 86, 56, 60, "#451a03", 3), path("M70 86L126 146M126 86L70 146", "none", 3, "#b45309"),
          rect(20, 76, 36, 30, "#1c1917", 3), rect(140, 76, 36, 30, "#1c1917", 3),
          # pencereden bakan at başları
          ellipse(38, 96, 9, 12, "#8b5a2b", 2), ellipse(158, 96, 9, 12, "#f3f4f6", 2),
          circle(35, 92, 1.5, "#111827", 0), circle(155, 92, 1.5, "#111827", 0)]
    p.append(rect(W / 2 - 60, 12, 120, 26, "#292524", 6, 2.5, "#fbbf24"))
    save("buildings/hara.svg", svg(W, H, p))


# ---------------------------------------------------------------- 1.4: okul ve havalimanı terminali

def okul():
    W, H = 168, 200
    p = [rect(6, 60, W - 12, 136, "#fde68a", 4), rect(6, 176, W - 12, 20, "#d6b98a"),
         poly([(0, 64), (84, 22), (168, 64)], "#b91c1c"), rect(72, 8, 24, 40, "#e5e7eb", 2, 2),
         path("M84 8v-6", "none", 2), poly([(84, 2), (100, 6), (84, 10)], "#dc2626", 1.5),
         circle(84, 34, 8, "#f8fafc", 2), path("M84 29v5l4 2", "none", 1.5),
         rect(64, 128, 40, 68, "#7c2d12", 3), path("M84 128v68", "none", 2, "#fdba74")]
    for x in (18, 116):
        for y in (78, 128):
            p += [rect(x, y, 34, 30, "url(#glass)", 3, 2), path(f"M{x + 17} {y}v30M{x} {y + 15}h34", "none", 1.5)]
    p.append(rect(W / 2 - 56, 22, 112, 26, "#1e3a8a", 6, 2.5, "#fde68a"))
    save("buildings/okul.svg", svg(W, H, p, GLASS))


def terminal():
    W, H = 420, 230
    p = [rect(6, 70, W - 12, 156, "#e2e8f0", 6), rect(6, 206, W - 12, 20, "#94a3b8"),
         path("M6 70Q210 6 414 70", "#94a3b8", 3), rect(20, 100, W - 40, 70, "url(#glass)", 6, 2.5)]
    for x in range(40, W - 30, 40):
        p.append(path(f"M{x} 100v70", "none", 2, "#64748b"))
    p += [rect(180, 160, 60, 66, "#334155", 4), path("M210 160v66", "none", 2, "#94a3b8"),
          rect(330, 10, 30, 64, "#475569", 3), rect(318, 2, 54, 16, "#93c5fd", 4, 2)]
    p.append(rect(W / 2 - 92, 40, 184, 30, "#0f172a", 7, 3, "#38bdf8"))
    save("buildings/terminal.svg", svg(W, H, p, GLASS))


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
    galeri()
    mobilya()
    pazar()
    vehicles()
    furniture()
    petshop()
    muhtarlik()
    businesses()
    pets()
    karakol()
    banka()
    carsi()
    fabrika()
    muze()
    teleferik()
    dagevi()
    hara()
    okul()
    terminal()
