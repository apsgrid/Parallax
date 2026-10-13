# Parallax C64 Flight Combat / Score State

This document is the authoritative reconstruction of the resident flight laser, terrain collision, verified destructible score path, and the recovered moving-object laser-hit endpoint.

## Confidence convention

- **VERIFIED** — directly demonstrated by canonical RAM bytes, exact data tables, or deterministic code flow.
- **STRONG** — supported by multiple paths but still benefits from runtime parity capture.
- **OPEN** — deliberately not named beyond the available evidence.

## Flight laser fire — $10DA / $10FC (VERIFIED)

Outside the landing-transition branch, held FIRE enters the original laser path only when:

- state gate `$CF02 < 7`;
- no projectile is already active (`$077B == 0`).

The original is therefore a **single-projectile** weapon. It is not the arbitrary stream of visual bolts used by the first Godot prototype.

On fire:

- X `$0779 = $54`;
- Y `$077A = $75`;
- state `$077B = $1E`;
- height snapshot `$077C = current $0778`;
- heading snapshot is stored at `$116B`.

The modern `FlightCombatModel` reproduces this state exactly.

## Projectile movement — $116D+ (VERIFIED)

Each active non-impact projectile subtracts signed heading-table values from X/Y.

X table at `$0E20`:

`0,-1,-2,-3,-4,-3,-2,-1,0,1,2,3,4,3,2,1`

Y table at `$0DF0`:

`6,6,4,3,0,-3,-4,-6,-6,-6,-4,-3,0,3,4,6`

Recovered screen bounds are:

- X: `$0C..$AB`;
- Y: `$32..$B1`.

Crossing a bound clears the projectile.

## Terrain sample geometry — $12F0 -> $0C1B (VERIFIED)

The flight projectile collision path samples a 3×3 character footprint.

The recovered collision priority is centre/cross first, then corners. As zero-based row-major indices:

`[4,1,3,5,7,0,2,8,6]`

The first sample producing a nonzero classifier result owns the collision response.

## Terrain collision classes — $0C91+ (VERIFIED structure)

The resident classifier returns:

- `$31-$3C` -> class 1;
- `$48` -> class 2;
- `$58` -> class 5;
- at projectile height >= `$14`:
  - `$3D` -> class 3;
  - `$64` -> class 4.

There is also a dynamic class-5 band around `$93/$94`.

The player-facing names of all classes remain open unless separately established.

### Dynamic $93/$94 band

Startup values:

- upper threshold `$012C = $94`;
- lower threshold `$012D = $93`.

The animation update at `$2420-$2433` computes:

`expansion = floor($23C9 / 8)`

then:

- upper = `$94 + expansion`;
- lower = `$93 - expansion`.

The exact runtime scheduling/enable condition for the `$23CB` animation remains a parity task. The reference model implements the exact threshold formula without inventing an activation cadence.

## Collision response records — $1349-$135C (VERIFIED)

Each class selects four bytes:

`[impact cadence, effect selector, sound/destructible selector, state low bits]`

Recovered records:

1. `[2,5,11,$00]`
2. `[2,6,1,$21]`
3. `[2,6,1,$21]`
4. `[2,2,11,$00]`
5. `[2,3,11,$00]`

Classes 2 and 3 have selector 1 and therefore call the destructible routine at `$147F`.

## Impact animation — $11C9+ (VERIFIED)

Projectile impact state uses the high bit of `$077B`.

The state advances when an internal counter reaches the selected cadence. For the recovered terrain classes the cadence is 2 frames.

Terminal impact states:

- `$87`;
- `$AB`.

Reaching either clears projectile X/Y/state.

## Destructible terrain score path — $147F (VERIFIED)

This is the first completely reconstructed natural score source.

A destructible hit:

1. writes a 3×3 blast pattern into the active screen/world cache;
2. writes pending score `$022D = $0F`;
3. jumps to the master-metatile writeback path `$1A57`.

Therefore the exact award is:

**+15 points**

The blast pattern is:

```
3E 04 3E
04 40 04
3E 04 3E
```

This is now integrated into ordinary Godot flight play.

### Direct master-map writeback — $1A57 (VERIFIED correction)

An earlier reconstruction treated adjacent bytes around `$1AB4/$1AB9` as a generic nine-value lookup. That is not the direct laser-writeback behavior.

The `$147F` pattern loop exits with X=9 before jumping to `$1A57`. Consequently the direct hit compares only:

- master ID `$F7`;

and replaces it with:

- `$00`.

The adjacent table bytes are also consumed by the distinct maintenance routine `$1AC1`.

The modern implementation preserves this distinction and does not perform a fabricated arbitrary-ID destruction search.

## Six-digit score accumulator — $0226-$022D (VERIFIED)

The visible score consists of six ASCII decimal digits at `$0226-$022B`.

`$022D` is the pending score increment.

Routine `$2275+`:

1. adds pending increment to the least-significant displayed digit;
2. normalizes decimal carry through all six digits;
3. clears `$022D`.

