# Parallax Remake / Reverse Engineering

Working project for reconstructing the 1986 Commodore 64 game **Parallax** into a documented, testable specification suitable for a modern remake.

## Current status

The C64 disk image has been extracted and its nested loaders/decrunchers have been reconstructed without modifying the original source media.

Primary source:
- \`Source/PARALLAX.D64\`
- SHA-256: \`03ded09446d23096f87ba45356bf6a66ce7a7e3eaf397c77682c5f62c8ed448f\`

Final playable runtime image reconstructed:
- address range: \`$0801-$DA8C\`
- size: 53,900 bytes
- SHA-256: \`c6b9f9a02b9c84ea335bd9af8986c62b03af2fd03c13cc14ccc771c9251850c3\`

## Reproducible extraction pipeline

1. \`analyze_d64.py\` - parses D64 directory/file chains.
2. \`decrunch_parallax.py\` - first backwards LZ-style decruncher.
3. \`decrunch_stage2.py\` - startup RLE layer.
4. \`decrunch_overlay_game.py\` - document/presentation overlay expansion.
5. \`decrunch_stage4_game.py\` - second backwards LZ layer producing the playable runtime.
6. Inspection scripts provide static 6502 disassembly and hardware-reference scans.

Generated binary dumps live under \`Unpacked/\` and are intentionally not intended for public Git publication.

## First verified runtime facts

- Final entry begins at \`$0801\`.
- Main initialization/game loop work begins around \`$097D\`.
- Joystick normalization routine: \`$0B4B\`.
- Keyboard matrix scan: \`$2046\`.
- Direct CIA joystick/keyboard access uses \`$DC00/$DC01\`.
- Raster/VIC-II handling uses \`$D011/$D012/$D019/$D01A\`.
- Sprite control is heavily used through \`$D015\` and related VIC registers.
- SID is accessed in multiple runtime sections; master volume/filter register \`$D418\` has verified references.
- Runtime text contains explicit systems for scientists, passwords, lasers and shields.

## Next reverse-engineering targets

1. Trace the frame/main-loop call graph from \`$097D\`.
2. Label flight state variables and movement/altitude update routines.
3. Locate landing detection and transition to on-foot state.
4. Map world/region data and collision geometry.
5. Isolate laser/shield damage logic.
6. Decode scientist/password/computer interaction state.
7. Extract graphics, sprites, character sets and SID assets.
8. Write a clean behavioural specification before implementing the remake.

The objective is not to port opaque 6502 code directly. The objective is to recover the game's rules, data and state transitions accurately enough to reimplement them cleanly in a modern engine.
