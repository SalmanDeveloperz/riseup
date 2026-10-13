#!/usr/bin/env python3
"""
RiseUp sleep sound generator (Phase 6).

WHAT:  Synthesizes 10 relaxing, SEAMLESSLY LOOPING sounds from noise and maths:
       rain, ocean, wind, fire, crickets, stream, fan, white / pink / brown noise.
WHY:   Generated audio has no licence problems, and anyone can tweak and regenerate it.
OUT:   Alarm/Resources/SleepSounds/sleep_*.caf (IMA4-compressed CAF, 22.05 kHz mono, 40 s).

RUN (from the project folder):
    python3 Tools/generate_sleep_sounds.py

LEARN: How a loop is made seamless
----------------------------------
A 40-second file that plays over and over would "click" at the seam if the end doesn't match
the start. We render a bit MORE than 40 s, then cross-fade the extra tail into the beginning:
the first second slowly turns from "the end of the sound" into "the start of the sound".
Played on repeat, the join is inaudible.

LEARN: Noise colours
--------------------
  white: every frequency equally loud (hiss)
  pink:  each octave equally loud (softer, like steady rain)
  brown: low frequencies much louder (deep rumble, like a distant waterfall)

TRY: change RAIN_DROPS_PER_SECOND below, re-run, rebuild, and listen in the Sleep tab.
Needs only the Python standard library + macOS's built-in `afconvert`.
"""
import math
import os
import random
import struct
import subprocess
import tempfile
import wave

RATE = 22050                 # samples per second (plenty for noise, half the file size of 44.1 kHz)
DURATION = 40.0              # seconds per loop
CROSSFADE = 1.5              # seconds blended at the seam
RAIN_DROPS_PER_SECOND = 14   # TRY: 30 for a downpour
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Alarm", "Resources", "SleepSounds")

N = int(RATE * DURATION)
N_FADE = int(RATE * CROSSFADE)
TOTAL = N + N_FADE


# ---------- noise building blocks (each returns a list of TOTAL floats) ----------

def white(rng):
    return [rng.uniform(-1, 1) for _ in range(TOTAL)]

