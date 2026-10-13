class_name ParallaxEncounterModel
extends RefCounted

const GroundModel = preload("res://scripts/ground_model.gd")

const TYPE_NONE := 0
const TYPE_ROAMING_SCIENTIST := 4
const TYPE_STUNNED_SCIENTIST := 5
const TYPE_ACCOMPANYING_SCIENTIST := 6

const DIR_RIGHT := 0
const DIR_LEFT := 1
const DIR_DOWN := 2
const DIR_UP := 3

const MOVE_X := [1, -1, 0, 0]
const MOVE_Y := [0, 0, 1, -1]
const PROJECTILE_X := [4, -4, 0, 0]
const PROJECTILE_Y := [0, 0, 4, -4]
const SIMPLE_ENTITY_POINTERS := [0x41, 0x40, 0x43, 0x42]
const SCIENTIST_FRAME_CODES := [
    0x56, 0x58, 0x57, 0x58,
    0x5A, 0x59, 0x5B, 0x59,
    0x54, 0x53, 0x55, 0x53,
    0x50, 0x52, 0x51, 0x52,
]
const PROJECTILE_POINTERS := [0x46, 0x47, 0x45, 0x44]

# $E9E7 is intentionally read with a possible index 7; byte $E9EE is 1,
# so the effective eight-entry table is 1,3,4,4,4,4,4,1.
const ENTITY_TYPE_TABLE := [1, 3, 4, 4, 4, 4, 4, 1]

var runtime_data: Dictionary = {}

var entity_type := TYPE_NONE
var entity_position := Vector2i.ZERO
var entity_direction := DIR_RIGHT
var wander_counter := 0
var animation_tick := 0
var animation_phase := 0
var spawn_enabled := true

var kard_offer_available := true
var kard_offer_pending := false
var offered_kard: Array = []

var projectile_active := false
var projectile_position := Vector2i.ZERO
var projectile_direction := DIR_RIGHT
var projectile_impact := false
var projectile_impact_subtick := 0
var projectile_impact_frame := 0

var room_layout: Array = []
var room_macro := Vector2i.ZERO
var room_special_gate := false


func configure_runtime(data: Dictionary) -> void:
    runtime_data = data


func reset_all() -> void:
    entity_type = TYPE_NONE
    entity_position = Vector2i.ZERO
    entity_direction = DIR_RIGHT
    wander_counter = 0
    animation_tick = 0
    animation_phase = 0
    spawn_enabled = true
    kard_offer_available = true
    kard_offer_pending = false
    offered_kard.clear()
    _clear_projectile()
    room_layout.clear()
    room_macro = Vector2i.ZERO
    room_special_gate = false


func begin_ground_session() -> void:
    entity_type = TYPE_NONE
    entity_position = Vector2i.ZERO
    entity_direction = DIR_RIGHT
    wander_counter = 0
    animation_tick = 0
    animation_phase = 0
    spawn_enabled = true
    kard_offer_available = true
    kard_offer_pending = false
    offered_kard.clear()
    _clear_projectile()
    room_layout.clear()
    room_macro = Vector2i.ZERO
    room_special_gate = false


func set_carried_scientist(player_position: Vector2i = Vector2i.ZERO) -> void:
    entity_type = TYPE_ACCOMPANYING_SCIENTIST
    entity_position = player_position + Vector2i(16, 0)


func enter_room(
    layout: Array,
    macro_x: int,
    macro_y: int,
    progression_index: int,
    special_gate: bool,
    player_position: Vector2i,
    random_source
) -> Dictionary:
    room_layout.clear()
    for row in layout:
        room_layout.append(row.duplicate())
    room_macro = Vector2i(macro_x, macro_y)
    room_special_gate = special_gate

    var events := {
        "entity_spawned": false,
        "entity_type": entity_type,
    }

    if entity_type == TYPE_ACCOMPANYING_SCIENTIST:
        # $E48C clears $F060 for a carried/following scientist, preventing
        # another KARD offer from the same scientist.
        kard_offer_available = false
        entity_position = player_position + Vector2i(16, 0)
        return events

    # $E981 suppresses ordinary spawning in the special password-gate room.
    if special_gate:
        entity_position = Vector2i.ZERO
        return events

    if not spawn_enabled:
        return events

    if _stun_zone_index(macro_y) != progression_index:
        entity_position = Vector2i.ZERO
        return events

    # $E999 repeatedly chooses X=128..191 and Y=70..133 until the entity's
    # centre character is walkable.
    var found := false
    for _attempt in range(256):
        var x := (int(random_source.next_random_byte()) & 0x3F) + 0x80
        var y := (int(random_source.next_random_byte()) & 0x3F) + 0x46
        if _entity_center_passable(Vector2i(x, y)):
            entity_position = Vector2i(x, y)
            found = true
            break

    if not found:
        entity_position = Vector2i.ZERO
        return events

    var selector := _runtime_byte(0x1000 + macro_y * 2 + macro_x) & 0x07
    entity_type = int(ENTITY_TYPE_TABLE[selector])
    entity_direction = int(random_source.next_random_byte()) & 0x03
    wander_counter = 0
    events["entity_spawned"] = true
    events["entity_type"] = entity_type
    return events


