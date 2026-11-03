# Builds "Water Safety and You", the F.A.L.C.O.N. orientation tape about the Wader.
#   python3 tape.py <voice_dir> <out_dir> [--stills 12.5,40] [--no-video] [--no-audio] [--size 960x720]
# voice_dir holds Microsoft Sam's lines from fetch_voice.py. Writes out_dir/falcon_tape.mp4 (and .srt).
import argparse, bisect, math, multiprocessing as mp, os, subprocess, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gfx, scenes as S, sound as A
from narration import LINES, SUBS
from vhs import vhs

FPS = 30
SLOWED = {"hear": 0.78}   # lines played slower and lower


# ---------------------------------------------------------------- timeline
def L(key, pad=0.45):
    return ("line", key, pad)


def P(sec):
    return ("pause", sec)


def M(name):
    return ("mark", name)


class Scene:
    def __init__(self, name, draw, beats, beds=None, sfx=None, glitch=None, static=None, freeze=None):
        self.name, self.draw, self.beats = name, draw, beats
        self.beds = beds or []
        self.sfx = sfx or []
        self.glitch = glitch or []
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


def card(n, name, key):
    return Scene(f"card{n}", S.section_card(n, name), [P(0.45), L(key, 1.0)], sfx=[(0.0, "chime_section", 0.55)])


