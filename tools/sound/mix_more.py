# More creature sounds, from the same approved CC0 recordings as the voice and the kills:
# - the charge screech in three parts, so it lasts exactly as long as the charge without looping:
#   charge_onset (clicks speeding into the scream), charge_hold_a / _b (the scream carried on: a
#   spectral stretch of its own middle, with slow swells, drifting pitch and rasp from the original,
#   so it keeps changing and never repeats), and charge_end (the scream's real ending).
# - the kills: kill_strain (flesh stretching, bones creaking), kill_crack_1..3 (single bones
#   giving way), kill_neck (the neck tearing open), kill_split (a body tearing down the middle).
# - feeding: feed_tear_1/2 (tearing a mouthful off), feed_crunch_1/2 (bone between the teeth),
#   feed_chew_1/2 (wet chewing), feed_gulp (swallowing), feed_growl (a low rumble while it eats).
#   python3 mix_more.py <raw dir> <ambience raw dir> <out dir>
import sys
import numpy as np
import voice_lib as V
from voice_lib import SR, load, pitch, band, fit, fades, pool_reverb, drive, grains, devoice

V.RAW, AMB, V.OUT = sys.argv[1], sys.argv[2], sys.argv[3]


def load_amb(name, start, end):
    raw = V.RAW
    V.RAW = AMB
    x = load(name, start, end)
    V.RAW = raw
    return x


def norm(x):
    return x / (np.abs(x).max() + 1e-9)


def edge(x, a=0.008, b=0.08):
    x = x.copy()
    na, nb = int(a * SR), int(b * SR)
    x[:na] *= np.linspace(0, 1, na)
    x[-nb:] *= np.linspace(1, 0, nb)
    return x


def stretch(x, factor, win=0.12, seed=0):
    # Spectral stretch: overlapping windows with scrambled phases ("paulstretch"). A short window
    # keeps the grit of a scream instead of melting it into a pad.
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
    return norm(out)


def wobble(x, depth, rate, seed):
    # Slowly drifting pitch (a voice can't hold one note), by resampling at a varying speed.
    r = np.random.default_rng(seed)
    t = np.arange(len(x)) / SR
    sp = 1 + depth * (np.sin(2 * np.pi * rate * t + r.uniform(0, 6)) + 0.5 * np.sin(2 * np.pi * rate * 2.7 * t + r.uniform(0, 6)))
    pos = np.cumsum(sp)
    pos = pos[pos < len(x) - 1]
    return np.interp(pos, np.arange(len(x)), x)


def swells(n, rate, depth, seed):
    r = np.random.default_rng(seed)
    k = max(4, int(n / SR * rate) + 2)
    pts = r.uniform(1 - depth, 1, k)
    return np.interp(np.linspace(0, k - 1, n), np.arange(k), pts)


# ---- The charge screech (the same two screams and dry-ice whine as the approved charge) ---------
def screech_voice(voice, start, end, drive_amt):
    v = load(voice, start, end)
    body = pitch(v, -4)
    s = body + fit(pitch(v, -12), len(body)) * 0.45
    s = np.tanh(band(s, lo=120) * drive_amt) / np.tanh(drive_amt)
    return norm(s)


throat = pitch(load('688417', 1.5, 23.4), -4)
gs = grains(devoice(throat), 40, length=0.035)


def click_lead(length=0.75):
    lead = np.zeros(int(length * SR)); pos, k, iv = 0, 0, 0.09
    while pos < len(lead) - 3000:
        g = gs[k % len(gs)]; m = min(len(g), len(lead) - pos)
        lead[pos:pos + m] += g[:m]; pos += int(iv * SR); k += 1; iv = max(0.02, iv * 0.82)
    return drive(lead, 2.5) * 0.8


a = screech_voice('633958', 0.0, 2.2, 0.8)
c = screech_voice('398802', 0.0, 2.0, 1.0)
n = max(len(a), len(c))
scream = norm(fit(a, n) + fit(c, n) * 0.8)
whine = band(pitch(load('10347', 1.5, 3.75), -2), lo=900)
L = len(scream)
cut_on = int(0.55 * SR)                 # the onset ends here, the hold carries on from here
cut_end = L - int(0.75 * SR)            # the scream's own ending starts here
short_room = dict(wet=0.15, rt_low=1.1, rt_high=0.5)

onset = np.concatenate([click_lead(), scream[:cut_on] + fit(whine, cut_on) * 0.35])
onset[-int(0.04 * SR):] *= np.linspace(1, 0, int(0.04 * SR))
V.save('charge_onset', pool_reverb(onset, **short_room))

