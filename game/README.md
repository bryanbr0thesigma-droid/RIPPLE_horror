# RIPPLE: demo

A co-op VR demo of RIPPLE: a title screen, a character selector (three suits, your color, your
name), and one level, The Shallow Halls, with every core mechanic. Up to 4 players, on Quest
headsets or PCs, with or without VR. Built in Godot 4.7.2 with Godot XR Tools.

![Map of the test level](../docs/level1_map.png)

## Install on Quest (APK)

1. Turn on **Developer Mode** for your headset in the Meta Horizon phone app (Devices, your
   headset, Developer Mode). This needs a free Meta developer account.
2. Install `ripple-demo.apk` with one of these:
   - [Meta Quest Developer Hub](https://developers.meta.com/horizon/documentation/android-apps/meta-quest-developer-hub/):
     plug the headset in with USB, then drag the APK onto the device page.
   - [SideQuest](https://sidequestvr.com/): plug in, then drag the APK onto the SideQuest window.
   - Or from a terminal: `adb install -r ripple-demo.apk`
3. In the headset, open **Library**, choose **Unknown Sources** in the filter menu, and start
   **RIPPLE Demo**.

Your friend does the same on their Quest. Then, from anywhere: one of you picks **Play, Host online
(room code)** and reads out the 6-character room code (it pops up in the game and stays in the pause
menu); the other picks **Play, Join online with a code** and types it. On the same Wi-Fi you can
also use **Host on this Wi-Fi** and tap the host's game in the list.

## The title screen

- **Play:** host online with a room code, join online with a code, host on your Wi-Fi, play solo,
  join a game found on your network, or join by address.
- **Character:** type your name on the keyboard (or press Random), pick one of the three suits with
  the arrows, and pick a color. Your character stands on the pedestal next to the menu. In the game,
  your hands match your suit's gloves and other players see your suit in your color.
- **Settings:** snap or smooth turning, volume and music volume.
- **Credits:** the artists whose models, sounds and music are in the game.
- Your choices are saved on the headset.
- In the game, press the **menu button** on the left controller (or Esc on desktop) to pause or
  leave to the title.

## Run it on a PC

1. Download **Godot 4.7.2** (the standard version, not .NET) from
   [godotengine.org](https://godotengine.org/download/archive/4.7.2-stable/).
2. In the Godot Project Manager, choose **Import** and pick `game/project.godot` from this repo.
   The first time, Godot imports the assets, which takes a minute.
3. Press **Play** (F5).
   - **VR:** connect your Quest with **Link** or **Air Link** first, and make sure the Meta Quest
     Link app is your active OpenXR runtime (Meta Quest Link app: Settings, General, OpenXR
     Runtime). SteamVR headsets work too. The game starts in VR when it finds a headset.
   - **No headset:** it starts in desktop mode (keyboard and mouse), which is handy for testing.

## Play with a friend

Both of you need the game: either both open the project in Godot (clone this repo), or one of you
exports a build for the other (see below).

- **Online, from anywhere (room code):** one of you presses **Host online (room code)**. A
  6-character code like `QWX4P7` appears in the game (desktop: top-left; VR: a message, and in the
  pause menu). The other presses **Join online with a code**, types it and presses **Join**.
  The games connect straight to each other with WebRTC; a free public MQTT broker is only used
  to swap connection details for that code (`game/core/online_room.gd`). It works through most home
  routers. If both players are on strict networks (some mobile hotspots, school or work Wi-Fi), the
  direct connection can fail; then use one of the options below. To test without the internet, run
  `python3 tools/mqtt_ws_broker.py 8899` and start both games with `--signal=ws://127.0.0.1:8899/mqtt`.
- **Same Wi-Fi or network:** one of you presses **Host on this Wi-Fi**. The other sees "*name*'s game"
  under "Join a game on your network" and clicks it. If it doesn't appear, type the host's address
  on the keypad and press **Join this address**. The host's address is shown at the bottom of the
  menu ("This computer: ...") and at the top-left of the screen while hosting.
- **Different houses:** the easiest way is a free virtual network such as
  [Tailscale](https://tailscale.com/) or [ZeroTier](https://www.zerotier.com/). Both install it and
  join the same network, then the joining player types the host's Tailscale or ZeroTier address
  (for example `100.x.x.x`). Or the host forwards **UDP port 7777** on their router and shares
  their public IP address.
- **Firewall:** when Windows asks, allow Godot (or the exported game) on private networks. The game
  uses UDP port 7777, and UDP port 7778 to find games on your network.
- Up to 4 players. The host runs the creature, so if the host leaves, the game ends for everyone.
- VR and desktop players can play together.

## Controls

| | VR | Desktop |
|---|---|---|
| Move | Left stick | WASD (Shift to run: loud in water) |
| Turn | Right stick | Mouse |
| Jump | A or X | Space |
| Climb out of the water | Grab the pool edge or a ladder and pull | Space while facing the edge, or W on a ladder |
| Pick up | Grip | E |
| Use the held item (scan, pour, throw) | Trigger, or tip the canteen, or throw it | Left mouse |
| Fill the canteen | Hold it in the water and pull either trigger | Hold right mouse to dip it (crouch with Ctrl), then left mouse |
| Squeeze flashlight | Keep pumping the trigger: each squeeze gives a burst of light | Keep clicking left mouse |
| Backpack (4 items) | Let go of an item over your shoulder to put it in; grip there with an empty hand to take the last one out | B |
| Hold with both hands | Grab an item you're holding with your other hand too | |
| Give an item | Your teammate grabs it out of your hand | Your teammate presses E on it |
| Shove a teammate | Swing your hand into them | F |
| Drop | Let go of grip | Q |
| Drop a test dummy (see below) | Click both thumbsticks | Ctrl+Shift+P |
| Leave | Close the game | Esc twice |

## The level

1. **Start room.** The plaque on the wall explains the rules.
2. **Hall A.** All the pools are shallow, about knee-deep (0.65 m), so you wade rather than swim.
   The channel between Hall A and Hall B is deep (1.5 m), and the creature crawls through it. The staff room key sits on an island in the middle of the pool. Jump
   the stepping columns to get it, or wade through the water slowly. Falling in is loud, and so is
   wading fast.
3. **Staff room.** Unlock it with the key. Inside: two canteens, the lidar scanner on its charger,
   the distiller, and bottles to throw as decoys.
4. **Hall B, the dark sector.** The lights are out. Scan with the lidar to find the narrow
   beams. The softly glowing water in the north-west corner is the mineral water: kneel at the
   platform's edge and dip a canteen in it, then carry it along the beams without spilling and pour
   it into the generator's funnel. It takes 2 canteens. Distilled water starts it faster. Starting
   the generator makes noise; once it runs, the lights come on and its hum masks your noise nearby.
5. **Hall C.** Pull the lever on the west ledge (loud) to extend the pool cover across the pool so
   you can cross on dry ground. Or wade the whole way, if you're brave.
6. **Exit.** The level ends when everyone gets here.

## The mechanics in this demo

- **The creature** lives in the water, hunts by sound and is fast. It can't leave the water: dry
  ground is safe. Small noises make it come and investigate. A fall, or more noise near where it's
  investigating, makes it charge, with clicks that speed up into a death screech.
- **Going still** when it arrives: it only knows roughly where you are, so it searches by feel
  around that area. Even if you stay perfectly still there's about a 30% chance it finds you. Any
  movement at all gives you away: your head, your body, or your hands in the water. Afterwards it
  lingers nearby for a while.
- **Noise:** falling in (louder from higher up), wading (faster is louder), moving your hands in the
  water (only hand movement relative to your body counts), dropping or throwing things into the
  water, spilling the canteen into the pool, the lever, and the generator starting up. Re-entering
  the water while still dripping is louder. Every noise in the water draws ripple rings for
  everyone to see. In VR, the controllers rumble with the noise you make.
- **Lidar:** only the holder sees the dots. It sees through the water, and shows the creature in red
  and teammates in yellow. The battery drains while scanning and recharges at the charger once the
  power is on.
- **Getting caught:** it grabs you and kills you one of three ways: it pulls your head off, the
  spine stuck for a moment before it rips out; it tears you in half at the waist; or it tears you
  in half down the middle. If it's you, your view blurs as it pulls (head and spine) or cuts
  straight to black (torn apart). Your teammates see all of it. Holding on to the pool's edge or a
  ladder doesn't save you: with your feet over the pool you still count as in the water.
- **Dying:** everything you carried (in your hands and your backpack) goes into your bag, which
  floats where you died with a faint glow.
  - **Alone:** you're straight back at the last dry room you passed through. Go back for your bag
    and grab it to get your things back.
  - **With teammates still alive:** you're a ghost, where you died. You can move about, but you
    can't hold anything, you make no noise, and the creature ignores you; your view is tinted and
    teammates see you faint and see-through. You come back to life when a living teammate steps
    into a dry room (or the exit), or straight away if one carries your bag into a dry room. Your
    things come back to your backpack when you do.
  - **If everyone's down:** everyone comes back together at the last dry room the team reached.
    Progress (the door, the generator, the cover) stays.
  - The key, the canteens and the scanner go back where they started if they're ever lost
    (fallen out of reach, or left untouched for five minutes).
- **Feeding:** after a kill it feeds on the remains for 6 to 10 seconds and ignores every noise.
  That's your teammates' chance to run, or to grab your bag.
- **Canteen:** hold it in the water and pull either trigger to fill it. A prompt floats over the
  water, a bar shows it filling, and it pops and buzzes when it's full (and says what's in it).
  It has no physics: let go and it drops straight down and stands upright, or floats upright.
  Let go of it near the distiller and it goes onto the stand. It never spills: at the generator,
  hold it over the funnel and tip it or pull a trigger, and all of it goes in. Two full canteens
  start the generator.
- **Squeeze flashlight** (start room): a dynamo torch. Every pull of the trigger gives it a burst of
  charge that drains in a moment, so it only stays lit while you keep pumping, pulsing with each
  squeeze. The creature can't hear it.
- **Backpack:** everyone carries one for up to four items, and teammates can see it on your back.
  Whatever is in it stays with you; if you leave the game, it falls out where you were.
- **Two-handed holding:** grab an item you're already holding with your other hand as well.
- **The creature's target:** with several things making noise in the water, it goes for the
  nearest and doesn't turn back for farther ones until it gets there.
- **Test dummy:** click both thumbsticks in VR (Ctrl+Shift+P on desktop) to drop a plain grey
  player into the water in front of you. It has no mind of its own: it fidgets a little, so the
  creature finds it and you can watch the kills from outside. Only the host's creature hunts it,
  and everyone in the game sees it.

## Build the APK yourself

The project already has an Android export preset called **Quest** (`export_presets.cfg`). Once:

1. In Godot's AssetLib tab, install **Godot OpenXR Vendors plugin** 5.1 (it's not in the repo
   because it's 82 MB).
2. Install the Android SDK (platform 36, build-tools 36.1.0) and a JDK 17 or newer, and set their
   paths in Editor Settings, Export, Android. Download the 4.7.2 export templates (Editor, Manage
   Export Templates).
3. Make a keystore, and tell Godot about it with the environment variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
   `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` (or fill them in the preset, but don't commit them).
4. Export from Project, Export, or from a terminal:

```bash
godot --headless --path game --install-android-build-template --export-release "Quest" build/ripple-demo.apk
```

## Export a build for a friend who doesn't have Godot

Editor, Manage Export Templates, Download. Then Project, Export, add **Windows Desktop**, and
Export Project. Send them the `.exe` and `.pck` together.

## Automated tests

The game can drive itself to check that everything works:

```bash
godot --headless --path game -- --desktop --host --autotest=smoke
```

```bash
godot --headless --path game -- --desktop --host --autotest=mechanics
```

The mechanics test falls into the pool, gets searched and caught, unlocks the door, fills and pours
both canteens, starts the generator, extends the pool cover and reaches the exit. For co-op, run a
host and a client at the same time:

```bash
godot --headless --path game -- --desktop --host --autotest=net_host
```

```bash
godot --headless --path game -- --desktop --join=127.0.0.1 --autotest=net_client
```

Add `--fakevr` instead of `--desktop` to build the VR rig without a headset.

## Not done yet

- It hasn't been played on a real headset yet. The VR rig is tested by forcing VR mode without one.
- The generator and distiller are still simple shapes; real models for them are in review
  (Round 22 in ASSETS.md). The rest of the level is gray-box walls and pools with real props.
- The blur when you're killed uses the screen texture; it hasn't been checked on a real headset.
- Other players' suits follow their head and hands, but their legs don't step when they walk;
  the body glides.
- The creature's search shows as its search animation while it circles the area; there's no
  separate arm-reaching animation yet.
- The creature doesn't lunge at the pool edge, so dry ground is always safe.
- No voice chat yet (use Discord or similar).

## Files

- `core/` session, noise, water and game state. `level/` the level, built from rectangles at load
  time. `player/` VR rig, desktop rig, suits and avatars. `creature/` the creature. `items/` key, canteen,
  lidar, bottles, lever. `ui/` title screen, menus and on-screen text. `tests/` the automated tests.
- Third-party assets and their licenses: [CREDITS.md](CREDITS.md).
