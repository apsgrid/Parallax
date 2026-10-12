# RE tooling audit — 2026-10-12

## Installed and exercised

- **Code Spelunker (`cs`) 3.2.0** — installed at `C:\Users\Andrew\.local\bin\cs.exe`; used for state/address searches, stale-assumption detection, open-gap discovery, and shield follow-up.
- **Funes 1.8.0** — installed in WSL Ubuntu at `~/.local/bin/funes`; project-isolated memory indexed 38 chunks from the authoritative Parallax RE documents and milestone history.
- **TruffleHog 3.99.2** — installed in WSL for Funes' mandatory secret scanning.
- **REA 6.4.0 (Windows)** — installed globally with Node 22.20.0.
- **REA 6.4.0 (WSL)** — installed against a checksum-verified native Linux Node 22.20.0 runtime for source-import/evidence workflows that require Linux no-follow filesystem semantics.

## REA target boundary

Direct tests against the original artifacts established the current boundary:
- D64: unsupported binary format;
- C64 PRG: unsupported binary format;
- raw playable image: Windows binary-layout provider is not a 6502/raw provider;
- current Ghidra P0 provider path is for supported native x86/x64 targets, not the Parallax 6502 image.

Therefore REA must not be cited as the decompiler/disassembler authority for Parallax. `py65`/VICE/static data-flow remain the original-target evidence lane.

## REA historical source graph

WSL `import-reference-source` successfully created a `HistoricalSourceGraph` for the Godot reconstruction.
- root SHA-256: `ae0a5378ec881b769da32ae1ac78f4b2fd52e98f796782cdd3b317611872510c`
- authority: `historical-reference`
- includes hashed source, tests, project files, local generated world/graphics assets and documentation at audit time.

Generated graph JSON remains local under `rea_audit/`.

## REA reconstruction obligation ledger

Authenticated review Evidence was generated with REA's own `createEvidence()` and `createEvidenceBundle()` implementation.
- ledger ID: `rol_8cbb55ffe466198ab1badb9698bf3539bdb0ed8e17bbdf0aa80e7a3ada66296d`
- closure digest: `882f390a92401b9ce1c15d39f05231b8e1086a489738d75a242d1845b578fe7b`
- status: `unknown` (intentionally conservative)
- required obligations: 5
- verified: 0
- required open: 5

Tracked obligations:
1. shield behavior beyond toggle/status presentation;
2. RETURN/datacard/password computer behavior;
3. exact collision-tile taxonomy;
4. special/alternate flight-ground paths beyond the verified normal round trip;
5. exact ship/shadow projection ownership.

## Funes validation

Current project memory source validates as 21 turns / 57 chunks / 0 rejected / 0 duplicate IDs before indexing.
Recall checks correctly retrieved:
- corrected Stage-5 range, byte count and SHA-256;
- post-startup viewport/player coordinates;
- landing-ready conditions.

Funes is a retrieval layer, not original-game authority.

## Second-pass finding: shields

`cs` + Funes + full static xref/index-table tracing found:
- direct `$CF26` accesses only in the F7 toggle and SHIELDS ON/OFF status display;
- the post-toggle `$1FA8` path is an event/status queue;
- no `$26` entry in the relevant generic `$CF00,X/Y` state index tables inspected;
- no identified resident flight damage/collision consumer of `$CF26`.

This is strong negative evidence, not proof that every possible indirect/self-modifying/overlay path is absent. Original Rules mode must not invent a shield protection effect until stronger evidence is found.

## Second-pass finding: flight ↔ ground transition

The normal flight/ground round trip is now reconstructed and implemented in the reference model.

Verified core sequence:
- landing FIRE sets `$F4` but does not switch mode immediately;
- next-tick flight dispatch jumps to `$E000`;
- `$E049` gates one-time ground initialization;
- `$F3` is cleared in ground mode and restored to 1 on return;
- `$EB5B` is the normal return-to-ship gate;
- normal player-to-craft return range is -7..+7 on both axes;
- successful return realigns scroll state, clears `$E049/$F4`, restores the craft coordinate, and resumes flight on the next tick.

Godot reference tests now exercise the two-stage entry, ground state, rejected +8 offset, successful near-craft return, flag restoration and scroll realignment.

Remaining open transition evidence is limited to:
- the `$E9E5 == 6` special case that widens the negative X return bound to -27;
- the alternate `$E720` exit/control path.
