# Parallax reverse-engineering tooling rule

This workflow is mandatory for substantial Parallax reverse-engineering work. The tools are complementary; do not claim one tool has validated a target outside its supported formats.

## Before a new RE pass

1. Query the project Funes memory for the subsystem being investigated. Use the project-isolated memory under `.funes` so prior corrections and dead ends are visible before new analysis.
2. Run Code Spelunker (`cs`) over the repository for addresses, symbols, stale assumptions, TODOs, and related analysis scripts before writing one-off grep/search code.
3. Check the current REA provider/capability state. Use REA evidence/reconstruction workflows where supported, but never force a C64 D64/PRG/raw 6502 image through an x86/x64 provider.

## Target-specific authority

For the original C64 program, the primary technical evidence lane remains:
- corrected playable RAM/image reconstruction;
- `py65` static disassembly and explicit xref/data-flow scripts;
- VICE remote-monitor/runtime observations when a reproducible live state is available;
- byte/table extraction tied to concrete addresses and call paths.

REA 6.4.0 currently does not natively analyze the Parallax 6502 D64/PRG. Its role here is source/reference hashing, authenticated review Evidence, and conservative reconstruction-obligation tracking.

## Memory and structural search

- Funes must be refreshed after authoritative RE documents change materially.
- The Parallax Funes store is a **current authoritative-state index**, not a revision archive. Refreshes rebuild the project memory from the current generated transcript so superseded claims cannot compete with corrected findings.
- Funes recall is context retrieval, not binary proof; claims still require address/data-flow/runtime evidence.
- `cs` is the default repository-wide structural search tool. Prefer it over ad-hoc text scans when searching source/docs/scripts.
- Record stale assumptions discovered by `cs` as code/doc fixes, not merely audit notes.

## Reconstruction ledger

Open behavior that affects remake fidelity should be represented in the REA reconstruction-obligation ledger.
- Never create fake Evidence IDs or mark an obligation verified without comparable original authority and a verifier.
- Missing 6502-native REA authority must remain explicit.
- When a gap is solved, add the original evidence, implementation owner/fixture/verifier, then regenerate the ledger.

## Milestone closeout

After a substantial milestone:
1. update authoritative documents (`RE_NOTES.md`, `FLIGHT_STATE.md`, `WORLD_FORMAT.md`, `TILE_GRAPHICS.md` as applicable);
2. run focused `cs` stale-assumption/open-gap searches;
3. refresh Funes memory and verify recall of at least one newly changed fact;
4. regenerate the REA obligation ledger;
5. run Godot/reference tests;
6. inspect Git status and keep copyrighted/generated game data out of public commits.

## Clean-room/reference projects

Nanolathe is an architectural clean-room reimplementation reference, not a Parallax binary analyzer or memory store. Use it for patterns such as subsystem separation, original-behavior oracles, data-driven compatibility layers, and test organization when useful; do not treat its code as evidence about Parallax.
