# Prop preparation

Blender 4.2 scripts that turn approved downloads into the files in `game/assets/props/` and
`game/assets/gore/`. Run them headless: `blender -b --python SCRIPT -- ARGS`.

- `ph_to_glb.py in.gltf out.glb max_tex [piece=x,y,z ...]`: a Poly Haven glTF (1k) to a GLB,
  optionally keeping only some pieces of a kit, each moved so a chosen point is its origin
  (used for Modular Pipes).
- `convert_approved.py <sketchfab dir> <polyhaven dir> <game dir>`: the approved Round 20 and 21
  models. Each is baked to real-world size with a sensible origin (bottom centre for doors and
  ladders, centre for hand-held items), simplified for Quest and given textures of at most 1024 px.
  Special cases:
  - The key is recolored gold.
  - The staff room door is split into its frame and a leaf hinged at its own origin, so the game
    can swing it open.
  - The pool cover lever is split into the panel and a handle that turns about its pivot.
  - The three bottles in the wine and whiskey set become `bottle_glass_1` to `_3`.
  - The spine is stood upright with the top vertebra at its origin, to hang from the neck.

Sketchfab downloads need an API token (`Authorization: Token ...`). Never commit the token.
Credits for everything here are in `game/CREDITS.md`.
