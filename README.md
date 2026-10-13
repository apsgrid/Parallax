# Parallax Remake / Reverse Engineering

Working project for reconstructing the 1986 Commodore 64 game **Parallax** into a documented, testable specification suitable for a modern remake.

## Current status

The original C64 media has been preserved and the complete nested loader chain has now been reconstructed through the **fully expanded playable RAM state**.

Primary source:
- \`Source/PARALLAX.D64\`
- SHA-256: \`03ded09446d23096f87ba45356bf6a66ce7a7e3eaf397c77682c5f62c8ed448f\`

Canonical playable snapshot:
- \`Unpacked/playable_ram.bin\` — full 64 KiB RAM state after all known unpacking stages
- output range: \`$0800-$FFFF\`
- expanded bytes: 63,488
- SHA-256: \`232471c51e24254873f182b865378aca60a0b171490d75c66123e007e1cdb137\`

## Reproducible extraction pipeline

1. \`analyze_d64.py\` — parses D64 directory/file chains.
2. \`decrunch_parallax.py\` — first backwards LZ-style decruncher.
3. \`decrunch_stage2.py\` — startup RLE layer.
4. \`decrunch_overlay_game.py\` — document/presentation overlay expansion.
5. \`decrunch_stage4_game.py\` — second backwards LZ layer.
6. \`decrunch_stage5_playable.py\` — final relocation/RLE stage producing the playable RAM image.
7. Inspection scripts provide targeted 6502 disassembly, xrefs and hardware/state scans.

Generated binary dumps live under \`Unpacked/\` and are excluded from public Git publication.

## Gameplay reconstruction now verified

See **\`FLIGHT_STATE.md\`** and **\`flight_state_map.json\`**.

Key findings:

- Joystick reader: \`$0AE5\`
- Flight input/debounce: \`$0E65\`
- 16-step heading: \`$0DBD\`
- flight-height value: \`$0778\`, range \`$03-$28\`
- X velocity fixed-point pair: \`$0709:$070A\`
- Y velocity fixed-point pair: \`$070B:$070C\`
- heading-vector velocity convergence: \`$0F0D\`
- terrain / 3×3 collision sampler: \`$0C1B\` + \`$0BEB\`
- landing gear state: \`$CF13\`
- landing-regime handler: \`$165A\`
- fire / laser / flight-to-ground handler: \`$10DA\`
- projectile state: \`$0779-$077C\`
- world-scroll motion application: \`$0B42\`
- keyboard matrix scanner: \`$2085\`

The original flight controls are now matched to code: RIGHT/LEFT rotate through 16 headings, DOWN climbs, UP dives, FIRE shoots lasers, SPACE toggles landing gear, F7 toggles shields, and RETURN opens the recovered KARD/PASS status display.

## Next reverse-engineering targets

Completed core milestones now include the heading tables, corrected overlay-swapped 480×480 world, flight charset/palette, deterministic flight reference model, the normal flight ↔ ground round trip, SHIP SUPPLY/disembark, byte-aligned outdoor collision, on-foot controls/sprites, the recovered `$C1-$C3 -> $E444` interior layer, the complete KARD/bank/shop/password/RETURN computer state, the scientist stun → KARD offer → capture loop, and the progression-5 transporter/ending path documented in `ENDGAME_STATE.md`.

The first complete gameplay vertical slice is now executable and regression-tested:

**fly → land → SHIP SUPPLY → EXIT SHIP → walk → enter structure → interact with terminal → leave structure → return to craft → take off**

Current targets beyond the completed endgame milestone:

1. Validate the now-implemented authentic three-slot moving-flight-object scheduler against controlled VICE captures, resolve the exact object-destruction presentation, and trace the recovered $CF15 craft-impact event into damage/shield behavior. Spawn/type selection, three-slot records, movement, materialization/animation, region colours, rendering and natural `2*object_state` scoring are implemented.
2. Resolve the exact identities, behavior and player effects of the remaining local entity types 1 and 3.
3. Assign exact semantics to the remaining flight collision tile classes.
4. Identify sprite ownership for ship, shadow, projectiles and landing gear.
5. Finish flight laser/enemy damage behavior and test whether shields have any gameplay effect.
6. Verify interior and ending raster/palette timing against the original.
7. Capture controlled original VICE parity cases for outdoor collision, scientist stun/KARD capture, terminal transactions and the final transporter/ending sequence.

The objective is not to port opaque 6502 code directly. The objective is to recover the game's rules, data and state transitions accurately enough to reimplement them cleanly in a modern engine.


## Builds and platforms

The Godot reconstruction now has reproducible export presets for **Windows x86-64, Web and Android arm64**. Android/Web touchscreen play uses an on-screen control layer that feeds the same recovered simulation inputs as the desktop keyboard rather than a separate mobile ruleset.

See `BUILDING.md` for regeneration, toolchain, packaging and validation instructions. Original source media and generated C64-derived runtime assets remain excluded from Git; local/private builds include the generated runtime data required to play.
