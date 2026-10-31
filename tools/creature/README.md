# Creature build

Builds the RIPPLE creature from two CC BY models: the body and limbs of
[The Rake](https://sketchfab.com/3d-models/the-rake-92898b04b24e4315b0673fcfe307f64e) by Sealife Fan 3,
and the head and tail of
[Four Legged Predator](https://sketchfab.com/3d-models/four-legged-predator-7f68f9daa698433299092bfecaae4e9e)
by Timsblends. It adds pale skin, blind eyes, needle teeth and sound pits, and keeps the crawler's
11 animations. Both artists must be credited in the game.

## Steps

1. Download both models from Sketchfab as glTF and unzip them.
2. Make the pale textures:
   ```
   python3 pale_textures.py \
     predator/textures/Head_baseColor.png tex/pred_Head_pale.png \
     predator/textures/Body_baseColor.png tex/pred_Body_pale.png \
     predator/textures/Limbs_baseColor.png tex/pred_Limbs_pale.png \
     rake/textures/lambert1_baseColor.jpeg tex/rake_body_pale.png
   ```
   The predator textures were also brightened a little (gamma 0.72) to match the crawler's body.
3. Export the predator parts. Serve a folder containing `parts_export.html` and the unzipped
   predator model as `predator/` over HTTP, open the page, and it downloads `parts.obj` and
   `parts.json`. Options go in the page's URL, for example
   `parts_export.html?eyes=hollow&gap=0.02&len=1.6&thick=0.85&tilt=-0.45` for hollow eye sockets
   and more, longer fangs leaning into the mouth. The parts are cut from the predator's rest pose, because its file's bind pose
   has the eyes outside their sockets.
4. Write `parts.mtl` next to `parts.obj`, pointing `PredHead`, `PredBody` and `PredLimbs` at the
   pale textures and giving `Teeth`, `Pit`, `BlindEye` and `Socket` plain colors.
5. Build in Blender 4.2:
   ```
   blender -b --python build_creature.py -- rake/scene.gltf parts.obj parts.json tex creature.glb 1.35 0.8 0.34 0.45 0.8
   ```
   The numbers are the head scale (relative to the crawler's own head), the tail scale, how much
   of the tail's thick base to trim, and how thin to make the tail at its base and at its tip.

## Known rough spots

- The tail is rigid. It needs its own bones, or procedural sway in the game.
- The joins at the neck and hips need smoothing.
- The textures are 2048 px and the crawler's normal map is large. Downsize for Quest.

## Glossy black version (being reviewed)

`build_tar_creature.py` makes a different take from the crawler alone: wet, glossy black skin,
a new smooth eyeless head with a crooked slit of human teeth, and sound pits.

1. Make a near-black version of the crawler's base color texture (keep its detail as faint
   variation; the one used was a ramp from about 0.01 to 0.07).
2. Build:
   ```
   blender -b --python build_tar_creature.py -- rake/scene.gltf tar_body.png creature_tar.glb 1.1 14
   ```
   The numbers are the head size (relative to the crawler's own head) and the mouth tilt in degrees.

## Drowned version (being reviewed)

`build_drowned_creature.py` keeps the crawler's own near-human head and gives it matte,
waterlogged dark grey-brown skin, yellowed teeth, and either blank or empty eyes:

```
blender -b --python build_drowned_creature.py -- rake/scene.gltf drowned_skin.png creature_drowned.glb hollow
```

Use `sealed` instead of `hollow` for blank, filmed-over eyes. The unhinged jaw isn't baked in: open
the jaw bone about 0.75 rad around its X axis and stretch it about 1.3x along its length, in the
game or in a preview.
