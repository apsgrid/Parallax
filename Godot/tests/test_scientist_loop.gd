extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")
const EncounterModel = preload("res://scripts/encounter_model.gd")

var failures := 0


func _initialize() -> void:
    _test_natural_scientist_kard_loop()
    if failures == 0:
        print("PARALLAX SCIENTIST LOOP: PASS")
        quit(0)
    else:
        push_error("PARALLAX SCIENTIST LOOP: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _room() -> Array:
    var room: Array = []
    for _y in range(20):
        var row: Array = []
        for _x in range(40):
            row.append(0x1F)
        room.append(row)
    # Upper entry is centre (6,7). Three LEFT pixels expose the left-space exit.
    room[7][4] = 0x20
    return room


func _zero_runtime() -> Dictionary:
    var bytes: Array = []
    bytes.resize(0x1800)
    bytes.fill(0)
    return {
        "seed_base": 0x0900,
        "seed_bytes": bytes,
        "base_tiles": _room(),
        "patterns": {},
        "special_coords": [],
    }


func _test_natural_scientist_kard_loop() -> void:
    var m := FlightModel.new()
    m.reset()
    m.configure_interior_runtime(_zero_runtime())

    # Establish an ordinary current-region local room around the recovered
    # C1/C2 spawn. This bypasses only travel to the doorway, not encounter logic.
    m.ground_transition_flag = true
    m.ground_initialized = true
    m.flight_raster_mode = false
    m.landed = true
    m.ground_entry_world = Vector2i(120, 240)
    m.ground_phase = FlightModel.GROUND_PHASE_INTERIOR
    m.interior_model.enter_with_layout(0xC1, _room())
    m.encounter_model.begin_ground_session()
    m.encounter_model.room_layout = _room()
    m.encounter_model.room_macro = Vector2i.ZERO

    m.supply_model.carried_stun_guns = 1
    m.supply_model.carried_ammunition = 5
    m.supply_model.ship_scientists = 0

    # Player is (62,98), facing RIGHT. Scientist at (70,98) is hit after
    # the projectile's immediate four-pixel firing-frame movement.
    m.encounter_model.set_test_entity(
        EncounterModel.TYPE_ROAMING_SCIENTIST,
        Vector2i(70,98),
        EncounterModel.DIR_RIGHT
    )

    var events := m.step(0, false, 9, 0, -1, true)
    _check(events["stun_projectile_fired"], "interior FIRE launches recovered stun projectile")
    _check(events["scientist_stunned"], "stun projectile converts roaming type 4 to stunned type 5")
    _check(events["kard_offer_opened"], "close stunned scientist opens generated KARD prompt")
    _check(m.kard_offer_pending(), "KARD Y/N prompt becomes modal")
    _check(m.supply_model.carried_ammunition == 4, "natural stun shot consumes one ammunition")

    var offered_text := m.computer_model.kard_text(m.encounter_model.offered_kard)
    _check(offered_text == "1-000", "shared zero byte stream produces deterministic offered KARD 1-000")

    var answer := m.answer_kard_offer(true)
    _check(answer["kard_taken"], "Y takes naturally generated KARD")
    _check(answer["scientist_following"], "scientist becomes type 6 after KARD interaction")
    _check(m.computer_model.kard_count() == 2, "natural KARD acquisition fills second carried slot")
    _check(m.computer_model.kard_text(m.computer_model.kards[1]) == "1-000", "acquired KARD persists in computer inventory")
    _check(m.encounter_model.scientist_present(), "captured scientist is now accompanying state 6")

    # Leave the local area through the recovered left-space boundary.
    for _i in range(3):
        events = m.step(GroundModel.LEFT, false, 9)
        _check(events["ground_moved"], "captured scientist follows while player walks toward exit")
    events = m.step(0, false, 9)
    _check(events["exited_interior"] and m.on_foot(), "local left-space boundary restores outdoor mode")

    # Scientist-present $E9E5==6 widens only negative X return range to -27.
    m.ground_model.player_offset = Vector2i(-20, 0)
    m.ground_player_offset = Vector2i(-20, 0)
    events = m.step(0, true, 9)
    _check(events["exited_ground"], "type-6 scientist permits recovered -20 X return-to-craft case")
    _check(m.supply_model.ship_scientists == 1, "unsolved captured scientist is restored aboard by $E760")
    _check(m.supply_model.carried_scientists == 0, "return clears TAKE AWAY scientist count")
    _check(m.computer_model.kard_count() == 2, "acquired KARD survives return to flight")
    _check(m.world_x == 120 and m.world_y == 240, "scientist return restores exact landing world anchor")
