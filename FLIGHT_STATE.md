# Parallax C64 Flight-State Map

This document describes the first verified gameplay-state reconstruction from the fully expanded playable RAM image.

## Confidence convention

- **VERIFIED** — directly demonstrated by code/data flow.
- **STRONG** — semantics are strongly supported by code plus the original controls/manual.
- **OPEN** — address/function role is known, but exact player-facing semantics still need runtime verification.

## Canonical playable image

Stage 5 expands the previous image into essentially the complete C64 address space.

- Decompressor entry after stage 4: \`$0801\`
- Stage-5 compressed stream after relocation: \`$2E0F-$FFFF\`
- Playable output order: \`$0800-$FFFF\`, then \`$0000-$0003\`
- Output bytes: 63,488
- Wrapped-image SHA-256: \`5f0fc248e0a9249e92798a2e753b32735d4e3b8674816ce6113879eaf2ce6795\`
- Post-decompression handoff: \`$7C00\`

The working complete RAM snapshot is \`Unpacked/playable_ram.bin\`.

## Core flight controls

Original controls are mirrored exactly by the code:

- joystick LEFT -> turn anti-clockwise
- joystick RIGHT -> turn clockwise
- joystick UP -> dive
- joystick DOWN -> climb
- fire -> lasers
- SPACE -> landing gear toggle
- F7 -> shields toggle
- RETURN -> datacards/password display

### Joystick reader — $0AE5 (VERIFIED)

Reads CIA1 port A \`$DC00\`, converts the active-low C64 joystick bits to active-high, then reverses the four directional bits.

Returned bitfield:

| Bit | Value | Meaning |
|---|---:|---|
| 0 | $01 | RIGHT |
| 1 | $02 | LEFT |
| 2 | $04 | DOWN / climb |
| 3 | $08 | UP / dive |
| 4 | $10 | FIRE |

Fire is also cached temporarily in zero-page \`$8F\`.

### Debounced flight-input handler — $0E65 (VERIFIED)

The four direction bits are individually accumulated in \`$0E5D-$0E60\` and compared against repeat thresholds in \`$0E61-$0E64\`.

Actions:
- RIGHT -> \`$0EDD\`: increment heading.
- LEFT -> \`$0EE9\`: decrement heading.
- DOWN -> \`$0EF5\`: increment flight-height value.
- UP -> \`$0F01\`: decrement flight-height value.

## Primary flight-state variables

### $0DBD — heading index (VERIFIED)

- 4-bit value, masked with \`#$0F\`.
- Range: 0-15.
- RIGHT increments it.
- LEFT decrements it.
- Used to index directional velocity tables.

Interpretation: 16 discrete headings around 360 degrees.

### $0778 — flight-height / vertical flight level (STRONG)

- Hard range enforced by input code: \`$03-$28\` (3-40).
- DOWN/climb increments it.
- UP/dive decrements it.
- Used by terrain/collision and ship-shadow/vertical projection code.
- Landing/ground-contact logic is concentrated around \`$14-$15\`.

This should be represented in the remake as an explicit Z/height state, not merely a cosmetic sprite offset.

### $0709:$070A — X velocity, signed fixed-point (VERIFIED)

- \`$0709\`: signed integer component.
- \`$070A\`: fractional accumulator.
- The velocity converges toward a heading-derived target.
- Positive and negative values are handled explicitly.

### $070B:$070C — Y velocity, signed fixed-point (VERIFIED)

- \`$070B\`: signed integer component.
- \`$070C\`: fractional accumulator.
- Same convergence model as X.

### $1659 — acceleration/deceleration step (VERIFIED)

Normal flight:
- \`$1659 = $40\`

Landing/low-altitude regime:
- \`$1659 = $0C\`

The smaller landing value makes velocity changes substantially gentler/slower.

### $0B40 / $0B41 — scrolling/world-position accumulators (STRONG)

Routine \`$0B42\` applies integer X/Y motion \`$0709/$070B\` to these values every update, then derives map/source addresses used to copy visible world data.

These are part of the scrolling/world-position system rather than velocity themselves.

## Flight update chain

The same update chain appears in several resident/mirrored banks. One clean copy begins at \`$0E30\`.

### Flight dispatcher — $0E30 (VERIFIED)

Pseudo-flow:

\`\`\`
if scripted_state ($139F):
    goto scripted movement $13A0

if ground_transition ($F4):
    goto $E000

update_laser_projectile()      ; $113A
read_flight_controls()         ; $0E65
converge_velocity_to_heading() ; $0F0D
update_landing_regime()        ; $165A
enforce_height_collision()     ; $10BB
update_heading_render_state()  ; $0F78
update_animation_phase()       ; $107B
handle_fire_or_transition()    ; $10DA
update_special_projectile()    ; $135F
tail_update()                  ; $19D5
\`\`\`

Equivalent copies exist around:
- \`$3D0D\`
- \`$6BEA\`
- \`$9AC7\`
- \`$C9A4\`

## Horizontal flight physics

### Velocity convergence — $0F0D (VERIFIED)

1. Uses \`$0DBD\` heading plus mode \`$124E\`.
2. Reads target X/Y integer velocity from tables around:
   - \`$0DD0/$0E00\`
   - related tables \`$0DE0/$0E10\`
3. Compares current signed X/Y velocity to target.
4. Adjusts the fractional byte by \`$1659\`.
5. Carries/borrows into the signed integer byte.

This is acceleration toward a heading vector, not instantaneous movement.

### Collision response / forced velocity — $0F98+ (VERIFIED)

Terrain sampling can replace current X/Y velocity directly from collision-response tables around \`$1044-$1078\`, depending on the collision class and current mode.

## Terrain and collision

### 3×3 footprint sampler — $0BEB / $0C1B (VERIFIED)

\`$0C1B\` converts craft screen/world coordinates into a map-data pointer and samples nine cells using offsets from \`$1313+\`.

The nine sampled tile values are cached at \`$0C09-$0C11\`.

\`$0BEA\` counts how many of those nine samples fall outside tile-code range \`$0D-$10\`.

The routine classifies several special tile ranges/codes and returns a collision/category result in A/Y/X.

### Landing-clearance relationship (VERIFIED structure, OPEN exact tile taxonomy)

At flight-height near the ground-contact band, the 3×3 sample count and tile classification alter the craft collision/clearance masks \`$075D/$0763\`.

Exact names for every tile class remain to be assigned after world-data extraction.

## Landing gear and landing-ready state

### $CF13 — landing gear flag (VERIFIED)

SPACE is decoded by the keyboard scanner and sets event flag \`$CF14\`.

Handler \`$1FEB-$2006\`:
- waits for the event,
- clears the event,
- XORs \`$CF13\` with 1.

Therefore:
- \`$CF13 = 0/1\` is the landing-gear state.

Some state transitions force \`$CF13 = 0\`.

### Landing-ready logic — $165A (STRONG)

Landing-specific behaviour is enabled when all of the following are true:

- \`$0778 == $15\`
- landing gear \`$CF13 != 0\`
- the sampled footprint count \`$0BEA == 9\`

When true:
- acceleration step changes from \`$40\` to \`$0C\`;
- \`$10FB\` becomes 1;
- transition timer/state \`$19D4\` is set.

Interpretation: craft is at the landing flight level, gear is down, and the footprint is considered clear/acceptable.

### $10FB — landing/ground-transition eligibility flag (STRONG)

Set only by the landing-ready path above; cleared in normal flight.

### $F4 — flight-to-ground transition state (STRONG)

The flight dispatcher jumps to \`$E000\` whenever \`$F4 != 0\`.

\`$10DA\` can set \`$F4=1\` while \`$10FB\` is active, X/Y integer velocity is zero, and an additional game-state threshold is satisfied.

This is very likely the final transition from flight to the on-ground module. Exact player-visible timing should be checked dynamically.

## Landing gear / shield / datacard keyboard flags

The keyboard event layer around \`$1FC7-$20F6\` is now mapped:

- SPACE event \`$CF14\` -> toggles landing gear \`$CF13\`.
- F7 event \`$CF27\` -> toggles \`$CF26\` (strongly identified as shields).
- RETURN event \`$CF28\` -> invokes the datacard/password display handler.

## Lasers / projectile state

### Fire handler — $10DA (VERIFIED structure)

If landing-transition eligibility is not active, FIRE enters the laser/projectile path when allowed by cooldown/state checks.

If no projectile is currently active, the routine initializes:

- \`$0779 = $54\`
- \`$077A = $75\`
- \`$077B = $1E\`
- \`$077C = current $0778 flight-height\`
- heading snapshot stored at \`$116B\`

### Projectile variables — $0779-$077C (STRONG)

- \`$0779\`: projectile X/screen coordinate.
- \`$077A\`: projectile Y/screen coordinate.
- \`$077B\`: projectile life/state; zero means inactive.
- \`$077C\`: projectile flight-height snapshot.

\`$113A+\` and \`$116D+\` update projectile position/lifetime using heading-vector lookup tables.

## Rendering/projection anchors

### $0748/$0749 and $074A/$074B (STRONG)

Initialized as paired coordinate sets.

Routine \`$1094\` derives the second pair from the first plus \`$0778\`:
- one coordinate subtracts roughly height/2;
- the other adds height.

This is consistent with the ship/shadow or height-projection relationship. Exact sprite ownership still needs VIC sprite-pointer tracing.

## Remake implementation implications

The first modern flight prototype should preserve these mechanics before changing feel:

1. 16 discrete headings.
2. Separate X/Y signed fixed-point velocity.
3. Acceleration toward a heading-vector target instead of direct positional steering.
4. Explicit flight-height/Z value.
5. Dive/climb independent of horizontal heading.
6. 3×3 ground/terrain footprint sampling.
7. Landing gear as an independent state.
8. A landing-ready regime with reduced acceleration and zero-horizontal-speed requirement.
9. Projectile/laser altitude captured at firing time.

For the remake we can later expose smoother analogue steering and interpolation, but these original rules should remain available as the reference/original handling model.


## Recovered heading target tables

The playable runtime contains two 16-direction integer velocity target sets.

Mode 0:
- H00 (0, 2)
- H01 (-1, 2)
- H02 (-2, 2)
- H03 (-2, 1)
- H04 (-2, 0)
- H05 (-2, -1)
- H06 (-2, -2)
- H07 (-1, -2)
- H08 (0, -2)
- H09 (1, -2)
- H10 (2, -2)
- H11 (2, -1)
- H12 (2, 0)
- H13 (2, 1)
- H14 (2, 2)
- H15 (1, 2)

Mode 1:
- H00 (0, 3)
- H01 (-2, 3)
- H02 (-3, 3)
- H03 (-3, 2)
- H04 (-3, 0)
- H05 (-3, -2)
- H06 (-3, -3)
- H07 (-2, -3)
- H08 (0, -3)
- H09 (2, -3)
- H10 (3, -3)
- H11 (3, -2)
- H12 (3, 0)
- H13 (3, 2)
- H14 (3, 3)
- H15 (2, 3)

These values are now used directly by the Godot reference controller rather than approximated with trigonometry.