middle = scream[cut_on:cut_end]
for name, seed in (('charge_hold_a', 3), ('charge_hold_b', 8)):
    secs = 10.0
    body = fit(wobble(stretch(middle, secs * SR / len(middle) * 1.05, 0.12, seed), 0.012, 0.35, seed), int(secs * SR))
    # Rasp: short grains of the real scream scattered on top, so it stays torn and harsh.
    r = np.random.default_rng(seed + 50)
    rasp = np.zeros(len(body))
    p = 0
    while p < len(body) - int(0.2 * SR):
        Lg = int(r.uniform(0.06, 0.14) * SR)
        i = int(r.integers(0, len(middle) - Lg))
        rasp[p:p + Lg] += middle[i:i + Lg] * np.hanning(Lg) * r.uniform(0.4, 0.9)
        p += int(Lg * r.uniform(0.4, 0.8))
    wl = fit(np.tile(stretch(whine, 3.0, 0.2, seed), 4), len(body))
    hold = norm(body) * 0.8 + norm(rasp) * 0.45 + wl * 0.25
    hold = norm(np.tanh(hold * 1.6)) * swells(len(hold), 1.6, 0.35, seed)
    # It starts exactly where the onset left off: the real scream crossfading into the stretch.
    head = scream[cut_on:cut_on + int(0.35 * SR)] + fit(whine[cut_on:], int(0.35 * SR)) * 0.35
    xf = len(head)
    hold[:xf] = head * np.linspace(1, 0, xf) + hold[:xf] * np.linspace(0, 1, xf)
    hold[:int(0.03 * SR)] *= np.linspace(0, 1, int(0.03 * SR))
    hold[-int(0.3 * SR):] *= np.linspace(1, 0, int(0.3 * SR))
    V.save(name, pool_reverb(hold, **short_room))

end = scream[cut_end:] + fit(whine[cut_end:], L - cut_end) * 0.3
end = edge(end, 0.03, 0.12)
V.save('charge_end', pool_reverb(np.concatenate([end, np.zeros(int(0.6 * SR))]), **short_room))

# ---- Kills -------------------------------------------------------------------------------------
teeth = grains(load('470902', 0.5, 9.5), 12, length=0.06)
water = band(pitch(load_amb('480855', 2.0, 16.0), -4), lo=150, hi=3200)


def tear(seconds, seed, cracks, density=(0.35, 0.7)):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    out = np.zeros(n)
    pos = 0
    while pos < n - int(0.05 * SR):
        Lg = int(r.uniform(0.03, 0.09) * SR)
        i = int(r.integers(0, len(water) - Lg))
        out[pos:pos + Lg] += (water[i:i + Lg] * np.hanning(Lg) * r.uniform(0.6, 1.0))[: n - pos]
        pos += int(Lg * r.uniform(*density))
    out = np.tanh(norm(out) * 2.2)
    out *= np.minimum(1, np.arange(n) / (0.04 * SR)) * np.linspace(1.0, 0.5, n)
    t = np.arange(n) / SR
    out += np.sin(2 * np.pi * (48 + 12 * t) * t) * 0.35 * np.exp(-t * 1.5)
    for k in range(cracks):
        g = drive(pitch(teeth[(seed + k) % len(teeth)], -15 + k), 3.5)
        p = int(r.uniform(0.05, 0.8) * n)
        out[p:p + len(g)] += g[: n - p] * 1.1
    return out


def crack(k):
    n = int(0.45 * SR)
    out = np.zeros(n)
    for j in range(2):                                   # a snap and its splinter
        g = drive(pitch(teeth[(k * 3 + j) % len(teeth)], -9 - 2 * k - j * 3), 4.0)
        p = int(j * 0.035 * SR)
        out[p:p + len(g)] += g[: n - p] * (1.0 - j * 0.35)
    t = np.arange(int(0.25 * SR)) / SR
    out[: len(t)] += np.sin(2 * np.pi * (70 - 10 * k) * t) * np.exp(-t * 18) * 0.8
    return out


r = np.random.default_rng(5)
n = int(1.3 * SR)                                        # flesh stretching, joints creaking
strain = np.zeros(n)
pos = 0
while pos < n - int(0.1 * SR):
    Lg = int(r.uniform(0.08, 0.2) * SR)
    i = int(r.integers(0, len(water) - Lg))
    g = pitch(water[i:i + Lg], -7)
    g = g * np.hanning(len(g))
    strain[pos:pos + len(g)] += g[: n - pos] * r.uniform(0.5, 1.0)
    pos += int(len(g) * r.uniform(0.3, 0.5))
groan = fit(band(pitch(load('830016', 9.0, 11.0), -10), hi=900), n)
strain = norm(np.tanh(norm(strain) * 1.8)) * 0.7 + norm(groan) * 0.5
for j in range(5):                                       # creaks
    g = drive(pitch(teeth[(j * 2) % len(teeth)], -16), 2.0) * 0.5
    p = int(r.uniform(0.15, 1.1) * SR)
    strain[p:p + len(g)] += g[: n - p]
