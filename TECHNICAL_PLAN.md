# Golf Game — Technical Implementation Plan

## Tech Stack
- **Engine:** Godot 4.x
- **Language:** GDScript
- **Platform:** Android (APK via Google Play)
- **Storage:** Local JSON save files (no backend until IAP added)
- **Graphics:** Godot 2D primitives + ColorRect/Polygon2D (no art assets needed to start)

---

## Project Structure

```
golf_game/
├── scenes/
│   ├── main_menu.tscn
│   ├── course_select.tscn
│   ├── hole.tscn          # core game scene
│   ├── scorecard.tscn
│   ├── shop.tscn
│   └── mystery_box.tscn
├── scripts/
│   ├── ball.gd
│   ├── club.gd
│   ├── hole_generator.gd  # procedural hole generation
│   ├── hole_manager.gd
│   ├── input_handler.gd
│   ├── camera_controller.gd
│   ├── equipment_manager.gd
│   ├── points_manager.gd
│   ├── mystery_box.gd
│   └── save_manager.gd
├── data/
│   ├── clubs.json         # club stat definitions
│   ├── balls.json         # ball stat definitions
│   └── loot_tables.json   # mystery box rarity weights
└── autoloads/             # global singletons
    ├── GameState.gd       # current session data
    ├── SaveManager.gd
    └── EquipmentManager.gd
```

---

## Scene Hierarchy: `hole.tscn`

```
Hole (Node2D)
├── Course (StaticBody2D)
│   ├── Fairway (Polygon2D + CollisionPolygon2D)
│   ├── Rough (Polygon2D + CollisionPolygon2D)
│   ├── Sand (Polygon2D + CollisionPolygon2D)
│   ├── Water (Area2D)           # hazard trigger
│   ├── OOB (Area2D)            # out of bounds trigger
│   └── Cup (Area2D)            # hole detection
├── Ball (RigidBody2D)
│   ├── Sprite (ColorRect, simple white circle)
│   └── CollisionShape2D
├── Flag (AnimatedSprite2D)
├── Camera (Camera2D)
├── HUD (CanvasLayer)
│   ├── StrokeCounter
│   ├── PowerBar
│   ├── ClubSelector
│   └── AimArrow
└── HoleManager (Node)          # game logic controller
```

---

## 1. Ball Physics

**Node type:** `RigidBody2D`

**Key properties:**
```
# Applied per surface via PhysicsMaterial
Fairway:  friction = 0.6, bounce = 0.2
Rough:    friction = 0.9, bounce = 0.1
Sand:     friction = 1.5, bounce = 0.05
Green:    friction = 0.3, bounce = 0.1
```

**Ball stats (modified by equipped ball):**
```gdscript
var distance_modifier: float   # multiplies impulse force
var air_resistance: float      # linear_damp when airborne
var roll_resistance: float     # linear_damp when on ground
```

**Physics flow:**
1. Ball is `RigidBody2D` with gravity enabled
2. Track if ball is grounded via `RaycastCast2D` pointing down
3. When grounded: set `linear_damp` to surface friction value
4. When airborne: set `linear_damp` to `air_resistance`
5. Ball comes to rest when `linear_velocity.length() < 5.0`

---

## 2. Input Handler (Drag-to-Shoot)

```
Touch down on ball → start drag
Drag backward → draw aim arrow + power indicator
Release → apply impulse, increment stroke counter
```

**Implementation logic:**
```gdscript
# input_handler.gd
var drag_start: Vector2
var is_dragging: bool = false
var MAX_DRAG_DISTANCE: float = 200.0

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed and ball_touched(event.position):
            drag_start = event.position
            is_dragging = true
        elif not event.pressed and is_dragging:
            shoot(event.position)
            is_dragging = false

    if event is InputEventScreenDrag and is_dragging:
        update_aim_indicator(event.position)

func shoot(drag_end: Vector2):
    var drag_vector = drag_start - drag_end        # reversed = shoot forward
    var power = clamp(drag_vector.length(), 0, MAX_DRAG_DISTANCE) / MAX_DRAG_DISTANCE
    var direction = drag_vector.normalized()
    var force = direction * power * club.power * ball.distance_modifier
    ball.apply_central_impulse(force)
    stroke_count += 1
```

