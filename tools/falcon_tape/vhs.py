# Makes a clean 640x480 frame look like it was played off a worn VHS tape: soft luma with an
# edge halo, smeared and shifted colour, wobbling scanlines, head-switching noise at the bottom,
# dropouts, snow, and tracking glitches when asked for.
import numpy as np

H, W = 480, 640


def hblur(a, n):
    """Box blur of width n along the rows (last axis)."""
    if n <= 1:
        return a
    pad = n // 2
    p = np.pad(a, [(0, 0)] * (a.ndim - 1) + [(pad + 1, n - pad - 1)], mode="edge")
    cs = np.cumsum(p, axis=-1)
    return (cs[..., n:] - cs[..., :-n]) / n


def shift_rows(chans, dx):
    """Shift every row of each channel right by dx[row] pixels (fractional, edge-filled)."""
    xs = np.arange(W, dtype=np.float32)[None, :] - dx[:, None]
    x0 = np.floor(xs)
    f = (xs - x0)[None]
    i0 = np.clip(x0, 0, W - 1).astype(np.int32)
    i1 = np.clip(x0 + 1, 0, W - 1).astype(np.int32)
    a = np.take_along_axis(chans, np.broadcast_to(i0, chans.shape), axis=2)
    b = np.take_along_axis(chans, np.broadcast_to(i1, chans.shape), axis=2)
    return a * (1 - f) + b * f


_rows = np.arange(H, dtype=np.float32)
_vy, _vx = np.mgrid[0:H, 0:W].astype(np.float32)
_vig = 1 - 0.22 * (((_vx - W / 2) / (W / 2)) ** 2 + ((_vy - H / 2) / (H / 2)) ** 2) ** 1.5
_vig = np.clip(_vig, 0.6, 1)[None]
_scan = np.where(np.arange(H) % 2 == 1, 0.93, 1.0).astype(np.float32)[:, None, None]


def snow(rng, shape=(H, W)):
    n = rng.random(shape, dtype=np.float32)
    n = hblur(n, 3)
    n = (n - 0.5) * 2.6 + 0.5
    n *= (0.7 + 0.6 * rng.random((shape[0], 1), dtype=np.float32))
    return np.clip(n, 0, 1)


def vhs(img, gt, fi, glitch=0.0, static=0.0, wear=1.0):
    """img: HxWx3 uint8. gt: time in seconds, fi: frame index (seeds the noise).
    glitch: 0..1 tracking trouble. static: 0..1 blend to snow. wear: overall noise amount."""
    rng = np.random.default_rng(fi * 7919 + 17)
    x = img.astype(np.float32) / 255.0
    R, G, B = x[..., 0], x[..., 1], x[..., 2]
    Y = 0.299 * R + 0.587 * G + 0.114 * B
    I = 0.596 * R - 0.274 * G - 0.322 * B
    Q = 0.211 * R - 0.523 * G + 0.312 * B

    if static > 0:
        sn = snow(rng)
        Y = Y * (1 - static) + sn * static
        I = I * (1 - static) + (rng.random((H, W), dtype=np.float32) - 0.5) * 0.08 * static
        Q = Q * (1 - static) + (rng.random((H, W), dtype=np.float32) - 0.5) * 0.08 * static

    # Luma: limited bandwidth, with the sharpening halo VHS decks add.
    Yb = hblur(Y, 3)
    Y = Yb + 0.55 * (Yb - hblur(Y, 11))
    # Chroma: much less bandwidth, smeared to the right, half vertical resolution.
    I = hblur(hblur(I, 11), 9)
    Q = hblur(hblur(Q, 11), 9)
    I = np.roll(I, 4, axis=1); I[:, :4] = I[:, 4:5]
    Q = np.roll(Q, 4, axis=1); Q[:, :4] = Q[:, 4:5]
    I = (I + np.roll(I, 1, axis=0)) * 0.5
    Q = (Q + np.roll(Q, 1, axis=0)) * 0.5
    I *= 0.82
    Q *= 0.82
    # Chroma noise: slow colour blotches along each line.
    cn = rng.normal(0, 0.022 * wear, (2, H, W // 16 + 1)).astype(np.float32)
    cn = np.repeat(cn, 16, axis=2)[:, :, :W]
    I += hblur(cn[0], 17)
    Q += hblur(cn[1], 17)
    # Luma noise.
    Y = Y + hblur(rng.normal(0, 0.03 * wear, (H, W)).astype(np.float32), 2)

    # Timebase wobble: every line shifts a little; the picture bends at the top.
    dx = 0.45 * np.sin(_rows / 37.0 + gt * 1.7) + 0.3 * np.sin(_rows / 9.0 - gt * 5.1)
    dx += hblur(rng.normal(0, 0.35, H).astype(np.float32)[None], 5)[0]
    dx += 3.0 * np.exp(-_rows / 7.0) * (0.6 + 0.4 * np.sin(gt * 3.0))
    if glitch > 0:
        band_c = (gt * 260.0) % (H + 160) - 80
        band_h = 18 + 60 * glitch
        inband = np.abs(_rows - band_c) < band_h
        jag = np.repeat(rng.normal(0, 1, H // 3 + 1).astype(np.float32), 3)[:H]
        dx += inband * jag * 22 * glitch
        dx += rng.normal(0, 1.4 * glitch, H).astype(np.float32)
        Y = np.where(inband[:, None], Y * (1 - 0.5 * glitch) + snow(rng) * 0.6 * glitch, Y)
    # Head switching noise in the last lines.
    hs = 8
    dx[-hs:] += 14 + rng.normal(0, 4, hs) + np.linspace(0, 10, hs)
    chans = shift_rows(np.stack([Y, I, Q]), dx.astype(np.float32))
    Y, I, Q = chans[0], chans[1], chans[2]
    Y[-hs:] = Y[-hs:] * 0.7 + snow(rng, (hs, W)) * 0.3

    # Dropouts: short bright streaks where the tape's oxide is gone.
    n_drop = rng.poisson(1.2 * wear + 25 * glitch)
    for _ in range(n_drop):
        yy = rng.integers(0, H - hs)
        xx = rng.integers(0, W - 20)
        L = rng.integers(8, 70)
        Y[yy, xx:xx + L] = 0.75 + 0.25 * rng.random()
        I[yy, xx:xx + L] *= 0.2
        Q[yy, xx:xx + L] *= 0.2

    # Vertical roll on big glitches.
    if glitch > 0.6:
        off = int((glitch - 0.6) * 120 * rng.random())
        if off:
            Y = np.roll(Y, off, axis=0); I = np.roll(I, off, axis=0); Q = np.roll(Q, off, axis=0)
            Y[max(0, off - 4):min(H, off + 4)] = 0.02

    R = Y + 0.956 * I + 0.621 * Q
    G = Y - 0.272 * I - 0.647 * Q
    B = Y - 1.106 * I + 1.703 * Q
    out = np.stack([R, G, B])
    out = 0.05 + 0.9 * np.clip(out, 0, 1)
    out = out * _vig
    out = np.transpose(out, (1, 2, 0)) * _scan
    return (np.clip(out, 0, 1) ** 1.05 * 255).astype(np.uint8)
