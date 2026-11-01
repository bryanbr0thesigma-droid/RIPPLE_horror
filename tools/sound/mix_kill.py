# The kill sounds, all from the CC0 recordings the voice already uses: death screech takes built
# from the three approved screams (the game plays a different one each kill), bite crunches, the
# tearing, the spine being pulled out, wet chewing while it feeds, and a drowning gurgle.
#   python3 mix_kill.py <raw dir> <ambience raw dir> <out dir>
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


def voice(name, start, length, semis, sub, drive_amt):
    v = load(name, start, start + length)
    body = pitch(v, semis)
    s = body + fit(pitch(v, semis - 12), len(body)) * sub
    s = np.tanh(band(s, lo=110) * drive_amt) / np.tanh(drive_amt)
    return s / (np.abs(s).max() + 1e-9)


def banshee(start, semis, n, level):
    return fit(band(pitch(load('10347', start, start + 2.4), semis), lo=900), n) * level


def stutter(x, cuts, gap):
    # Break a scream into bursts: "ah-ah-AAAH".
    out, pos = [], 0
    for c in cuts:
        i = int(c * SR)
        piece = x[pos:i].copy()
        piece[-int(0.01 * SR):] *= np.linspace(1, 0, int(0.01 * SR))
        out += [piece, np.zeros(int(gap * SR))]
        pos = i
    out.append(x[pos:])
    return np.concatenate(out)


def rattle_tail(seconds, semis, seed):
    r = np.random.default_rng(seed)
    st = r.uniform(7.0, 24.0)
    return fades(drive(pitch(load('830016', st, st + seconds * 2 ** (semis / 12)), semis), 2.2), 0.05, 0.4)


def gurgle(seconds, semis, seed):
    r = np.random.default_rng(seed)
    st = r.uniform(2.0, 20.0)
    w = band(pitch(load_amb('480855', st, st + seconds * 2 ** (semis / 12)), semis), lo=80, hi=900)
    n = len(w)
    env = np.zeros(n)                     # bubbles: short swells at random
    for _ in range(int(seconds * 9)):
        c, L = int(r.uniform(0, n)), int(r.uniform(0.04, 0.16) * SR)
        env[c:c + L] += np.hanning(L)[: len(env[c:c + L])] * r.uniform(0.5, 1.0)
    w = w * (0.25 + env)
    return fades(w / (np.abs(w).max() + 1e-9), 0.05, 0.5)


def inhale(x, length):
    # A reversed, filtered breath of the scream that swells into it.
    piece = band(x[: int(length * SR)][::-1], lo=300, hi=3000)
    return piece * np.linspace(0, 1, len(piece)) ** 2 * 0.6


def finish(s, n_tail=0.08):
    s = s / (np.abs(s).max() + 1e-9)
    s *= np.minimum(1, np.arange(len(s)) / (0.008 * SR))
    s[-int(n_tail * SR):] *= np.linspace(1, 0, int(n_tail * SR))
    return s


room = dict(wet=0.16, rt_low=1.2, rt_high=0.5)
TAKES = [
    # (scream, start, length, semis, sub, drive, second scream or None, banshee (start, semis, level), shape)
    ('633958', 0.0, 2.2, -4, 0.45, 0.8, ('398802', 0.0, 2.0, -5, 0.4, 1.0, 0.8), (1.5, -2, 0.35), 'plain'),
    ('398802', 0.3, 2.4, -6, 0.6, 1.4, None, (0.5, -5, 0.25), 'plain'),
    ('633958', 0.6, 1.9, -2, 0.3, 1.0, None, (1.0, 1, 0.45), 'stutter'),
    ('398802', 0.0, 2.6, -3, 0.5, 0.9, ('633958', 0.9, 1.6, -7, 0.5, 1.2, 0.6), None, 'plain'),
    ('633958', 0.2, 2.0, -7, 0.55, 1.6, None, (0.2, -4, 0.3), 'inhale'),
    None,   # take 6 was turned down
    ('633958', 0.0, 2.6, -5.5, 0.6, 1.2, None, None, 'plain'),
]
for i, take in enumerate(TAKES):
    if take is None:
        continue
    name, st, ln, semis, sub, drv, second, ban, shape = take
    s = voice(name, st, ln, semis, sub, drv)
    if second:
        n2, s2, l2, p2, sb2, d2, lvl = second
        b = voice(n2, s2, l2, p2, sb2, d2)
        delay = int((0.15 + 0.1 * (i % 3)) * SR)
        n = max(len(s), len(b) + delay)
        s = fit(s, n) + fit(np.pad(b, (delay, 0)), n) * lvl
    if ban:
        s = s + banshee(ban[0], ban[1], len(s), ban[2])
    s = finish(s)
    if shape == 'stutter':
        s = stutter(s, [0.18 + 0.04 * (i % 2), 0.42], 0.09 + 0.02 * (i % 3))
    elif shape == 'rattle':
        s = np.concatenate([s[:-int(0.3 * SR)], fit(s[-int(0.3 * SR):], int(0.3 * SR)) + fit(rattle_tail(1.4, -4 - i % 3, i)[:int(0.3 * SR)], int(0.3 * SR)) * 0.5, rattle_tail(1.4, -4 - i % 3, i) * 0.6])
    elif shape == 'gurgle':
        s = np.concatenate([s, gurgle(1.8, -6, i) * 0.7])
    elif shape == 'inhale':
        s = np.concatenate([inhale(s, 0.5), s])
    V.save('kill_screech_%d' % (i + 1), pool_reverb(finish(s, 0.2), **room))

