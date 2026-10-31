# Creature voice

`mix_voice.py` mixes the creature's clicking voice from CC0 recordings on Freesound.
It writes three stereo WAVs:

- `voice_search.wav`: hunting. Deep, wet throat clicks in a tiled pool hall.
- `voice_close.wav`: close by. Slower rattling clicks with water at its mouth.
- `voice_charge.wav`: charging. Clicks speeding up into a harsh rasp.

It lowers the pitch to suit a big body, filters and layers the recordings, builds the
accelerating click train for the charge from single clicks, and adds a pool-hall
reverb (long, with the highs dying faster than the lows).

## Recordings

All are CC0, so no credit is needed and the files can be committed. Each uploader
says how they made the sound.

| File | Sound | Uploader | How it was made |
|---|---|---|---|
| `688417.mp3` | [Weird Throat Clicking](https://freesound.org/people/Fupicat/sounds/688417/) | Fupicat | His own voice |
| `830016.mp3` | [death rattle - sound samples](https://freesound.org/people/Moss___6/sounds/830016/) | Moss___6 | Voice, recorded on a Tascam |
| `533537.mp3` | [grottle manip](https://freesound.org/people/Saltbearer/sounds/533537/) | Saltbearer | Throat crackle into a water bottle, processed |
| `362780.mp3` | [Spider Call](https://freesound.org/people/taure/sounds/362780/) | taure | A real jumping spider |
| `470902.mp3` | [teeth clicking](https://freesound.org/people/Zrte/sounds/470902/) | Zrte | Teeth |
| `422666.mp3` | [hydrophone bubbles straw small](https://freesound.org/people/JavierZumer/sounds/422666/) | JavierZumer | Hydrophone |

Also being reviewed but not in the mixes yet:
[bat-like monster sonar click](https://freesound.org/people/vestibule-door/sounds/669717/) (vestibule-door)
and [insectoid monster clicking](https://freesound.org/people/LucasDuff/sounds/467700/) (LucasDuff).

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
