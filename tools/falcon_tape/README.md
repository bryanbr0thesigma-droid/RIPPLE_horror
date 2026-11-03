# F.A.L.C.O.N. orientation tape

"Water Safety and You": a 3-minute analogue-horror training video about the Wader, made as a 1991
VHS tape from the Federal Agency for Liminal Classification & Occult Nature and narrated by
Microsoft Sam. It teaches the game's core rules in-world: the Wader hunts by sound, dry ground is
safe, falls are loud, going still gives you a 70% chance, what its clicking means, and what to do
when someone is taken.

The finished video is `media/falcon_tape.mp4` (960x720, 4:3) with subtitles in
`media/falcon_tape.srt`.

## What's in it

- **The Wader:** silhouettes rendered from the game's own creature model (`silhouettes/`), the
  only artwork made for the tape.
- **Everything else is existing human-made work** (public domain or CC0, listed in
  `assets/CREDITS.md`): ISO 7010 safety signs, road-sign stick figures and a falcon engraving from
  Openclipart for the seal, CC0 static and elevator music from OpenGameArt, and the game's own
  recordings (creature voice, splashes, wading, drips, room tone, music).
- **Drawn by the scripts:** only text (in existing fonts), the simulated water of the side
  cross-sections (the pool, deck and concrete), and the VHS tape effect (`vhs.py`).
- **Narration:** Microsoft Sam (SAPI 4), a 1990s rule-based speech synthesizer.

## Files

- `narration.py`: every line Sam reads, with subtitle text where it differs.
- `fetch_voice.py`: downloads each line read by Microsoft Sam from tetyys.com's SAPI4 service.
- `scenes.py`: one draw function per scene. `tape.py`: the timeline (scenes timed to the
  narration), the frame renderer, the mix and the subtitles. `gfx.py`: canvas, water and the
  pasted-in assets. `sound.py`: loading, filters and the tape wobble (no synthesis). `vhs.py`: the
  tape look.
- `assets/`: the downloaded signs, figures, falcon and sounds, with `CREDITS.md`.
- `silhouettes.html`, `silhouettes.mjs`, `pack_silhouettes.py`: render the creature side-on with
  three.js in headless Chromium and pack the frames. `render_svgs.mjs` and `pack_people.py` turn
  the downloaded SVGs into PNGs.

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
