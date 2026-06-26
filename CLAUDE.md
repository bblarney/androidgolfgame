# Birdie Blitz

A mobile **3D golf game** built in **Godot 4.6** (GDScript), targeting Android. Drag-to-shoot
gameplay over procedurally generated holes, a points economy, a pro shop with procedurally
generated equipment, and a clubhouse for managing your loadout.

> Note: `TECHNICAL_PLAN.md` is the original design doc and describes a **2D** prototype. The
> project has since moved to **3D** (RigidBody3D ball, Camera3D, terrain/sky shaders). Trust the
> code over that doc where they disagree.

## Running

Open the project in the Godot 4.6 editor and run. Main scene is `scenes/loading_screen.tscn`
(every scene transition routes through the loading screen via `SceneManager`).

## Architecture

### Autoloads (global singletons, see `project.godot` for load order)
- **SaveManager** — single JSON save at `user://save.json`. Owns all persisted state (points,
  inventory, loadout, stats, in-progress round, generated items). Has `_ensure_*` migrations that
  backfill new fields into old saves on load. Auto-saves on every mutation.
- **EquipmentManager** — loads `data/clubs.json` + `data/balls.json`, merges in procedurally
  generated items stored in the save, and is the single lookup-by-id point for all gear. Handles
  equip/own/loadout queries. Emits `club_changed`.
- **GameState** — current round/session: seed, hole number, mode (`practice`/`9`/`18`), scores.
  Owns deterministic per-round logic (biome layout, par rolls) derived from the round seed.
- **SceneManager** — central scene router; `goto(path)` always goes through the loading screen.

### Scenes (`scenes/`)
`loading_screen` (boot) → `main_menu` → `hole` (core gameplay) / `clubhouse` / `pro_shop` /
`tutorial`.

### Core gameplay (`scripts/`, scene = `hole.tscn`)
- **hole_manager.gd** — game-logic controller; wires ball, camera, input, HUD, scorecard.
- **hole_generator.gd** — procedural 3D hole generation from `GameState.get_hole_seed()`:
  spine/fairway/terrain mesh, hazards, green, surrounding apron landscape, biome theming.
- **ball.gd** — `RigidBody3D`; surface friction, rest detection, hazard/safe-position tracking.
- **input_handler.gd** — drag-to-shoot + camera rotate; emits `shot_taken` / `aim_changed`.
- **camera_controller.gd**, **aim_indicator.gd**, **club_visual.gd**, **club_selector.gd** — view/HUD.
- **item_generator.gd** — pure procedural generator for pro-shop clubs/balls (rarity-weighted).
- **item_visuals.gd**, **pro_shop.gd**, **clubhouse.gd**, **scorecard.gd**, **scorebug.gd** — shop/UI.

### Data (`data/`)
`clubs.json`, `balls.json` — base equipment stats. `loot_tables.json` — mystery box rarity weights.
**Procedurally generated items are NOT in these files** — their full definitions live in the save
(`generated_clubs`/`generated_balls`) and are merged in by EquipmentManager on boot.

### Shaders (`shaders/`)
`terrain`, `sky`, `flag`, `ball`, `wind` — visual theming for the 3D course.

## Key conventions
- **Determinism:** holes, biomes, and par are pure functions of the round seed + hole number, so a
  round is reproducible and survives app close/reopen. Code that reproduces a generator roll
  outside the generator (e.g. `GameState.get_par_for_hole`) must keep its thresholds in sync with
  the generator — see the comments there.
- **Items are always looked up by id** through EquipmentManager; never branch on whether an item is
  hand-authored vs. generated.
- **Save migrations** go in SaveManager's `_ensure_*` helpers so existing players aren't broken.
- Comments in this codebase explain *why*, not *what* — match that style.
