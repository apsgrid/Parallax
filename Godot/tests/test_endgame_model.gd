extends SceneTree

const EndgameModel = preload("res://scripts/endgame_model.gd")

var failures := 0


func _initialize() -> void:
    _test_score_gate()
    _test_band_mapping()
    _test_transport_selector()
    _test_real_master_destination()
    _test_ending_and_name_entry()

    if failures == 0:
        print("PARALLAX ENDGAME MODEL TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX ENDGAME MODEL TESTS: %d FAILURE(S)" % failures)
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


func _test_score_gate() -> void:
    var m := EndgameModel.new()
    m.reset_all()
    _check(m.score_text() == "000000", "game score starts at six-digit 000000")
    _check(m.high_score_text() == "000010", "initial best-score record is recovered 000010")
    _check(m.high_score_name == "CHRIX", "initial best-score name is recovered CHRIX")

    m.add_score(10)
    _check(not m.qualifies_for_ending_overlay(), "score equal to 000010 does not qualify")
    m.add_score(1)
    _check(m.qualifies_for_ending_overlay(), "score 000011 strictly beats recovered record")


func _test_band_mapping() -> void:
    var m := EndgameModel.new()
    _check(m.current_viewport_band(0) == 0, "macro Y 0 is transporter band 0")
    _check(m.current_viewport_band(18) == 0, "macro Y 18 remains transporter band 0")
    _check(m.current_viewport_band(19) == 1, "macro Y 19 enters transporter band 1")
    _check(m.current_viewport_band(36) == 1, "macro Y 36 remains transporter band 1")
    _check(m.current_viewport_band(37) == 2, "macro Y 37 enters transporter band 2")
    _check(m.current_viewport_band(55) == 3, "macro Y 55 enters transporter band 3")
    _check(m.current_viewport_band(73) == 4, "macro Y 73 enters transporter band 4")
    _check(m.current_viewport_band(91) == 5, "macro Y 91 enters transporter band 5")


func _test_transport_selector() -> void:
    var master := _empty_master()
    # Band 3 scan starts at row 57. Row-major order makes these indices 0,1.
    master[59][90] = 0x77
    master[61][70] = 0x77

    var m := EndgameModel.new()
    m.reset_all()
    m.configure_master_map(master)

    var candidates := m.transport_candidates(Vector2i(50,60))
    _check(candidates == [Vector2i(90,59), Vector2i(70,61)], "band-3 $77 markers are scanned in original row-major order")

    # $17C8 starts at zero, then increments before selection: first selector=1.
    var events := m.activate_transporter(Vector2i(50,60), 5)
    _check(events["transported"], "$70 transporter selects a valid $77 destination")
    _check(events["marker"] == Vector2i(70,61), "first low-nibble selector chooses candidate index 1")
    _check(events["pre_scroll_macro"] == Vector2i(66,63), "$1795 applies marker X-4 / Y+2 before scroll effect")
    _check(events["destination_macro"] == Vector2i(66,59), "twenty Y-scroll frames reduce final macro Y by four")
    _check(not events["final_gate"], "ordinary destination does not trigger stage-5 ending")
    _check(m.transport_cooldown == 0x32, "transporter sets recovered 50-frame re-entry cooldown")
    var blocked := m.activate_transporter(Vector2i(50,60), 5)
    _check(not blocked["transported"], "active transporter cooldown rejects immediate retrigger")
    for _i in range(0x32):
        m.tick_playing_frame()
    _check(m.transport_cooldown == 0, "50 flight frames expire transporter cooldown")

    # Force selector wrap so the next accepted low nibble is zero.
    m.transport_selector_counter = 15
    events = m.activate_transporter(Vector2i(50,60), 4)
    _check(events["marker"] == Vector2i(90,59), "selector wrap reaches candidate index 0")
    _check(events["destination_macro"] == Vector2i(86,57), "winning marker maps to recovered final viewport macro")
    _check(not events["final_gate"], "winning coordinates alone do not win before progression exactly 5")

    m.transport_cooldown = 0
    m.transport_selector_counter = 15
    events = m.activate_transporter(Vector2i(50,60), 5)
    _check(events["final_gate"], "progression 5 plus X>=80/Y<80 enters final effect")
    _check(m.state == EndgameModel.STATE_FINAL_EFFECT_WAIT_FIRE, "final transporter enters FIRE-wait state")


