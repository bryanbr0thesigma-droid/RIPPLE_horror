# Builds "Going In, Coming Out", F.A.L.C.O.N. orientation tape 08-E (entry and exit procedures for
# the poolrooms), with the same renderer, mix and tape look as tape.py.
#   python3 tape08.py <voice_dir> <out_dir> [--stills 12.5,40] [--no-video] [--no-audio] [--size 960x720]
# voice_dir holds Microsoft Sam's lines: python3 fetch_voice.py <voice_dir> narration08
# Writes out_dir/falcon_tape_08.mp4 (and .srt).
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gfx
gfx.TAPE_ID = "08-E"
import narration08, scenes as S, scenes08 as E, tape
from tape import Scene, L, P, M

tape.LINES, tape.SUBS = narration08.LINES, narration08.SUBS
tape.NAME = "falcon_tape_08"


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
        Scene("title", E.title, [P(0.6), L("title8", 2.4)], beds=[(0, "corp")], glitch=[("e:title8+1.7", 0.25, 0.45)]),
        card(1, "BEFORE ENTRY"),
        Scene("reception", E.reception, [P(0.4), L("signin", 0.5), L("timein", 1.4)], beds=[(0, "corp")]),
        Scene("kit", E.kit, [P(0.3), L("kit", 2.0)], beds=[(0, "corp")]),
        Scene("alone", E.alone, [P(0.3), L("alone", 1.8)], beds=[(0, "corp")]),
        card(2, "GOING IN"),
        Scene("haveto", E.have_to, [P(0.4), L("haveto", 1.8)], beds=[(0, "eerie")]),
        Scene("range", E.range_check, [P(0.3), L("km", 0.3), M("scan"), P(3.0), M("clear"), P(1.6)],
              beds=[(0, "corp")], sfx=[(f"scan+{k * 0.6:.1f}", "pop", 0.25) for k in range(5)] + [("clear", "ding", 0.4)]),
        Scene("walk", E.walk_wet, [P(0.3), L("walk", 1.8)], beds=[(0, "corp")], sfx=[(0.6, "drips:2.4", 0.3)]),
        Scene("ladder", E.ladder, [P(0.3), L("ladder", 0.2), L("slowly", 1.6), L("jump", 1.8)], beds=[(0, "corp")],
              sfx=[("e:slowly+0.2", "wade:1.2", 0.3)]),
        Scene("mark", E.mark, [P(0.3), L("mark", 1.0), L("partner", 1.8)], beds=[(0, "corp+halls")],
              sfx=[(0.2, "wade:6", 0.3)]),
        card(3, "COMING OUT"),
        Scene("comeout", E.come_out, [P(0.3), L("way", 1.8), L("climb", 2.0), L("dryoff", 1.8), L("noleave", 2.2)],
              beds=[(0, "corp")], sfx=[("way", "wade:2.2", 0.3), ("dryoff+0.4", "drips:2.4", 0.35)]),
        card(4, "THE HEADCOUNT"),
        Scene("count", E.headcount, [P(0.3), L("count", 0.3), M("c1"), P(2.0), L("again", 0.3), M("c2"), P(2.0),
                                     L("same", 0.4), M("ok"), P(0.9), L("lower", 2.4)],
              beds=[(0, "corp"), ("lower", "eerie")]),
        Scene("higher", E.higher, [P(0.4), M("c3"), P(3.4), L("higher", 1.6), L("donttell", 1.8)],
              beds=[(0, "eerie")], sfx=[("c3+2.45", "drips:4", 0.35)],
              glitch=[("c3+2.4", 0.2, 0.5), ("donttell", 0.25, 0.4)]),
        Scene("normally", E.walk_on, [P(0.3), L("normal", 0.8), L("super", 2.0)], beds=[(0, "eerie")],
              sfx=[(0.2, "drips:5", 0.3)]),
        card(5, "SIGN OUT"),
        Scene("signout", E.sign_out, [P(0.3), L("signout", 0.9), L("inside", 2.2)], beds=[(0, "corp")]),
        Scene("summary", E.summary, [P(0.5), L("rm0", 0.5), L("rm1", 0.5), L("rm2", 0.5), L("rm3", 0.5), L("rm4", 0.5),
                                     L("rm5", 1.6)], beds=[(0, "corp")]),
        Scene("outro", E.outro, [P(0.5), L("end", 3.4)], beds=[(0, "corp")], sfx=[(0.2, "jingle", 0.5)]),
        Scene("blank", S.blank, [P(2.2)], glitch=[(1.95, 0.25, 0.5)]),
        Scene("end", E.tape_end, [P(0.8), M("static"), P(1.4), M("stop"), P(1.6), P(0.8)],
              beds=[(0, "none")], sfx=[("static", "static:1.4", 0.6)], static=[("static", 1.4, 1.0)]),
    ]


tape.timeline = timeline

if __name__ == "__main__":
    tape.main()
