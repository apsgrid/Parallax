# Parallax C64 Scientist / Stun / KARD Encounter State

This document records the recovered local scientist encounter that connects interior exploration to natural KARD acquisition and scientist capture.

## Confidence convention

- **VERIFIED** — directly demonstrated by canonical byte signatures, code/data flow or exact state tables.
- **STRONG** — supported by multiple paths but still benefits from original-runtime parity capture.
- **OPEN** — deliberately not assigned beyond the available evidence.

## Encounter lifecycle (VERIFIED)

The recovered scientist lifecycle is:

**type 4 roaming scientist -> stun hit -> type 5 stunned scientist -> close KARD interaction -> type 6 accompanying scientist**

Type 6 is the same scientist-present state already used by the regional password gate and return-to-ship reconciler.

The lifecycle is not an inferred modern design. It is produced directly by the original transitions:

- projectile hit at `$EEC2-$EECF` converts type 4 or type 6 to type 5;
- `$F026` interacts only with visible type 5;
- after `$F061` returns, `$F055-$F05C` promotes the scientist to type 6 when `$CF06 == 0`;
- `$E01F` also creates type 6 from a TAKE AWAY scientist on a later outing;
- `$E760` reconciles type 6 back into the ship scientist state unless the regional password was solved.

## Ground-session flags — $E0B2 / $E0B7 (VERIFIED)

Ground initialization sets:

- `$E998 = 1` — local entity spawning enabled;
- `$F060 = 1` — one KARD offer available during the outing.

A projectile/entity hit clears `$E998`, preventing another ordinary spawn after the hit.

A KARD offer clears `$F060`, making the generated-card prompt one-shot for that ground outing.

When a type-6 scientist enters a local room, `$E48C-$E48E` clears `$F060` so the same accompanying scientist cannot generate another KARD.

## Current-region gate — $E833 (VERIFIED)

Scientist spawning and stun-gun firing are restricted to the region currently being solved.

`$E833` computes:

`floor(($0708 + 1) / 18)`

and compares the result with progression index `$030E`.

A mismatch suppresses the encounter spawn and rejects stun fire without consuming ammunition.

## Local entity spawning — $E981-$E9E1 (VERIFIED)

Ordinary entity spawning requires:

- `$E998 != 0`;
- current entity is not type 6;
- the room is not the special progression/password room (`$E85B == 0`);
- `$E833` confirms the current progression region.

The spawn search repeatedly consumes the shared `$E977` byte stream:

- X = `(random & $3F) + $80` -> 128..191;
- Y = `(random & $3F) + $46` -> 70..133;
- the candidate centre character must be walkable.

After a valid location is found, type selection uses:

`($1000[2 * macro_y + macro_x] & 7)`

as the index into the effective eight-entry type table:

`1, 3, 4, 4, 4, 4, 4, 1`

The eighth value is the byte at `$E9EE`, read when the masked selector is 7.

The direction then initializes from the next shared random byte `& 3`.

### Semantic boundary

- type 4: **VERIFIED roaming scientist** because it enters the stun/KARD/capture lifecycle;
- type 5: **VERIFIED stunned scientist**;
- type 6: **VERIFIED accompanying scientist**;
- types 1 and 3: **OPEN player-facing semantics**. They use the same local movement machinery but a stun-projectile hit removes them instead of entering the scientist path.

## Local entity movement — $EA02 (VERIFIED)

Visible ordinary entities use four cardinal directions.

For types other than 2, movement vectors are one pixel:

- RIGHT `(+1,0)`
- LEFT `(-1,0)`
- DOWN `(0,+1)`
- UP `(0,-1)`

Before movement, the adjacent character in the chosen direction is checked with the recovered local passability classifier.

If blocked:

1. select a new direction from `$E977 & 3`;
2. retry;
3. make at most five attempts;
4. restore the original direction if no route is accepted.

Type 5 skips movement entirely.

A wander counter at `$E9E6` is increased each rendered entity frame by `$E977 & 7`. When it reaches/exceeds `$82`, it resets and another `$E977 & 3` direction is selected.

## Scientist sprite behavior — $EAC8+ (VERIFIED)

The type-4 scientist animation is derived from the same 16 directional player frame codes at `$E04E`, with sprite pointer:

`player_frame_code + $55`

The four-frame animation phase advances every four local frames.

Type 5 always uses sprite pointer `$55`.

Type 6 is positioned sixteen pixels to the player's right at `$EAF7-$EB03`.

Before password success, its sprite pointer is the player's local sprite pointer minus `$28`, which produces the same scientist frame family `$A5-$B0`.

The Godot encounter renderer uses the original sprite bytes for:

- simple local entities `$40-$43`;
- stun projectile `$44-$47`;
- stunned scientist `$55`;
- projectile impact `$9D-$A4`;
- scientist animation `$A5-$B0`.

Generated sprite PNGs remain local and excluded from Git.

## Stun-gun fire — $EDFD (VERIFIED)

A new stun projectile can start only when all conditions hold:

- no existing projectile is active;
- carried stun-guns `$CF31 > 0`;
- carried ammunition `$CF32 > 0`;
- FIRE is held;
- `$E833` confirms the current progression region.

