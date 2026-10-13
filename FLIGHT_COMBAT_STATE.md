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

Its complete spawn/movement/render scheduler is not yet implemented in modern play, but the laser-hit endpoint is exact.

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

`FlightCombatModel.resolve_moving_object_hit()` implements this exact endpoint and is regression-tested. The modern game does not yet fabricate moving targets to trigger it.

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
- moving-object hit rectangle and `2*object_state` score endpoint.

`FlightModel` owns the combat model and feeds verified score awards into the same `EndgameModel` used by the recovered final score gate.

`main.gd` now:

- advances the original single projectile instead of spawning cosmetic bolts;
- samples real world terrain;
- applies the verified blast pattern;
- updates the runtime expanded world and master map when direct writeback is verified;
- renders the recovered projectile/impact state in the modern 3D presentation.

## Verification

Static authority:

- `verify_flight_combat.py`

Deterministic coverage:

- `Godot/tests/test_flight_combat_model.gd`
- `Godot/tests/test_flight_combat_integration.gd`

The integration regression proves:

**FIRE -> recovered projectile -> $48 destructible collision -> +15 -> score 000015 -> strict qualification over CHRIX 000010**

## Current boundary

The **flight laser / terrain collision / authentic destructible-score path is reconstructed and implemented**.

The moving-object laser-hit endpoint is also reconstructed and modeled, but the remaining flight-combat obligation is narrower:

- reconstruct and integrate the complete original **three-slot moving flight-object spawn/movement/render scheduler** around `$F700-$FFxx`;
- thereby make the already-verified `2*object_state` score awards occur naturally;
- capture controlled VICE parity for projectile timing, destructible writeback, and one moving-object hit;
- separately finish any craft-damage/shield coupling associated with those objects.
