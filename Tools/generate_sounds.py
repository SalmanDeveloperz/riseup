#!/usr/bin/env python3
"""
RiseUp alarm sound generator.

WHAT:  Synthesizes every RiseUp alarm tone from pure maths (sine/square waves, envelopes).
WHY:   Sounds we generate ourselves have NO licence problems on the App Store, and anyone
       can tweak or regenerate them. No downloads, no third-party audio.
OUT:   Alarm/Resources/Sounds/riseup_*.caf  (IMA4-compressed CAF, the format iOS alarm
       sounds like: small files that AlarmKit and AVAudioPlayer both play).

RUN (from the project folder):
    python3 Tools/generate_sounds.py                     # every sound
    python3 Tools/generate_sounds.py riseup_birds        # only the ones you name (faster)

TRY: change a frequency below (e.g. `radar` 1046 → 880), re-run, rebuild, and listen in
     the Sound Picker. Each sound is a small function: read one, then change it.

Needs only the Python standard library + macOS's built-in `afconvert` tool.
"""
import math
import os
import random
import struct
import subprocess
import sys
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


# =====================================================================================
# Richer sounds (added 2026-10-13). These build the whole 12 s at once in a list
# ("buffer") instead of one sample at a time, so they can use instruments with memory:
# plucked strings, bells that keep ringing, drums, filters.
# =====================================================================================

N = int(RATE * DURATION)

def new_buffer():
    return [0.0] * N

def mix(buf, start, samples, gain=1.0):
    """Adds `samples` into `buf` starting at `start` seconds.
    WHY `% N`: a note that rings past the end continues at the START, so when iOS loops the
    file there is no click or gap (a seamless loop)."""
    i0 = int(start * RATE)
    for k, value in enumerate(samples):
        buf[(i0 + k) % N] += gain * value

def normalize(buf, peak=0.95):
    """Scales so the loudest moment is `peak` (all sounds end up equally strong)."""
    top = max(abs(v) for v in buf) or 1.0
    return [v * peak / top for v in buf]

def lowpass(samples, cutoff):
    """One-pole low-pass filter: softens harsh highs (like turning down the treble)."""
    a = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out

def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]

def note(name):
    """'A4' → 440 Hz. Sharps like 'G#4'. Equal temperament: each semitone is ×2^(1/12)."""
    steps = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    letter, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((steps[letter] + 12 * (octave - 4)) / 12)

def fade_in(samples, seconds=0.003):
    n = max(1, int(seconds * RATE))
    return [v * min(1.0, k / n) for k, v in enumerate(samples)]

# ---------- instruments ----------

def bell_strike(freq, partials, length):
    """A struck bell: several sine "partials", each with its own loudness and decay speed.
    partials = [(frequency ratio, amplitude, decay per second), ...]"""
    n = int(length * RATE)
    out = [0.0] * n
    for ratio, amp, decay in partials:
        w = 2 * math.pi * freq * ratio / RATE
        fall = math.exp(-decay / RATE)
        level = amp
        for k in range(n):
            out[k] += level * math.sin(w * k)
            level *= fall
    return fade_in(out, 0.001)

def pluck(freq, length, damping=0.996, brightness=0.5, seed=1):
    """Karplus–Strong plucked string (harp, kalimba). A burst of noise circulates in a tiny
    delay line that is averaged every loop: it turns into a pure, decaying string tone."""
    rng = random.Random(seed)
    period = max(2, int(round(RATE / freq)))
    line = [rng.uniform(-1, 1) for _ in range(period)]
    for _ in range(int(brightness * 4)):             # pre-soften = a warmer pluck
        line = [(line[i] + line[i - 1]) / 2 for i in range(period)]
    n = int(length * RATE)
    out = [0.0] * n
    for k in range(n):
        i = k % period
        out[k] = line[i]
        line[i] = damping * 0.5 * (line[i] + line[(i + 1) % period])
    return fade_in(out, 0.002)

def epiano(freq, length, velocity=1.0):
    """Electric piano by FM synthesis: one sine wobbles another's phase (the "bell-ish" tine)."""
    n = int(length * RATE)
    out = []
    for k in range(n):
        t = k / RATE
        index = 1.6 * math.exp(-t * 5)               # bright attack, mellow tail
        body = math.sin(2 * math.pi * freq * t + index * math.sin(2 * math.pi * freq * t))
        tine = 0.12 * math.exp(-t * 18) * math.sin(2 * math.pi * freq * 7 * t)
        out.append(velocity * math.exp(-t * 1.8) * (body + tine))
    return fade_in(out)

def brass(freq, length, velocity=1.0):
    """Brass: a buzzy tone (many harmonics) that gets brighter as it swells, with vibrato."""
    n = int(length * RATE)
    out, phase = [], 0.0
    harmonics = [h for h in range(1, 13) if freq * h < 9000]
    for k in range(n):
        t = k / RATE
        attack = min(1.0, t / 0.04)
        release = min(1.0, max(0.0, (length - t) / 0.06))
        env = attack * release * (0.85 + 0.15 * math.exp(-t * 6))
        vibrato = 1 + (0.004 * math.sin(2 * math.pi * 5.5 * t) if t > 0.15 else 0)
        phase += 2 * math.pi * freq * vibrato / RATE
        bright = 0.35 + 0.65 * env
        value = sum((bright ** (h - 1)) / h * math.sin(h * phase) for h in harmonics)
        out.append(velocity * env * value)
    return out

def kick(length=0.4):
    out, phase = [], 0.0
    for k in range(int(length * RATE)):
        t = k / RATE
        phase += 2 * math.pi * (45 + 115 * math.exp(-t * 28)) / RATE   # pitch drops fast = "thump"
        out.append(math.exp(-t * 8) * math.sin(phase))
    return out

