# 🏌️ Birdie Blitz

A mobile **3D golf game** built in **Godot 4.6** (GDScript), targeting Android. Drag to aim, pull
back to set your power, and let it fly across procedurally generated holes. Earn points, hit the pro
shop for procedurally generated clubs and balls, tune your loadout in the clubhouse, and chase
birdies through full tournaments.

![Birdie Blitz gameplay](Screenshot%202026-06-23%20120821.png)

## Features

- **Drag-to-shoot 3D gameplay** — a physics-driven `RigidBody3D` ball over fully 3D terrain, with
  surface friction, hazards, and a sleek dart-style aim/power indicator.
- **Procedurally generated holes** — fairway spine, terrain mesh, hazards, greens, and surrounding
  landscape are generated from a round seed. Holes are *deterministic*, so a round is fully
  reproducible and survives closing and reopening the app.
- **Biome theming** — each hole is themed via custom terrain, sky, flag, ball, and wind shaders.
- **Points economy & pro shop** — spend earned points on rarity-weighted, procedurally generated
  clubs and balls, each with their own stats and visuals.
- **Clubhouse loadout** — own a bag of gear and manage which clubs and ball you bring to the course.
- **Game modes** — practice, 9-hole, and 18-hole rounds, plus tournament play.
- **Procedural audio** — upbeat menu music and club/ball sound effects with in-game volume settings.

## Getting Started

### Requirements

- [Godot 4.6](https://godotengine.org/) (Mobile renderer)

### Run it

1. Clone the repo:
   ```bash
   git clone https://github.com/bblarney/androidgolfgame.git
   ```
2. Open the project folder in the Godot 4.6 editor.
3. Press **Play**. The game boots into `scenes/loading_screen.tscn`; every scene transition routes
   through the loading screen via `SceneManager`.

The project is configured for portrait, mobile rendering, and exports to Android.

## Architecture

The game is organized around a handful of global autoload singletons plus per-scene controllers.

### Autoloads (global singletons)

| Singleton | Responsibility |
|---|---|
| **SaveManager** | Single JSON save at `user://save.json`. Owns all persisted state (points, inventory, loadout, stats, in-progress round, generated items) and auto-saves on every mutation. Includes migrations that backfill new fields into old saves. |
| **AudioManager** | Procedural ambient music, sound effects, and volume settings. |
| **EquipmentManager** | Loads base equipment from `data/`, merges in procedurally generated items from the save, and is the single lookup-by-id point for all gear. |
| **GameState** | Current round/session: seed, hole number, mode, scores, and deterministic per-round logic (biome layout, par rolls). |
| **TournamentManager** | Tournament progression and state. |
| **SceneManager** | Central scene router; `goto(path)` always passes through the loading screen. |

### Scenes (`scenes/`)

```
loading_screen (boot) → main_menu → hole (core gameplay)
                                   → clubhouse
                                   → pro_shop
                                   → tournament_hub
                                   → tutorial
```

### Core gameplay (`scripts/`, scene = `hole.tscn`)

- **hole_manager.gd** — game-logic controller; wires ball, camera, input, HUD, and scorecard.
- **hole_generator.gd** — procedural 3D hole generation from the hole seed.
- **ball.gd** — `RigidBody3D` ball with surface friction, rest detection, and hazard tracking.
- **input_handler.gd** — drag-to-shoot and camera rotation.
- **camera_controller.gd**, **aim_indicator.gd**, **club_visual.gd**, **club_selector.gd** — view/HUD.
- **item_generator.gd** — pure procedural generator for pro-shop clubs and balls.
- **pro_shop.gd**, **clubhouse.gd**, **scorecard.gd**, **scorebug.gd**, **item_visuals.gd** — shop/UI.

### Data (`data/`)

`clubs.json` and `balls.json` hold base equipment stats; `loot_tables.json` holds mystery-box
rarity weights. Procedurally generated items live in the save file (not in `data/`) and are merged
in by EquipmentManager on boot.

### Shaders (`shaders/`)

`terrain`, `sky`, `flag`, `ball`, and `wind` provide the visual theming for the 3D course.

## Project Layout

```
golfgame/
├── autoloads/     # Global singletons (Save, Audio, Equipment, GameState, Tournament, Scene)
├── scenes/        # Godot scenes (loading, menu, hole, clubhouse, pro shop, tournament, tutorial)
├── scripts/       # Gameplay and UI controllers
├── shaders/       # Terrain, sky, flag, ball, wind shaders
├── data/          # Base equipment + loot tables (JSON)
├── assets/        # Fonts and UI theme
└── project.godot  # Godot project configuration
```

## Key Conventions

- **Determinism:** holes, biomes, and par are pure functions of the round seed plus hole number.
  Any code that reproduces a generator roll outside the generator must keep its thresholds in sync.
- **Items are always looked up by id** through EquipmentManager — never branch on whether an item
  is hand-authored or generated.
- **Save migrations** go in SaveManager's `_ensure_*` helpers so existing players aren't broken.
- Comments explain *why*, not *what*.

---

Built with [Godot Engine](https://godotengine.org/).
