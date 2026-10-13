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
    finding: "F7 toggles $CF26 and queues status event 6/7. The recovered moving-object impact path is now complete: $FFA3 queues event 2/3 and $2022 indexes only $CF01 ENGINE or $CF02 LAZERS, with no $CF26 read. Therefore shields are verified not to reduce/cancel moving-object contact damage. Full direct-xref scans still find no other resident damage consumer, but unrelated indirect/overlay/auxiliary-fire use remains an open negative-evidence question.",
    sources: ["FLIGHT_STATE.md", "FLIGHT_COMBAT_STATE.md", "flight_combat_state_map.json", "Godot/scripts/flight_combat_model.gd", "Godot/scripts/main.gd", "Godot/tests/test_flight_damage.gd", "verify_flight_damage.py", "trace_shields.py", "trace_shield_block.py", "trace_shield_indexed.py", "inspect_shield_tables.py"],
    next: ["Resolve the still-open $FACC auxiliary object-fire behavior and check that path for any indirect shield use.", "Capture a reproducible original moving-object collision with shields OFF and ON as runtime parity evidence; do not add protection unless the original demonstrates it."]
  },
  {
    id: "entity.remaining-types",
    title: "Resolve remaining local entity types 1 and 3 and their player-facing effects",
    family: "entity-combat",
    location: "$E9E7 entity-type table -> $EA02 movement -> $EECD stun-hit dispatch",
    finding: "The scientist encounter is now reconstructed and implemented end-to-end: type 4 roaming scientist -> stun hit -> type 5 stunned scientist -> $F026/$F061 generated-KARD Y/N interaction -> type 6 accompanying scientist -> widened return gate and $E760 ship reconciliation. Types 1 and 3 remain in the same spawn/movement system and are removed by a stun-projectile hit instead of entering the scientist lifecycle, but their exact identities and player-facing effects remain open.",
    sources: ["ENCOUNTER_STATE.md", "encounter_state_map.json", "Godot/scripts/encounter_model.gd", "Godot/tests/test_encounter_model.gd", "Godot/tests/test_scientist_loop.gd", "verify_scientist_encounter.py", "trace_scientist_encounter.py", "trace_scientist_semantics.py"],
    next: ["Trace type-1/type-3 sprite behavior, contact/damage paths and any attack state.", "Correlate their spawn locations and sprite pointers with original visuals.", "Capture one original VICE encounter for each remaining type."]
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
    id: "combat.moving-object-scheduler",
    title: "Validate the reconstructed moving flight-object scheduler and resolve craft-impact semantics",
    family: "flight-combat",
    location: "$F700/$F874 object loop; $F825-$F864 three-slot records; $FBFF-$FC4C laser-hit endpoint",
    finding: "The resident single-laser, destructible +15 path, and $F874 three-slot moving-object scheduler are implemented end-to-end. Craft-impact semantics are now also recovered: $FFA3 queues event 2/3; $2022 maps those to $CF01 ENGINE / $CF02 LAZERS, adds 2..9 from $C000,Y, and $2058 decays $CF00-$CF02 every 90 status ticks. ENGINE >=40 suppresses motion/landing; LAZERS >=7 blocks firing. $CF26 is absent from this damage path. Remaining uncertainty is runtime parity, exact destruction presentation, $FACC auxiliary fire, and the indirect ENGINE>=60 failure path.",
    sources: ["FLIGHT_COMBAT_STATE.md", "flight_combat_state_map.json", "Godot/scripts/flight_combat_model.gd", "Godot/scripts/flight_model.gd", "Godot/scripts/main.gd", "Godot/tests/test_flight_combat_model.gd", "Godot/tests/test_flight_combat_integration.gd", "Godot/tests/test_flight_object_scheduler.gd", "Godot/tests/test_flight_damage.gd", "verify_flight_combat.py", "verify_flight_objects.py", "verify_flight_damage.py", "generate_flight_object_sprites.py", "trace_flight_object_loop.py", "trace_flight_objects.py"],
    next: ["Capture controlled VICE parity for one object spawn/movement sequence, one moving-object laser hit, and one craft-impact damage event.", "Verify the exact original destruction presentation rather than treating the modern fade/scale as original behavior.", "Resolve $FACC auxiliary object fire and the indirect $CF01>=0x3C catastrophic ENGINE-failure branch."]
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
