# The tape's music, synthesized here: the cheerful early-90s training-video bed (soft electric
# piano chords, a pad and a bass on a gentle Fmaj7 - Dm7 - Bbmaj7 - C loop) and the logo jingle.
import numpy as np
from sound import SR, env, filt, norm, place, reverb


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def epiano(freq, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    idx = 1.4 * np.exp(-t * 3.5) + 0.15
    tine = np.sin(2 * np.pi * freq * 14 * t) * 0.6 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * freq * t + np.sin(2 * np.pi * freq * t) * idx + tine)
    return x * np.exp(-t * 1.6) * env(n, 0.003, 0.08) * vel


def bell(freq, dur, vel=1.0, ratio=3.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t + 2.2 * np.exp(-t * 2.0) * np.sin(2 * np.pi * freq * ratio * t))
    return x * np.exp(-t * 2.2) * env(n, 0.002, 0.2) * vel


def pad(freqs, dur, vel=1.0, harm=7, detune=0.004):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        for d in (-detune, detune):
            for k in range(1, harm + 1):
                x += np.sin(2 * np.pi * f * (1 + d) * k * t + k) / k * (0.7 ** k)
    return x / (len(freqs) * 2) * env(n, 0.6, 0.8) * vel


def bass(freq, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)) * np.exp(-t * 0.8) * env(n, 0.01, 0.1) * vel


CHORDS = [(41, [53, 57, 60, 64]), (38, [50, 57, 60, 65]), (46, [53, 57, 58, 62]), (48, [52, 55, 60, 64])]


def corporate_bed(length, bpm=84):
    beat = 60 / bpm
    bar = beat * 4
    buf = np.zeros(int(length * SR) + SR * 4)
    t, i = 0.0, 0
    while t < length:
        b, notes = CHORDS[(i // 2) % 4]
        fs = [mtof(m) for m in notes]
        if i % 2 == 0:
            place(buf, pad(fs, bar * 2 + 0.8, 0.55), t)
            place(buf, bass(mtof(b), bar * 2, 0.5), t)
        for pos, vel in ((0, 0.55), (1.5, 0.35), (2.5, 0.4)):
            for j, f in enumerate(fs):
                place(buf, epiano(f, beat * 1.4, vel), t + pos * beat + j * 0.008)
        t += bar
        i += 1
    return norm(filt(buf, 60, 5000)[:int(length * SR)], 0.5)


def logo_jingle():
    out = np.zeros(int(4.5 * SR))
    for k, m in enumerate([65, 69, 72, 77]):
        place(out, bell(mtof(m), 3.5, 0.6), k * 0.16)
    place(out, pad([mtof(m) for m in (53, 57, 60, 64)], 3.0, 0.5), 0.6)
    return norm(reverb(out, 1.6, 0.3), 0.8)
