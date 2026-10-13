class_name ParallaxSupplyModel
extends RefCounted

const RIGHT := 0x01
const LEFT := 0x02
const DOWN := 0x04
const UP := 0x08
const FIRE := 0x10

const SEL_OXYGEN := 1
const SEL_STUN_GUNS := 2
const SEL_AMMUNITION := 3
const SEL_DRUGS := 4
const SEL_SCIENTISTS := 5
const SEL_SPACER := 6
const SEL_STANDARD_KIT := 7
const SEL_EXIT_ROW := 8

const MSG_NONE := -1
const MSG_SCIENTIST_REFUSES := 0
const MSG_NEED_OXYGEN := 1
const MSG_NO_SCIENTIST := 2
const MSG_DRUGGING_SCIENTIST := 3

var selection := SEL_SPACER
var side_right := false

# Ship-side stores: $CF04/$CF07/$CF08/$CF05/$CF06.
var ship_oxygen := 50
var ship_stun_guns := 1
var ship_ammunition := 50
var drugs := 0
var ship_scientists := 0

# TAKE AWAY stores: $CF30/$CF31/$CF32/$CF33.
var carried_oxygen := 0
var carried_stun_guns := 0
var carried_ammunition := 0
var carried_scientists := 0

# $CF34: set after the Drugs action so a scientist will co-operate.
var scientist_drugged := false

var last_message_code := MSG_NONE
var _last_input := 0
var _repeat_counter := 0
var _fire_armed := false


func reset_all() -> void:
    ship_oxygen = 50
    ship_stun_guns = 1
    ship_ammunition = 50
    drugs = 0
    ship_scientists = 0
    carried_oxygen = 0
    carried_stun_guns = 0
    carried_ammunition = 0
    carried_scientists = 0
    scientist_drugged = false
    begin_menu()


func begin_menu() -> void:
    # $E3C0 starts at 6. $E3BF is clear, selecting the left column.
    selection = SEL_SPACER
    side_right = false
    last_message_code = MSG_NONE
    _last_input = 0
    _repeat_counter = 0
    _fire_armed = false


func step(input_bits: int) -> Dictionary:
    var events := {
        "changed": false,
        "stay_aboard": false,
        "exit_ship": false,
        "message_code": MSG_NONE,
    }

    var masked := input_bits & 0x1F

    # $E651 waits until FIRE is released before dispatching the selected action.
    if _fire_armed:
        if (masked & FIRE) != 0:
            return events
        _fire_armed = false
        _last_input = masked
        _repeat_counter = 0
        return _activate_selection()

    var process_input := false
    if masked != _last_input:
        _last_input = masked
        _repeat_counter = 0
        process_input = true
    else:
        _repeat_counter += 1
        if _repeat_counter >= 5:
            _repeat_counter = 0
            process_input = true

    if not process_input:
        return events

    # $E3CF applies all set direction bits in sequence.
    if (masked & RIGHT) != 0:
        side_right = true
        events["changed"] = true
    if (masked & LEFT) != 0:
        side_right = false
        events["changed"] = true
    if (masked & DOWN) != 0 and selection < SEL_EXIT_ROW:
        selection += 1
        events["changed"] = true
    if (masked & UP) != 0 and selection > SEL_OXYGEN:
        selection -= 1
        events["changed"] = true

    # Selection 6 is explicitly non-actionable in $E425-$E437.
    if (masked & FIRE) != 0 and selection != SEL_SPACER:
        _fire_armed = true

    return events


func _activate_selection() -> Dictionary:
    var events := {
        "changed": false,
        "stay_aboard": false,
        "exit_ship": false,
        "message_code": MSG_NONE,
    }
    last_message_code = MSG_NONE

    match selection:
        SEL_OXYGEN:
            events["changed"] = _transfer_oxygen()
        SEL_STUN_GUNS:
            events["changed"] = _transfer_stun_guns()
        SEL_AMMUNITION:
            events["changed"] = _transfer_ammunition()
        SEL_DRUGS:
            if drugs == 0:
                return events
            if ship_scientists == 0:
                return _message(events, MSG_NO_SCIENTIST)
            drugs = (drugs - 1) & 0xFF
            scientist_drugged = true
            events["changed"] = true
            return _message(events, MSG_DRUGGING_SCIENTIST)
        SEL_SCIENTISTS:
            if side_right and ship_scientists != 0 and not scientist_drugged:
                return _message(events, MSG_SCIENTIST_REFUSES)
            events["changed"] = _transfer_scientist()
        SEL_STANDARD_KIT:
            _apply_standard_kit()
            events["changed"] = true
        SEL_EXIT_ROW:
            if side_right:
                if carried_oxygen == 0:
                    return _message(events, MSG_NEED_OXYGEN)
                events["exit_ship"] = true
            else:
                events["stay_aboard"] = true

    return events