def snare(length=0.22, seed=2):
    rng = random.Random(seed)
    noise = highpass([rng.uniform(-1, 1) for _ in range(int(length * RATE))], 1200)
    return [n * math.exp(-k / RATE * 22) + 0.4 * math.exp(-k / RATE * 30) * math.sin(2 * math.pi * 190 * k / RATE)
            for k, n in enumerate(noise)]

def hat(length=0.05, seed=3):
    rng = random.Random(seed)
    noise = highpass(highpass([rng.uniform(-1, 1) for _ in range(int(length * RATE))], 6000), 6000)
    return [n * math.exp(-k / RATE * 70) for k, n in enumerate(noise)]

def chirp(f0, f1, length, trill=0.0, trill_rate=40.0):
    """A bird's tweet: a quick pitch slide with a round envelope (and optional warble)."""
    n = int(length * RATE)
    out, phase = [], 0.0
    for k in range(n):
        x = k / n
        f = f0 + (f1 - f0) * x + trill * math.sin(2 * math.pi * trill_rate * k / RATE)
        phase += 2 * math.pi * f / RATE
        out.append((math.sin(math.pi * x) ** 1.5) * math.sin(phase))
    return out

# Bell "recipes": (ratio, amplitude, decay/s). Inharmonic ratios = metal, not a string.
SMALL_BELL = [(1.0, 1.0, 9), (2.32, 0.55, 14), (4.25, 0.3, 22), (6.8, 0.15, 30)]
PHONE_BELL = [(1.0, 1.0, 7), (2.0, 0.35, 10), (2.76, 0.4, 13), (5.4, 0.2, 25)]
CHURCH_BELL = [(0.5, 0.35, 0.6), (1.0, 1.0, 0.9), (1.19, 0.45, 1.4), (1.5, 0.3, 1.6),
               (2.0, 0.6, 1.8), (2.5, 0.2, 2.5), (3.0, 0.15, 3.0)]
CHIME = [(1.0, 1.0, 1.2), (2.0, 0.3, 2.0), (3.0, 0.12, 3.0), (4.2, 0.08, 4.0)]

# ---------- the sounds ----------

def twin_bell():
    """Wind-up alarm clock: a little hammer rattling between TWO bells, 16 hits a second."""
    buf = new_buffer()
    bells = [bell_strike(2050, SMALL_BELL, 0.5), bell_strike(2330, SMALL_BELL, 0.5)]
    cycle = 2.0                                       # 1.6 s ringing + 0.4 s pause
    for c in range(int(DURATION / cycle)):
        for h in range(int(1.6 * 16)):
            mix(buf, c * cycle + h / 16, bells[h % 2], 0.6)
    return normalize(buf)

def old_phone():
    """Classic telephone: "brrring-brrring … brrring-brrring" (two bells, 20 hits a second)."""
    buf = new_buffer()
    bells = [bell_strike(1180, PHONE_BELL, 0.35), bell_strike(1400, PHONE_BELL, 0.35)]
    for c in range(6):                                # 2-second pattern, 6 times
        for burst in (0.0, 0.6):
            for h in range(int(0.4 * 20)):
                mix(buf, c * 2.0 + burst + h / 20, bells[h % 2], 0.6)
    return normalize(buf)

def westminster():
    """Westminster Quarters (Big Ben's tune, 1793, public domain) on deep church bells."""
    buf = new_buffer()
    phrases = [["E4", "G#4", "F#4", "B3"], ["E4", "F#4", "G#4", "E4"],
               ["G#4", "E4", "F#4", "B3"], ["B3", "F#4", "G#4", "E4"]]
    t = 0.0
    for phrase in phrases:                            # 4 phrases × 3 s = 12 s
        for i, name in enumerate(phrase):
            length = 1.2 if i == 3 else 0.6           # the last note of a phrase is held
            mix(buf, t, bell_strike(note(name) * 2, CHURCH_BELL, 3.0), 0.5)
            t += length
    return normalize(lowpass(buf, 5000))