func step_frame(
    player_position: Vector2i,
    player_facing: int,
    fire_down: bool,
    progression_index: int,
    supply_model,
    random_source
) -> Dictionary:
    var events := {
        "projectile_fired": false,
        "projectile_blocked": false,
        "entity_hit": false,
        "scientist_stunned": false,
        "entity_removed": false,
        "kard_offer_opened": false,
        "scientist_following": false,
    }

    if kard_offer_pending:
        if entity_type == TYPE_ACCOMPANYING_SCIENTIST:
            entity_position = player_position + Vector2i(16, 0)
        return events

    _step_projectile(
        player_position,
        player_facing,
        fire_down,
        progression_index,
        supply_model,
        events
    )
    _step_entity(player_position, random_source)

    if entity_type == TYPE_STUNNED_SCIENTIST and _within_offer_range(player_position, entity_position):
        if kard_offer_available:
            offered_kard = random_source.generate_kard()
            kard_offer_available = false
            kard_offer_pending = true
            events["kard_offer_opened"] = true
        elif int(supply_model.ship_scientists) == 0:
            entity_type = TYPE_ACCOMPANYING_SCIENTIST
            entity_position = player_position + Vector2i(16, 0)
            events["scientist_following"] = true

    return events


func answer_kard_offer(take_kard: bool, computer_model, ship_scientists: int, player_position: Vector2i) -> Dictionary:
    var events := {
        "kard_taken": false,
        "kard_declined": false,
        "scientist_following": false,
    }
    if not kard_offer_pending:
        return events

    if take_kard:
        computer_model.take_generated_kard(offered_kard)
        events["kard_taken"] = true
    else:
        events["kard_declined"] = true

    kard_offer_pending = false
    offered_kard.clear()

    # $F055-$F05C promotes the stunned scientist after F061 returns,
    # regardless of Y/N, but only when there is no scientist already aboard.
    if ship_scientists == 0:
        entity_type = TYPE_ACCOMPANYING_SCIENTIST
        entity_position = player_position + Vector2i(16, 0)
        events["scientist_following"] = true

    return events


func kard_offer_text(computer_model) -> String:
    if not kard_offer_pending or offered_kard.size() != 4:
        return ""
    return "KARD  %s\n\nTAKE ?\n\nY / N" % computer_model.kard_text(offered_kard)


func scientist_present() -> bool:
    return entity_type == TYPE_ACCOMPANYING_SCIENTIST


func entity_sprite_pointer(player_frame_code: int, password_solved: bool = false) -> int:
    if entity_type == TYPE_NONE:
        return -1
    if entity_type == TYPE_ROAMING_SCIENTIST:
        var index := (entity_direction & 0x03) * 4 + (animation_phase & 0x03)
        return (int(SCIENTIST_FRAME_CODES[index]) + 0x55) & 0xFF
    if entity_type == TYPE_STUNNED_SCIENTIST:
        return 0x55
    if entity_type == TYPE_ACCOMPANYING_SCIENTIST:
        return (player_frame_code + (0x7D if password_solved else 0x55)) & 0xFF
    return int(SIMPLE_ENTITY_POINTERS[entity_direction & 0x03])


func projectile_sprite_pointer() -> int:
    if not projectile_active:
        return -1
    if projectile_impact:
        return 0x9D + clampi(projectile_impact_frame, 0, 7)
    return int(PROJECTILE_POINTERS[projectile_direction & 0x03])


func set_test_entity(type_value: int, position: Vector2i, direction: int = DIR_RIGHT) -> void:
    entity_type = type_value
    entity_position = position
    entity_direction = direction & 0x03


