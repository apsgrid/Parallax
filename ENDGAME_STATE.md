# Parallax C64 Endgame / Transporter State

This document records the recovered progression-5 transporter path, original ending overlay, score qualification and five-character high-score entry.

## Confidence convention

- **VERIFIED** — directly demonstrated by canonical byte signatures, code/data flow or exact tables.
- **STRONG** — supported by multiple paths but still benefits from runtime parity capture.
- **OPEN** — deliberately left unresolved.

## Overview

The fifth regional password, **GLOBE**, does not end the game immediately.

The original completion chain is:

**solve GLOBE -> progression becomes 5 -> fly into a $70 transporter trigger -> transporter chooses a $77 master-map destination -> arrive at the unique final destination -> final visual effect waits for FIRE -> restore title/ending overlay -> current score must beat TODAYS BESTEST SCORE -> congratulatory ending -> five-character name entry -> update best-score record -> return to title**

The endgame therefore combines three systems that were previously treated separately:

1. regional password progression;
2. world transporters;
3. the title/high-score overlay.

## Fifth password -> progression 5 (VERIFIED)

Password success at `$F202+`:

- sets outing-success flag `$F229 = 1`;
- increments progression `$030E`.

After successful **GLOBE**, progression is therefore exactly:

`$030E = 5`

The later final check compares for **exact equality with 5**, not greater-than-or-equal.

## Flight transporter trigger — tile $70 (VERIFIED)

The flight collision path at `$0FBA-$0FDA` runs when flight height is at least `$14`.

It examines the cross-shaped five cells of the 3x3 flight footprint.

Special codes include:

- `$5D` -> separate handler at `$1211`;
- `$70` -> transporter at `$1714`.

The corrected expanded world contains **18 visible tile-$70 trigger cells**.

These are entrances/triggers. They are not the destination records used by the relocation routine.

## Transporter cooldown — $191D (VERIFIED)

`$1714` refuses to run while `$191D != 0`.

After a successful transport it writes:

`$191D = $32`

The main flight loop decrements this value once per frame, giving an exact **50-frame re-entry cooldown**.

## Runtime master-map correction (VERIFIED)

During ordinary gameplay the 96x96 master map is addressed at `$8000-$A3FF`.

However, the canonical corrected Stage-5 RAM snapshot is still in title/ending-overlay layout:

- `$8000-$8FFF` contains executable title/ending overlay code;
- the first `$1000` bytes of the flight master map are parked in RAM under C64 I/O at `$D000-$DFFF`;
- `$9000-$A3FF` already contains the remainder of the master map.

The swap routine at `$CFA3+` exchanges the 16 pages at `$8000-$8FFF` with the RAM-under-I/O block at `$D000-$DFFF` when entering/leaving gameplay.

Therefore the authoritative runtime master map reconstructed from the canonical pre-swap image is:

`RAM[$D000:$E000] + RAM[$9000:$A400]`

This corrects the old extractor, which had interpreted the title overlay as the first 4096 map bytes.

The corrected 96x96 master map contains **204 distinct metatile IDs**. Its expanded 480x480 world uses **202 final tile codes**.

## Destination records — master metatile $77 (VERIFIED)

Routine `$17FB` scans a 20-row band of the **96x96 master map**, not the expanded tile map.

A destination is any master cell whose metatile ID is:

`$77`

The corrected runtime master map contains **18** such destination cells.

The six band-start rows at `$17C2` are:

`0, 19, 38, 57, 76, 95`

The current band index comes from `$162C`, which repeatedly subtracts 18 while the remainder is at least 19.

## Destination selector — $17C8 / $17C9 (VERIFIED)

The destination selector is not the shared `$E977` KARD/entity random stream.

For each selection attempt:

1. persistent byte `$17C8` is incremented;
2. only its low nibble is used;
3. values outside the current destination count are rejected;
4. the chosen candidate is rejected if adjusted X equals current macro X;
5. it is also rejected if the pre-scroll adjusted Y equals current macro Y.

The accepted candidate is selected from the row-major `$77` list.

The Godot reference model reproduces this persistent low-nibble selector.

## Relocation geometry — $1795 + twenty scroll frames (VERIFIED)

For master marker `(mx,my)`, `$1795` first writes:

- macro X = `mx - 4`;
- macro Y = `my + 2`.

The transporter then sets Y scroll velocity to `+8` and runs exactly **20 scroll frames**.

Twenty character-tile scrolls equal four 5-tile macro cells. Positive C64 scroll moves the viewport toward lower map coordinates.

Therefore the final viewport macro after the transporter effect is:

**`(mx - 4, my - 2)`**

The original fine/tile remainder is preserved.

## Final stage-5 coordinate gate — $089C (VERIFIED)

After relocation and the twenty scroll frames, `$089C` requires all of:

- progression `$030E == 5`;
- viewport macro X `$0707 >= $50` (80);
- viewport macro Y `$0708 < $50` (80).

Otherwise the transporter completes normally.

### Unique winning destination

Applying the final coordinate transformation to all 18 corrected `$77` markers leaves exactly one qualifying marker:

- master marker: **(90,59)**
- final viewport macro: **(86,57)**

