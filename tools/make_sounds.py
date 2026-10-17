#!/usr/bin/env python3
"""MyCity Online seslerini ve müziğini sentezler (numpy + scipy gerekir).

Çalıştır:  python3 tools/make_sounds.py   ->  assets/sounds/*.wav
Hepsi bu betikle üretilir; dışarıdan ses dosyası yoktur.
"""
import os
import wave

import numpy as np
from scipy.signal import lfilter

SR = 22050
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sounds")
rng = np.random.default_rng(42)


def t_of(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.005, release=None, decay=None):
    """Basit zarf: hızlı atak, ardından üstel sönüm ya da doğrusal bırakma."""
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    if decay:
        e *= np.exp(-np.arange(n) / (SR * decay))
    if release:
        r = min(n, int(SR * release))
        e[-r:] *= np.linspace(1, 0, r)
    return e


def tone(freq, dur, shape="sine", decay=None, release=0.02, vib=0.0):
    t = t_of(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * 5.5 * t)) if vib else freq
    ph = 2 * np.pi * np.cumsum(np.full(len(t), 1.0) * f) / SR
    if shape == "sine":
        w = np.sin(ph)
    elif shape == "square":
        w = np.tanh(3 * np.sin(ph)) * 0.6
    elif shape == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    else:  # saw
        w = 2 * ((ph / (2 * np.pi)) % 1) - 1
    return w * env(len(t), release=release, decay=decay)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def mix_at(buf, x, start):
    i = int(start * SR)
    end = min(len(buf), i + len(x))
    buf[i:end] += x[: end - i]


def note(n):
    """MIDI nota numarası -> frekans."""
    return 440.0 * 2 ** ((n - 69) / 12)


def save(name, x, vol=0.8):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = (x / peak * vol * 32767).astype(np.int16)
    os.makedirs(ROOT, exist_ok=True)
    p = os.path.join(ROOT, name + ".wav")
    with wave.open(p, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(x.tobytes())
    print("yazıldı:", os.path.relpath(p), f"{len(x) / SR:.2f} sn")


# ---------------------------------------------------------------- efektler

def effects():
    save("click", tone(1500, 0.04, "sine", decay=0.012), 0.5)
    save("open", lowpass(noise(0.22), 1800) * env(int(SR * 0.22), 0.04, decay=0.07), 0.45)
    save("coin", seq(tone(988, 0.07, "square", release=0.01), tone(1319, 0.22, "square", decay=0.08)), 0.55)
    save("cash", seq(*[tone(note(n), 0.09, "square", decay=0.1) for n in (72, 76, 79, 84)],
                     tone(note(88), 0.45, "square", decay=0.18)), 0.6)
    save("lose", seq(*[tone(note(n), d, "saw", release=0.05, vib=0.01) * 0.6
                       for n, d in ((67, 0.22), (66, 0.22), (65, 0.22), (64, 0.55))]), 0.5)
    save("error", seq(tone(196, 0.12, "square"), tone(147, 0.18, "square"), gap=0.03), 0.45)
    bell = tone(1046, 0.6, "sine", decay=0.18) + 0.4 * tone(2093, 0.6, "sine", decay=0.1)
    save("notify", bell, 0.45)
    save("success", seq(tone(note(76), 0.1, "tri", decay=0.08), tone(note(79), 0.25, "tri", decay=0.12)), 0.6)
    sp = lowpass(noise(0.6), 2500) * env(int(SR * 0.6), 0.01, decay=0.15)
    sp += 0.3 * lowpass(noise(0.6), 600) * env(int(SR * 0.6), 0.05, decay=0.25)
    save("splash", sp, 0.6)
    save("bite", seq(*[tone(1760, 0.07, "square", decay=0.03) for _ in range(3)], gap=0.04), 0.55)
    save("catch", seq(*[tone(note(n), 0.08, "tri", decay=0.08) for n in (67, 71, 74, 79)],
                      tone(note(83), 0.3, "tri", decay=0.12)), 0.6)
    card = highpass(noise(0.09), 2500) * env(int(SR * 0.09), 0.002, decay=0.025)
    save("card", card, 0.5)
    clack = lambda f: tone(f, 0.05, "sine", decay=0.01) + 0.5 * highpass(noise(0.05), 3000) * env(int(SR * 0.05), decay=0.006)
    save("chip", seq(clack(3200), clack(2600), gap=0.03), 0.5)
    save("tick", highpass(noise(0.02), 2000) * env(int(SR * 0.02), 0.001, decay=0.004), 0.45)
    d = np.zeros(int(SR * 0.6))
    for k in range(6):
        mix_at(d, clack(rng.uniform(1500, 2600)) * (1 - k * 0.12), k * 0.08 + rng.uniform(0, 0.03))
    save("dice", d, 0.55)
    g = np.zeros(int(SR * 1.2))
    for k in range(8):
        for off in (0.0, 0.07):
            mix_at(g, tone(110, 0.08, "sine", decay=0.02) + 0.3 * lowpass(noise(0.08), 900) * env(int(SR * 0.08), decay=0.02), k * 0.15 + off)
    save("gallop", g, 0.6)
    save("splash_small", lowpass(noise(0.25), 1800) * env(int(SR * 0.25), 0.005, decay=0.06), 0.4)


# ---------------------------------------------------------------- dalga ambiyansı

def waves():
    dur = 8.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    base = lowpass(noise(dur), 700)
    hiss = highpass(lowpass(noise(dur), 3500), 900)
    # 8 sn içinde tam 2 dalga: döngü ek yerinde süreksizlik olmasın
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 4.0 - np.pi / 2) ** 2
    x = base * swell + 0.25 * hiss * swell ** 3
    fade = int(SR * 0.5)                # uçları birbirine karıştır
    x[:fade] = x[:fade] * np.linspace(0, 1, fade) + x[-fade:] * np.linspace(1, 0, fade)
    save("waves", x[: n - fade], 0.5)


