class_name ParallaxInteriorModel
extends RefCounted

const GroundModel = preload("res://scripts/ground_model.gd")

const RIGHT := GroundModel.RIGHT
const LEFT := GroundModel.LEFT
const DOWN := GroundModel.DOWN
const UP := GroundModel.UP

const TERMINAL_NONE := 0
const TERMINAL_BANK := 1
const TERMINAL_SHOP := 2
const TERMINAL_PASSWORD := 3

const ENTRY_X := 0x3E
const ENTRY_Y_TOP := 0x62
const ENTRY_Y_BOTTOM := 0x8A

const BANK_CODES := {
    RIGHT: 0xD0,
    LEFT: 0xCE,
    DOWN: 0xCD,
    UP: 0xCF,
}
const SHOP_CODES := {
    RIGHT: 0xD2,
    LEFT: 0xD1,
}
const PASSWORD_CODES := {
    RIGHT: 0xD5,
    LEFT: 0xD3,
    DOWN: 0xD6,
    UP: 0xD4,
}

var runtime_data: Dictionary = {}
var layout: Array = []
var active := false
var entry_code := -1
var local_position := Vector2i.ZERO
var facing := 1
var animation_tick := 0
var animation_phase := 0
var frame_code := GroundModel.IDLE_FRAMES[0]
var terminal_open := false
var terminal_kind := TERMINAL_NONE
var terminal_contact_bit := 0
var region_index := 0
var zone_index := 0
var world_macro := Vector2i.ZERO
var password_gate_active := false

var _seed_pointer := 0
var _seed_cursor := 0


func configure_runtime(data: Dictionary) -> void:
    runtime_data = data


func reset() -> void:
    layout.clear()
    active = false
    entry_code = -1
    local_position = Vector2i.ZERO
    facing = 1
    animation_tick = 0
    animation_phase = 0
    frame_code = GroundModel.IDLE_FRAMES[0]
    terminal_open = false
    terminal_kind = TERMINAL_NONE
    terminal_contact_bit = 0
    region_index = 0
    zone_index = 0
    world_macro = Vector2i.ZERO
    password_gate_active = false
    _seed_pointer = 0
    _seed_cursor = 0


func enter(contact_code: int, macro_x: int, macro_y: int, current_region: int = 0) -> void:
    entry_code = contact_code
    region_index = current_region
    zone_index = clampi(floori(float(macro_y) / 18.0), 0, 4)
    world_macro = Vector2i(macro_x, macro_y)
    password_gate_active = false
    layout = _build_layout(macro_x, macro_y, current_region)
    _set_entry_position(contact_code)


func enter_with_layout(contact_code: int, tiles: Array) -> void:
    entry_code = contact_code
    zone_index = 0
    world_macro = Vector2i.ZERO
    password_gate_active = false
    layout.clear()
    for row in tiles:
        layout.append(row.duplicate())
    _set_entry_position(contact_code)


func _set_entry_position(contact_code: int) -> void:
    active = true
    terminal_open = false
    terminal_kind = TERMINAL_NONE
    terminal_contact_bit = 0
    facing = 1
    animation_tick = 0
    animation_phase = 0
    frame_code = GroundModel.IDLE_FRAMES[0]
    local_position = Vector2i(
        ENTRY_X,
        ENTRY_Y_BOTTOM if contact_code >= 0xC3 else ENTRY_Y_TOP
    )


func close_terminal() -> void:
    terminal_open = false
    terminal_kind = TERMINAL_NONE
    terminal_contact_bit = 0


