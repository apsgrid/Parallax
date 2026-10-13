class_name ParallaxFlightModel
extends RefCounted

const GroundModel = preload("res://scripts/ground_model.gd")
const SupplyModel = preload("res://scripts/supply_model.gd")
const InteriorModel = preload("res://scripts/interior_model.gd")
const ComputerModel = preload("res://scripts/computer_model.gd")
const EncounterModel = preload("res://scripts/encounter_model.gd")

const GROUND_PHASE_NONE := 0
const GROUND_PHASE_SUPPLY := 1
const GROUND_PHASE_OUTSIDE := 2
const GROUND_PHASE_INTERIOR := 3

const INITIAL_VIEW_ORIGIN_TILE := Vector2i(10, 30)

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

# Recovered mode-transition state:
# $F4 != 0 routes the next frame through $E000 ground mode.
# $F3 is cleared by $E000 and restored to 1 on return to flight.
# $E049 guards the one-time ground initialization block.
var ground_transition_flag := false
var flight_raster_mode := true
var ground_initialized := false

# Ground-mode player displacement from the stored craft screen position.
# $EB5B accepts the normal return-to-ship path only inside -7..+7.
var ground_player_offset := Vector2i.ZERO
var ground_entry_world := Vector2i.ZERO
var ground_phase := GROUND_PHASE_NONE
var ground_model := GroundModel.new()
var supply_model := SupplyModel.new()
var interior_model := InteriorModel.new()
var computer_model := ComputerModel.new()
var encounter_model := EncounterModel.new()

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
    ground_transition_flag = false
    flight_raster_mode = true
    ground_initialized = false
    ground_player_offset = Vector2i.ZERO
    ground_entry_world = Vector2i.ZERO
    ground_phase = GROUND_PHASE_NONE
    ground_model.reset()
    supply_model.reset_all()
    interior_model.reset()
    computer_model.reset_all()
    encounter_model.reset_all()
    _input_counters = [0, 0, 0, 0]


func configure_interior_runtime(data: Dictionary) -> void:
    interior_model.configure_runtime(data)
    computer_model.configure_runtime(data)
    encounter_model.configure_runtime(data)


func toggle_landing_gear() -> void:
    landing_gear = not landing_gear


func toggle_speed_mode() -> void:
    speed_mode = 1 - speed_mode


func step(
    input_bits: int,
    fire_pressed: bool,
    safe_cells: int,
    ground_blocked_bits: int = 0,
    ground_right_contact_code: int = -1,
    fire_down: bool = false
) -> Dictionary:
    var events := {
        "laser": false,
        "ground_transition_requested": false,
        "entered_ground": false,
        "exited_ground": false,
        "ground_moved": false,
        "ground_move_delta": Vector2i.ZERO,
        "ground_scroll_delta": Vector2i.ZERO,
        "ground_special_interaction": false,
        "entered_supply": false,
        "exited_ship": false,
        "supply_changed": false,
        "supply_stay_aboard": false,
        "supply_message_code": SupplyModel.MSG_NONE,
        "entered_interior": false,
        "exited_interior": false,
        "interior_terminal_opened": false,
        "interior_terminal_kind": InteriorModel.TERMINAL_NONE,
        "interior_entry_code": -1,
        "entity_spawned": false,
        "entity_type": EncounterModel.TYPE_NONE,
        "stun_projectile_fired": false,
        "scientist_stunned": false,
        "kard_offer_opened": false,
        "kard_offer_pending": false,
        "scientist_following": false,
    }

    # The flight dispatcher tests $F4 before running any flight update.
    # Therefore the FIRE frame only sets the transition flag; $E000 runs
    # on the following 50 Hz tick.
    if ground_transition_flag:
        if not ground_initialized:
            _enter_ground_mode()
            events["entered_ground"] = true
            events["entered_supply"] = true
            return events

        if ground_phase == GROUND_PHASE_SUPPLY:
            var supply_bits := input_bits
            if fire_down:
                supply_bits |= SupplyModel.FIRE
            var supply_events: Dictionary = supply_model.step(supply_bits)
            events["supply_changed"] = supply_events["changed"]
            events["supply_message_code"] = supply_events["message_code"]

            if supply_events["stay_aboard"]:
                events["supply_stay_aboard"] = true
                _exit_ground_mode()
                events["exited_ground"] = true
                return events

            if supply_events["exit_ship"]:
                ground_phase = GROUND_PHASE_OUTSIDE
                ground_model.reset()
                ground_player_offset = Vector2i.ZERO
                if supply_model.carried_scientists > 0:
                    encounter_model.set_carried_scientist(Vector2i.ZERO)
                events["exited_ship"] = true
            return events

        if ground_phase == GROUND_PHASE_INTERIOR:
            if encounter_model.kard_offer_pending:
                events["kard_offer_pending"] = true
                return events

            var interior_events: Dictionary = interior_model.step(input_bits)
            events["ground_moved"] = interior_events["moved"]
            events["ground_move_delta"] = interior_events["move_delta"]
            events["interior_terminal_opened"] = interior_events["terminal_opened"]
            events["interior_terminal_kind"] = interior_events["terminal_kind"]

            var encounter_events: Dictionary = encounter_model.step_frame(
                interior_model.local_position,
                interior_model.facing,
                fire_down and not interior_model.terminal_open,
                computer_model.progression_index,
                supply_model,
                computer_model
            )
            events["stun_projectile_fired"] = encounter_events["projectile_fired"]
            events["scientist_stunned"] = encounter_events["scientist_stunned"]
            events["kard_offer_opened"] = encounter_events["kard_offer_opened"]
            events["scientist_following"] = encounter_events["scientist_following"]
            events["kard_offer_pending"] = encounter_model.kard_offer_pending

            # $F026 precedes $EBEB in the original local loop. If both would
            # trigger on the same frame, the KARD offer owns the modal state.
            if encounter_events["kard_offer_opened"] and interior_events["terminal_opened"]:
                interior_model.close_terminal()
                computer_model.close_terminal()
                events["interior_terminal_opened"] = false

            if interior_events["terminal_opened"] and not encounter_model.kard_offer_pending:
                computer_model.open_terminal(
                    int(interior_events["terminal_kind"]),
                    interior_model.zone_index,
                    interior_model.password_gate_active,
                    supply_model.carried_scientists > 0 or encounter_model.scientist_present()
                )
            if interior_events["terminal_closed"]:
                computer_model.close_terminal()

            if interior_events["exited"]:
                ground_phase = GROUND_PHASE_OUTSIDE
                events["exited_interior"] = true
            return events

        var ground_events: Dictionary = ground_model.step(
            input_bits,
            ground_blocked_bits,
            ground_right_contact_code
        )
        ground_player_offset = ground_model.player_offset
        events["ground_moved"] = ground_events["moved"]
        events["ground_move_delta"] = ground_events["move_delta"]
        events["ground_scroll_delta"] = ground_events["scroll_delta"]
        events["ground_special_interaction"] = ground_events["special_right_interaction"]

        if ground_events["special_right_interaction"]:
            var entry_code := int(ground_events["special_contact_code"])
            var screen_origin := GroundModel.screen_origin_tile(
                INITIAL_VIEW_ORIGIN_TILE,
                ground_entry_world + ground_model.scroll_offset
            )
            var macro_x := floori(float(screen_origin.x) / 5.0)
            var macro_y := floori(float(screen_origin.y) / 5.0)
            interior_model.enter(entry_code, macro_x, macro_y, computer_model.progression_index)
            var encounter_entry: Dictionary = encounter_model.enter_room(
                interior_model.layout,
                macro_x,
                macro_y,
                computer_model.progression_index,
                interior_model.password_gate_active,
                interior_model.local_position,
                computer_model
            )
            ground_phase = GROUND_PHASE_INTERIOR
            events["entered_interior"] = true
            events["interior_entry_code"] = entry_code
            events["entity_spawned"] = encounter_entry["entity_spawned"]
            events["entity_type"] = encounter_entry["entity_type"]
            return events

        if fire_pressed and _can_return_to_ship():
            _exit_ground_mode()
            events["exited_ground"] = true
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
                ground_transition_flag = true
                events["ground_transition_requested"] = true
        else:
            events["laser"] = true

    world_x += vx_hi
    world_y += vy_hi

    return events