The Godot `EndgameModel` stores the equivalent integer score and formats it as six digits.

One authentic +15 terrain hit changes:

`000000 -> 000015`

The recovered initial best score is `000010 CHRIX`, so **one verified destructible hit is sufficient to make the original ending qualification naturally reachable**.

No points are awarded merely for firing.

## Moving-flight-object laser hit — $FBFF-$FC4C (VERIFIED endpoint)

The original contains a separate three-slot moving-object subsystem.

The complete $F874 three-record scheduler is now statically reconstructed and implemented in modern play. Each persistent record is copied through the $F825 scratch state, updated in original order, then copied back before the next of exactly three slots. The previously verified laser-hit endpoint is now reached naturally by these scheduled objects.

The collision routine requires:

- player projectile active;
- projectile not already in impact state.

### Object height categories

Category is `object_state & 3`.

Recovered projectile-height bands are lower-inclusive / upper-exclusive:

- category 0: `$07..$5F` when invoked by the surrounding object state;
- category 1: `$14..$22`;
- category 2: `$00..$13`;
- category 3: `$1C..$31`.

### Hit rectangle

For both X and Y, the unsigned subtraction must represent a signed delta:

**-11 through +9 inclusive**

### Hit result

A successful moving-object laser hit:

- clears player projectile state `$077B`;
- writes pending score:
  `$022D = 2 * full object_state`;
- transitions/removes the object through the surrounding object scheduler.

Because the full byte is doubled rather than only the low category bits, states such as 5/6/7 award 10/12/14 points.

`FlightCombatModel.resolve_moving_object_hit()` implements this exact endpoint and is regression-tested. `step_objects()` now supplies the authentic three-slot spawn/movement lifecycle around it; no substitute enemy system is used.

## Godot implementation

`Godot/scripts/flight_combat_model.gd` implements:

- single-projectile fire gate;
- exact projectile initial state;
- heading-vector movement;
- screen bounds;
- 3×3 collision priority;
- verified terrain classes;
- collision response records;
- impact cadence/termination;
- exact dynamic-band threshold formula;
- verified +15 destructible score path;
- direct `$F7 -> $00` master writeback rule;
- moving-object category height bands;
- moving-object hit rectangle and `2*object_state` score endpoint;
- exact three-slot $F874 record scheduler;
- recovered surface/void/edge spawn categories;
- recovered surface and edge movement tables plus craft-X compensation;
- recovered materialization and state animation sprite-pointer tables;
- recovered five-region object-colour table;
- craft/object and same-category object/object overlap destruction paths;
- 20-frame object explosion lifetime and natural moving-object score production;
- exact `$FACC` hostile-fire trigger with independent attack RNG;
- exact two-slot `$FDF1/$FE80` hostile-projectile lifecycle, movement, sprite animation and `$BE-$C7` impact sequence;
- hostile-projectile contact routed through the recovered ENGINE/LAZERS damage consumer.

`FlightModel` owns the combat model and feeds verified score awards into the same `EndgameModel` used by the recovered final score gate.

`main.gd` now:

- advances the original single projectile instead of spawning cosmetic bolts;
- samples real world terrain;
- applies the verified blast pattern;
- updates the runtime expanded world and master map when direct writeback is verified;
- renders the recovered player shot/impact state and both recovered hostile-fire slots in the modern 3D presentation.

## Verification

Static authority:

- `verify_flight_combat.py`
- `verify_flight_aux_projectiles.py`

Deterministic coverage:

- `Godot/tests/test_flight_combat_model.gd`
- `Godot/tests/test_flight_combat_integration.gd`
- `Godot/tests/test_flight_aux_projectiles.gd`

The integration regression proves:

**FIRE -> recovered projectile -> $48 destructible collision -> +15 -> score 000015 -> strict qualification over CHRIX 000010**

## Three-slot moving-object scheduler — $F874 (VERIFIED structure, IMPLEMENTED)

The scheduler owns three persistent object records. For each slot it copies the first 12 live bytes through the $F825 scratch record, executes the per-object chain, writes the record back, and repeats until the slot counter reaches exactly three.

Recovered per-object order at $F8CA:

1. spawn/materialization ($F8EA);
2. movement ($F9D0);
3. hostile-projectile spawn attempt ($FACC);
4. animation/presentation updates ($FB8A/$FB4F);
5. player-laser collision ($FBFF);
6. craft/object and object/object collision handling ($F76D).

Recovered motion data includes the cardinal surface vectors at $FA7C/$FA81, 17-entry craft-X compensation at $FA86, and eight-direction edge-object vectors at $FB3F/$FB47. Sprite-pointer animation tables are recovered at $FD91-$FDC0 and the five-region colour table begins at $FDC9.

Godot now executes this scheduler before advancing the player projectile, creates exactly three persistent visual slots, decodes the recovered VIC-II sprite pointers locally, applies the recovered per-object colours, and allows the verified `2*object_state` awards to occur naturally.

