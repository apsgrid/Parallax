extends SceneTree

const GroundModel = preload("res://scripts/ground_model.gd")

var failures := 0


func _initialize() -> void:
    _test_passable_tiles()
    _test_direction_priority()
    _test_blocked_fallthrough()
    _test_vertical_motion()
    _test_animation_cadence()
    _test_scroll_accumulator()
    _test_screen_origin_boundaries()
    _test_collision_screen_cells()
    _test_special_right_contact()

    if failures == 0:
        print("PARALLAX GROUND TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX GROUND TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _test_passable_tiles() -> void:
    _check(GroundModel.is_passable_tile(0x2A), "$2A is in the recovered walkable whitelist")
    _check(GroundModel.is_passable_tile(0x80), "$80 is in the recovered walkable whitelist")
    _check(GroundModel.is_passable_tile(0xDF), "$DF is in the recovered walkable whitelist")
    _check(not GroundModel.is_passable_tile(0xC1), "$C1 is not normally walkable")
    _check(not GroundModel.is_passable_tile(0x00), "$00 is not in the recovered walkable whitelist")


func _test_direction_priority() -> void:
    var m := GroundModel.new()
    var events := m.step(GroundModel.RIGHT | GroundModel.LEFT, 0)
    _check(events["moved"], "simultaneous horizontal input produces one accepted move")
    _check(events["move_delta"] == Vector2i(1, 0), "RIGHT wins the recovered direction priority")
    _check(events["scroll_delta"] == Vector2i(-1, 0), "RIGHT movement produces inverse -X scroll delta")
    _check(m.player_offset == Vector2i(1, 0), "ground player offset advances one pixel right")
    _check(m.scroll_offset == Vector2i(-1, 0), "RIGHT stores the recovered inverse ground-scroll pixel")
    _check(m.facing == 1, "RIGHT selects recovered facing code 1")


func _test_blocked_fallthrough() -> void:
    var m := GroundModel.new()
    var events := m.step(GroundModel.RIGHT | GroundModel.LEFT, GroundModel.RIGHT)
    _check(events["moved"], "blocked RIGHT falls through to another held direction")
    _check(events["move_delta"] == Vector2i(-1, 0), "LEFT moves when higher-priority RIGHT is blocked")
    _check(events["scroll_delta"] == Vector2i(1, 0), "LEFT movement produces inverse +X scroll delta")
    _check(m.facing == 2, "LEFT selects recovered facing code 2")


func _test_vertical_motion() -> void:
    var m := GroundModel.new()
    var events := m.step(GroundModel.DOWN, 0)
    _check(events["move_delta"] == Vector2i(0, 1), "DOWN moves one ground pixel")
    _check(events["scroll_delta"] == Vector2i(0, -1), "DOWN produces inverse -Y scroll delta")
    events = m.step(GroundModel.UP, 0)
    _check(events["move_delta"] == Vector2i(0, -1), "UP moves one ground pixel")
    _check(m.player_offset == Vector2i.ZERO, "opposite vertical moves cancel")


func _test_animation_cadence() -> void:
    var m := GroundModel.new()
    for i in range(3):
        m.step(GroundModel.RIGHT, 0)
    _check(m.animation_phase == 0, "walk animation holds phase for first three accepted moves")
    _check(m.frame_code == 0x56, "RIGHT phase 0 uses recovered frame $56")
    m.step(GroundModel.RIGHT, 0)
    _check(m.animation_phase == 1, "fourth accepted move advances walk animation phase")
    _check(m.frame_code == 0x58, "RIGHT phase 1 uses recovered frame $58")
    m.step(0, 0)
    _check(m.frame_code == 0x58, "idle RIGHT frame uses recovered frame $58")


func _test_scroll_accumulator() -> void:
    var m := GroundModel.new()
    m.step(GroundModel.RIGHT, 0)
    m.step(GroundModel.RIGHT, 0)
    m.step(GroundModel.DOWN, 0)
    _check(m.player_offset == Vector2i(2, 1), "accepted ground movement accumulates intuitive player displacement")
    _check(m.scroll_offset == Vector2i(-2, -1), "ground scroll accumulator remains the exact inverse displacement")

    m.reset()
    _check(m.scroll_offset == Vector2i.ZERO, "ground reset clears recovered inverse-scroll accumulator")


func _test_screen_origin_boundaries() -> void:
    var origin := Vector2i(10, 30)
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i.ZERO) == Vector2i(10, 30),
        "zero scroll keeps the original screen tile origin"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(7, 7)) == Vector2i(10, 30),
        "+7 fine scroll does not cross a character boundary"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(8, 8)) == Vector2i(9, 29),
        "+8 scroll reproduces $C00E wrap and decrements tile origin"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(-1, -1)) == Vector2i(11, 31),
        "-1 from fine zero reproduces immediate wrap to fine 7 and increments tile origin"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(-8, -8)) == Vector2i(11, 31),
        "-8 scroll remains one negative character from the original origin"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(7, 0) + Vector2i(1, 0)) == Vector2i(9, 30),
        "landing fine scroll + ground scroll are combined before boundary normalization"
    )
    _check(
        GroundModel.screen_origin_tile(origin, Vector2i(1, 0) + Vector2i(-1, 0)) == origin,
        "opposite flight/ground sub-tile scroll cancels before tile conversion"
    )


func _test_collision_screen_cells() -> void:
    _check(GroundModel.PLAYER_SCREEN_CELL == Vector2i(19, 10), "$E280 player collision center is screen cell 19,10")
    _check(GroundModel.COLLISION_UP_CELL == Vector2i(19, 9), "$E280 UP sample is screen cell 19,9")
    _check(GroundModel.COLLISION_LEFT_CELL == Vector2i(18, 10), "$E280 LEFT sample is screen cell 18,10")
    _check(GroundModel.COLLISION_RIGHT_CELL == Vector2i(20, 10), "$E280 RIGHT sample is screen cell 20,10")
    _check(GroundModel.COLLISION_DOWN_CELL == Vector2i(19, 11), "$E280 DOWN sample is screen cell 19,11")


func _test_special_right_contact() -> void:
    var m := GroundModel.new()
    var events := m.step(GroundModel.RIGHT, GroundModel.RIGHT, 0xC2)
    _check(not events["moved"], "blocked special contact does not perform normal movement")
    _check(events["special_right_interaction"], "$C1-$C3 blocked RIGHT contact triggers recovered special branch")
