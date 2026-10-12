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
- ledger ID: `rol_f1b1874e398a27c9c33fc386048d3025ce6927cacd2c884bc05749df11326ca1`
- closure digest: `9de87aaab9b56a7ccba450db866ec7d0c3a431c1de8478f2bb906814e8da863a`
- status: `unknown` (intentionally conservative)
- required obligations: 5
- verified: 0
- required open: 5

Tracked obligations:
1. shield behavior beyond toggle/status presentation;
2. RETURN/datacard/password computer behavior;
3. exact collision-tile taxonomy;
4. exact flight-to-ground transition and reverse launch path;
5. exact ship/shadow projection ownership.

## Funes validation

Current project memory source validates as 19 turns / 49 chunks / 0 rejected / 0 duplicate IDs before indexing.
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