func _transfer_oxygen() -> bool:
    if side_right:
        if ship_oxygen == 0:
            return false
        ship_oxygen = (ship_oxygen - 1) & 0xFF
        carried_oxygen = (carried_oxygen + 1) & 0xFF
    else:
        if carried_oxygen == 0:
            return false
        carried_oxygen = (carried_oxygen - 1) & 0xFF
        ship_oxygen = (ship_oxygen + 1) & 0xFF
    return true


func _transfer_stun_guns() -> bool:
    if side_right:
        if ship_stun_guns == 0:
            return false
        ship_stun_guns = (ship_stun_guns - 1) & 0xFF
        carried_stun_guns = (carried_stun_guns + 1) & 0xFF
    else:
        if carried_stun_guns == 0:
            return false
        carried_stun_guns = (carried_stun_guns - 1) & 0xFF
        ship_stun_guns = (ship_stun_guns + 1) & 0xFF
    return true


func _transfer_ammunition() -> bool:
    if side_right:
        if ship_ammunition == 0:
            return false
        ship_ammunition = (ship_ammunition - 1) & 0xFF
        carried_ammunition = (carried_ammunition + 1) & 0xFF
    else:
        if carried_ammunition == 0:
            return false
        carried_ammunition = (carried_ammunition - 1) & 0xFF
        ship_ammunition = (ship_ammunition + 1) & 0xFF
    return true


func _transfer_scientist() -> bool:
    if side_right:
        if ship_scientists == 0:
            return false
        ship_scientists = (ship_scientists - 1) & 0xFF
        carried_scientists = (carried_scientists + 1) & 0xFF
    else:
        if carried_scientists == 0:
            return false
        carried_scientists = (carried_scientists - 1) & 0xFF
        ship_scientists = (ship_scientists + 1) & 0xFF
    return true


func _apply_standard_kit() -> void:
    # Verbatim $E6C4/$E760 behavior. It first consolidates carried equipment
    # back into ship stores (except Drugs), while preserving the carried
    # scientist count across that consolidation. It then moves all ordinary
    # ship oxygen/stun-guns/ammunition into TAKE AWAY and clears those stores.
    var saved_scientists := carried_scientists

    ship_oxygen = (ship_oxygen + carried_oxygen) & 0xFF
    carried_oxygen = 0
    ship_stun_guns = (ship_stun_guns + carried_stun_guns) & 0xFF
    carried_stun_guns = 0
    ship_ammunition = (ship_ammunition + carried_ammunition) & 0xFF
    carried_ammunition = 0
    ship_scientists = (ship_scientists + carried_scientists) & 0xFF
    carried_scientists = 0

    carried_scientists = saved_scientists

    carried_oxygen = ship_oxygen
    carried_stun_guns = ship_stun_guns
    carried_ammunition = ship_ammunition
    ship_oxygen = 0
    ship_stun_guns = 0
    ship_ammunition = 0


func _message(events: Dictionary, code: int) -> Dictionary:
    last_message_code = code
    events["message_code"] = code
    return events


static func message_text(code: int) -> String:
    match code:
        MSG_SCIENTIST_REFUSES:
            return "SCIENTIST REFUSES TO CO-OPERATE"
        MSG_NEED_OXYGEN:
            return "YOU MUST TAKE SOME OXYGEN !!!"
        MSG_NO_SCIENTIST:
            return "NO SCIENTIST"
        MSG_DRUGGING_SCIENTIST:
            return "DRUGGING SCIENTIST (HO-HO)"
    return ""
