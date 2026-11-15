#!/usr/bin/env python3
"""Generates the game's music loop and sound effects into assets/audio/.

Run from the project folder:  python3 tools/make_audio.py
Needs numpy (pip install numpy).

Everything is synthesised from sine waves and noise, so there are no samples
to license. To use your own audio, replace any .wav with a file of the same
name and stop running this script for it.
"""
import os
import wave
import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
RATE = 22050


def hz(note):
    """'C4', 'F#3', 'A5' -> frequency."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semis = names[note[0]] + (1 if "#" in note else 0) + 12 * (int(note[-1]) + 1)
    return 440.0 * 2 ** ((semis - 69) / 12)


def tone(freq, seconds, decay, harmonics=((1, 1.0),), attack=0.005):
    t = np.arange(int(seconds * RATE)) / RATE
    wave_ = sum(a * np.sin(2 * np.pi * freq * h * t) for h, a in harmonics)
    env = np.exp(-t * decay) * np.minimum(1.0, t / attack)
    return wave_ * env


def save(name, samples, peak=0.8):
    samples = samples / max(1e-9, np.max(np.abs(samples))) * peak
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((samples * 32767).astype("<i2").tobytes())


def add(track, sound, at, gain=1.0):
    """Mix `sound` into `track` at `at` seconds, wrapping round the end so the
    loop has no seam."""
    start = int(at * RATE)
    idx = (start + np.arange(len(sound))) % len(track)
    np.add.at(track, idx, sound * gain)


PLUCK = ((1, 1.0), (2, 0.35), (3, 0.12))
BELL = ((1, 1.0), (2.01, 0.4), (4.02, 0.15))
SOFT = ((1, 1.0), (2, 0.15))


def make_music():
    beat = 60 / 84
    bars = 8
    track = np.zeros(int(bars * 4 * beat * RATE))
    chords = [
        ("C3", ["C4", "E4", "G4", "E4"]), ("A2", ["A3", "C4", "E4", "C4"]),
        ("F2", ["F3", "A3", "C4", "A3"]), ("G2", ["G3", "B3", "D4", "B3"]),
    ]
    melody = {  # bar -> [(beat, note, length in beats)]
        2: [(0, "E5", 1), (1, "G5", 1), (2, "A5", 2)],
        3: [(0, "G5", 1.5), (1.5, "E5", 0.5), (2, "D5", 2)],
        4: [(0, "E5", 1), (1, "G5", 0.5), (1.5, "A5", 0.5), (2, "C6", 2)],
        5: [(0, "A5", 1), (1, "G5", 1), (2, "E5", 2)],
        6: [(0, "C5", 1), (1, "D5", 1), (2, "E5", 1), (3, "G5", 1)],
        7: [(0, "D5", 2), (2.5, "C5", 1.5)],
    }
    for bar in range(bars):
        root, arp = chords[bar % 4]
        at = bar * 4 * beat
        add(track, tone(hz(root), 4 * beat, 0.9, SOFT, attack=0.03), at, 0.55)
        add(track, tone(hz(root) * 2, 2 * beat, 1.5, SOFT, attack=0.03), at + 2 * beat, 0.25)
        for i in range(8):
            add(track, tone(hz(arp[i % 4]), 1.2 * beat, 5.0, PLUCK), at + i * beat / 2, 0.22 if i % 2 else 0.3)
        for when, note, length in melody.get(bar, []):
            add(track, tone(hz(note), length * beat + 0.6, 3.0, BELL), at + when * beat, 0.3)
    echo = np.roll(track, int(0.75 * beat * RATE)) * 0.3 + np.roll(track, int(1.5 * beat * RATE)) * 0.12
    save("garden_theme", track + echo, peak=0.7)


def sweep(f0, f1, seconds, decay):
    t = np.arange(int(seconds * RATE)) / RATE
    freq = f0 + (f1 - f0) * t / seconds
    return np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * decay)


def noise(seconds, decay, smooth):
    rng = np.random.default_rng(7)
    n = rng.uniform(-1, 1, int(seconds * RATE))
    n = np.convolve(n, np.ones(smooth) / smooth, mode="same")
    return n * np.exp(-np.arange(len(n)) / RATE * decay)


def sequence(notes, gap, length, decay, harmonics):
    out = np.zeros(int((gap * len(notes) + length) * RATE))
    for i, note in enumerate(notes):
        s = tone(hz(note), length, decay, harmonics)
        out[int(i * gap * RATE):int(i * gap * RATE) + len(s)] += s
    return out


def make_effects():
    soil = noise(0.14, 28, 14) * 2.0
    soil[:len(sweep(140, 60, 0.12, 30))] += sweep(140, 60, 0.12, 30) * 0.6
    save("soil", soil, 0.7)
    water = np.zeros(int(0.42 * RATE))
    for i, (f0, f1) in enumerate(((900, 500), (1100, 650), (800, 480))):
        s = sweep(f0, f1, 0.1, 22)
        water[int(i * 0.1 * RATE):int(i * 0.1 * RATE) + len(s)] += s
    save("water", water + noise(0.42, 9, 5) * 0.25, 0.5)
    save("plant", sweep(320, 720, 0.09, 18), 0.6)
    save("pet", sequence(["E6", "A6"], 0.09, 0.4, 9, BELL), 0.5)
    save("pick", sequence(["C5", "E5", "G5"], 0.06, 0.3, 12, PLUCK), 0.6)
    save("morning", sequence(["C5", "E5", "G5", "C6"], 0.16, 1.2, 3, BELL), 0.6)
    save("grow", sequence(["G5", "C6", "E6", "G6", "C7"], 0.09, 1.0, 4, BELL), 0.55)
    save("page", noise(0.16, 16, 3), 0.3)
    save("step", noise(0.05, 60, 10) * 1.5, 0.22)
    # The clock tower bending time: a bell, clockwork ticking faster and
    # faster under a rising whoosh, a crash, then a small "ta-da".
    warp = np.zeros(int(3.9 * RATE))

    def at(sound, when, gain=1.0):
        start = int(when * RATE)
        end = min(len(warp), start + len(sound))
        warp[start:end] += sound[:end - start] * gain

    at(tone(hz("C3"), 1.6, 2.2, BELL), 0.0, 0.9)
    at(tone(hz("G3"), 1.4, 2.5, BELL), 0.05, 0.5)
    when, gap = 0.45, 0.22
    while when < 2.45:
        at(tone(1400 + when * 500, 0.04, 90, SOFT), when, 0.35)
        when += gap
        gap = max(0.03, gap * 0.86)
    t = np.arange(int(2.0 * RATE)) / RATE
    whoosh = np.sin(2 * np.pi * np.cumsum(180 + 900 * (t / 2.0) ** 2) / RATE) * (t / 2.0) ** 1.5
    at(whoosh, 0.5, 0.45)
    at(noise(0.9, 5, 2), 2.5, 1.1)
    at(tone(hz("C2"), 0.9, 4, SOFT), 2.5, 0.9)
    at(sequence(["G5", "C6"], 0.14, 0.7, 5, BELL), 3.05, 0.5)
    save("warp", warp, 0.75)


if __name__ == "__main__":
    make_music()
    make_effects()
    print("audio written to", os.path.normpath(OUT))
