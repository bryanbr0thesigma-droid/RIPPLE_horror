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
| [Nanando diver](https://sketchfab.com/3d-models/nanando-diver-underwater-0073b3e5348640fbbaf73278726400fb) | Player suit. Player color changes the yellow parts. Fins removed. | Sketchfab | Marco Lopez | CC BY 4.0 |
| [Scuba Diver](https://sketchfab.com/3d-models/3cffae9b572d4506b3025e29d6ff068c) | Player suit (0.8). Rigged with the diver's skeleton (`tools/suits/rig_like_diver.py`). Player color changes the tank and gear. | Sketchfab | turelljc | CC BY 4.0 |
| [The Diver](https://sketchfab.com/3d-models/cf096d52e26a4ed397e13c7ccbd52f6b) | Player suit (0.8): the brass-helmet diver. Rigged the same way; textures shrunk for the Quest. Player color changes the straps. | Sketchfab | amt16 | CC BY 4.0 |
| [Cat Girl - Anime Character Model](https://sketchfab.com/3d-models/cat-girl-anime-character-model-c3ebdd8cadf549cda8fd01685bf76ed0) | Secret suit "Latex diver" (0.8.1), unlocked by typing 34 on the character page. A VRoid character, kitbashed by `tools/suits/build_latex_diver.py`: her skin from the neck down becomes black latex, her figure is made fuller through her own skin weights (bust, waist, hips and rear, thighs), and she wears the Scuba Diver's tank, vest and mask. Sprung jiggle bones (VRoid's bust bones, plus added rear and thigh bones) bounce with her movement in the game; a mask on her top's pink trim makes it take the player color (0.8.2). | Sketchfab | VR_Avatars | CC BY 4.0 |
| [Four Legged Predator](https://sketchfab.com/3d-models/four-legged-predator-7f68f9daa698433299092bfecaae4e9e) | Not used by the current creature, which is built from The Rake alone. Kept in case. | Sketchfab | Timsblends | CC BY 4.0 |
| [The Rake](https://sketchfab.com/3d-models/the-rake-92898b04b24e4315b0673fcfe307f64e) | The creature: body, head, limbs and animations (see "The creature" in `DESIGN.md`) | Sketchfab | Sealife Fan 3 | CC BY 4.0 |
| [Brown Leather](https://polyhaven.com/a/brown_leather) | Pore and wrinkle detail for the creature's skin | Poly Haven | Poly Haven | CC0 |
| [Old Key](https://sketchfab.com/3d-models/d846b203f4754ee3825e8c4c76d21b21) | The staff room key. Recolored gold. In the game (0.4). | Sketchfab | TheFalkonett | CC BY 4.0 |
| [Metal Door 2](https://sketchfab.com/3d-models/4da6b538427244aaababe36d3e228a40) | The locked staff room door; the leaf swings open on its hinge. In the game (0.4). | Sketchfab | tboiston | CC BY 4.0 |
| [Fire Escape / Exit Doors](https://sketchfab.com/3d-models/4ad9f395571a4dfaadce33dfeccc7a53) | The exit. In the game (0.4). | Sketchfab | bloobloo | CC BY 4.0 |
| [Old metal bunker door](https://sketchfab.com/3d-models/a602f52789fb4bc1a46cc1d0633def60) | A sealed door in the start room (dressing). In the game (0.4). | Sketchfab | rakutin | CC BY 4.0 |
| [Industrial Electricity's Lever](https://sketchfab.com/3d-models/66915915e3234d319415d6bfb4e3a59e) | The generator's power lever. In the game (0.4). | Sketchfab | Amine.Elouneg | CC BY 4.0 |
| [Old lever](https://sketchfab.com/3d-models/f1075e12ba4a49368e0f29c62881ac73) | The pool cover lever; its handle turns. In the game (0.4). | Sketchfab | gunnarcorrea | CC BY 4.0 |
| [Geiger counter](https://sketchfab.com/3d-models/25b8e5c2de1148c0b991bb239efa1808) | The lidar scanner's body. In the game (0.4). | Sketchfab | DenisKorablyov | CC BY 4.0 |
| [Dusty Beer Bottle](https://sketchfab.com/3d-models/03d9062085214988b2e984470c7c0d28) | Throwable bottle. In the game (0.4). | Sketchfab | GameDevNick | CC BY 4.0 |
| [Whiskey and Wine Low-Poly Bottles](https://sketchfab.com/3d-models/99999f032f624e8cb05651f041dbf8eb) | Three more throwable bottles. In the game (0.4). | Sketchfab | Helyeouka | CC BY 4.0 |
| [CC0 - Pool Ladder 3](https://sketchfab.com/3d-models/43cbe4e6e68140e1ad202cf8a3e53650) | Every pool ladder, stretched to the pool's depth. Titled CC0 but listed as CC BY, so credited. In the game (0.4). | Sketchfab | plaggy | CC BY 4.0 |
| [Human Spine](https://sketchfab.com/3d-models/57c71ac4134e40be9506be639a29c9a4) | Hangs from the head in the head-and-spine kill. In the game (0.4). | Sketchfab | b_bear | CC BY 4.0 |
| [Realistic Human Heart](https://sketchfab.com/3d-models/3f8072336ce94d18b3d0d055a1ece089) | Spills out in the torn-in-half kill. In the game (0.4). | Sketchfab | neshallads | CC BY 4.0 |
| [Realistic Human Lungs](https://sketchfab.com/3d-models/ce09f4099a68467880f46e61eb9a3531) | Same. In the game (0.4). | Sketchfab | neshallads | CC BY 4.0 |
| [Human liver and gallbladder](https://sketchfab.com/3d-models/6c4e9bd0d49f4828b804259330c0c6c4) | Same. In the game (0.4). | Sketchfab | ElliotSS | CC BY 4.0 |
| [Human kidney (Lowpoly example 9k)](https://sketchfab.com/3d-models/2417146cf20a49b5960c79d554d20650) | Same. In the game (0.4). | Sketchfab | linejung | CC BY 4.0 |
| [digestive system](https://sketchfab.com/3d-models/f78ce703805f49d3b732e37be5b93188) | The stomach, same. In the game (0.4). | Sketchfab | 7D_Production | CC BY 4.0 |
| [Rusted liquid storages](https://sketchfab.com/3d-models/1d79acb10553424eb1dfda079af880cd) | The distiller, along the staff room's back wall. In the game (0.5). | Sketchfab | maxpsr | CC BY 4.0 |
| [Machinery device](https://sketchfab.com/3d-models/560748f914fd4209aa8437242fbfd3b8) | The distiller machine the canteen goes on, in front of the tanks (shrunk to 1.7 m, simplified). In the game (0.9.4). | Sketchfab | maxpsr | CC BY 4.0 |
| [Old Metal Table (Low Poly)](https://sketchfab.com/3d-models/92a14c8d231b4812bc7b97d03da6ddd9) | The staff room table. In the game (0.9.4). | Sketchfab | berkgedik | CC BY 4.0 |
| [Tool Cart](https://polyhaven.com/a/tool_cart) | The stand under the lidar charger. In the game (0.9.4). | Poly Haven | Savva Zakharov | CC0 |
| [Plastic Thermos](https://polyhaven.com/a/plastic_thermos) | The canteen. In the game (0.4). | Poly Haven | PierreB3D | CC0 |

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
the creature's voice, the three ambience loops, the suits, and since 0.4 the props, spine and
organs listed above. The kill sounds (screeches 1, 3 and 5, bites, tearing, the spine rip and
feeding) are mixed by `tools/sound/mix_kill.py` from the same CC0 recordings as the
voice. Screeches 2, 4 and 7 were trimmed as asked and are back in Round 22; the
game doesn't play them until they're approved. Its other sounds (splashes, wading, plop,
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
- **Round 20 and 21 (done):** the key, doors, levers, canteen, scanner, bottles, pool
  ladder, spine and organs are approved and in the game (0.4). Every generator and
  distiller in Round 20 was turned down; the two "maybe" generators and new options for
  both are in **Round 22**. Until one is picked, the generator and distiller stay simple
  shapes.
- **Suit models:** in the game since 0.3 (`game/assets/suits/`). Each was prepared in
  Blender by the scripts in `tools/suits/`: the anti-radiation suit is rebuilt from the
  author's source FBX (the download's hands and boots hung off IK control bones), the
  diver is stood upright, and the jumpsuit's skeleton is refitted to its mesh. The
  jumpsuit's own gloves can't be used (they are stored half a metre from the hands), so the
  diver's gloved hands are moved onto it (`tools/suits/transplant_hands.py`). One color mask
  per suit marks the parts that take the player's color. Each suit is also split into
  head, chest and legs pieces by skin weight (`tools/suits/split_parts.py`) for the kills.
  Every suit is also cut into left and right halves (`tools/suits/split_lr.py`) for the
  vertical tear. (Reshaped female versions were tried in 0.8 and removed in 0.8.1.)
- **Avatar movement:** other players' suits follow their real head and hand tracking
  (`game/player/suit_ik.gd`): the hips drop and the legs bend when they crouch, the arms
  reach for their hands, the head turns with theirs. No animation library is needed.

## Code libraries

Not art, but shipped in the game, all allowing commercial use:

| Library | Use | License |
|---|---|---|
| [Godot Engine](https://godotengine.org/) | The engine | MIT |
| [Godot XR Tools](https://github.com/GodotVR/godot-xr-tools) | VR movement, grabbing, hands | MIT |
| [Godot OpenXR Vendors](https://github.com/GodotVR/godot_openxr_vendors) | Quest export | MIT |
| [webrtc-native](https://github.com/godotengine/webrtc-native) | Online co-op (0.9), downloaded by `tools/fetch_webrtc.sh`. Bundles [libdatachannel](https://github.com/paullouisageneau/libdatachannel) and [libjuice](https://github.com/paullouisageneau/libjuice) (MPL 2.0, unmodified), usrsctp and libsrtp (BSD), Mbed TLS (Apache 2.0) | MIT |

## Dropped

- Striker jumpsuit (DanlyVostok): removed from the game in 0.8.

- Quaternius Universal Base Characters and Universal Animation Library: the approved
  suits are complete characters, so the bare bodies aren't needed.

## Files

The approved files will be downloaded into the project when the Godot project is set
up.
