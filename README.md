# BUTT BOUNCE — Rooftop Rush

A small 3D rooftop parkour prototype built with **Godot 4** and GDScript. Charge a bounce, launch yourself across rooftops, steer in the air, hit spring platforms, and reach the goal.

## Getting started

1. Install Godot 4 (the project was previously being worked on with Godot 4.7.2).
2. Download or clone this repository.
3. Open Godot Project Manager and choose **Import**.
4. Select this folder's `project.godot` file.
5. Open the project, wait for Godot to import the GLB and audio assets, and press **F6** only for a selected scene or **F5** to run the main scene.

The configured main scene is `scenes/rooftop_rush.tscn`.

## Controls

| Input | Action |
|---|---|
| W / A / S / D or arrow keys | Move and steer |
| Hold Space | Charge the bounce while grounded |
| Release Space | Launch the bounce; a longer charge gives a stronger launch |
| R | Restart / respawn |

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
        └── optional/  # six unrigged character prototypes
```

## Current prototype features

- Third-person follow camera and in-game HUD
- Ground movement with acceleration and braking
- Hold-to-charge, release-to-launch bounce mechanic
- Air steering and air braking
- Respawn and checkpoint support in the player controller
- Launch and fail sound effects
- Rooftop world scene, goal area, platforms and hazard script
- Six additional unrigged character prototypes in `assets/characters/optional/`

The optional characters are prototype models only. They do not currently form a playable character-selection system and are not rigged or animated.

## Open source and assets

The **project source code** is licensed under the MIT License; see `LICENSE`.

The MIT license does **not** automatically cover the 3D models or audio files. Asset ownership and redistribution terms need to be confirmed separately before publicly redistributing those files. See `ASSET-LICENSING.md`.

## Development status

This is a prototype project. It has been reconstructed from the latest saved project bundle from the earlier development session. The project files and internal `res://` references have been checked for completeness, but Godot is not installed in the packaging environment, so a fresh Godot editor import and gameplay test have not been performed here. Please open it in Godot 4 and report any import or parser error before tagging a release.
