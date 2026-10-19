#!/usr/bin/env python3
"""
Mirrorlock -- procedural audio.

Synthesises every sound effect and both music loops from scratch (no samples,
no third-party material) using only the Python standard library:

    python3 tools/synth_audio.py

Writes 16-bit mono WAV files to assets/audio/sfx and assets/audio/music.
Deterministic (fixed seeds): rerunning gives identical files. Released with the
project under CC0 terms.

Music loops are rendered for their loop length plus a tail; the tail is folded
back onto the start so ringing notes carry across the loop point seamlessly.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SFX_SR = 44100
MUSIC_SR = 22050
TAU = 2 * math.pi


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def buf(seconds, sr):
    return [0.0] * int(seconds * sr)


def env_ad(t, attack, decay):
    """Attack then exponential decay."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def add_bell(out, sr, start, freq, dur, amp, decay=0.45, partials=((1, 1.0), (2.0, 0.35), (3.01, 0.12), (4.2, 0.06))):
    """Soft bell / music-box tone: a few slightly inharmonic partials."""
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    for i in range(max(0, n)):
        t = i / sr
        e = env_ad(t, 0.004, decay)
        v = 0.0
        for mult, a in partials:
            v += a * math.sin(TAU * freq * mult * t) * math.exp(-t * (mult - 1) * 1.6)
        out[s0 + i] += amp * e * v


def add_pluck(out, sr, start, freq, dur, amp):
    """Marimba-like pluck."""
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    for i in range(max(0, n)):
        t = i / sr
        e = env_ad(t, 0.002, 0.07)
        v = math.sin(TAU * freq * t) + 0.25 * math.sin(TAU * freq * 4 * t) * math.exp(-t * 40)
        out[s0 + i] += amp * e * v


def add_pad(out, sr, start, freqs, dur, amp, attack=1.2, release=1.5):
    """Warm detuned pad chord with slow swell."""
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    for i in range(max(0, n)):
        t = i / sr
        if t < attack:
            e = (t / attack) ** 2
        elif t > dur - release:
            e = max(0.0, (dur - t) / release) ** 2
        else:
            e = 1.0
        v = 0.0
        for f in freqs:
            v += math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * 1.003 * t + 1.0) + 0.18 * math.sin(TAU * f * 2 * t)
        out[s0 + i] += amp * e * v / len(freqs)


def add_noise_swell(out, sr, start, dur, amp, seed, lo=0.02, hi=0.25):
    """Breathy whoosh: one-pole filtered noise whose brightness rises then falls."""
    rnd = random.Random(seed)
    s0 = int(start * sr)
    n = min(int(dur * sr), len(out) - s0)
    y = 0.0
    for i in range(max(0, n)):
        p = i / n
        e = math.sin(math.pi * p) ** 2
        k = lo + (hi - lo) * math.sin(math.pi * p)
        y += k * (rnd.uniform(-1, 1) - y)
        out[s0 + i] += amp * e * y


def reverb(x, sr, mix=0.25, room=0.82):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    combs = [int(sr * d) for d in (0.0297, 0.0371, 0.0411, 0.0437)]
    wet = [0.0] * len(x)
    for d in combs:
        b = [0.0] * d
        idx = 0
        for i, s in enumerate(x):
            y = b[idx]
            b[idx] = s + y * room
            idx = (idx + 1) % d
            wet[i] += y * 0.25
    for d, g in ((int(sr * 0.005), 0.7), (int(sr * 0.0017), 0.7)):
        b = [0.0] * d
        idx = 0
        for i, s in enumerate(wet):
            bo = b[idx]
            y = -g * s + bo
            b[idx] = s + g * y
            idx = (idx + 1) % d
            wet[i] = y
    return [a * (1 - mix) + w * mix for a, w in zip(x, wet)]


def normalize(x, peak=0.85):
    m = max(1e-9, max(abs(v) for v in x))
    return [v * peak / m for v in x]


def fade_edges(x, sr, fin=0.002, fout=0.02):
    a = int(fin * sr)
    b = int(fout * sr)
    for i in range(min(a, len(x))):
        x[i] *= i / a
    for i in range(min(b, len(x))):
        x[len(x) - 1 - i] *= i / b
    return x


def write(path, x, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in x))
    print("wrote", os.path.relpath(path, ROOT), "%.2fs" % (len(x) / sr))


# ----------------------------------------------------------------------------- SFX

def sfx_tap():
    sr = SFX_SR
    x = buf(0.18, sr)
    add_pluck(x, sr, 0, mtof(84), 0.18, 0.8)
    return fade_edges(x, sr)


def sfx_click():
    sr = SFX_SR
    x = buf(0.06, sr)
    add_pluck(x, sr, 0, mtof(91), 0.06, 0.5)
    return fade_edges(x, sr)


