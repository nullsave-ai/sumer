#!/usr/bin/env python3
"""Generates all audio assets for Sarab (SFX + looping music) procedurally.

Everything is synthesized from scratch (no samples, no licensing issues).
Run:  python3 tools/gen_audio.py   ->  writes assets/audio/*.wav
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR * decay)


def fade(x, a=0.004, b=0.02):
    n = len(x)
    fa = min(int(SR * a), n // 2)
    fb = min(int(SR * b), n // 2)
    if fa > 0:
        x[:fa] *= np.linspace(0, 1, fa)
    if fb > 0:
        x[-fb:] *= np.linspace(1, 0, fb)
    return x


def lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def hp(x, cutoff):
    return x - lp(x, cutoff)


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    return np.sin(2 * np.pi * freq * t + phase)


def sweep(f0, f1, dur, curve=1.0):
    t = t_axis(dur)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def save(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * gain
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", path, f"{len(x)/SR:.2f}s")


def pluck(freq, dur, bright=1.0, decay=5.0):
    """Oud-like plucked tone (additive, fast attack, harmonic decay)."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for h in range(1, 9):
        amp = (1.0 / h) * (bright ** (h - 1))
        d = decay * (1 + 0.55 * (h - 1))
        out += amp * np.sin(2 * np.pi * freq * h * t) * np.exp(-t * d)
    out *= np.minimum(1.0, t / 0.003)
    return out


# ------------------------------------------------------------------ SFX
def make_coin():
    a = sine(988, 0.22) * env_exp(int(SR * 0.22), 14)
    b = np.concatenate([np.zeros(int(SR * 0.07)), sine(1319, 0.22) * env_exp(int(SR * 0.22), 12)])
    n = max(len(a), len(b))
    x = np.zeros(n)
    x[: len(a)] += a
    x[: len(b)] += b * 1.1
    x += 0.25 * np.concatenate([np.zeros(int(SR * 0.07)), sine(2638, 0.22) * env_exp(int(SR * 0.22), 20)])[:n]
    save("coin", fade(x))


def make_shard():
    n = int(SR * 0.45)
    x = np.zeros(n)
    for i, f in enumerate([1568, 2093, 2637, 3136]):
        s = sine(f, 0.45) * env_exp(n, 9 + i * 2)
        x += s * (0.7 ** i) * (1 + 0.15 * np.sin(2 * np.pi * 14 * t_axis(0.45)))
    save("shard", fade(x))


def make_jump():
    n = int(SR * 0.26)
    w = hp(noise(0.26), 800) * np.hanning(n) * 0.5
    s = sweep(240, 640, 0.26, 0.8) * np.hanning(n) * 0.7
    save("jump", fade(w + s))


def make_land():
    n = int(SR * 0.16)
    t = sweep(120, 55, 0.16) * env_exp(n, 22)
    w = lp(noise(0.16), 700) * env_exp(n, 30) * 0.7
    save("land", fade(t + w), 0.7)


def make_slide():
    n = int(SR * 0.55)
    w = noise(0.55)
    w = hp(lp(w, 4200), 600)
    e = np.minimum(1, np.arange(n) / (SR * 0.05)) * np.exp(-np.arange(n) / SR * 3.2)
    save("slide", fade(w * e), 0.7)


def make_lane():
    n = int(SR * 0.11)
    w = hp(lp(noise(0.11), 3500), 900) * np.hanning(n)
    save("lane", fade(w), 0.5)


def make_hit():
    n = int(SR * 0.42)
    t = sweep(150, 45, 0.42, 0.6) * env_exp(n, 9)
    w = lp(noise(0.42), 1800) * env_exp(n, 14) * 0.9
    save("hit", fade(t + w), 0.95)