def electro():
    """Upbeat dance loop at 120 BPM: kick, claps, hats, bass and a rising synth arpeggio."""
    buf = new_buffer()
    beat = 0.5
    chords = [["A2", "A4", "C5", "E5"], ["F2", "F4", "A4", "C5"],
              ["C3", "G4", "C5", "E5"], ["G2", "G4", "B4", "D5"]]
    k, s, h = kick(), snare(), hat()
    for b in range(24):                               # 6 bars of 4 beats
        t = b * beat
        mix(buf, t, k, 0.9)
        if b % 2 == 1:
            mix(buf, t, s, 0.45)
        mix(buf, t + beat / 2, h, 0.25)
        root, *tones = chords[(b // 4) % 4]
        # Off-beat bass (the classic "pumping" dance bass).
        mix(buf, t + beat / 2, brass(note(root), 0.22, 0.5), 0.5)
        if b >= 8:                                    # bars 3–6: the melody joins in
            for i in range(4):
                tone = tones[(b * 4 + i) % len(tones)]
                mix(buf, t + i * beat / 4, pluck(note(tone), 0.18, 0.993, 0.2, seed=b * 4 + i), 0.35)
    return normalize(buf)

def fanfare():
    """Bright brass fanfare, "rise and shine!", in two-voice harmony."""
    buf = new_buffer()
    melody = [("G4", 0.18), ("G4", 0.18), ("C5", 0.36), ("E5", 0.18), ("E5", 0.18), ("C5", 0.36),
              ("G4", 0.18), ("C5", 0.18), ("E5", 0.18), ("G5", 0.9), ("E5", 0.25), ("G5", 1.0)]
    for rep in range(3):                              # 3 × 4 s
        t = rep * 4.0
        for name, length in melody:
            f = note(name)
            mix(buf, t, brass(f, length * 0.95), 0.55)
            mix(buf, t, brass(f * 0.8, length * 0.95), 0.3)     # a major third below
            t += length
    return normalize(lowpass(buf, 6000))

def school_bell():
    """Electric school / fire bell: a fast hammer on one big bell, 3 s on, 1 s off."""
    buf = new_buffer()
    strike = bell_strike(1550, PHONE_BELL, 0.3)
    for c in range(3):
        for h in range(int(3.0 * 25)):
            mix(buf, c * 4.0 + h / 25, strike, 0.6)
    return normalize(buf)

def birds():
    """Morning birdsong: a few different "birds" singing over a soft breeze."""
    rng = random.Random(7)
    buf = new_buffer()
    # Soft breeze underneath.
    breeze = lowpass([rng.uniform(-1, 1) for _ in range(N)], 500)
    for k in range(N):
        buf[k] += 0.25 * breeze[k] * (0.6 + 0.4 * math.sin(2 * math.pi * k / N))
    t = 0.2
    while t < DURATION - 0.5:
        kind = rng.choice(["robin", "robin", "sparrow", "whistle"])
        gain = rng.uniform(0.4, 1.0)                  # some birds are further away
        if kind == "robin":                           # a phrase of varied clear notes
            for _ in range(rng.randint(4, 7)):
                f0 = rng.uniform(2600, 4200)
                length = rng.uniform(0.07, 0.14)
                mix(buf, t, chirp(f0, f0 * rng.uniform(0.8, 1.25), length, trill=rng.choice([0, 120])), gain)
                t += length + rng.uniform(0.03, 0.08)
        elif kind == "sparrow":                       # a quick repeated trill
            for _ in range(rng.randint(8, 14)):
                mix(buf, t, chirp(5200, 3800, 0.03), gain * 0.7)
                t += 1 / 14
        else:                                         # a slow two-part whistle
            mix(buf, t, chirp(1900, 2700, 0.35), gain)
            mix(buf, t + 0.4, chirp(2700, 2300, 0.3), gain)
            t += 0.75
        t += rng.uniform(0.3, 1.1)
    return normalize(buf, 0.9)

def harp():
    """Harp glissandos rising through warm chords, getting louder (gentle start)."""
    buf = new_buffer()
    chords = [["C3", "E3", "G3", "B3", "D4", "E4", "G4", "B4", "C5", "D5", "E5", "G5"],
              ["A2", "C3", "E3", "G3", "B3", "C4", "E4", "G4", "A4", "B4", "C5", "E5"],
              ["F2", "A2", "C3", "E3", "G3", "A3", "C4", "E4", "F4", "G4", "A4", "C5"],
              ["G2", "B2", "D3", "F3", "A3", "B3", "D4", "F4", "G4", "A4", "B4", "D5"]]
    for c, chord in enumerate(chords):               # 4 chords × 3 s
        for i, name in enumerate(chord):
            mix(buf, c * 3.0 + i * 0.085, pluck(note(name), 2.8, 0.9975, 0.6, seed=c * 20 + i), 0.5)
    swell = [0.45 + 0.55 * k / N for k in range(N)]
    return normalize([v * s for v, s in zip(buf, swell)])

def kalimba():
    """Thumb piano: soft wooden "plinks" playing a happy pentatonic tune."""
    buf = new_buffer()
    tune = ["C5", "E5", "G5", "E5", "A5", "G5", "E5", "D5",
            "C5", "D5", "E5", "G5", "E5", "D5", "C5", "G4"]
    step = 0.375                                      # 16 notes × 0.375 s = 6 s, played twice
    for rep in range(2):
        for i, name in enumerate(tune):
            f = note(name)
            n = int(1.4 * RATE)
            tone = [math.exp(-k / RATE * 3.2) * math.sin(2 * math.pi * f * k / RATE)
                    + 0.25 * math.exp(-k / RATE * 25) * math.sin(2 * math.pi * f * 5.9 * k / RATE)
                    for k in range(n)]
            mix(buf, rep * 6.0 + i * step, fade_in(tone), 0.5)
            if i % 4 == 0:                            # a low note under every 4th
                mix(buf, rep * 6.0 + i * step, pluck(f / 4, 1.2, 0.997, 0.8, seed=i), 0.35)
    swell = [0.55 + 0.45 * k / N for k in range(N)]
    return normalize([v * s for v, s in zip(buf, swell)])

def lofi():
    """Lo-fi morning: mellow electric-piano chords, a lazy beat and vinyl crackle."""
    rng = random.Random(11)
    buf = new_buffer()
    beat = 0.75                                       # 80 BPM: 4 bars of 3 s
    chords = [["C3", "E4", "G4", "B4"], ["A2", "C4", "E4", "G4"],
              ["D3", "F4", "A4", "C5"], ["G2", "B3", "D4", "F4"]]
    k, s, h = kick(), snare(), hat()
    for bar, chord in enumerate(chords):
        t0 = bar * 3.0
        for i, name in enumerate(chord):              # a soft, slightly rolled chord
            mix(buf, t0 + i * 0.03, epiano(note(name), 2.9, 0.8 if i else 1.0), 0.35)
        mix(buf, t0 + 2.25, epiano(note(chord[-1]) * 2, 0.7, 0.6), 0.2)   # a little answer
        for b, hit in [(0, k), (1.5, k), (1, s), (3, s)]:
            mix(buf, t0 + b * beat, hit, 0.55 if hit is k else 0.3)
        for e in range(8):                            # swung hi-hats
            mix(buf, t0 + e * beat / 2 + (0.06 if e % 2 else 0), h, 0.12)
    buf = lowpass(buf, 3500)                          # the warm, "old tape" sound
    for _ in range(140):                              # vinyl crackle
        buf[rng.randrange(N)] += rng.uniform(-0.25, 0.25)
    return normalize(buf, 0.9)

def ocean():
    """Waves rolling in at sunrise, with chimes that slowly grow louder."""
    rng = random.Random(5)
    noise = [rng.uniform(-1, 1) for _ in range(N)]
    soft = lowpass(lowpass(noise, 700), 900)
    buf = new_buffer()
    for k in range(N):
        wave_shape = (0.5 - 0.5 * math.cos(2 * math.pi * 2 * k / N)) ** 1.6   # 2 waves per loop
        buf[k] = soft[k] * (0.25 + 0.75 * wave_shape)
    pentatonic = ["C5", "D5", "E5", "G5", "A5", "C6"]
    t = 0.4
    while t < DURATION - 0.3:
        loudness = 0.25 + 0.75 * t / DURATION
        mix(buf, t, bell_strike(note(rng.choice(pentatonic)), CHIME, 2.5), 0.22 * loudness)
        t += rng.choice([0.5, 0.75, 1.0])
    return normalize(buf, 0.9)


BUILT_SOUNDS = {
    "riseup_twinbell": twin_bell,
    "riseup_oldphone": old_phone,
    "riseup_westminster": westminster,
    "riseup_electro": electro,
    "riseup_fanfare": fanfare,
    "riseup_schoolbell": school_bell,
    "riseup_birds": birds,
    "riseup_harp": harp,
    "riseup_kalimba": kalimba,
    "riseup_lofi": lofi,
    "riseup_ocean": ocean,
}


# =====================================================================================
# Sounds of the world, nature and music (added 2026-10-13, round 2).
# Each one pairs with a live wallpaper (LiveWallpaper.signatureSound in the app).
# Melodies are ORIGINAL, written in each tradition's typical scale, not copies of songs.
# =====================================================================================

def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) for _ in range(n)]

