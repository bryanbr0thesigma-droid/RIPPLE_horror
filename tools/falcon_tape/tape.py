# Builds "Water Safety and You", the F.A.L.C.O.N. orientation tape about the Wader (about 3 minutes).
#   python3 tape.py <voice_dir> <out_dir> [--stills 12.5,40] [--no-video] [--no-audio] [--size 960x720]
# voice_dir holds Microsoft Sam's lines from fetch_voice.py. Writes out_dir/falcon_tape.mp4 (and .srt).
import argparse, bisect, math, multiprocessing as mp, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gfx, music, scenes as S, sound as A
from narration import LINES, SUBS
from vhs import vhs

FPS = 30
SLOWED = {}               # lines played slower and lower (none now)


# ---------------------------------------------------------------- timeline
def L(key, pad=0.45):
    return ("line", key, pad)


def P(sec):
    return ("pause", sec)


def M(name):
    return ("mark", name)


class Scene:
    def __init__(self, name, draw, beats, beds=None, sfx=None, glitch=None, static=None, freeze=None, snap=False):
        self.name, self.draw, self.beats = name, draw, beats
        self.snap = snap                    # round the length up to whole frames
        self.beds = beds or []
        self.sfx = sfx or []
        self.glitch = glitch or []          # (time, seconds, strength[, also dip the sound])
        self.static = static or []
        self.freeze = freeze or []

    def at(self, spec):
        """A time in this scene: a number, a mark or line name ("pr4"), its end ("e:pr4"), plus an offset ("pr4+0.5")."""
        if isinstance(spec, (int, float)):
            return float(spec)
        off = 0.0
        for sign in ("+", "-"):
            if sign in spec[1:]:
                i = spec.rindex(sign)
                off = float(spec[i:])
                spec = spec[:i]
                break
        if spec.startswith("e:"):
            return self.e[spec[2:]] + off
        return self.m[spec] + off


def frac(key, f, add=0.0):
    """A time that far through a line (0..1), for cues that follow what Sam is saying."""
    return lambda sc: sc.m[key] + f * (sc.e[key] - sc.m[key]) + add


def card(n, name):
    return Scene(f"card{n}", S.section_card(n, name), [P(2.0)], sfx=[(0.0, "chime", 0.45)])


