# RIPPLE — Design Doc

## Pitch

A co-op VR horror platformer. You're trapped in flooded places and have to escape by
climbing, jumping and balancing above the water. Something lives in the water. It
can't see you. It hears the water. If you fall in, it's coming.

## Scope

- **Platform:** Meta Quest standalone (Quest 3 / 3S)
- **Engine:** Godot 4
- **Players:** 1–4 co-op, fully playable solo
- **Structure:** separate levels, each one a flooded location to escape from
- **Goal of every level:** reach the exit
- **Water level:** fixed (it never rises or drains)
- **Assets:** no AI-generated assets (see Asset policy)

## Core rules

1. **It hunts by sound in the water.** Anything that disturbs the water makes noise.
2. **It can't leave the water.** Dry ground is safe.
3. **It's fast.** You can't outrun it once it's charging.
4. **Falling in is the main danger.** A fall is a big splash, and it almost always
   hears it and charges. Most of the game is spent above the water trying not to
   fall in.

## Falling in

Falling in should be terrifying but survivable, or players will stop taking risks.

- **Fall height sets splash size.** A short slip off a low ledge is a medium splash.
  A fall from high up is huge. Lowering yourself in slowly from a ledge is quiet.
- **"Almost always" hears you.** A fall goes unheard only if it's masked by thunder
  or heavy rain, or the creature is far away or busy with a decoy.
- **Its distance is your escape window.** It charges from wherever it is, so how
  long you have depends on how far away it was. Its wake and sound cue tell you how
  close it is.
- **There's always a way out nearby.** Ladders, chains, low ledges and pipes are
  placed so a fallen player can always reach one if they move immediately.
- **The edge isn't safe.** It can lunge about 1 m out of the water, so you have to
  climb all the way up, not just grab the edge.

## Platforming

Movement:
- **Walk and jump:** thumbstick movement plus a jump button
- **Climb:** grab ledges, pipes, chains and ladders with your hands and pull yourself
  up. This is the most natural kind of VR platforming and the most comfortable.
- **Mantle:** pull yourself up onto a ledge you're hanging from
- **Balance:** walk along narrow beams and planks, physically if you have room

Platform types:
- **Narrow beams and planks:** some tilt or creak (small noise if they touch water)
- **Floating debris:** bobs when you land on it and makes small ripples
- **Wet, slippery surfaces:** you slide if you move too fast
- **Crumbling platforms:** give way after a moment, or if more than one player
  stands on them
- **Hanging pipes and chains:** swing or climb across
- **Broken ladders:** missing rungs you have to reach past
- **Powered platforms:** bridges, lifts and moving platforms switched on by levers
  and fuse boxes

Short wading sections between platforming sections keep the stealth part alive:
sometimes there's no way around the water and you have to go through it slowly.

## Making a fast creature fair

1. **Noise takes time to travel.** Every noise spreads as a ripple at a fixed speed.
   The creature reacts to where the noise *was*, not where you are now.
2. **Small noises get investigated first.** The creature has escalating states:
   - **Patrol:** wanders slowly
   - **Investigate:** swims at medium speed to where a small noise came from
   - **Charge:** full speed, triggered by a big splash like a fall, or more noise
     near the spot it's investigating
   - **Lose interest:** reaches the spot, hears nothing for a few seconds, goes back
     to patrolling

   Freezing when it starts investigating is always a valid way to survive a small
   noise. A fall usually skips straight to charge.
3. **It always gives itself away.** Each state has its own tells: a V-shaped wake, a
   fin or back breaking the surface, bubbles, and a different sound cue per state.
   An attentive player always knows what it's doing.
4. **It waits.** After you climb out, it circles nearby for a while, so going back
   into the water right away is a bad idea.

## Noise

| Source | Noise |
|---|---|
| Falling in | Very loud, louder from higher up. Almost always triggers a charge. |
| Lowering yourself in slowly | Quiet |
| Wading slowly | Very quiet |
| Wading fast | Loud |
| Hands moving underwater | Depends on hand speed: slow is silent, a flinch is a splash |
| Landing on floating debris | Small ripples |
| Dropping an item into the water | Medium |
| Re-entering the water while dripping | Medium (you drip for a while after climbing out) |
| Throwing an object into the water | Loud, at the landing point (use as a decoy) |
| Interactions | See the interactables table |

**Cover noise:** rain, thunder, dripping pipes and running machinery mask the noise
you make. A thunderclap is a window to do something loud.

**Haptics:** controller vibration matches how much noise you're making, so players
learn by feel.

## Interactables

Every interaction has a cost: noise, or a risky position above the water.

| Interactable | How it works | Noise |
|---|---|---|
| **Keys** | Usually on hard-to-reach ledges. Some are in shallow water and have to be grabbed slowly. Drop one and it sinks with a plop. Insert and turn in the lock. | Quiet if careful |
| **Locked doors** | Opened with keys. Some are rusted or stuck and have to be forced. | Key: quiet. Forcing: loud |
| **Levers** | Pulled physically. Extend bridges, lower platforms, open gates. Heavy ones clank. Some need two players at once (solo version: wedge with a crowbar). | Loud — time with thunder or a decoy |
| **Fuse boxes** | Find fuses, open the panel, slot them in. Restoring power runs lifts and moving platforms. Often mounted where you have to hang on with one hand while working with the other. | Medium (sparks, buzzing) |
| **Throwables** | Bottles, stones, cans. Throw to make noise somewhere else. | Loud at the landing point |

