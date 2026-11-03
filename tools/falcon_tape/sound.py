# Sound for the tape: loading, FFT filters, small synths (the corporate training-video bed,
# chimes, typewriter, whoosh), and the tape itself (hiss, hum, wow and flutter).
import math, os, subprocess
import numpy as np

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
GAME_AUDIO = os.path.normpath(f"{HERE}/../../game/assets/audio")


def load(path, sr=SR):
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(sr), "-f", "f32le", "-"]
    return np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)


def game(name):
    return load(f"{GAME_AUDIO}/{name}.ogg")


def save(path, st):
    pcm = (np.clip(st, -1, 1) * 32767).astype("<i2").tobytes()
    ch = 1 if st.ndim == 1 else st.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-", path], input=pcm, check=True)


def filt(x, lo=None, hi=None, order=2):
    """Zero-phase Butterworth-shaped band limit done in the frequency domain."""
    n = len(x)
    if n == 0:
        return x
    N = 1 << int(math.ceil(math.log2(n + 1024)))
    X = np.fft.rfft(x, N)
    f = np.fft.rfftfreq(N, 1 / SR)
    g = np.ones_like(f)
    if hi:
        g /= np.sqrt(1 + (f / hi) ** (2 * order))
    if lo:
        g /= np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
    return np.fft.irfft(X * g, N)[:n]


def conv(x, ir):
    n = len(x) + len(ir) - 1
    N = 1 << int(math.ceil(math.log2(n)))
    return np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:n]


def reverb(x, decay=1.2, mix=0.3, seed=1, lo=200, hi=5000):
    rng = np.random.default_rng(seed)
    n = int(decay * SR)
    ir = rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR * 6.9 / decay)
    ir = filt(ir, lo, hi)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = conv(x, ir)
    out = np.zeros(len(wet))
    out[:len(x)] += x * (1 - mix)
    out += wet * mix
    return out


def resample(x, factor):
    """Play back factor times faster (factor < 1 slows and lowers)."""
    n = int(len(x) / factor)
    return np.interp(np.arange(n) * factor, np.arange(len(x)), x)


def norm(x, peak=1.0):
    return x / (np.abs(x).max() + 1e-9) * peak


def env(n, a=0.005, r=0.05):
    e = np.ones(n)
    na, nr = min(n, int(a * SR)), min(n, int(r * SR))
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ---------------------------------------------------------------- instruments
def epiano(freq, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    idx = 1.4 * np.exp(-t * 3.5) + 0.15
    mod = np.sin(2 * np.pi * freq * t) * idx
    tine = np.sin(2 * np.pi * freq * 14 * t) * 0.6 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * freq * t + mod + tine)
    return x * np.exp(-t * 1.6) * env(n, 0.003, 0.08) * vel