A shot:

- consumes exactly **one carried ammunition**;
- does **not** consume the stun-gun;
- starts at player local coordinates `$E442/$E443`;
- copies player direction `$E048`, then subtracts one to create projectile direction 0..3.

The projectile moves four pixels per local frame:

- RIGHT `(+4,0)`
- LEFT `(-4,0)`
- DOWN `(0,+4)`
- UP `(0,-4)`

Direction sprite pointers are:

`$46, $47, $45, $44`.

Before each movement step the character immediately ahead is checked for passability. A blocked path enters the impact animation instead of moving.

## Projectile/entity hit — $EE97-$EED8 (VERIFIED)

After a successful four-pixel movement, collision compares projectile minus entity coordinates.

A hit is accepted when both signed differences are:

**-6 through +5 inclusive**

On hit:

- projectile enters impact state `$80`;
- entity respawning `$E998` is disabled;
- type 4 or type 6 -> type 5;
- any other hittable type -> entity X becomes zero, removing it.

The impact animation uses eight states `$80-$87`, each held for two frames. Reaching `$88` clears the projectile. Total impact duration is therefore **16 local frames**.

## Stunned-scientist approach — $F026 (VERIFIED)

KARD/scientist interaction requires:

- entity X nonzero;
- entity type exactly 5.

The player/entity signed-difference window is:

- X: **-9 through +8**
- Y: **-6 through +5**

Inside this window the game calls `$F061`.

## KARD offer — $F061 (VERIFIED)

If `$F060 & $0F == 0`, no new card is offered.

Otherwise the game:

1. consumes four values from the shared `$E977` stream;
2. generates the exact KARD record already documented in `COMPUTER_STATE.md`;
3. clears `$F060` **before** asking the player;
4. displays the generated KARD;
5. waits specifically for keyboard **Y** or **N**.

The player-facing interaction is:

`KARD C-NNN`
`TAKE ?`
`(Y/N)`

The random stream advances even when the player answers No because generation occurs before the prompt.

### Yes

The card is inserted using the original two-slot replacement rule.

### No

The generated card is discarded.

### Scientist outcome after either answer

After `$F061` returns, `$F055-$F05C` checks ship scientist `$CF06`.

- if `$CF06 == 0`: the stunned scientist becomes type 6 and accompanies the player;
- if `$CF06 != 0`: the scientist remains type 5.

Therefore **declining the KARD does not decline the scientist**.

If the outing's KARD offer was already consumed, a close type-5 scientist skips the card prompt but can still become type 6 when no scientist is aboard.

## Type-6 scientist and regional password (VERIFIED)

Type 6 is accepted as scientist-present by the special regional password terminal.

This means a naturally captured scientist can be used at the progression gate in the **same outing**, or can be escorted back to the craft for the existing ship/drug/TAKE AWAY route.

## Return to craft — $EB5B / $E760 (VERIFIED)

Normal return range is X/Y -7..+7.

When entity state is type 6, the negative X return bound widens to **-27**, while:

- positive X remains +7;
- Y remains -7..+7.

The Godot reference model now implements that exact special range.

On successful unsolved return:

- `$E760` consolidates ordinary carried supplies;
- the accompanying type-6 scientist becomes ship scientist `$CF06 = 1`;
- the drugged flag is cleared.

If the regional password was solved on the outing, the scientist is not restored aboard.

## Godot implementation

`Godot/scripts/encounter_model.gd` implements:

- current-region spawn gating;
- exact shared `$E977` random stream use via `ComputerModel`;
- original random spawn search and entity type table;
- one-pixel local wandering;
- scientist type 4/5/6 lifecycle;
- exact stun-fire inventory checks;
- one-ammunition shot cost;
- four-pixel projectile movement;
- terrain blocking and 16-frame impact state;
- exact projectile/entity hit window;
- exact stunned-scientist approach window;
- one KARD offer per outing;
- modal Y/N generated-KARD interaction;
- Yes/No scientist promotion behavior;
- type-6 follower state.

`FlightModel` integrates the encounter into the local frame order and now uses encounter type 6 for password-gate presence and return-to-ship reconciliation.

`main.gd` renders the recovered entity/projectile sprite data and exposes the Y/N KARD prompt.

## Verification

Static authority:

- `verify_scientist_encounter.py`

Deterministic model coverage:

- `Godot/tests/test_encounter_model.gd`
- `Godot/tests/test_scientist_loop.gd`

The scientist-loop regression verifies:

**roaming scientist -> stun -> KARD offer -> take KARD -> type-6 escort -> local exit -> widened scientist return gate -> scientist aboard + KARD retained**

## Current boundary

The **scientist stun / natural KARD acquisition / capture loop is reconstructed and implemented**.

Separate open work:

- exact semantic identities and player effects of local entity types 1 and 3;
- progression-5/endgame behavior after `GLOBE`;
- controlled VICE parity capture of a full scientist stun/KARD/capture encounter;
- any local entity damage/attack behavior belonging to types 1/3 rather than the scientist path.
