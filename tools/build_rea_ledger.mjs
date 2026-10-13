import { pathToFileURL } from "node:url";

const home = process.env.HOME;
const reaRoot = process.env.REA_ROOT ?? `${home}/.local/lib/node_modules/rea-agents/dist`;
const { createEvidence } = await import(pathToFileURL(`${reaRoot}/domain/evidence.js`).href);
const { createEvidenceBundle } = await import(pathToFileURL(`${reaRoot}/domain/evidenceBundle.js`).href);

const provider = { id: "parallax-review", name: "Parallax reconstruction review", version: "1" };

const findings = [
  {
    id: "flight.shields.behavior",
    title: "Determine whether the original $CF26 shield flag has any gameplay effect",
    family: "flight-system",
    location: "C64 $CF26/$CF27 -> Godot shield status",
    finding: "F7 toggles $CF26 and queues status event 6/7. Full direct-xref and relevant indexed-state-table scans found no resident flight damage/collision consumer of $CF26; gameplay effect remains unproven.",
    sources: ["FLIGHT_STATE.md", "Godot/scripts/main.gd", "trace_shields.py", "trace_shield_block.py", "trace_shield_indexed.py", "inspect_shield_tables.py"],
    next: ["Test for indirect/self-modifying or overlay-specific reads of the shield state.", "Capture a reproducible original damage scenario with shields OFF and ON before implementing any protection effect."]
  },
  {
    id: "computer.datacard.return",
    title: "Reconstruct RETURN/datacard/password computer behavior",
    family: "computer-ui",
    location: "C64 RETURN event -> Godot datacard/password computer",
    finding: "RETURN is recognized in the C64 keyboard path, but the Godot prototype explicitly reports the computer as not wired yet.",
    sources: ["FLIGHT_STATE.md", "Godot/scripts/main.gd"],
    next: ["Trace the RETURN event handler, datacard/password data structures, screen transitions and exit path.", "Create deterministic fixtures for at least one datacard/password interaction."]
  },
  {
    id: "terrain.collision.taxonomy",
    title: "Assign exact semantics to all special flight collision tile classes",
    family: "terrain-collision",
    location: "$0C91+ collision classifier and world tile codes",
    finding: "Structural classes $31-$3C, $48, $58 and altitude-dependent ranges around $93/$94 are verified, but exact player-facing meanings remain open.",
    sources: ["FLIGHT_STATE.md", "WORLD_FORMAT.md", "TILE_GRAPHICS.md"],
    next: ["Correlate classifier return classes with world locations and visible glyphs.", "Trace each class into collision masks and gameplay responses."]
  },
  {
    id: "transition.flight-ground",
    title: "Resolve the remaining special $E9E5==6 flight-ground return case",
    family: "mode-transition",
    location: "$10FB/$F4 -> $E000 -> $E60D supply; $E720 STAY ABOARD; EXIT SHIP -> outdoor $EB5B return",
    finding: "The normal transition is reconstructed and implemented through the recovered SHIP SUPPLY state. $E720 is now verified as STAY ABOARD; EXIT SHIP is oxygen-gated and enters outdoor ground mode; $EB5B performs the later near-craft return. Remaining transition uncertainty is the $E9E5==6 special case that widens the negative X return bound.",
    sources: ["FLIGHT_STATE.md", "TRANSITION_STATE.md", "SUPPLY_STATE.md", "Godot/scripts/flight_model.gd", "Godot/scripts/supply_model.gd", "Godot/tests/test_flight_model.gd", "Godot/tests/test_supply_model.gd", "trace_supply_state.py", "trace_ground_transition.py", "trace_ground_return.py"],
    next: ["Determine the player-facing meaning and trigger of the $E9E5==6 special return range.", "Capture one controlled original VICE landing -> supply -> exit -> return round trip."]
  },
  {
    id: "ground.fine-scroll-collision",
    title: "Resolve special $C1-$C3 ground/interior submode and validate reconstructed collision timing",
    family: "ground-control",
    location: "$E280/$E2FC exact screen sampler; $C1-$C3 -> $E444",
    finding: "The $E280 zero-page pointer is now correctly decoded as $797B/$7D7B, giving exact samples UP(19,9), LEFT(18,10), RIGHT(20,10), DOWN(19,11). $C1FD plus $C00E/$C03F and $C070/$C091 establish the signed fine-scroll/tile/macro normalization, and Godot now combines landing and inverse ground scroll before sampling the expanded map. Remaining uncertainty is controlled runtime parity and the semantic identities/exit behavior of the $C1/$C2/$C3 -> $E444 submode.",
    sources: ["GROUND_STATE.md", "WORLD_FORMAT.md", "ground_state_map.json", "Godot/scripts/ground_model.gd", "Godot/scripts/main.gd", "Godot/tests/test_ground_model.gd", "trace_ground_collision_alignment.py", "trace_ground_controls.py", "trace_ground_special.py", "trace_ground_submode.py"],
    next: ["Capture one reproducible VICE outdoor movement case across a character boundary and compare sampled codes/frame timing.", "Identify the semantic roles of $C1/$C2/$C3 and the exit condition of the $E444 secondary ground/interior submode."]
  },
  {
    id: "rendering.ship-shadow-ownership",
    title: "Resolve exact sprite ownership and altitude projection semantics",
    family: "rendering-projection",
    location: "$0748/$0749, $074A/$074B, $1094",
    finding: "The coordinate-pair projection relationship is strongly supported, but which pair owns ship, shadow or related sprites is not yet verified.",
    sources: ["FLIGHT_STATE.md", "TILE_GRAPHICS.md"],
    next: ["Trace VIC sprite pointer and coordinate writes back to the projection pairs.", "Verify projection at multiple flight heights."]
  }
];

const evidence = findings.map((f) => createEvidence(undefined, provider, {
  predicateType: "parallax.reconstruction-review",
  operation: "review_reconstruction_gap",
  parameters: { obligation_id: f.id },
  result: {
    obligation_id: f.id,
    finding: f.finding,
    source_paths: f.sources,
    required_next_evidence: f.next
  },
  confidence: "derived",
  authority: "analyst-inference",
  limitations: [
    "REA native providers do not support the original C64 6502 D64/PRG target on this host.",
    "Finding is grounded in the project's static py65/VICE reverse-engineering record, not native REA decompilation."
  ]
}));

const reviewed_obligations = findings.map((f, i) => ({
  obligation_id: f.id,
  obligation_version: 1,
  title: f.title,
  application_layer: "application",
  family: f.family,
  target: {
    artifact_sha256: null,
    application_node_id: null,
    semantic_node_id: null,
    location: f.location
  },
  required: true,
  required_case_kinds: ["positive", "negative"],
  required_original_authority: "static",
  required_fixture_authority: "unit",
  required_verifier_authority: "unit",
  requires_parser_type: false,
  dependency_obligation_ids: [],
  residual_unknown_ids: [],
  unavailable_authority: ["rea-native-6502"],
  required_next_evidence: f.next,
  disposition: "active",
  review_evidence_ids: [evidence[i].evidence_id]
}));

const request = {
  evidence_bundle: createEvidenceBundle(evidence),
  reviewed_obligations,
  manifest: { bindings: [], contradictions: [] }
};

process.stdout.write(JSON.stringify(request, null, 2));
