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
- root SHA-256: `c732d499338b0f2e282a837e819a4f9d59b1dc5872eb27a9f3a9fc395f997056`
- authority: `historical-reference`
- includes hashed source, tests, project files, local generated world/graphics assets and documentation at audit time.

Generated graph JSON remains local under `rea_audit/`.

## REA reconstruction obligation ledger

Authenticated review Evidence was generated with REA's own `createEvidence()` and `createEvidenceBundle()` implementation.
- ledger ID: `rol_0b46938d3dcdf49018e29e3350b3207fc6053b88def9f484457ea084b76e04e1`
- closure digest: `c8489466201f8103f3737cf58cc9f53f3ff7a8540e9c2d606af3ec9842cb9f77`
- status: `unknown` (intentionally conservative)
- required obligations: 6
- verified: 0
- required open: 6

Tracked obligations:
1. shield behavior beyond toggle/status presentation;
2. remaining local entity types 1 and 3 and their player-facing effects;
3. exact collision-tile taxonomy;
4. natural flight projectile/enemy score production feeding the recovered ending qualification;
5. controlled runtime parity for reconstructed outdoor/interior/scientist/endgame timing;
6. exact ship/shadow projection ownership.

## Funes validation

Current project memory source validates as 35 turns / 150 chunks / 0 rejected / 0 duplicate IDs before indexing.
Recall checks correctly retrieved:
- corrected Stage-5 range, byte count and SHA-256;
- post-startup viewport/player coordinates and landing-ready conditions;
- SHIP SUPPLY → STAY ABOARD / oxygen-gated EXIT SHIP;
- authentic starting KARD `0-285` and 20 credits;
- COMPUTABANK / COMPUTASHOP behavior and BONANZA PACK effects;
- STACK / JEWEL / PARCH / SALON / GLOBE progression;
- scientist-present `$E9E5 == 6` and solved/unsolved return behavior;
- type 4 roaming scientist → type 5 stunned scientist → type 6 accompanying scientist;
- stun-gun one-ammunition cost, four-pixel projectile and -6..+5 entity hit window;
- generated-KARD Y/N interaction and the type-6 widened return gate;
- corrected runtime master-map overlay swap and 18 `$77` transporter destinations;
- unique winning marker `(90,59)` -> final viewport macro `(86,57)` after `GLOBE`;
- `$030D=$7B` ending-overlay handoff, strict `score > 000010` qualification and `CHRIX` best-score record;
- recovered `WELL DONE CAP'N` / `MEGA HERO` ending and five-character UP/DOWN/FIRE name entry.

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

The scientist/NPC stun-combat path that naturally reaches `$F061` has since been reconstructed and implemented. The remaining entity obligation is limited to local entity types 1 and 3 and their exact player-facing effects. The progression-5 transporter and original ending have also been reconstructed and implemented; the separate remaining combat obligation is natural score production from verified projectile/enemy hits.

## Second-pass finding: scientist stun and natural KARD acquisition

The scientist/KARD acquisition loop is no longer an open reconstruction obligation.

Verified and implemented findings now include:
- current-region gating at `$E833` for both local spawning and stun-gun fire;
- random local spawn search from the shared `$E977` byte stream;
- effective entity-type selector table `1,3,4,4,4,4,4,1`;
- type 4 as roaming scientist, type 5 as stunned scientist, and type 6 as accompanying scientist;
- one-pixel cardinal entity movement with blocked-direction retries and the original wander counter;
- carried stun-gun + ammunition requirement, one-ammunition shot cost, and four-pixel projectile vectors;
- exact projectile/entity hit box of -6..+5 on both axes;
- type 4/type 6 stun-hit transition to type 5 and removal of other hittable types;
- eight two-frame projectile-impact states, for a 16-frame impact lifetime;
- exact type-5 approach window X -9..+8 / Y -6..+5;
- one generated-KARD offer per outing at `$F061`, with generation before the Y/N decision;
- original two-slot KARD insertion on Y and discard on N;
- type-5 -> type-6 promotion after either answer when no scientist is already aboard;
- type-6 +16 X follower positioning and the widened -27 X return-to-craft bound;
- `$E760` restoration of an unsolved captured scientist to the ship.

`EncounterModel`, the recovered encounter sprites, the Y/N KARD prompt, and the full natural scientist loop are integrated into Godot. The end-to-end regression now proves roaming scientist -> stun -> KARD offer -> KARD acquisition -> type-6 escort -> local exit -> widened return gate -> scientist aboard with KARD retained.

Static authority is independently checked by `verify_scientist_encounter.py`. Deterministic coverage is in `test_encounter_model.gd` and `test_scientist_loop.gd`.

The REA entity obligation has moved to the genuinely unresolved local entity types 1 and 3. Their shared movement/spawn mechanics are known, and a stun hit removes them rather than entering the scientist lifecycle, but their exact identities, attack/damage behavior and player-facing effects remain open.

## Second-pass finding: progression-5 transporter and original ending

The progression-5/endgame path is no longer an open reconstruction obligation.

Verified and implemented findings now include:
- successful `GLOBE` advances progression `$030E` to exactly 5;
- flight special tile `$70` dispatches to the transporter at `$1714` when the recovered flight-height gate is met;
- transporter re-entry cooldown is exactly 50 frames via `$191D = $32`;
- the runtime 96x96 master map is reconstructed correctly across the `$8000-$8FFF` / RAM-under-I/O swap;
- transporter destinations are master-map metatile `$77`, with 18 markers in the corrected runtime map;
- the persistent low-nibble selector at `$17C8/$17C9` chooses row-major destinations within the current vertical band;
- marker relocation is `(mx-4,my+2)` before twenty +8 scroll frames, yielding final viewport macro `(mx-4,my-2)`;
- `$089C` requires progression exactly 5, macro X >= 80 and macro Y < 80;
- the unique winning marker is `(90,59)`, producing final viewport macro `(86,57)`;
- the final effect waits for FIRE, writes `$030D=$7B`, and restores the title/ending overlay through the `$CFxx` swap trampoline;
- the restored overlay recognizes `$030D=$7B` and enters the dedicated ending route;
- current score is six ASCII decimal digits and must strictly beat the mutable best-score record;
- the built-in best score is `000010` under the name `CHRIX`;
- the original congratulatory text includes `WELL DONE CAP'N` and the `MEGA HERO` line;
- the original prompt is spelled `ENTRE ... -----`;
- five-character name entry uses UP/DOWN to change a six-bit screen code and FIRE to accept after release arming;
- accepted score/name replace the best-score record before the original title return path.

`EndgameModel` now implements the transporter selector/cooldown, exact final coordinate gate, score qualification, ending state, five-character entry, best-score update and title-return state. `FlightModel` integrates transporter relocation into recovered scroll coordinates; `main.gd` detects tile `$70` in the original flight cross sample and presents the ending UI.

The corrected world extractor now accounts for the gameplay overlay swap, eliminating the former false interpretation of `$8000-$8FFF` as master-map bytes in the pre-swap snapshot.

Static authority is checked independently by `verify_endgame_state.py` and `verify_world_overlay_swap.py`. Deterministic coverage is in `test_endgame_model.gd` and `test_endgame_integration.gd`.

The remaining score-related obligation is deliberately narrower: natural score production from verified flight projectile/destructible and moving-enemy/object hits. The endgame score gate itself is complete, and points are not invented for actions whose scoring semantics are not yet reconstructed.
