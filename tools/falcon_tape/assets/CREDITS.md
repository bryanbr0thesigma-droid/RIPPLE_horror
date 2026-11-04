# Tape assets

Everything here is public domain or CC0, made by people (not generated), and allows commercial use.
Uploads from before 2022 were preferred, to stay clear of AI-made work.

| File | What it's for | Source | Author | License |
|---|---|---|---|---|
| `signs/ISO_7010_W001` | General warning (the opening warning card) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7010_W001.svg) | Maxxl2, after ISO 7010 | Public domain |
| `signs/ISO_7010_W008` | Drop (fall): falling in, and the falling figure | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7010_W008.svg) | Maxxl2, after ISO 7010 | Public domain |
| `signs/ISO_7010_P001` | The prohibition disc, ring and slash | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7010_P001.svg) | after ISO 7010 | Public domain |
| `signs/ISO_7010_P004` | The walking figure (stop moving) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7010_P004.svg) | after ISO 7010 | Public domain |
| `signs/ISO_7010_M001` | General mandatory action: remember | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7010_M001.svg) | after ISO 7010 | Public domain |
| `falcon_121135.svg` | The falcon in the F.A.L.C.O.N. seal (the rock it perches on removed by `../build_signs.py`) | [Openclipart 121135, "peregrine falcon"](https://openclipart.org/detail/121135/peregrine-falcon) (2011) | papapishu | Public domain (CC0) |
| `people/*` (from `oc_241042.svg`) | The people in the diagrams | [Openclipart 241042, "Template of road signs (stickmen)"](https://openclipart.org/detail/241042) (2016) | rones | Public domain (CC0) |
| `signs/ISO_7000_0626` | The water drops (one raindrop from "keep dry", stood upright) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:ISO_7000_-_Ref-No_0626.svg) | after ISO 7000 | CC0 |
| `sound/static.mp3` | Static and tape noise | [OpenGameArt, "Static"](https://opengameart.org/content/static) (2014) | xhunterko | CC0 |

`made/` holds the tape's own signs, put together from those ISO signs by `../build_signs.py`
(water added; the "stop moving" and "don't go in" signs reuse the walking and falling figures
inside the prohibition ring; the warning triangle holds the Wader's silhouette).

The music (the training-video bed and the logo jingle) is synthesized by `../music.py`.

Also used, from the game itself (`game/assets/audio`, see `game/CREDITS.md`): the creature's voice
and screeches, splashes, wading, drips, the room tone and the "Under the surface" music, all mixed
from CC0 recordings. The game's synthesized sounds (clank, door, flashlight) are not used.

The Wader's silhouettes (`../silhouettes/`) are rendered from the game's creature model (The Rake by
Sealife Fan 3, CC BY 4.0, reworked for RIPPLE).
