#!/usr/bin/env python3
"""Erzeugt alle Spielgeräusche deterministisch (nur Python-Standardbibliothek).

Alle Klänge sind eigene Synthesen (Sinus/Rechteck/Rauschen mit Hüllkurven) – keine
Aufnahmen, keine Samples Dritter. Ausgabe: assets/audio/*.wav (16 Bit, mono, 22050 Hz).
Aufruf: python3 tools/generate_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.89 / peak if peak > 0.89 else 1.0
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print("  %-22s %6.2f s" % (name, len(samples) / RATE))


def env_ad(i, n, attack=0.01, decay_pow=2.0):
    t = i / n
    a = min(1.0, (i / RATE) / max(attack, 1e-4))
    return a * (1.0 - t) ** decay_pow


class LowPass:
    def __init__(self, cutoff):
        self.set(cutoff)
        self.y = 0.0

    def set(self, cutoff):
        rc = 1.0 / (2 * math.pi * cutoff)
        dt = 1.0 / RATE
        self.a = dt / (rc + dt)

    def __call__(self, x):
        self.y += self.a * (x - self.y)
        return self.y


def noise(rng):
    return rng.uniform(-1.0, 1.0)


def step():
    rng = random.Random(11)
    n = int(0.13 * RATE)
    lp = LowPass(1400)
    out = []
    for i in range(n):
        e = env_ad(i, n, 0.002, 3.0)
        thump = math.sin(2 * math.pi * 90 * i / RATE) * math.exp(-i / (0.03 * RATE))
        out.append(lp(noise(rng)) * e * 0.8 + thump * 0.5)
    write("step", out)


def jump():
    rng = random.Random(12)
    n = int(0.22 * RATE)
    lp = LowPass(900)
    out = []
    for i in range(n):
        lp.set(600 + 2200 * (i / n))
        out.append(lp(noise(rng)) * math.sin(math.pi * i / n) * 0.7)
    write("jump", out)


def door():
    rng = random.Random(13)
    n = int(0.3 * RATE)
    lp = LowPass(700)
    out = []
    for i in range(n):
        t = i / RATE
        body = math.sin(2 * math.pi * 70 * t) * math.exp(-t / 0.06)
        click = lp(noise(rng)) * math.exp(-t / 0.015)
        out.append(body * 0.8 + click * 0.9)
    write("door", out)


def crash():
    rng = random.Random(14)
    n = int(0.9 * RATE)
    lp = LowPass(2500)
    lp2 = LowPass(300)
    partials = [(523, 0.3), (1187, 0.2), (1733, 0.15), (2411, 0.1)]
    out = []
    for i in range(n):
        t = i / RATE
        nz = lp(noise(rng)) * math.exp(-t / 0.12)
        boom = lp2(noise(rng)) * 3.0 * math.exp(-t / 0.2)
        ring = sum(a * math.sin(2 * math.pi * f * t) for f, a in partials) * math.exp(-t / 0.25)
        out.append(nz * 0.9 + boom * 0.7 + ring * 0.35)
    write("crash", out)


def horn():
    n = int(0.55 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        a = min(1.0, t / 0.02) * min(1.0, (n - i) / (0.05 * RATE))
        s = 0.0
        for f in (392.0, 494.0):
            for h in range(1, 6):
                s += math.sin(2 * math.pi * f * h * t) / h * (0.7 if h % 2 else 0.35)
        out.append(math.tanh(s * 0.9) * a)
    write("horn", out)


def siren():
    # Zweiton-Folge (Quarte), eigene Synthese, nahtlos schleifbar (2 x 0,6 s)
    seg = int(0.6 * RATE)
    out = []
    for k, f in enumerate((440.0, 587.0)):
        phase = 0.0
        for i in range(seg):
            phase += 2 * math.pi * f / RATE
            s = sum(math.sin(phase * h) / h for h in range(1, 7, 2))
            edge = min(1.0, i / (0.01 * RATE), (seg - i) / (0.01 * RATE))
            out.append(s * 0.8 * edge)
    write("siren", out)


def engine(name, base, harmonics, rattle, seed):
    # 1,0 s Schleife mit ganzzahliger Grundfrequenz -> nahtlos
    rng = random.Random(seed)
    n = RATE
    lp = LowPass(1800)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.0
        for h, a in harmonics:
            s += a * math.sin(2 * math.pi * base * h * t + h * 0.7)
        firing = 0.65 + 0.35 * math.sin(2 * math.pi * base * 0.5 * t) ** 2
        s = s * firing + lp(noise(rng)) * rattle
        out.append(math.tanh(s * 1.2) * 0.8)
    # weicher Übergang Ende->Anfang
    fade = int(0.01 * RATE)
    for i in range(fade):
        w = i / fade
        out[i] = out[i] * w + out[n - fade + i] * (1 - w)
    write(name, out[: n - fade])


def ambience():
    rng = random.Random(21)
    n = 8 * RATE
    lp = LowPass(160)
    lp2 = LowPass(900)
    out = []
    swells = [(rng.uniform(0.5, 7.0), rng.uniform(0.8, 2.0)) for _ in range(5)]
    chirps = [rng.uniform(0.3, 7.5) for _ in range(6)]
    for i in range(n):
        t = i / RATE
        rumble = lp(noise(rng)) * 2.4
        s = rumble
        for c, d in swells:
            x = (t - c) / d
            if -1.0 < x < 1.0:
                s += lp2(noise(rng)) * 0.25 * (1 - x * x)
        for c in chirps:
            dt = t - c
            if 0.0 <= dt < 0.12:
                f = 3200 + 900 * math.sin(dt * 90)
                s += 0.05 * math.sin(2 * math.pi * f * dt) * math.sin(math.pi * dt / 0.12)
        out.append(s)
    fade = int(0.5 * RATE)
    for i in range(fade):
        w = i / fade
        out[i] = out[i] * w + out[n - fade + i] * (1 - w)
    write("ambience_city", out[: n - fade])


def tone_seq(name, notes, dur, wave_kind="sine", gap=0.0, tail=0.3):
    out = []
    for f in notes:
        n = int(dur * RATE)
        for i in range(n):
            t = i / RATE
            ph = 2 * math.pi * f * t
            if wave_kind == "square":
                s = sum(math.sin(ph * h) / h for h in (1, 3, 5))
            else:
                s = math.sin(ph) + 0.25 * math.sin(2 * ph) + 0.1 * math.sin(3 * ph)
            out.append(s * env_ad(i, n, 0.005, 1.6) * 0.7)
        out.extend([0.0] * int(gap * RATE))
    out.extend([0.0] * int(tail * RATE))
    write(name, out)


def music_menu():
    # Eigene, ruhige Akkordfolge (Am - F - C - G), 16 s, nahtlos
    chords = [(220.0, 261.63, 329.63), (174.61, 220.0, 261.63), (130.81, 164.81, 196.0), (196.0, 246.94, 293.66)]
    seg = 4 * RATE
    lp = LowPass(1100)
    out = []
    for ci, chord in enumerate(chords):
        for i in range(seg):
            t = i / RATE
            tt = (ci * seg + i) / RATE
            s = 0.0
            for k, f in enumerate(chord):
                vib = 1.0 + 0.003 * math.sin(2 * math.pi * 0.25 * tt + k)
                ph = 2 * math.pi * f * vib * tt
                s += (math.sin(ph) + 0.4 * math.sin(2 * ph + 0.3) + 0.2 * math.sin(3 * ph)) * 0.22
            bass = math.sin(2 * math.pi * chord[0] / 2 * tt) * 0.35
            a = min(1.0, t / 0.8) * min(1.0, (4.0 - t) / 0.8)
            arp_f = chord[int(t * 2) % 3] * 2
            arp_t = (t * 2) % 1.0
            arp = math.sin(2 * math.pi * arp_f * tt) * math.exp(-arp_t * 6) * 0.12
            out.append(lp(s * (0.6 + 0.4 * a) + bass) + arp)
    write("music_menu", out)


def main():
    print("Erzeuge Audio nach", OUT)
    step()
    jump()
    door()
    crash()
    horn()
    siren()
    engine("engine_kompakt", 46, [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)], 0.15, 31)
    engine("engine_sport", 62, [(1, 0.8), (2, 0.7), (3, 0.5), (4, 0.35), (6, 0.2)], 0.2, 32)
    engine("engine_transporter", 38, [(1, 1.0), (2, 0.6), (3, 0.4), (5, 0.2)], 0.35, 33)
    ambience()
    tone_seq("ui_click", [880.0], 0.05, tail=0.02)
    tone_seq("ui_confirm", [660.0, 990.0], 0.07, tail=0.05)
    tone_seq("checkpoint", [1046.5, 1568.0], 0.09, tail=0.1)
    tone_seq("countdown_beep", [660.0], 0.18, "square", tail=0.05)
    tone_seq("countdown_go", [990.0], 0.45, "square", tail=0.05)
    tone_seq("money", [1318.5, 1760.0], 0.08, tail=0.1)
    tone_seq("mission_success", [523.25, 659.25, 783.99, 1046.5], 0.16, tail=0.5)
    tone_seq("mission_fail", [392.0, 349.23, 311.13], 0.24, tail=0.4)
    tone_seq("wanted_up", [784.0, 622.25], 0.12, "square", tail=0.1)
    music_menu()


if __name__ == "__main__":
    main()