**Aim indicator:** Draw a dotted line from ball in shoot direction, length proportional to power. A colored arc shows the accuracy spread (wider = less accurate club).

**Accuracy/spread:** On release, add a small random angle offset within `±club.accuracy_spread` degrees. Wide spread for Driver, near-zero for Putter.

---

## 3. Club System

Each club has 4 stats:

| Club | Power | Accuracy Spread | Spin | Best Use |
|------|-------|----------------|------|----------|
| Driver | 100% | ±12° | low | Tee shots |
| 3-Wood | 85% | ±9° | low | Fairway distance |
| Iron | 65% | ±5° | medium | Approach |
| Wedge | 40% | ±3° | high | Short game |
| Putter | 15% | ±0.5° | none | Green only |

**Spin mechanic (simplified):** Spin adds lateral velocity over time while airborne — curves the ball's path. High spin clubs can bounce/roll differently on landing. Implemented as a `_physics_process` force applied while the ball is in flight.

**Club data (`clubs.json`):**
```json
{
  "driver_default": {
    "id": "driver_default",
    "name": "Starter Driver",
    "rarity": "common",
    "power": 1.0,
    "spread": 12.0,
    "spin": 0.1,
    "description": "Reliable off the tee."
  }
}
```

---

## 4. Ball Equipment System

Ball stats modify physics, not input:

```json
{
  "ball_default": {
    "id": "ball_default",
    "name": "Starter Ball",
    "rarity": "common",
    "distance_modifier": 1.0,
    "air_resistance": 0.05,
    "roll_resistance": 0.4
  },
  "ball_rocket": {
    "id": "ball_rocket",
    "name": "Rocket Ball",
    "rarity": "rare",
    "distance_modifier": 1.35,
    "air_resistance": 0.02,
    "roll_resistance": 0.4
  }
}
```

---

## 5. Procedural Hole Generation

Every hole is unique — generated at runtime from a seed. No two rounds are the same. No `courses.json`.

### Seed System

```gdscript
# Each hole gets a seed derived from: round_seed + hole_number
# Reproducible: same seed always produces same hole (useful for daily challenge later)
var round_seed: int = randi()
var hole_seed: int = round_seed + hole_number
```

The round seed is stored in the save file so the current round survives app close/reopen.

### Generation Pipeline (`hole_generator.gd`)

```
generate_hole(seed) →
  1. seed_rng(seed)
  2. roll_hole_type()       → shape template (straight / dogleg-left / dogleg-right / S-curve)
  3. generate_spine()       → list of waypoints from tee to green
  4. build_fairway()        → polygon corridor around spine, variable width
  5. build_rough()          → wider polygon border around fairway
  6. place_hazards()        → water/sand scattered along spine, never fully blocking
  7. place_green()          → circular smooth-friction zone around cup
  8. calculate_par()        → based on spine length + hazard count
  9. spawn_terrain_nodes()  → instantiate all StaticBody2D / Area2D nodes into the scene
```

### Spine Generation

The spine is a list of 3–6 Vector2 waypoints from tee to cup. Each shape template constrains how waypoints are placed:

| Template | Waypoints | Description |
|----------|-----------|-------------|
| Straight | 3 | Tee → mid offset → cup, slight curve |
| Dogleg-left | 4 | Sharp left bend at ~40% length |
| Dogleg-right | 4 | Sharp right bend at ~40% length |
| S-curve | 5–6 | Two opposing bends, longer holes |

