extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")
const SupplyModel = preload("res://scripts/supply_model.gd")
const InteriorModel = preload("res://scripts/interior_model.gd")

var failures := 0


func _initialize() -> void:
    _test_complete_vertical_slice()
    if failures == 0:
        print("PARALLAX VERTICAL SLICE: PASS")
        quit(0)
    else:
        push_error("PARALLAX VERTICAL SLICE: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _synthetic_runtime() -> Dictionary:
    var room: Array = []
    for y in range(20):
        var row: Array = []
        for x in range(40):
            row.append(0x1F)
        room.append(row)

    # Upper $C1/$C2 entry centre is (6,7). Put the bank on the right,
    # and a blank-space exit three pixels to the left as in the E4DA path.
    room[7][7] = 0xD0
    room[7][4] = 0x20
    return {
        "base_tiles": room,
        "seed_base": 0,
        "seed_bytes": [],
        "patterns": {},
        "special_coords": [],
    }


func _test_complete_vertical_slice() -> void:
    var m := FlightModel.new()
    m.configure_interior_runtime(_synthetic_runtime())
    m.flight_height = FlightModel.LANDING_HEIGHT
    m.landing_gear = true
    m.world_x = 100
    m.world_y = 200

    # FLY -> LAND -> SHIP SUPPLY.
    m.step(0, false, 9)
    var events := m.step(0, true, 9)
    _check(events["ground_transition_requested"], "landing FIRE commits the recovered transition")
    events = m.step(0, false, 9)
    _check(events["entered_supply"] and m.in_supply_menu(), "landing reaches SHIP SUPPLY")

    # TAKE OXYGEN and EXIT SHIP.
    m.supply_model.carried_oxygen = 1
    m.supply_model.selection = SupplyModel.SEL_EXIT_ROW
    m.supply_model.side_right = true
    m.step(0, false, 9, 0, -1, true)
    events = m.step(0, false, 9, 0, -1, false)
    _check(events["exited_ship"] and m.on_foot(), "oxygen-gated EXIT SHIP reaches outdoor mode")

    # Outdoor blocked C1 entrance -> recovered E444 interior.
    events = m.step(GroundModel.RIGHT, false, 9, GroundModel.RIGHT, 0xC1, false)
    _check(events["entered_interior"] and m.in_interior(), "$C1 entrance reaches recovered interior mode")
    _check(m.interior_model.center_cell() == Vector2i(6, 7), "interior starts at recovered upper spawn")

    # Contact the recovered COMPUTABANK terminal.
    events = m.step(GroundModel.RIGHT, false, 9)
    _check(events["interior_terminal_opened"], "blocked D0 contact opens terminal")
    _check(events["interior_terminal_kind"] == InteriorModel.TERMINAL_BANK, "terminal is COMPUTABANK")
    _check(m.interior_model.terminal_open, "COMPUTABANK is modal")
    _check(m.computer_model.kard_text(m.computer_model.kards[0]) == "0-285", "vertical slice starts with recovered KARD 0-285")
    m.computer_model.press_action()
    var bank_events := m.computer_model.submit_kard_code("0285")
    _check(bank_events["kard_returned"], "vertical slice authenticates starting bank KARD")
    _check(m.computer_model.credits == 20, "class-0 bank query preserves initial 20 credits")

    # Original $EC45 behavior: a different direction unwinds the modal
    # terminal back to the local-area movement loop.
    events = m.step(GroundModel.LEFT, false, 9)
    _check(not m.interior_model.terminal_open and m.in_interior(), "different direction closes terminal back to interior")

    # Walk to left blank boundary and restore outdoor state.
    for i in range(3):
        events = m.step(GroundModel.LEFT, false, 9)
        _check(events["ground_moved"], "interior LEFT movement advances one pixel")
    events = m.step(0, false, 9)
    _check(events["exited_interior"] and m.on_foot(), "left $20 boundary exits interior back outdoors")

    # Outdoor state around the craft is preserved by the local-area detour.
    _check(m.ground_player_offset == Vector2i.ZERO, "interior round trip preserves outdoor craft-relative position")
    events = m.step(0, true, 9)
    _check(events["exited_ground"] and not m.landed, "FIRE at craft returns to flight")
    _check(not m.ground_transition_flag and m.flight_raster_mode, "flight state is restored after complete slice")
    _check(m.world_x == 100 and m.world_y == 200, "world position returns exactly to landing anchor")
