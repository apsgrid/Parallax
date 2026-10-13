extends SceneTree

const CombatModel = preload("res://scripts/flight_combat_model.gd")
const FlightModel = preload("res://scripts/flight_model.gd")

var failures := 0


func _initialize() -> void:
    _test_damage_amount_and_labels()
    _test_lazer_gate()
    _test_damage_recovery()
    _test_shield_is_status_only()
    _test_object_collision_bridge()
    _test_engine_damage_blocks_landing()
    if failures == 0:
        print("FLIGHT DAMAGE TESTS: PASS")
        quit(0)
    else:
        push_error("FLIGHT DAMAGE TESTS: %d failure(s)" % failures)
        quit(1)


func _check(value: bool, label: String) -> void:
    if value:
        print("PASS ", label)
    else:
        failures += 1
        push_error("FAIL " + label)


func _zeroes(count: int = 256) -> Array:
    var result := []
    result.resize(count)
    result.fill(0)
    return result


func _surface_samples(_x: int, _y: int) -> Array:
    return [0x2A,0x2A,0x2A,0x2A,0x2A,0x2A,0x2A,0x2A,0x2A]


func _test_damage_amount_and_labels() -> void:
    var c := CombatModel.new()
    c.configure_runtime({"damage_random_bytes": _zeroes()})
    c.reset()
    var engine := c.apply_craft_impact(2)
    _check(engine["applied"] and engine["damage_type"] == "ENGINE", "event code 2 maps to recovered ENGINE damage")
    _check(engine["damage_amount"] == 2 and c.engine_damage == 2, "zero $C000 random byte produces recovered minimum +2 ENGINE damage")
    var lazers := c.apply_craft_impact(3)
    _check(lazers["damage_type"] == "LAZERS" and c.laser_damage == 2, "event code 3 maps to recovered LAZERS damage")


func _test_lazer_gate() -> void:
    var c := CombatModel.new()
    c.reset()
    c.laser_damage = 6
    _check(c.can_fire(), "$CF02 LAZERS damage 6 still allows firing")
    c.laser_damage = 7
    _check(not c.can_fire(), "$CF02 LAZERS damage 7 reaches recovered fire lockout")


func _test_damage_recovery() -> void:
    var c := CombatModel.new()
    c.reset()
    c.landing_gear_damage = 3
    c.engine_damage = 4
    c.laser_damage = 5
    for _i in range(89):
        c.advance_damage_recovery()
    _check(c.engine_damage == 4 and c.laser_damage == 5, "damage is unchanged for first 89 status ticks")
    var recovery := c.advance_damage_recovery()
    _check(recovery["recovered"], "$2058 recovery fires on status tick $5A")
    _check(c.landing_gear_damage == 2 and c.engine_damage == 3 and c.laser_damage == 4, "recovery decrements $CF00-$CF02 exactly once")


func _test_shield_is_status_only() -> void:
    var c := CombatModel.new()
    c.configure_runtime({"damage_random_bytes": _zeroes()})
    c.reset()
    _check(not c.shields_on, "$CF26 starts clear / SHIELDS OFF")
    _check(c.toggle_shields(), "F7-equivalent toggle sets $CF26 / SHIELDS ON")
    var hit := c.apply_craft_impact(2)
    _check(hit["damage_amount"] == 2 and c.engine_damage == 2, "shield state does not alter recovered $2022 ENGINE damage path")


func _test_object_collision_bridge() -> void:
    var m := FlightModel.new()
    m.configure_interior_runtime({
        "seed_bytes": _zeroes(0x1800),
        "damage_random_bytes": _zeroes(),
    })
    m.reset()
    var slot: Dictionary = m.flight_combat_model.object_slots[0]
    slot["state"] = 5
    slot["x"] = 0x54
    slot["y"] = 0x75
    slot["direction"] = 4
    slot["spawn_phase"] = 0x10
    slot["anim_frame"] = 0
    slot["anim_subtick"] = 0
    slot["turn_timer"] = 0
    slot["color"] = 1
    m.flight_combat_model.object_slots[0] = slot
    var events := m.advance_flight_objects(Callable(self, "_surface_samples"), false)
    _check(events["damage_events"].size() == 1, "FlightModel consumes queued craft-collision damage in same frame")
    _check(int(events["damage_events"][0]["event_code"]) == 2 and m.flight_combat_model.engine_damage == 2, "zero object RNG event 2 applies +2 ENGINE damage")


func _test_engine_damage_blocks_landing() -> void:
    var m := FlightModel.new()
    m.reset()
    m.flight_combat_model.engine_damage = 0x28
    m.flight_height = FlightModel.LANDING_HEIGHT
    m.landing_gear = true
    m.vx_hi = 0
    m.vy_hi = 0
    var events := m.step(0, true, 9, 0, -1, true)
    _check(not events["ground_transition_requested"], "$CF01 ENGINE damage >= $28 blocks recovered landing transition")