def sfx_zip():
    """A quick rising whoosh: the twins sliding off the board."""
    sr = SFX_SR
    x = buf(0.42, sr)
    n = int(0.34 * sr)
    phase = 0.0
    rnd = random.Random(31)
    y = 0.0
    for i in range(n):
        t = i / sr
        p = t / 0.34
        f = 520 + 1900 * p ** 1.6
        phase += TAU * f / sr
        e = math.sin(math.pi * min(1.0, p)) ** 1.5
        y += 0.35 * (rnd.uniform(-1, 1) - y)
        x[i] += e * (0.22 * math.sin(phase) + 0.10 * math.sin(2 * phase) + 0.45 * y * p)
    return fade_edges(reverb(x, sr, 0.2), sr)


def sfx_chime():
    """Two bells a fifth apart, struck together: twins escaping as one."""
    sr = SFX_SR
    x = buf(1.2, sr)
    add_bell(x, sr, 0.0, mtof(84), 1.1, 0.42, decay=0.45)
    add_bell(x, sr, 0.012, mtof(91), 1.0, 0.32, decay=0.4)
    add_bell(x, sr, 0.03, mtof(96), 0.7, 0.12, decay=0.25)
    return fade_edges(reverb(x, sr, 0.32), sr)


def sfx_bump():
    """A soft thud with a short rattle."""
    sr = SFX_SR
    x = buf(0.32, sr)
    rnd = random.Random(5)
    for i in range(int(0.3 * sr)):
        t = i / sr
        f = 140 * math.exp(-t * 9) + 60
        x[i] += 0.8 * math.exp(-t * 16) * math.sin(TAU * f * t)
        x[i] += 0.25 * math.exp(-t * 40) * rnd.uniform(-1, 1)
    return fade_edges(x, sr)


def sfx_heart():
    """Losing a heart: a falling minor third."""
    sr = SFX_SR
    x = buf(0.5, sr)
    for k, m in enumerate((69, 65)):
        s0 = int(k * 0.11 * sr)
        for i in range(int(0.26 * sr)):
            t = i / sr
            e = env_ad(t, 0.005, 0.09)
            ph = (mtof(m) * t) % 1.0
            tri = 4 * abs(ph - 0.5) - 1
            x[s0 + i] += 0.55 * e * tri
    return fade_edges(reverb(x, sr, 0.18), sr)


def sfx_crumble():
    """A stone breaking up: gritty noise bursts, low and short."""
    sr = SFX_SR
    x = buf(0.6, sr)
    rnd = random.Random(19)
    for b in range(7):
        s0 = int((0.02 + b * 0.055 + rnd.uniform(0, 0.02)) * sr)
        y = 0.0
        for i in range(int(0.09 * sr)):
            if s0 + i >= len(x):
                break
            t = i / sr
            y += 0.18 * (rnd.uniform(-1, 1) - y)
            x[s0 + i] += (0.7 - b * 0.07) * math.exp(-t * 45) * y
    return fade_edges(reverb(x, sr, 0.15), sr)


def sfx_hint():
    sr = SFX_SR
    x = buf(0.9, sr)
    rnd = random.Random(7)
    notes = [84, 88, 91, 96, 100]
    for k, m in enumerate(notes):
        add_bell(x, sr, k * 0.05 + rnd.uniform(0, 0.01), mtof(m), 0.5, 0.25, decay=0.18,
                 partials=((1, 1.0), (2.76, 0.2)))
    return fade_edges(reverb(x, sr, 0.35), sr)


def sfx_undo():
    sr = SFX_SR
    x = buf(0.36, sr)
    n = int(0.3 * sr)
    phase = 0.0
    for i in range(n):
        t = i / sr
        p = t / 0.3
        f = 1500 - 1000 * p
        phase += TAU * f / sr
        x[i] += 0.3 * math.sin(math.pi * p) * math.sin(phase)
    return fade_edges(reverb(x, sr, 0.2), sr)


def sfx_complete():
    sr = SFX_SR
    x = buf(2.6, sr)
    for k, m in enumerate((72, 79, 76, 84, 88, 91, 96)):
        add_bell(x, sr, k * 0.085, mtof(m), 1.8, 0.33, decay=0.7)
    add_pad(x, sr, 0.0, [mtof(m) for m in (48, 55, 60, 64)], 2.5, 0.35, attack=0.4, release=1.6)
    add_noise_swell(x, sr, 0.0, 0.6, 0.15, 11)
    return fade_edges(reverb(x, sr, 0.3), sr)


