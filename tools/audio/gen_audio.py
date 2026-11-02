"""Original procedural audio for PONDLIGHT (SFX, ambience loops, music loops).

Pure-Python synthesis (Karplus-Strong plucks, FM bells, filtered noise).
Output: 16-bit mono WAV at 22050 Hz in pondlight/assets/audio/.
"""
from __future__ import annotations

import math
import os
import random
import struct
import wave

SR = 22050
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "pondlight", "assets", "audio"))
TAU = math.tau


def write(path, data, peak=0.85):
    m = max(1e-6, max(abs(v) for v in data))
    g = peak / m
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v * g)) * 32767)) for v in data))


def buf(sec):
    return [0.0] * int(SR * sec)


def add(dst, src, at=0.0, gain=1.0):
    o = int(at * SR)
    for i, v in enumerate(src):
        j = o + i
        if j >= len(dst):
            break
        dst[j] += v * gain


def env(n, a, d, sustain=0.0, curve=4.0):
    out = []
    an = max(1, int(a * SR))
    for i in range(n):
        if i < an:
            out.append(i / an)
        else:
            t = (i - an) / SR
            out.append(sustain + (1 - sustain) * math.exp(-t * curve / max(1e-3, d)))
    return out


def sine(freq, sec, a=0.003, d=0.3, gain=1.0, sweep_to=None, vib=0.0):
    n = int(SR * sec)
    e = env(n, a, d)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = freq if sweep_to is None else freq + (sweep_to - freq) * t
        f *= 1 + vib * math.sin(TAU * 5.2 * i / SR)
        ph += TAU * f / SR
        out.append(math.sin(ph) * e[i] * gain)
    return out


def noise(sec, lp=0.5, hp=0.0, a=0.002, d=0.2, seed=1, gain=1.0):
    r = random.Random(seed)
    n = int(SR * sec)
    e = env(n, a, d)
    y = 0.0
    yh = 0.0
    prev = 0.0
    out = []
    for i in range(n):
        x = r.uniform(-1, 1)
        y += lp * (x - y)
        if hp > 0:
            yh = hp * (yh + y - prev)
            prev = y
            v = yh
        else:
            v = y
        out.append(v * e[i] * gain)
    return out


def pluck(freq, sec, gain=1.0, bright=0.5, seed=0):
    """Karplus-Strong plucked string."""
    r = random.Random(seed + int(freq))
    n = int(SR * sec)
    period = max(2, int(SR / freq))
    line = [r.uniform(-1, 1) for _ in range(period)]
    # soften the excitation
    for k in range(3):
        line = [(line[i] + line[i - 1]) * 0.5 for i in range(period)]
    out = []
    idx = 0
    damp = 0.996 - (1 - bright) * 0.006
    for i in range(n):
        a = line[idx]
        b = line[(idx + 1) % period]
        line[idx] = (a * 0.5 + b * 0.5) * damp
        out.append(a * gain)
        idx = (idx + 1) % period
    # gentle fade at the end
    f = min(n, int(0.02 * SR))
    for i in range(f):
        out[n - 1 - i] *= i / f
    return out


def bell(freq, sec, gain=1.0, ratio=3.5, index=2.0, d=0.6):
    n = int(SR * sec)
    out = []
    for i in range(n):
        t = i / SR
        e = math.exp(-t * 4.0 / d)
        mod = math.sin(TAU * freq * ratio * t) * index * e
        out.append(math.sin(TAU * freq * t + mod) * e * gain)
    return out