func _step_projectile(
    player_position: Vector2i,
    player_facing: int,
    fire_down: bool,
    progression_index: int,
    supply_model,
    events: Dictionary
) -> void:
    if projectile_impact:
        projectile_impact_subtick += 1
        if projectile_impact_subtick >= 2:
            projectile_impact_subtick = 0
            projectile_impact_frame += 1
            if projectile_impact_frame >= 8:
                _clear_projectile()
        return

    if not projectile_active:
        if not fire_down:
            return
        if int(supply_model.carried_stun_guns) <= 0:
            return
        if int(supply_model.carried_ammunition) <= 0:
            return
        if _stun_zone_index(room_macro.y) != progression_index:
            return

        supply_model.carried_ammunition -= 1
        projectile_active = true
        projectile_position = player_position
        projectile_direction = clampi(player_facing - 1, 0, 3)
        events["projectile_fired"] = true

    # $EE41-$EE53 tests the character one step ahead before moving.
    if not _projectile_path_passable(projectile_position, projectile_direction):
        _begin_projectile_impact()
        events["projectile_blocked"] = true
        return

    projectile_position += Vector2i(
        int(PROJECTILE_X[projectile_direction]),
        int(PROJECTILE_Y[projectile_direction])
    )

    if entity_position.x == 0:
        return

    var delta := projectile_position - entity_position
    if delta.x < -6 or delta.x > 5 or delta.y < -6 or delta.y > 5:
        return

    _begin_projectile_impact()
    spawn_enabled = false
    events["entity_hit"] = true

    if entity_type == TYPE_ROAMING_SCIENTIST or entity_type == TYPE_ACCOMPANYING_SCIENTIST:
        entity_type = TYPE_STUNNED_SCIENTIST
        events["scientist_stunned"] = true
    else:
        entity_type = TYPE_NONE
        entity_position = Vector2i.ZERO
        events["entity_removed"] = true


func _step_entity(player_position: Vector2i, random_source) -> void:
    if entity_type == TYPE_NONE or entity_position.x == 0:
        return

    if entity_type == TYPE_ACCOMPANYING_SCIENTIST:
        entity_position = player_position + Vector2i(16, 0)
        return

    if entity_type != TYPE_STUNNED_SCIENTIST:
        var original_direction := entity_direction
        var moved := false
        var attempts := 5
        while attempts > 0:
            if _entity_direction_passable(entity_position, entity_direction):
                var speed := 2 if entity_type == 2 else 1
                entity_position += Vector2i(
                    int(MOVE_X[entity_direction]) * speed,
                    int(MOVE_Y[entity_direction]) * speed
                )
                moved = true
                break
            entity_direction = int(random_source.next_random_byte()) & 0x03
            attempts -= 1
        if not moved:
            entity_direction = original_direction

    if entity_type >= TYPE_ROAMING_SCIENTIST:
        animation_tick += 1
        if animation_tick >= 4:
            animation_tick = 0
            animation_phase = (animation_phase + 1) & 0x03

    # $EA88 consumes one shared random byte every rendered entity frame.
    var counter_add := int(random_source.next_random_byte()) & 0x07
    var next_counter := wander_counter + counter_add
    if next_counter >= 0x82:
        wander_counter = 0
        entity_direction = int(random_source.next_random_byte()) & 0x03
    else:
        wander_counter = next_counter


func _entity_center_passable(position: Vector2i) -> bool:
    var c := _center_cell(position)
    return GroundModel.is_passable_tile(_tile_code(c.x, c.y))


func _entity_direction_passable(position: Vector2i, direction: int) -> bool:
    var c := _center_cell(position)
    match direction:
        DIR_RIGHT:
            c.x += 1
        DIR_LEFT:
            c.x -= 1
        DIR_DOWN:
            c.y += 1
        DIR_UP:
            c.y -= 1
    return GroundModel.is_passable_tile(_tile_code(c.x, c.y))


func _projectile_path_passable(position: Vector2i, direction: int) -> bool:
    return _entity_direction_passable(position, direction)


func _center_cell(position: Vector2i) -> Vector2i:
    return Vector2i(
        floori(float(position.x - 0x0C) / 8.0),
        floori(float(position.y - 0x2D) / 8.0) + 1
    )


func _tile_code(x: int, y: int) -> int:
    if y < 0 or y >= room_layout.size():
        return 0x20
    var row: Array = room_layout[y]
    if x < 0 or x >= row.size():
        return 0x20
    return int(row[x])


func _within_offer_range(player: Vector2i, entity: Vector2i) -> bool:
    var delta := player - entity
    return delta.x >= -9 and delta.x <= 8 and delta.y >= -6 and delta.y <= 5


func _stun_zone_index(macro_y: int) -> int:
    # $E833 computes floor(($0708 + 1) / 18).
    return floori(float(macro_y + 1) / 18.0)


func _runtime_byte(address: int) -> int:
    var seed_base := int(runtime_data.get("seed_base", 0x0900))
    var seed: Array = runtime_data.get("seed_bytes", [])
    var index := address - seed_base
    if index < 0 or index >= seed.size():
        return 0
    return int(seed[index]) & 0xFF


func _begin_projectile_impact() -> void:
    projectile_active = true
    projectile_impact = true
    projectile_impact_subtick = 0
    projectile_impact_frame = 0


func _clear_projectile() -> void:
    projectile_active = false
    projectile_position = Vector2i.ZERO
    projectile_direction = DIR_RIGHT
    projectile_impact = false
    projectile_impact_subtick = 0
    projectile_impact_frame = 0