def make_shift_in():
    dur = 0.7
    n = int(SR * dur)
    x = sweep(180, 1600, dur, 2.2) * np.sin(np.pi * np.arange(n) / n) ** 0.6
    x += 0.5 * sweep(185, 1620, dur, 2.2) * np.sin(np.pi * np.arange(n) / n) ** 0.6
    sh = hp(noise(dur), 2500) * np.hanning(n) * 0.35
    save("shift_in", fade(x * 0.6 + sh))


def make_shift_out():
    dur = 0.5
    n = int(SR * dur)
    x = sweep(1500, 200, dur, 0.7) * env_exp(n, 4)
    x += 0.5 * sweep(1520, 205, dur, 0.7) * env_exp(n, 4)
    save("shift_out", fade(x))


def make_powerup():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        parts.append((i * 0.07, pluck(f, 0.5, 0.8, 6)))
    total = int(SR * (0.07 * 3 + 0.5))
    x = np.zeros(total)
    for off, p in parts:
        o = int(off * SR)
        x[o : o + len(p)] += p[: total - o]
    save("powerup", fade(x))


def make_graze():
    dur = 0.18
    n = int(SR * dur)
    w = hp(noise(dur), 2500) * np.hanning(n) * 0.5
    p = sine(1760, dur) * env_exp(n, 20) * 0.6
    save("graze", fade(w + p), 0.6)


def make_gameover():
    # descending Hijaz-flavoured phrase
    seq = [(587.33, 0.0), (554.37, 0.22), (466.16, 0.44), (392.0, 0.66), (293.66, 0.95)]
    total = int(SR * 2.2)
    x = np.zeros(total)
    for f, off in seq:
        p = pluck(f, 1.2, 0.85, 3.2)
        o = int(off * SR)
        x[o : o + len(p)] += p[: total - o]
    save("gameover", fade(x, 0.003, 0.2))


def make_click():
    n = int(SR * 0.05)
    x = sine(1200, 0.05) * env_exp(n, 60)
    save("click", fade(x), 0.5)


def make_buy():
    seq = [(784, 0.0), (988, 0.08), (1175, 0.16), (1568, 0.24)]
    total = int(SR * 0.9)
    x = np.zeros(total)
    for f, off in seq:
        p = pluck(f, 0.6, 0.8, 5)
        o = int(off * SR)
        x[o : o + len(p)] += p[: total - o]
    save("buy", fade(x))


def make_storm():
    dur = 6.0
    n = int(SR * dur)
    w = lp(noise(dur), 520)
    w2 = lp(noise(dur), 160) * 2.0
    mod = 0.65 + 0.35 * np.sin(2 * np.pi * 0.37 * t_axis(dur) + 1.0) * np.sin(2 * np.pi * 0.11 * t_axis(dur))
    x = (w + w2) * mod
    # seamless loop: crossfade tail into head
    xf = int(SR * 0.5)
    x[:xf] = x[:xf] * np.linspace(0, 1, xf) + x[-xf:] * np.linspace(1, 0, xf)
    x = x[:-xf]
    save("storm", x, 0.8)


