# The squeeze flashlight's sounds, synthesized: a dynamo whirring while it's squeezed (a seamless
# loop: a geared whine with the ratchet ticking) and the click of the lever.
#   python3 synth_flashlight.py <out dir>
import sys, subprocess
import numpy as np

SR = 48000
OUT = sys.argv[1]


def save(name, x):
    x = x / (np.abs(x).max() + 1e-9) * 0.8
    st = np.stack([x, x], 1)
    pcm = (np.clip(st, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'libvorbis', '-q:a', '5', f'{OUT}/{name}.ogg'], input=pcm, check=True)


r = np.random.default_rng(3)
n = SR * 2                                   # 2 s loop, whole number of cycles of everything
t = np.arange(n) / SR
f = 240.0
saw = 2 * ((t * f) % 1.0) - 1
whine = saw * 0.5 + np.sin(2 * np.pi * f * 2 * t) * 0.3
whine *= 0.75 + 0.25 * np.sin(2 * np.pi * 4.0 * t)          # the squeeze rhythm
ticks = np.zeros(n)
for i in range(36):                           # the ratchet: 18 ticks a second
    p = int(i * n / 36)
    L = int(0.006 * SR)
    ticks[p:p + L] += r.standard_normal(L) * np.exp(-np.arange(L) / (0.0015 * SR))
X = np.fft.rfft(whine * 0.35 + ticks * 0.8)
fr = np.fft.rfftfreq(n, 1 / SR)
X *= 1 / np.sqrt(1 + (fr / 3500) ** 4) / np.sqrt(1 + (200 / np.maximum(fr, 1)) ** 4)
save('flashlight_whir', np.fft.irfft(X, n))
L = int(0.08 * SR)
click = r.standard_normal(L) * np.exp(-np.arange(L) / (0.006 * SR))
click += np.sin(2 * np.pi * 1800 * np.arange(L) / SR) * np.exp(-np.arange(L) / (0.01 * SR)) * 0.6
save('flashlight_click', click)
print('flashlight sounds')
