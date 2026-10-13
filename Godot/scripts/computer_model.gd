class_name ParallaxComputerModel
extends RefCounted

const TERMINAL_NONE := 0
const TERMINAL_BANK := 1
const TERMINAL_SHOP := 2
const TERMINAL_PASSWORD := 3

const STATE_CLOSED := 0
const STATE_INSERT := 1
const STATE_SELECT_KARD := 2
const STATE_ENTER_KARD_CODE := 3
const STATE_SHOP_OFFER := 4
const STATE_PASSWORD_ENTRY := 5
const STATE_RESULT := 6

const PASSWORDS := ["STACK", "JEWEL", "PARCH", "SALON", "GLOBE"]
const KARD_CLASS_TABLE := [1,0,2,0,3,0,4,0,5,0,1,0,2,0,3,0]

var credits := 20
# $CF03 is explicitly labelled FUEL in the original $1CB8 status string.
# Keep the established internal name for compatibility with existing callers.
var flight_endurance := 99
var kards: Array = [[0, 2, 8, 5]]
var password_display := ["-", "-", "-", "-", "-"]
var progression_index := 0
var password_solved_this_trip := false

var terminal_kind := TERMINAL_NONE
var state := STATE_CLOSED
var special_password_gate := false
var scientist_present := false
var current_zone := 0
var selected_kard_index := -1
var active_kard: Array = []
var entered_text := ""
var result_message := ""

var seed_bytes: Array = []
var _random_cursor := 0


func configure_runtime(data: Dictionary) -> void:
    seed_bytes = data.get("seed_bytes", []).duplicate()


func reset_all() -> void:
    credits = 20
    flight_endurance = 99
    kards = [[0, 2, 8, 5]]
    password_display = ["-", "-", "-", "-", "-"]
    progression_index = 0
    password_solved_this_trip = false
    close_terminal()
    _random_cursor = 0


func begin_ground_session() -> void:
    password_solved_this_trip = false


func close_terminal() -> void:
    terminal_kind = TERMINAL_NONE
    state = STATE_CLOSED
    special_password_gate = false
    scientist_present = false
    current_zone = 0
    selected_kard_index = -1
    active_kard.clear()
    entered_text = ""
    result_message = ""


func open_terminal(kind: int, zone: int, is_special_gate: bool, has_scientist: bool) -> void:
    terminal_kind = kind
    current_zone = clampi(zone, 0, 4)
    special_password_gate = is_special_gate
    scientist_present = has_scientist
    selected_kard_index = -1
    active_kard.clear()
    entered_text = ""
    result_message = ""

    if kind == TERMINAL_PASSWORD and is_special_gate:
        if not has_scientist:
            state = STATE_RESULT
            result_message = "SCIENTIST\nNOT PRESENT"
        else:
            state = STATE_PASSWORD_ENTRY
        return

    if kind == TERMINAL_SHOP:
        state = STATE_INSERT
        return

    state = STATE_INSERT


func kard_count() -> int:
    return kards.size()


func kard_text(card: Array) -> String:
    if card.size() != 4:
        return "?-???"
    return "%d-%d%d%d" % [int(card[0]), int(card[1]), int(card[2]), int(card[3])]


func starting_kard_text() -> String:
    return kard_text([0, 2, 8, 5])


func generate_kard(random_values: Array = []) -> Array:
    var r0 := _take_random(random_values, 0)
    var kard_class := int(KARD_CLASS_TABLE[(r0 >> 1) & 0x0F])
    return [
        kard_class,
        _take_random(random_values, 1) & 0x07,
        _take_random(random_values, 2) & 0x07,
        _take_random(random_values, 3) & 0x07,
    ]


func take_generated_kard(card: Array) -> void:
    var new_card := card.duplicate()
    if kards.size() < 2:
        kards.append(new_card)
        return

    # $F0D9-$F0E3 preserves a class-0 card in slot A when replacing
    # from a full two-KARD inventory; otherwise slot A is replaced.
    if int(kards[0][0]) == 0:
        kards[1] = new_card
    else:
        kards[0] = new_card