def env_adsr(n, attack, release, total):
    """Linear attack, flat, linear release (in seconds) for n samples."""
    out = []
    for k in range(n):
        t = k / RATE
        a = min(1.0, t / attack) if attack > 0 else 1.0
        r = min(1.0, max(0.0, (total - t) / release)) if release > 0 else 1.0
        out.append(a * r)
    return out

def harmonic_tone(freq, length, harmonics, attack=0.02, release=0.08, vibrato=0.0, vib_rate=5.5, detune=0.0):
    """A tone built from harmonics [(number, amplitude)]: the basis of reeds, flutes, strings."""
    n = int(length * RATE)
    env = env_adsr(n, attack, release, length)
    out, phase = [], 0.0
    usable = [(h, a) for h, a in harmonics if freq * h < RATE / 2.2]
    for k in range(n):
        t = k / RATE
        f = freq * (1 + detune) * (1 + (vibrato * math.sin(2 * math.pi * vib_rate * t) if t > 0.15 else 0))
        phase += 2 * math.pi * f / RATE
        out.append(env[k] * sum(a * math.sin(h * phase) for h, a in usable))
    return out

def membrane(f_start, f_end, decay, length, noise_amount=0.0, seed=1):
    """A drum skin: a quick pitch slide that fades (djembe, tabla, timpani, frame drum)."""
    n = int(length * RATE)
    rng = random.Random(seed)
    out, phase = [], 0.0
    for k in range(n):
        t = k / RATE
        f = f_end + (f_start - f_end) * math.exp(-t * 30)
        phase += 2 * math.pi * f / RATE
        level = math.exp(-t * decay)
        out.append(level * (math.sin(phase) + noise_amount * rng.uniform(-1, 1) * math.exp(-t * 60)))
    return out

def flute(freq, length, breath=0.08, seed=1):
    """Pan flute: an almost pure tone with a breathy noise layer and gentle vibrato."""
    tone = harmonic_tone(freq, length, [(1, 1.0), (2, 0.18), (3, 0.06)], attack=0.06, release=0.15, vibrato=0.006)
    air = lowpass(highpass(noise(len(tone), seed), freq * 0.8), freq * 2.5)
    shape = env_adsr(len(tone), 0.03, 0.15, length)
    return [t + breath * 3 * a * s for t, a, s in zip(tone, air, shape)]

def piano(freq, length, velocity=1.0):
    """Acoustic piano: slightly stretched harmonics (real strings are a bit stiff) that fade at different speeds."""
    n = int(length * RATE)
    out = [0.0] * n
    for h in range(1, 9):
        ratio = h * math.sqrt(1 + 0.0004 * h * h)
        f = freq * ratio
        if f > RATE / 2.2:
            break
        amp = velocity / (h ** 1.3)
        decay = 1.2 + 0.9 * h
        w = 2 * math.pi * f / RATE
        level = amp
        fall = math.exp(-decay / RATE)
        for k in range(n):
            out[k] += level * math.sin(w * k)
            level *= fall
    return fade_in(out, 0.002)

STEEL_PAN = [(1.0, 1.0, 2.4), (2.0, 0.55, 3.5), (3.0, 0.25, 5.0), (4.0, 0.12, 7.0)]
BOWL = [(1.0, 1.0, 0.35), (2.71, 0.5, 0.55), (5.15, 0.25, 0.9), (8.17, 0.1, 1.4)]
COWBELL = [(1.0, 1.0, 5), (1.48, 0.6, 7), (2.66, 0.35, 10)]

def koto():
    """Japan · koto: bright plucked silk strings in the 'In' scale (D Eb G A Bb)."""
    buf = new_buffer()
    melody = [("D5", 1), ("A4", 1), ("A#4", 1), ("A4", 1), ("G4", 2), ("D#4", 1), ("D4", 3),
              ("G4", 1), ("A4", 1), ("A#4", 1), ("D5", 1), ("D#5", 2), ("D5", 1), ("A#4", 1), ("A4", 4)]
    step, t = 0.32, 0.0
    for i, (name, beats) in enumerate(melody):
        mix(buf, t, pluck(note(name), 2.2, 0.9965, 0.15, seed=i), 0.55)
        if beats >= 3:                                    # a soft octave answer on long notes
            mix(buf, t + step, pluck(note(name) / 2, 2.0, 0.997, 0.4, seed=i + 50), 0.3)
        t += beats * step
    for b in range(0, 12, 3):                             # low drone every 3 s
        mix(buf, b, pluck(note("D3"), 2.8, 0.998, 0.6, seed=99 + b), 0.35)
    return normalize(buf)