def timeline():
    return [
        Scene("vcr", S.vcr, [P(3.2)], static=[(0, 0.6, 1.0), (2.75, 0.45, 1.0)],
              sfx=[(0, "static:0.6", 0.5), (2.75, "static:0.45", 0.5)]),
        Scene("bars", S.bars, [P(2.6)], sfx=[(0.0, "tone:2.6", 0.25)]),
        Scene("leader", S.leader, [P(3.0)], sfx=[(0.0, "pop", 0.3), (1.0, "pop", 0.3), (2.0, "pop", 0.3)]),
        Scene("warning", S.warning, [P(1.0), L("warn1", 0.7), L("warn2", 1.6), L("warn3", 1.4)]),
        Scene("logo", S.logo, [P(2.9), L("pres", 1.2)], beds=[(0, "corp")], sfx=[(0.25, "jingle", 0.6)]),
        Scene("title", S.title, [P(0.6), L("title", 2.2)], beds=[(0, "corp")], glitch=[("e:title+1.5", 0.25, 0.45)]),
        card(1, "THE POOLROOMS"),
        Scene("poolrooms", S.poolrooms, [P(0.4), L("pr1", 0.6), L("endless", 0.6), L("drink", 0.9), L("pr3", 0.5),
                                         L("pr4", 2.4), L("pr5", 2.8)],
              beds=[(0, "corp+halls"), ("pr4", "halls"), ("pr4+2.6", "eerie")],
              sfx=[("pr5+1.0", "click_close", 0.7)], glitch=[("pr5+1.0", 0.25, 0.3)]),
        card(2, "THE WADER"),
        Scene("wader", S.the_wader, [P(0.5), L("id1", 0.6), L("eyes", 1.4)], beds=[(0, "eerie")],
              sfx=[("e:eyes+0.25", "subliminal", 0.6)], glitch=[("e:eyes+0.2", 0.2, 0.7)]),
        Scene("hearing", S.hearing, [P(0.3), L("sound", 3.2)], beds=[(0, "corp")], sfx=[(0.0, "wade:6", 0.35)]),
        card(3, "FALLING IN"),
        Scene("falling", S.falling, [P(0.3), M("drop"), P(2.1), L("fall", 0.3), L("out", 1.6)],
              beds=[(0, "corp"), ("e:fall+0.1", "eerie")],
              sfx=[("drop+1.0", "splash_big", 0.7), ("e:fall+0.1", "charge_onset", 0.6)], glitch=[("e:fall+0.1", 0.25, 0.35)]),
        Scene("dry", S.dry_ground, [P(0.3), L("dry", 1.6)], beds=[(0, "corp")], sfx=[(0.2, "wade:3.0", 0.35)]),
        card(4, "STILLNESS"),
        Scene("landed", S.landed, [P(0.6), L("landed", 2.4)], beds=[(0, "eerie")], snap=True,
              sfx=[(0.1, "splash_big", 0.7), (frac("landed", 0.48), "wade:1.6", 0.4),
                   (frac("landed", 0.84), "charge_onset", 0.55), (frac("landed", 0.84, 0.7), "close:3.0", 0.45)]),
        Scene("demo", S.demo, [P(0.4), M("walk"), L("feel", 4.2), M("flinch"), P(1.8), M("dark"), P(0.35), M("standby"),
                               P(5.8), M("after"), P(2.4)],
              beds=[(0, "eerie"), ("flinch", "none"), ("standby", "corp"), ("standby+2.75", "none"), ("after", "eerie")],
              sfx=[("walk", "wade:3.0", 0.35), ("walk+0.3", "clip:hunt", 0.55), ("walk+3.0", "close:3.4", 0.45),
                   ("flinch", "wade:1.8", 0.45),
                   ("standby+0.3", "muffled:kill_screech_5", 1.2), ("standby+1.5", "muffled:kill_tear", 1.0),
                   ("standby+1.55", "muffled:kill_crack_2", 0.9), ("standby+2.6", "muffled:splash_big", 0.7),
                   *[(f"standby+{a:.2f}", "static:0.06", 0.35) for a, p in S.STANDBY_FLASHES],
                   ("standby+2.8", "tone:2.95", 0.22)],
              glitch=[(f"standby+{a:.2f}", S.FLASH, 0.35, False) for a, p in S.STANDBY_FLASHES]),
        Scene("stillness2", S.stillness, [P(0.3), L("found", 1.8), L("st5", 2.6)],
              beds=[(0, "eerie"), ("st5-0.3", "none")],
              sfx=[("e:st5+0.15", "stutter", 1.0), ("e:st5+1.35", "subliminal", 0.6)],
              glitch=[("e:st5+0.15", 1.2, 0.35), ("e:st5+1.3", 0.2, 0.8)], freeze=[("e:st5+0.15", 1.1)]),
        card(5, "WARNING SIGNS"),
        Scene("clicking", S.clicking, [P(0.3), L("listen", 0.2), M("snd_hunt"), P(3.0), L("scr", 0.2),
                                       M("snd_charge"), P(4.9)],
              sfx=[("snd_hunt", "clip:hunt", 0.8), ("snd_charge", "clip:charge", 0.75)], glitch=[("snd_charge+2.4", 0.3, 0.4)]),
        card(6, "MISSING PERSONNEL"),
        Scene("taken", S.taken, [P(0.3), L("ca1", 1.2), L("busy", 2.2)], beds=[(0, "dark")],
              sfx=[("ca1+0.8", "subliminal", 0.35), ("ca1+1.4", "muffled:feed_chew_1", 0.6),
                   ("ca1+3.0", "muffled:feed_chew_2", 0.6), ("busy+0.6", "muffled:kill_feast", 0.5)],
              glitch=[("ca1+0.75", 0.15, 0.6)]),
        Scene("back", S.coming_back, [P(0.4), L("ret", 1.0), L("ca6", 2.2)], beds=[(0, "dark")],
              sfx=[("ret+0.8", "drips:4", 0.35)], glitch=[("ca6", 0.18, 0.5)]),
        Scene("summary", S.summary, [P(0.5), L("rm0", 0.5), L("rm1", 0.6), L("rm2", 0.6), L("rm3", 0.9), L("rm4", 0.3)],
              beds=[(0, "corp"), ("rm4", "none")]),
        Scene("fallin", S.fall_in, [P(0.25), L("rm5", 2.2)], glitch=[(0, 0.35, 0.9)], sfx=[(0.0, "static:0.3", 0.5)]),
        Scene("outro", S.outro, [P(0.5), L("end", 3.4)], beds=[(0, "corp")], sfx=[(0.2, "jingle", 0.5)]),
        Scene("blank", S.blank, [P(2.2)], glitch=[(1.95, 0.25, 0.5)]),
        Scene("stinger", S.stinger, [P(0.8), L("body", 0.7), M("yours"), L("hear", 2.4), M("static"), P(1.4), M("stop"),
                                     P(1.6), P(0.8)],
              beds=[(0, "none")], sfx=[("yours", "static:0.08", 0.3), ("static", "static:1.4", 0.6)],
              glitch=[("yours", 0.12, 0.5, False)], static=[("static", 1.4, 1.0)]),
    ]