```gdscript
func generate_spine(template: String) -> Array[Vector2]:
    var points: Array[Vector2] = []
    var tee = Vector2(150, rng.randf_range(400, 600))
    points.append(tee)

    match template:
        "straight":
            points.append(tee + Vector2(rng.randf_range(600, 900), rng.randf_range(-200, 200)))
        "dogleg_left":
            var elbow = tee + Vector2(rng.randf_range(400, 600), rng.randf_range(-100, 100))
            points.append(elbow)
            points.append(elbow + Vector2(rng.randf_range(300, 500), rng.randf_range(-300, -150)))
        "dogleg_right":
            var elbow = tee + Vector2(rng.randf_range(400, 600), rng.randf_range(-100, 100))
            points.append(elbow)
            points.append(elbow + Vector2(rng.randf_range(300, 500), rng.randf_range(150, 300)))
        "s_curve":
            # two elbows in opposing directions
            ...

    points.append(points[-1] + Vector2(rng.randf_range(100, 200), 0))  # cup at end
    return points
```

### Fairway Construction

Walk each spine segment and extrude left/right by a variable half-width to build a polygon:

```gdscript
func build_fairway(spine: Array[Vector2]) -> PackedVector2Array:
    var left_edge: Array[Vector2] = []
    var right_edge: Array[Vector2] = []

    for i in range(spine.size() - 1):
        var segment = spine[i + 1] - spine[i]
        var normal = Vector2(-segment.y, segment.x).normalized()
        var width = rng.randf_range(120, 220)   # narrow or wide fairway
        left_edge.append(spine[i] + normal * width)
        right_edge.append(spine[i] - normal * width)

    # combine left + reversed right → closed polygon
    var polygon = PackedVector2Array(left_edge + right_edge.reverse())
    return polygon
```

Rough is built identically with a larger width multiplier (1.8×) layered behind fairway.

### Hazard Placement

Hazards are placed at random points along the spine at 30–75% of the total length (never near tee or cup):

```gdscript
func place_hazards(spine: Array[Vector2]) -> Array[Dictionary]:
    var hazards = []
    var num_water = rng.randi_range(0, 2)
    var num_sand  = rng.randi_range(0, 3)

    for i in range(num_water):
        var t = rng.randf_range(0.3, 0.75)        # position along spine
        var pos = spine_interpolate(spine, t)
        var offset = rng.randf_range(60, 130)      # how far off-center
        var side = 1 if rng.randf() > 0.5 else -1
        hazards.append({ "type": "water", "position": pos + perpendicular(spine, t) * side * offset, "radius": rng.randf_range(60, 120) })

    for i in range(num_sand):
        # same logic, smaller radius, can be on fairway edge
        ...

    return hazards
```

Hazards are circular `Area2D` nodes. Water triggers penalty + reset; sand is a `StaticBody2D` with high-friction PhysicsMaterial.

### Par Calculation

```gdscript
func calculate_par(spine: Array[Vector2], hazard_count: int) -> int:
    var length = spine_total_length(spine)
    var base_par = 3 if length < 700 else (4 if length < 1200 else 5)
    # hazards don't change par — they just make it harder to achieve
    return base_par
```

### Hazard Handling

- **Water / OOB:** `Area2D.body_entered` → +1 penalty stroke, ball resets to last recorded safe position (updated every 0.5s while ball is on fairway/rough/green)
- **Sand:** No penalty, PhysicsMaterial with friction = 1.5, bounce = 0.05
- **Cup:** `Area2D.body_entered` → hole complete only if `ball.linear_velocity.length() < 80`

### What Changes Each Hole

| Element | Randomized |
|---------|-----------|
| Hole shape | Straight / dogleg-left / dogleg-right / S-curve |
| Fairway width | 120–220px (narrow to wide) |
| Fairway path curve | Spine waypoint offsets |
| Water hazards | 0–2, random position + size |
| Sand bunkers | 0–3, random position + size |
| Par | 3 / 4 / 5 based on generated length |
| Total length | ~500–1500px |

---

## 6. Camera Controller

```gdscript
# camera_controller.gd
# Phase 1: Show full hole on load (zoom out, pan to overview)
# Phase 2: After player touches ball, follow ball in flight
# Phase 3: Ball at rest, zoom in to ball position

enum CameraState { OVERVIEW, FOLLOWING, RESTING }

func _physics_process(delta):
    match state:
        CameraState.FOLLOWING:
            position = position.lerp(ball.position, 8 * delta)
        CameraState.RESTING:
            position = position.lerp(ball.position, 3 * delta)
```

