# Mix the creature's click voice from CC0 recordings: pitch shifts, filters, layering, an accelerating
# click train, and a tiled pool-hall reverb. Writes stereo WAVs.
#   python3 mix_voice.py <raw dir> <out dir>
import subprocess, sys
import numpy as np

RAW, OUT = sys.argv[1:3]
SR = 48000
rng = np.random.default_rng(7)


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


def pool_reverb(x, wet, rt_low=2.6, rt_high=1.1):
    # Hard tiles and water: long, bright early, highs dying faster than lows. Different noise per ear.
    n = int(rt_low * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        noise = rng.standard_normal(n)
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


# ---- 1. Hunting: the click voice it makes while searching. Mostly dry: a short, small-room echo.
dur = 12.0; N = int(dur * SR)
throat = fit(pitch(load('688417', 1.5, 12.0), -4), N)
save('voice_search', pool_reverb(fades(throat), wet=0.12, rt_low=1.0, rt_high=0.45))

# ---- 2. Close by: rattling clicks and teeth, near you. Two higher pitches to choose from.
dur = 8.0; N = int(dur * SR)
teeth = fit(band(load('470902', 0.9, 9.5), lo=600), N)
for name, semis in (('voice_close_high', 0), ('voice_close_higher', 3)):
    rattle = fit(pitch(load('830016', 0.0, 6.9), semis), N)
    save(name, pool_reverb(fades(rattle + teeth * 0.5), wet=0.1, rt_low=0.9, rt_high=0.4))

# ---- 3. Charging: a death screech. A recorded scream, lowered for size, with a second throat an octave
# under it (not quite human), a torn edge, and dry ice on piano strings whining on top.
def screech(voice, start, end, drive):
    v = load(voice, start, end)
    body = pitch(v, -4)
    s = body + fit(pitch(v, -12), len(body)) * 0.45
    s = np.tanh(band(s, lo=120) * drive) / np.tanh(drive)
    s = s + fit(band(pitch(load('10347', 1.5, 3.75), -2), lo=900), len(s)) * 0.35
    s *= np.minimum(1, np.arange(len(s)) / (0.01 * SR))
    s[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))
    return s


def click_lead(length=0.75):
    # Clicks speeding up, to lead into the screech.
    gs = grains(pitch(load('688417', 1.5, 23.4), -3), 24)
    lead = np.zeros(int(length * SR)); pos, k, iv = 0, 0, 0.09
    while pos < len(lead) - 3000:
        g = gs[k % len(gs)]; m = min(len(g), len(lead) - pos)
        lead[pos:pos + m] += g[:m]; pos += int(iv * SR); k += 1; iv = max(0.02, iv * 0.82)
    return lead * 0.8


short_room = dict(wet=0.15, rt_low=1.1, rt_high=0.5)
mic = screech('633958', 0.0, 2.2, 0.8)              # already harsh, so little extra edge
save('voice_charge_a', pool_reverb(mic, **short_room))
save('voice_charge_a_clicks', pool_reverb(np.concatenate([click_lead(), mic]), **short_room))
save('voice_charge_b', pool_reverb(screech('249813', 0.42, 1.2, 2.2), **short_room))
save('voice_charge_c', pool_reverb(screech('398802', 0.0, 2.0, 1.0), **short_room))
print('mixed')
