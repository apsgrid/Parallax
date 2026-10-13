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
    id: "entity.kard-acquisition",
    title: "Reconstruct the scientist/NPC stun-combat path that naturally offers generated KARDs",
    family: "entity-combat",
    location: "$E9E5 entity types 4/5/6 -> $EECD stun transition -> $F026/$F061 KARD offer",
    finding: "The KARD/economy/computer state is now reconstructed and implemented, including authentic startup KARD 0-285, generated-KARD format/replacement, COMPUTABANK, COMPUTASHOP, password-letter discovery, scientist-gated regional passwords and RETURN status. The original KARD generator at $F061 is modeled, but the world/NPC stun-combat interaction that naturally reaches it is not yet connected to the modern playable scene.",
    sources: ["COMPUTER_STATE.md", "Godot/scripts/computer_model.gd", "Godot/tests/test_computer_model.gd", "Godot/tests/test_computer_integration.gd", "verify_computer_state.py", "trace_kard_state.py"],
    next: ["Trace entity types 4/5/6, projectile/stun collision and interaction timing through $EECD/$F026.", "Implement the NPC scientist encounter so generated KARDs are acquired naturally.", "Capture one original VICE stun -> KARD offer case."]
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
    id: "progression.endgame",
    title: "Reconstruct progression-5 and the original endgame/ending condition",
    family: "progression",
    location: "$030E progression index; password success at $F202; progression-5 checks around $089C",
    finding: "The five regional password gates are reconstructed and implemented: STACK, JEWEL, PARCH, SALON and GLOBE each advance $030E. The scientist-present $E9E5==6 return state is now identified and its $E760 outcome implemented. What happens after progression reaches 5, including the coordinate-gated logic around $089C and the player-facing ending, remains outside the completed computer milestone.",
    sources: ["COMPUTER_STATE.md", "TRANSITION_STATE.md", "Godot/scripts/computer_model.gd", "Godot/tests/test_computer_integration.gd", "trace_computer_state.py", "trace_kard_state.py"],
    next: ["Trace all reads of $030E when it equals 5, especially the $089C world-coordinate gate.", "Identify the final objective, success/ending transition and reset/credits consequences.", "Capture the original final-stage behavior in VICE if reproducible."]
  },
  {
    id: "ground.fine-scroll-collision",
    title: "Validate reconstructed outdoor/interior movement timing against the original runtime",
    family: "ground-control",
    location: "$E280/$E2FC outdoor sampler; $C1-$C3 -> $E444 local-area mode -> $E4DA exit",
    finding: "Outdoor collision, the repeated C1/C2/C3 entrance motif, E444 room entry, 40x20 room generation, E5E6 local coordinate transform, EBEB terminal dispatch, and E4DA left-space exit are reconstructed and implemented. The automated vertical slice now enters a structure, interacts with COMPUTABANK, exits, returns to the craft and resumes flight. Remaining evidence gap is runtime parity rather than structural semantics.",
    sources: ["GROUND_STATE.md", "INTERIOR_STATE.md", "ground_state_map.json", "Godot/scripts/ground_model.gd", "Godot/scripts/interior_model.gd", "Godot/scripts/flight_model.gd", "Godot/tests/test_ground_model.gd", "Godot/tests/test_interior_model.gd", "Godot/tests/test_vertical_slice.gd", "trace_ground_collision_alignment.py", "verify_interior_mode.py"],
    next: ["Capture one reproducible VICE outdoor character-boundary case and one complete interior entry/terminal/exit case.", "Compare original frame timing and sampled character codes against the reference models."]
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
