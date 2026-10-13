# Parallax C64 Interior / Computer State

This document records the recovered local-area mode entered from the outdoor ground controller through the repeated `$C1/$C2/$C3` entrance motif.

## Confidence convention

- **VERIFIED** — directly demonstrated by code/data flow or canonical byte signatures.
- **STRONG** — role is supported by multiple independent code/data observations.
- **OPEN** — deeper player-facing semantics remain to be reconstructed.

## Outdoor entrance motif — `$C1/$C2/$C3 -> $E444` (VERIFIED)

The expanded 480×480 world contains 125 repeated vertical entrance motifs. Each uses the three codes consecutively:

- `$C1` — upper entrance slice
- `$C2` — middle entrance slice
- `$C3` — lower entrance slice

The outdoor controller only takes the branch when RIGHT is held, ordinary movement is blocked, and the RIGHT collision sample is one of those three codes.

The codes are therefore structural entrance slices, not ordinary walkable terrain.

## Interior entry — `$E444` (VERIFIED)

`$E444`:

1. saves outdoor fine scroll `$0703/$0704`;
2. clears local state `$E85B`;
3. builds the local screen through `$E321`;
4. swaps the interior character data through `$E803`;
5. adds deterministic local objects through `$E866`;
6. refreshes display state through `$ECD7`;
7. sets local player X `$E442 = $3E`;
8. sets local player Y `$E443 = $62` for `$C1/$C2`, or `$8A` for `$C3`;
9. clears the ordinary four movement-block flags;
10. enters the local loop at `$E491`.

## Local pixel -> screen-cell transform — `$E5E6` (VERIFIED)

The collision pointer is computed from the local player coordinates:

- column = `floor((X - $0C) / 8)`
- sampled UP row = `floor((Y - $2D) / 8)`
- player-centre row = sampled UP row + 1

Therefore the recovered entry centres are:

- `$C1/$C2` -> local `($3E,$62)` -> screen cell **(6,7)**
- `$C3` -> local `($3E,$8A)` -> screen cell **(6,12)**

## Base room — `$E321/$E395` (VERIFIED)

The mode builds a fixed **40×20** character room from 32 5×5 metatiles.

The 8×4 metatile IDs at `$F489` are:

`E0 B2 B3 B3 B4 B6 B7 B8 / B1 C0 B0 B0 C1 B9 B1 BA / B1 C0 B0 B0 C1 B9 B1 BA / C2 B5 C3 C3 C4 BB BC BD`

The base room is generated locally by `extract_interior_runtime.py`; the derived JSON remains excluded from Git.

## Character swap — `$E803/$E821` (VERIFIED)

On entry, `$E803`:

- preserves `$4400-$45FF` at `$5D00-$5EFF`;
- copies `$5A30-$5C2F` into `$4400-$45FF`.

This replaces character codes `$80-$BF` for the local-area presentation.

`$E821` restores the saved character bytes on exit.

## Dynamic local objects — `$E866/$E900/$E94F` (VERIFIED)

The local room is decorated deterministically from a byte stream keyed by the exterior macro coordinates.

Candidate placement:

- row = next stream byte `& $0F`
- column = (next stream byte `& $0F`) + 6

`$E900` retries until the requested rectangle consists entirely of `$1F` floor, then `$E94F` stamps the pattern.

Three recovered patterns are used:

- **COMPUTABANK** — 4×4
- **COMPUTASHOP** — 4×6
- **KARD/password terminal** — 6×6

Five special region anchors can force the password-terminal pattern:

`(13,15), (33,25), (45,50), (2,70), (63,84)`

## Interior movement loop — `$E491` (VERIFIED)

Each local frame executes:

- raster/update wait `$E507`
- local coordinate pointer `$E5E6`
- four-way collision `$E295/$E2FC`
- ordinary direction selection/movement `$E15B`
- sprite-frame write `$E271`
- local coordinate update `$E4B8`
- world/entity/interaction helpers `$EDFD/$EA02/$F026/$EBEB`

Movement therefore reuses the recovered ground direction priority and passable-character classifier, but acts on the fixed local screen rather than outdoor scrolling.

## Terminal dispatch — `$EBEB` (VERIFIED)

`$EBEB` checks held **blocked** directions and compares that direction's contact code with three tables.

Direction order is RIGHT, LEFT, DOWN, UP.

### COMPUTABANK -> `$ED2C`

Contact codes:

- RIGHT `$D0`
- LEFT `$CE`
- DOWN `$CD`
- UP `$CF`

Recovered text includes:

- `WELCOME TO..`
- `COMPUTABANK`
- `PLEASE INSERT YOUR KARD`

### COMPUTASHOP -> `$EF3C`

Contact codes:

- RIGHT `$D2`
- LEFT `$D1`

Recovered shop flow includes the **BONANZA PACK**, priced at 20 credits.

### KARD/password terminal -> `$F12B`

Contact codes:

- RIGHT `$D5`
- LEFT `$D3`
- DOWN `$D6`
- UP `$D4`

The five recovered progression passwords at `$F22A` are:

1. `STACK`
2. `JEWEL`
3. `PARCH`
4. `SALON`
5. `GLOBE`

A correct password advances the region/progression index in the original code.

## Interior exit — `$E4DA` (VERIFIED)

`$E4DA` reads zero-page `$46`, which `$E2AB` has populated with the **LEFT collision sample**.

When that sample becomes `$20` (space), the local loop exits. The game restores the prior character/display state and returns to the outdoor controller.

The local detour does not replace the outdoor craft-relative walk displacement. Returning through the local exit therefore resumes the outdoor state around the same entrance/craft relationship.

## Terminal unwind — `$EC45` (VERIFIED)

While a terminal interaction is active, `$EC45` re-reads the directional input.

- zero directional input leaves the terminal state active;
- continuing to hold the original contact direction leaves it active;
- a different non-zero direction restores the local display state and unwinds back to the interior movement loop.

The Godot reference model implements this original directional escape behavior. Enter is retained only as a modern convenience for closing the visible terminal panel.

## Godot implementation

`Godot/scripts/interior_model.gd` implements:

- exact `$C1/$C2/$C3` entry spawns;
- exact local pixel-to-cell transform;
- recovered 40×20 room data;
- deterministic original pattern placement;
- the ordinary passability/direction rules;
- direction-specific COMPUTABANK/COMPUTASHOP/KARD terminal dispatch;
- `$20` left-boundary exit;
- modal initial-state/cardless terminal interaction.

`Godot/scripts/main.gd` renders the recovered room, switches the player/camera into local coordinates, shows the recovered terminal interaction panel and restores outdoor rendering on exit.

`Godot/tests/test_vertical_slice.gd` verifies the first complete gameplay slice:

**flight -> land -> SHIP SUPPLY -> EXIT SHIP -> outdoor -> enter structure -> terminal interaction -> leave structure -> return to craft -> flight**

## Current boundary

The first complete gameplay vertical slice is implemented.

Still open beyond that milestone:

- full KARD ownership/account state and all bank transaction details;
- complete COMPUTASHOP purchase inventory effects beyond already traced original routines;
- live entry of all five progression passwords in the modern UI;
- scientist/entity interactions within local areas;
- controlled VICE parity capture for an entire interior entry/terminal/exit sequence;
- controlled runtime parity of the interior raster/palette timing (the verified `$80-$BF` charset swap is now rendered by a dedicated generated atlas).
