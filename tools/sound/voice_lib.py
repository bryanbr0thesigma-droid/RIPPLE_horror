# Shared helpers for the creature sound mixes (loading, pitch, filters, distortion, pool reverb).
import subprocess
import numpy as np

SR = 48000
RAW = "."
OUT = "."


def load(name, start=0.0, end=None):
    cmd = ['ffmpeg', '-v', 'error', '-i', f'{RAW}/{name}.mp3', '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-']
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    x = x[int(start * SR): int(end * SR) if end else None]
    return x / (np.abs(x).max() + 1e-9)


def save(name, st):
    st = np.stack([band(st[:, c], lo=70) for c in range(2)], 1)    # clear the rumble under the voice
    st = st / (np.abs(st).max() + 1e-9) * 0.89
    pcm = (np.clip(st, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-', f'{OUT}/{name}.wav'], input=pcm, check=True)


def pitch(x, semis):
    # Resample: lower pitch also slows it down, which suits a big body.
    f = 2 ** (semis / 12)
    n = int(len(x) / f)
    return np.interp(np.arange(n) * f, np.arange(len(x)), x)


def band(x, lo=None, hi=None):
    X = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(fr)
    if lo: g *= 1 / np.sqrt(1 + (lo / np.maximum(fr, 1)) ** 4)
    if hi: g *= 1 / np.sqrt(1 + (fr / hi) ** 4)
    return np.fft.irfft(X * g, len(x))


def fit(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def fades(x, a=0.02, b=0.3):
    x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    x[:na] *= np.linspace(0, 1, na)
    x[-nb:] *= np.linspace(1, 0, nb)
    return x


def pool_reverb(x, wet, rt_low=2.6, rt_high=1.1, seed=7):
    # Hard tiles and water: long, bright early, highs dying faster than lows. Different noise per ear.
    n = int(rt_low * SR)
    t = np.arange(n) / SR
    out = []
    r = np.random.default_rng(seed)          # the same room every run, whatever was mixed before
    for ch in range(2):
        noise = r.standard_normal(n)
        lowp, highp = band(noise, hi=1800), band(noise, lo=1800)
        ir = lowp * 10 ** (-3 * t / rt_low) + highp * 10 ** (-3 * t / rt_high)
        ir[: int(0.012 * SR)] = 0                                  # pre-delay
        for d, gain in ((0.019, 0.5), (0.031, 0.35), (0.047, 0.3), (0.063, 0.22)):   # tile reflections
            ir[int((d + ch * 0.003) * SR)] += gain * 8
        ir /= np.sqrt((ir ** 2).sum())
        m = len(x) + n
        y = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)
        y = y / (np.abs(y).max() + 1e-9) * np.abs(x).max()
        out.append((1 - wet) * np.pad(x, (0, n)) + wet * y)
    return np.stack(out, 1)


def grains(x, count, length=0.07):
    # Pick the strongest click transients as short grains.
    env = np.convolve(np.abs(band(x, lo=900)), np.ones(96) / 96, 'same')
    gap, L = int(0.06 * SR), int(length * SR)
    picks, e = [], env.copy()
    while len(picks) < count:
        i = int(e.argmax())
        if i < L or i > len(x) - L:
            e[max(0, i - gap): i + gap] = 0
            continue
        picks.append(i)
        e[max(0, i - gap): i + gap] = 0
    win = np.hanning(L)
    return [x[i - L // 4: i - L // 4 + L] * win for i in picks]


def devoice(x, n=1024, hop=256, passes=2):
    # Take the vowel out of a voice: flatten each moment's spectral shape (the moving mouth shape that
    # makes throat clicks sound like someone saying "yeah"), then give every frame the same fixed,
    # non-human resonance. Each frame keeps its loudness, so the click rhythm stays.
    win = np.hanning(n)
    fr = np.fft.rfftfreq(n, 1 / SR)
    lf = np.log2(np.maximum(fr, 20))
    target = (0.35 + np.exp(-((lf - np.log2(260)) / 0.6) ** 2) + 0.8 * np.exp(-((lf - np.log2(1300)) / 0.35) ** 2)
              + 0.6 * np.exp(-((lf - np.log2(3400)) / 0.3) ** 2)) / np.sqrt(1 + (fr / 7000) ** 4)
    kernel = np.ones(5) / 5                       # about 230 Hz: narrow enough to catch the vowel peaks
    xp = np.pad(x, (n, n))
    out = np.zeros_like(xp); norm = np.zeros_like(xp)
    for i in range(0, len(xp) - n, hop):
        f = xp[i:i + n] * win
        X = np.fft.rfft(f)
        Y = X
        for _ in range(passes):                   # flatten twice: one pass leaves some of the vowel
            env = np.exp(np.convolve(np.log(np.abs(Y) + 1e-9), kernel, 'same'))
            Y = Y / env
        Y = Y * target
        y = np.fft.irfft(Y, n)
        y *= np.sqrt((f ** 2).sum() / ((y * win) ** 2).sum().clip(1e-12))
        out[i:i + n] += y * win; norm[i:i + n] += win ** 2
    return (out / np.maximum(norm, 1e-6))[n:n + len(x)]


def drive(x, amount):
    # Distortion: a rough, torn edge on the clicks.
    x = x / (np.abs(x).max() + 1e-9)
    return np.tanh(x * amount) / np.tanh(amount)