func _test_real_master_destination() -> void:
    var file := FileAccess.open("res://data/world_480.json", FileAccess.READ)
    _check(file != null, "corrected generated world data is available")
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    var master: Array = parsed.get("master_tiles", [])
    var destinations: Array = parsed.get("transport_destinations", [])

    var m := EndgameModel.new()
    m.configure_master_map(master)
    var candidates := m.transport_candidates(Vector2i(50,60))

    _check(destinations.size() == 18, "corrected runtime master map contains 18 $77 destinations")
    _check(candidates.size() == 6, "band 3 contains six original transporter destinations")
    _check(candidates[0] == Vector2i(90,59), "unique stage-5 winning marker is first band-3 candidate")

    var qualifying := []
    for marker in destinations:
        var p := Vector2i(int(marker["x"]) - 4, int(marker["y"]) - 2)
        if p.x >= 0x50 and p.y < 0x50:
            qualifying.append(Vector2i(int(marker["x"]), int(marker["y"])))
    _check(qualifying == [Vector2i(90,59)], "only master marker (90,59) satisfies final coordinate gate")


func _test_ending_and_name_entry() -> void:
    var master := _empty_master()
    master[59][90] = 0x77

    var m := EndgameModel.new()
    m.reset_all()
    m.configure_master_map(master)
    m.transport_selector_counter = 15
    var transport := m.activate_transporter(Vector2i(50,60), 5)
    _check(transport["final_gate"], "test setup reaches final transporter state")

    m.add_score(10)
    var events := m.step_ending(0, true)
    _check(events["score_disqualified"], "FIRE with score 000010 skips congratulatory overlay")
    _check(m.state == EndgameModel.STATE_TITLE_RETURN, "non-qualifying ending returns to title path")

    m.reset_game()
    m.configure_master_map(master)
    m.transport_selector_counter = 15
    m.add_score(11)
    m.activate_transporter(Vector2i(50,60), 5)
    events = m.step_ending(0, true)
    _check(events["ending_overlay_opened"], "FIRE with score 000011 opens recovered ending overlay")
    _check(m.state == EndgameModel.STATE_NAME_ENTRY, "qualified ending enters five-character name entry")
    _check(m.name_entry_display() == "A----", "name entry starts each position at screen code 1 / A")

    # Held FIRE cannot immediately accept the first character.
    events = m.step_ending(0, true)
    _check(not events["name_accepted"], "$8888 debounce rejects held FIRE on name-entry arrival")
    m.step_ending(0, false)

    # Two UP ticks increment A -> B, then FIRE accepts B.
    m.step_ending(EndgameModel.INPUT_UP, false)
    events = m.step_ending(EndgameModel.INPUT_UP, false)
    _check(events["name_changed"], "two-call cadence applies UP character increment")
    events = m.step_ending(0, true)
    _check(events["name_accepted"], "released-then-pressed FIRE accepts current name character")
    _check(m.name_entry_display().begins_with("BA"), "first accepted name character is B and next starts at A")

    # Accept remaining four A characters with a release before each FIRE.
    for _i in range(4):
        m.step_ending(0, false)
        events = m.step_ending(0, true)

    _check(events["title_returned"], "fifth accepted character returns through original title path")
    _check(m.state == EndgameModel.STATE_TITLE_RETURN, "name completion reaches title-return state")
    _check(m.high_score_value == 11, "qualified ending copies current score into best-score record")
    _check(m.high_score_name == "BAAAA", "five entered characters replace recovered best-score name")
    _check(m.title_return_message().contains("000011"), "title-return record exposes updated six-digit score")
