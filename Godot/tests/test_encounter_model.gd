extends SceneTree

const EncounterModel = preload("res://scripts/encounter_model.gd")
const ComputerModel = preload("res://scripts/computer_model.gd")
const SupplyModel = preload("res://scripts/supply_model.gd")

var failures := 0


func _initialize() -> void:
    _test_spawn()
    _test_region_gated_fire()
    _test_stun_offer_and_capture()
    _test_decline_still_captures()
    _test_existing_ship_scientist_blocks_follow()
    _test_projectile_impact_lifetime()
    _test_carried_scientist_state()

    if failures == 0:
        print("PARALLAX ENCOUNTER TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX ENCOUNTER TESTS: %d FAILURE(S)" % failures)
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


func _runtime_with_type_selector(selector: int) -> Dictionary:
    var seed: Array = []
    seed.resize(0x800)
    seed.fill(0)
    seed[0x700] = selector
    return {
        "seed_base": 0x0900,
        "seed_bytes": seed,
    }


func _computer_with_zero_stream() -> ComputerModel:
    var c := ComputerModel.new()
    c.reset_all()
    var bytes: Array = []
    bytes.resize(256)
    bytes.fill(0)
    c.configure_runtime({"seed_bytes": bytes})
    return c


func _test_spawn() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    e.configure_runtime(_runtime_with_type_selector(2))
    e.begin_ground_session()
    var events := e.enter_room(_floor_room(), 0, 0, 0, false, Vector2i(62, 98), c)
    _check(events["entity_spawned"], "current progression region spawns a local entity")
    _check(e.entity_type == EncounterModel.TYPE_ROAMING_SCIENTIST, "selector 2 maps through $E9E7 to roaming scientist type 4")
    _check(e.entity_position == Vector2i(128, 70), "zero stream reproduces recovered spawn origin 128,70")
    _check(e.entity_direction == EncounterModel.DIR_RIGHT, "spawn direction uses shared random byte & 3")

    e.begin_ground_session()
    events = e.enter_room(_floor_room(), 0, 18, 0, false, Vector2i(62, 98), c)
    _check(not events["entity_spawned"], "$E833 suppresses spawning outside current progression region")


func _test_region_gated_fire() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    var s := SupplyModel.new()
    s.reset_all()
    s.carried_stun_guns = 1
    s.carried_ammunition = 3
    e.begin_ground_session()
    e.room_layout = _floor_room()
    e.room_macro = Vector2i(0, 18)
    var events := e.step_frame(Vector2i(62,98), 1, true, 0, s, c)
    _check(not events["projectile_fired"], "stun gun is disabled outside the current progression region")
    _check(s.carried_ammunition == 3, "region-rejected fire does not consume ammunition")

    e.room_macro = Vector2i(0, 0)
    events = e.step_frame(Vector2i(62,98), 1, true, 0, s, c)
    _check(events["projectile_fired"], "stun gun fires inside current progression region")
    _check(s.carried_ammunition == 2, "stun shot consumes exactly one carried ammunition")
    _check(s.carried_stun_guns == 1, "stun shot does not consume the stun-gun")
    _check(e.projectile_position == Vector2i(66,98), "RIGHT stun projectile moves four pixels on the firing frame")


