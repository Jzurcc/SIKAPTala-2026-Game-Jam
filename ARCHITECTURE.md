# SIKAPTala — Architecture & Extensibility Guide

> **A comprehensive technical reference detailing the architectural design, system patterns, module depths, and extensibility playbooks for SIKAPTala.**

---

## Table of Contents
1. [Architectural Transformation Overview](#1-architectural-transformation-overview)
2. [Detailed Record of Remediation Changes](#2-detailed-record-of-remediation-changes)
3. [Core Architectural Principles](#3-core-architectural-principles)
4. [Deepened Subsystem Pipelines](#4-deepened-subsystem-pipelines)
   - [Movement & Rule Resolution Engine](#movement--rule-resolution-engine)
   - [Transactional Turn Pipeline](#transactional-turn-pipeline)
   - [Spatial Tag Registry & Overrides](#spatial-tag-registry--overrides)
5. [Step-by-Step Extensibility Playbooks](#5-step-by-step-extensibility-playbooks)
   - [Playbook 1: Adding a New Tag](#playbook-1-adding-a-new-tag)
   - [Playbook 2: Adding a New Object / Prop / Hazard](#playbook-2-adding-a-new-object--prop--hazard)
   - [Playbook 3: Adding a New AI Entity Behavior](#playbook-3-adding-a-new-ai-entity-behavior)
   - [Playbook 4: Reworking UI & Subtext Interactions](#playbook-4-reworking-ui--subtext-interactions)
6. [GDScript 4 Best Practices & Engineering Standards](#6-gdscript-4-best-practices--engineering-standards)

---

## 1. Architectural Transformation Overview

### Before: The Monolithic & Circular Architecture
Prior to remediation, the codebase suffered from circular God-Autoloads, quadruplicated tile-slicing logic, pervasive duck-typing, scattered collision heuristics, and monolithic scripts exceeding 500 lines:

```mermaid
graph TD
    GS_OLD[GameState God-Autoload<br/>7 Unrelated Responsibilities] <--> GR_OLD[Grid God-Autoload<br/>Spatial + Spawner + Scene Manipulation]
    GS_OLD --> P_OLD[Player.gd: 559 lines<br/>Movement + Tutorial UI + Dialogue + Drawing + Collision]
    GS_OLD --> TDM_OLD[TagDisplayManager: 438 lines<br/>Hover + CPU Pixel Peeking + Drag Physics]
    GR_OLD --> OBJ_OLD[Fragmented Objects<br/>WorldObject / SubtextProp / TileToObject / Entity]
```

### After: Deep Modules, Single Interfaces & Atomic Transactions
The codebase has been refactored into deep domain modules with high locality and testable seams:

```mermaid
graph TD
    subgraph Core Singletons & Services
        GS[GameState<br/>Transactional Turn Pipeline & Undo Engine]
        GR[Grid<br/>Spatial Registry & Atomic Step Rule Engine]
        AM[AudioManager<br/>BGM Playlist, SFX, Bus Filters]
        SM[SceneManager<br/>Transitions & Screen Fading]
        TC[TileConverter<br/>Atlas-to-Sprite & Runtime Conversions]
    end

    subgraph Domain Hierarchy
        GB[GridBody2D Base Class<br/>Multi-cell Snapping, Push Physics, Death]
        GB --> P[Player<br/>Input, Facing, Animation Dispatch]
        GB --> E[Entity<br/>Turn AI, Patrol, Chase, Flee, Death]
        GB --> WO[WorldObject / Prop<br/>Light Objects, Beads, Obstacles]
        GB --> SP[SubtextProp<br/>Multi-tile Textured Props]
        TTL[TaggedTileLayer<br/>Self-Registering TileMapLayer]
    end

    subgraph Decoupled Subsystems
        P --> TUTC[TutorialController<br/>CanvasLayer, Typewriter, Step Input]
        P --> DB[DialogueBubble<br/>Text Wrapping, Bubble Sway, ID Dialogues]
        TDM[TagDisplayManager<br/>Hover Detection & Tile Highlights] --> DC[DragController<br/>Spring Physics, Snapping, Spatial Tag Swaps]
    end
```

---

## 2. Detailed Record of Remediation Changes

The table below summarizes every architectural issue diagnosed in [`code review.md`](code%20review.md) and how it was remediated:

| Issue in Review | Root Cause | Remediated Solution | Key Files |
|---|---|---|---|
| **§1. Autoload Entanglement** | `GameState` managed Audio, Transitions, Scene Tree Injection, Turn Scheduling, and Collision. | Audio extracted to `AudioManager`; scene transitions extracted to `SceneManager`. Recursive string scraping removed. | [`audio_manager.gd`](scripts/services/audio_manager.gd)<br>[`scene_manager.gd`](scripts/services/scene_manager.gd)<br>[`game_state.gd`](scripts/core/game_state.gd) |
| **§1. Grid Scene Manipulation** | `Grid` spawned nodes, deleted tile cells, and managed live scene nodes. | Isolated into `TileConverter` utility. `Grid` is now a pure spatial index. | [`grid.gd`](scripts/core/grid.gd)<br>[`tile_converter.gd`](scripts/services/tile_converter.gd) |
| **§2.A Tile-Slicing Duplication** | 5 scripts duplicated `TileSetAtlasSource` texture extraction. | Consolidated into `TileConverter.build_sprite_from_tile()`. Deleted `tile_to_object.gd`. | [`tile_converter.gd`](scripts/services/tile_converter.gd) |
| **§2.B Duplicate TileMap Scripts** | `wall_layer.gd`, `floor_layer.gd`, `locked_wall_layer.gd` were 100% copy-pasted. | Unified into `TaggedTileLayer` with exported default tags and self-registration. | [`tagged_tile_layer.gd`](scripts/objects/tagged_tile_layer.gd) |
| **§2.C Fragmented Object Hierarchy** | `world_object`, `subtext_prop`, `entity` separately implemented push and occupancy. | Unified base class `GridBody2D` handles multi-cell occupancy, movement tweens, and push physics. | [`grid_body_2d.gd`](scripts/core/grid_body_2d.gd)<br>[`world_object.gd`](scripts/objects/world_object.gd)<br>[`subtext_prop.gd`](scripts/objects/subtext_prop.gd)<br>[`entity.gd`](scripts/entities/entity.gd) |
| **§3. Runtime Crash Traps** | Missing `unregister_object`, missing `register_tilemap`, multi-tile vacate bug. | Added symmetrical unregistering; multi-cell occupancy looping in `_vacate_cells()` / `_occupy_cells()`. | [`game_state.gd`](scripts/core/game_state.gd)<br>[`grid_body_2d.gd`](scripts/core/grid_body_2d.gd) |
| **§4. Dual Tag Typing** | Split between 7-item enum in `grid.gd` and raw string literals in other files. | Created canonical `TagDef` with 15 tags and bidirectional conversion helpers. | [`tag_def.gd`](scripts/core/tag_def.gd)<br>[`tag_label.gd`](scripts/ui/tag_label.gd) |
| **§5. God-File: `player.gd`** | 559 lines handling tutorial sequences, dialogue UI, sway, and drawing. | Extracted `TutorialController` and `DialogueBubble`. `player.gd` reduced by 56% to ~246 lines. | [`player.gd`](scripts/player/player.gd)<br>[`tutorial_controller.gd`](scripts/player/tutorial_controller.gd)<br>[`dialogue_bubble.gd`](scripts/player/dialogue_bubble.gd) |
| **§5. CPU Pixel Peeking** | `img.get_pixel()` called per-frame on the CPU in `_process`. | Replaced with discrete integer grid cell queries (`get_cell_source_id`). | [`tag_display_manager.gd`](scripts/ui/tag_display_manager.gd) |
| **§5. Drag Monolith** | `tag_display_manager.gd` mixed hover display with drag springs and swap logic. | Extracted `DragController`. Reduced display manager to 261 lines. | [`drag_controller.gd`](scripts/ui/drag_controller.gd)<br>[`tag_display_manager.gd`](scripts/ui/tag_display_manager.gd) |
| **§6. Incomplete Undo System** | Missing `layer_tags`, missing `regions`, destroyed tiles lost forever, dead entities lost to `queue_free()`. | Built typed `UndoSnapshot`, deferred death via `GameState.mark_dead()`, and tile restoration on undo. | [`game_state.gd`](scripts/core/game_state.gd)<br>[`grid_body_2d.gd`](scripts/core/grid_body_2d.gd)<br>[`tile_converter.gd`](scripts/services/tile_converter.gd) |
| **Deepening 1: Rule Engine** | Movement and collision checks duplicated across player, entity, and gamestate. | Unified into `Grid.resolve_step(actor, dir)` returning structured resolution results. | [`grid.gd`](scripts/core/grid.gd)<br>[`player.gd`](scripts/player/player.gd)<br>[`entity.gd`](scripts/entities/entity.gd) |
| **Deepening 2: Turn Pipeline** | Distributed step choreography across input handling and loose signal handlers. | Encapsulated into atomic `GameState.step_turn(actor, dir)`. | [`game_state.gd`](scripts/core/game_state.gd)<br>[`player.gd`](scripts/player/player.gd) |
| **Deepening 3: Spatial Tags** | Tag dragging spawned runtime SubtextRegion nodes into scene tree. | Replaced with in-memory `cell_tag_overrides` dictionary, eliminating transient scene mutation. | [`grid.gd`](scripts/core/grid.gd)<br>[`drag_controller.gd`](scripts/ui/drag_controller.gd) |

---

## 3. Core Architectural Principles

When building new features for SIKAPTala, adhere to these three golden rules:

### Principle 1: The Tag-First Rule (Composition over Type Checking)
Never check what class a node is to determine its behavior. Check its **tags**:
- ❌ **Bad**: `if occupant is FragileBox: occupant.shatter()`
- ✅ **Good**: `if "FRAGILE" in occupant.tags: occupant.die()`
- ❌ **Bad**: `if layer.name.contains("Wall"): block()`
- ✅ **Good**: `if "IMPASSABLE" in Grid.get_wall_tags(pos): block()`

This ensures that any object, tile, or entity can acquire any behavior dynamically when tags are swapped.

### Principle 2: The Spatial Grid vs. Scene Tree Separation
- **`Grid`** is the spatial database of coordinates, cell occupancy, step resolution, and tag queries.
- **Scene Nodes** are the visual representations.
- Never manipulate scene trees directly inside `Grid`. If a tile needs to become an object, route it through `TileConverter`.

### Principle 3: The State Transaction Rule (Undo Compatibility)
Any game mechanic that alters state (moving, swapping tags, killing an entity, converting a tile) must be reversible by the Undo system:
1. **Never call `queue_free()` directly during gameplay.** Call `die()`, which routes through `GameState.mark_dead()`.
2. **Push undo state BEFORE making changes**: Call `GameState.push_undo_state()` before the player moves or before tags are swapped.

---

## 4. Deepened Subsystem Pipelines

### Movement & Rule Resolution Engine

The `Grid.resolve_step(actor, dir)` engine consolidates all physics, pushing propagation, tag interactions, and harmful checks into a single atomic function:

```mermaid
flowchart TB
    Actor[Player / Entity Step] --> GridEngine[Grid.resolve_step actor, dir]
    GridEngine --> C1{Tile Blocked?}
    C1 -- Yes --> B1[Result: blocked=true]
    C1 -- No --> C2{Occupant at Target?}
    C2 -- Yes --> C3{Occupant Tags}
    C3 -- PASSABLE --> S1[Proceed]
    C3 -- FRAGILE --> K1[Kill Occupant -> Proceed]
    C3 -- HARMFUL + Player --> D1[Attack Player / Player Dies]
    C3 -- Pushable --> P1{Recursive Push}
    P1 -- Success --> S1
    P1 -- Blocked --> B1
    C2 -- No --> S1[Result: success=true]
```

### Transactional Turn Pipeline

`GameState.step_turn(actor, dir)` coordinates snapshotting, rule resolution, AI execution, and turn completion:

```mermaid
sequenceDiagram
    Player->>GameState: step_turn(self, dir)
    GameState->>GameState: push_undo_state()
    GameState->>Grid: resolve_step(self, dir)
    alt Step Blocked / Aborted
        GameState->>GameState: pop_undo_state() [Discard Snapshot]
        GameState-->>Player: return false
    else Step Succeeded
        GameState->>Grid: vacate(old) & occupy(new)
        GameState->>Entity: take_turn() [All Enemies]
        GameState->>GameState: emit turn_processed
        GameState-->>Player: return true
    end
```

### Spatial Tag Registry & Overrides

Tag dragging in Subtext mode no longer creates transient scene nodes. All tag overrides are tracked in pure spatial memory:

```mermaid
flowchart LR
    Drag[DragController] -->|set_cell_tag_override pos, layer, tags| G[Grid]
    G -->|updates in-memory| O[cell_tag_overrides Dictionary]
    G -->|re-evaluates| W[wall_tags & layer_tags]
    Undo[UndoSnapshot] -->|snapshot / restore| O
```

---

## 5. Step-by-Step Extensibility Playbooks

---

### Playbook 1: Adding a New Tag

Let's say you want to add a new tag: **`BURNING`** (destroys fragile objects on contact and spreads to neighbors).

#### Step 1: Register the Tag in [`scripts/core/tag_def.gd`](scripts/core/tag_def.gd)
Add the tag name to `TagDef.Tag` enum:
```gdscript
enum Tag {
    IMPASSABLE, LOCKED, PASSABLE, FRAGILE,
    HEAVY, LIGHT, INTERACTABLE, COLD,
    SLEEPING, CHASING, PATROLLING, FLEEING,
    PUSHING, HARMFUL, HIDDEN,
    BURNING  # <-- Added
}
```

#### Step 2: Assign a Tag Color in [`scripts/ui/tag_label.gd`](scripts/ui/tag_label.gd)
Add the display color for the substrate UI overlay:
```gdscript
var tag_colors: Dictionary = {
    # ...
    "BURNING": "#ff5500",  # Fiery orange
}
```

#### Step 3: Implement the Behavior Hook
Add the tag consequence in `Grid.resolve_step()` or `GameState.process_turn()`:
```gdscript
# Example in GameState.process_turn():
for e in entities:
    if "BURNING" in e.tags:
        for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var occ = Grid.get_occupant(e.grid_pos + dir)
            if occ and "FRAGILE" in occ.tags:
                occ.die()
```

---

### Playbook 2: Adding a New Object / Prop / Hazard

To create a new pushable or interactive object (e.g. `SpikeTrap`, `Mirror`, `HeavyBoulder`):

#### Step 1: Create the Script Extending `GridBody2D`
```gdscript
class_name SpikeTrap
extends GridBody2D

@export var is_active: bool = true

func _on_ready() -> void:
    if tags.is_empty():
        tags = ["HARMFUL", "IMPASSABLE"]
    GameState.register_object(self)

func _on_die() -> void:
    GameState.unregister_object(self)
    Grid.refresh_all_tags()

func can_be_pushed(dir: Vector2i) -> bool:
    return "LIGHT" in tags and not is_active
```

#### Step 2: Create the Scene (`SpikeTrap.tscn`)
- Root node: `Node2D` with `SpikeTrap.gd` attached.
- Child node: `Sprite2D` or `AnimatedSprite2D`.
- `GridBody2D` automatically handles grid snapping, occupancy registration, tween movement, and undo/redo support.

---

### Playbook 3: Adding a New AI Entity Behavior

To create a new AI enemy behavior (e.g. `WANDERING`, `MIMIC`):

1. **Add tag to `TagDef`** (e.g. `WANDERING`).
2. **Add behavior branch in [`scripts/entities/entity.gd`](scripts/entities/entity.gd)** inside `take_turn()`:
```gdscript
func take_turn() -> void:
    if not is_alive: return
    if "SLEEPING" in tags: return
    
    if "CHASING" in tags:
        _do_chase()
    elif "WANDERING" in tags:
        _do_wander()
```
3. Implement `_do_wander()` using `_move_entity(random_dir)`. `_move_entity()` automatically invokes `Grid.resolve_step()`!

---

### Playbook 4: Reworking UI & Subtext Interactions

1. **Tag Drag & Drop Mechanics**: Handled entirely inside [`scripts/ui/drag_controller.gd`](scripts/ui/drag_controller.gd).
2. **Hover Detection & Tile Highlights**: Handled inside [`scripts/ui/tag_display_manager.gd`](scripts/ui/tag_display_manager.gd).
3. **Subtext Overlay Shader & Fullscreen Post-Processing**: Configured in [`scripts/ui/subtext_overlay.gd`](scripts/ui/subtext_overlay.gd) and connected to `GameState.substrate_toggled`.

---

## 6. GDScript 4 Best Practices & Engineering Standards

1. **Strict Static Typing**: Always explicitly type variables, parameters, and return types (`var pos: Vector2i = ...`). Never rely on `:=` when the RHS expression returns a `Variant` (e.g., `event.keycode`, `get_global_mouse_position()`, `lerp()`).
2. **Node Names are `StringName`**: When doing ternary expressions with strings, always cast node names: `str(layer.name) if layer else ""`.
3. **Symmetrical Registration**: Every object that registers on `_ready()` MUST unregister on `_exit_tree()` or `die()` (`GameState.unregister_object()`, `Grid.vacate()`).
4. **Deferred Tile Conversions**: Use `TileConverter.convert_to_prop_if_unoccupied()` when converting static tiles into interactive objects at runtime.