# ------------------------------------------------------------------ MUSIC
def make_music():
    """8 bars of driving Hijaz groove (D E-flat F# G A B-flat C) at 112 BPM."""
    bpm = 112
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    tail = 1.2
    total = int(SR * (dur + tail))
    mix = np.zeros(total)

    def add(sig, at):
        o = int(at * SR)
        if o >= total:
            return
        e = min(total, o + len(sig))
        mix[o:e] += sig[: e - o]

    # drone: D2 + A2 breathing
    t = t_axis(dur + tail)
    drone = 0.18 * np.sin(2 * np.pi * 73.42 * t) + 0.11 * np.sin(2 * np.pi * 110.0 * t)
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * (1 / (bars * 4 * beat)) * 4 * t)
    mix += drone

    # darbuka: doum (D) / tek (T) / ka (k) -- maqsum rhythm  D T k T D k T k
    pat = ["D", "T", "k", "T", "D", "k", "T", "k"]
    step = beat / 2
    steps = bars * 8
    doum = sweep(130, 62, 0.22, 0.5) * env_exp(int(SR * 0.22), 14)
    tek = hp(lp(noise(0.08), 7000), 2500) * env_exp(int(SR * 0.08), 55)
    ka = hp(lp(noise(0.05), 6000), 3500) * env_exp(int(SR * 0.05), 70) * 0.6
    for i in range(steps):
        c = pat[i % 8]
        at = i * step
        if c == "D":
            add(doum * 0.9, at)
        elif c == "T":
            add(tek * 0.55, at)
        else:
            add(ka * 0.7, at)
    # hand-clap on 2 and 4 of each bar
    for b in range(bars * 4):
        if b % 2 == 1:
            clap = hp(lp(noise(0.12), 5200), 1200) * env_exp(int(SR * 0.12), 28)
            add(clap * 0.3, b * beat)

    # bass pulse on D / A
    D2, A2, C3, Bb2 = 73.42, 110.0, 130.81, 116.54
    bass_notes = [D2, D2, A2, D2, Bb2, Bb2, A2, C3]
    for b in range(bars * 4):
        f = bass_notes[(b // 1) % 8]
        s = sine(f, beat * 0.9) * np.exp(-t_axis(beat * 0.9) * 4.5)
        add(s * 0.28, b * beat)

    # melody in Hijaz; phrases of 2 bars, repeated with variation
    D4, Eb4, Fs4, G4, A4, Bb4, C5, D5, Eb5, Fs5 = 293.66, 311.13, 369.99, 392.0, 440.0, 466.16, 523.25, 587.33, 622.25, 739.99
    phrases = [
        [(D4, 0.5), (Eb4, 0.5), (Fs4, 1.0), (G4, 0.5), (Fs4, 0.5), (Eb4, 0.5), (D4, 0.5), (Eb4, 1.0), (D4, 1.0)],
        [(A4, 0.5), (Bb4, 0.5), (A4, 0.5), (G4, 0.5), (Fs4, 1.0), (G4, 0.5), (A4, 0.5), (Eb4, 1.0), (D4, 1.0)],
        [(D5, 0.5), (C5, 0.5), (Bb4, 0.5), (A4, 0.5), (G4, 1.0), (Fs4, 0.5), (G4, 0.5), (A4, 1.0), (D4, 1.0)],
        [(Fs4, 0.5), (G4, 0.5), (A4, 0.5), (Bb4, 0.5), (C5, 1.0), (Bb4, 0.5), (A4, 0.5), (Fs4, 0.5), (Eb4, 0.5), (D4, 1.0)],
    ]
    pos = 0.0
    for p_i in range(4):
        ph = phrases[p_i]
        pos = p_i * 8 * beat
        for f, d in ph:
            n = pluck(f, d * beat * 2.2 + 0.3, 0.85, 4.0)
            add(n * 0.30, pos)
            if p_i % 2 == 1:
                add(pluck(f * 2, d * beat * 1.4 + 0.2, 0.7, 7.0) * 0.07, pos + 0.02)
            pos += d * beat
    # upper counter-line in the second half
    for b in range(16, 32):
        if b % 2 == 0:
            f = [D5, C5, Bb4, A4][((b - 16) // 2) % 4]
            add(pluck(f, 0.5, 0.8, 6.0) * 0.12, b * beat + beat * 0.5)

    # fold the reverb-ish tail back to the start for a seamless loop
    loop_n = int(SR * dur)
    body = mix[:loop_n].copy()
    tl = mix[loop_n:]
    body[: len(tl)] += tl
    body = fade(body, 0.002, 0.002)
    save("music", body, 0.8)


if __name__ == "__main__":
    make_coin()
    make_shard()
    make_jump()
    make_land()
    make_slide()
    make_lane()
    make_hit()
    make_shift_in()
    make_shift_out()
    make_powerup()
    make_graze()
    make_gameover()
    make_click()
    make_buy()
    make_storm()
    make_music()
