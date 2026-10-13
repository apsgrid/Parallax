extends SceneTree

const CombatModel = preload("res://scripts/flight_combat_model.gd")
const FlightModel = preload("res://scripts/flight_model.gd")

var failures := 0


func _init() -> void:
    _test_projectile_motion_and_gate()
    _test_terrain_classifier_and_score()
    _test_dynamic_collision_band()
    _test_direct_master_writeback()
    _test_moving_object_hit_rule()
    _test_score_integration()
    if failures == 0:
        print("PARALLAX FLIGHT COMBAT TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX FLIGHT COMBAT TESTS: %d failure(s)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _test_projectile_motion_and_gate() -> void:
    var c := CombatModel.new()
    c.reset()
    _check(c.fire(0, 0x15), "first FIRE creates recovered single projectile")
    _check(not c.fire(0, 0x15), "active projectile blocks a second laser")
    _check(c.projectile_x == 0x54 and c.projectile_y == 0x75, "laser starts at recovered $54,$75")
    _check(c.projectile_state == 0x1E and c.projectile_height == 0x15, "laser stores recovered state and firing height")

    var events: Dictionary = c.advance()
    _check(events["moved"] and events["needs_collision"], "live projectile advances before collision test")
    _check(c.projectile_x == 0x54 and c.projectile_y == 0x6F, "heading 0 subtracts exact $0E20/$0DF0 vector")


func _test_terrain_classifier_and_score() -> void:
    var c := CombatModel.new()
    var samples := [0x20,0x20,0x20,0x20,0x31,0x20,0x20,0x20,0x20]
    var result: Dictionary = c.classify_terrain(samples, 0x15)
    _check(result["collision_class"] == 1 and result["sample_index"] == 4, "centre $31-$3C sample wins recovered collision priority")

    samples = [0x20,0x48,0x20,0x20,0x20,0x20,0x20,0x20,0x20]
    c.reset()
    c.fire(4, 0x15)
    var hit: Dictionary = c.resolve_terrain(samples)
    _check(hit["collision"] and hit["collision_class"] == 2, "$48 produces recovered destructible collision class 2")
    _check(hit["destructible"] and hit["score_award"] == 15, "destructible terrain queues recovered +15 score")
    _check(c.projectile_state == 0xA1 and c.projectile_exploding(), "destructible hit enters recovered $A1 explosion state")

    samples = [0x20,0x20,0x20,0x20,0x3D,0x20,0x20,0x20,0x20]
    result = c.classify_terrain(samples, 0x13)
    _check(result["collision_class"] == 0, "$3D is not collision class 3 below height $14")
    result = c.classify_terrain(samples, 0x14)
    _check(result["collision_class"] == 3, "$3D becomes destructible collision class 3 at height $14")


func _test_dynamic_collision_band() -> void:
    var c := CombatModel.new()
    var samples := [0x20,0x20,0x20,0x20,0x94,0x20,0x20,0x20,0x20]
    _check(c.classify_terrain(samples, 0x15)["collision_class"] == 0, "startup $94/$93 dynamic interval is empty")
    c.set_dynamic_band_counter(8)
    _check(c.dynamic_upper_threshold == 0x95 and c.dynamic_lower_threshold == 0x92, "$23C9/8 expands recovered collision thresholds")
    _check(c.classify_terrain(samples, 0x15)["collision_class"] == 5, "$94 enters dynamic collision band after one expansion step")
    samples[4] = 0x92
    _check(c.classify_terrain(samples, 0x15)["collision_class"] == 5, "$92 enters lower dynamic collision band after one expansion step")


func _test_direct_master_writeback() -> void:
    var c := CombatModel.new()
    _check(c.destruction_replacement(0xF7) == 0x00, "$147F->$1A57 direct hit replaces master $F7 with $00")
    _check(c.destruction_replacement(0x12) == -1, "$12 belongs to separate $1AC1 maintenance path, not direct hit writeback")
    _check(c.destruction_replacement(0x4B) == -1, "$4B is not directly rewritten by laser hit")


func _test_moving_object_hit_rule() -> void:
    var c := CombatModel.new()
    c.fire(0, 0x15)
    var hit: Dictionary = c.resolve_moving_object_hit(5, 0x54, 0x75, 0x14)
    _check(hit["hit"] and hit["object_destroyed"], "live projectile hits object inside exact overlap and height band")
    _check(hit["score_award"] == 10, "moving object award is exact 2*object_state")
    _check(not c.projectile_active(), "moving object hit clears player laser at $FC43")

    c.reset()
    c.fire(0, 0x15)
    hit = c.resolve_moving_object_hit(5, 0x54 + 11, 0x75, 0x14)
    _check(hit["hit"], "signed X delta -11 is inside original object hit window")

    c.reset()
    c.fire(0, 0x15)
    hit = c.resolve_moving_object_hit(5, 0x54 - 10, 0x75, 0x14)
    _check(not hit["hit"], "signed X delta +10 is outside original object hit window")

    c.reset()
    c.fire(0, 0x15)
    hit = c.resolve_moving_object_hit(5, 0x54, 0x75, 0x13)
    _check(not hit["hit"], "object category 1 rejects current craft height below $14")

    c.reset()
    c.fire(0, 0x15)
    hit = c.resolve_moving_object_hit(4, 0x54, 0x75, 0x07)
    _check(hit["hit"] and hit["score_award"] == 8, "category 0 uses recovered $07-$5F height band when invoked")


func _test_score_integration() -> void:
    var m := FlightModel.new()
    m.reset()
    _check(m.endgame_model.score_value == 0, "flight combat integration starts at score zero")
    _check(m.flight_combat_model.fire(4, 0x15), "integration projectile can fire")
    var samples := [0x20,0x20,0x20,0x20,0x48,0x20,0x20,0x20,0x20]
    var events: Dictionary = m.resolve_flight_projectile(samples)
    _check(events["destructible"] and events["score_award"] == 15, "FlightModel receives verified destructible award")
    _check(m.endgame_model.score_value == 15, "verified terrain hit feeds recovered ending score state")
    _check(m.endgame_model.qualifies_for_ending_overlay(), "one authentic +15 terrain hit beats recovered initial best score 000010")
