# Parallax C64 Computer / KARD / Password State

This document is the authoritative reconstruction of the KARD economy and computer-progression layer used by the recovered interior terminals.

## Confidence convention

- **VERIFIED** — directly demonstrated by canonical byte signatures, code/data flow or exact state tables.
- **STRONG** — role is supported by multiple independent code paths but still benefits from original-runtime parity capture.
- **OPEN** — intentionally not assigned beyond available evidence.

## Startup computer/economy state — $2101-$2112 (VERIFIED)

The initialization table at $2113 establishes:

- flight endurance / energy counter `$CF03 = 99`;
- ship oxygen `$CF04 = 50`;
- ship stun-guns `$CF07 = 1`;
- ship ammunition `$CF08 = 50`;
- KARD count `$CF09 = 1`;
- starting KARD slot A = **`0-285`**;
- five password-display slots `$CF29-$CF2D = -----`;
- credits `$CF2E = 20`.

This corrects the earlier prototype assumption that the player began without a KARD.

The exact player-facing name of `$CF03` remains open. Its behavior is clear: it starts at 99, is periodically decremented during flight, zero reaches the failure path, and COMPUTASHOP adds 30 with a cap of 99. The modern model calls it **flight endurance** rather than inventing a fuel label.

## KARD format (VERIFIED)

A KARD is a four-byte record displayed as:

**class-number = `C-NNN`**

Examples:
- starting KARD `0-285`;
- generated KARD `3-527`.

The first digit is a class in the range 0–5. The remaining three digits are each in the range 0–7.

The game can carry at most two KARDs.

## Generated KARDs — $F061 (VERIFIED)

When the original KARD-acquisition interaction runs, class selection uses the 16-byte table at `$F10B`:

`1,0,2,0,3,0,4,0,5,0,1,0,2,0,3,0`

The table index is:

`(random_byte >> 1) & $0F`

The three numeric digits are produced from three further random bytes masked with `& $07`.

### Shared random-byte stream — $E977 (VERIFIED)

The apparent random source is itself deterministic. `$E977` increments the byte at `$E976`, transfers it to Y, and returns `$0900,Y`. The cursor therefore walks the 256-byte table `$0900-$09FF` with 8-bit wrap.

COMPUTABANK credit awards and generated KARDs consume this same stream. `ComputerModel` uses the extracted `$0900` table and the same increment-before-read / 8-bit-wrap rule.

### Two-slot replacement rule

If fewer than two KARDs are carried, the generated KARD fills the next slot.

If two are already carried:

- when slot A is class 0, slot A is preserved and slot B is replaced;
- otherwise slot A is replaced and slot B remains.

The exact generation/replacement algorithm is implemented in `ComputerModel`.

The original world/NPC path that reaches this interaction belongs to the scientist/stun-combat entity subsystem and is not yet wired into the modern playable scene.

## KARD insertion and authentication — $F248+ (VERIFIED)

All KARD-authenticated terminal paths share the recovered insertion flow.

- zero KARDs: terminal reports that no KARD is available;
- one KARD: it is selected automatically;
- two KARDs: the original presents KARD A / KARD B selection;
- the selected four-byte record is temporarily removed from inventory;
- the player enters the complete four-digit value;
- all four digits are compared exactly.

### Incorrect authentication

For a **class-0** KARD:
- incorrect number -> `INCORRECT / TAKE KARD`;
- the KARD is returned.

For a **class 1–5** KARD:
- incorrect number -> `KARD LOST !`;
- the KARD is destroyed.

This class distinction is implemented and regression-tested.

## COMPUTABANK — $ED2C (VERIFIED)

### Class-0 KARD

A correctly authenticated class-0 KARD is an account/balance KARD.

The bank:
- reports the current credit balance;
- returns the KARD;
- does not modify credits.

The recovered starting `0-285` KARD therefore gives immediate access to the player's initial 20-credit balance.

### Class 1–5 KARD

A correctly authenticated class 1–5 KARD is consumed by COMPUTABANK and awards credits.

The original algorithm works in tens of credits:

1. `q = floor(credits / 10)`;
2. take a random byte;
3. `candidate = ((~random) & 7) + q`;
4. retry while `candidate >= 10`;
5. `award = (candidate - q) * 10`;
6. add the award to credits.

The display reports `xx CREDITS TAKEN`.

This algorithm is implemented deterministically and accepts explicit random bytes in tests.

## COMPUTASHOP — $EF3C (VERIFIED)

The shop requires the player to possess a KARD, but it does **not** remove or authenticate the KARD.

The recovered product is:

**BONANZA PACK — 20 credits**

If credits are below 20:
- `YOU CAN NOT AFFORD IT!`

On purchase:

- credits `$CF2E -= 20`;
- flight endurance `$CF03 += 30`, capped at 99;
- carried oxygen `$CF30 += 20`, capped at 49;
- carried ammunition `$CF32 += 20`, capped at 49;
- drugs `$CF05 += 1`.

The KARD remains carried.

All five mutations and both caps are statically verified and covered by model tests.

## Ordinary KARD/password terminal — $F12B (VERIFIED)

Away from the current progression anchor, the six-by-six KARD/password terminal is a **password-letter reader**.

After correct KARD authentication:

### Class 0

