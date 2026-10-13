# Parallax Remake — Godot vertical slice

Executable modern prototype reconstructed from the 1986 C64 game rules and world data.

Engine:
- Godot 4.7.2 stable
- GDScript
- 50 Hz deterministic physics tick

Current prototype:
- recovered 16-step C64 heading tables
- recovered signed fixed-point X/Y velocity convergence
- authentic post-startup state: heading 4, flight height 21
- climb/dive flight-height state
- landing gear and landing-regime braking
- 3×3 original landing/collision footprint
- laser bolts
- recovered two-stage flight → ground transition ($F4 request, next-tick $E000 entry)
- recovered normal ground → flight return gate and state restoration
- deterministic land → SHIP SUPPLY → EXIT SHIP → walk → return-to-ship round trip
- recovered SHIP SUPPLY inventory transfer, scientist/drug behavior, Standard Kit, STAY ABOARD and oxygen-gated EXIT SHIP
- recovered on-foot joystick priority, one-pixel movement and inverse scrolling
- exact 17-code on-foot passable-character whitelist
- recovered on-foot walk animation using the original C64 sprite frames $50-$5B
- recovered $E280 ground collision screen cells and C64 fine-scroll/tile/macro alignment mapped exactly onto the expanded world
- recovered $C1/$C2/$C3 structure entrances and $E444 local-area/interior state
- recovered 40×20 interior room generation with deterministic COMPUTABANK/COMPUTASHOP/KARD terminal placement
- recovered interior entry coordinates, local movement/collision, terminal dispatch and left-space exit
- recovered interior $80-$BF character swap rendered from $5A30-$5C2F
- authentic startup computer state: 20 credits, one KARD `0-285`, PASS `-----`
- recovered two-slot KARD generation/replacement and four-digit authentication
- recovered COMPUTABANK balance/credit-award paths and class-dependent KARD loss rules
- recovered 20-credit COMPUTASHOP BONANZA PACK with exact inventory effects/caps
- recovered KARD password-letter discovery and all five scientist-gated regional passwords
- recovered RETURN KARD/PASS status display
- executable vertical slice: flight → land → supply → disembark → walk → interior terminal → outdoors → craft → flight
- complete recovered 480×480 world available to the renderer
- streamed world window that follows the craft
- original flight charset decoded from $4000
- original multicolour world palette bands
- original tile artwork rendered on unshaded nearest-neighbour surfaces
- shallow 3D relief only for verified collision classes
- optional diagnostic HUD and landing-footprint overlay

Verified initial geometry:
- post-startup viewport origin: tile (10, 30)
- player start centre: approximately tile (29, 39)
- one expanded world tile = 8 original scroll units

Controls:
- In flight: Left/Right or A/D turn; Down/S climbs; Up/W dives
- On foot/interior: Arrows/WASD use the recovered RIGHT → LEFT → DOWN → UP priority and one-pixel movement
- Z: fire; when landing-ready and stopped, commit landing; in SHIP SUPPLY, select on release; on foot at the craft, return to flight; in terminals, insert/continue
- A/B in terminal selection: choose KARD A or B; B also buys the offered BONANZA PACK
- 0–9 in KARD authentication: enter the complete four-digit KARD number
- A–Z at a regional password gate: enter the five-letter password; Backspace edits terminal input
- Enter outside a terminal: show recovered KARD A/B and PASS status
- Space: landing gear
- F7: shield UI state
- Tab: switch between the two recovered velocity table sets
- R: reset to the recovered C64 start state
- F1: toggle diagnostic HUD
- F2: toggle 3×3 landing-footprint overlay

The deterministic reference layers live in `scripts/flight_model.gd`, `ground_model.gd`, `supply_model.gd`, `interior_model.gd`, and `computer_model.gd`. Computer/economy coverage lives in `tests/test_computer_model.gd` and `test_computer_integration.gd`; the complete gameplay-loop regression lives in `tests/test_vertical_slice.gd`.

Generated local world/graphics files are intentionally excluded from Git because they contain derived original game data. They are regenerated from the authorised local source media. Interior assets are rebuilt with `extract_interior_runtime.py` and `generate_interior_tile_atlases.py`.