def bell(freq, dur, vel=1.0, ratio=3.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    idx = 2.2 * np.exp(-t * 2.0)
    x = np.sin(2 * np.pi * freq * t + idx * np.sin(2 * np.pi * freq * ratio * t))
    return x * np.exp(-t * 2.2) * env(n, 0.002, 0.2) * vel


def pad(freqs, dur, vel=1.0, harm=7, detune=0.004):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in freqs:
        for d in (-detune, detune):
            for k in range(1, harm + 1):
                x += np.sin(2 * np.pi * f * (1 + d) * k * t + k) / k * (0.7 ** k)
    x /= len(freqs) * 2
    return x * env(n, 0.6, 0.8) * vel


def bass(freq, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(4 * np.pi * freq * t)
    return x * np.exp(-t * 0.8) * env(n, 0.01, 0.1) * vel


def place(buf, x, t, gain=1.0):
    i = int(t * SR)
    if i >= len(buf) or i + len(x) <= 0:
        return
    if i < 0:
        x, i = x[-i:], 0
    m = min(len(x), len(buf) - i)
    buf[i:i + m] += x[:m] * gain


# ---------------------------------------------------------------- music beds
CHORDS = [  # (bass, chord notes): a gentle Fmaj7 - Dm7 - Bbmaj7 - C loop
    (41, [53, 57, 60, 64]),
    (38, [50, 57, 60, 65]),
    (46, [53, 57, 58, 62]),
    (48, [52, 55, 60, 64]),
]


def corporate_bed(length, bpm=84):
    """The cheerful synth bed of an early-90s training video."""
    beat = 60 / bpm
    bar = beat * 4
    buf = np.zeros(int(length * SR) + SR * 4)
    t = 0.0
    i = 0
    while t < length:
        b, notes = CHORDS[(i // 2) % 4]
        fs = [mtof(m) for m in notes]
        if i % 2 == 0:
            place(buf, pad(fs, bar * 2 + 0.8, 0.55), t)
            place(buf, bass(mtof(b), bar * 2, 0.5), t)
        for k, (pos, vel) in enumerate([(0, 0.55), (1.5, 0.35), (2.5, 0.4)]):
            for j, f in enumerate(fs):
                place(buf, epiano(f, beat * 1.4, vel), t + pos * beat + j * 0.008)
        t += bar
        i += 1
    buf = filt(buf, 60, 5000)
    return norm(buf[:int(length * SR)], 0.5)


def drone(length, seed=3):
    rng = np.random.default_rng(seed)
    n = int(length * SR)
    t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * 41.2 * t) + 0.7 * np.sin(2 * np.pi * 43.65 * t + 1)
         + 0.3 * np.sin(2 * np.pi * 82.4 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t)))
    x += filt(rng.normal(0, 1, n), 80, 400) * 0.6
    return norm(x, 0.5)


# ---------------------------------------------------------------- effects
def chime_logo():
    out = np.zeros(int(4.5 * SR))
    for k, m in enumerate([65, 69, 72, 77]):
        place(out, bell(mtof(m), 3.5, 0.6), k * 0.16)
    place(out, pad([mtof(m) for m in (53, 57, 60, 64)], 3.0, 0.5), 0.6)
    return norm(reverb(out, 1.6, 0.3), 0.8)


def chime_section():
    out = np.zeros(int(2.5 * SR))
    place(out, bell(mtof(81), 2.0, 0.7, ratio=2.0), 0.0)
    place(out, bell(mtof(76), 2.0, 0.7, ratio=2.0), 0.28)
    return norm(reverb(out, 1.0, 0.25), 0.6)


def chime_point(m=76):
    return norm(reverb(bell(mtof(m), 1.6, 0.7, ratio=2.0), 0.8, 0.2), 0.5)


def typewriter(seed=0):
    rng = np.random.default_rng(seed)
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    click = filt(rng.normal(0, 1, n), 1800, 6000) * np.exp(-t * 400)
    thump = np.sin(2 * np.pi * 180 * t) * np.exp(-t * 120) * 0.5
    return norm(click + thump, 0.5)


def tick():
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 2200 * t) * np.exp(-t * 200) * 0.4


def whoosh(dur=0.7, seed=5):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    x = filt(rng.normal(0, 1, n), 400, 3000)
    e = np.sin(np.linspace(0, np.pi, n)) ** 2
    return norm(x * e, 0.4)


def static_burst(dur, seed=7):
    rng = np.random.default_rng(seed)
    n = int(dur * SR)
    x = filt(rng.normal(0, 1, n), 200, 9000)
    x *= 0.6 + 0.4 * filt(rng.normal(0, 1, n), None, 20) * 6
    return norm(x, 0.6) * env(n, 0.005, 0.03)


def relay_click():
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 120 * t) * np.exp(-t * 60) + filt(np.random.default_rng(2).normal(0, 1, n), 1000, 5000) * np.exp(-t * 90) * 0.5
    return norm(x, 0.5)


def hum_buzz(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * 120 * k * t) / k for k in range(1, 8))
    return norm(x, 0.3) * env(n, 0.01, 0.02)


def boom(dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 55 * np.exp(-t * 0.4)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 1.2)
    return norm(x, 0.8)


def tape(x, seed=11):
    """Wow and flutter, the tape's band limit, a little saturation, hiss and mains hum."""
    rng = np.random.default_rng(seed)
    n = len(x)
    t = np.arange(n) / SR
    wobble = (0.0009 * np.sin(2 * np.pi * 0.55 * t) + 0.0004 * np.sin(2 * np.pi * 0.21 * t + 1)
              + 0.00003 * np.sin(2 * np.pi * 6.8 * t))
    x = np.interp(t - wobble - 0.002, t, x)
    x = filt(x, 70, 9000)
    x = np.tanh(x * 1.15) / 1.15
    hiss = filt(rng.normal(0, 1, n), 1500, 12000) * 0.0035
    hum = (np.sin(2 * np.pi * 60 * t) + 0.4 * np.sin(2 * np.pi * 180 * t)) * 0.0022
    return x + hiss + hum
