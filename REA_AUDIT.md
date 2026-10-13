# RE tooling audit — 2026-10-12

## Installed and exercised

- **Code Spelunker (`cs`) 3.2.0** — installed at `C:\Users\Andrew\.local\bin\cs.exe`; used for state/address searches, stale-assumption detection, open-gap discovery, and shield follow-up.
- **Funes 1.8.0** — installed in WSL Ubuntu at `~/.local/bin/funes`; project-isolated memory currently indexes the authoritative Parallax RE documents and milestone history.
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
- root SHA-256: `84a2d51eac854d069e2f8e315fdbfed74864f32521eece6d40cd831db8fcb9ca`
- authority: `historical-reference`
- includes hashed source, tests, project files, local generated world/graphics assets and documentation at audit time.

Generated graph JSON remains local under `rea_audit/`.

## REA reconstruction obligation ledger

Authenticated review Evidence was generated with REA's own `createEvidence()` and `createEvidenceBundle()` implementation.
- ledger ID: `rol_58f018a101ec393d1e2095f77f72ed7c610150c5516b8a8296f810528cbac14a`
- closure digest: `b4c34910bbd105b20764ce9e153e5e2e04d39d9daec89fc6a2988fb340a42052`
- status: `unknown` (intentionally conservative)
- required obligations: 6
- verified: 0
- required open: 6

Tracked obligations:
1. shield behavior beyond toggle/status presentation;
2. scientist/NPC stun-combat and natural generated-KARD acquisition;
3. exact collision-tile taxonomy;
4. progression-5/endgame behavior after the five regional passwords;
5. controlled runtime parity for reconstructed outdoor/interior movement and terminal timing;
6. exact ship/shadow projection ownership.

## Funes validation

Current project memory source validates as 29 turns / 111 chunks / 0 rejected / 0 duplicate IDs before indexing.
Recall checks correctly retrieved:
- corrected Stage-5 range, byte count and SHA-256;
- post-startup viewport/player coordinates and landing-ready conditions;
- SHIP SUPPLY → STAY ABOARD / oxygen-gated EXIT SHIP;
- authentic starting KARD `0-285` and 20 credits;
- COMPUTABANK / COMPUTASHOP behavior and BONANZA PACK effects;
- STACK / JEWEL / PARCH / SALON / GLOBE progression;
- scientist-present `$E9E5 == 6` and solved/unsolved return behavior.

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

The transition audit has since resolved the supply/disembark intermediate state:
- `$E60D` presents SHIP SUPPLY after landing;
- `$E720` is the verified STAY ABOARD path back to flight;
- EXIT SHIP requires carried oxygen `$CF30 != 0` before outdoor ground control begins.

The `$E9E5 == 6` special case is now semantically resolved as the scientist-present local state. Its carried-scientist trigger, password-gate use and `$E760` return outcome are verified; only exact runtime/spatial parity of the widened -27 X allowance remains open. See `TRANSITION_STATE.md`, `SUPPLY_STATE.md` and `COMPUTER_STATE.md`.

## Second-pass finding: on-foot controls

The outdoor ground-control loop is now reconstructed and implemented as a separate deterministic `GroundModel`.

Verified rules include:
- CIA1 joystick normalization with the same logical direction bits as flight;
- strict RIGHT → LEFT → DOWN → UP direction priority;
- blocked-direction fall-through;
- one-pixel accepted movement;
- inverse scroll/craft deltas;
- exact 17-character passable whitelist;
- four-move walk-animation cadence and exact `$50-$5B` sprite frames;
- `$074A/$074B` fixed landing anchor versus mutable `$E060/$E05F` ground-relative coordinate roles;
- `$C1-$C3` blocked RIGHT contact branches into the secondary ground submode at `$E444`.