def sfx_fail():
    sr = SFX_SR
    x = buf(1.4, sr)
    for k, m in enumerate((67, 63, 60)):
        add_bell(x, sr, k * 0.16, mtof(m), 1.0, 0.35, decay=0.5, partials=((1, 1.0), (2.0, 0.25)))
    add_pad(x, sr, 0.1, [mtof(m) for m in (48, 51, 55)], 1.2, 0.25, attack=0.2, release=0.9)
    return fade_edges(reverb(x, sr, 0.3), sr)


def sfx_coin():
    sr = SFX_SR
    x = buf(0.5, sr)
    add_bell(x, sr, 0, mtof(83), 0.2, 0.4, decay=0.08, partials=((1, 1.0), (2.0, 0.3)))
    add_bell(x, sr, 0.07, mtof(88), 0.43, 0.45, decay=0.2, partials=((1, 1.0), (2.0, 0.3), (3.0, 0.1)))
    return fade_edges(reverb(x, sr, 0.2), sr)


def sfx_unlock():
    sr = SFX_SR
    x = buf(1.8, sr)
    for k, m in enumerate((67, 72, 76, 79, 84)):
        add_bell(x, sr, k * 0.12, mtof(m), 1.4, 0.32, decay=0.6)
    add_noise_swell(x, sr, 0, 0.9, 0.2, 13)
    return fade_edges(reverb(x, sr, 0.35), sr)


def sfx_open():
    """Soft rising whoosh used when a card opens."""
    sr = SFX_SR
    x = buf(0.35, sr)
    add_noise_swell(x, sr, 0, 0.3, 0.35, 17, 0.03, 0.2)
    return fade_edges(x, sr)


# ----------------------------------------------------------------------------- Music

def loop_track(seconds, tail, seed, bpm, chords, melody_density, melody_oct, pad_amp, bell_amp):
    sr = MUSIC_SR
    total = seconds + tail
    x = buf(total, sr)
    rnd = random.Random(seed)
    beat = 60.0 / bpm
    bars = len(chords)
    bar_len = seconds / bars
    scale = [0, 2, 4, 7, 9]  # major pentatonic
    for b, (root, quality) in enumerate(chords):
        t0 = b * bar_len
        third = 4 if quality == "maj" else 3
        tones = [root, root + 7, root + 12 + third, root + 19]
        add_pad(x, sr, t0, [mtof(m) for m in tones], bar_len + 1.6, pad_amp, attack=1.4, release=1.6)
        add_bell(x, sr, t0, mtof(root - 12), 2.5, bell_amp * 0.5, decay=1.2, partials=((1, 1.0), (2, 0.2)))
        steps = int(round(bar_len / (beat / 2)))
        prev = rnd.choice(scale)
        for s in range(steps):
            if rnd.random() > melody_density:
                continue
            idx = scale.index(prev) + rnd.choice((-1, 0, 1, 1, 2, -2))
            idx = max(0, min(len(scale) * 2 - 1, idx))
            prev = scale[idx % len(scale)]
            note = 12 * melody_oct + (12 if idx >= len(scale) else 0) + scale[idx % len(scale)]
            add_bell(x, sr, t0 + s * beat / 2, mtof(note), 1.6, bell_amp * rnd.uniform(0.7, 1.0), decay=0.6)
    x = reverb(x, sr, 0.35, 0.86)
    n = int(seconds * sr)
    y = x[:n]
    for i in range(len(x) - n):
        y[i % n] += x[n + i]
    return normalize(y, 0.6)


def main():
    sfx = {
        "tap": sfx_tap, "click": sfx_click, "zip": sfx_zip, "chime": sfx_chime, "bump": sfx_bump,
        "heart": sfx_heart, "crumble": sfx_crumble, "hint": sfx_hint, "undo": sfx_undo,
        "complete": sfx_complete, "fail": sfx_fail, "coin": sfx_coin, "unlock": sfx_unlock,
        "open": sfx_open, "error": sfx_heart,
    }
    for name, fn in sfx.items():
        write(os.path.join(SFX_DIR, name + ".wav"), normalize(fn(), 0.8), SFX_SR)
    # Glassy, mirrored calm: I - vi - IV - V in F for the menu, C for play.
    menu = loop_track(32.0, 4.0, 23, 72, [(53, "maj"), (50, "min"), (58, "maj"), (60, "maj")] * 2, 0.42, 6, 0.5, 0.32)
    write(os.path.join(MUSIC_DIR, "menu.wav"), menu, MUSIC_SR)
    play = loop_track(40.0, 4.0, 37, 64, [(48, "maj"), (45, "min"), (53, "maj"), (55, "maj"), (48, "maj"), (52, "min"), (53, "maj"), (55, "maj")], 0.28, 6, 0.42, 0.26)
    write(os.path.join(MUSIC_DIR, "play.wav"), play, MUSIC_SR)


if __name__ == "__main__":
    main()
