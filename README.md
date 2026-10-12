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

The original flight controls are now matched to code: RIGHT/LEFT rotate through 16 headings, DOWN climbs, UP dives, FIRE shoots lasers, SPACE toggles landing gear, F7 toggles shields, and RETURN opens datacard/password handling.

## Next reverse-engineering targets

Completed core milestones now include the heading tables, 480×480 world format, flight charset/palette, deterministic flight reference model, and the normal flight ↔ ground round trip.

Current targets:

1. Reconstruct ground/on-foot controls and movement state.
2. Resolve the special `$E9E5 == 6` return range and alternate `$E720` exit path.
3. Assign exact semantics to the remaining collision tile classes.
4. Identify sprite ownership for ship, shadow, projectiles and landing gear.
5. Finish laser/enemy damage behavior and test whether shields have any gameplay effect.
6. Decode RETURN/datacard/password and scientist/computer interaction state.
7. Reconstruct the first complete fly → land → on-foot → interact → return → takeoff vertical slice.

The objective is not to port opaque 6502 code directly. The objective is to recover the game's rules, data and state transitions accurately enough to reimplement them cleanly in a modern engine.