def timeline():
    return [
        Scene("vcr", S.vcr, [P(3.2)], static=[(0, 0.6, 1.0), (2.75, 0.45, 1.0)]),
        Scene("warning", S.warning, [P(1.0), L("warn1", 0.7), L("warn2", 1.6), L("warn3", 1.5)]),
        Scene("logo", S.logo, [P(2.9), L("pres", 1.3)], beds=[(0, "corp")], sfx=[(0.25, "chime_logo", 0.7)]),
        Scene("title", S.title, [P(0.7), L("title", 0.9), L("sub", 2.4)], beds=[(0, "corp")],
              glitch=[("e:sub+1.6", 0.25, 0.45)]),
        card(1, "THE POOLROOMS", "s1"),
        Scene("poolrooms", S.poolrooms, [P(0.5), L("pr1", 0.5), L("pr2", 0.7), L("pr3", 0.5), L("pr4", 2.4), L("pr5", 2.8)],
              beds=[(0, "corp+halls"), ("pr4", "halls"), ("pr4+2.6", "eerie")],
              sfx=[*[(f"pr4+{0.4 + k * 0.35:.2f}", "relay", 0.35) for k in range(8)],
                   ("pr5+0.85", "buzz:0.08", 0.4), ("pr5+1.02", "buzz:0.22", 0.4), ("pr5+1.0", "click_close", 0.9)],
              glitch=[("pr5+1.0", 0.25, 0.3)]),
        card(2, "IDENTIFICATION", "s2"),
        Scene("ident", S.ident, [P(0.6), L("id1", 0.8), L("id2", 0.6), L("id3", 0.6), L("id4", 1.6)],
              beds=[(0, "corp"), ("id1", "eerie")],
              sfx=[("e:id4+0.25", "subliminal", 0.4)], glitch=[("e:id4+0.2", 0.2, 0.7)]),
        Scene("dry", S.dry, [P(0.4), L("id5", 1.8)], beds=[(0, "corp")], sfx=[(0.3, "wade:3.2", 0.25)]),
        card(3, "HOW IT HEARS", "s3"),
        Scene("hear", S.hear, [P(0.4), L("hr1", 0.5), L("hr2", 0.5), L("hr3", 1.4)], beds=[(0, "corp")],
              sfx=[(0.0, "wade:12", 0.22)]),
        Scene("noise", S.noise_chart, [P(0.3), L("hr4", 0.9), L("hr5", 0.9), L("hr6", 0.9), L("hr7", 1.4)], beds=[(0, "corp")],
              sfx=[("hr5+0.2", "wade:2.0", 0.18), ("hr6+0.2", "wadefast:2.0", 0.45), ("hr7+0.2", "hands:2.0", 0.35)]),
        Scene("investigate", S.investigate, [P(0.4), L("hr8", 2.0)], beds=[(0, "corp")],
              sfx=[(0.8, "plop", 1.5), (1.4, "wade:3.0", 0.25)]),
        card(4, "FALLING IN", "s4"),
        Scene("fall", S.fall, [P(0.3), L("fa1", 1.5), L("fa2", 2.4)], beds=[(0, "corp"), ("e:fa2-1.3", "eerie")],
              sfx=[("fa1+2.0", "splash_big", 1.2), ("e:fa2-1.3", "charge_onset", 0.45)],
              glitch=[("e:fa2-1.3", 0.25, 0.35)]),
        Scene("speed", S.speed, [P(0.3), L("fa3", 1.6)], beds=[(0, "eerie")]),
        Scene("climb", S.climb_out, [P(0.3), L("fa4", 0.6), L("fa5", 2.6)], beds=[(0, "corp"), ("fa5+1.0", "eerie")],
              sfx=[("fa4+0.6", "wade:1.4", 0.35)]),
        card(5, "STILLNESS PROTOCOL", "s5"),
        Scene("search", S.still_search, [P(0.3), L("st1", 0.6), L("st2", 3.0)], beds=[(0, "eerie")],
              sfx=[("st2", "wade:2.6", 0.25), ("st2+2.6", "close:5.0", 0.35)]),
        Scene("dontmove", S.dont_move, [P(0.3), L("st3", 1.4)], beds=[(0, "eerie")]),
        Scene("odds", S.odds, [P(0.3), L("st4", 1.2), L("st5", 2.6)], beds=[(0, "corp"), ("st5-0.3", "none")],
              sfx=[("st5", "boom", 0.5), ("e:st5+0.15", "stutter", 1.0), ("e:st5+1.35", "subliminal", 0.4)],
              glitch=[("e:st5+0.15", 1.2, 0.35), ("e:st5+1.3", 0.2, 0.8)], freeze=[("e:st5+0.15", 1.1)]),
        card(6, "WARNING SIGNS", "s6"),
        Scene("wake", S.wake, [P(0.4), L("ws1", 1.2)], beds=[(0, "eerie")], sfx=[(0.0, "bubbles", 1.2)]),
        Scene("signs", S.signs, [P(0.3), L("ws2", 0.2), M("snd_wander"), P(2.8), L("ws3", 0.2), M("snd_hunt"), P(3.0),
                                 L("ws4", 0.2), M("snd_close"), P(3.0), L("ws5", 0.3), M("snd_charge"), P(4.9)],
              sfx=[("snd_wander", "clip:wander", 1.2), ("snd_hunt", "clip:hunt", 1.1), ("snd_close", "clip:close", 1.1),
                   ("snd_charge", "clip:charge", 0.5)], glitch=[("snd_charge+2.4", 0.3, 0.4)]),
        Scene("waits", S.waits, [P(0.4), L("ws6", 2.0)], beds=[(0, "eerie")], sfx=[(0.0, "wade:6", 0.2)]),
        card(7, "EQUIPMENT", "s7"),
        Scene("decoy", S.decoy, [P(0.3), L("eq1", 1.6)], beds=[(0, "corp")],
              sfx=[("eq1+0.8", "whoosh", 0.5), ("eq1+1.9", "splash_small", 0.7), ("eq1+2.3", "wade:1.7", 0.3)]),
        Scene("lidar", S.lidar, [P(0.3), L("eq2", 0.6), L("eq3", 0.8), L("eq4", 1.8)], beds=[(0, "eerie")],
              sfx=[("eq2+0.8", "whir", 0.35), ("eq4+0.2", "whir", 0.35), ("e:eq4-0.9", "buzz:0.13", 0.45),
                   ("e:eq4-0.9", "click_close", 0.9)], glitch=[("e:eq4-0.95", 0.25, 0.6)]),
        Scene("generator", S.generator_scene, [P(0.3), L("eq5", 0.7), L("eq6", 2.0)], beds=[(0, "corp")],
              sfx=[("eq5+2.4", "pour:0.8", 0.35), ("eq5+4.9", "pour:0.8", 0.35), (gen_time, "gen_start", 0.45),
                   ("eq6", "wade:5", 0.2)]),
        card(8, "CASUALTY PROCEDURE", "s8"),
        Scene("taken", S.taken, [P(0.3), L("ca1", 0.9), L("ca2", 1.0), L("ca3", 1.8)], beds=[(0, "drone")],
              sfx=[("ca1+0.4", "screech_far", 0.35), ("ca1+0.7", "splash_big", 0.9), ("ca1+1.4", "chew", 0.28),
                   ("ca2+1.5", "chew", 0.28), ("ca2+3.5", "chew", 0.25)]),
        Scene("bag", S.bag_scene, [P(0.3), L("ca4", 1.2)], beds=[(0, "drone")]),
        Scene("returning", S.returning, [P(0.3), L("ca5", 1.8)], beds=[(0, "drone")], sfx=[("ca5+1.2", "drips:6", 0.25)]),
        Scene("ask", S.ask, [P(0.4), L("ca6", 2.4)], beds=[(0, "drone")], glitch=[("ca6", 0.18, 0.5)]),
        Scene("summary", S.summary, [P(0.5), L("rm0", 0.5), L("rm1", 0.6), L("rm2", 0.6), L("rm3", 0.9), L("rm4", 0.3)],
              beds=[(0, "corp"), ("rm4", "none")],
              sfx=[("rm1", "point:72", 0.5), ("rm2", "point:76", 0.5), ("rm3", "point:79", 0.5)]),
        Scene("fallin", S.fall_in, [P(0.25), L("rm5", 2.2)], glitch=[(0, 0.35, 0.9)],
              sfx=[(0.0, "static:0.3", 0.5), ("rm5", "boom", 0.6)]),
        Scene("outro", S.outro, [P(0.5), L("end", 3.6)], beds=[(0, "corp")], sfx=[(0.2, "chime_logo", 0.6)]),
        Scene("blank", S.blank, [P(2.4)], glitch=[(2.15, 0.25, 0.5)]),
        Scene("stinger", S.stinger, [P(3.8), L("hear", 0.35), M("scare"), P(0.8), M("static"), P(1.5), M("stop"), P(1.6), P(0.9)],
              beds=[(0, "none")],
              sfx=[*[(0.5 + k / 15, "type", 0.7) for k in range(34) if "THE HUMAN BODY IS ABOUT 60% WATER."[k] != " "],
                   ("scare", "screech", 0.6), ("static", "static:1.5", 0.55)],
              glitch=[("scare", 0.8, 1.0)], static=[("static", 1.5, 1.0)]),
    ]