ALIGN = None   # (old layout {name: (t0, dur)}, changed names): set by splice.py


def copyable(sc, t, dur):
    old, changed = ALIGN
    if sc.name in changed or sc.name not in old or abs(old[sc.name][1] - dur) > 1e-6:
        return False
    shift = (t - old[sc.name][0]) * FPS
    return abs(shift - round(shift)) < 1e-3


def layout(tl, durs):
    t = 0.0
    for i, sc in enumerate(tl):
        sc.t0, sc.m, sc.e = t, {}, {}
        lt = 0.0
        for b in sc.beats:
            if b[0] == "line":
                sc.m[b[1]] = lt
                sc.e[b[1]] = lt + durs[b[1]]
                lt += durs[b[1]] + b[2]
            elif b[0] == "pause":
                lt += b[1]
            else:
                sc.m[b[1]] = lt
        if getattr(sc, "snap", False):
            lt = math.ceil(lt * FPS - 1e-6) / FPS
        if ALIGN and i + 1 < len(tl) and not copyable(sc, t, lt) and tl[i + 1].name in ALIGN[0]:
            # a scene that gets rendered anyway is padded (by under a frame) so the next one
            # lands a whole number of frames from where it was, and can be copied
            frac = ((t + lt - ALIGN[0][tl[i + 1].name][0]) * FPS) % 1.0
            if 1e-6 < frac < 1 - 1e-6:
                lt += (1 - frac) / FPS
        sc.dur = lt
        t += lt
    return t


# ---------------------------------------------------------------- audio sources
def voice(voice_dir, key):
    x = A.load(f"{voice_dir}/{key}.wav")
    x = x[np.argmax(np.abs(x) > 0.01):]                     # drop leading silence
    tail = np.nonzero(np.abs(x) > 0.01)[0]
    x = x[:tail[-1] + int(0.05 * A.SR)] if len(tail) else x
    x = A.filt(x, 140, 7500)
    x = level(x, 0.15)                                      # every line equally loud on average
    x = 0.62 * np.tanh(x / 0.62)
    if key in SLOWED:
        x = A.resample(x, SLOWED[key])
        x = A.filt(x, 80, 4000)
        x = A.reverb(x, 2.6, 0.45, lo=100, hi=3000)
        x = A.norm(x, 0.8)
    return x


def creature_clips():
    hunt = A.game("creature_hunt")
    return {"hunt": hunt[int(3 * A.SR):int(5.8 * A.SR)], "charge": A.game("creature_charge")}


def envelope(x, rate=100):
    hop = A.SR // rate
    n = len(x) // hop
    e = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1))
    return e / (e.max() + 1e-9)


