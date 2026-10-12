# Parallax Ground / On-Foot State

This document records the verified resident on-foot control loop reached through the flight-to-ground transition.

## Ground frame chain

After the one-time `$E000/$E064` initialization, the outdoor ground dispatcher runs from `$E029`:

- optional `$EB25` when `$E9E5 == 6`;
- `$E280` — four-direction collision sampling;
- `$E15B` — joystick direction selection, facing, movement and animation;
- `$E271` — writes the current player sprite frame pointer;
- `$E216` — applies the inverse scroll/craft-coordinate delta;
- `$EDC9` — tracks proximity to the saved landing macro position;
- `$EB5B` — FIRE return-to-ship gate.

## Joystick normalization — `$E516` (VERIFIED)

`$E516` reads CIA1 `$DC00`, inverts active-low input, masks to five joystick bits and reverses the four direction bits exactly as the flight reader does.

Returned logical bits:
- `$01` RIGHT
- `$02` LEFT
- `$04` DOWN
- `$08` UP
- `$10` FIRE

## Direction selection and one-pixel movement — `$E15B` (VERIFIED)

Direction priority is strict:

1. RIGHT
2. LEFT
3. DOWN
4. UP

A blocked direction falls through to the next held direction. The first held, unblocked direction is accepted.

Facing code `$E048`:
- RIGHT = 1
- LEFT = 2
- DOWN = 3
- UP = 4

Accepted movement writes the inverse world/scroll delta:
- RIGHT player movement -> `$E062 = $FF` (-1 X scroll)
- LEFT player movement -> `$E062 = $01` (+1 X scroll)
- DOWN player movement -> `$E063 = $FF` (-1 Y scroll)
- UP player movement -> `$E063 = $01` (+1 Y scroll)

This establishes one-pixel on-foot movement per accepted frame. The world/craft moves opposite the player's intuitive direction because the player is held near a fixed screen anchor.

## Ground collision sampler — `$E280/$E2FC` (VERIFIED)

The collision pointer targets the active screen buffer at a fixed neighborhood around the ground player. It samples four cardinal character cells:

- UP: offset `$00`
- LEFT: offset `$27`
- RIGHT: offset `$29`
- DOWN: offset `$50`

Blocked flags:
- `$E2F8` RIGHT
- `$E2F9` LEFT
- `$E2FA` DOWN
- `$E2FB` UP

`$E2FC` considers a sampled character passable only when it matches one of these 17 codes:

`C0 DE DF 1F 4D 80 81 82 83 84 85 86 87 88 89 1B 2A`

Every other code blocks normal movement.

### Godot collision bridge

`GroundModel` uses the exact recovered whitelist and blocked-bit semantics. The current scene bridge maps the modern world coordinate to the expanded 480×480 tile map and tests the neighboring cells.

This bridge is **PROVISIONAL**, not byte-perfect original authority. The exact C64 fine-scroll/screen-buffer mapping still needs to be expressed directly in the reference state before claiming identical collision timing at character boundaries.

## Movement animation — `$E046/$E047/$E048/$E05E` (VERIFIED)

Each accepted movement increments `$E046`. Every fourth accepted movement:
- `$E046` resets;
- `$E047` increments;
- phase is `$E047 & 3`.

Idle frame codes by facing:
- RIGHT `$58`
- LEFT `$59`
- DOWN `$53`
- UP `$52`

Four-phase walking frames:
- RIGHT: `$56 $58 $57 $58`
- LEFT: `$5A $59 $5B $59`
- DOWN: `$54 $53 $55 $53`
- UP: `$50 $52 $51 $52`

`$E271` adds `$7D` to the frame code and writes the resulting VIC sprite pointer to `$7BF9/$7FF9`, identifying this as sprite 1.

## Recovered sprite artwork

Frame codes `$50-$5B` map to VIC sprite pointers `$CD-$D8`, placing their 63-byte sprite payloads in the `$7340-$763F` range of VIC bank `$4000-$7FFF`.

`generate_ground_sprites.py` extracts all 12 frames into local transparent PNGs for the Godot prototype. Generated artwork remains ignored by Git.

## Coordinate roles during ground mode — corrected

`$E064` starts by copying the current flight coordinate `$0748/$0749` into both:
- fixed landing/craft anchor `$074A/$074B`;
- mutable ground-relative coordinate `$E060/$E05F` and saved `$06/$07`.

During walking, `$E216`:
- adds `$E062/$E063` to `$E060/$E05F`;
- mirrors the mutable values into `$0748/$0749`;
- writes those same inverse movement deltas into `$0709/$070B` for the scroll updater.

Therefore, in ground mode:
- `$074A/$074B` remain the fixed landing/craft anchor used by the return gate;
- `$E060/$E05F` and `$0748/$0749` are the moving relative/scroll coordinate;
- `$074A-$E060` / `$074B-$E05F` measure player displacement from the craft.

This corrects the earlier interpretation that treated `$074A/$074B` as the moving player coordinate.

## Return to craft — `$EB5B`

FIRE near the craft uses the displacement above. Normal accepted range is -7..+7 on each axis. The return routine feeds the remaining displacement into `$0709/$070B` and `$C1FD`, cancelling the accumulated ground scrolling and restoring the landing world position before flight resumes.

## Special RIGHT contact — `$C1-$C3 -> $E444` (VERIFIED branch, OPEN semantics)

If no normal movement was accepted, RIGHT is still held, and the sampled RIGHT character is `$C1`, `$C2`, or `$C3`, `$E15B` jumps to `$E444`.

`$E444`:
- saves fine scroll `$0703/$0704`;
- switches graphics/data state through `$E321/$E803/$E866/$ECD7`;
- relocates the local player coordinate to `$3E,$62` or `$3E,$8A` depending on contact code;
- clears the ordinary four movement-block flags;
- enters a secondary movement/collision/render loop at `$E491`;
- eventually restores the prior display state and returns.

This is a distinct ground/interior submode, not a generic FIRE interaction. Exact meanings of `$C1/$C2/$C3`, the interior objective, and its exit condition remain OPEN.

## Godot implementation

`Godot/scripts/ground_model.gd` implements:
- exact logical direction bits;
- exact direction priority;
- blocked-direction fall-through;
- one-pixel player offsets;
- inverse scroll deltas;
- exact 17-code passable whitelist;
- exact idle/walk animation tables and four-move cadence;
- the `$C1-$C3` special RIGHT-contact event.

`Godot/scripts/main.gd` additionally:
- displays the recovered ground sprite frames;
- follows the ground player with the camera;
- supplies the provisional expanded-world collision bridge;
- keeps the original collision model separate from that bridge so the bridge can be replaced when fine-scroll mapping is completed.

## Current confidence

- ground input normalization: **VERIFIED**
- direction priority/facing/movement deltas: **VERIFIED**
- passable character whitelist: **VERIFIED**
- walk animation cadence/frame codes: **VERIFIED**
- inverse scroll behavior: **VERIFIED**
- fixed anchor vs mutable ground coordinate roles: **VERIFIED**
- `$C1-$C3 -> $E444` secondary-submode branch: **VERIFIED structure**
- exact semantic names for `$C1/$C2/$C3`: **OPEN**
- exact modern-world ↔ C64 fine-scroll collision alignment: **OPEN**
