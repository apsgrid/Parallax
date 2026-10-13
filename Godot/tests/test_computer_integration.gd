extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")
const InteriorModel = preload("res://scripts/interior_model.gd")
const ComputerModel = preload("res://scripts/computer_model.gd")

var failures := 0


func _initialize() -> void:
    _test_scientist_password_progression()
    if failures == 0:
        print("PARALLAX COMPUTER INTEGRATION: PASS")
        quit(0)
    else:
        push_error("PARALLAX COMPUTER INTEGRATION: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _room_with_password_contact() -> Array:
    var room: Array = []
    for _y in range(20):
        var row: Array = []
        for _x in range(40):
            row.append(0x1F)
        room.append(row)
    # C1/C2 spawn centre = (6,7); D5 is RIGHT-facing password-terminal edge.
    room[7][7] = 0xD5
    room[7][4] = 0x20
    return room


func _test_scientist_password_progression() -> void:
    var m := FlightModel.new()
    m.reset()

    # Establish the already-landed local-area state.
    m.ground_transition_flag = true
    m.ground_initialized = true
    m.flight_raster_mode = false
    m.landed = true
    m.ground_phase = FlightModel.GROUND_PHASE_INTERIOR
    m.ground_entry_world = Vector2i(44, 55)
    m.ground_player_offset = Vector2i.ZERO

    m.supply_model.carried_scientists = 1
    m.supply_model.ship_scientists = 0
    m.interior_model.enter_with_layout(0xC1, _room_with_password_contact())
    m.interior_model.password_gate_active = true
    m.interior_model.zone_index = 0

    var events := m.step(GroundModel.RIGHT, false, 9)
    _check(events["interior_terminal_opened"], "password contact opens terminal through FlightModel")
    _check(events["interior_terminal_kind"] == InteriorModel.TERMINAL_PASSWORD, "contact dispatches password terminal")
    _check(m.computer_model.state == ComputerModel.STATE_PASSWORD_ENTRY, "TAKE AWAY scientist activates special password gate")

    var computer_events := m.computer_model.submit_password("STACK")
    _check(computer_events["password_correct"], "STACK advances first progression gate")
    _check(m.computer_model.progression_index == 1, "FlightModel-owned computer progression advances to stage 1")
    _check(m.computer_model.password_solved_this_trip, "outing remembers solved password gate")

    # Leave terminal/interior, return to craft, and execute E760 consolidation.
    m.close_interior_terminal()
    m.ground_phase = FlightModel.GROUND_PHASE_OUTSIDE
    events = m.step(0, true, 9)
    _check(events["exited_ground"], "near-craft FIRE returns to flight after solved gate")
    _check(m.supply_model.carried_scientists == 0, "return clears TAKE AWAY scientist")
    _check(m.supply_model.ship_scientists == 0, "password-solved scientist is not returned aboard")
    _check(m.world_x == 44 and m.world_y == 55, "return preserves stored landing anchor")
