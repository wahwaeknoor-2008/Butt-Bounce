# BUTT BOUNCE — Rooftop Rush

A 3D rooftop parkour prototype built with **Godot 4** and GDScript.

Charge a butt-bounce, launch across rooftops, steer through the air, hit spring platforms, avoid hazards, and reach the goal.

## Getting started

1. Install Godot 4 (the project was previously developed with Godot 4.7.2).
2. Download or clone this repository.
3. Open Godot Project Manager and choose **Import**.
4. Select the repository's `project.godot` file.
5. Open the project, wait for Godot to import the 3D and audio assets, and press **F5** to run the main scene.

The configured main scene is `scenes/rooftop_rush.tscn`.

## Controls

| Input | Action |
|---|---|
| W / A / S / D or arrow keys | Move and steer |
| Hold Space | Sit down and charge the butt-bounce |
| Release Space | Launch; longer charge gives a higher bounce |
| R | Restart / respawn |

After a bounce, the character lands on his butt and automatically stands up again.

## Character animation

The visible player now uses the uploaded character scene at `assets/characters/butt_bouncer.tscn`. The model has a simple grouped mesh rather than a skeleton, so the whole character is tilted as one piece for the seated bounce pose.

- Hold Space or left mouse to charge the first bounce
- Release to launch forward and upward
- The character rotates backward into a butt-first airborne pose
- On ground impact, the fart sound plays and the character automatically rebounds forward
- WASD / arrow keys steer the next rebound direction

## Project structure

```text
BUTT-BOUNCE-Rooftop-Rush/
├── project.godot
├── README.md
├── LICENSE
├── ASSET-LICENSING.md
├── .gitignore
├── scenes/
│   ├── rooftop_rush.tscn
│   ├── player.tscn
│   └── world.tscn
├── scripts/
│   ├── level.gd
│   ├── player.gd
│   ├── platform.gd
│   └── hazard.gd
└── assets/
    ├── audio/
    │   ├── fail_sound.mp3
    │   └── launch_fart.mp3
    └── characters/
        ├── parkour_character.glb
        └── optional/
```

## Current prototype features

- Third-person follow camera and in-game HUD
- Ground movement with acceleration and braking
- Hold-to-charge, release-to-launch bounce mechanic
- Charge-time-based launch height
- Air steering and air braking
- Procedural idle, run, jump, sit, landing and stand-up poses
- Butt-first landing and automatic recovery
- Respawn and checkpoint support in the player controller
- Launch and fail sound effects
- Rooftop world scene, goal area, platforms and hazard script
- Six additional unrigged character prototypes in `assets/characters/optional/`

## Open source and assets

The **project source code** is licensed under the MIT License; see `LICENSE`.

The MIT license does **not** automatically cover the 3D models or audio files. Asset ownership and redistribution terms need to be confirmed separately before publicly redistributing those files. See `ASSET-LICENSING.md`.

## Development status

This is an early playable prototype. The current character animation update is code-driven and should be tested in Godot 4.7.2 for pose alignment, collisions, and timing before release.


## Rooftop environment and obstacles

The rooftop route now includes additional moving transfer platforms and swinging wrecking-ball hazards. Existing crumble and spring pads activate when the player touches them. The environment adds animated extractor fans, rooftop pipework, exhaust vents, warning beacons, safety rails, softer sky ambient lighting, and reduced distance fog.

**Bounce controls:** hold Space to crouch and charge; release Space to launch. Use WASD or the arrow keys to steer. Touching a swinging ball sends the player back to the checkpoint.


## Coin collection

The 27 rooftop coins are collectible. Touch a coin with the player to collect it; the coin disappears, a floating `+1` pickup indicator appears, and the top-right HUD counter updates. Coins spin and hover to make them easier to spot.
