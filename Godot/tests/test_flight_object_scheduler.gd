extends SceneTree

const CombatModel = preload("res://scripts/flight_combat_model.gd")

var failures := 0


func _initialize() -> void:
    _test_surface_spawn()
    _test_void_spawn()
    _test_edge_spawn()
    _test_surface_motion()
    _test_blocked_turn()
    _test_edge_motion()
    _test_object_laser_score()
    _test_craft_collision_boundary()
    _test_object_explosion_lifetime()

    if failures == 0:
        print("PARALLAX FLIGHT OBJECT SCHEDULER TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX FLIGHT OBJECT SCHEDULER TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _zero_seed() -> Array:
    var bytes: Array = []
    bytes.resize(256)
    bytes.fill(0)
    return bytes


func _surface_samples(_x: int, _y: int) -> Array:
    var samples: Array = []
    samples.resize(9)
    samples.fill(0x2A)
    return samples


func _void_samples(_x: int, _y: int) -> Array:
    var samples: Array = []
    samples.resize(9)
    samples.fill(0x0D)
    return samples


func _mixed_samples(_x: int, _y: int) -> Array:
    return [0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20]


func _fresh() -> CombatModel:
    var c := CombatModel.new()
    c.configure_runtime({"seed_bytes": _zero_seed()})
    c.reset()
    return c


func _set_slot(c: CombatModel, index: int, state: int, x: int, y: int, direction: int, phase: int = 0x10) -> Dictionary:
    var slot: Dictionary = c.object_slots[index]
    slot["state"] = state
    slot["x"] = x
    slot["y"] = y
    slot["direction"] = direction
    slot["spawn_phase"] = phase
    slot["anim_frame"] = 0
    slot["anim_subtick"] = 0
    slot["turn_timer"] = 0
    slot["color"] = 1
    c.object_slots[index] = slot
    return slot


func _test_surface_spawn() -> void:
    var c := _fresh()
    var events := c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(events["spawned"].size() == 3, "all three inactive slots attempt recovered surface spawn")
    for i in range(3):
        var slot := c.object_slot(i)
        _check(int(slot["x"]) == 0x28 and int(slot["y"]) == 0x32, "zero random stream produces recovered $28/$32 spawn in slot %d" % i)
        _check(int(slot["state"]) == 5, "surface category becomes recovered state 5 in region 0 slot %d" % i)
        _check(int(slot["direction"]) == 4 and int(slot["spawn_phase"]) == 0, "surface spawn begins materialization with direction 4")
    var render := c.object_render_state(0)
    _check(render["sprite_pointer"] == 0xB1, "materialization phase 0 renders recovered sprite $B1")
    _check(render["color"] == 0x0D, "region-0 state-5 color comes from recovered $FDC9 table")


func _test_void_spawn() -> void:
    var c := _fresh()
    var events := c.step_objects(0,0,0x10,0,Callable(self,"_void_samples"),true)
    _check(events["spawned"].size() == 3, "void footprint permits all three category-2 slots")
    _check(int(c.object_slot(0)["state"]) == 6, "void category becomes recovered state 6 in region 0")


func _test_edge_spawn() -> void:
    var c := _fresh()
    var events := c.step_objects(0,0,0x20,0,Callable(self,"_mixed_samples"),true)
    _check(events["spawned"] == [0], "mixed terrain only permits category-3 spawn in slot 0")
    var slot := c.object_slot(0)
    _check(int(slot["state"]) == 7, "mixed slot-0 spawn becomes recovered state 7 in region 0")
    _check(int(slot["x"]) == 0x02 and int(slot["y"]) == 0xA0, "zero stream selects recovered left-edge category-3 entry")
    _check(int(slot["direction"]) == 1 and int(slot["spawn_phase"]) == 0x10, "edge object starts active with recovered direction 1")


func _test_surface_motion() -> void:
    var c := _fresh()
    _set_slot(c,0,5,50,80,1)
    c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(int(c.object_slot(0)["x"]) == 51 and int(c.object_slot(0)["y"]) == 80, "surface direction 1 moves one pixel right")

    c = _fresh()
    _set_slot(c,0,5,50,80,4,0)
    for _i in range(14):
        c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(int(c.object_slot(0)["spawn_phase"]) == 14, "surface materialization advances one phase per frame")
    c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(int(c.object_slot(0)["spawn_phase"]) == 15 and int(c.object_slot(0)["direction"]) == 0, "phase 15 selects recovered random cardinal direction")
    _check(c.object_render_state(0)["sprite_pointer"] == 0xB4, "phase 15 renders recovered $B4 materialization sprite")


func _test_blocked_turn() -> void:
    var c := _fresh()
    _set_slot(c,0,5,60,90,1)
    c.step_objects(0,0,0x20,0,Callable(self,"_mixed_samples"),true)
    var slot := c.object_slot(0)
    _check(int(slot["x"]) == 60 and int(slot["y"]) == 90, "blocked surface move keeps compensated base coordinates")
    _check(int(slot["direction"]) == 2, "zero random bit rotates blocked direction +1")


func _test_edge_motion() -> void:
    var c := _fresh()
    _set_slot(c,0,7,60,90,0)
    c.step_objects(0,0,0x20,0,Callable(self,"_mixed_samples"),true)
    var slot := c.object_slot(0)
    _check(int(slot["x"]) == 60 and int(slot["y"]) == 88, "category-3 direction 0 uses recovered (0,-2) vector")

    slot["turn_timer"] = 15
    c.object_slots[0] = slot
    c.step_objects(0,0,0x20,0,Callable(self,"_mixed_samples"),true)
    _check(int(c.object_slot(0)["turn_timer"]) == 0 and int(c.object_slot(0)["direction"]) == 1, "category-3 direction changes after recovered 16-frame timer")


func _test_object_laser_score() -> void:
    var c := _fresh()
    _set_slot(c,0,5,0x54,0x75,4)
    _check(c.fire(0,0x20), "scheduler test creates live player laser")
    var events := c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(events["laser_hits"] == [0], "naturally scheduled object reaches verified laser-hit endpoint")
    _check(events["score_award"] == 10, "state-5 scheduled object awards exact 2*state = 10")
    _check(int(c.object_slot(0)["state"]) == 0xFF, "laser-hit scheduled object enters recovered explosion state")
    _check(not c.projectile_active(), "object hit clears player laser")


func _test_craft_collision_boundary() -> void:
    var c := _fresh()
    _set_slot(c,0,5,0x54,0x75,4)
    var events := c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),false)
    _check(events["craft_collisions"].size() == 1 and int(events["craft_collisions"][0]["slot"]) == 0, "scheduled object detects recovered craft overlap at $54/$75")
    _check(int(events["craft_collisions"][0]["event_code"]) == 2, "zero random stream exposes recovered craft-collision event code 2")
    _check(events["score_award"] == 0, "craft/object collision does not award score")
    _check(int(c.object_slot(0)["state"]) == 0xFF, "craft collision enters object explosion path")


func _test_object_explosion_lifetime() -> void:
    var c := _fresh()
    _set_slot(c,0,5,0x54,0x75,4)
    c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),false)
    for _i in range(19):
        c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(int(c.object_slot(0)["state"]) == 0xFF, "object explosion remains active through frame 19")
    c.step_objects(0,0,0x20,0,Callable(self,"_surface_samples"),true)
    _check(int(c.object_slot(0)["state"]) == 0, "object explosion clears on recovered frame 20")