---

## 7. Points Economy

Points are earned per hole based on score vs par:

| Result | Points |
|--------|--------|
| Hole-in-one | 500 |
| Eagle (-2) | 300 |
| Birdie (-1) | 150 |
| Par (0) | 75 |
| Bogey (+1) | 25 |
| Double Bogey (+2) | 10 |
| Worse | 5 |

Bonus multipliers:
- Complete all holes in a round: +20%
- No penalty strokes all round: +15%
- Consecutive birdies: +50pts each

Points accumulate in `SaveManager` and persist between sessions. No expiry.

---

## 8. Mystery Box System

**Three box tiers (costs in points):**

| Box | Cost | Rarity Pool |
|-----|------|-------------|
| Bronze Box | 500 pts | Common 70%, Uncommon 25%, Rare 5% |
| Silver Box | 1500 pts | Uncommon 55%, Rare 35%, Legendary 10% |
| Gold Box | 4000 pts | Rare 50%, Legendary 40%, Mythic 10% |

**Loot table (`loot_tables.json`):**
```json
{
  "bronze": {
    "common":    { "weight": 70, "pool": ["driver_worn", "ball_range"] },
    "uncommon":  { "weight": 25, "pool": ["iron_precision", "ball_longrange"] },
    "rare":      { "weight": 5,  "pool": ["driver_eagle", "ball_rocket"] }
  }
}
```

**Weighted random selection:**
```gdscript
func roll_loot(box_id: String) -> String:
    var table = loot_tables[box_id]
    var roll = randf() * 100.0
    var cumulative = 0.0
    for rarity in table:
        cumulative += table[rarity].weight
        if roll <= cumulative:
            var pool = table[rarity].pool
            var item_id = pool[randi() % pool.size()]
            return item_id
```

**Duplicate handling:** If player already owns the item, convert to 25% of box cost in points (partial refund).

**IAP hook:** Box purchases point to a `purchase_box(box_id)` function. Initially deducts points locally. When you add Google Play Billing, this function is where you swap in the real payment flow — the rest of the system doesn't change.

---

## 9. Save System

Single JSON file at `user://save.json`:

```json
{
  "version": 1,
  "points": 1250,
  "lifetime_points": 8400,
  "equipped": {
    "club": "driver_default",
    "ball": "ball_default"
  },
  "inventory": ["driver_default", "ball_default", "iron_precision"],
  "stats": {
    "rounds_played": 12,
    "holes_completed": 47,
    "best_round_score": -3,
    "total_strokes": 612,
    "eagles": 2,
    "birdies": 18
  },
  "current_round_seed": 849201748,
  "current_hole": 4
}
```

`SaveManager` is an **autoload singleton** — always accessible, auto-saves after each hole and each mystery box open.

---

## 10. Build & Release Pipeline

1. **Development:** Godot editor on PC, test in Godot's built-in emulator
2. **Android testing:** Enable USB debugging on phone, deploy direct from Godot via one-click Android export
3. **Requires:** Android Studio installed (for SDK/NDK), keystore file for signing
4. **Play Store:** Upload signed APK/AAB, set up internal test track first
5. **IAP (phase 2):** Add `godot-android-plugin-google-play-billing` plugin, implement in `purchase_box()`

---

## Implementation Order

| Phase | What | Why |
|-------|------|-----|
| 1 | Ball physics + drag-to-shoot input | Core gameplay feel |
| 2 | One hardcoded hole, camera, cup detection | Playable loop |
| 3 | Scorecard + points calculation | Feedback/reward |
| 4 | Club/ball stat system + equipment switching | Differentiation |
| 5 | Procedural hole generator | Infinite unique content |
| 6 | Save system | Persistence |
| 7 | Mystery box + shop UI | Progression loop |
| 8 | Main menu + course select UI | Polish |
| 9 | Android export + Play Store setup | Ship |
| 10 | IAP integration | Monetization |
