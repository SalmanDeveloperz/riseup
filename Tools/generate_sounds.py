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
