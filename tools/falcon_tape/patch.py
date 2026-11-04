# Re-renders only part of an already built tape and splices it back in, instead of rendering
# the whole video again. The frames from the keyframe before --from to the keyframe after --to
# are rendered and encoded; everything else is copied from the existing video untouched, and
# the existing sound is kept (use this only when the sound did not change).
#   python3 patch.py <voice_dir> <out_dir> --from 104.0 --to 107.7
# out_dir is where tape.py wrote falcon_tape_video.mp4 and falcon_tape_audio.wav; this rewrites
# falcon_tape_video.mp4 (the previous one is kept as falcon_tape_video_prev.mp4) and falcon_tape.mp4.
import argparse, multiprocessing as mp, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scenes as S
import tape


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def keyframes(video):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v", "-skip_frame", "nokey",
                          "-show_entries", "frame=pts_time", "-of", "csv=p=0", video],
                         capture_output=True, text=True, check=True).stdout
    return [float(x.strip().rstrip(",")) for x in out.split() if x.strip().rstrip(",")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("voice_dir")
    ap.add_argument("out_dir")
    ap.add_argument("--from", dest="t0", type=float, required=True)
    ap.add_argument("--to", dest="t1", type=float, required=True)
    ap.add_argument("--size", default="960x720")
    ap.add_argument("--crf", default="23")
    a = ap.parse_args()
    vid = f"{a.out_dir}/falcon_tape_video.mp4"
    wav = f"{a.out_dir}/falcon_tape_audio.wav"
    total, voices = tape.setup(a.voice_dir)
    S.ENVS.update({k: tape.envelope(v) for k, v in tape.creature_clips().items()})
    n = int(total * tape.FPS)
    keys = keyframes(vid)
    k0 = max(k for k in keys if k <= a.t0 + 1e-6)
    later = [k for k in keys if k >= a.t1 - 1e-6]
    f0 = round(k0 * tape.FPS)
    f1 = round(later[0] * tape.FPS) if later else n
    print(f"re-rendering frames {f0}-{f1} ({(f1 - f0) / tape.FPS:.1f} s) of {n}")

    tmp = f"{a.out_dir}/patch_tmp"
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)
    w, h = a.size.split("x")
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "640x480",
                            "-r", str(tape.FPS), "-i", "-", "-vf", f"scale={w}:{h}:flags=bicubic,setsar=1",
                            "-c:v", "libx264", "-preset", "slow", "-crf", a.crf, "-pix_fmt", "yuv420p",
                            "-f", "mpegts", f"{tmp}/mid.ts"], stdin=subprocess.PIPE)
    with mp.get_context("fork").Pool(os.cpu_count()) as pool:
        for fr in pool.imap(tape.render, range(f0, f1), chunksize=4):
            enc.stdin.write(fr)
    enc.stdin.close()
    enc.wait()

    # The untouched parts, cut exactly at keyframes and kept with their own timestamps.
    parts = []
    if f0 > 0:
        run("ffmpeg", "-v", "error", "-y", "-i", vid, "-frames:v", str(f0), "-c:v", "copy", "-an",
            "-f", "mpegts", f"{tmp}/head.ts")
        parts.append(f"{tmp}/head.ts")
    parts.append(f"{tmp}/mid.ts")
    if f1 < n:
        run("ffmpeg", "-v", "error", "-y", "-ss", f"{f1 / tape.FPS:.6f}", "-i", vid, "-c:v", "copy", "-an",
            "-f", "mpegts", f"{tmp}/tail.ts")
        parts.append(f"{tmp}/tail.ts")
    with open(f"{tmp}/list.txt", "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)

    shutil.copy(vid, f"{a.out_dir}/falcon_tape_video_prev.mp4")
    run("ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", f"{tmp}/list.txt", "-c:v", "copy",
        "-movflags", "+faststart", vid)
    got = int(subprocess.run(["ffprobe", "-v", "error", "-count_packets", "-select_streams", "v", "-show_entries",
                              "stream=nb_read_packets", "-of", "csv=p=0", vid], capture_output=True, text=True).stdout)
    print(f"frames: {got} (expected {n})")
    run("ffmpeg", "-v", "error", "-y", "-i", vid, "-i", wav, "-c:v", "copy", "-c:a", "aac", "-b:a", "160k",
        "-shortest", "-movflags", "+faststart", f"{a.out_dir}/falcon_tape.mp4")
    shutil.rmtree(tmp, ignore_errors=True)
    print("wrote", f"{a.out_dir}/falcon_tape.mp4")


if __name__ == "__main__":
    main()
