# Mix seamless poolrooms ambience loops from CC0 recordings: a room tone bed, fluorescent hum, water
# moving against the pool edges, a pump behind a wall, and single drips scattered around the room.
#   python3 mix_ambience.py <recordings dir> <out dir>
import subprocess, sys
import numpy as np

RAW, OUT = sys.argv[1:3]
SR = 48000
LOOP = 60.0


def load(name, start=0.0, end=None, stereo=False):
    cmd = ['ffmpeg', '-nostdin', '-v', 'error', '-i', f'{RAW}/{name}.mp3', '-ac', '2' if stereo else '1', '-ar', str(SR), '-f', 'f32le', '-']
    x = np.frombuffer(subprocess.run(cmd, capture_output=True, check=True).stdout, np.float32).astype(np.float64)
    if stereo:
        x = x.reshape(-1, 2)
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


def rms(x):
    return np.sqrt((x ** 2).mean())


def bed(x, level, xf=3.0):
    # Make a recording into a seamless loop of LOOP seconds at a given loudness (relative RMS).
    if x.ndim == 1:
        x = np.stack([x, np.roll(x, int(0.37 * SR))], 1)             # a little width from a mono source
    n, f = int(LOOP * SR), int(xf * SR)
    while len(x) < n + f:
        x = np.concatenate([x, x[::-1]])
    x = x[: n + f].copy()
    ramp = np.linspace(0, 1, f)[:, None]
    x[:f] = x[:f] * ramp + x[n:n + f] * (1 - ramp)                  # the end fades into the start
    x = x[:n]
    return x / (rms(x) + 1e-9) * level


def drips(source, count, level, seed, pan_width=0.9, hi=None):
    # Single drips (each with its own echo) cut from a recording and scattered around the loop.
    r = np.random.default_rng(seed)
    x = load(source)
    env = np.convolve(np.abs(band(x, lo=800)), np.ones(240) / 240, 'same')
    picks, e, L = [], env.copy(), int(2.2 * SR)
    while len(picks) < 14:
        i = int(e.argmax())
        if i < int(0.02 * SR) or i > len(x) - L:
            e[max(0, i - SR // 2): i + SR // 2] = 0
            continue
        picks.append(i); e[max(0, i - SR // 2): i + SR // 2] = 0
    out = np.zeros((int(LOOP * SR), 2))
    for _ in range(count):
        i = picks[r.integers(len(picks))]
        d = x[i - int(0.01 * SR): i - int(0.01 * SR) + L] * np.linspace(1, 0, L) ** 1.5
        if hi: d = band(d, hi=hi)
        p = r.uniform(-pan_width, pan_width)
        g = np.array([np.cos((p + 1) * np.pi / 4), np.sin((p + 1) * np.pi / 4)]) * r.uniform(0.35, 1.0)
        at = int(r.uniform(0, LOOP) * SR)
        idx = (np.arange(L) + at) % len(out)                            # wrap around so the loop stays seamless
        out[idx] += d[:, None] * g
    return out / (rms(out) + 1e-9) * level


def save(name, st):
    st = st / (np.abs(st).max() + 1e-9) * 0.9
    pcm = (np.clip(st, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-', f'{OUT}/{name}.wav'], input=pcm, check=True)


room = bed(band(load('670070', 10, 120), lo=40), 1.0)                       # empty-building room tone
hum = bed(band(load('451918', 2, 54), lo=60, hi=3000), 0.45)                 # fluorescent tubes, softened
water = bed(band(load('480855', 0, 73), lo=80, hi=5000), 0.5)                # water moving against the edges
pump = bed(band(load('658155', 5, 180), lo=40, hi=900), 1.4)                 # pump room, heard through a wall
cave_drops = bed(band(load('609161', 1, 47), lo=300), 0.3)                   # far-off drops

# Shallow halls with the lights on: room tone, hum, gentle water, a few drips.
save('amb_halls', room + hum + water + drips('177958', 9, 0.55, 1))
# Next to a pump room: the same hall, with a pump droning behind the wall.
save('amb_pumproom', room * 0.6 + hum * 0.8 + water * 0.8 + pump + drips('177958', 6, 0.45, 2))
# Dark sector, lights off: no hum. Quieter water, far-off drops, more drips close by.
save('amb_dark', room + water * 0.55 + cave_drops + drips('177958', 16, 0.8, 3))
print('mixed')
