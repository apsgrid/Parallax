# Parallax Flight ↔ Ground Transition

This document records the second-pass reconstruction of the mode transition between flight and the on-ground module.

## Core state

- `$F4` — ground-transition / ground-active flag.
- `$F3` — flight raster/update mode flag: 1 in flight, cleared to 0 by ground initialization.
- `$E049` — one-time ground initialization guard.
- `$0748/$0749` — flight coordinate pair; during ground mode it mirrors the mutable relative/scroll coordinate.
- `$074A/$074B` — fixed landing/craft anchor copied from `$0748/$0749` on ground entry and retained for the return-to-ship proximity test.
- `$E060/$E05F` — mutable ground-relative coordinate initialized from the same landing anchor and shifted opposite the player's walking direction.

## Flight → ground

### 1. Landing request — `$10DA`

FIRE can set `$F4 = 1` only when the recovered landing gate is active:

- `$10FB != 0` (landing-ready);
- integer X/Y velocity `$0709 | $070B == 0`;
- `$CF01 < $28`;
- FIRE is active.

The current flight frame then finishes. The mode does **not** change inside `$10DA`.

### 2. Next-frame dispatch — `$0E30`

`$0E38-$0E3C` tests `$F4` before the ordinary flight update chain. When non-zero it jumps directly to `$E000`.

This proves the transition is two-stage:

1. landing FIRE frame sets `$F4`;
2. the next 50 Hz game tick enters ground mode.

### 3. One-time ground initialization — `$E000` / `$E064`

`$E000` first checks `$E049`.

When `$E049 == 0`:

- increments `$E049`, marking the ground module initialized;
- clears `$E9E5` then performs ground setup;
- calls `$E064` to preserve/re-map flight state;
- clears `$F3`;
- if `$CF33 != 0`, sets `$E9E5 = 6` for a special ground case.

`$E064` performs the core state handoff:

- copies `$0748/$0749` into fixed anchor `$074A/$074B`;
- stores the same initial coordinate in mutable `$E060/$E05F` and saved `$06/$07`; ground walking subsequently changes `$E060/$E05F` and mirrors it back into `$0748/$0749`;
- sets bit 1 of `$0764`;
- sets `$0770 = 2`;
- saves `$0703/$0704` into zero-page `$04/$05`;
- saves `$0707/$0708` into `$EDC8/$EDC7`;
- performs the ground graphics/data setup.

After initialization, `$E000` continues at `$E029` on every ground frame rather than repeating the setup.

## Ground frame loop

The resident ground dispatcher executes the following stable chain from `$E029`:

- optional `$EB25` when `$E9E5 == 6`;
- `$E280`;
- `$E15B`;
- `$E271`;
- `$E216`;
- `$EDC9`;
- `$EB5B` return-to-ship check.

Full semantics of the individual ground handlers belong to the next ground-control reconstruction pass.

## Ground → flight: normal return-to-ship path — `$EB5B`

`$EB5B` is called every ground frame and first tests FIRE.

For the normal case it compares the fixed landing/craft anchor against the mutable ground-relative coordinate. Because walking scrolls the world opposite the player, the subtraction yields the player's displacement from the craft:

- X displacement = `$074A - $E060`;
- Y displacement = `$074B - $E05F`.

Normal accepted range:

- X: -7 through +7;
- Y: -7 through +7.

When `$E9E5 == 6`, the lower X bound is widened to -27 while the upper bound remains +7. The reason for this special case is still OPEN.

When the proximity gate succeeds:

1. writes the remaining anchor-to-relative deltas temporarily into integer velocity `$0709/$070B`;
2. calls `$C008 -> $C1FD` to feed those deltas through the normal scroll updater and cancel the accumulated walking scroll;
3. clears those temporary velocities;
4. clears bit 1 of `$0764`;
5. sets `$0770 = 0`;
6. clears `$E049`;
7. clears `$F4`;
8. sets `$F3 = 1`;
9. calls `$E760` to reconcile ground state;
10. restores `$0748/$0749` from saved `$06/$07`;
11. clears sprite-0 high-X state in `$D010`;
12. calls `$C008` again;
13. waits for FIRE release and returns.

On the next main-loop tick `$F4 == 0`, so `$0E30` resumes the normal flight update chain.

## Alternate exit path — `$E720` (OPEN exact purpose)

`$E720` also:

- clears `$E049`;
- clears `$F4`;
- sets `$F3 = 1`;
- reconciles ground state through `$E760`;
- restores swapped graphics through `$E821`;
- clears ground-specific `$0764/$0770` state;
- calls `$E7A6` and jumps through `$EC67`.

It is reached from the ground-side control flow around `$E67B`, not from the ordinary `$EB5B` return-to-ship path. Its exact player-facing purpose remains open and is tracked separately rather than being folded into the normal takeoff behavior.

## Godot reference implementation

`Godot/scripts/flight_model.gd` now preserves the verified flag ordering:

- landing FIRE sets `ground_transition_flag` only;
- the next `step()` performs the `$E000`-equivalent ground initialization;
- `flight_raster_mode` models `$F3`;
- `ground_initialized` models `$E049`;
- `GroundModel.player_offset` models intuitive on-foot displacement from the landing craft while the original scroll coordinate moves inversely;
- FIRE within the verified normal -7..+7 return range cancels the walking displacement and restores the exact landing world position before flight resumes.

Ground walking is now implemented in the deterministic `GroundModel` from the recovered `$E516/$E15B/$E216/$E280` rules. The modern scene exposes the recovered sprite animation and a provisional expanded-world collision bridge; byte-perfect C64 fine-scroll collision alignment remains an explicit open item.

## Current confidence

- Flight FIRE → `$F4` request: **VERIFIED**.
- Next-tick `$E000` dispatch: **VERIFIED**.
- `$E049` one-time initialization behavior: **VERIFIED**.
- `$F3` flight/ground mode behavior: **VERIFIED**.
- `$EB5B` normal return-to-ship proximity gate and flag restoration: **VERIFIED**.
- Meaning of `$E9E5 == 6` widened X range: **OPEN**.
- Exact purpose of alternate `$E720` exit path: **OPEN**.
