extends SceneTree

const SupplyModel = preload("res://scripts/supply_model.gd")

var failures := 0


func _initialize() -> void:
    _test_initial_inventory()
    _test_transfer()
    _test_oxygen_gate_and_exit()
    _test_stay_aboard()
    _test_drug_scientist_flow()
    _test_standard_kit()
    _test_cursor_repeat()

    if failures == 0:
        print("PARALLAX SUPPLY TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX SUPPLY TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _fire_and_release(m: SupplyModel) -> Dictionary:
    m.step(SupplyModel.FIRE)
    return m.step(0)


func _test_initial_inventory() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    _check(m.ship_oxygen == 50, "startup ship oxygen matches $CF04=$32")
    _check(m.ship_stun_guns == 1, "startup ship stun-guns match $CF07=$01")
    _check(m.ship_ammunition == 50, "startup ship ammunition matches $CF08=$32")
    _check(m.selection == SupplyModel.SEL_SPACER, "supply cursor starts at recovered selection 6")
    _check(not m.side_right, "supply cursor starts in left column")


func _test_transfer() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.selection = SupplyModel.SEL_OXYGEN
    m.side_right = true
    var events := _fire_and_release(m)
    _check(events["changed"], "oxygen transfer fires on FIRE release")
    _check(m.ship_oxygen == 49 and m.carried_oxygen == 1, "RIGHT transfers one oxygen ship -> TAKE AWAY")

    m.side_right = false
    events = _fire_and_release(m)
    _check(m.ship_oxygen == 50 and m.carried_oxygen == 0, "LEFT transfers one oxygen TAKE AWAY -> ship")


func _test_oxygen_gate_and_exit() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.selection = SupplyModel.SEL_EXIT_ROW
    m.side_right = true
    var events := _fire_and_release(m)
    _check(not events["exit_ship"], "EXIT SHIP is blocked with zero carried oxygen")
    _check(events["message_code"] == SupplyModel.MSG_NEED_OXYGEN, "zero-oxygen exit uses recovered warning")

    m.carried_oxygen = 1
    events = _fire_and_release(m)
    _check(events["exit_ship"], "EXIT SHIP succeeds once TAKE AWAY oxygen is nonzero")


func _test_stay_aboard() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.selection = SupplyModel.SEL_EXIT_ROW
    m.side_right = false
    var events := _fire_and_release(m)
    _check(events["stay_aboard"], "left action on row 8 is STAY ABOARD")


func _test_drug_scientist_flow() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.selection = SupplyModel.SEL_DRUGS
    m.drugs = 1
    var events := _fire_and_release(m)
    _check(events["message_code"] == SupplyModel.MSG_NO_SCIENTIST, "drug action without scientist reports NO SCIENTIST")
    _check(m.drugs == 1, "drug is not consumed when no scientist is present")

    m.ship_scientists = 1
    m.selection = SupplyModel.SEL_SCIENTISTS
    m.side_right = true
    events = _fire_and_release(m)
    _check(events["message_code"] == SupplyModel.MSG_SCIENTIST_REFUSES, "undrugged scientist refuses transfer")
    _check(m.carried_scientists == 0, "refusing scientist remains aboard")

    m.selection = SupplyModel.SEL_DRUGS
    m.side_right = false
    events = _fire_and_release(m)
    _check(events["message_code"] == SupplyModel.MSG_DRUGGING_SCIENTIST, "drugging scientist uses recovered confirmation")
    _check(m.drugs == 0 and m.scientist_drugged, "drugging consumes one drug and sets $CF34-equivalent flag")

    m.selection = SupplyModel.SEL_SCIENTISTS
    m.side_right = true
    events = _fire_and_release(m)
    _check(events["changed"], "drugged scientist transfer succeeds")
    _check(m.ship_scientists == 0 and m.carried_scientists == 1, "scientist moves to TAKE AWAY")


func _test_standard_kit() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.carried_oxygen = 3
    m.carried_stun_guns = 2
    m.carried_ammunition = 4
    m.ship_scientists = 2
    m.carried_scientists = 1
    m.selection = SupplyModel.SEL_STANDARD_KIT
    var events := _fire_and_release(m)
    _check(events["changed"], "STANDARD KIT executes recovered consolidation")
    _check(m.ship_oxygen == 0 and m.carried_oxygen == 53, "STANDARD KIT moves consolidated oxygen to TAKE AWAY")
    _check(m.ship_stun_guns == 0 and m.carried_stun_guns == 3, "STANDARD KIT moves consolidated stun-guns to TAKE AWAY")
    _check(m.ship_ammunition == 0 and m.carried_ammunition == 54, "STANDARD KIT moves consolidated ammunition to TAKE AWAY")
    _check(m.carried_scientists == 1, "STANDARD KIT preserves existing carried scientist count")


func _test_cursor_repeat() -> void:
    var m := SupplyModel.new()
    m.reset_all()
    m.step(SupplyModel.DOWN)
    _check(m.selection == 7, "DOWN immediately advances supply cursor")
    for i in range(4):
        m.step(SupplyModel.DOWN)
    _check(m.selection == 7, "held direction waits through four repeat frames")
    m.step(SupplyModel.DOWN)
    _check(m.selection == 8, "fifth held frame repeats supply cursor movement")
