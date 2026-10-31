# Creature voice

`mix_voice.py` mixes the creature's voice from CC0 recordings on Freesound. It writes
stereo WAVs:

- `voice_search.wav`: hunting. Deep throat clicks with a short, small echo. The
  recording's changing mouth shape (which made it sound like a person saying "yeah")
  is flattened out and replaced with one fixed, non-human tone, then distorted.
- `voice_search_bursts.wav`: the same clicks cut apart and rearranged into bursts.
- `voice_close.wav`: close by. Rattling clicks and teeth, distorted.
- `voice_charge.wav`: charging. A death screech from two recorded screams together,
  each lowered for size with a second throat an octave under it, with dry ice on piano
  strings whining on top.
- `voice_charge_clicks.wav`: a burst of speeding-up clicks, then the screech.

## Recordings

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

## Steps

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
