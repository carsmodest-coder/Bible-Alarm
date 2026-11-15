#!/usr/bin/env python3
"""Generates the built-in alarm tones. They are synthesized here from sine waves, so they are
original to this project (no samples or recordings from anywhere else).

Usage: python3 Tools/make_sounds.py BibleAlarm/Resources/Sounds
"""
import os
import sys
import wave

import numpy as np

RATE = 22050
LENGTH = 28.0


def note(freq, dur, harmonics, decay, attack=0.01):
    t = np.arange(int(dur * RATE)) / RATE
    out = np.zeros_like(t)
    for mult, amp in harmonics:
        out += amp * np.sin(2 * np.pi * freq * mult * t) * np.exp(-t * decay * (1 + 0.35 * (mult - 1)))
    env = np.minimum(1.0, t / attack)
    return out * env


def place(track, start, sound, gain=1.0):
    i = int(start * RATE)
    j = min(len(track), i + len(sound))
    if i < len(track):
        track[i:j] += gain * sound[: j - i]


def finish(track, path, rise=6.0):
    # Start quietly and grow: kinder to someone who is asleep.
    t = np.arange(len(track)) / RATE
    track = track * (0.35 + 0.65 * np.minimum(1.0, t / rise))
    track[-int(0.4 * RATE):] *= np.linspace(1, 0, int(0.4 * RATE))
    track = track / np.max(np.abs(track)) * 0.89
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes((track * 32767).astype("<i2").tobytes())
    print(os.path.basename(path), "%.1f s" % (len(track) / RATE), "%.1f MB" % (os.path.getsize(path) / 1e6))


BELL = [(1, 1.0), (2.0, 0.5), (3.0, 0.22), (4.2, 0.12), (5.4, 0.06)]
SOFT = [(1, 1.0), (2.0, 0.25), (3.0, 0.08)]
PLUCK = [(1, 1.0), (2, 0.45), (3, 0.3), (4, 0.16), (5, 0.1), (6, 0.05)]

C4, D4, E4, G4, A4 = 261.63, 293.66, 329.63, 392.00, 440.00
C5, D5, E5, G5, A5, C6 = 523.25, 587.33, 659.25, 783.99, 880.00, 1046.50


def dawn(path):
    """Slow rising bell phrase."""
    track = np.zeros(int(LENGTH * RATE))
    phrase = [C5, E5, G5, C6, G5, E5]
    t = 0.0
    while t < LENGTH - 1:
        for k, f in enumerate(phrase):
            place(track, t + k * 0.55, note(f, 2.6, BELL, 1.6), 0.8)
        place(track, t, note(C4, 4.0, SOFT, 0.7), 0.5)
        t += 4.4
    finish(track, path)


def chimes(path):
    """Bright wind-chime pattern."""
    rng = np.random.default_rng(7)
    track = np.zeros(int(LENGTH * RATE))
    scale = [C5, D5, E5, G5, A5, C6]
    t = 0.0
    while t < LENGTH - 1:
        f = scale[int(rng.integers(0, len(scale)))]
        place(track, t, note(f, 2.2, BELL, 2.4), float(rng.uniform(0.5, 0.9)))
        t += float(rng.choice([0.28, 0.42, 0.56, 0.84]))
    finish(track, path)


def harp(path):
    """Plucked arpeggios."""
    track = np.zeros(int(LENGTH * RATE))
    chords = [[C4, E4, G4, C5, E5, G5], [A4 / 2, C4, E4, A4, C5, E5], [D4, G4, 493.88, D5, G5, 987.77], [C4, E4, G4, C5, E5, C6]]
    t = 0.0
    c = 0
    while t < LENGTH - 1:
        for k, f in enumerate(chords[c % len(chords)]):
            place(track, t + k * 0.22, note(f, 2.4, PLUCK, 2.0, attack=0.004), 0.7)
        t += 2.2
        c += 1
    finish(track, path)


def still_waters(path):
    """Warm, slow two-note swell."""
    track = np.zeros(int(LENGTH * RATE))
    t = 0.0
    pairs = [(E4, G4), (D4, G4), (C4, E4), (D4, A4)]
    k = 0
    while t < LENGTH - 1:
        a, b = pairs[k % len(pairs)]
        for f in (a, b, a * 2):
            n = note(f, 3.4, SOFT, 0.5, attack=0.9)
            place(track, t, n, 0.6)
        place(track, t + 1.7, note(b * 2, 2.0, BELL, 2.0), 0.35)
        t += 3.4
        k += 1
    finish(track, path, rise=8.0)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    dawn(os.path.join(out, "dawn.wav"))
    chimes(os.path.join(out, "chimes.wav"))
    harp(os.path.join(out, "harp.wav"))
    still_waters(os.path.join(out, "still_waters.wav"))