func press_action(supply_model = null) -> Dictionary:
    var events := _empty_events()
    if state == STATE_CLOSED:
        return events

    if state == STATE_RESULT:
        events["close_terminal"] = true
        return events

    if state == STATE_INSERT:
        if kards.is_empty():
            state = STATE_RESULT
            result_message = "YOU DO NOT HAVE A KARD\nTO INSERT!!"
            return events

        if terminal_kind == TERMINAL_SHOP:
            state = STATE_SHOP_OFFER
            return events

        if kards.size() == 1:
            _take_kard_for_auth(0)
            state = STATE_ENTER_KARD_CODE
        else:
            state = STATE_SELECT_KARD
        return events

    if state == STATE_ENTER_KARD_CODE and entered_text.length() == 4:
        return submit_kard_code(entered_text)

    if state == STATE_PASSWORD_ENTRY and entered_text.length() == 5:
        return submit_password(entered_text)

    if state == STATE_SHOP_OFFER:
        return buy_bonanza(supply_model)

    return events


func select_kard(index: int) -> Dictionary:
    var events := _empty_events()
    if state != STATE_SELECT_KARD:
        return events
    if index < 0 or index >= kards.size():
        return events
    _take_kard_for_auth(index)
    state = STATE_ENTER_KARD_CODE
    return events


func input_character(character: String) -> Dictionary:
    var events := _empty_events()
    if character.is_empty():
        return events
    var ch := character.substr(0, 1).to_upper()

    if state == STATE_ENTER_KARD_CODE:
        if ch < "0" or ch > "9":
            return events
        if entered_text.length() < 4:
            entered_text += ch
        if entered_text.length() == 4:
            return submit_kard_code(entered_text)
        return events

    if state == STATE_PASSWORD_ENTRY:
        if ch < "A" or ch > "Z":
            return events
        if entered_text.length() < 5:
            entered_text += ch
        if entered_text.length() == 5:
            return submit_password(entered_text)
    return events


func backspace() -> void:
    if entered_text.length() > 0:
        entered_text = entered_text.substr(0, entered_text.length() - 1)


func submit_kard_code(code: String, random_values: Array = []) -> Dictionary:
    var events := _empty_events()
    if state != STATE_ENTER_KARD_CODE or active_kard.size() != 4:
        return events

    var expected := "%d%d%d%d" % [
        int(active_kard[0]), int(active_kard[1]), int(active_kard[2]), int(active_kard[3])
    ]
    if code != expected:
        var class_value := int(active_kard[0])
        if class_value == 0:
            _return_active_kard()
            result_message = "INCORRECT\nTAKE KARD"
            events["kard_returned"] = true
        else:
            active_kard.clear()
            result_message = "INCORRECT\nKARD LOST!"
            events["kard_lost"] = true
        entered_text = ""
        state = STATE_RESULT
        return events

    var klass := int(active_kard[0])
    if terminal_kind == TERMINAL_BANK:
        if klass == 0:
            _return_active_kard()
            result_message = "YOU HAVE\n%02d CREDIT LEFT" % credits
            events["kard_returned"] = true
        else:
            var award := _bank_award(random_values)
            active_kard.clear()
            result_message = "%02d CREDITS\nTAKEN" % award
            events["credits_changed"] = award
            events["kard_consumed"] = true
        entered_text = ""
        state = STATE_RESULT
        return events

    if terminal_kind == TERMINAL_PASSWORD:
        if klass == 0:
            _return_active_kard()
            result_message = "INVALID KARD"
            events["kard_returned"] = true
        else:
            var password: String = String(PASSWORDS[current_zone])
            var letter: String = password.substr(klass - 1, 1)
            password_display[klass - 1] = letter
            result_message = "CLASS %d PASS\nLETTER NUMBER %d IS\n%s" % [klass, klass, letter]
            active_kard.clear()
            events["password_letter_revealed"] = true
            events["kard_consumed"] = true
            events["revealed_class"] = klass
            events["revealed_letter"] = letter
        entered_text = ""
        state = STATE_RESULT
        return events

    _return_active_kard()
    state = STATE_RESULT
    return events


func submit_password(value: String) -> Dictionary:
    var events := _empty_events()
    if state != STATE_PASSWORD_ENTRY:
        return events

    var candidate := value.to_upper()
    if progression_index < 0 or progression_index >= PASSWORDS.size():
        state = STATE_RESULT
        result_message = "SYSTEM OFF"
        return events

    if candidate == PASSWORDS[progression_index]:
        progression_index += 1
        password_solved_this_trip = true
        password_display = ["-", "-", "-", "-", "-"]
        result_message = "SYSTEM OFF"
        events["password_correct"] = true
        events["progression_advanced"] = true
        events["progression_index"] = progression_index
    else:
        result_message = "INVALID"
        events["password_incorrect"] = true

    entered_text = ""
    state = STATE_RESULT
    return events


