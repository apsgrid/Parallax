extends SceneTree

const CombatModel = preload("res://scripts/flight_combat_model.gd")
const FlightModel = preload("res://scripts/flight_model.gd")

var failures := 0


func _initialize() -> void:
    _test_spawn_and_same_frame_motion()
    _test_two_slot_capacity_and_rng()
    _test_shared_sprite_animation()
    _test_aux_craft_collision()
    _test_flight_model_damage_bridge()
    _test_explosion_pointer_sequence()

    if failures == 0:
        print("PARALLAX AUX PROJECTILE TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX AUX PROJECTILE TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _seed(values: Dictionary = {}) -> Array:
    var bytes: Array = []
    bytes.resize(256)
    bytes.fill(0)
    for key in values:
        bytes[int(key)] = int(values[key])
    return bytes


func _surface_samples(_x: int, _y: int) -> Array:
    var samples: Array = []
    samples.resize(9)
    samples.fill(0x2A)
    return samples


func _fresh(seed_values: Dictionary = {}) -> CombatModel:
    var c := CombatModel.new()
    c.configure_runtime({
        "seed_bytes": _seed(seed_values),
        "damage_random_bytes": _seed(),
    })
    c.reset()
    return c


func _set_object(c: CombatModel, index: int, x: int, y: int) -> void:
    var slot: Dictionary = c.object_slots[index]
    slot["state"] = 5
    slot["x"] = x
    slot["y"] = y
    slot["direction"] = 4
    slot["spawn_phase"] = 0x10
    slot["anim_frame"] = 0
    slot["anim_subtick"] = 0
    slot["turn_timer"] = 0
    slot["color"] = 1
    c.object_slots[index] = slot


func _prime_three_objects(c: CombatModel) -> void:
    _set_object(c, 0, 60, 80)
    _set_object(c, 1, 120, 120)
    _set_object(c, 2, 170, 180)


func _test_spawn_and_same_frame_motion() -> void:
    var c := _fresh({1: 4})
    _prime_three_objects(c)
    var events := c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    _check(events["aux_fire_requests"].size() == 1, "$FACC low-three-bits == 4 allocates one hostile projectile")
    _check(int(events["aux_fire_requests"][0]["projectile_slot"]) == 0, "first hostile shot uses recovered first free slot")
    var shot: Dictionary = c.aux_projectiles[0]
    _check(int(shot["x"]) == 60 and int(shot["y"]) == 82, "$F8C6->$FDF6 moves a newly spawned direction-4 shot in the same frame")
    _check(int(shot["state"]) == 5 and int(shot["direction"]) == 4, "hostile shot inherits parent state and recovered 8-way RNG direction")
    _check(int(c.aux_projectile_render_state(0)["sprite_pointer"]) == 0x56, "hostile projectile begins on recovered sprite pointer $56")


func _test_two_slot_capacity_and_rng() -> void:
    var c := _fresh({1: 4, 2: 4, 3: 4})
    _prime_three_objects(c)
    var events := c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    _check(events["aux_fire_requests"].size() == 2, "only two persistent hostile projectile slots can be allocated")
    _check(int(c.aux_projectiles[0]["x"]) != 0 and int(c.aux_projectiles[1]["x"]) != 0, "both recovered hostile projectile records are occupied")
    _check(c.object_attack_random_cursor == 3, "$FBC4 attack RNG is consumed for all three fire attempts")
    _check(c.object_random_cursor == 2, "full two-slot pool drops the third shot without consuming $FBB9 direction RNG")


func _test_shared_sprite_animation() -> void:
    var c := _fresh({1: 4})
    _prime_three_objects(c)
    c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    for _i in range(3):
        c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    _check(int(c.aux_projectile_render_state(0)["sprite_pointer"]) == 0x57, "$FF0F shared animation advances after four scheduler ticks")


func _test_aux_craft_collision() -> void:
    var c := _fresh()
    _prime_three_objects(c)
    c.aux_projectiles[0] = {
        "x": 0x54,
        "y": 0x75,
        "direction": 4,
        "state": 5,
        "mode_or_pointer": 0,
    }
    var events := c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), false)
    _check(events["aux_craft_collisions"].size() == 1, "hostile projectile reaches recovered craft-collision path")
    _check(int(events["aux_craft_collisions"][0]["event_code"]) == 2, "zero primary RNG queues recovered $CF15 event code 2")
    _check(int(c.aux_projectiles[0]["state"]) == 0xFF, "craft impact changes hostile projectile to recovered explosion state")
    _check(int(c.aux_projectiles[0]["mode_or_pointer"]) == 0xBE, "hostile impact starts recovered explosion pointer $BE")


func _test_flight_model_damage_bridge() -> void:
    var m := FlightModel.new()
    m.configure_interior_runtime({
        "seed_bytes": _seed(),
        "damage_random_bytes": _seed(),
    })
    m.reset()
    _prime_three_objects(m.flight_combat_model)
    m.flight_combat_model.aux_projectiles[0] = {
        "x": 0x54,
        "y": 0x75,
        "direction": 4,
        "state": 5,
        "mode_or_pointer": 0,
    }
    var events := m.advance_flight_objects(Callable(self, "_surface_samples"), false)
    _check(events["damage_events"].size() == 1, "FlightModel routes hostile projectile impact through recovered damage consumer")
    _check(str(events["damage_events"][0]["damage_type"]) == "ENGINE", "hostile event code 2 damages recovered ENGINE field")
    _check(m.flight_combat_model.engine_damage == 2, "zero damage RNG applies recovered minimum +2 ENGINE damage")


func _test_explosion_pointer_sequence() -> void:
    var c := _fresh()
    _prime_three_objects(c)
    c.aux_projectiles[0] = {
        "x": 0x54,
        "y": 0x75,
        "direction": 4,
        "state": 5,
        "mode_or_pointer": 0,
    }
    c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), false)
    _check(int(c.aux_projectile_render_state(0)["sprite_pointer"]) == 0xBE, "new hostile explosion remains on $BE in its collision frame")
    c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    _check(int(c.aux_projectile_render_state(0)["sprite_pointer"]) == 0xBE, "odd post-impact direction tick holds explosion pointer")
    c.step_objects(0, 0, 0x20, 0, Callable(self, "_surface_samples"), true)
    _check(int(c.aux_projectile_render_state(0)["sprite_pointer"]) == 0xBF, "even post-impact direction tick advances recovered explosion pointer")
