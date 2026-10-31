# RIPPLE — Design Doc

## Pitch

A co-op VR horror game. You're trapped in flooded places and have to escape.
Something lives in the water. It can't see you. It hears the water.

## Scope

- **Platform:** Meta Quest standalone (Quest 3 / 3S)
- **Players:** 1–4 co-op, fully playable solo
- **Structure:** separate levels, each one a flooded location to escape from
- **Goal of every level:** reach the exit
- **Water level:** fixed (it never rises or drains)

## Core rules

1. **It hunts by sound in the water.** Anything that disturbs the water makes noise.
2. **It can't leave the water.** Dry ground is safe.
3. **It's fast.** You can't outrun it once it's charging. You survive by not being
   heard, or by being close enough to dry ground when it comes.

## Making a fast creature fair

The creature is fast, so the game has to warn the player before it arrives.

1. **Noise takes time to travel.** Every noise spreads as a ripple at a fixed speed.
   The creature reacts to where the noise *was*, not where you are now.
2. **It investigates before it attacks.** The creature has escalating states:
   - **Patrol:** wanders slowly
   - **Investigate:** swims at medium speed to where the noise came from
   - **Charge:** full speed, triggered by a loud noise, or more noise near the spot
     it's investigating
   - **Lose interest:** reaches the spot, hears nothing for a few seconds, goes back
     to patrolling

   Freezing when it starts investigating is always a valid way to survive.
3. **It always gives itself away.** Each state has its own tells: a V-shaped wake, a
   fin or back breaking the surface, bubbles, and a different sound cue per state.
   An attentive player always knows what it's doing.
4. **Dry ground is always within reach.** Levels are built so a careful player is
   never too far from a dry spot. The routes between them run through noisy terrain
   (debris, glass, deeper water).
5. **The water's edge isn't safe.** It can lunge about 1 m out of the water at the
   edge. Standing right next to the water is still dangerous.

## Keeping players in the water

Dry ground being safe only works if players can't stay on it.

- Everything needed to progress is in or across the water: keys sunk on the bottom,
  fuse boxes on walls you can only reach while standing in water, levers on pillars.
- Dry spots are small and spread out. There's never a dry path to the exit.
- When you climb out, it circles nearby for a while. To get back in safely you have
  to wait it out or distract it.

## Noise

| Source | Noise |
|---|---|
| Wading slowly | Very quiet |
| Wading fast | Loud |
| Hands moving underwater | Depends on hand speed: slow is silent, a flinch is a splash |
| Re-entering the water while dripping | Medium (you drip for a while after climbing out) |
| Throwing an object into the water | Loud, at the landing point (use as a decoy) |
| Interactions | See the interactables table |

**Cover noise:** rain, thunder, dripping pipes and running machinery mask the noise
you make. A thunderclap is a window to do something loud.

**Haptics:** controller vibration matches how much noise you're making, so players
learn by feel.

## Interactables

Every interaction has a noise cost, so progress is always a risk.

| Interactable | How it works | Noise |
|---|---|---|
| **Keys** | Often on the bottom. Reach down and grab slowly; grabbing fast splashes. Insert and turn in the lock. | Quiet if careful |
| **Locked doors** | Opened with keys. Some are rusted or stuck and have to be forced. | Key: quiet. Forcing: loud |
| **Levers** | Pulled physically. Heavy ones clank. Some need two players at once (solo version: wedge with a crowbar). | Loud — time with thunder or a decoy |
| **Fuse boxes** | Find fuses, open the panel, slot them in. Restoring power turns on lights, gates and lifts. Panels are mounted above water, so you're standing in it while you work. | Medium (sparks, buzzing) |
| **Throwables** | Bottles, stones, cans. Throw to make noise somewhere else. | Loud at the landing point |

Typical level chain: **find key → open storeroom → collect fuses → power the gate →
pull the exit lever → escape.**

## Levels

Each level is 15–25 minutes long, with dry rooms as checkpoints.

1. **Flooded school** — tutorial. Teaches wading, decoys and freezing.
2. **Drowned subway station**
3. **Pumping station**
4. **Village after the dam broke**
5. **Flooded house** — finale

## Multiplayer

- **One creature, hears everyone.** One teammate's noise endangers the whole team.
- **Co-op tasks:** two-person levers, one player distracts while another works a fuse
  box, passing items across the water.
- **Proximity voice chat.** Optional setting: your real voice and breathing reach the
  water through the mic.
- **Getting caught:** you're out until the team reaches the next dry checkpoint room,
  then you respawn. If everyone is caught, restart from the last checkpoint.
- **Solo:** every two-person task has a solo alternative.

## Tech

- **Engine:** Unity 6 LTS, OpenXR, Meta XR SDK, XR Interaction Toolkit (grabbing,
  levers, sockets for keys and fuses)
- **Networking:** Photon Fusion 2 in host mode, plus Photon Voice for voice chat.
  The free tier is enough for development.
- **Host-authoritative creature:** the creature AI runs on the host. Each player's
  game detects their own noise (hand speed, wading speed) and sends noise events to
  the host.
- **Noise model:** a noise event has an origin, a loudness and a start time. It
  spreads as a ring at a fixed speed and gets quieter with distance. The creature
  "hears" a noise when the ring reaches it. This keeps the AI predictable and cheap.
- **Water visuals:** shader-based ripple rings (the active ripples are passed to the
  water shader as an array), cubemap reflections and fog. No real-time reflections
  or GPU wave simulation, to stay fast on Quest.
- **"Can't leave the water":** the creature moves on a NavMesh that only covers
  water. The edge lunge is an attack with a fixed reach.
- **Audio:** 3D positional audio is essential. Half the game is hearing where it is.
  Underwater muffling when your head goes under.
- **Performance target:** 72–90 Hz on Quest 3 / 3S.

## Milestones

1. **Solo gray-box:** one room. Wading and hand splashes create noise events. The
   creature (water-only NavMesh) investigates and charges. Dry islands, getting
   caught, restart.
2. **Interactables:** key and door, lever, fuse box, throwables, each with its noise
   cost.
3. **Multiplayer:** 2 players over Photon, creature runs on the host, shared noise.
4. **Level 1:** the flooded school, fully built with audio and atmosphere.
5. **More levels, voice chat, polish.**

## Open questions

- What does the creature look like? What's the story — why are you there?
- Should mic noise (voice reaching the water) be on or off by default?
- Is 4 the max player count?
- How long does a dripping player stay noisy after climbing out?
