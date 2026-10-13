# Parallax C64 World Format

The corrected fully expanded playable image reveals the original flight world as a two-level tile hierarchy.

## Master map

- Base: `$8000`
- Dimensions: **96 × 96 macro cells**
- Storage: one byte per macro cell
- Size: 9,216 bytes
- Each byte selects one of 256 metatiles

### Canonical snapshot layout / overlay swap

The **runtime** map base is still `$8000`, but the corrected Stage-5 snapshot is captured before the title/flight overlay swap. In that image:

- `$8000-$8FFF` contains title/ending overlay code;
- the runtime map's first `$1000` bytes are parked under C64 I/O at `$D000-$DFFF`;
- `$9000-$A3FF` already contains the remainder of the map.

Routine `$CFA3` swaps `$8000-$8FFF` with RAM-under-I/O `$D000-$DFFF` when entering gameplay. Therefore an extractor working from `playable_ram.bin` must reconstruct the runtime map as:

`RAM[$D000:$E000] + RAM[$9000:$A400]`

The earlier extractor incorrectly read the pre-swap title overlay as the first 4096 map bytes. The corrected extractor now also emits the 96x96 `master_tiles` array and transporter destination metadata into the ignored local JSON.

Corrected world statistics:
- **204** distinct master metatile IDs;
- **202** distinct expanded final tile codes.

## Metatile table

- Base: `$269C`
- Count: 256 metatiles
- Each metatile: **5 × 5 tile codes**
- Storage: 25 bytes per metatile
- Total size: 6,400 bytes

Expanding the macro-map therefore produces a **480 × 480 tile world**.

The address calculator at `$C176` performs the hierarchy:

1. Use the macro Y coordinate to select one of the 96-byte rows via the pointer table at `$033C/$033D`.
2. Read the macro-cell byte at macro X.
3. Use that byte as an index into the metatile pointer table at `$03FC/$04FC`.
4. Add the 5×5 fine X/Y offset to obtain the final tile code.

The scroll renderer around `$C0DB-$C43F` copies those tile codes into the alternating 40-column C64 screen buffers at `$7800` and `$7C00`.

## Original viewport and player start

The startup routine initially writes:
- macro X: `$0707 = 2`
- macro Y: `$0708 = 10`
- fine X: `$0705 = 0`
- fine Y: `$0706 = 0`

That raw state corresponds to expanded tile coordinate **(10, 50)**, but it is not the final gameplay viewport. The game then performs 20 deliberate pre-scroll frames with Y scroll velocity `$070B = $08`. Because one character tile is 8 scroll units and one macro cell is 5 tiles, those 20 frames move the viewport upward by 20 tiles.

Verified post-startup viewport origin:
- **tile (10, 30)**

The player collision routine `$0C1B` samples the craft at screen column 18, row 8 and checks a 3×3 footprint. The footprint therefore begins at world tile **(28, 38)** and its centre is approximately:
- **player start tile (29, 39)**

The Godot reference controller uses 8 original scroll units per expanded tile and anchors player displacement at tile (29, 39).

## Collision / landing

The flight collision sampler works against the rendered screen buffer, but those screen codes are the expanded world tile codes.

For landing readiness, the 3×3 footprint counts a cell as acceptable when its code is **outside `$0D-$10`**. All nine cells must qualify.

Other collision classes currently verified by the classifier include:
- `$31-$3C`
- `$48`
- `$58`
- altitude-dependent dynamic ranges around `$93/$94`

Exact semantic names for those classes are still being reconstructed.

## Godot integration

`extract_world.py` expands the original hierarchy into local generated data for the Godot prototype.

The generated `Godot/data/world_480.json` is deliberately ignored by Git because it contains derived original level data. The extractor and format documentation are versioned instead.

The Godot renderer now streams a moving window over the full recovered 480×480 world. Player displacement is anchored at the verified start centre (29, 39), and landing checks query the original C64 tile codes directly.

## Scroll accumulator sign

The scroll updater at `$C1FD` adds integer X/Y velocity `$0709/$070B` into fine scroll `$0703/$0704`.

When a positive fine-scroll value wraps past 7, the normalization routines `$C00E/$C03F` subtract 8 from the fine value and **decrement** the corresponding tile offset `$0705/$0706`. Tile-offset underflow then decrements macro coordinate `$0707/$0708`.

Therefore the world-coordinate relationship is:

- positive C64 scroll accumulation -> negative expanded-world displacement;
- negative C64 scroll accumulation -> positive expanded-world displacement.

The Godot renderer now preserves `world_x/world_y` as C64 scroll accumulators but converts them to modern world position with the opposite sign. Ground player displacement is then added intuitively on top of the landed world position.

## Ground collision screen-grid mapping

The outdoor ground controller does not use an abstract neighboring-world-tile lookup. Routine `$E280` samples the active C64 screen buffer at fixed cells.

Correct zero-page pointer interpretation:
- `$8B = $7B` is the low byte;
- `$8C = $79` (or `$7D` when `$0701 != 0`) is the high byte;
- base pointer = `$797B` or `$7D7B`.

Relative to `$7800/$7C00`, the sampled cells are:
- UP (19,9)
- LEFT (18,10)
- RIGHT (20,10)
- DOWN (19,11)

The player collision centre is therefore (19,10).

Because both flight and ground use the same `$0703-$0708` scroll hierarchy, the modern expanded-world bridge combines the saved landing scroll with ground inverse-scroll pixels before converting to tile coordinates. For signed aggregate scroll `d`, expanded-world tile-origin shift is `-floor(d/8)`.

This preserves C64 collision changes at the original character-boundary frames, including negative fine-scroll wrap.