def level(x, rms=0.12):
    """Scale a sound so its loud parts sit at a fixed loudness (about the narration's)."""
    loud = x[np.abs(x) > np.abs(x).max() * 0.05]
    return x / (np.sqrt(np.mean(loud ** 2)) + 1e-9) * rms if len(loud) else x


class Sfx:
    def __init__(self, clips):
        self.clips = clips
        self.cache = {}
        self.static = A.asset("static.mp3")

    def get(self, name):
        if name not in self.cache:
            self.cache[name] = level(self.make(name))
        return self.cache[name]

    def make(self, name):
        base, _, arg = name.partition(":")
        g = A.game
        if base == "static":
            n = int(float(arg) * A.SR)
            return self.static[int(2 * A.SR):int(2 * A.SR) + n] * A.env(n, 0.005, 0.03)
        if base == "click_close":
            return g("creature_close")[int(0.4 * A.SR):int(1.2 * A.SR)] * A.env(int(0.8 * A.SR), 0.01, 0.2)
        if base == "subliminal":
            s = g("kill_screech_3")[:int(0.16 * A.SR)]
            return s + np.concatenate([self.static[:int(0.1 * A.SR)] * 0.5, np.zeros(len(s) - int(0.1 * A.SR))])
        if base == "wade":
            n = int(float(arg) * A.SR)
            return A.loop_to(g("wade_loop"), n) * A.env(n, 0.3, 0.4)
        if base == "close":
            n = int(float(arg) * A.SR)
            return A.loop_to(g("creature_close"), n) * A.env(n, 0.3, 0.6)
        if base == "clip":
            return self.clips[arg]
        if base == "drips":
            x = np.zeros(int(float(arg) * A.SR))
            p = A.resample(g("plop"), 1.6)
            for k in range(int(float(arg) / 0.9)):
                A.place(x, p, k * 0.9 + 0.1 * (k % 3))
            return x
        if base == "screech_far":
            return A.filt(g("kill_screech_1"), None, 1500)
        if base == "chew":
            return A.filt(np.concatenate([g("feed_chew_1"), g("feed_chew_2")]), None, 1800)
        if base == "muffled":
            return A.filt(g(arg), None, 900) * 0.8
        if base == "screech":
            return g("kill_screech_3")
        if base == "jingle":
            return music.logo_jingle()
        if base == "chime":
            return music.section_chime()
        if base == "tone":
            return music.test_tone(float(arg))
        if base == "pop":
            return music.test_tone(0.04)
        if base == "ding":
            return music.ding()
        return g(base)