def sitar():
    """India · sitar at sunrise: a tanpura drone, a morning-raga melody (Bhairav scale) and tabla."""
    buf = new_buffer()
    for c in range(5):                                    # tanpura: Pa, Sa, Sa, low Sa, repeating
        for j, name in enumerate(["G3", "C4", "C4", "C3"]):
            mix(buf, c * 2.4 + j * 0.6, pluck(note(name), 2.6, 0.9993, 0.7, seed=c * 4 + j), 0.28)
    phrase = [("C5", 2), ("B4", 1), ("C5", 1), ("C#5", 2), ("C5", 2), ("G4", 3), ("G#4", 1), ("G4", 2),
              ("F4", 1), ("E4", 1), ("C#4", 2), ("C4", 4)]
    t = 0.3
    for i, (name, beats) in enumerate(phrase):
        f = note(name)
        tone = pluck(f, 1.6, 0.9975, 0.1, seed=200 + i)
        # "Jawari" buzz: a little soft clipping gives the sitar its bright, buzzing edge.
        mix(buf, t, [math.tanh(2.2 * v) for v in tone], 0.42)
        t += beats * 0.3
    na = membrane(520, 480, 9, 0.35, 0.3, seed=7)
    ge = membrane(70, 110, 6, 0.5, 0.1, seed=8)
    for b in range(40):                                    # tabla: dha dhin dhin dha / dha tin tin ta
        bt = b * 0.3
        if b % 4 == 0:
            mix(buf, bt, ge, 0.5)
        mix(buf, bt, na, 0.22 if b % 4 else 0.3)
    return normalize(buf)

def desert_oud():
    """Sahara · oud: a plucked lute in the Hijaz scale, desert wind and a frame drum."""
    buf = new_buffer()
    wind = lowpass(lowpass(noise(N, 31), 400), 600)
    for k in range(N):
        buf[k] += 0.35 * wind[k] * (0.6 + 0.4 * math.sin(2 * math.pi * k / N * 2))
    phrase = ["D4", "D#4", "F#4", "G4", "A4", "G4", "F#4", "D#4", "D4", "D4",
              "A3", "A#3", "C4", "D4", "D#4", "F#4", "D#4", "D4"]
    rhythm = [0.25, 0.25, 0.25, 0.25, 0.5, 0.25, 0.25, 0.25, 0.75, 0.5,
              0.25, 0.25, 0.25, 0.25, 0.5, 0.5, 0.5, 1.0]
    t, rep = 0.2, 0
    while t < DURATION - 0.5:
        for i, (name, dur) in enumerate(zip(phrase, rhythm)):
            if t >= DURATION - 0.3:
                break
            mix(buf, t, pluck(note(name), 1.5, 0.9955, 0.35, seed=rep * 40 + i), 0.5)
            if dur >= 0.75:                                # tremolo picking on long notes
                for r in range(1, 4):
                    mix(buf, t + r * dur / 4, pluck(note(name), 0.6, 0.995, 0.35, seed=rep * 40 + i + 100 * r), 0.25)
            t += dur
        rep += 1
    doum = membrane(95, 70, 7, 0.6, 0.2, seed=3)
    tek = [v * math.exp(-k / RATE * 50) for k, v in enumerate(highpass(noise(int(0.08 * RATE), 4), 2500))]
    for bar in range(6):                                   # maqsum: DUM tek tek DUM tek
        for pos, hit in [(0, doum), (0.5, tek), (0.75, tek), (1.25, doum), (1.5, tek)]:
            mix(buf, bar * 2 + pos, hit, 0.55 if hit is doum else 0.3)
    return normalize(buf)

def savanna_drums():
    """Africa · savanna: djembe drums in a rolling 12/8 groove, kalimba and shaker."""
    buf = new_buffer()
    bass = membrane(90, 60, 7, 0.5, 0.1, seed=11)
    tone = membrane(260, 220, 14, 0.3, 0.3, seed=12)
    slap = [v * math.exp(-k / RATE * 35) for k, v in enumerate(highpass(noise(int(0.15 * RATE), 13), 1500))]
    pulse = 2.0 / 12                                       # 12 pulses per 2-second bar
    pattern = "B.TTS.B.TTS."                               # B bass, T tone, S slap
    for bar in range(6):
        for i, c in enumerate(pattern):
            t = bar * 2 + i * pulse
            if c == "B": mix(buf, t, bass, 0.7)
            if c == "T": mix(buf, t, tone, 0.45)
            if c == "S": mix(buf, t, slap, 0.4)
        for i in range(12):                                # shaker on every pulse
            mix(buf, bar * 2 + i * pulse, hat(0.06, seed=bar * 12 + i), 0.12 if i % 3 else 0.2)
    tune = ["C5", "E5", "G5", "E5", "A5", "G5", "E5", "D5", "C5", "D5", "E5", "G5"]
    for i, name in enumerate(tune * 2):
        t = 0.5 + i * (2.0 / 4)
        if t < DURATION - 0.2:
            mix(buf, t, pluck(note(name), 1.2, 0.996, 0.7, seed=300 + i), 0.3)
    return normalize(buf)

