# F.A.L.C.O.N. orientation tape

"Water Safety and You": a 3-minute analogue-horror training video about the Wader, made as a 1991
VHS tape from the Federal Agency for Liminal Classification & Occult Nature and narrated by
Microsoft Sam. It hints at the game's rules in-world without giving too much away: the Wader hunts
by sound, dry ground is safe, don't fall in, stand still, listen for it, and don't go in after
someone who's taken. It never says what happens to them: in its demonstration of the stillness
protocol the agent flinches and the tape cuts to a "please stand by" card, with only a few
half-second glimpses getting through.

The finished video is `media/falcon_tape.mp4` (960x720, 4:3) with subtitles in
`media/falcon_tape.srt`. For the game there is `game/assets/video/falcon_tape.ogv` (640x480, the tape's
own resolution, Ogg Theora: the only video format Godot 4 plays on its own), about 29 MB, with
the same subtitles next to it. To remake it from a build:

```
ffmpeg -i out/falcon_tape.mp4 -i out/falcon_tape_audio.wav -map 0:v -map 1:a -vf scale=640:480:flags=lanczos \
  -c:v libtheora -q:v 6 -c:a libvorbis -q:a 3 -ac 1 -shortest game/assets/video/falcon_tape.ogv
```

The cassette's labels are in `media/labels/`: `label_top.png` for the face of the cassette
(78 x 46 mm) and `label_spine.png` for the spine (146 x 19 mm), both drawn by `labels.py`. Print
them at those sizes.

## What's in it

- **The Wader:** silhouettes rendered from the game's own creature model (`silhouettes/`), the
  only artwork made for the tape.
- **Existing human-made work** (public domain or CC0, listed in `assets/CREDITS.md`): ISO 7010
  safety signs (rebuilt into the tape's own signs by `build_signs.py`, with water added), road-sign
  stick figures from Openclipart, a falcon engraving from Openclipart for the seal (its rock removed), CC0 static from OpenGameArt,
  and the game's own recordings (creature voice, splashes, wading, drips, room tone, music).
- **Made by the scripts:** text (in existing fonts), the simulated water of the side
  cross-sections, the training-video music and logo jingle (`music.py`), and the VHS tape effect
  (`vhs.py`).
- **Narration:** Microsoft Sam (SAPI 4), a 1990s rule-based speech synthesizer.

## Files

- `narration.py`: every line Sam reads, with subtitle text where it differs.
- `fetch_voice.py`: downloads each line read by Microsoft Sam from tetyys.com's SAPI4 service.
- `scenes.py`: one draw function per scene. `tape.py`: the timeline (scenes timed to the
  narration), the frame renderer, the mix and the subtitles. `gfx.py`: canvas, water and the
  pasted-in assets. `sound.py`: loading, filters and the tape wobble. `music.py`: the music.
  `vhs.py`: the tape look.
- `assets/`: the downloaded signs, figures, falcon and static, with `CREDITS.md`; `assets/made/`
  holds the rebuilt signs from `build_signs.py`.
- `silhouettes.html`, `silhouettes.mjs`, `pack_silhouettes.py`: render the creature side-on with
  three.js in headless Chromium and pack the frames. `render_svgs.mjs` and `pack_people.py` turn
  the downloaded SVGs into PNGs.
- `labels.py`: draws the cassette's two labels (`python3 labels.py <out_dir>`, which also writes
  a side-by-side `labels_preview.png`).

## Build

Needs Python 3 with numpy and Pillow, ffmpeg, and the fonts Liberation Sans, FreeMono and Unifont.

```
python3 fetch_voice.py voice
python3 tape.py voice out
```

`out/falcon_tape.mp4` and `out/falcon_tape.srt` come out after a few minutes. `--stills 12.5,40`
writes single frames instead, for checking a scene.

## Notes

- Microsoft Sam belongs to Microsoft. Analogue-horror videos use him all the time, but if the tape
  is used to sell the game, consider re-recording the lines with a voice you have rights to:
  `tape.py` times every scene to whatever WAVs are in the voice folder.
- To change a line, edit `narration.py`, delete its WAV from the voice folder, and fetch again.
