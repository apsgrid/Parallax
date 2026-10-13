extends SceneTree

const InteriorModel = preload("res://scripts/interior_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")

var failures := 0


func _initialize() -> void:
    _test_entry_geometry()
    _test_terminal_code_families()
    _test_terminal_contact()
    _test_exit_boundary()
    _test_generated_runtime()

    if failures == 0:
        print("PARALLAX INTERIOR TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX INTERIOR TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _floor_room() -> Array:
    var room: Array = []
    for _y in range(20):
        var row: Array = []
        for _x in range(40):
            row.append(0x1F)
        room.append(row)
    return room


func _test_entry_geometry() -> void:
    var m := InteriorModel.new()
    var room := _floor_room()
    m.enter_with_layout(0xC1, room)
    _check(m.local_position == Vector2i(0x3E, 0x62), "$C1 uses recovered upper interior spawn")
    _check(m.center_cell() == Vector2i(6, 7), "upper spawn maps through $E5E6 to cell 6,7")

    m.enter_with_layout(0xC2, room)
    _check(m.center_cell() == Vector2i(6, 7), "$C2 shares recovered upper spawn")

    m.enter_with_layout(0xC3, room)
    _check(m.local_position == Vector2i(0x3E, 0x8A), "$C3 uses recovered lower interior spawn")
    _check(m.center_cell() == Vector2i(6, 12), "lower spawn maps through $E5E6 to cell 6,12")


func _test_terminal_code_families() -> void:
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.RIGHT, 0xD0) == InteriorModel.TERMINAL_BANK, "RIGHT $D0 dispatches COMPUTABANK")
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.LEFT, 0xCE) == InteriorModel.TERMINAL_BANK, "LEFT $CE dispatches COMPUTABANK")
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.RIGHT, 0xD2) == InteriorModel.TERMINAL_SHOP, "RIGHT $D2 dispatches COMPUTASHOP")
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.LEFT, 0xD1) == InteriorModel.TERMINAL_SHOP, "LEFT $D1 dispatches COMPUTASHOP")
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.DOWN, 0xD6) == InteriorModel.TERMINAL_PASSWORD, "DOWN $D6 dispatches password terminal")
    _check(InteriorModel.terminal_kind_for_contact(GroundModel.UP, 0xD4) == InteriorModel.TERMINAL_PASSWORD, "UP $D4 dispatches password terminal")


func _test_terminal_contact() -> void:
    var room := _floor_room()
    room[7][7] = 0xD0
    var m := InteriorModel.new()
    m.enter_with_layout(0xC1, room)
    var events := m.step(GroundModel.RIGHT)
    _check(not events["moved"], "blocked terminal contact does not move the player")
    _check(events["terminal_opened"], "blocked terminal contact opens recovered interaction")
    _check(events["terminal_kind"] == InteriorModel.TERMINAL_BANK, "contact reports COMPUTABANK kind")
    _check(m.terminal_open, "terminal state remains modal")
    events = m.step(GroundModel.LEFT)
    _check(events["terminal_closed"], "$EC45-equivalent different direction unwinds terminal")
    _check(not m.terminal_open, "terminal returns to interior loop")


func _test_exit_boundary() -> void:
    var room := _floor_room()
    room[7][4] = 0x20
    var m := InteriorModel.new()
    m.enter_with_layout(0xC1, room)

    for _i in range(3):
        var events := m.step(GroundModel.LEFT)
        _check(events["moved"], "left corridor movement advances one local pixel")
    _check(m.local_position.x == 0x3B, "three LEFT steps reach recovered exit-adjacent X")

    var exit_events := m.step(0)
    _check(exit_events["exited"], "$E4DA-equivalent left $20 sample exits interior")
    _check(not m.active, "interior state clears on exit")


func _test_generated_runtime() -> void:
    var file := FileAccess.open("res://data/interior_runtime.json", FileAccess.READ)
    _check(file != null, "generated interior runtime data is available")
    if file == null:
        return
    var data = JSON.parse_string(file.get_as_text())
    _check(typeof(data) == TYPE_DICTIONARY, "interior runtime JSON parses")
    if typeof(data) != TYPE_DICTIONARY:
        return

    var m := InteriorModel.new()
    m.configure_runtime(data)
    m.enter(0xC1, 0, 14, 0)
    _check(m.layout.size() == 20, "recovered interior layout has 20 rows")
    _check(m.layout[0].size() == 40, "recovered interior layout has 40 columns")
    _check(m.center_cell() == Vector2i(6, 7), "generated room preserves recovered entry geometry")

    # Region anchor (13,15) forces the $04 password-terminal placement flag.
    m.enter(0xC1, 13, 15, 0)
    var flattened: Array = []
    for row in m.layout:
        flattened.append_array(row)
    _check(0xD5 in flattened and 0xD3 in flattened and 0xD6 in flattened and 0xD4 in flattened, "recovered region anchor stamps KARD/password terminal pattern")