def steel_drum():
    """Caribbean · steel drum: a sunny calypso melody with bass and shaker."""
    buf = new_buffer()
    melody = ["G4", "C5", "E5", "G5", "E5", "C5", "D5", "E5", "F5", "E5", "D5", "C5", "D5", "G4", "B4", "D5"]
    rhythm = [0.25, 0.25, 0.25, 0.5, 0.25, 0.25, 0.25, 0.75, 0.25, 0.25, 0.25, 0.5, 0.25, 0.25, 0.25, 0.75]
    t = 0.0
    while t < DURATION - 0.3:
        for name, dur in zip(melody, rhythm):
            if t >= DURATION - 0.3:
                break
            pan = bell_strike(note(name), STEEL_PAN, 1.2)
            mix(buf, t, pan, 0.5)
            mix(buf, t, bell_strike(note(name) * 2, STEEL_PAN, 0.6), 0.12)   # shimmer
            t += dur
    for beat in range(24):
        root = ["C2", "G2", "A2", "F2"][(beat // 6) % 4]
        if beat % 2 == 0:
            mix(buf, beat * 0.5, pluck(note(root), 0.5, 0.993, 0.8, seed=beat), 0.5)
        mix(buf, beat * 0.5 + 0.25, hat(0.05, seed=beat + 70), 0.15)
    return normalize(buf)

def singing_bowls():
    """Himalaya · singing bowls: deep metal bowls that hum and slowly 'beat' (wobble)."""
    buf = new_buffer()
    strikes = [(0.0, "C4"), (2.8, "G4"), (5.6, "D5"), (8.4, "A4"), (10.6, "C4")]
    for t, name in strikes:
        f = note(name)
        mix(buf, t, bell_strike(f, BOWL, 6.0), 0.5)
        mix(buf, t, bell_strike(f + 1.6, BOWL, 6.0), 0.35)   # a twin 1.6 Hz apart → the slow wobble
    air = lowpass(lowpass(noise(N, 41), 300), 500)
    return normalize([v + 0.08 * a for v, a in zip(buf, air)])

def accordion():
    """Paris · accordion: a café waltz (oom-pah-pah) with the classic wavy 'musette' sound."""
    buf = new_buffer()
    reed = [(1, 1.0), (2, 0.5), (3, 0.33), (4, 0.25), (5, 0.2), (6, 0.12), (7, 0.08)]
    beat = 1.0 / 3
    melody = [("A4", 2), ("C5", 1), ("B4", 1), ("A4", 1), ("G#4", 1), ("A4", 3), ("E5", 1), ("D5", 1), ("C5", 1),
              ("D5", 1), ("C5", 1), ("B4", 1), ("C5", 3), ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 1), ("C5", 1),
              ("B4", 1), ("C5", 1), ("D5", 1), ("E5", 3), ("D5", 1), ("C5", 1), ("B4", 1), ("A4", 3)]
    t = 0.0
    for name, beats in melody:
        length = beats * beat * 0.95
        for detune in (-0.0035, 0.0, 0.0035):             # three reeds a little apart = "musette"
            mix(buf, t, harmonic_tone(note(name), length, reed, attack=0.03, release=0.05, detune=detune), 0.12)
        t += beats * beat
    chords = [("A2", ["A3", "C4", "E4"]), ("E2", ["G#3", "B3", "E4"]), ("A2", ["A3", "C4", "E4"]), ("C3", ["C4", "E4", "G4"])]
    for bar in range(12):
        root, triad = chords[bar % 4]
        mix(buf, bar * 1.0, harmonic_tone(note(root), 0.3, reed[:4], attack=0.01, release=0.05), 0.25)
        for b in (1, 2):
            for n_ in triad:
                mix(buf, bar * 1.0 + b * beat, harmonic_tone(note(n_), 0.18, reed[:4], attack=0.01, release=0.04), 0.07)
    return normalize(lowpass(buf, 5000))

def alpine_horn():
    """Swiss Alps · alphorn: long warm horn calls echoing off the mountains, and cowbells."""
    buf = new_buffer()
    horn = [(1, 1.0), (2, 0.45), (3, 0.2), (4, 0.1)]
    calls = [(0.2, 262, 1.4), (1.7, 349, 1.0), (2.8, 392, 0.7), (3.6, 524, 2.2),
             (6.2, 437, 1.2), (7.5, 392, 1.0), (8.6, 349, 0.8), (9.5, 262, 2.0)]
    for start, f, length in calls:
        tone = harmonic_tone(f, length, horn, attack=0.12, release=0.4, vibrato=0.004, vib_rate=4.5)
        for echo, gain in [(0.0, 0.5), (0.45, 0.22), (0.9, 0.1)]:   # the mountain echo
            mix(buf, start + echo, tone, gain)
    rng = random.Random(51)
    t = 0.3
    while t < DURATION:
        mix(buf, t, bell_strike(rng.choice([820, 880, 1040]), COWBELL, 0.8), 0.12)
        t += rng.uniform(0.6, 1.6)
    return normalize(lowpass(buf, 4500))

def highland_pipes():
    """Scotland · bagpipes: two steady drones under a bright chanter tune, with grace notes. Loud!"""
    buf = new_buffer()
    drone = [(1, 1.0), (2, 0.7), (3, 0.5), (4, 0.35), (5, 0.25), (6, 0.18)]
    for f, gain in [(note("A2"), 0.16), (note("A3"), 0.12)]:
        mix(buf, 0, harmonic_tone(f, DURATION, drone, attack=0.3, release=0.2), gain)
    chanter = [(1, 1.0), (2, 0.6), (3, 0.55), (4, 0.3), (5, 0.25), (6, 0.15), (7, 0.1)]
    tune = [("A4", 0.5), ("C#5", 0.25), ("E5", 0.25), ("A5", 0.75), ("F#5", 0.25), ("E5", 0.5), ("C#5", 0.5),
            ("D5", 0.5), ("B4", 0.5), ("A4", 1.0), ("E5", 0.5), ("F#5", 0.25), ("G5", 0.25), ("A5", 0.5),
            ("E5", 0.5), ("C#5", 0.5), ("B4", 0.5), ("A4", 1.5)]
    t = 0.2
    while t < DURATION - 0.3:
        for name, dur in tune:
            if t >= DURATION - 0.3:
                break
            mix(buf, t, harmonic_tone(note("G5"), 0.035, chanter, attack=0.004, release=0.01), 0.18)   # grace note
            mix(buf, t + 0.035, harmonic_tone(note(name), dur - 0.035, chanter, attack=0.01, release=0.03), 0.3)
            t += dur
    return normalize(lowpass(buf, 6000))

def pan_flute():
    """Andes · pan flute: a breathy pentatonic melody, quick charango strums and a bombo drum."""
    buf = new_buffer()
    melody = [("E5", 0.5), ("G5", 0.5), ("A5", 1.0), ("B5", 0.5), ("A5", 0.5), ("G5", 1.0), ("E5", 0.5),
              ("D5", 0.5), ("E5", 2.0), ("B4", 0.5), ("D5", 0.5), ("E5", 1.0), ("G5", 0.5), ("E5", 0.5), ("D5", 1.0), ("E5", 2.0)]
    t = 0.0
    for i, (name, dur) in enumerate(melody):
        if t < DURATION - 0.2:
            mix(buf, t, flute(note(name), dur * 0.95, seed=i), 0.45)
        t += dur * 0.85
    chords = [["E4", "G4", "B4", "E5"], ["D4", "F#4", "A4", "D5"], ["C4", "E4", "G4", "C5"], ["D4", "F#4", "A4", "D5"]]
    for beat in range(24):
        chord = chords[(beat // 6) % 4]
        for j, name in enumerate(chord):                   # a fast strum: strings 15 ms apart
            mix(buf, beat * 0.5 + j * 0.015, pluck(note(name), 0.4, 0.993, 0.3, seed=beat * 4 + j), 0.12)
        if beat % 2 == 0:
            mix(buf, beat * 0.5, membrane(80, 55, 6, 0.5, 0.15, seed=beat), 0.4)
    return normalize(buf)

def rainforest():
    """Rainforest: tropical bird calls, frogs, insects and dripping leaves after rain."""
    rng = random.Random(61)
    buf = new_buffer()
    rain = highpass(lowpass(noise(N, 62), 4000), 800)
    insects = highpass(noise(N, 63), 5000)
    for k in range(N):
        t = k / RATE
        buf[k] += 0.06 * rain[k] + 0.05 * insects[k] * (0.5 + 0.5 * math.sin(2 * math.pi * 7 * t))
    t = 0.2
    while t < DURATION - 0.5:                               # tropical birds: whistles and fast trills
        if rng.random() < 0.5:
            for _ in range(rng.randint(3, 6)):
                f = rng.uniform(1800, 3200)
                mix(buf, t, chirp(f, f * rng.uniform(1.2, 1.6), 0.09), 0.5)
                t += 0.12
        else:
            mix(buf, t, chirp(2400, 1600, 0.5, trill=300, trill_rate=25), 0.45)
            t += 0.6
        t += rng.uniform(0.3, 0.9)
    for i in range(16):                                     # frogs: low "rib-bit" croaks
        start = rng.uniform(0, DURATION - 0.4)
        n = int(0.22 * RATE)
        croak = [math.sin(2 * math.pi * 320 * k / RATE) * (0.5 + 0.5 * math.sin(2 * math.pi * 30 * k / RATE)) * math.sin(math.pi * k / n)
                 for k in range(n)]
        mix(buf, start, croak, 0.25)
    for i in range(20):                                     # drips: a short falling "plop"
        mix(buf, rng.uniform(0, DURATION), [math.exp(-k / RATE * 40) * math.sin(2 * math.pi * (1400 - 6000 * k / RATE) * k / RATE)
                                             for k in range(int(0.08 * RATE))], 0.2)
    return normalize(buf, 0.9)

def seashore():
    """Seashore: waves breaking on the beach and seagulls calling overhead."""
    rng = random.Random(71)
    soft = lowpass(lowpass(noise(N, 72), 1200), 1500)
    hiss = highpass(noise(N, 73), 3000)
    buf = new_buffer()
    for k in range(N):
        x = k / N
        surge = (0.5 - 0.5 * math.cos(2 * math.pi * 3 * x)) ** 2      # 3 waves per loop
        buf[k] = soft[k] * (0.2 + 0.8 * surge) + 0.15 * hiss[k] * surge
    for start in [0.8, 3.1, 5.0, 8.2, 10.0]:                 # gulls: a harsh falling "kee-ow"
        n = int(0.45 * RATE)
        call, phase = [], 0.0
        for k in range(n):
            x = k / n
            f = 1700 - 700 * x + 120 * math.sin(2 * math.pi * 18 * k / RATE)
            phase += 2 * math.pi * f / RATE
            call.append(math.sin(math.pi * x) * (math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.25 * math.sin(3 * phase)))
        mix(buf, start, call, rng.uniform(0.25, 0.4))
    return normalize(buf, 0.9)

def thunderstorm():
    """Thunderstorm: heavy rain and rolling thunder. Hard to sleep through!"""
    rain = highpass(lowpass(noise(N, 81), 6000), 500)
    buf = [0.35 * v for v in rain]
    for start, power in [(0.6, 1.0), (5.2, 0.8), (8.9, 1.0)]:
        n = int(3.5 * RATE)
        rumble = lowpass(lowpass(noise(n, int(start * 10)), 120), 160)
        crack = highpass(noise(int(0.25 * RATE), int(start * 10) + 1), 1200)
        shaped = [v * 6 * power * min(1, k / (0.05 * RATE)) * math.exp(-k / RATE * 1.1) for k, v in enumerate(rumble)]
        mix(buf, start, shaped, 1.0)
        mix(buf, start, [v * math.exp(-k / RATE * 18) for k, v in enumerate(crack)], 0.8 * power)
    return normalize(buf)

def jazz_piano():
    """Music · jazz piano: swinging chords, a walking bass and soft brushes."""
    buf = new_buffer()
    chords = [["D3", "F4", "A4", "C5", "E5"], ["G2", "F4", "B4", "E5"], ["C3", "E4", "G4", "B4", "D5"], ["A2", "C#4", "G4", "A#4"]]
    walks = [["D3", "E3", "F3", "F#3"], ["G2", "A2", "B2", "C#3"], ["C3", "B2", "A2", "G2"], ["A2", "C#3", "E3", "D#3"]]
    beat, swing = 0.5, 0.33
    for bar in range(6):
        idx = bar % 4
        t0 = bar * 2.0
        chord = chords[idx]
        for hit, vel in [(0.0, 0.8), (1.5 + swing * beat, 0.6)]:     # "Charleston" comping
            for n_ in chord[1:]:
                mix(buf, t0 + hit, piano(note(n_), 1.4, vel), 0.16)
        for b, n_ in enumerate(walks[idx]):
            mix(buf, t0 + b * beat, pluck(note(n_), 0.6, 0.995, 0.8, seed=bar * 4 + b), 0.5)
        for b in range(4):                                  # brushes: swish on every beat
            mix(buf, t0 + b * beat, [v * math.exp(-k / RATE * 12) for k, v in enumerate(highpass(noise(int(0.2 * RATE), bar * 8 + b), 3000))], 0.08)
    return normalize(buf)

def acoustic_guitar():
    """Music · acoustic guitar: warm finger-picking over four happy chords."""
    buf = new_buffer()
    shapes = [["C3", "E3", "G3", "C4", "E4"], ["B2", "D3", "G3", "B3", "D4"], ["A2", "E3", "A3", "C4", "E4"], ["F2", "C3", "F3", "A3", "C4"]]
    order = [0, 2, 3, 4, 1, 3, 4, 2]                          # bass, then the treble strings
    for bar in range(4):
        notes_ = shapes[bar]
        for i, s in enumerate(order * 2):
            t = bar * 3.0 + i * 0.1875
            mix(buf, t, pluck(note(notes_[s]), 1.6, 0.9965, 0.45, seed=bar * 20 + i), 0.35 if s else 0.5)
    return normalize(lowpass(buf, 5000))

def epic_strings():
    """Music · epic strings: a rising orchestral string swell with timpani and brass. Get up, hero!"""
    buf = new_buffer()
    strings = [(h, 1.0 / h) for h in range(1, 9)]
    chords = [["D3", "A3", "D4", "F4"], ["A#2", "F3", "A#3", "D4"], ["F3", "A3", "C4", "F4"], ["C3", "G3", "C4", "E4"]]
    for bar, chord in enumerate(chords):
        t0 = bar * 3.0
        swell = 0.6 + 0.15 * bar
        for name in chord:
            for detune in (-0.004, 0.0, 0.004):             # a section, not one violin
                mix(buf, t0, harmonic_tone(note(name), 3.05, strings, attack=0.5, release=0.3, vibrato=0.005, detune=detune), 0.05 * swell)
        mix(buf, t0, harmonic_tone(note(chord[0]) / 2, 3.0, strings[:5], attack=0.2, release=0.3), 0.12 * swell)
        for roll in range(int(6 + bar * 4)):                 # timpani roll that grows
            mix(buf, t0 + 3.0 - (roll + 1) * 0.08, membrane(110, 90, 4, 0.6, 0.2, seed=bar * 30 + roll), 0.12 * (roll + 1) / (6 + bar * 4))
    mix(buf, 0, membrane(110, 80, 2.5, 1.5, 0.3, seed=999), 0.8)       # the big hit at the start of the loop
    mix(buf, 0, brass(note("D4"), 0.8), 0.3)
    return normalize(lowpass(buf, 6000))

def starlight():
    """Starlight: a soft space pad with twinkling bells far away."""
    rng = random.Random(91)
    buf = new_buffer()
    for name in ["C3", "G3", "D4", "E4"]:
        for detune in (-0.003, 0.003):
            mix(buf, 0, harmonic_tone(note(name), DURATION, [(1, 1.0), (2, 0.2)], attack=2.0, release=2.0, vibrato=0.002, vib_rate=0.3, detune=detune), 0.08)
    sparkle = ["C6", "D6", "E6", "G6", "B6", "D7"]
    t = 0.4
    while t < DURATION - 0.3:
        mix(buf, t, bell_strike(note(rng.choice(sparkle)), CHIME, 2.0), 0.12 * (0.4 + 0.6 * t / DURATION))
        t += rng.choice([0.25, 0.5, 0.75])
    return normalize(buf, 0.9)

BUILT_SOUNDS.update({
    "riseup_koto": koto,
    "riseup_sitar": sitar,
    "riseup_desertoud": desert_oud,
    "riseup_savannadrums": savanna_drums,
    "riseup_steeldrum": steel_drum,
    "riseup_singingbowls": singing_bowls,
    "riseup_accordion": accordion,
    "riseup_alpinehorn": alpine_horn,
    "riseup_highlandpipes": highland_pipes,
    "riseup_panflute": pan_flute,
    "riseup_rainforest": rainforest,
    "riseup_seashore": seashore,
    "riseup_thunderstorm": thunderstorm,
    "riseup_jazzpiano": jazz_piano,
    "riseup_acousticguitar": acoustic_guitar,
    "riseup_epicstrings": epic_strings,
    "riseup_starlight": starlight,
})


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
    wanted = set(sys.argv[1:])                        # empty = everything
    jobs = [(name, lambda fn=fn: render(fn)) for name, fn in SOUNDS.items()]
    jobs += [(name, fn) for name, fn in BUILT_SOUNDS.items()]
    for name, build in jobs:
        if wanted and name not in wanted:
            continue
        path = write_caf(name, build())
        print(f"✓ {os.path.relpath(path)}  ({os.path.getsize(path) // 1024} KB)")
