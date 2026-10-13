class_name ParallaxEndgameModel
extends RefCounted

const STATE_PLAYING := 0
const STATE_FINAL_EFFECT_WAIT_FIRE := 1
const STATE_NAME_ENTRY := 2
const STATE_TITLE_RETURN := 3

const INPUT_DOWN := 0x04
const INPUT_UP := 0x08

const TRANSPORT_MASTER_ID := 0x77
const TRANSPORT_TRIGGER_TILE := 0x70
const TRANSPORT_BAND_STARTS := [0x00, 0x13, 0x26, 0x39, 0x4C, 0x5F]

const INITIAL_BEST_SCORE := 10
const INITIAL_BEST_NAME := "CHRIX"

const ENDING_LINES := [
    "WELL DONE CAP'N",
    "",
    "EVEN THOUGH ALL OUR BOYS WERE",
    "BLOWN TO PIECES..",
    "",
    "YOU STILL INFLICTED ENOUGH DAMAGE ON",
    "THE ENEMY TO BECOME A MEGA HERO",
]

var master_tiles: Array = []

var state := STATE_PLAYING
var score_value := 0
var high_score_value := INITIAL_BEST_SCORE
var high_score_name := INITIAL_BEST_NAME

# $17C8 is incremented before use and only its low nibble participates.
var transport_selector_counter := 0
var transport_cooldown := 0

var winning_marker := Vector2i(-1, -1)
var winning_destination_macro := Vector2i(-1, -1)

var name_codes := [1, 1, 1, 1, 1]
var name_index := 0
var _name_tick := 0
var _name_fire_ready := false


func configure_master_map(rows: Array) -> void:
    master_tiles.clear()
    for row in rows:
        if typeof(row) == TYPE_ARRAY:
            master_tiles.append(row.duplicate())


func reset_game() -> void:
    state = STATE_PLAYING
    score_value = 0
    transport_selector_counter = 0
    transport_cooldown = 0
    winning_marker = Vector2i(-1, -1)
    winning_destination_macro = Vector2i(-1, -1)
    name_codes = [1, 1, 1, 1, 1]
    name_index = 0
    _name_tick = 0
    _name_fire_ready = false


func reset_all() -> void:
    high_score_value = INITIAL_BEST_SCORE
    high_score_name = INITIAL_BEST_NAME
    reset_game()


func active() -> bool:
    return state != STATE_PLAYING


func score_text() -> String:
    return "%06d" % clampi(score_value, 0, 999999)


func high_score_text() -> String:
    return "%06d" % clampi(high_score_value, 0, 999999)


func add_score(points: int) -> void:
    if points <= 0:
        return
    score_value = mini(999999, score_value + points)


func qualifies_for_ending_overlay() -> bool:
    # $8810-$881E compares six ASCII decimal digits against the mutable
    # "TODAYS BESTEST SCORE" record. Initial record is 000010 CHRIX.
    return score_value > high_score_value


func current_viewport_band(macro_y: int) -> int:
    # $162C repeatedly subtracts $12 while the remaining value is >= $13.
    var reduced := macro_y
    var band := 0
    while reduced >= 0x13:
        reduced -= 0x12
        band += 1
    return clampi(band, 0, TRANSPORT_BAND_STARTS.size() - 1)


func tick_playing_frame() -> void:
    if state == STATE_PLAYING and transport_cooldown > 0:
        transport_cooldown -= 1


func transport_candidates(current_macro: Vector2i) -> Array:
    var result: Array = []
    if master_tiles.size() < 96:
        return result

    var band := current_viewport_band(current_macro.y)
    var start_y := int(TRANSPORT_BAND_STARTS[band])
    for y in range(start_y, mini(start_y + 20, 96)):
        var row: Array = master_tiles[y]
        for x in range(mini(row.size(), 96)):
            if int(row[x]) == TRANSPORT_MASTER_ID:
                result.append(Vector2i(x, y))
    return result