def pink(rng):
    """Paul Kellet's well-known pink noise filter (cheap and good)."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(TOTAL):
        w = rng.uniform(-1, 1)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        out.append((b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11)
        b6 = w * 0.115926
    return out

def brown(rng):
    """Integrated white noise with a small leak so it never drifts away."""
    value, out = 0.0, []
    for _ in range(TOTAL):
        value = (value + rng.uniform(-1, 1) * 0.02) * 0.998
        out.append(value * 3.5)
    return out

def lowpass(samples, amount):
    """Simple one-pole low-pass filter. amount 0…1: smaller = darker."""
    value, out = 0.0, []
    for s in samples:
        value += amount * (s - value)
        out.append(value)
    return out

def loop_sine(cycles, i):
    """A slow wave that repeats exactly `cycles` times per loop, so it loops seamlessly."""
    return math.sin(2 * math.pi * cycles * i / N)

def add_events(samples, rng, per_second, make_event):
    """Adds short sounds (rain drops, fire pops, chirps) at random moments."""
    count = int(per_second * DURATION)
    for _ in range(count):
        start = rng.randrange(0, TOTAL - RATE)
        for offset, value in enumerate(make_event(rng)):
            samples[start + offset] += value
    return samples


# ---------- the sounds ----------

def rain(rng):
    base = pink(rng)
    def drop(r):
        length = int(RATE * r.uniform(0.01, 0.04))
        loud = r.uniform(0.05, 0.25)
        return [loud * r.uniform(-1, 1) * math.exp(-k / (length / 4)) for k in range(length)]
    return add_events([s * 0.9 for s in base], rng, RAIN_DROPS_PER_SECOND, drop)

def ocean(rng):
    base = brown(rng)
    hiss = lowpass(white(rng), 0.3)
    out = []
    for i in range(TOTAL):
        swell = 0.5 + 0.5 * loop_sine(4, i)             # 4 waves per 40 s = one every 10 s
        out.append(base[i] * (0.25 + 0.75 * swell) + hiss[i] * 0.25 * swell ** 3)
    return out

def wind(rng):
    base = lowpass(pink(rng), 0.15)
    return [base[i] * (0.55 + 0.25 * loop_sine(3, i) + 0.2 * loop_sine(7, i)) * 2.2 for i in range(TOTAL)]

def fire(rng):
    base = [s * 0.7 for s in brown(rng)]
    def crackle(r):
        length = int(RATE * r.uniform(0.003, 0.02))
        loud = r.uniform(0.15, 0.6)
        return [loud * r.uniform(-1, 1) * math.exp(-k / (length / 3)) for k in range(length)]
    return add_events(base, rng, 9, crackle)

def crickets(rng):
    base = [s * 0.25 for s in brown(rng)]
    def chirp(r):
        freq = r.uniform(4200, 4800)
        out = []
        for pulse in range(3):                           # cricket "chirr": 3 quick pulses
            for k in range(int(RATE * 0.025)):
                t = k / RATE
                out.append(0.12 * math.sin(2 * math.pi * freq * t) * math.sin(math.pi * k / (RATE * 0.025)))
            out.extend([0.0] * int(RATE * 0.02))
        return out
    return add_events(base, rng, 2.2, chirp)

def stream(rng):
    base = lowpass(white(rng), 0.45)
    bubbles = lowpass(white(rng), 0.02)
    return [base[i] * (0.6 + 2.5 * abs(bubbles[i])) * 0.8 for i in range(TOTAL)]

def fan(rng):
    base = lowpass(white(rng), 0.08)
    out = []
    for i in range(TOTAL):
        hum = 0.05 * math.sin(2 * math.pi * 120 * i / RATE)
        out.append(base[i] * 2.6 * (0.95 + 0.05 * loop_sine(20, i)) + hum)
    return out

SOUNDS = {
    "sleep_rain": rain,
    "sleep_ocean": ocean,
    "sleep_wind": wind,
    "sleep_fire": fire,
    "sleep_crickets": crickets,
    "sleep_stream": stream,
    "sleep_fan": fan,
    "sleep_white": lambda rng: [s * 0.35 for s in white(rng)],
    "sleep_pink": lambda rng: [s * 1.2 for s in pink(rng)],
    "sleep_brown": brown,
}


# ---------- loop, normalise, save ----------

def make_loop(samples):
    """Cross-fades the extra tail into the start (see LEARN above)."""
    out = samples[:N]
    for i in range(N_FADE):
        fade = i / N_FADE
        out[i] = samples[i] * fade + samples[N + i] * (1 - fade)
    return out

def normalise(samples, target_rms=0.15, max_peak=0.95):
    """Makes every sound about EQUALLY LOUD (same average energy, "RMS"), without clipping.

    WHY not just "loudest sample = 0.7": white noise was then 3x louder than ocean, which is a
    nasty surprise when you switch sounds in bed (we measured this after the first version).
    """
    rms = (sum(s * s for s in samples) / len(samples)) ** 0.5 or 1.0
    biggest = max(abs(s) for s in samples) or 1.0
    scale = min(target_rms / rms, max_peak / biggest)
    return [s * scale for s in samples]

def write_caf(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.abspath(os.path.join(OUT_DIR, name + ".caf"))
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name + ".wav")
        with wave.open(wav_path, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))
        subprocess.run(["afconvert", "-f", "caff", "-d", "ima4", wav_path, out], check=True)
    print(f"wrote {out}")

if __name__ == "__main__":
    for index, (name, make) in enumerate(SOUNDS.items()):
        rng = random.Random(1000 + index)        # fixed seed → the same file every run
        write_caf(name, normalise(make_loop(make(rng))))