func step(input_bits: int) -> Dictionary:
    var events := {
        "moved": false,
        "move_delta": Vector2i.ZERO,
        "exited": false,
        "terminal_opened": false,
        "terminal_closed": false,
        "terminal_kind": TERMINAL_NONE,
    }

    if not active:
        return events
    if terminal_open:
        # $EC45 normalizes directions, ignores zero input, and unwinds the
        # terminal interaction when the current direction no longer equals
        # the contact direction stored in $EC2F.
        var directional := input_bits & 0x0F
        if directional != 0 and directional != terminal_contact_bit:
            close_terminal()
            events["terminal_closed"] = true
        return events

    var samples := collision_samples()

    # $E4DA tests the LEFT sample every interior frame. $20 marks the
    # local-area exit boundary; the outdoor state/display is then restored.
    if int(samples["left"]) == 0x20:
        active = false
        events["exited"] = true
        return events

    var blocked := 0
    if not GroundModel.is_passable_tile(int(samples["right"])):
        blocked |= RIGHT
    if not GroundModel.is_passable_tile(int(samples["left"])):
        blocked |= LEFT
    if not GroundModel.is_passable_tile(int(samples["down"])):
        blocked |= DOWN
    if not GroundModel.is_passable_tile(int(samples["up"])):
        blocked |= UP

    var candidates := [
        [RIGHT, 1, Vector2i(1, 0)],
        [LEFT, 2, Vector2i(-1, 0)],
        [DOWN, 3, Vector2i(0, 1)],
        [UP, 4, Vector2i(0, -1)],
    ]
    for candidate in candidates:
        var bit: int = candidate[0]
        if (input_bits & bit) == 0:
            continue
        facing = int(candidate[1])
        if (blocked & bit) != 0:
            continue
        var delta: Vector2i = candidate[2]
        local_position += delta
        events["moved"] = true
        events["move_delta"] = delta
        _advance_walk_animation()
        break

    # $EBEB checks every held blocked direction after movement selection.
    # The three direction-specific character families dispatch to
    # COMPUTABANK, COMPUTASHOP, and the KARD/password terminal.
    for bit in [RIGHT, LEFT, DOWN, UP]:
        if (input_bits & bit) == 0 or (blocked & bit) == 0:
            continue
        var code: int = _contact_code_for_bit(samples, bit)
        var kind := terminal_kind_for_contact(bit, code)
        if kind != TERMINAL_NONE:
            terminal_open = true
            terminal_kind = kind
            terminal_contact_bit = bit
            events["terminal_opened"] = true
            events["terminal_kind"] = kind
            return events

    if not events["moved"]:
        frame_code = GroundModel.IDLE_FRAMES[facing - 1]
    return events


func center_cell() -> Vector2i:
    # $E5E6: X -> (X-$0C)/8; Y -> (Y-$2D)/8.
    # $E295 treats that pointer as the UP sample, so the player centre is
    # one character row below it.
    return Vector2i(
        floori(float(local_position.x - 0x0C) / 8.0),
        floori(float(local_position.y - 0x2D) / 8.0) + 1
    )


func collision_samples() -> Dictionary:
    var c := center_cell()
    return {
        "up": tile_code(c.x, c.y - 1),
        "left": tile_code(c.x - 1, c.y),
        "right": tile_code(c.x + 1, c.y),
        "down": tile_code(c.x, c.y + 1),
    }


func tile_code(x: int, y: int) -> int:
    if y < 0 or y >= layout.size():
        return 0x20
    var row: Array = layout[y]
    if x < 0 or x >= row.size():
        return 0x20
    return int(row[x])


func _contact_code_for_bit(samples: Dictionary, bit: int) -> int:
    match bit:
        RIGHT:
            return int(samples["right"])
        LEFT:
            return int(samples["left"])
        DOWN:
            return int(samples["down"])
        UP:
            return int(samples["up"])
    return -1


func terminal_text() -> String:
    match terminal_kind:
        TERMINAL_BANK:
            return "WELCOME TO..\nCOMPUTABANK\n\nPLEASE INSERT\nYOUR KARD"
        TERMINAL_SHOP:
            return "WELCOME TO..\nCOMPUTASHOP\n\nPRESS THE BUTTON"
        TERMINAL_PASSWORD:
            return "THIS IS....\nTHE BIG ONE\n\nINSERT YOUR KARD"
    return ""