def build_audio(tl, total, voices, clips, out_wav):
    n = int((total + 1) * A.SR)
    narr = np.zeros(n)
    fx = np.zeros(n)
    for sc in tl:
        for key, t in sc.m.items():
            if key in voices:
                A.place(narr, voices[key], sc.t0 + t)
    sfx = Sfx(clips)
    for sc in tl:
        for spec in sc.sfx:
            t, name, gain = spec
            tt = t(sc) if callable(t) else sc.at(t)
            if name == "stutter":
                v = voices["st5"]
                word = v[-int(0.45 * A.SR):]
                for k, f in enumerate((1.0, 0.92, 0.82)):
                    w = A.resample(word, f)
                    w = np.round(w * 12) / 12 if k else w
                    A.place(narr, w, sc.t0 + tt + k * 0.42, gain * (1 - 0.15 * k))
                continue
            A.place(fx, sfx.get(name), sc.t0 + tt, gain)
    # music beds, with crossfades
    rate = 100
    ctl_n = int((total + 1) * rate)
    gains = {"corp": 0.09, "corp_slow": 0.1, "eerie": 0.08, "halls": 0.05, "dark": 0.08}     # under Sam
    ctl = {k: np.zeros(ctl_n) for k in gains}
    segs = []
    for sc in tl:
        for t, bed in sc.beds:
            segs.append((sc.t0 + sc.at(t), bed))
        if not sc.beds:
            segs.append((sc.t0, "none"))
    segs.sort()
    for i, (t0, bed) in enumerate(segs):
        t1 = segs[i + 1][0] if i + 1 < len(segs) else total + 1
        for b in bed.split("+"):
            if b in ctl:
                ctl[b][int(t0 * rate):int(t1 * rate)] = 1
    k = np.ones(int(0.8 * rate)) / int(0.8 * rate)
    voice_env = np.convolve(np.abs(narr[:ctl_n * (A.SR // rate)]).reshape(ctl_n, -1).max(1) > 0.03, np.ones(60) / 60, "same")
    duck = 1 - 0.4 * np.clip(voice_env * 1.5, 0, 1)
    tt = np.arange(n) / A.SR
    ct = np.arange(ctl_n) / rate
    beds = np.zeros(n)
    srcs = {"corp": lambda: music.corporate_bed(total + 1),
            "corp_slow": lambda: A.filt(A.resample(music.corporate_bed(total * 0.75 + 2), 0.75), None, 2500),
            "eerie": lambda: A.game("music_under_surface"),
            "halls": lambda: A.game("amb_halls"), "dark": lambda: A.game("amb_dark")}
    for b, c in ctl.items():
        if c.any():
            g = np.convolve(c, k, "same") * gains[b] * duck
            src = A.loop_to(level(srcs[b](), 1.0), n)
            beds += src * np.interp(tt, ct, g)
    mix = narr + fx + beds
    # tape trouble: glitches dip the sound and add noise; static replaces it
    trouble = np.zeros(ctl_n)
    noise_amt = np.zeros(ctl_n)
    for sc in tl:
        for t, d, s, *sound in sc.glitch:
            if sound and not sound[0]:
                continue                                    # a picture-only glitch
            a = int((sc.t0 + sc.at(t)) * rate)
            trouble[a:a + int(d * rate)] = np.maximum(trouble[a:a + int(d * rate)], 0.55 * s)
            noise_amt[a:a + int(d * rate)] = np.maximum(noise_amt[a:a + int(d * rate)], 0.12 * s)
        for t, d, s, *sound in sc.static:
            if sound and not sound[0]:
                continue
            a = int((sc.t0 + sc.at(t)) * rate)
            trouble[a:a + int(d * rate)] = np.maximum(trouble[a:a + int(d * rate)], 0.85 * s)
            noise_amt[a:a + int(d * rate)] = np.maximum(noise_amt[a:a + int(d * rate)], 0.35 * s)
    mix *= 1 - np.interp(tt, ct, trouble)
    stat = A.loop_to(level(sfx.static, 0.12), n)
    mix += stat * np.interp(tt, ct, noise_amt) * 3
    mix = A.tape(mix, level(sfx.static, 0.12))
    mix = 0.95 * np.tanh(mix * 1.4 / 0.95)                 # louder, soft-limited (no normalizing to the scream)
    A.save(out_wav, np.stack([mix, mix], 1))


# ---------------------------------------------------------------- video
TL = None
STARTS = None
EVENTS = None


def setup(voice_dir):
    global TL, STARTS, EVENTS
    durs = {}
    voices = {}
    for k in LINES:
        voices[k] = voice(voice_dir, k)
        durs[k] = len(voices[k]) / A.SR
    TL = timeline()
    total = layout(TL, durs)
    STARTS = [sc.t0 for sc in TL]
    EVENTS = {"glitch": [], "static": [], "freeze": []}
    for sc in TL:
        for t, d, s, *_ in sc.glitch:
            EVENTS["glitch"].append((sc.t0 + sc.at(t), d, s))
        for t, d, s, *_ in sc.static:
            EVENTS["static"].append((sc.t0 + sc.at(t), d, s))
        for t, d in sc.freeze:
            EVENTS["freeze"].append((sc.t0 + sc.at(t), d))
    return total, voices


def fx_at(gt):
    glitch = static = 0.0
    for t0, d, s in EVENTS["glitch"]:
        if t0 <= gt < t0 + d:
            glitch = max(glitch, s)
    for t0, d, s in EVENTS["static"]:
        if t0 <= gt < t0 + d:
            static = max(static, s)
    return glitch, static


def draw_frame(gt):
    for t0, d in EVENTS["freeze"]:
        if t0 <= gt < t0 + d:
            gt = t0
    i = max(0, bisect.bisect_right(STARTS, gt) - 1)
    sc = TL[i]
    c = gfx.Canvas()
    sc.draw(c, gt - sc.t0, sc)
    if 0.9 <= gt < 6.0:
        S.osd(c, "PLAY \u25b6")
    return c.finish()


def render(fi):
    gt = fi / FPS
    g, st = fx_at(gt)
    return vhs(draw_frame(gt), gt, fi, g, st).tobytes()


def srt(tl, path):
    def ts(t):
        ms = int(round(t * 1000))
        return f"{ms // 3600000:02d}:{ms // 60000 % 60:02d}:{ms // 1000 % 60:02d},{ms % 1000:03d}"
    items = []
    for sc in tl:
        for k, t in sc.m.items():
            if k in LINES:
                items.append((sc.t0 + t, sc.t0 + sc.e[k], SUBS.get(k, LINES[k])))
    items.sort()
    with open(path, "w") as f:
        for i, (a, b, s) in enumerate(items, 1):
            f.write(f"{i}\n{ts(a)} --> {ts(b)}\n{s}\n\n")


def write_layout(tl, total, path):
    import json
    json.dump({"fps": FPS, "total": total, "scenes": [[s.name, s.t0, s.dur] for s in tl]}, open(path, "w"), indent=1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("voice_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--stills", default="")
    ap.add_argument("--no-video", action="store_true")
    ap.add_argument("--no-audio", action="store_true")
    ap.add_argument("--size", default="960x720")
    ap.add_argument("--crf", default="24")
    ap.add_argument("--jobs", type=int, default=os.cpu_count())
    a = ap.parse_args()
    os.makedirs(a.out_dir, exist_ok=True)
    total, voices = setup(a.voice_dir)
    clips = creature_clips()
    S.ENVS.update({k: envelope(v) for k, v in clips.items()})
    print(f"length {total:.1f} s, {int(total * FPS)} frames")
    for sc in TL:
        print(f"  {sc.t0:7.2f}  {sc.name:12s} {sc.dur:5.2f}")
    if a.stills:
        from PIL import Image
        for s in a.stills.split(","):
            gt = float(s)
            fi = int(gt * FPS)
            g, st = fx_at(gt)
            Image.fromarray(vhs(draw_frame(gt), gt, fi, g, st)).save(f"{a.out_dir}/still_{gt:07.2f}.png")
            Image.fromarray(draw_frame(gt)).save(f"{a.out_dir}/clean_{gt:07.2f}.png")
        return
    srt(TL, f"{a.out_dir}/falcon_tape.srt")
    write_layout(TL, total, f"{a.out_dir}/layout.json")
    wav = f"{a.out_dir}/falcon_tape_audio.wav"
    if not a.no_audio:
        build_audio(TL, total, voices, clips, wav)
        print("audio done")
    if a.no_video:
        return
    vid = f"{a.out_dir}/falcon_tape_video.mp4"
    n = int(total * FPS)
    w, h = a.size.split("x")
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "640x480", "-r", str(FPS),
                            "-i", "-", "-vf", f"scale={w}:{h}:flags=bicubic,setsar=1", "-c:v", "libx264", "-preset", "slow",
                            "-crf", a.crf, "-pix_fmt", "yuv420p", vid], stdin=subprocess.PIPE)
    with mp.get_context("fork").Pool(a.jobs) as pool:
        for i, fr in enumerate(pool.imap(render, range(n), chunksize=8)):
            enc.stdin.write(fr)
            if i % 900 == 0:
                print(f"frame {i}/{n}", flush=True)
    enc.stdin.close()
    enc.wait()
    out = f"{a.out_dir}/falcon_tape.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", vid, "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
                    "-shortest", "-movflags", "+faststart", out], check=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
