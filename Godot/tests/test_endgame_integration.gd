extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")
const EndgameModel = preload("res://scripts/endgame_model.gd")

var failures := 0


func _initialize() -> void:
    _test_flight_transporter_to_ending()

    if failures == 0:
        print("PARALLAX ENDGAME INTEGRATION: PASS")
        quit(0)
    else:
        push_error("PARALLAX ENDGAME INTEGRATION: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _empty_master() -> Array:
    var rows: Array = []
    for _y in range(96):
        var row: Array = []
        row.resize(96)
        row.fill(0)
        rows.append(row)
    return rows


func _test_flight_transporter_to_ending() -> void:
    var master := _empty_master()
    master[59][90] = 0x77

    var m := FlightModel.new()
    m.reset()
    m.configure_world_runtime(master)

    # Place the flight viewport at exact macro (50,60), preserving zero
    # tile/fine remainder. INITIAL_VIEW_ORIGIN_TILE is (10,30).
    m.world_x = -(50 * 5 - 10) * 8
    m.world_y = -(60 * 5 - 30) * 8
    m.vx_hi = 2
    m.vy_hi = -1
    m.computer_model.progression_index = 5
    m.endgame_model.transport_selector_counter = 15
    m.add_score(11)

    _check(m.viewport_macro() == Vector2i(50,60), "integration setup maps flight scroll to macro 50,60")

    var events := m.step(
        0,
        false,
        9,
        0,
        -1,
        false,
        EndgameModel.TRANSPORT_TRIGGER_TILE
    )
    _check(events["transported"], "flight $70 contact invokes recovered transporter")
    _check(events["transport_marker"] == Vector2i(90,59), "flight integration selects recovered winning $77 marker")
    _check(events["transport_destination_macro"] == Vector2i(86,57), "flight integration applies final post-scroll destination")
    _check(m.viewport_macro() == Vector2i(86,57), "world scroll is realigned to destination macro")
    _check(m.world_x == -3360 and m.world_y == -2040, "transporter preserves tile remainder while updating exact scroll accumulators")
    _check(m.vx_hi == 0 and m.vy_hi == 0, "transporter clears recovered integer flight velocities")
    _check(events["endgame_triggered"], "progression-5 winning destination raises final-effect event")
    _check(m.endgame_active(), "final transporter suspends ordinary flight model")
    _check(m.endgame_model.state == EndgameModel.STATE_FINAL_EFFECT_WAIT_FIRE, "integration enters original FIRE-wait ending phase")

    var ending_events := m.step_endgame(0, true)
    _check(ending_events["ending_overlay_opened"], "FIRE hands qualified score to restored ending overlay")
    _check(m.endgame_model.state == EndgameModel.STATE_NAME_ENTRY, "integrated ending reaches original five-character name entry")
    _check(m.endgame_model.ending_message().contains("WELL DONE CAP'N"), "integrated ending exposes recovered congratulatory text")