# ---------------------------------------------------------------- müzik

def music():
    bpm = 108
    beat = 60.0 / bpm
    bars = 16
    total = bars * 4 * beat
    buf = np.zeros(int(SR * total) + SR)
    # Akorlar (C - Am - F - G), her biri 2 ölçü
    chords = [(48, (60, 64, 67)), (45, (57, 60, 64)), (41, (57, 60, 65)), (43, (59, 62, 67))]
    # Melodi: (ölçü içindeki vuruş, nota, süre vuruş) — pentatonik, sakin
    phrase_a = [(0, 76, 1), (1, 79, 0.5), (1.5, 76, 0.5), (2, 74, 1), (3, 72, 1),
                (4, 69, 1.5), (5.5, 72, 0.5), (6, 74, 2)]
    phrase_b = [(0, 77, 1), (1, 76, 0.5), (1.5, 74, 0.5), (2, 72, 1), (3, 74, 1),
                (4, 79, 1.5), (5.5, 76, 0.5), (6, 74, 2)]
    phrase_c = [(0, 76, 0.5), (0.5, 79, 0.5), (1, 81, 1), (2, 79, 1), (3, 76, 1),
                (4, 74, 1), (5, 72, 1), (6, 72, 2)]
    melody_plan = [phrase_a, phrase_b, phrase_a, phrase_c]
    for bar in range(bars):
        t0 = bar * 4 * beat
        root, triad = chords[(bar // 2) % 4]
        # bas: 1. ve 3. vuruş, ara notada oktav
        for b, n in ((0, root), (2, root), (3.5, root + 12)):
            mix_at(buf, tone(note(n), beat * 0.9, "tri", decay=0.4) * 0.55, t0 + b * beat)
        # akor arpeji (sekizlik)
        for k in range(8):
            n = triad[[0, 1, 2, 1][k % 4]] + (12 if k >= 4 and bar % 2 else 0)
            mix_at(buf, tone(note(n), beat * 0.45, "sine", decay=0.25) * 0.22, t0 + k * beat / 2)
        # davul
        for b in (0, 2):
            kick = np.sin(2 * np.pi * np.cumsum(np.linspace(140, 45, int(SR * 0.18))) / SR) * env(int(SR * 0.18), 0.001, decay=0.06)
            mix_at(buf, kick * 0.7, t0 + b * beat)
        for b in (1, 3):
            mix_at(buf, highpass(noise(0.15), 1200) * env(int(SR * 0.15), 0.001, decay=0.04) * 0.22, t0 + b * beat)
        for k in range(8):
            mix_at(buf, highpass(noise(0.04), 6000) * env(int(SR * 0.04), 0.001, decay=0.01) * (0.12 if k % 2 else 0.07), t0 + k * beat / 2)
        # melodi: her 2 ölçü bir cümle; ilk 2 ölçü sadece eşlik (giriş)
        if bar >= 2 and bar % 2 == 0:
            phrase = melody_plan[(bar // 2 - 1) % 4]
            for b, n, d in phrase:
                mix_at(buf, tone(note(n), d * beat * 0.95, "square", decay=0.5, vib=0.004) * 0.18, t0 + b * beat)
    out = buf[: int(SR * total)]
    # ek yerinde tık olmasın
    f = int(SR * 0.01)
    out[:f] *= np.linspace(0, 1, f)
    out[-f:] *= np.linspace(1, 0, f)
    save("music_city", out, 0.55)


if __name__ == "__main__":
    effects()
    waves()
    music()
