class_name ParallaxGroundModel
extends RefCounted

const RIGHT := 0x01
const LEFT := 0x02
const DOWN := 0x04
const UP := 0x08

# $E280 collision sampler uses pointer $797B/$7D7B. Relative to the active
# $7800/$7C00 40-column screen this is centered on screen cell (19,10).
const COLLISION_UP_CELL := Vector2i(19, 9)
const COLLISION_LEFT_CELL := Vector2i(18, 10)
const COLLISION_RIGHT_CELL := Vector2i(20, 10)
const COLLISION_DOWN_CELL := Vector2i(19, 11)
const PLAYER_SCREEN_CELL := Vector2i(19, 10)

# $E2FC accepts only these character codes as walkable.
const PASSABLE_TILE_CODES := [
    0xC0, 0xDE, 0xDF, 0x1F, 0x4D,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x1B, 0x2A,
]

# Idle frame values from $E04A-$E04D, indexed by facing 1..4.
const IDLE_FRAMES := [0x58, 0x59, 0x53, 0x52]

# Four-frame movement cycles from $E04E-$E05D.
const MOVE_FRAMES := [
    [0x56, 0x58, 0x57, 0x58],
    [0x5A, 0x59, 0x5B, 0x59],
    [0x54, 0x53, 0x55, 0x53],
    [0x50, 0x52, 0x51, 0x52],
]

var player_offset := Vector2i.ZERO
# Exact inverse one-pixel values eventually copied by $E250 into $0709/$070B.
# This shares the same signed scroll-unit convention as flight world_x/world_y.
var scroll_offset := Vector2i.ZERO
var facing := 1
var animation_tick := 0
var animation_phase := 0
var frame_code := IDLE_FRAMES[0]


func reset() -> void:
    player_offset = Vector2i.ZERO
    scroll_offset = Vector2i.ZERO
    facing = 1
    animation_tick = 0
    animation_phase = 0
    frame_code = IDLE_FRAMES[0]


func step(input_bits: int, blocked_bits: int, right_contact_code: int = -1) -> Dictionary:
    var events := {
        "moved": false,
        "move_delta": Vector2i.ZERO,
        "scroll_delta": Vector2i.ZERO,
        "special_right_interaction": false,
        "special_contact_code": -1,
    }

    # $E15B checks directions in strict priority order. A blocked direction
    # falls through so another simultaneously-held direction may still move.
    var candidates := [
        [RIGHT, 1, Vector2i(1, 0), Vector2i(-1, 0)],
        [LEFT, 2, Vector2i(-1, 0), Vector2i(1, 0)],
        [DOWN, 3, Vector2i(0, 1), Vector2i(0, -1)],
        [UP, 4, Vector2i(0, -1), Vector2i(0, 1)],
    ]

    for candidate in candidates:
        var bit: int = candidate[0]
        if (input_bits & bit) == 0:
            continue

        facing = int(candidate[1])
        if (blocked_bits & bit) != 0:
            continue

        var move_delta: Vector2i = candidate[2]
        var scroll_delta: Vector2i = candidate[3]
        player_offset += move_delta
        scroll_offset += scroll_delta
        events["moved"] = true
        events["move_delta"] = move_delta
        events["scroll_delta"] = scroll_delta
        _advance_walk_animation()
        return events

    # $E1C2-$E1DE checks the RIGHT contact code only after no movement was
    # accepted. Codes $C1-$C3 branch to the special handler at $E444.
    if (input_bits & RIGHT) != 0 and right_contact_code >= 0xC1 and right_contact_code < 0xC4:
        events["special_right_interaction"] = true
        events["special_contact_code"] = right_contact_code

    frame_code = IDLE_FRAMES[facing - 1]
    return events


func _advance_walk_animation() -> void:
    animation_tick += 1
    if animation_tick == 4:
        animation_tick = 0
        animation_phase = (animation_phase + 1) & 0x03
    frame_code = MOVE_FRAMES[facing - 1][animation_phase]


static func screen_origin_tile(initial_origin: Vector2i, total_scroll_units: Vector2i) -> Vector2i:
    # $C00E/$C03F normalize fine scroll in 8-pixel units. Positive scroll
    # wraps by decrementing the tile origin; negative scroll from zero wraps
    # to fine=7 and increments it. floor() reproduces both directions.
    return initial_origin + Vector2i(
        -floori(float(total_scroll_units.x) / 8.0),
        -floori(float(total_scroll_units.y) / 8.0)
    )


static func is_passable_tile(code: int) -> bool:
    return code in PASSABLE_TILE_CODES
