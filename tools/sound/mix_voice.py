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


def click_bursts(gs, seconds, seed):
    # Clicks in bursts with pauses between them, rather than one even buzz.
    r = np.random.default_rng(seed)
    out = np.zeros(int(seconds * SR)); pos, k = int(0.1 * SR), 0
    while pos < len(out) - int(0.3 * SR):
        for _ in range(r.integers(4, 13)):
            g = gs[k % len(gs)] * r.uniform(0.6, 1.0); k += 1
            m = min(len(g), len(out) - pos)
            out[pos:pos + m] += g[:m]
            pos += int(r.uniform(0.028, 0.065) * SR)
            if pos >= len(out) - len(g):
                break
        pos += int(r.uniform(0.25, 0.9) * SR)
    return out


small_room = dict(wet=0.12, rt_low=1.0, rt_high=0.45)

def shuffle_pieces(x, seconds, seed, piece=(0.12, 0.3), jitter=1.0):
    # Cut a recording into pieces shorter than a spoken word and join them in a random order, each a
    # little higher or lower. No whole "yeah" survives, but the clicks stay wet and natural (not the
    # fixed tone that made it sound like a machine).
    r = np.random.default_rng(seed)
    rms = np.sqrt((x ** 2).mean())
    out = np.zeros(int(seconds * SR) + SR); pos, xf = 0, int(0.015 * SR)
    while pos < int(seconds * SR):
        L = int(r.uniform(*piece) * SR)
        i = int(r.integers(0, len(x) - L))
        chunk = x[i:i + L]
        if np.sqrt((chunk ** 2).mean()) < 0.4 * rms:
            continue                                   # skip the quiet gaps
        chunk = pitch(chunk, r.uniform(-jitter, jitter)) * r.uniform(0.75, 1.0)
        w = np.ones(len(chunk)); w[:xf] = np.linspace(0, 1, xf); w[-xf:] = np.linspace(1, 0, xf)
        m = min(len(chunk), len(out) - pos)
        out[pos:pos + m] += (chunk * w)[:m]
        pos += len(chunk) - xf
    return out[:int(seconds * SR)]


small_room = dict(wet=0.12, rt_low=1.0, rt_high=0.45)
dur = 12.0; N = int(dur * SR)

# ---- 1. Hunting. Three takes:
#   rattle: the same rattling voice as "close by", deeper and steadier, so it's one creature.
#   pieces: the throat clicks cut into short pieces and shuffled, so they can't form a word.
#   both:   the two together.
rattle_src = np.concatenate([load('830016', 7.6, 13.7), load('830016', 22.5, 31.7)])
rattle_hunt = fit(pitch(rattle_src, -3), N)
throat_src = pitch(load('688417', 1.5, 23.4), -4)
pieces = shuffle_pieces(throat_src, dur, 5)
save('voice_search_rattle', pool_reverb(fades(drive(rattle_hunt, 1.8)), **small_room))
save('voice_search_pieces', pool_reverb(fades(drive(pieces, 1.8)), **small_room))
both = rattle_hunt / np.abs(rattle_hunt).max() + 0.7 * pieces / np.abs(pieces).max()
save('voice_search_both', pool_reverb(fades(drive(both, 1.8)), **small_room))
gs = grains(devoice(throat_src), 40, length=0.035)    # single clicks for the charge's lead-in

# ---- 2. Close by: rattling clicks and teeth, between the first pitch and the recorded pitch, distorted.
N = int(8.0 * SR)
teeth = fit(band(load('470902', 0.9, 9.5), lo=600), N)
rattle = fit(pitch(load('830016', 0.0, 6.9), -1.5), N)
save('voice_close', pool_reverb(fades(drive(rattle / np.abs(rattle).max() + teeth * 0.5, 2.0)), wet=0.1, rt_low=0.9, rt_high=0.4))

# ---- 3. Charging: a death screech. Two recorded screams together, each lowered for size with a second
# throat an octave under it (not quite human), a torn edge, and dry ice on piano strings whining on top.
def screech_voice(voice, start, end, drive_amt):
    v = load(voice, start, end)
    body = pitch(v, -4)
    s = body + fit(pitch(v, -12), len(body)) * 0.45
    s = np.tanh(band(s, lo=120) * drive_amt) / np.tanh(drive_amt)
    return s / np.abs(s).max()


def finish(s):
    s = s + fit(band(pitch(load('10347', 1.5, 3.75), -2), lo=900), len(s)) * 0.35
    s *= np.minimum(1, np.arange(len(s)) / (0.01 * SR))
    s[-int(0.08 * SR):] *= np.linspace(1, 0, int(0.08 * SR))
    return s


def click_lead(length=0.75):
    # Clicks speeding up, in the same voice as the hunting clicks, to lead into the screech.
    lead = np.zeros(int(length * SR)); pos, k, iv = 0, 0, 0.09
    while pos < len(lead) - 3000:
        g = gs[k % len(gs)]; m = min(len(g), len(lead) - pos)
        lead[pos:pos + m] += g[:m]; pos += int(iv * SR); k += 1; iv = max(0.02, iv * 0.82)
    return drive(lead, 2.5) * 0.8


a = screech_voice('633958', 0.0, 2.2, 0.8)       # screeched into a mic: already harsh, little extra edge
c = screech_voice('398802', 0.0, 2.0, 1.0)       # long, rough monster scream
n = max(len(a), len(c))
both = finish(fit(a, n) + fit(c, n) * 0.8)
short_room = dict(wet=0.15, rt_low=1.1, rt_high=0.5)
save('voice_charge', pool_reverb(both, **short_room))
save('voice_charge_clicks', pool_reverb(np.concatenate([click_lead(), both]), **short_room))
print('mixed')