strain *= np.linspace(0.35, 1.0, n) ** 1.5
V.save('kill_strain', pool_reverb(edge(norm(strain), 0.05, 0.15), wet=0.1, rt_low=0.9, rt_high=0.4))
for k in range(3):
    V.save('kill_crack_%d' % (k + 1), pool_reverb(edge(norm(crack(k)), 0.002, 0.1), wet=0.1, rt_low=0.8, rt_high=0.35))

neck = fit(tear(0.7, 21, 1, (0.25, 0.5)), int(0.85 * SR))
t = np.arange(int(0.3 * SR)) / SR
neck[int(0.45 * SR):int(0.45 * SR) + len(t)] += np.sin(2 * np.pi * 52 * t) * np.exp(-t * 14) * 1.2   # the pop
V.save('kill_neck', pool_reverb(edge(norm(neck), 0.005, 0.12), wet=0.1, rt_low=0.9, rt_high=0.4))

split = tear(1.6, 31, 4, (0.2, 0.45))                    # down the middle: faster and faster, then a splatter
split *= np.interp(np.arange(len(split)), [0, 0.3 * SR, 1.1 * SR, len(split)], [0.6, 0.8, 1.0, 0.6])
spl = band(load_amb('480855', 11.0, 12.2), lo=200, hi=5000)
sp_at = int(1.05 * SR)
split = fit(split, sp_at + len(spl))
split[sp_at:] += spl * np.exp(-np.arange(len(spl)) / (0.35 * SR)) * 0.8
V.save('kill_split', pool_reverb(edge(norm(split), 0.005, 0.2), wet=0.12, rt_low=1.0, rt_high=0.45))

# ---- Feeding -----------------------------------------------------------------------------------
for k in range(2):
    V.save('feed_tear_%d' % (k + 1), pool_reverb(edge(norm(tear(0.45, 40 + k, 1, (0.25, 0.5))), 0.004, 0.1), wet=0.1, rt_low=0.8, rt_high=0.35))
for k in range(2):
    n = int(0.5 * SR)
    out = np.zeros(n)
    rr = np.random.default_rng(60 + k)
    p = 0.0
    for j in range(4):                                   # a few quick crunches
        g = drive(pitch(teeth[(k * 5 + j) % len(teeth)], -11 - rr.uniform(0, 3)), 3.2)
        i = int(p * SR)
        out[i:i + len(g)] += g[: n - i] * rr.uniform(0.6, 1.0)
        p += rr.uniform(0.06, 0.11)
    out += fit(band(pitch(water[k * SR: k * SR + int(0.4 * SR)], -6), lo=200, hi=1800), n) * np.exp(-np.arange(n) / (0.15 * SR)) * 0.5
    V.save('feed_crunch_%d' % (k + 1), pool_reverb(edge(norm(out), 0.002, 0.1), wet=0.1, rt_low=0.8, rt_high=0.35))
for k in range(2):
    rr = np.random.default_rng(80 + k)
    n = int(1.6 * SR)
    ch = np.zeros(n)
    p = 0.05
    while p < 1.45:                                      # chewing: wet squelches about three a second
        g = tear(rr.uniform(0.12, 0.25), int(rr.integers(0, 30)), 1 if rr.random() < 0.3 else 0)
        i = int(p * SR)
        ch[i:i + len(g)] += g[: n - i] * rr.uniform(0.4, 0.9)
        p += rr.uniform(0.25, 0.42)
    V.save('feed_chew_%d' % (k + 1), pool_reverb(edge(norm(ch), 0.01, 0.15), wet=0.12, rt_low=1.0, rt_high=0.45))
gulp_w = band(pitch(load_amb('480855', 6.0, 6.6), -11), lo=60, hi=700)
gulp = norm(gulp_w) * np.hanning(len(gulp_w)) ** 0.5
thr = fit(band(pitch(load('830016', 3.0, 3.4), -9), hi=800), len(gulp)) * np.hanning(len(gulp))
V.save('feed_gulp', pool_reverb(edge(norm(gulp + thr * 0.6), 0.01, 0.1), wet=0.08, rt_low=0.7, rt_high=0.3))
gr = band(pitch(load('830016', 14.0, 19.0), -8), hi=1000)
gr = norm(drive(gr, 1.4)) * swells(len(gr), 1.2, 0.5, 9)
V.save('feed_growl', pool_reverb(fades(gr, 0.4, 0.8), wet=0.1, rt_low=0.9, rt_high=0.4))
print('mixed more sounds')