The Godot scene now renders the recovered ground sprite frames and maps outdoor collision through the recovered C64 screen grid. The `$E280` pointer is `$797B/$7D7B`, giving exact samples UP(19,9), LEFT(18,10), RIGHT(20,10), DOWN(19,11). The bridge combines landing and inverse ground-scroll pixels before applying the recovered `$C1FD -> $C00E/$C03F -> $C070/$C091` normalization chain. Static alignment and unit-boundary tests pass; a controlled VICE parity capture remains desirable as runtime evidence.

## Second-pass finding: interiors and first complete vertical slice

The `$C1/$C2/$C3 -> $E444` branch is no longer an open semantic submode.

Verified structure now includes:
- `$C1/$C2/$C3` as upper/middle/lower slices of repeated world entrance motifs;
- `$E444` local-area entry and preserved outdoor fine scroll;
- fixed 40×20 room construction from the original metatile set;
- `$E803/$E821` interior charset swap/restore;
- deterministic COMPUTABANK, COMPUTASHOP and KARD/password pattern placement;
- local coordinate transform at `$E5E6`;
- entry centres (6,7) for `$C1/$C2` and (6,12) for `$C3`;
- terminal dispatch at `$EBEB` with direction-specific contact codes;
- `$E4DA` left-`$20` interior exit;
- `$EC45` terminal unwind when the held direction changes;
- progression passwords `STACK`, `JEWEL`, `PARCH`, `SALON`, `GLOBE`.

Godot now implements a deterministic `InteriorModel`, generated local room data, terminal presentation, local movement/collision and restoration to outdoor state.

The automated `test_vertical_slice.gd` now completes:

**flight -> landing -> SHIP SUPPLY -> EXIT SHIP -> outdoor walking -> structure entry -> COMPUTABANK interaction -> structure exit -> return to craft -> flight**

The first complete gameplay vertical slice is therefore implemented. The KARD/account/shop/password progression layer has since also been reconstructed and implemented; remaining work is now outside the computer state itself. Runtime parity capture and exact interior raster/palette timing remain separate fidelity tasks; the verified `$80-$BF` charset swap is reproduced by a dedicated generated interior atlas.

## Second-pass finding: KARD/economy/password computer state

The computer layer is no longer an open reconstruction obligation.

Verified and implemented findings now include:
- authentic startup state: 20 credits, flight-endurance counter 99, one KARD `0-285`, PASS `-----`;
- two-slot KARD records in `C-NNN` form;
- exact generated-KARD class table and three 0-7 digits;
- original full-inventory replacement rule that preserves a class-0 slot-A KARD;
- common four-digit KARD authentication and A/B selection;
- wrong class-0 number returns the KARD, while wrong class 1-5 destroys it;
- COMPUTABANK class-0 balance query and class 1-5 random credit award/consumption;
- COMPUTASHOP BONANZA PACK for 20 credits, including +30 flight endurance (cap 99), +20 carried oxygen (cap 49), +20 carried ammunition (cap 49), and +1 drug;
- normal KARD/password terminals consuming class 1-5 KARDs to reveal the corresponding letter of STACK/JEWEL/PARCH/SALON/GLOBE;
- current-progression-anchor selection of the special password gate;
- TAKE AWAY scientist `$CF33 > 0` creating local type `$E9E5 == 6`;
- scientist-required five-letter password entry, `$F229` success flag, `$030E` progression increment and PASS display reset;
- `$E760` equipment consolidation and solved/unsolved scientist return behavior;
- RETURN `$20C4 -> $1FD7 -> $2131` KARD/PASS status display.

Godot now implements this state in ComputerModel, integrates it through FlightModel/SupplyModel, and exposes playable A/B KARD selection, numeric authentication, shop purchase, five-letter password input and RETURN status.

Deterministic coverage now includes `test_computer_model.gd`, `test_computer_integration.gd` and the full vertical-slice test. The static verifier `verify_computer_state.py` independently checks the canonical runtime bytes.

The REA open obligation has therefore moved to the separate scientist/NPC stun-combat path that naturally reaches the recovered KARD generator at `$F061`. A second new obligation tracks progression-5/endgame behavior after all five passwords.