func _enter_ground_mode() -> void:
    # $E000 one-time initialization: mark initialized, clear $F3, preserve
    # the flight/world anchor that the ground module later returns to.
    ground_initialized = true
    flight_raster_mode = false
    landed = true
    ground_entry_world = Vector2i(world_x, world_y)
    ground_phase = GROUND_PHASE_SUPPLY
    supply_model.begin_menu()
    computer_model.begin_ground_session()
    encounter_model.begin_ground_session()
    ground_model.reset()
    ground_player_offset = Vector2i.ZERO
    vx_hi = 0
    vy_hi = 0


func in_supply_menu() -> bool:
    return ground_transition_flag and ground_initialized and ground_phase == GROUND_PHASE_SUPPLY


func on_foot() -> bool:
    return ground_transition_flag and ground_initialized and ground_phase == GROUND_PHASE_OUTSIDE


func in_interior() -> bool:
    return ground_transition_flag and ground_initialized and ground_phase == GROUND_PHASE_INTERIOR


func close_interior_terminal() -> void:
    interior_model.close_terminal()
    computer_model.close_terminal()


func answer_kard_offer(take_kard: bool) -> Dictionary:
    return encounter_model.answer_kard_offer(
        take_kard,
        computer_model,
        supply_model.ship_scientists,
        interior_model.local_position
    )


func kard_offer_pending() -> bool:
    return encounter_model.kard_offer_pending


func _can_return_to_ship() -> bool:
    # $EB5B widens only the negative X bound when local entity type is 6.
    var min_x := -27 if encounter_model.scientist_present() else -7
    return (
        ground_player_offset.x >= min_x
        and ground_player_offset.x <= 7
        and ground_player_offset.y >= -7
        and ground_player_offset.y <= 7
    )


func _exit_ground_mode() -> void:
    # $E760 consolidates TAKE AWAY equipment before flight resumes.
    # The local type-6 scientist only exists after EXIT SHIP; a successful
    # password gate consumes that scientist instead of returning it aboard.
    var scientist_present := (
        ground_phase != GROUND_PHASE_SUPPLY
        and (supply_model.carried_scientists > 0 or encounter_model.scientist_present())
    )
    supply_model.return_from_ground(
        scientist_present,
        computer_model.password_solved_this_trip
    )
    computer_model.close_terminal()

    # $EB92-$EBD0 feeds the remaining player-to-craft delta through the
    # same scroll updater used during walking. The deltas cancel and flight
    # resumes at the original landing world position.
    world_x = ground_entry_world.x
    world_y = ground_entry_world.y
    vx_hi = 0
    vy_hi = 0

    ground_transition_flag = false
    ground_initialized = false
    flight_raster_mode = true
    ground_phase = GROUND_PHASE_NONE
    landed = false
    ground_player_offset = Vector2i.ZERO
    interior_model.reset()
    encounter_model.reset_all()


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
