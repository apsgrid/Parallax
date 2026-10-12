# Parallax Remake — Godot vertical slice

This is the first executable modern prototype built from the recovered C64 flight rules.

Engine:
- Godot 4.7.2 stable
- GDScript
- 50 Hz physics tick to match PAL-era update cadence

Current prototype:
- 3D orthographic greybox arena
- recovered 16-step heading tables
- recovered signed fixed-point X/Y velocity convergence
- climb/dive flight-height state
- landing gear state
- 3x3 landing-footprint display
- landing-regime braking
- flight-to-ground transition trigger
- laser bolts
- debug HUD exposing original state variables

Controls:
- Left/Right or A/D: turn
- Down/S: climb
- Up/W: dive
- Z: fire; when landing-ready and stopped, commit landing
- Space: landing gear
- F7: shield UI state
- Tab: switch between the two recovered velocity table sets
- R: reset

The reference flight model lives in scripts/flight_model.gd and is intentionally independent of rendering. Tests live in tests/test_flight_model.gd.
