# Parallax C64 Flight Graphics

This document records the verified graphics path used by the flight module and how it maps into the Godot remake.

## VIC layout

The flight display uses the VIC-II character system in bank `$4000-$7FFF`.

Verified components:
- character set base: `$4000`
- alternating screen buffers: `$7800` and `$7C00`
- world screen width: 40 character columns
- character glyph size: 8×8 pixels
- multicolour character mode is enabled through `$D016`

The scroll renderer writes expanded world tile codes directly into the active screen buffer. A world tile code is therefore also a character-code index into the flight charset.

## Character colour RAM

Flight initialisation at `$13DB-$13F3` fills all four pages of colour RAM `$D800-$DBFF` with:

- `$09`

In multicolour character mode:
- bit 3 selects multicolour character rendering
- low colour bits select individual character colour 1

Therefore the fourth colour of every normal flight-world glyph is white.

## Shared multicolour registers

The raster IRQ around `$0A80-$0AB5` explicitly sets:
- `$D022 = $0B` — shared multicolour 1, dark grey
- `$D023` — shared multicolour 2, selected by vertical world band

At `$0AAC`, the code loads `$164E,X` and writes it directly to `$D023`.

Verified world-band values beginning at `$164E`:
- band 0: `$0E` — light blue
- band 1: `$05` — green
- band 2: `$06` — blue
- band 3: `$04` — purple
- band 4: `$03` — cyan
- band 5: `$20` — VIC low nibble 0, black

The band index is derived from macro-map Y in `$162C-$164D`, subtracting 18 macro rows per band.

The IRQ also uses a separate `$D023 = $0C` value during the lower/status raster region; that is not a world-surface palette value.

## Multicolour pixel interpretation

Each charset byte represents four two-bit multicolour pixels, each doubled horizontally:

- `00` -> background colour
- `01` -> `$D022`
- `10` -> `$D023`
- `11` -> individual colour RAM value

The Godot atlas generator reproduces this mapping from the original bytes at `$4000`.

## Recovered glyph facts

The corrected expanded world uses:
- 202 distinct character codes
- 146 distinct glyph bitmaps

The previous 218/155 counts included title-overlay bytes that had been misread as the first block of the master map before the `$CFA3` runtime swap was understood.

Several character codes deliberately share identical artwork while retaining separate gameplay semantics.

Verified all-zero / visually blank glyph codes used by the world include:
`0D 0E 0F 10 20 44 5D 80-89 8B-9C FF`

Important examples:
- `$2A = AA AA AA AA AA AA AA AA` — solid shared world-band colour
- `$23 = FF FF FF FF FF FF FF FF` — solid individual colour
- `$0D-$10` — visually blank and rejected by the landing-footprint test

The latter confirms that the landing rejection class is void/non-surface rather than a raised wall class.

## Original viewport and craft offset

The initial scroll state is not the final player position.

After the 20-frame startup scroll:
- viewport origin: world tile **(10, 30)**
- player 3×3 footprint top-left: **(28, 38)**
- approximate player centre: **(29, 39)**

The collision routine derives this from fixed screen position:
- footprint screen column 18
- footprint screen row 8

One expanded character tile equals **8 original scroll units**.

## Godot rendering

Generated local atlases:
`Godot/generated/tiles_zone_0.png` through `tiles_zone_5.png`

These are deliberately ignored by Git because they are derived original game artwork. `generate_tile_atlases.py` is versioned so the assets can be regenerated from an authorised local source image.

The Godot renderer:
- creates literal 8×8 glyph textures in memory from the generated atlas images
- uses nearest-neighbour filtering
- uses unshaded top materials to preserve C64 palette values
- leaves verified blank glyphs as black void
- adds only shallow 3D relief for collision classes whose special role is established in code
- streams a moving tile window over the full recovered 480×480 world

Debug overlays are optional:
- F1 — diagnostic HUD
- F2 — 3×3 landing footprint

The reference graphics remain pixel-derived from the C64 data; 3D extrusion is a remake presentation layer, not inferred original geometry.