No other `$77` destination satisfies both X/Y conditions.

The band containing this marker has six transporter destinations in row-major order:

- (90,59)
- (70,61)
- (23,73)
- (32,73)
- (40,73)
- (48,73)

Because the low-nibble selector persists across transports, the winning marker is reached according to that selector state rather than by a one-time hardcoded jump.

## Final effect / FIRE gate — $3F9C (VERIFIED)

When the stage-5 coordinate condition succeeds, the transporter jumps into the dedicated final visual-effect loop at `$3F9C`.

The effect waits for joystick FIRE at `$3FAF+`.

On FIRE it:

- ends the visual effect;
- clears relevant gameplay display/entity state;
- writes `$030D = $7B`;
- jumps through `$CF46`.

The `$CFxx` trampoline swaps the title/ending overlay back into `$8000-$8FFF` and transfers control to it.

## $030D=$7B ending discriminator (VERIFIED)

The restored overlay reads `$030D` at `$80CB`.

Normal title/demo flow is used unless it equals:

`$7B`

The special value takes the dedicated ending path through `$816F -> $8810`.

The marker is then cleared.

## Score qualification — $8810 (VERIFIED)

The game keeps the current score as six ASCII decimal digits at:

`$0226-$022B`

The mutable best-score record begins at `$835B`.

Its initial built-in value is:

- score: **000010**
- name: **CHRIX**

The ending route compares the six current score digits lexically with the stored best-score digits.

The congratulatory ending proceeds only when:

**current score > stored best score**

Equality does not qualify.

On a fresh game this means the current score must be at least **000011**.

If the score does not beat the record, the special path immediately returns to the ordinary title loop without the congratulatory/name-entry screen.

## Score production boundary

The score system is structurally separate from the stage-5 ending.

Known original score sources include:

- a flight projectile/destructible collision response that writes `$022D = $0F`;
- moving enemy/object hits that write `$022D = 2 * object_type`.

Routine `$226D+` folds `$022D` into the six decimal score digits with carry normalization.

The current Godot prototype now models the score value and exact ending qualification, but it does **not** invent points for simply firing a laser. Natural score production remains part of the unfinished flight projectile/enemy damage subsystem.

This is now tracked as a combat/score obligation rather than an endgame ambiguity.

## Recovered ending text (VERIFIED)

The restored overlay contains the dedicated congratulatory screen beginning with:

`WELL DONE CAP'N`

It tells the captain that despite the crew being destroyed, enough damage was inflicted on the enemy to become a “MEGA HERO”.

The original entry prompt is spelled:

`ENTRE ...  -----`

The Godot Original Rules presentation preserves that spelling.

## Five-character name entry — $8EAE (VERIFIED)

The ending accepts exactly **five** screen-code characters.

Each new character begins at screen code `1` (A).

Controls are joystick based:

- UP increments the current 6-bit screen code;
- DOWN decrements it;
- FIRE accepts the current character.

Character adjustment occurs on a two-call cadence.

A FIRE-release latch at `$8888` prevents the FIRE used to leave the final effect from immediately accepting the first name character.

After five accepted characters:

- six current score digits are copied into the best-score record;
- the five entered name characters are copied into the name field.

## Return to title (VERIFIED)

After updating the score/name record, the ending performs its fade/audio teardown and jumps to `$BFC0`.

The post-save path eventually executes:

`$BFFD: JMP $8014`

which returns to the normal title loop.

## Godot implementation

`Godot/scripts/endgame_model.gd` implements:

- score/current-best state with initial `000010 / CHRIX`;
- exact strict score qualification;
- vertical-band selection;
- row-major master-map `$77` destination discovery;
- persistent low-nibble destination selector;
- candidate rejection rules;
- exact 50-frame transporter cooldown;
- `mx-4 / my+2` pre-scroll coordinates;
- final `mx-4 / my-2` viewport coordinates;
- exact progression-5/X/Y final gate;
- final FIRE wait;
- ending-overlay score qualification;
- five-character 6-bit name entry;
- two-call UP/DOWN cadence;
- FIRE-release arming;
- best-score update;
- title-return state.

`FlightModel` integrates the transporter with C64 scroll coordinates while preserving sub-macro tile remainder.

`main.gd` detects tile `$70` across the cross-shaped flight footprint, loads the corrected master map and presents the recovered ending/name-entry flow.

## Verification

Static authority:

- `verify_endgame_state.py`
- `verify_world_overlay_swap.py`

Deterministic model coverage:

- `Godot/tests/test_endgame_model.gd`
- `Godot/tests/test_endgame_integration.gd`

The integration regression proves:

**flight macro (50,60) -> $70 trigger -> marker (90,59) -> final macro (86,57) -> progression-5 final effect -> FIRE -> score-qualified ending -> five-character name entry**

## Current boundary

The **progression-5 transporter and original ending state are reconstructed and implemented**.

Remaining separate work:

- exact flight projectile/destructible scoring behavior in the modern playable scene;
- enemy/object scoring and damage;
- shield gameplay effect, if any;
- exact remaining local entity types 1 and 3;
- controlled VICE parity capture of the complete final transporter/ending sequence;
- persistence format for the best-score record in the modern remake.
