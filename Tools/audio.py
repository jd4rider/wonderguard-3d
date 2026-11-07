#!/usr/bin/env python3
"""Synthesise every sound in Wonderguard 3D.

    python3 Tools/audio.py

Standard library only: the WAVs are written sample by sample so the repository
holds no opaque audio downloads. Re-running is deterministic.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "Assets", "Audio", "SFX")
MUSIC_DIR = os.path.join(ROOT, "Assets", "Audio", "Music")
RATE = 22050


def write(path: str, samples: list[float], peak: float = 0.82) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = bytearray()
    for value in samples:
        clamped = max(-1.0, min(1.0, value * peak))
        data += struct.pack("<h", int(clamped * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(data))
    print("wrote", os.path.relpath(path, ROOT), f"{len(samples) / RATE:.2f}s")


def tone(freq: float, seconds: float, decay: float = 8.0, kind: str = "sine") -> list[float]:
    out = []
    count = int(RATE * seconds)
    for i in range(count):
        t = i / RATE
        env = math.exp(-decay * t)
        phase = math.tau * freq * t
        if kind == "square":
            value = (1.0 if math.sin(phase) >= 0 else -1.0) * 0.5
        elif kind == "saw":
            value = 2.0 * ((freq * t) % 1.0) - 1.0
        elif kind == "tri":
            value = 2.0 * abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0
        else:
            value = math.sin(phase)
        out.append(value * env)
    return out


def mix(*tracks: list[float]) -> list[float]:
    length = max(len(track) for track in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, value in enumerate(track):
            out[i] += value
    return out


def concat(*tracks: list[float]) -> list[float]:
    out: list[float] = []
    for track in tracks:
        out.extend(track)
    return out


def sweep(start: float, end: float, seconds: float, decay: float = 5.0, kind: str = "sine") -> list[float]:
    out = []
    count = int(RATE * seconds)
    phase = 0.0
    for i in range(count):
        t = i / RATE
        freq = start + (end - start) * (i / count)
        phase += math.tau * freq / RATE
        value = math.sin(phase)
        if kind == "square":
            value = (1.0 if value >= 0 else -1.0) * 0.45
        out.append(value * math.exp(-decay * t))
    return out


def noise(seconds: float, decay: float = 12.0, seed: int = 1, lowpass: float = 0.0) -> list[float]:
    rng = random.Random(seed)
    out = []
    previous = 0.0
    for i in range(int(RATE * seconds)):
        t = i / RATE
        raw = rng.random() * 2.0 - 1.0
        if lowpass > 0.0:
            previous = previous + lowpass * (raw - previous)
            raw = previous
        out.append(raw * math.exp(-decay * t))
    return out


def sfx() -> None:
    write(os.path.join(SFX_DIR, "ui_click.wav"), tone(760, 0.06, 46), 0.45)
    write(os.path.join(SFX_DIR, "ui_back.wav"), tone(420, 0.09, 28), 0.42)
    write(os.path.join(SFX_DIR, "build.wav"),
          mix(concat(tone(220, 0.07, 22), tone(330, 0.07, 22), tone(440, 0.12, 16)), noise(0.1, 40, 3)), 0.6)
    write(os.path.join(SFX_DIR, "upgrade.wav"),
          concat(tone(523, 0.08, 18), tone(659, 0.08, 18), tone(784, 0.08, 18), tone(1046, 0.18, 12)), 0.55)
    write(os.path.join(SFX_DIR, "sell.wav"), sweep(620, 240, 0.18, 12), 0.5)
    write(os.path.join(SFX_DIR, "arrow.wav"), mix(sweep(880, 420, 0.12, 18), noise(0.05, 60, 4, 0.6)), 0.5)
    write(os.path.join(SFX_DIR, "cannon.wav"), mix(sweep(180, 60, 0.3, 8), noise(0.22, 14, 6, 0.3)), 0.7)
    write(os.path.join(SFX_DIR, "flame.wav"), mix(noise(0.28, 9, 8, 0.15), tone(120, 0.2, 10)), 0.55)
    write(os.path.join(SFX_DIR, "ice.wav"), mix(tone(1320, 0.1, 22), tone(1760, 0.12, 24), noise(0.08, 30, 9)), 0.45)
    write(os.path.join(SFX_DIR, "zap.wav"), mix(sweep(1400, 300, 0.16, 16, "square"), noise(0.1, 24, 10)), 0.5)
    write(os.path.join(SFX_DIR, "splash.wav"), mix(noise(0.18, 16, 11, 0.5), tone(320, 0.14, 18)), 0.5)
    write(os.path.join(SFX_DIR, "mist.wav"), mix(noise(0.32, 7, 12, 0.08), tone(240, 0.2, 10)), 0.45)
    write(os.path.join(SFX_DIR, "magic.wav"), concat(tone(660, 0.07, 20), tone(880, 0.07, 20), tone(1320, 0.16, 14)), 0.5)
    write(os.path.join(SFX_DIR, "drum.wav"), mix(sweep(140, 60, 0.4, 7), noise(0.2, 12, 13, 0.25)), 0.7)
    write(os.path.join(SFX_DIR, "magnet.wav"), sweep(180, 640, 0.26, 7, "tri"), 0.45)
    write(os.path.join(SFX_DIR, "portal.wav"), sweep(300, 1100, 0.32, 6, "sine"), 0.45)
    write(os.path.join(SFX_DIR, "summon.wav"), concat(tone(330, 0.08, 20), tone(440, 0.08, 20), tone(550, 0.14, 14)), 0.5)
    write(os.path.join(SFX_DIR, "coin.wav"), concat(tone(1046, 0.05, 24), tone(1568, 0.1, 18)), 0.35)
    write(os.path.join(SFX_DIR, "enemy_die.wav"), mix(sweep(520, 140, 0.18, 12), noise(0.12, 22, 14)), 0.5)
    write(os.path.join(SFX_DIR, "leak.wav"), mix(sweep(300, 80, 0.42, 6), noise(0.3, 9, 15)), 0.65)
    write(os.path.join(SFX_DIR, "wave_start.wav"), concat(tone(392, 0.1, 12), tone(523, 0.1, 12), tone(659, 0.18, 8)), 0.5)
    write(os.path.join(SFX_DIR, "wave_clear.wav"), concat(tone(659, 0.08, 14), tone(784, 0.08, 14), tone(988, 0.16, 10)), 0.5)
    write(os.path.join(SFX_DIR, "boss.wav"), mix(sweep(140, 60, 0.9, 3), tone(70, 0.8, 3), noise(0.6, 4, 16, 0.2)), 0.7)
    write(os.path.join(SFX_DIR, "boss_die.wav"), mix(sweep(300, 40, 1.1, 2.5), noise(0.9, 4, 17, 0.2)), 0.8)
    write(os.path.join(SFX_DIR, "victory.wav"),
          concat(tone(523, 0.12, 8), tone(659, 0.12, 8), tone(784, 0.12, 8), tone(1046, 0.4, 4)), 0.65)
    write(os.path.join(SFX_DIR, "defeat.wav"),
          concat(tone(392, 0.16, 8), tone(311, 0.16, 8), tone(233, 0.5, 5)), 0.6)


CHORDS = [
    [196.00, 246.94, 293.66],
    [174.61, 220.00, 261.63],
    [146.83, 196.00, 246.94],
    [174.61, 220.00, 293.66],
]


def music(name: str, seconds: float, lead: bool, tempo: float, bass_gain: float) -> None:
    """A warm pad, a walking bass and (in battle) a music-box lead."""
    beat = tempo
    bars = int(seconds / (beat * 4))
    length = int(RATE * seconds)
    out = [0.0] * length
    for bar in range(bars):
        chord = CHORDS[bar % len(CHORDS)]
        start = bar * beat * 4
        for freq in chord:
            for i in range(int(RATE * beat * 4)):
                t = i / RATE
                attack = min(1.0, t / 0.3)
                release = min(1.0, (beat * 4 - t) / 0.5)
                phase = math.tau * freq * (start + t)
                value = math.sin(phase) * 0.1 + math.sin(phase * 2.0) * 0.025
                index = int(RATE * start) + i
                if 0 <= index < length:
                    out[index] += value * attack * release
        for step in range(8):
            t0 = start + step * beat * 0.5
            freq = chord[0] * (2.0 if step % 2 else 0.5)
            for i in range(int(RATE * beat * 0.5)):
                t = i / RATE
                env = math.exp(-9.0 * t)
                index = int(RATE * t0) + i
                if 0 <= index < length:
                    out[index] += math.sin(math.tau * freq * t) * env * bass_gain
        if lead:
            for step in range(8):
                t0 = start + step * beat * 0.5
                freq = chord[step % 3] * 4.0
                for i in range(int(RATE * beat * 0.42)):
                    t = i / RATE
                    env = math.exp(-16.0 * t)
                    index = int(RATE * t0) + i
                    if 0 <= index < length:
                        out[index] += math.sin(math.tau * freq * t) * env * 0.05
                        out[index] += math.sin(math.tau * freq * 2.0 * t) * env * 0.02
    write(os.path.join(MUSIC_DIR, name + ".wav"), out, 0.72)


if __name__ == "__main__":
    sfx()
    music("menu", 16.0, False, 0.6, 0.12)
    music("battle", 16.0, True, 0.5, 0.15)
    music("boss", 16.0, True, 0.42, 0.2)
    print("audio build complete")