# The bite: teeth clicks dropped an octave and more, crushed, over a low thump and a wet squelch.
teeth = grains(load('470902', 0.5, 9.5), 12, length=0.06)
for k in range(2):
    r = np.random.default_rng(40 + k)
    n = int(0.9 * SR)
    out = np.zeros(n)
    for j in range(4):
        g = drive(pitch(teeth[(k * 4 + j) % len(teeth)], -13 + j), 3.0)
        p = int((0.02 + j * r.uniform(0.05, 0.09)) * SR)
        out[p:p + len(g)] += g[: n - p] * (1.0 - j * 0.15)
    t = np.arange(int(0.35 * SR)) / SR
    out[: len(t)] += np.sin(2 * np.pi * (55 + 20 * k) * t) * np.exp(-t * 12) * 0.9
    sq = band(pitch(load_amb('480855', 3.0 + k * 5, 4.5 + k * 5), -5), lo=200, hi=2200)
    out += fit(sq, n) * np.exp(-np.arange(n) / (0.25 * SR)) * 0.6
    V.save('kill_bite_%d' % (k + 1), pool_reverb(finish(out, 0.15), wet=0.1, rt_low=0.8, rt_high=0.35))

# Tearing flesh: wet squelches from the water recording, cut short and stacked, over a low strain.
def tear(seconds, seed, cracks):
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    out = np.zeros(n)
    w = band(pitch(load_amb('480855', 4.0 + seed, 9.0 + seed), -4), lo=150, hi=3200)
    pos = 0
    while pos < n - int(0.05 * SR):            # a fast run of short wet tears
        L = int(r.uniform(0.03, 0.09) * SR)
        i = int(r.integers(0, len(w) - L))
        g = w[i:i + L] * np.hanning(L) * r.uniform(0.6, 1.0)
        out[pos:pos + L] += g[: n - pos]
        pos += int(L * r.uniform(0.35, 0.7))
    out = np.tanh(out / (np.abs(out).max() + 1e-9) * 2.2)
    out *= np.minimum(1, np.arange(n) / (0.04 * SR)) * np.linspace(1.0, 0.5, n)
    t = np.arange(n) / SR                      # a deep strain under it
    out += np.sin(2 * np.pi * (48 + 12 * t) * t) * 0.35 * np.exp(-t * 1.5)
    for c in range(cracks):                    # bones giving way: teeth clicks dropped very low
        g = drive(pitch(teeth[(seed + c) % len(teeth)], -15 + c), 3.5)
        p = int(r.uniform(0.05, 0.8) * n)
        out[p:p + len(g)] += g[: n - p] * 1.1
    return out


V.save('kill_tear', pool_reverb(finish(tear(1.4, 3, 3), 0.25), wet=0.1, rt_low=0.9, rt_high=0.4))
# The spine: a long rip with the vertebrae cracking one after another, faster and faster.
sp = tear(1.8, 7, 0)
gap = 0.16
p = 0.25
k = 0
while p < 1.6:
    g = drive(pitch(teeth[k % len(teeth)], -12 - (k % 3)), 3.0)
    i = int(p * SR)
    sp[i:i + len(g)] += g[: len(sp) - i] * 0.9
    p += gap
    gap = max(0.05, gap * 0.82)
    k += 1
V.save('kill_spine', pool_reverb(finish(sp, 0.3), wet=0.1, rt_low=0.9, rt_high=0.4))
# Feeding: wet chewing and crunching, to loop quietly while it eats.
ch = np.zeros(int(4.0 * SR))
r = np.random.default_rng(11)
p = 0.1
while p < 3.8:
    g = tear(r.uniform(0.15, 0.35), int(r.integers(0, 20)), 1 if r.random() < 0.4 else 0)
    i = int(p * SR)
    ch[i:i + len(g)] += g[: len(ch) - i] * r.uniform(0.4, 0.9)
    p += r.uniform(0.35, 0.8)
V.save('kill_feast', pool_reverb(finish(ch, 0.3), wet=0.12, rt_low=1.0, rt_high=0.45))

# Being dragged under: gurgling water and a choked rattle.
g = gurgle(3.2, -8, 99)
rt = fit(band(pitch(load('830016', 12.0, 15.0), -7), hi=1200), len(g)) * 0.35
V.save('kill_gurgle', pool_reverb(finish(g + rt, 0.5), wet=0.08, rt_low=0.6, rt_high=0.3))
print('mixed kill sounds')
