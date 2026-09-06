# Design Decisions

Reference doc for decisions made so far on this project. Update as things change.

## Concept

2D Metroidvania. Player character is a cat wielding an umbrella as a weapon.
Story goal: defeat an ancient being who has resurrected, along with five
lieutenant-tier enemies called **the Five Forbiddens**.

## Core Decisions

| Area | Decision |
|---|---|
| Engine / language | Godot 4.7, GDScript |
| First build target | Core player controller (movement + umbrella combat) before anything else |
| Controls | Keyboard + gamepad, both supported from the start via Godot's InputMap |
| Map structure | Single interconnected world, ability-gated (classic Metroidvania — new abilities open previously inaccessible paths) |
| Combat feel | Fast & precise (Hollow Knight-style: quick swings, tight hitboxes, full mobility during attacks) |
| Starting moveset | Walk + jump only. Dash, wall-jump, double-jump etc. are deferred — likely candidates for later unlockable abilities tied to progression |
| Art style | Pixel art. Near-term: hand-made placeholder sprites (generated as real PNGs, not primitives) so the game looks cohesive while prototyping. Longer-term: mix of custom art and a free/purchased asset pack, swapped in without changing gameplay code |
| Boss design | User has concepts already for the Five Forbiddens — not yet documented here, to be added once shared |

## Umbrella Weapon Mechanics

The umbrella serves three roles, all implemented in the initial player controller:

1. **Melee swing** — close-range arc attack, fast startup/short active window/short recovery, tweened rotation through an arc.
2. **Block / parry** — holding the guard input opens the umbrella defensively. The first ~0.15s of the hold is a parry window (`can_parry` flag on the player); holding past that is a plain block. No enemies exist yet to test this against — it's implemented as player-side state ready for enemies to check via future hit-resolution code.
3. **Glide / float** — holding guard while falling drastically reduces gravity and caps fall speed, functioning as an umbrella-float traversal tool. Does not trigger while moving upward.

Explicitly **not** included (rejected in favor of the above): ranged throw/boomerang umbrella attack.

## Death & Respawn

- The player has HP (`MAX_HEALTH = 5`) and a brief post-hit invulnerability window (0.6s, shown as a sprite blink) to prevent multi-hit spam from a single contact.
- Falling into a **void zone** (an `Area2D` placed below the level) or reaching 0 HP both call the same `Player.die()` — full heal, teleport back to the room's spawn point, short fade-to-black-and-back.
- Guarding currently blocks all incoming damage outright (no distinction yet between a timed parry and a plain block) — `can_parry` is tracked but not yet wired to any special reaction, since no enemy attack reacts differently to a parry yet.

## First Enemy: Fire Sprite

- Small hovering flame enemy (`scenes/enemies/FireSprite.tscn`), 2 HP, bobs in place, deals 1 contact damage to the player on touch (with its own cooldown so it doesn't multi-hit every frame).
- Takes damage from the umbrella swing via the player's attack hitbox; flashes on hit, shrinks and despawns on death.
- Purely a combat-testing enemy for the player controller — no patrol AI, no ranged attack, no drops. Placed once in `TestRoom.tscn` between the two platforms.

## Current Implementation State

- `project.godot` — input map bound to keyboard and gamepad (D-pad/stick, A, X, LB); low-res viewport (480×270) with canvas_items/expand stretch for a chunky pixel-art look; `TestRoom.tscn` set as the main scene. Keyboard bindings:
  - `move_left`/`move_right`: A/D or Left/Right arrows
  - `move_up`/`move_down`: W/S or Up/Down arrows (not consumed by any gameplay yet — reserved for future ladder/crouch mechanics)
  - `jump`: Space or M
  - `attack`: J, B, or left mouse button
  - `guard`: K, N, or right mouse button
- `scripts/player/player.gd` — CharacterBody2D controller: acceleration/friction movement, coyote time + jump buffering + variable jump height, umbrella swing/guard/parry/glide state machine. Tunable constants live at the top of the file.
- `scenes/player/Player.tscn` — player scene: body collider, facing pivot (handles left/right mirroring for sprite + umbrella + hitbox together), umbrella pivot, attack hitbox (`Area2D`, disabled outside the active swing window), Camera2D.
- `scenes/test/TestRoom.tscn` — throwaway test room: ground + two platforms, a void death-zone below, one Fire Sprite, player spawn point. For controller/combat testing only, not a real level.
- `scripts/world/void_zone.gd` — generic "kill any player that touches this" Area2D; reusable anywhere a bottomless pit is needed.
- `scripts/enemies/fire_sprite.gd`, `scenes/enemies/FireSprite.tscn` — first enemy (see above).
- `assets/sprites/player/` — placeholder pixel-art PNGs generated procedurally (cat idle, umbrella closed, umbrella open).
- `assets/sprites/enemies/` — placeholder pixel-art for the fire sprite. All placeholders are meant to be swapped for real art later.

No save system or real level content exists yet — everything above is scaffolding for the player controller and combat loop.

## Open Items / Next Steps

- Get the Five Forbiddens concepts from the user and document them here (theme, arena, attacks, ability tie-in per boss).
- Decide on/acquire the actual pixel-art asset pack or commission approach.
- Playtest the controller in the real Godot editor (not available in the dev sandbox) and tune feel constants.
- Design the interconnected map / ability-gating layout once more abilities exist beyond walk/jump.
