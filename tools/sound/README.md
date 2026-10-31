# Sound

## Creature voice

`mix_voice.py` mixes the creature's voice from CC0 recordings on Freesound. It writes
stereo WAVs.

Approved in review:

- `voice_search_rattle.wav`: hunting. The same rattling voice as close by, deeper and
  steadier, lightly distorted with a short echo.
- `voice_close.wav`: close by. Rattling clicks and teeth, distorted.
- `voice_charge_clicks.wav`: charging. A burst of speeding-up clicks, then a death
  screech from two recorded screams together, each lowered for size with a second
  throat an octave under it, with dry ice on piano strings whining on top.

Also written but not chosen: `voice_search_pieces.wav` (throat clicks shuffled),
`voice_search_both.wav`, and `voice_charge.wav` (the screech without the clicks).

Tried and rejected: the throat clicks as recorded (sounded like a person saying
"yeah"), and with their tone flattened (sounded like a printer).

### Recordings

All are CC0, so no credit is needed and the files can be committed.

| File | Sound | Uploader | How it was made |
|---|---|---|---|
| `688417.mp3` | [Weird Throat Clicking](https://freesound.org/people/Fupicat/sounds/688417/) | Fupicat | His own voice |
| `830016.mp3` | [death rattle - sound samples](https://freesound.org/people/Moss___6/sounds/830016/) | Moss___6 | Voice, recorded on a Tascam |
| `470902.mp3` | [teeth clicking](https://freesound.org/people/Zrte/sounds/470902/) | Zrte | Teeth |
| `633958.mp3` | [Horrordeathsound](https://freesound.org/people/DatBloxyBirb/sounds/633958/) | DatBloxyBirb | Screeched into a mic |
| `398802.mp3` | [Monster Scream Death](https://freesound.org/people/DangAdv64/sounds/398802/) | DangAdv64 | Not stated |
| `10347.mp3` | [4th dimension banshee death](https://freesound.org/people/batchku/sounds/10347/) | batchku | Grand piano with dry ice on the strings |

Rejected in review: the jumping spider call, the throat crackle into a bottle, the
hydrophone bubbles, and the Goblin Death scream. Not used yet:
[bat-like monster sonar click](https://freesound.org/people/vestibule-door/sounds/669717/),
[insectoid monster clicking](https://freesound.org/people/LucasDuff/sounds/467700/),
[Screeching](https://freesound.org/people/adamcreeper/sounds/780970/) (eggs in a hot pan).

### Steps

1. Put the recordings in one folder, named by their Freesound id (`688417.mp3` and so
   on). The first mixes used Freesound's high-quality previews. For the game,
   download the full-quality originals (needs a free Freesound account) and convert
   them to MP3, or change the extension in `load()`.
2. Mix (needs Python 3 with numpy, and ffmpeg):
   ```
   python3 mix_voice.py recordings out
   ```

In the game, play these as 3D positional sounds and vary them (start offset, small
pitch changes) so the clicking doesn't loop audibly.

## Ambience

`mix_ambience.py` mixes seamless 60-second ambience loops from CC0 Freesound
recordings: a room tone bed, fluorescent hum, water moving against the pool edges, a
pump behind a wall, and single drips (each with its own echo) scattered around the
loop. Being reviewed (Round 18):

- `amb_halls.wav`: shallow halls, lights on.
- `amb_pumproom.wav`: next to a pump room.
- `amb_dark.wav`: dark sector, lights off (no hum).

| File | Sound | Uploader |
|---|---|---|
| `670070.mp3` | [Room Tone, Empty Hospital](https://freesound.org/people/Kinoton/sounds/670070/) | Kinoton |
| `451918.mp3` | [room tone depanneur corner store fluorescent light only hum](https://freesound.org/people/kyles/sounds/451918/) | kyles |
| `480855.mp3` | [R29-23-Rhythmic Movement of Water](https://freesound.org/people/craigsmith/sounds/480855/) | craigsmith |
| `658155.mp3` | [Pool Equipment - Filter - Pumps](https://freesound.org/people/courter/sounds/658155/) | courter |
| `609161.mp3` | [Many drops of water in a big cave](https://freesound.org/people/nomadas/sounds/609161/) | nomadas |
| `177958.mp3` | [Water Dripping in Cave](https://freesound.org/people/Sclolex/sounds/177958/) | Sclolex |

```
python3 mix_ambience.py recordings out
```

In the game, play the bed quietly and loop it. Better still, play the drips and water
as separate 3D sounds placed around the room.
