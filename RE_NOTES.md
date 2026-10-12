# Reverse-engineering notes

## Source inventory

Ichabod path: \`E:\Projects\Parallax\`

Preserved source captures:
- \`Parallax (Europe).nib\` - 327,936 bytes
- \`Parallax (Europe).tap\` - 702,898 bytes
- \`PARALLAX.D64\` - 174,848 bytes
- \`PARALLAX.T64\` - 8,618 bytes

The D64 contains a main PRG called \`PARALLAX+\` loading at \`$0801\`.

## Packing / loader chain

### Stage 1 - outer LZ-style packer

BASIC stub: \`SYS 2059\` -> \`$080B\`.

Bootstrap copies a 256-byte decruncher from \`$BEA2\` to \`$00F0\` and jumps to \`$014E\`.

Important embedded state:
- bit-buffer seed: \`$C0\`
- table/compressed boundary: \`$BDA2\`
- destination starts backwards at \`$D6BF\`
- completion target: \`$0801\`

Verified result:
- output \`$0801-$D6BF\`
- 52,927 output bytes
- final destination lands exactly at \`$0801\`

### Stage 2 - relocation + RLE

Startup relocates \`$07C0-$D6BF\` upward by \`$293F\`, producing a stream at \`$31AC-$FFFE\`.

Decoder output starts at \`$0800\`.

Encoding:
- ordinary byte -> one byte
- \`BB count value\` -> repeated value
- \`ED value\` -> value repeated exactly 3 times

Verified result:
- output \`$0800-$D719\`
- 53,018 output bytes
- SHA-256 \`0537f6d09984fff5e0de38dddf2a1e49970e3ae045d2891046fc62f596195e6b\`

### Stage 3 - document/presentation overlay

Relocation:
- source \`$171A-$D719\`
- destination \`$3FFF-$FFFE\`
- delta \`$28E5\`
- compressed stream starts \`$4200\`

Encoding:
- \`DE count value\` -> repeat value
- \`9B value\` -> repeat value 3 times
- \`D9 count\` -> repeat space (\`$20\`)
- \`B6 count\` -> repeat zero

Output:
- \`$0800-$EF3F\`
- 59,200 bytes
- entry \`$CA98\`
- SHA-256 \`0298aa64a35ac038af1010936a8106554125ede69471edff5b0e540c31d99a66\`

This overlay contains the embedded Parallax documentation/presentation screens.

### Stage 4 - intermediate game LZ layer

The document overlay exits via \`$080B\`.

That bootstrap copies another instance of the stage-1 LZ decruncher family from \`$8EE8\` to zero page.

Parameters:
- bit-buffer seed: \`$F8\`
- table/compressed boundary: \`$8DE8\`
- destination starts backwards at \`$DA8C\`
- completion target: \`$0801\`

Verified result:
- output \`$0801-$DA8C\`
- 53,900 bytes
- final destination lands exactly at \`$0801\`
- SHA-256 \`c6b9f9a02b9c84ea335bd9af8986c62b03af2fd03c13cc14ccc771c9251850c3\`

## Runtime landmarks

### Main initialization

Around \`$097D\` the game performs a stable sequence of subsystem calls, then synchronizes to the VIC raster. This is the current anchor for reconstructing the frame loop.

### Joystick normalization - $0B4B

Reads CIA1 port A \`$DC00\`, inverts active-low inputs, masks to five joystick bits, then normalizes them to:

- bit 0 (\`$01\`) = RIGHT
- bit 1 (\`$02\`) = LEFT
- bit 2 (\`$04\`) = DOWN
- bit 3 (\`$08\`) = UP
- bit 4 (\`$10\`) = FIRE

The normalized value is returned in A. Fire is also cached in zero-page \`$8F\`.

This is a useful compatibility contract for the remake input layer.

### Keyboard scanner - $2046

Scans the C64 keyboard matrix by writing row masks to \`$DC00\`, reading stable values from \`$DC01\`, applying per-key masks, and returning/dispatching key state using tables around \`$20B8+\`.

### Other verified systems

Text/data searches in the final runtime locate:
- \`PARALLAX\` at approximately \`$4064\`
- \`PASSWORD\` around \`$5E59\`
- multiple \`SCIENT...\` strings/data regions
- \`LAZER\` references around \`$1CE1/$1F26\`
- \`SHIELD\` references around \`$1D92/$1D9F/$1F3E/$1F4E\`

These are search anchors only; code/data boundaries still need to be labelled before assigning semantics.

## Method rule

Do not linear-disassemble large unknown ranges and assume they are code. Parallax uses compressed overlays, data tables and self-modifying loader code. Every subsystem label should be backed by a call/reference path or runtime hardware access.


### Stage 5 - final playable expansion

**Correction to the earlier Stage 4 label:** Stage 4 is still an intermediate packed image. Its entry at \`$0801\` performs one more relocation/RLE pass before the actual playable state is available.

Stage-5 bootstrap:
- relocates source range \`$078D-$DA8C\` upward by \`$2572\`
- compressed stream begins at \`$2E0F\`
- decoder output begins at \`$0800\`
- completion handoff: \`$7C00\`

Encoding:
- ordinary byte -> literal
- \`D1 count value\` -> repeat value
- \`D7 value\` -> repeat value 3 times
- \`CB count\` -> repeat zero
- \`75\` -> two zero bytes
- \`D3 count\` -> repeat \`$2A\`
- \`A1\` -> two \`$2A\` bytes
- \`AF count\` -> repeat space (\`$20\`)

Verified result:
- output order \`$0800-$FFFF\`, then \`$0000-$0003\`
- 63,492 expanded bytes
- wrapped-image SHA-256 \`5f0fc248e0a9249e92798a2e753b32735d4e3b8674816ce6113879eaf2ce6795\`
- canonical RAM snapshot: \`Unpacked/playable_ram.bin\`

## Flight-state reconstruction

Detailed labels are maintained in \`FLIGHT_STATE.md\` and \`flight_state_map.json\`.

High-confidence state:
- \`$0DBD\` — 16-step heading.
- \`$0778\` — flight-height / vertical flight level.
- \`$0709:$070A\` — signed fixed-point X velocity.
- \`$070B:$070C\` — signed fixed-point Y velocity.
- \`$1659\` — acceleration step; \`$40\` normal, \`$0C\` in landing regime.
- \`$CF13\` — landing gear state, toggled from SPACE event handling.
- \`$10FB\` — landing-ready / ground-transition eligibility.
- \`$0779-$077C\` — laser/projectile state block.
- \`$0B40/$0B41\` — scrolling/world-position accumulators.

Primary routines:
- \`$0AE5\` joystick normalizer.
- \`$0E65\` flight input/debounce.
- \`$0F0D\` heading-vector velocity convergence.
- \`$0C1B\` terrain/collision classifier.
- \`$0BEB\` 3×3 footprint sampler.
- \`$165A\` landing-regime detector.
- \`$10BB\` height/collision guard.
- \`$10DA\` fire / laser / ground-transition handler.
- \`$113A+\` projectile update.
- \`$0B42\` applies integer motion to world-scroll accumulators.
- \`$2085\` keyboard matrix scanner.

The flight update chain is mirrored in several resident banks. A clean copy starts at \`$0E30\` and calls the routines above in stable order.
