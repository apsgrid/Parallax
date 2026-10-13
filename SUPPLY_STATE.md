# Parallax Ship Supply / Disembark State

This document records the supply/inventory state entered after a successful flight landing and before ordinary outdoor on-foot control.

## Position in the landing state machine

A successful flight landing still follows the verified two-stage transition:

1. FIRE sets `$F4`.
2. The next main-loop tick enters `$E000`.
3. One-time setup at `$E064` preserves the craft/world anchor and prepares the ground display.
4. **Before outdoor walking begins, `$E064` calls `$E60D`, which presents the SHIP SUPPLY screen and waits for a player choice.**
5. Choosing EXIT SHIP enters the outdoor ground controller.
6. Choosing STAY ABOARD follows `$E720` back to flight without entering outdoor walking.

This corrects the earlier model that treated `$E000/$E064` as an immediate transition into the `$E029` outdoor loop.

## Screen text — $4980+

The `$E60D -> $E589/$E538` display path renders:

- SHIP SUPPLY
- OXYGEN
- DRUGS
- SCIENTISTS
- STUN-GUNS
- AMMUNITION
- TAKE AWAY
- STANDARD KIT
- STAY ABOARD
- EXIT SHIP

The original uses explicit screen coordinates and colour bytes. The modern UI preserves the recovered choices and state semantics rather than copying the C64 layout byte-for-byte.

## Cursor/input state — $E3BD-$E3C0 / $E3CF

`$E3C0` is the vertical selection, constrained to 1 through 8.

Recovered selection identities:

1. Oxygen
2. Stun-Guns
3. Ammunition
4. Drugs
5. Scientists
6. spacer / non-action
7. Standard Kit
8. bottom action row: STAY ABOARD / EXIT SHIP

`$E3BF` is the horizontal side:
- LEFT clears it to `$00`;
- RIGHT sets it to `$80`.

Input handling at `$E3CF`:
- reacts immediately when joystick state changes;
- repeats a continuously held state every five frames;
- processes RIGHT, LEFT, DOWN and UP from the normalized joystick state;
- ignores FIRE on selection 6;
- selected actions are dispatched only after FIRE has been released via the wait loop at `$E651`.

## Inventory mapping

The ordinary transfer handler at `$E69E` uses the index tables around `$E70B/$E710`.

| Selection | Ship side | TAKE AWAY side |
| --- | --- | --- |
| Oxygen | `$CF04` | `$CF30` |
| Stun-Guns | `$CF07` | `$CF31` |
| Ammunition | `$CF08` | `$CF32` |
| Scientists | `$CF06` | `$CF33` |

RIGHT transfers one item from ship to TAKE AWAY. LEFT transfers one item in the opposite direction. A zero source count performs no transfer.

Drugs use `$CF05` but are handled by a special action rather than the ordinary left/right transfer path.

## Startup quantities

The initial state table written by `$2101-$2112` includes:

- ship oxygen `$CF04 = $32` = **50**
- ship stun-guns `$CF07 = $01` = **1**
- ship ammunition `$CF08 = $32` = **50**

The cleared state starts carried quantities, drugs and scientists at zero unless later gameplay has changed them.

## Scientist / drug behavior

### Scientists

Attempting to move a scientist to TAKE AWAY while a scientist is available but `$CF34 == 0` is refused.

Recovered message:
- **SCIENTIST REFUSES TO CO-OPERATE**

### Drugs

Selection 4 uses `$E6EF+`:

- zero drugs: no action;
- drugs available but no ship-side scientist: no drug is consumed and the game reports **NO SCIENTIST**;
- with both a drug and scientist present: one drug is consumed, `$CF34 = 1`, and the game reports **DRUGGING SCIENTIST (HO-HO)**.

After `$CF34` is set, the scientist can be moved to TAKE AWAY.

## Standard Kit — $E6C4 / $E760

Selection 7 executes the original consolidation sequence.

The routine:

1. saves the current carried scientist count `$CF33`;
2. calls `$E760`, which consolidates ordinary carried stores back into their corresponding ship stores;
3. restores the saved carried scientist count;
4. copies all ship oxygen, stun-guns and ammunition into TAKE AWAY `$CF30/$CF31/$CF32`;
5. clears ship-side `$CF04/$CF07/$CF08`.

The reference implementation preserves this slightly unusual scientist handling rather than simplifying it.

## STAY ABOARD — $E720

Selection 8 with the LEFT side active reaches `$E720`.

This resolves the formerly open "alternate exit" path.

`$E720`:
- clears `$E049`;
- clears `$F4`;
- restores `$F3 = 1`;
- reconciles ground/inventory state through `$E760`;
- restores swapped graphics through `$E821`;
- clears ground-specific `$0764/$0770` state;
- restores saved fine-scroll/display state;
- returns to the flight-side control flow.

Player-facing meaning: **STAY ABOARD**.

## EXIT SHIP — $E748

Selection 8 with the RIGHT side active tests carried oxygen `$CF30`.

If carried oxygen is zero, outdoor exit is refused with:

- **YOU MUST TAKE SOME OXYGEN !!!**

When `$CF30 != 0`, the routine restores the ground graphics/display state and returns from the supply interface into the outdoor ground controller.

Therefore oxygen is a verified prerequisite for disembarking.

## Reference implementation

`Godot/scripts/supply_model.gd` models:

- the recovered eight-position cursor;
- LEFT/RIGHT side selection;
- five-frame held-input repeat;
- FIRE-release action dispatch;
- ordinary one-unit inventory transfers;
- drug/scientist rules and exact status messages;
- Standard Kit consolidation;
- STAY ABOARD;
- oxygen-gated EXIT SHIP.

`ParallaxFlightModel` now distinguishes:
- flight;
- transition request;
- SHIP SUPPLY;
- outdoor on-foot mode.

Outdoor `GroundModel` movement is not enabled until EXIT SHIP succeeds.

## Confidence

- supply menu existence/order in landing flow: **VERIFIED**
- cursor directions/repeat and FIRE-release dispatch: **VERIFIED**
- ordinary inventory transfer pairs: **VERIFIED**
- startup oxygen/stun-gun/ammunition quantities: **VERIFIED**
- scientist refusal/drugging behavior: **VERIFIED**
- Standard Kit data movement: **VERIFIED structure**
- STAY ABOARD = `$E720`: **VERIFIED**
- EXIT SHIP oxygen requirement: **VERIFIED**
- exact C64 visual layout in modern UI: intentionally not treated as gameplay authority