def gen_time(sc):
    return min(sc.m["eq5"] + 5.9, sc.m["eq6"] - 0.1)


def layout(tl, durs):
    t = 0.0
    for sc in tl:
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
    x = np.tanh(A.norm(x, 1.0) * 1.4) / np.tanh(1.4) * 0.72
    if key in SLOWED:
        x = A.resample(x, SLOWED[key])
        x = A.filt(x, 80, 4000)
        x = A.reverb(x, 2.6, 0.45, lo=100, hi=3000)
        x = A.norm(x, 0.8)
    return x


def loop_to(x, n):
    return np.tile(x, n // len(x) + 1)[:n]


def creature_clips():
    hunt = A.game("creature_hunt")
    close = A.game("creature_close")
    charge = A.game("creature_charge")
    n = int(2.6 * A.SR)
    gate = np.zeros(n)
    for a, b in ((0.15, 0.75), (1.55, 2.05)):
        gate[int(a * A.SR):int(b * A.SR)] = 1
    gate = np.convolve(gate, np.ones(400) / 400, "same")
    wander = hunt[:n] * gate * 0.9 + loop_to(A.game("wade_loop"), n) * 0.25
    return {"wander": wander, "hunt": hunt[int(3 * A.SR):int(5.8 * A.SR)],
            "close": close[:int(2.8 * A.SR)], "charge": charge}


def envelope(x, rate=100):
    hop = A.SR // rate
    n = len(x) // hop
    e = np.sqrt(np.mean(x[:n * hop].reshape(n, hop) ** 2, axis=1))
    return e / (e.max() + 1e-9)


class Sfx:
    def __init__(self, clips):
        self.clips = clips
        self.cache = {}

    def get(self, name):
        if name in self.cache:
            return self.cache[name]
        base, _, arg = name.partition(":")
        g = A.game
        if base == "chime_logo":
            x = A.chime_logo()
        elif base == "chime_section":
            x = A.chime_section()
        elif base == "point":
            x = A.chime_point(int(arg))
        elif base == "relay":
            x = A.relay_click()
        elif base == "buzz":
            x = A.hum_buzz(float(arg))
        elif base == "click_close":
            x = g("creature_close")[int(0.4 * A.SR):int(1.2 * A.SR)] * A.env(int(0.8 * A.SR), 0.01, 0.2)
        elif base == "subliminal":
            x = A.static_burst(0.1) * 0.6
            s = g("kill_screech_3")[:int(0.16 * A.SR)]
            x = np.concatenate([x, np.zeros(len(s) - len(x))]) + s if len(s) > len(x) else x
        elif base in ("wade", "wadefast"):
            w = g("wade_loop")
            if base == "wadefast":
                w = A.resample(w, 1.5)
            n = int(float(arg) * A.SR)
            x = loop_to(w, n) * A.env(n, 0.3, 0.4) * 2.5
        elif base == "hands":
            n = int(float(arg) * A.SR)
            x = loop_to(g("pour_loop"), n) * A.env(n, 0.1, 0.3) * 0.6 + loop_to(A.resample(g("wade_loop"), 2.0), n) * 0.4
        elif base == "pour":
            n = int(float(arg) * A.SR)
            x = loop_to(g("pour_loop"), n) * A.env(n, 0.05, 0.2)
        elif base == "close":
            n = int(float(arg) * A.SR)
            x = loop_to(g("creature_close"), n) * A.env(n, 0.3, 0.6)
        elif base == "clip":
            x = self.clips[arg]
        elif base == "whir":
            x = g("flashlight_whir")[:int(1.6 * A.SR)]
            x = x * A.env(len(x), 0.05, 0.3)
        elif base == "gen_start":
            st, hum = g("generator_start"), g("generator_hum")
            x = np.concatenate([st[:int(3.0 * A.SR)] * A.env(int(3.0 * A.SR), 0.01, 0.5),
                                loop_to(hum, int(9 * A.SR)) * A.env(int(9 * A.SR), 0.5, 1.5)])
        elif base == "bubbles":
            rng = np.random.default_rng(9)
            x = np.zeros(int(9 * A.SR))
            p = A.resample(g("plop"), 2.2)
            for k in range(26):
                A.place(x, p, rng.uniform(0, 8.5), rng.uniform(0.1, 0.4))
        elif base == "drips":
            x = np.zeros(int(float(arg) * A.SR))
            p = A.resample(g("plop"), 1.6)
            for k in range(int(float(arg) / 0.9)):
                A.place(x, p, k * 0.9 + 0.1 * (k % 3), 0.5)
        elif base == "screech_far":
            x = A.filt(g("kill_screech_1"), None, 1500)
        elif base == "chew":
            x = A.filt(np.concatenate([g("feed_chew_1"), g("feed_chew_2")]), None, 1800)
        elif base == "screech":
            x = A.norm(g("kill_screech_3"), 1.0)
        elif base == "static":
            x = A.static_burst(float(arg))
        elif base == "boom":
            x = A.boom()
        elif base == "whoosh":
            x = A.whoosh()
        elif base == "type":
            x = A.typewriter()
        else:
            x = g(base)
        self.cache[name] = x
        return x


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
    gains = {"corp": 0.6, "eerie": 0.5, "drone": 0.3, "halls": 0.9}
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
    duck = 1 - 0.35 * np.clip(voice_env * 1.5, 0, 1)
    tt = np.arange(n) / A.SR
    ct = np.arange(ctl_n) / rate
    beds = np.zeros(n)
    srcs = {"corp": lambda: A.corporate_bed(total + 1),
            "eerie": lambda: loop_to(A.norm(A.game("music_under_surface"), 0.6), n),
            "drone": lambda: A.drone(total + 1),
            "halls": lambda: loop_to(A.norm(A.game("amb_halls"), 0.6), n)}
    for b, c in ctl.items():
        if c.any():
            g = np.convolve(c, k, "same") * gains[b] * duck
            src = srcs[b]()[:n]
            beds[:len(src)] += src * np.interp(tt[:len(src)], ct, g)
    mix = narr + fx + beds
    # tape trouble: glitches dip the sound and add noise; static replaces it
    trouble = np.zeros(ctl_n)
    noise_amt = np.zeros(ctl_n)
    for sc in tl:
        for t, d, s in sc.glitch:
            a = int((sc.t0 + sc.at(t)) * rate)
            trouble[a:a + int(d * rate)] = np.maximum(trouble[a:a + int(d * rate)], 0.55 * s)
            noise_amt[a:a + int(d * rate)] = np.maximum(noise_amt[a:a + int(d * rate)], 0.12 * s)
        for t, d, s in sc.static:
            a = int((sc.t0 + sc.at(t)) * rate)
            trouble[a:a + int(d * rate)] = np.maximum(trouble[a:a + int(d * rate)], 0.85 * s)
            noise_amt[a:a + int(d * rate)] = np.maximum(noise_amt[a:a + int(d * rate)], 0.35 * s)
    mix *= 1 - np.interp(tt, ct, trouble)
    mix += A.static_burst(total + 1, seed=31)[:n] * np.interp(tt, ct, noise_amt)
    mix = A.tape(mix)
    mix = mix / (np.abs(mix).max() + 1e-9) * 0.89
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
        for t, d, s in sc.glitch:
            EVENTS["glitch"].append((sc.t0 + sc.at(t), d, s))
        for t, d, s in sc.static:
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
        S.osd(c, "PLAY")
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
