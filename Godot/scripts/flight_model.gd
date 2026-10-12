class_name ParallaxFlightModel
extends RefCounted

const HEIGHT_MIN := 0x03
const HEIGHT_MAX := 0x28
const LANDING_HEIGHT := 0x15

const ACCEL_NORMAL := 0x40
const ACCEL_LANDING := 0x0C

# Recovered directly from the C64 runtime tables.
# Index is the 16-step heading at $0DBD.
const HEADING_X_MODE0 := [0, -1, -2, -2, -2, -2, -2, -1, 0, 1, 2, 2, 2, 2, 2, 1]
const HEADING_Y_MODE0 := [2, 2, 2, 1, 0, -1, -2, -2, -2, -2, -2, -1, 0, 1, 2, 2]
const HEADING_X_MODE1 := [0, -2, -3, -3, -3, -3, -3, -2, 0, 2, 3, 3, 3, 3, 3, 2]
const HEADING_Y_MODE1 := [3, 3, 3, 2, 0, -2, -3, -3, -3, -3, -3, -2, 0, 2, 3, 3]

# Debounce thresholds recovered from $0E61-$0E64.
# RIGHT, LEFT, DOWN/climb, UP/dive.
const INPUT_REPEAT := [4, 4, 1, 1]

var heading := 4
var flight_height := 0x15
var speed_mode := 0

var vx_hi := 0
var vx_frac := 0x80
var vy_hi := 0
var vy_frac := 0x80

var world_x := 0
var world_y := 0

var landing_gear := false
var landing_ready := false
var landed := false
var footprint_safe_cells := 0
var acceleration_step := ACCEL_NORMAL

var _input_counters := [0, 0, 0, 0]


func reset() -> void:
    heading = 4
    flight_height = 0x15
    speed_mode = 0
    vx_hi = 0
    vx_frac = 0x80
    vy_hi = 0
    vy_frac = 0x80
    world_x = 0
    world_y = 0
    landing_gear = false
    landing_ready = false
    landed = false
    footprint_safe_cells = 0
    acceleration_step = ACCEL_NORMAL
    _input_counters = [0, 0, 0, 0]


func toggle_landing_gear() -> void:
    landing_gear = not landing_gear


func toggle_speed_mode() -> void:
    speed_mode = 1 - speed_mode


func step(input_bits: int, fire_pressed: bool, safe_cells: int) -> Dictionary:
    var events := {
        "laser": false,
        "landed": false,
    }

    if landed:
        return events

    footprint_safe_cells = clampi(safe_cells, 0, 9)
    _process_direction_input(input_bits)

    # $0F0D converges toward the heading target using the step selected
    # by the previous frame's landing-regime decision.
    var target_x: int = int(HEADING_X_MODE1[heading] if speed_mode == 1 else HEADING_X_MODE0[heading])
    var target_y: int = int(HEADING_Y_MODE1[heading] if speed_mode == 1 else HEADING_Y_MODE0[heading])

    var x_pair := _converge_axis(vx_hi, vx_frac, target_x, acceleration_step)
    vx_hi = x_pair.x
    vx_frac = x_pair.y

    var y_pair := _converge_axis(vy_hi, vy_frac, target_y, acceleration_step)
    vy_hi = y_pair.x
    vy_frac = y_pair.y

    # $165A applies an additional $38 braking step when the craft is at
    # the landing band, gear is down, and all nine footprint cells qualify.
    landing_ready = (
        flight_height == LANDING_HEIGHT
        and landing_gear
        and footprint_safe_cells == 9
    )

    if landing_ready:
        x_pair = _brake_axis(vx_hi, vx_frac)
        vx_hi = x_pair.x
        vx_frac = x_pair.y
        y_pair = _brake_axis(vy_hi, vy_frac)
        vy_hi = y_pair.x
        vy_frac = y_pair.y
        acceleration_step = ACCEL_LANDING
    else:
        acceleration_step = ACCEL_NORMAL

    if fire_pressed:
        if landing_ready:
            if vx_hi == 0 and vy_hi == 0:
                landed = true
                events["landed"] = true
        else:
            events["laser"] = true

    if not landed:
        world_x += vx_hi
        world_y += vy_hi

    return events


func _process_direction_input(input_bits: int) -> void:
    for i in range(4):
        var bit := 1 << i
        if (input_bits & bit) != 0:
            _input_counters[i] += 1
            if _input_counters[i] >= INPUT_REPEAT[i]:
                _input_counters[i] = 0
                _apply_direction_action(i)
        else:
            _input_counters[i] = 0


func _apply_direction_action(index: int) -> void:
    match index:
        0: # RIGHT
            heading = (heading + 1) & 0x0F
        1: # LEFT
            heading = (heading - 1) & 0x0F
        2: # DOWN = climb
            flight_height = mini(flight_height + 1, HEIGHT_MAX)
        3: # UP = dive
            flight_height = maxi(flight_height - 1, HEIGHT_MIN)


func _converge_axis(hi: int, frac: int, target: int, step_amount: int) -> Vector2i:
    if hi == target:
        return Vector2i(hi, frac)

    if hi < target:
        frac += step_amount
        if frac >= 256:
            frac -= 256
            hi += 1
    else:
        frac -= step_amount
        if frac < 0:
            frac += 256
            hi -= 1

    return Vector2i(hi, frac)


func _brake_axis(hi: int, frac: int) -> Vector2i:
    const BRAKE_STEP := 0x38

    if hi < 0:
        frac += BRAKE_STEP
        if frac >= 256:
            frac -= 256
            hi += 1
    elif hi > 0:
        frac -= BRAKE_STEP
        if frac < 0:
            frac += 256
            hi -= 1
    else:
        frac = 0x80

    return Vector2i(hi, frac)


func target_velocity() -> Vector2i:
    if speed_mode == 1:
        return Vector2i(HEADING_X_MODE1[heading], HEADING_Y_MODE1[heading])
    return Vector2i(HEADING_X_MODE0[heading], HEADING_Y_MODE0[heading])