static func terminal_name(kind: int) -> String:
    match kind:
        TERMINAL_BANK:
            return "COMPUTABANK"
        TERMINAL_SHOP:
            return "COMPUTASHOP"
        TERMINAL_PASSWORD:
            return "KARD/PASSWORD TERMINAL"
    return "INTERIOR"


static func terminal_kind_for_contact(bit: int, code: int) -> int:
    if BANK_CODES.has(bit) and int(BANK_CODES[bit]) == code:
        return TERMINAL_BANK
    if SHOP_CODES.has(bit) and int(SHOP_CODES[bit]) == code:
        return TERMINAL_SHOP
    if PASSWORD_CODES.has(bit) and int(PASSWORD_CODES[bit]) == code:
        return TERMINAL_PASSWORD
    return TERMINAL_NONE


func _advance_walk_animation() -> void:
    animation_tick += 1
    if animation_tick == 4:
        animation_tick = 0
        animation_phase = (animation_phase + 1) & 0x03
    frame_code = GroundModel.MOVE_FRAMES[facing - 1][animation_phase]


func _build_layout(macro_x: int, macro_y: int, current_region: int) -> Array:
    var result: Array = []
    var base: Array = runtime_data.get("base_tiles", [])
    for row in base:
        result.append(row.duplicate())

    if result.is_empty():
        return result

    _seed_pointer = (((macro_x >> 2) + 0x09) << 8) | ((macro_y * 2) & 0xFF)
    _seed_cursor = 0
    var flags := _read_seed() & 0x07

    var anchors: Array = runtime_data.get("special_coords", [])
    if current_region >= 0 and current_region < anchors.size():
        var pair: Array = anchors[current_region]
        if pair.size() >= 2:
            var dx := int(pair[0]) - macro_x
            var dy := int(pair[1]) - macro_y
            if dx >= -1 and dx <= 1 and dy >= -1 and dy <= 1:
                password_gate_active = true
                flags = 0x04

    if (flags & 0x01) != 0:
        _place_pattern(result, "bank")
    if (flags & 0x02) != 0:
        _place_pattern(result, "shop")
    if (flags & 0x04) != 0:
        _place_pattern(result, "password")
    return result


func _read_seed() -> int:
    _seed_cursor = (_seed_cursor + 1) & 0xFF
    var seed: Array = runtime_data.get("seed_bytes", [])
    var seed_base := int(runtime_data.get("seed_base", 0x0900))
    var address := _seed_pointer + _seed_cursor
    var index := address - seed_base
    if index < 0 or index >= seed.size():
        return 0
    return int(seed[index])


func _place_pattern(target: Array, name: String) -> bool:
    var patterns: Dictionary = runtime_data.get("patterns", {})
    if not patterns.has(name):
        return false
    var spec: Dictionary = patterns[name]
    var rows := int(spec.get("rows", 0))
    var cols := int(spec.get("cols", 0))
    var data: Array = spec.get("data", [])

    for _attempt in range(255):
        var row0 := _read_seed() & 0x0F
        var col0 := (_read_seed() & 0x0F) + 6
        if not _rect_is_floor(target, col0, row0, cols, rows):
            continue
        var i := 0
        for yy in range(rows):
            for xx in range(cols):
                target[row0 + yy][col0 + xx] = int(data[i])
                i += 1
        return true
    return false


static func _rect_is_floor(target: Array, x0: int, y0: int, cols: int, rows: int) -> bool:
    if y0 < 0 or y0 + rows > target.size():
        return false
    for yy in range(rows):
        var row: Array = target[y0 + yy]
        if x0 < 0 or x0 + cols > row.size():
            return false
        for xx in range(cols):
            if int(row[x0 + xx]) != 0x1F:
                return false
    return true