func _test_stun_offer_and_capture() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    var s := SupplyModel.new()
    s.reset_all()
    s.carried_stun_guns = 1
    s.carried_ammunition = 5
    s.ship_scientists = 0
    e.begin_ground_session()
    e.room_layout = _floor_room()
    e.room_macro = Vector2i.ZERO
    e.set_test_entity(EncounterModel.TYPE_ROAMING_SCIENTIST, Vector2i(70,98))

    var events := e.step_frame(Vector2i(62,98), 1, true, 0, s, c)
    _check(events["entity_hit"], "projectile collision detects scientist within recovered -6..+5 box")
    _check(events["scientist_stunned"], "type 4 stun hit converts scientist to type 5")
    _check(e.entity_type == EncounterModel.TYPE_STUNNED_SCIENTIST, "stunned scientist is immobile type 5")
    _check(not e.spawn_enabled, "entity hit clears the original respawn-enable flag")
    _check(events["kard_offer_opened"], "player within recovered approach window opens KARD offer")
    _check(e.kard_offer_pending, "KARD offer remains modal for Y/N")
    _check(e.offered_kard == [1,0,0,0], "KARD is generated before Y/N from the shared byte stream")

    var answer := e.answer_kard_offer(true, c, s.ship_scientists, Vector2i(62,98))
    _check(answer["kard_taken"], "Y accepts generated KARD")
    _check(c.kard_count() == 2 and c.kard_text(c.kards[1]) == "1-000", "accepted KARD enters recovered two-slot inventory")
    _check(answer["scientist_following"], "scientist is promoted after KARD prompt returns")
    _check(e.entity_type == EncounterModel.TYPE_ACCOMPANYING_SCIENTIST, "captured scientist becomes type 6")
    _check(e.entity_position == Vector2i(78,98), "type 6 follows sixteen pixels to the player's right")


func _test_decline_still_captures() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    var s := SupplyModel.new()
    s.reset_all()
    s.ship_scientists = 0
    e.begin_ground_session()
    e.kard_offer_pending = true
    e.offered_kard = [2,1,2,3]
    e.entity_type = EncounterModel.TYPE_STUNNED_SCIENTIST

    var answer := e.answer_kard_offer(false, c, s.ship_scientists, Vector2i(40,50))
    _check(answer["kard_declined"], "N declines generated KARD")
    _check(c.kard_count() == 1, "declined KARD is not added to inventory")
    _check(answer["scientist_following"], "declining KARD still promotes scientist after $F061 returns")
    _check(e.entity_type == EncounterModel.TYPE_ACCOMPANYING_SCIENTIST, "declined-offer scientist still becomes type 6")


func _test_existing_ship_scientist_blocks_follow() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    e.begin_ground_session()
    e.kard_offer_pending = true
    e.offered_kard = [2,1,2,3]
    e.entity_type = EncounterModel.TYPE_STUNNED_SCIENTIST

    var answer := e.answer_kard_offer(true, c, 1, Vector2i(40,50))
    _check(answer["kard_taken"], "KARD can still be taken when a scientist is already aboard")
    _check(not answer["scientist_following"], "$CF06!=0 suppresses type-6 promotion")
    _check(e.entity_type == EncounterModel.TYPE_STUNNED_SCIENTIST, "scientist remains type 5 when one is already aboard")


func _test_projectile_impact_lifetime() -> void:
    var e := EncounterModel.new()
    var c := _computer_with_zero_stream()
    var s := SupplyModel.new()
    s.reset_all()
    s.carried_stun_guns = 1
    s.carried_ammunition = 1
    var room := _floor_room()
    room[7][7] = 0x00
    e.begin_ground_session()
    e.room_layout = room
    e.room_macro = Vector2i.ZERO

    var events := e.step_frame(Vector2i(62,98), 1, true, 0, s, c)
    _check(events["projectile_blocked"], "blocked forward character starts impact animation")
    _check(e.projectile_impact, "blocked projectile enters recovered high-bit impact state")
    for _i in range(16):
        e.step_frame(Vector2i(62,98), 1, false, 0, s, c)
    _check(not e.projectile_active, "eight two-frame impact steps clear projectile after 16 frames")


func _test_carried_scientist_state() -> void:
    var e := EncounterModel.new()
    e.begin_ground_session()
    e.set_carried_scientist(Vector2i(62,98))
    _check(e.entity_type == EncounterModel.TYPE_ACCOMPANYING_SCIENTIST, "TAKE AWAY scientist maps to local type 6")
    _check(e.scientist_present(), "type 6 reports scientist present for return/password logic")
