extends SceneTree

const ComputerModel = preload("res://scripts/computer_model.gd")
const SupplyModel = preload("res://scripts/supply_model.gd")

var failures := 0


func _initialize() -> void:
    _test_startup()
    _test_kard_generation_and_replacement()
    _test_bank_class_zero()
    _test_bank_credit_award()
    _test_wrong_kard_rules()
    _test_shop()
    _test_password_letter_reveal()
    _test_password_gate()
    _test_return_consolidation()

    if failures == 0:
        print("PARALLAX COMPUTER TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX COMPUTER TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _test_startup() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    _check(m.credits == 20, "startup credits match $CF2E=$14")
    _check(m.flight_endurance == 99, "startup flight endurance matches $CF03=$63")
    _check(m.kard_count() == 1, "startup carries one KARD")
    _check(m.kard_text(m.kards[0]) == "0-285", "startup KARD is recovered 0-285")
    _check("".join(m.password_display) == "-----", "password display starts cleared")


func _test_kard_generation_and_replacement() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.configure_runtime({"seed_bytes": [0, 2, 3, 4, 5]})
    var streamed := m.generate_kard()
    _check(streamed == [0, 3, 4, 5], "$E977 stream increments before reading sequential $0900 bytes")

    m.reset_all()
    var kard := m.generate_kard([0, 9, 10, 11])
    _check(kard == [1, 1, 2, 3], "random KARD generation uses recovered class table and 0-7 digits")
    m.take_generated_kard(kard)
    _check(m.kards.size() == 2 and m.kard_text(m.kards[1]) == "1-123", "second KARD fills slot B")

    m.take_generated_kard([4, 4, 4, 4])
    _check(m.kard_text(m.kards[0]) == "0-285", "full inventory preserves class-0 slot A")
    _check(m.kard_text(m.kards[1]) == "4-444", "full inventory replaces slot B when A is class 0")

    m.kards = [[2,1,1,1], [3,2,2,2]]
    m.take_generated_kard([5,3,3,3])
    _check(m.kard_text(m.kards[0]) == "5-333", "without class-0 A, full inventory replaces slot A")
    _check(m.kard_text(m.kards[1]) == "3-222", "slot B remains when slot A is replaced")


func _test_bank_class_zero() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.open_terminal(ComputerModel.TERMINAL_BANK, 0, false, false)
    m.press_action()
    _check(m.state == ComputerModel.STATE_ENTER_KARD_CODE, "single starting KARD inserts directly at bank")
    var events := m.submit_kard_code("0285")
    _check(events["kard_returned"], "correct class-0 bank KARD is returned")
    _check(m.kard_count() == 1 and m.kard_text(m.kards[0]) == "0-285", "class-0 KARD remains carried")
    _check(m.credits == 20, "class-0 bank query does not change credits")
    _check("20 CREDIT LEFT" in m.result_message, "class-0 bank path reports remaining credits")


func _test_bank_credit_award() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.kards = [[2,1,2,3]]
    m.credits = 20
    m.open_terminal(ComputerModel.TERMINAL_BANK, 0, false, false)
    m.press_action()
    var events := m.submit_kard_code("2123", [0xFA])
    _check(events["kard_consumed"], "successful class 1-5 bank KARD is consumed")
    _check(events["credits_changed"] == 50, "recovered bank random formula awards five tens for byte $FA at 20 credits")
    _check(m.credits == 70, "bank award adds to credits")
    _check(m.kards.is_empty(), "consumed bank KARD is removed")


func _test_wrong_kard_rules() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.open_terminal(ComputerModel.TERMINAL_BANK, 0, false, false)
    m.press_action()
    var events := m.submit_kard_code("0000")
    _check(events["kard_returned"], "wrong class-0 KARD number returns KARD")
    _check(m.kard_count() == 1, "wrong class-0 KARD remains carried")

    m.kards = [[3,4,5,6]]
    m.open_terminal(ComputerModel.TERMINAL_BANK, 0, false, false)
    m.press_action()
    events = m.submit_kard_code("0000")
    _check(events["kard_lost"], "wrong class 1-5 KARD number loses KARD")
    _check(m.kards.is_empty(), "lost KARD is removed")


func _test_shop() -> void:
    var m := ComputerModel.new()
    var s := SupplyModel.new()
    m.reset_all()
    s.reset_all()
    m.credits = 20
    m.flight_endurance = 80
    s.carried_oxygen = 35
    s.carried_ammunition = 40
    s.drugs = 0

    m.open_terminal(ComputerModel.TERMINAL_SHOP, 0, false, false)
    m.press_action()
    var events := m.buy_bonanza(s)
    _check(events["shop_purchased"], "20-credit BONANZA PACK purchase succeeds")
    _check(m.credits == 0, "shop subtracts exactly 20 credits")
    _check(m.flight_endurance == 99, "shop +30 endurance caps at 99")
    _check(s.carried_oxygen == 49, "shop +20 carried oxygen caps at 49")
    _check(s.carried_ammunition == 49, "shop +20 carried ammunition caps at 49")
    _check(s.drugs == 1, "shop adds one drug")
    _check(m.kard_count() == 1, "shop requires but does not consume KARD")

    m.close_terminal()
    m.credits = 19
    m.open_terminal(ComputerModel.TERMINAL_SHOP, 0, false, false)
    m.press_action()
    events = m.buy_bonanza(s)
    _check(events["shop_insufficient_credits"], "shop rejects fewer than 20 credits")


func _test_password_letter_reveal() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.kards = [[3,1,2,3]]
    m.open_terminal(ComputerModel.TERMINAL_PASSWORD, 1, false, false)
    m.press_action()
    var events := m.submit_kard_code("3123")
    _check(events["password_letter_revealed"], "valid class KARD reveals password letter")
    _check(events["revealed_letter"] == "W", "class 3 in zone 1 reveals JEWEL letter W")
    _check(m.password_display[2] == "W", "revealed letter stored in class-3 display slot")
    _check(m.kards.is_empty(), "letter-reveal KARD is consumed")

    m.kards = [[0,2,8,5]]
    m.open_terminal(ComputerModel.TERMINAL_PASSWORD, 0, false, false)
    m.press_action()
    events = m.submit_kard_code("0285")
    _check(events["kard_returned"], "class-0 KARD is returned by password reader")
    _check(m.result_message == "INVALID KARD", "class-0 password-reader result is INVALID KARD")


func _test_password_gate() -> void:
    var m := ComputerModel.new()
    m.reset_all()
    m.open_terminal(ComputerModel.TERMINAL_PASSWORD, 0, true, false)
    _check(m.result_message == "SCIENTIST\nNOT PRESENT", "special gate refuses entry without scientist")

    m.open_terminal(ComputerModel.TERMINAL_PASSWORD, 0, true, true)
    _check(m.state == ComputerModel.STATE_PASSWORD_ENTRY, "scientist-present special gate accepts password input")
    var events := m.submit_password("STACK")
    _check(events["password_correct"], "first recovered password STACK is accepted")
    _check(m.progression_index == 1, "correct password advances progression index")
    _check(m.password_solved_this_trip, "correct password sets outing success flag")
    _check("".join(m.password_display) == "-----", "correct password clears five revealed-letter slots")

    m.begin_ground_session()
    m.open_terminal(ComputerModel.TERMINAL_PASSWORD, 1, true, true)
    events = m.submit_password("WRONG")
    _check(events["password_incorrect"], "incorrect regional password is rejected")
    _check(m.progression_index == 1, "incorrect password does not advance progression")


func _test_return_consolidation() -> void:
    var s := SupplyModel.new()
    s.reset_all()
    s.ship_oxygen = 10
    s.carried_oxygen = 7
    s.ship_stun_guns = 2
    s.carried_stun_guns = 1
    s.ship_ammunition = 20
    s.carried_ammunition = 5
    s.carried_scientists = 1
    s.ship_scientists = 0
    s.scientist_drugged = true
    s.return_from_ground(true, false)
    _check(s.ship_oxygen == 17 and s.carried_oxygen == 0, "$E760 consolidates oxygen")
    _check(s.ship_stun_guns == 3 and s.carried_stun_guns == 0, "$E760 consolidates stun-guns")
    _check(s.ship_ammunition == 25 and s.carried_ammunition == 0, "$E760 consolidates ammunition")
    _check(s.ship_scientists == 1 and s.carried_scientists == 0, "unsolved type-6 scientist returns aboard")
    _check(not s.scientist_drugged, "returning scientist clears drugged flag")

    s.ship_scientists = 0
    s.carried_scientists = 1
    s.scientist_drugged = true
    s.return_from_ground(true, true)
    _check(s.ship_scientists == 0 and s.carried_scientists == 0, "password-solved scientist is not returned aboard")