func buy_bonanza(supply_model) -> Dictionary:
    var events := _empty_events()
    if state != STATE_SHOP_OFFER:
        return events
    if kards.is_empty():
        state = STATE_RESULT
        result_message = "YOU DO NOT HAVE A KARD\nTO INSERT!!"
        return events
    if credits < 20:
        state = STATE_RESULT
        result_message = "YOU CAN NOT\nAFFORD IT!"
        events["shop_insufficient_credits"] = true
        return events
    if supply_model == null:
        return events

    credits -= 20
    flight_endurance = mini(flight_endurance + 30, 99)
    supply_model.carried_oxygen = mini(supply_model.carried_oxygen + 20, 49)
    supply_model.carried_ammunition = mini(supply_model.carried_ammunition + 20, 49)
    supply_model.drugs += 1

    state = STATE_RESULT
    result_message = "BONANZA PACK\nPURCHASED"
    events["shop_purchased"] = true
    events["credits_changed"] = -20
    return events


func screen_text() -> String:
    match state:
        STATE_CLOSED:
            return ""
        STATE_INSERT:
            var title := _terminal_title()
            return "%s\n\nPLEASE INSERT\nYOUR KARD\n\nZ / ENTER: INSERT" % title
        STATE_SELECT_KARD:
            var parts := ["SELECT KARD"]
            for i in range(kards.size()):
                var label := "A" if i == 0 else "B"
                parts.append("%s. %s" % [label, kard_text(kards[i])])
            parts.append("")
            parts.append("A/B: SELECT")
            return "\n".join(parts)
        STATE_ENTER_KARD_CODE:
            var visible := entered_text
            while visible.length() < 4:
                visible += "*"
            return "KARD TAKEN\n\nENTER KARD NUMBER\n%s\n\nDigits 0-9" % visible
        STATE_SHOP_OFFER:
            return "BONANZA PACK\n\nONLY 20 CR.\n\nCREDITS: %d\n\nB / Z: BUY" % credits
        STATE_PASSWORD_ENTRY:
            var visible := entered_text
            while visible.length() < 5:
                visible += "*"
            return "PASS : %s\n\nTYPE FIVE LETTERS" % visible
        STATE_RESULT:
            return result_message + "\n\nZ / ENTER: RETURN"
    return ""


func _terminal_title() -> String:
    match terminal_kind:
        TERMINAL_BANK:
            return "WELCOME TO..\nCOMPUTABANK"
        TERMINAL_SHOP:
            return "WELCOME TO..\nCOMPUTASHOP"
        TERMINAL_PASSWORD:
            return "THIS IS....\nTHE BIG ONE"
    return ""


func _take_kard_for_auth(index: int) -> void:
    active_kard = kards[index].duplicate()
    if kards.size() == 1:
        kards.clear()
    elif index == 0:
        kards[0] = kards[1]
        kards.remove_at(1)
    else:
        kards.remove_at(1)
    selected_kard_index = index
    entered_text = ""


func _return_active_kard() -> void:
    if active_kard.is_empty():
        return
    kards.append(active_kard.duplicate())
    active_kard.clear()


func _bank_award(random_values: Array = []) -> int:
    var tens := credits / 10
    var cursor := 0
    while true:
        var value := _take_random(random_values, cursor)
        cursor += 1
        var candidate := ((~value) & 0x07) + tens
        if candidate >= 10:
            continue
        var delta_tens := candidate - tens
        var award := delta_tens * 10
        credits += award
        return award
    return 0


func _take_random(values: Array, index: int) -> int:
    if index < values.size():
        return int(values[index]) & 0xFF
    return _next_random()


func next_random_byte() -> int:
    return _next_random()


func _next_random() -> int:
    if seed_bytes.is_empty():
        _random_cursor = (_random_cursor + 1) & 0xFF
        return _random_cursor
    _random_cursor = (_random_cursor + 1) & 0xFF
    return int(seed_bytes[_random_cursor % seed_bytes.size()]) & 0xFF


func _empty_events() -> Dictionary:
    return {
        "close_terminal": false,
        "kard_returned": false,
        "kard_lost": false,
        "kard_consumed": false,
        "credits_changed": 0,
        "password_letter_revealed": false,
        "revealed_class": 0,
        "revealed_letter": "",
        "password_correct": false,
        "password_incorrect": false,
        "progression_advanced": false,
        "progression_index": progression_index,
        "shop_purchased": false,
        "shop_insufficient_credits": false,
    }
