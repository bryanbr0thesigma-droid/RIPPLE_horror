# RIPPLE — Assets

Every asset must allow full commercial use and must not be AI-generated (see the
Asset policy in `DESIGN.md`). Assets are reviewed with previews before they're
approved.

## Rules

- **Licenses:** CC0 preferred. Anything else needs a license that allows commercial
  use in a game. CC BY is fine, but the artist must be named in the game's credits.
- **No AI:** check each source. Prefer sources that state they don't use generative AI.
- **Public repo:** this repository is public. Assets whose license forbids
  redistributing the raw files (for example the Sonniss GDC sound bundles or Mixamo)
  can be used in the game but must not be committed here.
- **Quest:** download textures at 1K and simplify heavy models.

## Approved

| Asset | What it's for | Source | Author | License |
|---|---|---|---|---|
| [Tiles 132 A](https://ambientcg.com/view?id=Tiles132A) — blue pool tiles, clean | Pool walls and floors | ambientCG | ambientCG | CC0 |
| [Tiles 132 C](https://ambientcg.com/view?id=Tiles132C) — blue pool tiles, broken | Damaged areas | ambientCG | ambientCG | CC0 |
| [Tiles 133 A](https://ambientcg.com/view?id=Tiles133A) — white square tiles, clean | Walls, walkways, platforms | ambientCG | ambientCG | CC0 |
| [Tiles 036](https://ambientcg.com/view?id=Tiles036) — white subway tiles | Corridors and staff areas | ambientCG | ambientCG | CC0 |
| [Prototype Textures](https://kenney.nl/assets/prototype-textures) | Gray-box test level | Kenney | Kenney | CC0 |
| [Wet Floor Sign 01](https://polyhaven.com/a/WetFloorSign_01) | Poolside dressing. In the game (0.3). | Poly Haven | Fran Calvente | CC0 |
| [Industrial Wall Lamp](https://polyhaven.com/a/industrial_wall_lamp) | Wall lighting in the small rooms. In the game (0.3). | Poly Haven | Kuutti Siitonen | CC0 |
| [Modular Pipes](https://polyhaven.com/a/modular_pipes) | Pipe runs along the hall walls and a riser by the generator. Only 5 pieces of the kit are used. In the game (0.3). | Poly Haven | Kuutti Siitonen | CC0 |
| [Plastic Monobloc Chair 01](https://polyhaven.com/a/plastic_monobloc_chair_01) | Poolside and staff room chairs. In the game (0.3). | Poly Haven | Kuutti Siitonen | CC0 |
| [Godot XR Tools hands](https://github.com/GodotVR/godot-xr-tools/tree/master/addons/godot-xr-tools/hands) | The player's own hands. Recolored to match the gloves of the suit the player wears. | Godot XR Tools | DigitalN8m4r3 | CC0 |
| [Anti-radiation suit (OZK)](https://sketchfab.com/3d-models/antiradiation-suit-ozk-2e815542505d48d8be91e9f7dbebfd0a) | Player suit. Player color changes the camo. | Sketchfab | sanyaork | CC BY 4.0 |
| [Jumpsuit Low Poly Game Ready (Striker14)](https://sketchfab.com/3d-models/jumpsuit-low-poly-game-ready-striker14-da288adbddf949aa85962968732f0999) | Player suit. Player color changes the stripes. | Sketchfab | DanlyVostok | CC BY 4.0 |
| [Nanando diver](https://sketchfab.com/3d-models/nanando-diver-underwater-0073b3e5348640fbbaf73278726400fb) | Player suit. Player color changes the yellow parts. Fins removed. | Sketchfab | Marco Lopez | CC BY 4.0 |
| [Four Legged Predator](https://sketchfab.com/3d-models/four-legged-predator-7f68f9daa698433299092bfecaae4e9e) | Not used by the current creature, which is built from The Rake alone. Kept in case. | Sketchfab | Timsblends | CC BY 4.0 |
| [The Rake](https://sketchfab.com/3d-models/the-rake-92898b04b24e4315b0673fcfe307f64e) | The creature: body, head, limbs and animations (see "The creature" in `DESIGN.md`) | Sketchfab | Sealife Fan 3 | CC BY 4.0 |
| [Brown Leather](https://polyhaven.com/a/brown_leather) | Pore and wrinkle detail for the creature's skin | Poly Haven | Poly Haven | CC0 |

## Maybe

Not added unless they're approved later.

- [Tiles 133 D](https://ambientcg.com/view?id=Tiles133D) — white square tiles, broken (ambientCG)
- [Utility Box 01](https://polyhaven.com/a/utility_box_01) — control box housing (Poly Haven)
- [Rollershutter Door](https://polyhaven.com/a/rollershutter_door) — gates (Poly Haven)
- [Crowbar 01](https://polyhaven.com/a/crowbar_01) — solo lever wedge (Poly Haven)
- [Mounted Fluorescent Lights](https://polyhaven.com/a/mounted_fluorescent_lights) (Poly Haven)
- [Caged Hanging Light](https://polyhaven.com/a/caged_hanging_light) (Poly Haven)
- [Modular Airduct Rectangular 01](https://polyhaven.com/a/modular_airduct_rectangular_01) (Poly Haven)
- [Rubber Duck Toy](https://polyhaven.com/a/rubber_duck_toy) (Poly Haven)
- [Plastic Crate 01](https://polyhaven.com/a/plastic_crate_01) (Poly Haven)
- [Plastic Bottle Gallon](https://polyhaven.com/a/plastic_bottle_gallon) — throwable (Poly Haven)
- [Can Rusted](https://polyhaven.com/a/can_rusted) — throwable (Poly Haven)
- Backup creature: [Ocean Creature](https://sketchfab.com/3d-models/ocean-creature-5c17cca6086e4910aa12e7d701ccd6a1) by bast_yy (Sketchfab, CC BY)
- Backup creature: [Snake attack animations](https://sketchfab.com/3d-models/snake-attack-animations-multiple-83c4290cd4b648fd942d4bbc2280a3f6) by Imagigoo (Sketchfab, CC BY)

## In the test demo

The co-op demo in `game/` already uses these approved assets (credits in `game/CREDITS.md`):
Tiles 132 A and Tiles 133 A (pool and wall tiles), the Godot XR Tools hands, the creature (The
Rake, reworked, with Brown Leather skin detail, built by `tools/creature/` at 1024 px textures),
the creature's voice, and the three ambience loops. Its other sounds (splashes, wading, plop,
pouring, generator, distiller) are cut from the same approved CC0 recordings; the metal clank
and door were synthesized for the project.

## Still needed

- **Creature import:** build it with the scripts in `tools/creature/` (the drowned
  version with dark skin and decorative mouths). Things to handle in Godot:
  - Pose the unhinged jaw: rotate the jaw bone about 0.75 rad around its X axis and
    stretch it about 1.3x along its length.
  - Some of the model's normals face inward. Check for missing faces.
  - The shoulder mouth bulges a little and needs sinking.
  - Downsize the 2048 px textures and the 4096 px normal map for Quest.
- **Sounds:** the creature's voice is mixed from CC0 Freesound recordings with
  `tools/sound/mix_voice.py` and is approved: hunting (the rattle), close by, and the
  charge (clicks, then a death screech). Ambience loops (`tools/sound/mix_ambience.py`)
  are approved (lit halls, pump room, dark sector). Music is approved: **Melted piano**
  (title screen) and **Under the surface** (in the level), made by `tools/sound/mix_music.py`
  from "At the End of Hope" by Emma_MA and "Underwater Ambient Pad" by isaiah658 (both CC0,
  OpenGameArt). Other sound effects come later.
- **Made by the team:** diving boards and towers, water slides, retractable pool covers,
  inflatable rings and floats.
- **Round 20 (waiting for picks):** real models for the key, doors, lever, canteen,
  generator, lidar scanner body, distiller, throwable bottles and pool ladder. Until they're
  picked, the game uses simple stand-in shapes for these.
- **Suit models:** in the game since 0.3 (`game/assets/suits/`). Each was prepared in
  Blender by the scripts in `tools/suits/`: the anti-radiation suit is rebuilt from the
  author's source FBX (the download's hands and boots hung off IK control bones), the
  diver is stood upright, and the jumpsuit's skeleton is refitted to its mesh. The
  jumpsuit's own gloves can't be used (they are stored half a metre from the hands), so it
  wears the XR Tools gloves, the same ones the player sees in first person. One color mask
  per suit marks the parts that take the player's color.
- **Avatar movement:** other players' suits follow their real head and hand tracking
  (`game/player/suit_ik.gd`): the hips drop and the legs bend when they crouch, the arms
  reach for their hands, the head turns with theirs. No animation library is needed.

## Dropped

- Quaternius Universal Base Characters and Universal Animation Library: the approved
  suits are complete characters, so the bare bodies aren't needed.

## Files

The approved files will be downloaded into the project when the Godot project is set
up.