func activate_transporter(current_macro: Vector2i, progression_index: int) -> Dictionary:
    var events := {
        "transported": false,
        "marker": Vector2i(-1, -1),
        "pre_scroll_macro": current_macro,
        "destination_macro": current_macro,
        "final_gate": false,
    }
    if state != STATE_PLAYING or transport_cooldown > 0:
        return events

    var candidates := transport_candidates(current_macro)
    if candidates.is_empty():
        return events

    # $17C9 increments a persistent byte, masks it to 0..15, rejects values
    # >= destination count, and also rejects a candidate whose adjusted X
    # or pre-scroll Y equals the current macro coordinate.
    for _attempt in range(256):
        transport_selector_counter = (transport_selector_counter + 1) & 0xFF
        var selector := transport_selector_counter & 0x0F
        if selector >= candidates.size():
            continue

        var marker: Vector2i = candidates[selector]
        var pre_scroll := Vector2i(marker.x - 4, marker.y + 2)
        if pre_scroll.x == current_macro.x:
            continue
        if pre_scroll.y == current_macro.y:
            continue

        # $1714 runs twenty +8 Y-scroll frames after $1795. That is exactly
        # four macro cells upward, so markerY+2 becomes markerY-2.
        var destination := Vector2i(marker.x - 4, marker.y - 2)

        events["transported"] = true
        events["marker"] = marker
        events["pre_scroll_macro"] = pre_scroll
        events["destination_macro"] = destination

        winning_marker = marker
        winning_destination_macro = destination
        transport_cooldown = 0x32

        # $089C requires progression exactly 5, X >= $50 and Y < $50.
        if progression_index == 5 and destination.x >= 0x50 and destination.y < 0x50:
            state = STATE_FINAL_EFFECT_WAIT_FIRE
            events["final_gate"] = true
        return events

    return events


func step_ending(input_bits: int, fire_down: bool) -> Dictionary:
    var events := {
        "ending_overlay_opened": false,
        "score_disqualified": false,
        "name_changed": false,
        "name_accepted": false,
        "title_returned": false,
    }

    if state == STATE_FINAL_EFFECT_WAIT_FIRE:
        # $3FAF-$3FC6 accepts FIRE directly; there is no release debounce here.
        if fire_down:
            if qualifies_for_ending_overlay():
                state = STATE_NAME_ENTRY
                name_codes = [1, 1, 1, 1, 1]
                name_index = 0
                _name_tick = 0
                # The same FIRE can still be held on entry. $8888 forces the
                # original name entry to observe a release before accepting.
                _name_fire_ready = false
                events["ending_overlay_opened"] = true
            else:
                state = STATE_TITLE_RETURN
                events["score_disqualified"] = true
                events["title_returned"] = true
        return events

    if state != STATE_NAME_ENTRY:
        return events

    # $8EAE updates the character selector on a two-call cadence.
    _name_tick += 1
    if _name_tick >= 2:
        _name_tick = 0
        var code := int(name_codes[name_index])
        if (input_bits & INPUT_UP) != 0:
            code = (code + 1) & 0x3F
            events["name_changed"] = true
        if (input_bits & INPUT_DOWN) != 0:
            code = (code - 1) & 0x3F
            events["name_changed"] = true
        name_codes[name_index] = code

    # $8888 implements FIRE-release arming between accepted characters.
    if not fire_down:
        _name_fire_ready = true
        return events
    if not _name_fire_ready:
        return events

    _name_fire_ready = false
    events["name_accepted"] = true
    name_index += 1

    if name_index >= 5:
        high_score_value = score_value
        high_score_name = entered_name()
        state = STATE_TITLE_RETURN
        events["title_returned"] = true
    else:
        name_codes[name_index] = 1
    return events


func entered_name() -> String:
    var text := ""
    for code in name_codes:
        text += _screen_code_character(int(code))
    return text


func name_entry_display() -> String:
    var chars := []
    for i in range(5):
        if i < name_index:
            chars.append(_screen_code_character(int(name_codes[i])))
        elif i == name_index and state == STATE_NAME_ENTRY:
            chars.append(_screen_code_character(int(name_codes[i])))
        else:
            chars.append("-")
    return "".join(chars)


func ending_message() -> String:
    var lines := ENDING_LINES.duplicate()
    lines.append("")
    lines.append("ENTRE ...  %s" % name_entry_display())
    return "\n".join(lines)


func title_return_message() -> String:
    return "TODAYS BESTEST SCORE\n\n%s     %s" % [high_score_text(), high_score_name]


func _screen_code_character(code: int) -> String:
    code &= 0x3F
    if code == 0:
        return "@"
    if code >= 1 and code <= 26:
        return String.chr(0x40 + code)
    if code == 27:
        return "["
    if code == 28:
        return "£"
    if code == 29:
        return "]"
    if code == 30:
        return "↑"
    if code == 31:
        return "←"
    if code == 32:
        return " "
    return String.chr(code)