def note(n):
    """MIDI note -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def lowpass(data, a):
    y = 0.0
    out = []
    for v in data:
        y += a * (v - y)
        out.append(y)
    return out


def loopify(data, fade_sec=1.5):
    """Make a seamless loop by cross-fading the tail into the head."""
    f = int(fade_sec * SR)
    head = data[:f]
    body = data[f:]
    for i in range(f):
        t = i / f
        body[len(body) - f + i] = body[len(body) - f + i] * (1 - t) + head[i] * t
    return body


# ===================================================================== SFX
def sfx():
    d = os.path.join(ROOT, "sfx")
    s = buf(0.06); add(s, sine(1500, 0.05, d=0.02, gain=0.4)); add(s, noise(0.04, lp=0.6, d=0.01, gain=0.3))
    write(os.path.join(d, "ui_hover.wav"), s, 0.35)
    s = buf(0.12); add(s, sine(420, 0.1, d=0.04)); add(s, sine(860, 0.08, d=0.03, gain=0.5)); add(s, noise(0.03, lp=0.7, d=0.01, gain=0.6))
    write(os.path.join(d, "ui_click.wav"), s, 0.6)
    s = buf(0.3); add(s, noise(0.28, lp=0.15, a=0.08, d=0.12, seed=3)); add(s, sine(300, 0.25, a=0.05, d=0.1, sweep_to=520, gain=0.25))
    write(os.path.join(d, "ui_open.wav"), s, 0.45)
    s = buf(0.25); add(s, noise(0.22, lp=0.12, a=0.02, d=0.08, seed=4)); add(s, sine(480, 0.2, d=0.08, sweep_to=260, gain=0.25))
    write(os.path.join(d, "ui_close.wav"), s, 0.4)
    s = buf(1.3)
    for i in range(10):
        add(s, sine(180 + i * 30, 0.08, d=0.04, gain=0.4), at=i * 0.12)
        add(s, noise(0.03, lp=0.4, d=0.01, seed=i, gain=0.3), at=i * 0.12)
    write(os.path.join(d, "cast_charge.wav"), s, 0.35)
    s = buf(0.4); add(s, noise(0.35, lp=0.35, a=0.01, d=0.14, seed=7)); add(s, sine(900, 0.3, d=0.12, sweep_to=300, gain=0.2))
    write(os.path.join(d, "cast_release.wav"), s, 0.6)
    s = buf(0.6); add(s, noise(0.5, lp=0.25, d=0.12, seed=9)); add(s, sine(620, 0.25, d=0.1, sweep_to=180, gain=0.7))
    add(s, noise(0.3, lp=0.6, d=0.05, seed=10, gain=0.4), at=0.03)
    write(os.path.join(d, "splash.wav"), s, 0.7)
    s = buf(0.12); add(s, sine(900, 0.1, d=0.04, sweep_to=380))
    write(os.path.join(d, "plop.wav"), s, 0.35)
    s = buf(0.9); add(s, sine(700, 0.2, d=0.08, sweep_to=220)); add(s, noise(0.25, lp=0.3, d=0.06, seed=12, gain=0.6))
    add(s, bell(1318, 0.7, gain=0.5, ratio=2.0, index=1.2), at=0.04); add(s, bell(1976, 0.6, gain=0.25, ratio=2.0, index=1.0), at=0.04)
    write(os.path.join(d, "bite.wav"), s, 0.75)
    s = buf(0.5)
    for i in range(7):
        add(s, noise(0.012, lp=0.9, d=0.004, seed=20 + i), at=i * 0.07)
        add(s, sine(2400, 0.015, d=0.004, gain=0.3), at=i * 0.07)
    write(os.path.join(d, "reel.wav"), s, 0.35)
    s = buf(0.4); add(s, pluck(784, 0.35, bright=0.8)); add(s, pluck(1175, 0.3, gain=0.4, bright=0.8))
    write(os.path.join(d, "strike_good.wav"), s, 0.5)
    s = buf(0.7); add(s, bell(1568, 0.6, ratio=2.0, index=0.8)); add(s, bell(2349, 0.5, gain=0.6, ratio=2.0, index=0.6), at=0.03)
    add(s, pluck(1568, 0.3, gain=0.5, bright=0.9))
    write(os.path.join(d, "strike_perfect.wav"), s, 0.55)
    s = buf(0.25); add(s, sine(150, 0.2, d=0.07, sweep_to=90)); add(s, noise(0.1, lp=0.2, d=0.03, seed=31, gain=0.5))
    write(os.path.join(d, "strike_miss.wav"), s, 0.55)
    s = buf(0.45)
    ph = 0.0
    for i in range(len(s)):
        t = i / SR
        f = 170 + 25 * math.sin(TAU * 7 * t)
        ph += TAU * f / SR
        saw = (ph / TAU) % 1.0 * 2 - 1
        s[i] = saw * math.exp(-t * 4) * (1 - math.exp(-t * 60))
    s = lowpass(s, 0.15)
    write(os.path.join(d, "tension.wav"), s, 0.4)
    s = buf(0.9)
    for i in range(4):
        add(s, noise(0.25, lp=0.3 + i * 0.05, d=0.08, seed=40 + i), at=i * 0.16)
        add(s, sine(400 - i * 40, 0.15, d=0.06, sweep_to=150, gain=0.5), at=i * 0.16)
    write(os.path.join(d, "surge.wav"), s, 0.7)
    s = buf(1.0)
    for i, n in enumerate((67, 64, 60)):
        add(s, pluck(note(n), 0.5, gain=0.8, bright=0.4), at=i * 0.16)
    write(os.path.join(d, "escape.wav"), s, 0.55)
    s = buf(0.6); add(s, pluck(1760, 0.3, bright=1.0)); add(s, noise(0.08, lp=0.9, d=0.02, seed=50, gain=0.8))
    add(s, sine(1400, 0.4, d=0.15, sweep_to=200, gain=0.4))
    write(os.path.join(d, "line_snap.wav"), s, 0.7)
    s = buf(1.2)
    for i, n in enumerate((72, 76, 79, 84)):
        add(s, pluck(note(n), 0.7, gain=0.8, bright=0.7), at=i * 0.08)
    add(s, bell(note(84), 0.8, gain=0.25, ratio=2, index=0.6), at=0.3)
    write(os.path.join(d, "catch.wav"), s, 0.65)
    s = buf(1.8)
    for i, n in enumerate((72, 76, 79, 83, 84, 88)):
        add(s, pluck(note(n), 0.9, gain=0.8, bright=0.8), at=i * 0.07)
    for i in range(10):
        add(s, bell(note(96 + (i % 4) * 2), 0.4, gain=0.12, ratio=2, index=0.5), at=0.35 + i * 0.06)
    write(os.path.join(d, "catch_rare.wav"), s, 0.7)
    s = buf(3.0)
    chords = [(60, 64, 67, 72), (65, 69, 72, 77), (67, 71, 74, 79), (72, 76, 79, 84)]
    for ci, ch in enumerate(chords):
        at = ci * 0.28 if ci < 3 else 0.9
        dur = 0.4 if ci < 3 else 1.9
        for n in ch:
            tone = buf(dur)
            ph = 0.0
            for i in range(len(tone)):
                t = i / SR
                ph += TAU * note(n) / SR
                saw = (ph / TAU) % 1.0 * 2 - 1
                tone[i] = saw * min(1, t * 30) * math.exp(-t * (3.0 if ci < 3 else 1.2))
            add(s, lowpass(tone, 0.12), at=at, gain=0.3)
    for i in range(16):
        add(s, bell(note(84 + (i * 5) % 12), 0.5, gain=0.12, ratio=2, index=0.4), at=1.0 + i * 0.07)
    write(os.path.join(d, "catch_legendary.wav"), s, 0.8)
    s = buf(0.7)
    for i in range(4):
        add(s, bell(2600 + i * 180, 0.25, gain=0.6, ratio=1.48, index=1.5, d=0.25), at=i * 0.07)
    write(os.path.join(d, "sell.wav"), s, 0.55)
    s = buf(1.0); add(s, bell(1046, 0.8, ratio=2, index=0.7)); add(s, bell(1568, 0.7, gain=0.6, ratio=2, index=0.6), at=0.08)
    for i in range(3):
        add(s, bell(2800 + i * 200, 0.2, gain=0.3, ratio=1.48, index=1.5, d=0.2), at=0.15 + i * 0.06)
    write(os.path.join(d, "purchase.wav"), s, 0.6)
    s = buf(2.4)
    for i, n in enumerate((60, 64, 67, 71, 72, 76, 79, 83, 84)):
        add(s, bell(note(n), 1.4, gain=0.5, ratio=2, index=0.8, d=1.2), at=i * 0.11)
        add(s, pluck(note(n), 0.8, gain=0.4, bright=0.6), at=i * 0.11)
    write(os.path.join(d, "unlock.wav"), s, 0.7)
    s = buf(1.4)
    for i in range(12):
        add(s, bell(note(84 + [0, 4, 7, 11, 12, 16][i % 6]), 0.5, gain=0.4, ratio=2, index=0.5), at=i * 0.06)
    write(os.path.join(d, "discovery.wav"), s, 0.6)
    s = buf(0.35); add(s, pluck(note(79), 0.3, bright=0.8)); add(s, pluck(note(86), 0.3, gain=0.6, bright=0.8), at=0.05)
    write(os.path.join(d, "levelup.wav"), s, 0.5)


# ===================================================================== AMBIENCE
def ambience():
    d = os.path.join(ROOT, "ambient")
    L = 22.0
    r = random.Random(77)
    # forest: soft wind + leaf rustle + birds
    s = noise(L + 1.5, lp=0.02, a=0.5, d=999, seed=101, gain=1.0)
    for i in range(len(s)):
        s[i] *= 0.55 + 0.45 * math.sin(TAU * i / SR / 7.3)
    rust = noise(L + 1.5, lp=0.5, hp=0.9, a=0.5, d=999, seed=102, gain=0.12)
    for i in range(len(rust)):
        rust[i] *= max(0.0, math.sin(TAU * i / SR / 5.1)) ** 2
    add(s, rust)
    t = 0.6
    while t < L:
        base = r.choice([2600, 3100, 3500, 2200])
        for k in range(r.randint(2, 5)):
            add(s, sine(base, 0.09, a=0.01, d=0.05, sweep_to=base * r.uniform(1.15, 1.45), gain=0.05), at=t + k * 0.11)
        t += r.uniform(1.4, 3.6)
    write(os.path.join(d, "amb_forest.wav"), loopify(s), 0.5)
    # rain
    s = noise(L + 1.5, lp=0.35, hp=0.0, a=0.5, d=999, seed=201, gain=0.6)
    add(s, noise(L + 1.5, lp=0.06, a=0.5, d=999, seed=202, gain=0.8))
    for _ in range(900):
        add(s, noise(0.01, lp=0.9, d=0.003, seed=r.randint(0, 99999), gain=r.uniform(0.1, 0.4)), at=r.uniform(0, L))
    write(os.path.join(d, "amb_rain.wav"), loopify(s), 0.5)
    # winter wind
    s = buf(L + 1.5)
    nz = noise(L + 1.5, lp=0.5, a=0.5, d=999, seed=301)
    y1 = y2 = 0.0
    for i in range(len(s)):
        tt = i / SR
        fc = 380 + 220 * math.sin(TAU * tt / 9.0) + 90 * math.sin(TAU * tt / 3.1)
        w0 = TAU * fc / SR
        q = 6.0
        alpha = math.sin(w0) / (2 * q)
        # simple resonant band-pass (state-variable-ish)
        y = alpha * nz[i] + 2 * math.cos(w0) * y1 * (1 - alpha) - y2 * (1 - 2 * alpha)
        y2, y1 = y1, y
        s[i] = y * (0.5 + 0.5 * math.sin(TAU * tt / 11.0) ** 2)
    add(s, noise(L + 1.5, lp=0.03, a=0.5, d=999, seed=302, gain=0.25))
    write(os.path.join(d, "amb_winter.wav"), loopify(s), 0.5)


# ===================================================================== MUSIC
def music_willow():
    bpm = 78
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    s = buf(L + 3)
    prog = [(48, [60, 64, 67, 71]), (45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]), (43, [55, 59, 62, 67])]
    patt = [0, 2, 1, 3, 2, 1, 3, 2]
    melody = [None, 76, None, 79, 77, 76, None, 72,  None, 72, 74, 76, None, 74, 72, None,
              69, None, 72, None, 74, 72, 69, None,  71, None, 74, None, 79, None, 77, None]
    for b in range(bars):
        root, ch = prog[b % 4]
        t0 = b * 4 * beat
        add(s, pluck(note(root - 12 + 12), beat * 3.5, gain=0.55, bright=0.25), at=t0)
        add(s, pluck(note(root + 7 - 12 + 12), beat * 1.8, gain=0.35, bright=0.25), at=t0 + 2 * beat)
        for k, pi in enumerate(patt):
            add(s, pluck(note(ch[pi]), beat * 2.2, gain=0.32, bright=0.55, seed=b * 8 + k), at=t0 + k * beat / 2)
        if b >= 4:
            half = (b % 4) * 8
            for k in range(8):
                n = melody[(half + k) % len(melody)]
                if n is not None and (b < 12 or k % 2 == 0):
                    add(s, sine(note(n), beat * 1.1, a=0.04, d=0.5, gain=0.16, vib=0.004), at=t0 + k * beat / 2)
    write(os.path.join(ROOT, "music", "music_willow.wav"), loopify(s[: int((L + 1.5) * SR)], 1.5), 0.7)


def music_frost():
    bpm = 66
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    s = buf(L + 3)
    prog = [(38, [62, 65, 69, 72, 76]), (34, [58, 62, 65, 69, 74]), (41, [60, 65, 69, 72, 76]), (40, [60, 64, 67, 72, 79])]
    for b in range(bars):
        root, ch = prog[b % 4]
        t0 = b * 4 * beat
        pad = buf(4 * beat + 1)
        for n in ch[:3]:
            for det in (-0.003, 0.003):
                add(pad, sine(note(n) * (1 + det), 4 * beat + 0.8, a=0.9, d=3.0, gain=0.08))
        add(s, pad, at=t0)
        add(s, sine(note(root), 4 * beat, a=0.05, d=2.0, gain=0.3), at=t0)
        order = [0, 2, 4, 3, 1, 3, 4, 2]
        for k, oi in enumerate(order):
            if (b + k) % 5 == 4:
                continue
            add(s, bell(note(ch[oi] + 12), 1.2, gain=0.18, ratio=4.0, index=0.9, d=0.9), at=t0 + k * beat / 2)
    write(os.path.join(ROOT, "music", "music_frost.wav"), loopify(s[: int((L + 1.5) * SR)], 1.5), 0.7)


def ambience_wild():
    d = os.path.join(ROOT, "ambient")
    L = 22.0
    r = random.Random(91)
    # jungle: warm air, cicada shimmer, frog croaks and far parrots
    s = noise(L + 1.5, lp=0.03, a=0.5, d=999, seed=401, gain=0.7)
    cic = noise(L + 1.5, lp=0.9, hp=0.95, a=0.5, d=999, seed=402, gain=0.05)
    for i in range(len(cic)):
        cic[i] *= (0.5 + 0.5 * math.sin(TAU * i / SR * 31.0)) * (0.6 + 0.4 * math.sin(TAU * i / SR / 6.0))
    add(s, cic)
    t = 0.4
    while t < L:
        f = r.choice([110, 130, 150])
        for k in range(r.randint(2, 4)):
            add(s, sine(f, 0.12, a=0.01, d=0.08, sweep_to=f * 0.8, gain=0.12, vib=0.05), at=t + k * 0.16)
        t += r.uniform(1.2, 3.0)
    t = 1.5
    while t < L:
        base = r.choice([1500, 1900, 2300])
        add(s, sine(base, 0.18, a=0.01, d=0.12, sweep_to=base * 0.7, gain=0.05), at=t)
        add(s, sine(base * 1.2, 0.14, a=0.01, d=0.1, sweep_to=base * 0.9, gain=0.04), at=t + 0.2)
        t += r.uniform(3.0, 6.0)
    write(os.path.join(d, "amb_jungle.wav"), loopify(s), 0.5)
    # sea: rolling surf swells + gulls
    s = buf(L + 1.5)
    nz = noise(L + 1.5, lp=0.08, a=0.5, d=999, seed=501, gain=1.0)
    hiss = noise(L + 1.5, lp=0.6, hp=0.5, a=0.5, d=999, seed=502, gain=0.25)
    for i in range(len(s)):
        tt = i / SR
        w = max(0.0, math.sin(TAU * tt / 5.5)) ** 3
        s[i] = nz[i] * (0.35 + 0.65 * w) + hiss[i] * w
    t = 2.0
    while t < L:
        base = r.choice([1200, 1400, 1650])
        for k in range(r.randint(1, 3)):
            add(s, sine(base, 0.22, a=0.02, d=0.15, sweep_to=base * 0.65, gain=0.05, vib=0.02), at=t + k * 0.28)
        t += r.uniform(4.0, 8.0)
    write(os.path.join(d, "amb_sea.wav"), loopify(s), 0.5)


def music_delta():
    bpm = 92
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    s = buf(L + 3)
    prog = [(45, [57, 60, 64, 67]), (41, [53, 57, 60, 64]), (43, [55, 59, 62, 67]), (40, [52, 55, 59, 64])]
    pent = [69, 72, 74, 76, 79, 81]
    r = random.Random(12)
    for b in range(bars):
        root, ch = prog[b % 4]
        t0 = b * 4 * beat
        add(s, pluck(note(root), beat * 1.6, gain=0.5, bright=0.3), at=t0)
        add(s, pluck(note(root + 7), beat * 1.2, gain=0.35, bright=0.3), at=t0 + 1.5 * beat)
        add(s, pluck(note(root), beat * 1.2, gain=0.35, bright=0.3), at=t0 + 2.5 * beat)
        for k in range(8):  # marimba-like offbeat chords
            if k % 2 == 1:
                for n in ch[1:3]:
                    add(s, bell(note(n), 0.35, gain=0.08, ratio=4.0, index=0.4, d=0.25), at=t0 + k * beat / 2)
        for k in range(16):  # shaker
            add(s, noise(0.05, lp=0.9, hp=0.8, d=0.03, seed=b * 16 + k, gain=0.05 if k % 4 else 0.09), at=t0 + k * beat / 4)
        if b >= 4:
            for k in range(8):
                if r.random() < 0.55:
                    add(s, bell(note(r.choice(pent)), 0.6, gain=0.13, ratio=3.0, index=0.6, d=0.45), at=t0 + k * beat / 2)
    write(os.path.join(ROOT, "music", "music_delta.wav"), loopify(s[: int((L + 1.5) * SR)], 1.5), 0.7)


def music_trench():
    bpm = 58
    beat = 60 / bpm
    bars = 12
    L = bars * 4 * beat
    s = buf(L + 3)
    prog = [(33, [57, 60, 64]), (29, [53, 57, 60]), (31, [55, 58, 62]), (28, [52, 56, 59])]
    for b in range(bars):
        root, ch = prog[b % 4]
        t0 = b * 4 * beat
        pad = buf(4 * beat + 1)
        for n in ch:
            for det in (-0.004, 0.004):
                add(pad, sine(note(n - 12) * (1 + det), 4 * beat + 0.8, a=1.2, d=3.5, gain=0.07))
        add(s, pad, at=t0)
        add(s, sine(note(root), 4 * beat, a=0.4, d=3.0, gain=0.35, vib=0.002), at=t0)
        for k, oi in enumerate([0, 2, 1, 2]):
            if (b + k) % 3 == 2:
                continue
            add(s, bell(note(ch[oi] + 12), 2.0, gain=0.14, ratio=3.5, index=1.1, d=1.4), at=t0 + k * beat)
    write(os.path.join(ROOT, "music", "music_trench.wav"), loopify(s[: int((L + 1.5) * SR)], 1.5), 0.7)


if __name__ == "__main__":
    import sys as _sys
    if not _sys.argv[1:] or "old" in _sys.argv[1:]:
        sfx()
        print("sfx")
        ambience()
        print("ambience")
    import sys
    which = sys.argv[1:]
    if not which or "old" in which:
        music_willow()
        music_frost()
    ambience_wild()
    music_delta()
    music_trench()
    print("music")
