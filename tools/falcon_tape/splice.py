# Builds a new version of the tape from an old one without rendering it all again: scenes that
# did not change are copied from the old video (moved to their new place if scenes before them
# changed length), and only the changed scenes, plus the few frames out to the old video's
# nearest keyframes, are rendered. The sound is always rebuilt (it is quick).
#   python3 splice.py <voice_dir> <old_dir> <new_dir> --changed falling,landed,demo,taken
# old_dir holds falcon_tape_video.mp4 and layout.json from an earlier build; scenes that are new
# or have a different length count as changed by themselves.
import argparse, json, multiprocessing as mp, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scenes as S
import tape


def keyframes(video, fps):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-skip_frame", "nokey",
                          "-show_entries", "frame=pts_time", "-of", "csv=p=0", video],
                         capture_output=True, text=True, check=True).stdout
    return sorted({round(float(x.strip().rstrip(",")) * fps) for x in out.split() if x.strip().rstrip(",")})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("voice_dir")
    ap.add_argument("old_dir")
    ap.add_argument("new_dir")
    ap.add_argument("--changed", default="")
    ap.add_argument("--size", default="960x720")
    ap.add_argument("--crf", default="23")
    a = ap.parse_args()
    fps = tape.FPS
    old_vid = f"{a.old_dir}/falcon_tape_video.mp4"
    old = json.load(open(f"{a.old_dir}/layout.json"))
    old_sc = {name: (t0, dur) for name, t0, dur in old["scenes"]}
    old_n = int(old["total"] * fps)
    os.makedirs(a.new_dir, exist_ok=True)

    total, voices = tape.setup(a.voice_dir)
    clips = tape.creature_clips()
    S.ENVS.update({k: tape.envelope(v) for k, v in clips.items()})
    n = int(total * fps)
    changed = set(x for x in a.changed.split(",") if x)

    # For each new frame: the old frame it can be copied from, or None.
    src = [None] * n
    for sc in tape.TL:
        if sc.name in changed or sc.name not in old_sc or abs(old_sc[sc.name][1] - sc.dur) > 1e-6:
            continue
        shift = (old_sc[sc.name][0] - sc.t0) * fps
        if abs(shift - round(shift)) > 1e-3:
            continue                                # not a whole number of frames: render it
        f0, f1 = int(round(sc.t0 * fps + 0.4999)), int(round((sc.t0 + sc.dur) * fps + 0.4999))
        for fi in range(max(0, f0), min(n, f1)):
            of = fi + round(shift)
            if 0 <= of < old_n:
                src[fi] = of
    keys = keyframes(old_vid, fps)

    # Runs of copyable frames, trimmed to keyframes; everything else is rendered.
    segs = []                                       # ("copy", old_start, count) / ("render", new_start, count)
    fi = 0
    while fi < n:
        if src[fi] is None:
            j = fi
            while j < n and src[j] is None:
                j += 1
            segs.append(["render", fi, j - fi])
            fi = j
            continue
        j = fi
        while j + 1 < n and src[j + 1] is not None and src[j + 1] == src[j] + 1:
            j += 1
        oa, ob = src[fi], src[j] + 1
        k0 = next((k for k in keys if k >= oa), None)
        k1 = max([k for k in keys if k <= ob] + ([old_n] if ob == old_n else []), default=None)
        if k0 is not None and k1 is not None and k0 < k1:
            if k0 > oa:
                segs.append(["render", fi, k0 - oa])
            segs.append(["copy", k0, k1 - k0])
            if ob > k1:
                segs.append(["render", fi + (k1 - oa), ob - k1])
        else:
            segs.append(["render", fi, j + 1 - fi])
        fi = j + 1
    rendered = sum(s[2] for s in segs if s[0] == "render")
    print(f"{n} frames: rendering {rendered} ({rendered / fps:.1f} s), copying {n - rendered}")

    tmp = f"{a.new_dir}/splice_tmp"
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    w, h = a.size.split("x")
    files = []
    with mp.get_context("fork").Pool(os.cpu_count()) as pool:
        for i, (kind, start, count) in enumerate(segs):
            path = f"{tmp}/{i:03d}.ts"
            if kind == "copy":
                subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{start / fps:.6f}", "-i", old_vid,
                                "-frames:v", str(count), "-c:v", "copy", "-an", "-f", "mpegts", path], check=True)
            else:
                enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24",
                                        "-s", "640x480", "-r", str(fps), "-i", "-",
                                        "-vf", f"scale={w}:{h}:flags=bicubic,setsar=1", "-c:v", "libx264",
                                        "-preset", "slow", "-crf", a.crf, "-pix_fmt", "yuv420p", "-f", "mpegts", path],
                                       stdin=subprocess.PIPE)
                for fr in pool.imap(tape.render, range(start, start + count), chunksize=4):
                    enc.stdin.write(fr)
                enc.stdin.close()
                enc.wait()
            files.append(path)
    with open(f"{tmp}/list.txt", "w") as f:
        f.writelines(f"file '{p}'\n" for p in files)
    vid = f"{a.new_dir}/falcon_tape_video.mp4"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", f"{tmp}/list.txt",
                    "-c:v", "copy", "-movflags", "+faststart", vid], check=True)
    got = int(subprocess.run(["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v", "-show_entries",
                              "stream=nb_read_packets", "-of", "csv=p=0", vid], capture_output=True, text=True).stdout)
    print(f"frames: {got} (expected {n})")

    wav = f"{a.new_dir}/falcon_tape_audio.wav"
    tape.build_audio(tape.TL, total, voices, clips, wav)
    tape.srt(tape.TL, f"{a.new_dir}/falcon_tape.srt")
    tape.write_layout(tape.TL, total, f"{a.new_dir}/layout.json")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", vid, "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
                    "-shortest", "-movflags", "+faststart", f"{a.new_dir}/falcon_tape.mp4"], check=True)
    shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", f"{a.new_dir}/falcon_tape.mp4")


if __name__ == "__main__":
    main()
