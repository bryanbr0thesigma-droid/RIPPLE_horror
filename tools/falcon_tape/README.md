# F.A.L.C.O.N. orientation tape

"Water Safety and You": an analogue-horror training video about the Wader, made as a 1991 VHS
tape from the Federal Agency for Liminal Classification & Occult Nature. It explains the game's
rules in-world: the Wader hunts by sound in the water, dry ground is safe, falls are loud, going
still gives you a 70% chance, what its clicking means, decoys, the lidar, generators and mineral
water, and what to do when someone is taken. About 6 minutes, narrated by Microsoft Sam.

The finished video is `media/falcon_tape.mp4` (960x720, 4:3) with subtitles in
`media/falcon_tape.srt`.

## How it's made

Everything is flat 2D, drawn in code the way a cheap 1990s training video was: title cards, a
seal, safety-sign pictograms, and side cross-sections of the poolrooms. The Wader only appears as
a silhouette cut from the game's own creature model. Then every frame is put through a VHS
tape (`vhs.py`): soft luma with an edge halo, smeared colour, wobbling lines, head-switching
noise, dropouts, and tracking glitches at chosen moments.

- `narration.py`: every line Sam reads (some spelled for Sam, like "lie-dar"), with subtitle text.
- `fetch_voice.py`: downloads each line read by Microsoft Sam (SAPI 4) from tetyys.com's SAPI4
  service, once per line.
- `silhouettes.html`, `silhouettes.mjs`, `pack_silhouettes.py`: render the creature
  (`game/assets/creature/creature.glb`) side-on as white-on-black cutouts with three.js in headless
  Chromium, and pack them into `silhouettes/` (idle, search and screech, 12 frames a second).
- `gfx.py`: the canvas, pictograms, seal, water, concrete hatching and silhouettes.
- `scenes.py`: one draw function per scene.
- `tape.py`: the timeline (scenes timed to the narration), the frame renderer, the sound mix and
  the subtitles.
- `sound.py`: filters, the synth bed, chimes, typewriter and the tape (hiss, hum, wow and flutter).
- `vhs.py`: the tape look.

Sounds are the game's own (creature voice, splashes, wading, generator, music; see
`game/CREDITS.md`) plus a few synthesized here. No generative AI was used: Sam is a 1990s
rule-based speech synthesizer, and the pictures are drawn by the scripts.

## Build

Needs Python 3 with numpy and Pillow, ffmpeg, and the fonts Liberation Sans, FreeMono and Unifont.

```
python3 fetch_voice.py voice
python3 tape.py voice out
```

`out/falcon_tape.mp4` and `out/falcon_tape.srt` come out after a few minutes. `--stills 12.5,40`
writes single frames instead, for checking a scene. `--size 1440x1080` for a larger file.

To redo the silhouettes (only if the creature changes): `npm install three@0.169.0 playwright`,
copy `creature.glb` here, run `python3 -m http.server 8765` in this folder, then
`node silhouettes.mjs frames` and `python3 pack_silhouettes.py frames`.

## Notes

- Microsoft Sam belongs to Microsoft. Analogue-horror videos use him all the time, but if the tape
  is used to sell the game, consider re-recording the lines with a voice you have rights to:
  `tape.py` times every scene to whatever WAVs are in the voice folder.
- To change a line, edit `narration.py`, delete its WAV from the voice folder, and fetch again.
