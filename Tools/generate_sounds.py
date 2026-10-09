#!/usr/bin/env python3
"""
RiseUp alarm sound generator.

WHAT:  Synthesizes every RiseUp alarm tone from pure maths (sine/square waves, envelopes).
WHY:   Sounds we generate ourselves have NO licence problems on the App Store, and anyone
       can tweak or regenerate them. No downloads, no third-party audio.
OUT:   Alarm/Resources/Sounds/riseup_*.caf  (IMA4-compressed CAF, the format iOS alarm
       sounds like: small files that AlarmKit and AVAudioPlayer both play).

RUN (from the project folder):
    python3 Tools/generate_sounds.py

TRY: change a frequency below (e.g. `radar` 1046 → 880), re-run, rebuild, and listen in
     the Sound Picker. Each sound is a small function: read one, then change it.

Needs only the Python standard library + macOS's built-in `afconvert` tool.
"""
import math
import os
import struct
import subprocess
import tempfile
import wave

RATE = 44100           # samples per second
DURATION = 12.0        # seconds per file (alarms loop it)
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Alarm", "Resources", "Sounds")


# ---------- building blocks ----------

def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)

def square(freq, t):
    return 1.0 if sine(freq, t) >= 0 else -1.0

def envelope(t, length, attack=0.005, release=0.02):
    """Quick fade in/out so tones don't click."""
    if t < attack:
        return t / attack
    if t > length - release:
        return max(0.0, (length - t) / release)
    return 1.0

def render(fn):
    """Calls fn(t) for every sample time and returns a list of floats in -1...1."""
    n = int(RATE * DURATION)
    return [max(-1.0, min(1.0, fn(i / RATE))) for i in range(n)]


# ---------- the sounds ----------

def digital(t):
    """Classic digital watch alarm: 4 fast beeps, pause, repeat."""
    cycle = t % 1.0
    for i in range(4):
        start = i * 0.12
        if start <= cycle < start + 0.08:
            local = cycle - start
            return 0.75 * square(2093, t) * 0.5 * envelope(local, 0.08)
    return 0.0

def radar(t):
    """Bright ping that repeats twice a second, like iOS's well-known style."""
    cycle = t % 0.5
    if cycle < 0.18:
        decay = math.exp(-cycle * 18)
        return 0.8 * decay * (sine(1046, t) + 0.35 * sine(2093, t)) / 1.35
    return 0.0

def bell(t):
    """Old-school bell: rich partials with a long decay, struck every 0.6 s."""
    cycle = t % 0.6
    decay = math.exp(-cycle * 6)
    partials = [(1.0, 880), (0.6, 1760), (0.4, 2637), (0.25, 3520)]
    value = sum(a * sine(f, t) for a, f in partials) / sum(a for a, _ in partials)
    return 0.85 * decay * value * envelope(cycle, 0.6, attack=0.002, release=0.01)

def siren(t):
    """Up-and-down siren sweep. Loud and hard to ignore."""
    # Frequency swings between 700 and 1200 Hz, 0.8 times per second:
    #     f(t) = 950 + 250·sin(2π·0.8·t)
    # To sweep smoothly we need the PHASE, which is the integral of the frequency:
    #     phase(t) = 2π·(950·t − 250/(2π·0.8)·cos(2π·0.8·t))
    sweep_rate = 0.8
    phase = 2 * math.pi * (950 * t - 250 / (2 * math.pi * sweep_rate) * math.cos(2 * math.pi * sweep_rate * t))
    return 0.7 * math.sin(phase)

def pulse(t):
    """Rapid urgent pulses that speed up each second."""
    cycle = t % 1.0
    rate = 6 + 6 * cycle          # 6 → 12 pulses per second
    on = (cycle * rate) % 1.0 < 0.5
    return 0.7 * square(1568, t) * 0.45 if on else 0.0

def arcade(t):
    """Retro game arpeggio (C-E-G-C) in square waves."""
    notes = [523, 659, 784, 1046, 784, 659]
    step = int(t / 0.11) % len(notes)
    local = t % 0.11
    return 0.55 * square(notes[step], t) * 0.5 * envelope(local, 0.11)

def sunrise(t):
    """Gentle rising chime arpeggio that slowly gets louder over the 12 seconds."""
    notes = [523, 659, 784, 988, 1175]
    step = int(t / 0.4) % len(notes)
    local = t % 0.4
    swell = 0.25 + 0.75 * (t / DURATION)          # quiet → full volume
    decay = math.exp(-local * 5)
    return 0.8 * swell * decay * (sine(notes[step], t) + 0.3 * sine(notes[step] * 2, t)) / 1.3

def marimba(t):
    """Soft wooden marimba melody."""
    melody = [659, 784, 880, 784, 659, 587, 523, 587]
    step = int(t / 0.3) % len(melody)
    local = t % 0.3
    decay = math.exp(-local * 12)
    f = melody[step]
    return 0.8 * decay * (sine(f, t) + 0.5 * sine(f * 4, t) * math.exp(-local * 40)) / 1.5


SOUNDS = {
    "riseup_digital": digital,
    "riseup_radar": radar,
    "riseup_bell": bell,
    "riseup_siren": siren,
    "riseup_pulse": pulse,
    "riseup_arcade": arcade,
    "riseup_sunrise": sunrise,
    "riseup_marimba": marimba,
}


def write_caf(name, samples):
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in samples))
        out = os.path.join(OUT_DIR, name + ".caf")
        # ima4 = Apple's compressed format for short sounds (~4x smaller than raw).
        subprocess.run(["afconvert", "-f", "caff", "-d", "ima4", wav_path, out], check=True)
        return out


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in SOUNDS.items():
        path = write_caf(name, render(fn))
        print(f"✓ {os.path.relpath(path)}  ({os.path.getsize(path) // 1024} KB)")
