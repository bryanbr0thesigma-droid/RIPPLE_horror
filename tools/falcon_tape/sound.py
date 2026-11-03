# Sound for the tape. Nothing is synthesized: everything comes from recordings (the game's own,
# the CC0 files in assets/sound) and Microsoft Sam, and is only cut, filtered and mixed here.
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


def asset(name):
    return load(f"{HERE}/assets/sound/{name}")


def save(path, st):
    pcm = (np.clip(st, -1, 1) * 32767).astype("<i2").tobytes()
    ch = 1 if st.ndim == 1 else st.shape[1]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", str(ch), "-i", "-", path], input=pcm, check=True)


def filt(x, lo=None, hi=None, order=2):
    """Zero-phase Butterworth-shaped band limit, done in the frequency domain."""
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


def reverb(x, decay=1.2, mix=0.3, seed=1, lo=200, hi=5000):
    """A plain convolution reverb (an exponentially decaying noise burst as the room)."""
    rng = np.random.default_rng(seed)
    n = int(decay * SR)
    ir = filt(rng.normal(0, 1, n) * np.exp(-np.arange(n) / SR * 6.9 / decay), lo, hi)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    m = len(x) + n - 1
    N = 1 << int(math.ceil(math.log2(m)))
    wet = np.fft.irfft(np.fft.rfft(x, N) * np.fft.rfft(ir, N), N)[:m]
    out = wet * mix
    out[:len(x)] += x * (1 - mix)
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


def loop_to(x, n):
    return np.tile(x, n // len(x) + 1)[:n]


def place(buf, x, t, gain=1.0):
    i = int(t * SR)
    if i >= len(buf) or i + len(x) <= 0:
        return
    if i < 0:
        x, i = x[-i:], 0
    m = min(len(x), len(buf) - i)
    buf[i:i + m] += x[:m] * gain


def tape(x, hiss):
    """Wow and flutter, the tape's band limit and a little saturation; hiss is a recording
    (the CC0 static, filtered thin) laid under everything."""
    n = len(x)
    t = np.arange(n) / SR
    wobble = (0.0009 * np.sin(2 * np.pi * 0.55 * t) + 0.0004 * np.sin(2 * np.pi * 0.21 * t + 1)
              + 0.00003 * np.sin(2 * np.pi * 6.8 * t))
    x = np.interp(t - wobble - 0.002, t, x)
    x = filt(x, 70, 9000)
    x = np.tanh(x * 1.15) / 1.15
    return x + loop_to(filt(hiss, 2500, 9000), n) * 0.02
