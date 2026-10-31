# Suit preparation

Blender 4.2 scripts that turn the three approved Sketchfab suits into the files in
`game/assets/suits/`. Run them headless: `blender -b --python SCRIPT -- ARGS`.

| Suit | Steps |
|---|---|
| Anti-radiation suit (OZK) | `build_ozk.py ozk_low.fbx textures_dir ozk.glb` on the author's source FBX: wires the hands and boots to the arm and leg bones (in the source they hang off IK control bones), removes the control bones, renames bones to Mixamo names, 1.72 m tall, base color + normal textures (1024 for the suit, 512 for the rest). Then `python3 make_ozk_mask.py ozk_albedo_1024.png ozk_mask.png` for the camo mask. |
| Diver | `prep.py` (drops the fins), then `normalize_suit.py in.glb diver.glb -180` to stand it upright, 1.72 m. |
| Striker jumpsuit | `prep.py`, then `rest_from_anim.py in.glb baked.glb 0` (bakes the idle frame as the rest pose), `refit_joints.py baked.glb refit.glb` (moves each joint to where the mesh bends and folds the broken finger bones into the hands), `normalize_suit.py refit.glb jumpsuit.glb keep`. |

`glb_check.py` and `mesh_info.py` print transforms, bounds and skin weights for checking.
In the game, `game/tests/suit_pose_shot.tscn` renders all three suits in a few IK poses and
`game/tests/probe_ik.gd` measures how close the wrists get to their targets.