Typical level chain: **find key → open storeroom → collect fuses → power the lift →
pull the lever to extend the exit bridge → escape.**

## Levels

Each level is 15–25 minutes long, with dry rooms as checkpoints.

1. **Flooded school** — tutorial. Teaches climbing, jumping, decoys and what happens
   when you fall in.
2. **Drowned subway station**
3. **Pumping station**
4. **Village after the dam broke**
5. **Flooded house** — finale

## Comfort

Platforming is the hardest thing to make comfortable in VR.

- Climbing is the main way to move between heights, because it's the most comfortable.
- Jumping is short and predictable, with an optional vignette while in the air.
- Snap turn and smooth turn options.
- No forced camera movement. Falling into the water uses the player's real fall, with
  an optional vignette.

## Multiplayer

- **One creature, hears everyone.** One teammate's fall endangers the whole team.
- **Co-op platforming:** pull a teammate up a ledge by the hand, boost them to a
  higher platform, hold a plank steady while they cross.
- **Rescue:** when someone falls in, the team can throw a decoy to buy them time or
  reach down and pull them out.
- **Co-op tasks:** two-person levers, one player distracts while another works a fuse
  box, passing items across gaps.
- **Weight:** some crumbling platforms only hold one player at a time.
- **Proximity voice chat.** Optional setting: your real voice and breathing reach the
  water through the mic.
- **Getting caught:** you're out until the team reaches the next dry checkpoint room,
  then you respawn. If everyone is caught, restart from the last checkpoint.
- **Solo:** every two-person task has a solo alternative.

## Tech

- **Engine:** Godot 4 (latest stable), OpenXR
- **VR toolkit:** Godot XR Tools for movement (direct movement, turning, jumping,
  climbing), picking up objects, and snap zones for keys and fuses
- **Quest export:** Godot OpenXR Vendors plugin. Mobile renderer, or Compatibility if
  performance needs it.
- **Physics:** Jolt (built into Godot 4.4+), for stable climbing and platform physics
- **Networking:** Godot's built-in multiplayer (MultiplayerSpawner,
  MultiplayerSynchronizer, RPCs). ENet over LAN during development. Online play needs
  a relay or matchmaking service — still to be chosen (options include Nakama, Epic
  Online Services, or WebRTC with a small signaling server).
- **Voice chat:** Godot has no built-in voice chat, so this needs an addon or a custom
  setup with microphone capture. Still to be chosen.
- **Host-authoritative creature:** the creature AI runs on the host. Each player's
  game detects their own noise (falls, hand speed, wading speed) and sends noise
  events to the host.
- **Noise model:** a noise event has an origin, a loudness and a start time. It
  spreads as a ring at a fixed speed and gets quieter with distance. The creature
  "hears" a noise when the ring reaches it. This keeps the AI predictable and cheap.
- **Water visuals:** a water shader drawing ripple rings (the active ripples are
  passed to the shader as an array), cubemap reflections and fog. No real-time
  reflections or GPU wave simulation, to stay fast on Quest.
- **"Can't leave the water":** the creature moves on a navigation mesh baked only over
  the water. The edge lunge is an attack with a fixed reach.
- **Audio:** 3D positional audio is essential. Half the game is hearing where it is.
  Underwater muffling when your head goes under.
- **Performance target:** 72–90 Hz on Quest 3 / 3S.

## Asset policy

No AI-generated assets: no AI-made models, textures, images, sound effects, music or
voice.

- Assets are made by the team, or come from human-made libraries with a clear
  license. Examples: Kenney (CC0), Poly Haven (CC0), ambientCG (CC0), and Freesound
  (license varies per sound).
- Check each asset before using it. Some libraries now contain AI-made content.
- Every third-party asset goes in a credits file with its source, author and license.
- Early milestones use Godot's built-in shapes (boxes, planes, CSG), so no assets are
  needed until level art starts.

## Milestones

1. **Solo gray-box:** platforms over water made from simple shapes. Walk, jump,
   climb. Falling in makes a splash, the creature (water-only navigation mesh)
   charges, ladders to climb out, getting caught, restart.
2. **Noise and stealth:** wading and hand noise, the investigate state, decoys,
   floating debris.
3. **Interactables:** key and door, lever, fuse box, each with its noise cost.
4. **Multiplayer:** 2 players over LAN, creature runs on the host, shared noise,
   pulling a teammate up.
5. **Level 1:** the flooded school, fully built with human-made art and audio.
6. **Online play, voice chat, more levels, polish.**

## Open questions

- What does the creature look like? What's the story — why are you there?
- Which online relay or matchmaking service?
- Which voice chat solution?
- Should mic noise (voice reaching the water) be on or off by default?
- Is 4 the max player count?
- How long does a dripping player stay noisy after climbing out?