- reports `INVALID KARD`;
- returns the class-0 KARD.

### Classes 1–5

- the KARD is consumed;
- class N reveals letter N of the current region's five-letter password;
- the revealed letter is written to password-display slot N.

The five regional passwords are:

1. `STACK`
2. `JEWEL`
3. `PARCH`
4. `SALON`
5. `GLOBE`

Example: class 3 in region 1 reveals the third letter of `JEWEL`, **W**.

## Regional progression gate — $E89F/$E85B + $F1A8 (VERIFIED)

The same terminal artwork becomes the actual five-letter progression gate only when the structure is within ±1 macro-cell of the current progression anchor.

Recovered anchors:

1. `(13,15)`
2. `(33,25)`
3. `(45,50)`
4. `(2,70)`
5. `(63,84)`

`$E89F` compares the current macro coordinates against the anchor indexed by progression `$030E`. On a match it sets `$E85B = 4` and forces the password-terminal pattern.

### Scientist requirement

On ground initialization, carried scientist `$CF33 > 0` causes local entity state `$E9E5 = 6`.

The special password gate requires that scientist-present state.

Without it:
- `SCIENTIST NOT PRESENT`.

With it:
- the terminal accepts five alphabetic characters.

### Password result

A correct regional password:

- displays `SYSTEM OFF`;
- sets outing flag `$F229 = 1`;
- increments progression `$030E`;
- clears the five displayed password letters back to `-----`.

An incorrect password reports:
- `INVALID`;
- progression is unchanged.

The modern model implements all five password stages.

## Scientist-present state and return — $E9E5 == 6 / $E760 (VERIFIED)

The previously unexplained local state `$E9E5 == 6` is now identified as the **scientist-present** ground state.

Evidence:
- `$E01F` maps carried scientist `$CF33 > 0` to local type 6;
- the password gate explicitly requires type 6;
- the return path checks type 6;
- if the outing password flag `$F229 == 0`, the scientist is restored to ship-side scientist state;
- if `$F229 == 1`, the scientist is not restored.

This also explains why `$EB5B` widens the lower X return bound from -7 to -27 in state 6: the return-to-craft gate accommodates the scientist-present configuration. The exact spatial reason for the extra 20 pixels can still be parity-checked, but the semantic identity of the state is no longer open.

### $E760 equipment consolidation

Before returning to flight:

- carried oxygen is merged into ship oxygen;
- carried stun-guns are merged into ship stun-guns;
- carried ammunition is merged into ship ammunition;
- carried versions are cleared.

Scientist handling is special as described above.

The modern `SupplyModel.return_from_ground()` now reproduces this behavior.

## RETURN KARD/PASS display — $20C4 -> $1FD7 -> $2131 (VERIFIED)

RETURN is not an unfinished generic computer action.

The keyboard scanner recognizes RETURN (`$0D`) and sets `$CF28`. The event handler at `$1FD7` then calls `$2131`, which constructs the status display from:

- carried KARD A;
- carried KARD B, when present;
- the five currently revealed password letters.

The recovered template is effectively:

`KARD A  C-NNN`
`KARD B  C-NNN`
`PASS    -----`

The Godot scene now exposes this status panel on Enter outside active terminal input.

## Godot implementation

`Godot/scripts/computer_model.gd` implements:

- authentic startup credits/endurance/KARD/password state;
- two-slot KARD inventory;
- exact generated-KARD class/digit algorithm;
- exact two-slot replacement rule;
- KARD selection and four-digit authentication;
- class-dependent wrong-number return/loss behavior;
- COMPUTABANK class-0 balance path;
- COMPUTABANK class 1–5 credit-award path;
- COMPUTASHOP BONANZA PACK;
- ordinary KARD password-letter reveal;
- five regional progression passwords;
- scientist-gated special password terminal;
- outing success flag and progression index.

`Godot/scripts/main.gd` provides playable keyboard interaction:

- A/B — choose between two KARDs;
- 0–9 — enter KARD number;
- A–Z — enter regional password;
- Backspace — correct typed terminal input;
- B or Z — buy the shop offer where appropriate;
- Z / Enter — insert/continue/return in terminal state;
- Enter outside terminals — show the recovered KARD/PASS status.

`Godot/scripts/supply_model.gd` implements the relevant `$E760` equipment/scientist reconciliation.

## Verification

Static authority:
- `verify_computer_state.py`

Deterministic model coverage:
- `tests/test_computer_model.gd`
- `tests/test_computer_integration.gd`
- `tests/test_vertical_slice.gd`

The computer model tests cover startup state, KARD generation/replacement, bank paths, wrong KARD handling, shop mutations/caps, password-letter reveal, regional password progression and return-to-ship scientist outcomes.

## Current boundary

The **computer/KARD/password/economy layer is reconstructed and implemented**.

The natural KARD source is now reconstructed in `ENCOUNTER_STATE.md`: roaming scientist type 4 can be stunned to type 5, approached for the exact Y/N generated-KARD offer, and promoted to accompanying type 6.

Separate next subsystems:

- progression-5/endgame behavior after all five passwords;
- exact identities/player effects of remaining local entity types 1 and 3;
- controlled VICE parity captures for terminal and scientist/KARD timing;
- exact original raster/palette timing around the terminal screens.