Static verification: `verify_flight_objects.py`.
Deterministic regression: `Godot/tests/test_flight_object_scheduler.gd`.

## Hostile object fire — $FACC -> $FF58 -> $FDF6 (VERIFIED, IMPLEMENTED)

The formerly open `$FACC` branch is now resolved end-to-end. Every active moving object consumes the independent `$FBC4` cursor over the shared `$0900` byte stream; a low-three-bit result of 4 attempts to fire.

`$FF58` owns exactly two persistent hostile-projectile records at `$FDF1-$FDF5` and `$FE80-$FE84`. A successful allocation copies the firing object's X/Y and full state, then consumes the primary `$FBB9` RNG cursor for one of eight directions. If both projectile records are occupied the shot is dropped without consuming that direction RNG.

After all three moving-object records have run, `$F8C6` tail-calls `$FDF6`. Both hostile shots then:

- apply the same 17-entry craft-X compensation table at `$FA86` used by object motion;
- add craft Y velocity `$070B`;
- add the recovered eight-direction vectors at `$FB3F/$FB47`;
- clear when X leaves `1..199` or Y leaves `5..249`;
- share the active VIC-II sprite-pointer cycle `$56,$57,$58,$59,$58,$57`, advancing every four scheduler ticks.

Craft contact reuses `$F773` and therefore the same object-category height bands and signed `-11..+9` X/Y contact rectangle. A hit reaches `$FFA3`, queues `[2,2,3,2]` through `$CF15`, and consequently damages ENGINE or LAZERS through the already verified `$2022` consumer. The hostile shot then enters the original `$BE-$C7` impact sprite sequence; the explosion pointer advances every second tick according to the preserved direction-counter parity and the slot clears at `$C7`.

The `$FFB9` alternate anchor check is gated by `$F4 != 0`. Normal flight runs with `$F4 == 0`, while the modern scheduler is already suspended once the flight-to-ground transition is active, so no ship/shadow ownership is invented for `$074A/$074B`.

Static verification: `verify_flight_aux_projectiles.py`.
Deterministic regression: `Godot/tests/test_flight_aux_projectiles.gd`.

## Craft-impact damage — $FFA3 -> $CF15 -> $2022 (VERIFIED, IMPLEMENTED)

Moving-object contact queues one of `[2,2,3,2]` at `$CF15`. The downstream status/damage routine at `$2022` is now traced exactly:

- event 2 indexes `$CF01`, whose original status label is **ENGINE**;
- event 3 indexes `$CF02`, whose original status label is **LAZERS**;
- `$207A` increments an 8-bit cursor and reads `$C000,Y`;
- `$2022` masks that byte with 7, adds 2, and adds the resulting **2–9** damage to the selected byte;
- `$2058` runs from the ordinary status path and, every `$5A` (90) ticks, decrements nonzero `$CF00/$CF01/$CF02` by one.

Verified gameplay thresholds:

- `$CF01 ENGINE >= $28` (40): `$093C` zeros the craft integer velocity bytes and `$10EF` refuses the landing transition;
- `$CF02 LAZERS >= 7`: `$10FC` refuses laser fire;
- the higher indirect ENGINE-failure branch reached at `$CF01 >= $3C` (60) is still being resolved before it is modeled.

The Godot model now consumes craft-collision event codes in the same frame, applies the recovered 2–9 damage source, decays the three damage fields every 90 status ticks, enforces the ENGINE landing/motion threshold, and enforces the LAZERS fire lockout.

Static verification: `verify_flight_damage.py`.
Deterministic regression: `Godot/tests/test_flight_damage.gd`.

### Shields on this path — VERIFIED no consumer

`$CF26` remains the F7 SHIELDS OFF/ON toggle. Full direct-reference analysis finds only the status display read and the `$2014-$2019` toggle itself. Crucially, neither `$FFA3` nor the now-complete `$2022` impact consumer reads `$CF26`, and the indexed damage target is selected only from `$CF00-$CF02`.

Therefore **both recovered moving-object contact and hostile-projectile contact are not shield-reduced**. Hostile shots converge on the same `$FFA3 -> $CF15 -> $2022` consumer, so resolving `$FACC` adds no hidden `$CF26` read. Original Rules mode preserves the shield toggle/status state but deliberately does not invent protection for these verified collisions. An unrelated overlay or still-unresolved indirect path could only change this conclusion with new evidence.

## Current boundary

The **flight laser, terrain collision, authentic destructible-score path, three-slot moving-object scheduler, two-slot hostile-projectile subsystem, and ENGINE/LAZERS impact damage are reconstructed and implemented**.

Remaining flight-combat evidence work is now narrower:

- capture controlled VICE parity for projectile timing, destructible writeback, one spawn/movement sequence, one moving-object hit, and one craft-impact damage event;
- verify exact original object-destruction presentation rather than treating the modern fade/scale as original behavior;
- resolve the indirect `$CF01 >= $3C` catastrophic ENGINE-failure branch before implementing it;
- resolve the exact activation cadence for the dynamic $93/$94 collision-band animation.
