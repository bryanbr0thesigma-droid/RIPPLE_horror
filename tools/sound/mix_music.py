# Background music that barely sounds like music: CC0 recordings slowed down 5-12 times with a spectral
# stretch (the "paulstretch" method: big overlapping windows with their phases scrambled), so notes melt
# into slow, shifting tones. Writes stereo WAVs that loop.
#   python3 mix_music.py <out dir> name=path ...
import subprocess, sys
import numpy as np

OUT = sys.argv[1]
SRC = dict(a.split('=', 1) for a in sys.argv[2:])
SR = 48000


def load(name, start=0.0, end=None):
    cmd = ['ffmpeg', '-nostdin', '-v', 'error', '-i', SRC[name], '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-']
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    x = x[int(start * SR): int(end * SR) if end else None]
    return x / (np.abs(x).max() + 1e-9)


def band(x, lo=None, hi=None):
    X = np.fft.rfft(x, axis=0)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    g = np.ones_like(fr)
    if lo: g *= 1 / np.sqrt(1 + (lo / np.maximum(fr, 1)) ** 4)
    if hi: g *= 1 / np.sqrt(1 + (fr / hi) ** 4)
    if x.ndim == 2: g = g[:, None]
    return np.fft.irfft(X * g, len(x), axis=0)


def pitch(x, semis):
    f = 2 ** (semis / 12)
    return np.interp(np.arange(int(len(x) / f)) * f, np.arange(len(x)), x)


def stretch(x, factor, win=0.6, seed=0):
    r = np.random.default_rng(seed)
    n = int(win * SR) // 2 * 2
    w = (1 - np.linspace(-1, 1, n) ** 2) ** 1.25
    hop_out = n // 4
    hop_in = hop_out / factor
    frames = int((len(x) - n) / hop_in)
    out = np.zeros(frames * hop_out + n)
    for k in range(frames):
        i = int(k * hop_in)
        mag = np.abs(np.fft.rfft(x[i:i + n] * w))
        ph = r.uniform(0, 2 * np.pi, len(mag))
        out[k * hop_out: k * hop_out + n] += np.fft.irfft(mag * np.exp(1j * ph), n) * w
    return out / (np.abs(out).max() + 1e-9)


def loop(st, xf=6.0):
    f = int(xf * SR)
    n = len(st) - f
    ramp = np.linspace(0, 1, f)[:, None]
    st = st.copy()
    st[:f] = st[:f] * ramp + st[n:] * (1 - ramp)
    return st[:n]


def save(name, st):
    st = st / (np.abs(st).max() + 1e-9) * 0.9
    pcm = (np.clip(st, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-', f'{OUT}/{name}.wav'], input=pcm, check=True)


def both_ears(x, factor, win, lo=None, hi=None):
    # Two different stretches of the same sound, one per ear, for a wide, slowly moving sound.
    l, r = stretch(x, factor, win, 1), stretch(x, factor, win, 2)
    n = min(len(l), len(r))
    return band(np.stack([l[:n], r[:n]], 1), lo=lo, hi=hi)


# 1. Melted piano: a slow electric piano piece stretched 8x. Its chords become long, drifting tones.
piano = both_ears(load('hope', 2.3, 28), 8, 0.7, lo=60, hi=3000)   # skip the silent first 2 s
save('music_melted_piano', loop(piano))

# 2. Singing drips: cave drips and dry ice on piano strings, stretched until the drips turn into a faint
#    shimmering choir, an octave lower.
drips = both_ears(pitch(load('drips', 0, 40), -5), 6, 0.5, lo=150, hi=4000)
whine = both_ears(pitch(load('dryice', 0, 3.7), -12), 30, 0.5, lo=100, hi=2500)
n = min(len(drips), len(whine))
save('music_singing_drips', loop(drips[:n] + 0.45 * whine[:n]))

# 3. Under the surface: a soft underwater pad stretched 10x and lowered, like hearing music through water.
pad = both_ears(pitch(load('pad', 0, 16.7), -7), 10, 0.8, lo=40, hi=1600)
save('music_under_surface', loop(pad))
print('mixed')
