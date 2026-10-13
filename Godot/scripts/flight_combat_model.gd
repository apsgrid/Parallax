class_name ParallaxFlightCombatModel
extends RefCounted

# Original flight laser state at $0779-$077C / $116B.
const PROJECTILE_START_X := 0x54
const PROJECTILE_START_Y := 0x75
const PROJECTILE_START_STATE := 0x1E

# Raw signed lookup values recovered from $0E20 and $0DF0.
# The 6502 subtracts these table values from projectile X/Y.
const PROJECTILE_X_TABLE := [0, -1, -2, -3, -4, -3, -2, -1, 0, 1, 2, 3, 4, 3, 2, 1]
const PROJECTILE_Y_TABLE := [6, 6, 4, 3, 0, -3, -4, -6, -6, -6, -4, -3, 0, 3, 4, 6]

# $0C91 checks the centre/cross cells first, then corners.
# Values are zero-based indices into the 3x3 row-major sample.
const COLLISION_PRIORITY := [4, 1, 3, 5, 7, 0, 2, 8, 6]

# Collision-class response records at $1349-$135C:
# [explosion cadence, render/effect selector, sound/destructible selector, state low bits].
const COLLISION_RESPONSES := {
    1: [2, 5, 11, 0x00],
    2: [2, 6, 1, 0x21],
    3: [2, 6, 1, 0x21],
    4: [2, 2, 11, 0x00],
    5: [2, 3, 11, 0x00],
}

# $FC3B-$FC42 height bands indexed by (object_state & 3) * 2.
# Lower bound is inclusive; upper bound is exclusive.
const OBJECT_HEIGHT_BANDS := [
    Vector2i(0x07, 0x60),
    Vector2i(0x14, 0x23),
    Vector2i(0x00, 0x14),
    Vector2i(0x1C, 0x32),
]

# Direct destructible-laser writeback: $147F's screen-pattern loop exits with
# X=9, so $1A57 compares only $1AB4+9 ($F7) and writes $1AB9+9 ($00).
# Other adjacent pairs are consumed by the separate $1AC1 maintenance pass.
const DIRECT_DESTRUCTION_MASTER_ID := 0xF7
const DIRECT_DESTRUCTION_REPLACEMENT := 0x00

# Three persistent $F835+ records are processed through the $F825 scratch
# record one slot at a time. Only the first twelve bytes are live in $F874.
const OBJECT_SLOT_COUNT := 3
const AUX_PROJECTILE_SLOT_COUNT := 2
const AUX_PROJECTILE_ACTIVE_SPRITES := [0x56,0x57,0x58,0x59,0x58,0x57]
const AUX_PROJECTILE_EXPLOSION_START := 0xBE
const AUX_PROJECTILE_EXPLOSION_END := 0xC7
const CRAFT_COLLISION_EVENT_CODES := [2, 2, 3, 2]
const OBJECT_CARDINAL_X := [0, 1, 0, -1, 0]
const OBJECT_CARDINAL_Y := [-1, 0, 1, 0, 0]
const OBJECT_DIAGONAL_X := [0, 1, 2, 1, 0, -1, -2, -1]
const OBJECT_DIAGONAL_Y := [-2, -1, 0, 1, 2, 1, 0, -1]
const OBJECT_CRAFT_X_COMP := [-4, -3, -3, -2, -2, -1, -1, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4]

const OBJECT_STATE_SPRITES := {
    1: [0xC9,0xCA,0xCB,0xCC,0xC9,0xCA,0xCB,0xCC],
    2: [0xB9,0xBA,0xBB,0xBC,0xB9,0xBA,0xBB,0xBC],
    3: [0x4C,0x4D,0x4E,0x4F,0x4C,0x4D,0x4E,0x4F],
    5: [0x48,0x49,0x4A,0x4B,0x48,0x49,0x4A,0x4B],
    6: [0x50,0x51,0x52,0x53,0x54,0x53,0x52,0x51],
    7: [0x4C,0x4D,0x4E,0x4F,0x4C,0x4D,0x4E,0x4F],
}

# $FDC9 is five 8-byte region rows indexed by (region*8)|object_state.
const OBJECT_COLOR_TABLE := [
    0x00,0x02,0x05,0x08,0x00,0x0D,0x04,0x03,
    0x00,0x0A,0x08,0x09,0x00,0x0E,0x02,0x04,
    0x00,0x09,0x0A,0x0D,0x00,0x02,0x05,0x0E,
    0x00,0x05,0x0E,0x09,0x00,0x08,0x0A,0x0D,
    0x00,0x0E,0x04,0x03,0x00,0x0C,0x09,0x0A,
]

var projectile_x := 0
var projectile_y := 0
var projectile_state := 0
var projectile_height := 0
var projectile_heading := 0

# $CF00/$CF01/$CF02 are the recovered DAMAGE panel fields:
# L.GEAR / ENGINE / LAZERS. $2022 adds 2..9 damage from queued impact events;
# $2058 decays all three by one every $5A status ticks.
const DAMAGE_RECOVERY_FRAMES := 0x5A
const ENGINE_DISABLE_THRESHOLD := 0x28
const LAZER_DISABLE_THRESHOLD := 0x07

var landing_gear_damage := 0
var engine_damage := 0
var laser_damage := 0
var damage_recovery_counter := 0
var damage_random_bytes: Array = []
var damage_random_cursor := 0

# $CF26 is the persistent F7 shield toggle. No consumer exists in the
# recovered impact/damage path, so it is deliberately status-only.
var shields_on := false

# Dynamic collision band starts at $94/$93 and is animated elsewhere.
var dynamic_upper_threshold := 0x94
var dynamic_lower_threshold := 0x93

var explosion_counter := 0
var explosion_cadence := 0
var impact_variant := 0

var object_slots: Array = []
var aux_projectiles: Array = []
var aux_animation_subtick := 0
var aux_animation_index := 0
var object_random_bytes: Array = []
var object_random_cursor := 0
var object_attack_random_cursor := 0


func configure_runtime(data: Dictionary) -> void:
    object_random_bytes = data.get("seed_bytes", []).duplicate()
    damage_random_bytes = data.get("damage_random_bytes", []).duplicate()
    _ensure_object_slots()
    _ensure_aux_projectiles()


func reset() -> void:
    projectile_x = 0
    projectile_y = 0
    projectile_state = 0
    projectile_height = 0
    projectile_heading = 0
    landing_gear_damage = 0
    engine_damage = 0
    laser_damage = 0
    damage_recovery_counter = 0
    damage_random_cursor = 0
    shields_on = false
    dynamic_upper_threshold = 0x94
    dynamic_lower_threshold = 0x93
    explosion_counter = 0
    explosion_cadence = 0
    impact_variant = 0
    object_random_cursor = 0
    object_attack_random_cursor = 0
    aux_animation_subtick = 0
    aux_animation_index = 0
    object_slots.clear()
    for _i in range(OBJECT_SLOT_COUNT):
        object_slots.append(_new_object_slot())
    aux_projectiles.clear()
    for _i in range(AUX_PROJECTILE_SLOT_COUNT):
        aux_projectiles.append(_new_aux_projectile_slot())


func projectile_active() -> bool:
    return projectile_state != 0


func projectile_exploding() -> bool:
    return (projectile_state & 0x80) != 0


func can_fire() -> bool:
    return laser_damage < LAZER_DISABLE_THRESHOLD and not projectile_active()


func engine_disabled() -> bool:
    return engine_damage >= ENGINE_DISABLE_THRESHOLD


func toggle_shields() -> bool:
    shields_on = not shields_on
    return shields_on


func apply_craft_impact(event_code: int) -> Dictionary:
    var events := {
        "applied": false,
        "event_code": event_code,
        "damage_type": "",
        "damage_amount": 0,
        "old_damage": 0,
        "new_damage": 0,
        "first_damage": false,
    }
    if event_code < 1 or event_code > 3:
        return events

    # $207A increments its self-modifying cursor, reads $C000,Y, then $2022
    # masks to three bits and adds two. This produces an exact 2..9 increment.
    var amount := (_next_damage_random() & 0x07) + 2
    var old_damage := 0
    match event_code:
        1:
            old_damage = landing_gear_damage
            landing_gear_damage = (landing_gear_damage + amount) & 0xFF
            events["damage_type"] = "L.GEAR"
            events["new_damage"] = landing_gear_damage
        2:
            old_damage = engine_damage
            engine_damage = (engine_damage + amount) & 0xFF
            events["damage_type"] = "ENGINE"
            events["new_damage"] = engine_damage
        3:
            old_damage = laser_damage
            laser_damage = (laser_damage + amount) & 0xFF
            events["damage_type"] = "LAZERS"
            events["new_damage"] = laser_damage

    events["applied"] = true
    events["damage_amount"] = amount
    events["old_damage"] = old_damage
    events["first_damage"] = old_damage == 0
    return events


func advance_damage_recovery() -> Dictionary:
    var events := {
        "recovered": false,
        "landing_gear_damage": landing_gear_damage,
        "engine_damage": engine_damage,
        "laser_damage": laser_damage,
    }
    damage_recovery_counter = (damage_recovery_counter + 1) & 0xFF
    if damage_recovery_counter != DAMAGE_RECOVERY_FRAMES:
        return events

    damage_recovery_counter = 0
    if landing_gear_damage > 0:
        landing_gear_damage -= 1
        events["recovered"] = true
    if engine_damage > 0:
        engine_damage -= 1
        events["recovered"] = true
    if laser_damage > 0:
        laser_damage -= 1
        events["recovered"] = true

    events["landing_gear_damage"] = landing_gear_damage
    events["engine_damage"] = engine_damage
    events["laser_damage"] = laser_damage
    return events


func fire(heading: int, height: int) -> bool:
    if not can_fire():
        return false
    projectile_x = PROJECTILE_START_X
    projectile_y = PROJECTILE_START_Y
    projectile_state = PROJECTILE_START_STATE
    projectile_height = height & 0xFF
    projectile_heading = heading & 0x0F
    explosion_counter = 0
    explosion_cadence = 0
    impact_variant = 0
    return true


func advance() -> Dictionary:
    var events := {
        "moved": false,
        "needs_collision": false,
        "expired": false,
        "explosion_advanced": false,
    }
    if not projectile_active():
        return events

    if projectile_exploding():
        explosion_counter += 1
        if explosion_counter == explosion_cadence:
            explosion_counter = 0
            projectile_state = (projectile_state + 1) & 0xFF
            events["explosion_advanced"] = true

        if projectile_state == 0xAB or projectile_state == 0x87:
            _clear_projectile()
            events["expired"] = true
        return events

    # $116D subtracts the signed lookup-table byte modulo 256.
    projectile_x = (projectile_x - int(PROJECTILE_X_TABLE[projectile_heading])) & 0xFF
    projectile_y = (projectile_y - int(PROJECTILE_Y_TABLE[projectile_heading])) & 0xFF
    events["moved"] = true

    # Exact original screen bounds: Y $32..$B1, X $0C..$AB.
    if projectile_y < 0x32 or projectile_y >= 0xB2 or projectile_x < 0x0C or projectile_x >= 0xAC:
        _clear_projectile()
        events["expired"] = true
        return events

    events["needs_collision"] = true
    return events


func resolve_terrain(samples: Array) -> Dictionary:
    var events := {
        "collision": false,
        "collision_class": 0,
        "sample_index": -1,
        "destructible": false,
        "score_award": 0,
        "impact_variant": 0,
    }
    if not projectile_active() or projectile_exploding():
        return events

    var result := classify_terrain(samples, projectile_height)
    var collision_class := int(result["collision_class"])
    if collision_class == 0:
        return events

    var response: Array = COLLISION_RESPONSES[collision_class]
    explosion_cadence = int(response[0])
    impact_variant = int(response[1])
    explosion_counter = 0
    projectile_state = 0x80 | int(response[3])

    events["collision"] = true
    events["collision_class"] = collision_class
    events["sample_index"] = int(result["sample_index"])
    events["impact_variant"] = impact_variant

    if int(response[2]) == 1:
        events["destructible"] = true
        events["score_award"] = 15
    return events


func classify_terrain(samples: Array, height: int) -> Dictionary:
    var result := {"collision_class": 0, "sample_index": -1}
    if samples.size() < 9:
        return result

    for sample_index in COLLISION_PRIORITY:
        var code := int(samples[sample_index]) & 0xFF
        var collision_class := _classify_code(code, height)
        if collision_class != 0:
            result["collision_class"] = collision_class
            result["sample_index"] = sample_index
            return result
    return result


func destruction_replacement(master_id: int) -> int:
    if (master_id & 0xFF) == DIRECT_DESTRUCTION_MASTER_ID:
        return DIRECT_DESTRUCTION_REPLACEMENT
    return -1


func set_dynamic_band_counter(counter: int) -> void:
    # $2420-$2433 derives both moving thresholds from floor($23C9 / 8).
    var expansion := (counter & 0xFF) >> 3
    dynamic_upper_threshold = (0x94 + expansion) & 0xFF
    dynamic_lower_threshold = (0x93 - expansion) & 0xFF


func resolve_moving_object_hit(object_state: int, object_x: int, object_y: int, craft_height: int) -> Dictionary:
    var events := {
        "hit": false,
        "score_award": 0,
        "object_destroyed": false,
        "object_category": object_state & 0x03,
    }
    if not projectile_active() or projectile_exploding():
        return events

    var category := object_state & 0x03
    var band: Vector2i = OBJECT_HEIGHT_BANDS[category]
    # $FC10 gates the hit with current craft height $0778, not the projectile's
    # firing-height snapshot $077C.
    if craft_height < band.x or craft_height >= band.y:
        return events

    # $FC1E-$FC3A accepts unsigned deltas 00..09 or F5..FF, i.e.
    # signed projectile-object deltas -11..+9 inclusive on both axes.
    var dx := (projectile_x - object_x) & 0xFF
    var dy := (projectile_y - object_y) & 0xFF
    if not _object_delta_hits(dx) or not _object_delta_hits(dy):
        return events

    _clear_projectile()
    events["hit"] = true
    events["object_destroyed"] = true
    # $FC48-$FC4C writes the full object state * 2 to pending score.
    events["score_award"] = (object_state & 0xFF) * 2
    return events




func object_slot(index: int) -> Dictionary:
    _ensure_object_slots()
    if index < 0 or index >= object_slots.size():
        return {}
    return object_slots[index]


func step_objects(
    craft_vx: int,
    craft_vy: int,
    craft_height: int,
    macro_y: int,
    terrain_sampler: Callable,
    suppress_craft_collision: bool = false
) -> Dictionary:
    _ensure_object_slots()
    _ensure_aux_projectiles()
    var events := {
        "spawned": [],
        "despawned": [],
        "laser_hits": [],
        "craft_collisions": [],
        "object_overlap_destroys": [],
        "aux_fire_requests": [],
        "aux_craft_collisions": [],
        "aux_despawned": [],
        "score_award": 0,
    }

    for slot_index in range(OBJECT_SLOT_COUNT):
        var slot: Dictionary = object_slots[slot_index]

        if int(slot["state"]) == 0xFF:
            if _advance_object_explosion(slot):
                events["despawned"].append(slot_index)
            object_slots[slot_index] = slot
            continue

        if int(slot["state"]) == 0:
            if _try_spawn_object(slot, slot_index, macro_y, terrain_sampler):
                events["spawned"].append(slot_index)
            object_slots[slot_index] = slot
            continue

        _advance_object_materialization(slot)
        _move_object(slot, craft_vx, craft_vy, terrain_sampler)

        if not _object_in_bounds(slot):
            slot = _new_object_slot()
            object_slots[slot_index] = slot
            events["despawned"].append(slot_index)
            continue

        # $FACC consumes a second independent cursor over the same $0900
        # table. Low three bits == 4 attempts to allocate one of two
        # persistent hostile-projectile slots at this object's X/Y.
        if (_next_object_attack_random() & 0x07) == 0x04:
            var aux_slot := _try_spawn_aux_projectile(slot)
            if aux_slot >= 0:
                events["aux_fire_requests"].append({
                    "slot": slot_index,
                    "projectile_slot": aux_slot,
                    "x": int(slot["x"]),
                    "y": int(slot["y"]),
                    "state": int(slot["state"]),
                })

        _advance_object_animation(slot)

        var laser_hit := resolve_moving_object_hit(
            int(slot["state"]),
            int(slot["x"]),
            int(slot["y"]),
            craft_height
        )
        if bool(laser_hit["hit"]):
            events["score_award"] += int(laser_hit["score_award"])
            events["laser_hits"].append(slot_index)
            _mark_object_explosion(slot)
            object_slots[slot_index] = slot
            continue

        if not suppress_craft_collision and _object_hits_craft(slot, craft_height):
            # $FFA3 consumes the primary object RNG and queues one of
            # [2,2,3,2] in $CF15 before $FC4F destroys the object.
            var event_code := int(CRAFT_COLLISION_EVENT_CODES[_next_object_random() & 0x03])
            events["craft_collisions"].append({
                "slot": slot_index,
                "event_code": event_code,
            })
            _mark_object_explosion(slot)
            object_slots[slot_index] = slot
            continue

        if _object_overlap_count(slot, slot_index) >= 2:
            events["object_overlap_destroys"].append(slot_index)
            _mark_object_explosion(slot)

        object_slots[slot_index] = slot

    # $F8C6 tail-calls $FDF6 only after all three moving-object records have
    # been processed. The two hostile projectile slots therefore move and
    # collide after every object's $FACC opportunity for the frame.
    var aux_events := _advance_aux_projectiles(
        craft_vx,
        craft_vy,
        craft_height,
        suppress_craft_collision
    )
    events["aux_craft_collisions"] = aux_events["craft_collisions"]
    events["aux_despawned"] = aux_events["despawned"]
    return events


func object_render_state(index: int) -> Dictionary:
    _ensure_object_slots()
    if index < 0 or index >= object_slots.size():
        return {"visible": false}
    var slot: Dictionary = object_slots[index]
    var state := int(slot["state"])
    if state == 0:
        return {"visible": false}
    if state == 0xFF:
        return {
            "visible": true,
            "exploding": true,
            "x": int(slot["explosion_x"]),
            "y": int(slot["explosion_y"]),
            "explosion_frame": int(slot["direction"]),
            "sprite_pointer": -1,
            "color": int(slot["color"]),
        }
    return {
        "visible": true,
        "exploding": false,
        "x": int(slot["x"]),
        "y": int(slot["y"]),
        "sprite_pointer": _object_sprite_pointer(slot),
        "color": int(slot["color"]),
        "state": state,
        "category": state & 0x03,
    }


func aux_projectile_render_state(index: int) -> Dictionary:
    _ensure_aux_projectiles()
    if index < 0 or index >= aux_projectiles.size():
        return {"visible": false}
    var slot: Dictionary = aux_projectiles[index]
    var x := int(slot["x"])
    if x == 0:
        return {"visible": false}

    var state := int(slot["state"])
    return {
        "visible": true,
        "exploding": state == 0xFF,
        "x": x,
        "y": int(slot["y"]),
        "sprite_pointer": (
            int(slot["mode_or_pointer"])
            if state == 0xFF
            else int(AUX_PROJECTILE_ACTIVE_SPRITES[aux_animation_index])
        ),
        "state": state,
        "category": state & 0x03,
    }


func collision_top_left_screen_cell() -> Vector2i:
    # $12F0 passes X=$0779-5; $0C1B then subtracts another 6 and divides
    # by four. Y subtracts $2F and maps every eight raster pixels to a row.
    return Vector2i(
        floori(float(projectile_x - 11) / 4.0),
        floori(float(projectile_y - 0x2F) / 8.0)
    )


func master_target_screen_cell() -> Vector2i:
    # $1A57 uses the projectile coordinate itself when locating the 96x96
    # master-map cell to replace.
    return Vector2i(
        floori(float(projectile_x - 6) / 4.0),
        floori(float(projectile_y - 0x2F) / 8.0)
    )


func _classify_code(code: int, height: int) -> int:
    if code >= 0x31 and code < 0x3D:
        return 1
    if code == 0x48:
        return 2
    if code == 0x58:
        return 5

    # Animated range around $93/$94. At startup the interval is empty:
    # upper=$94, lower=$93.
    if code >= 0x94:
        if code < dynamic_upper_threshold:
            return 5
    elif code < 0x93:
        if code >= dynamic_lower_threshold:
            return 5

    if height >= 0x14:
        if code == 0x3D:
            return 3
        if code == 0x64:
            return 4
    return 0






func _ensure_object_slots() -> void:
    if object_slots.size() == OBJECT_SLOT_COUNT:
        return
    object_slots.clear()
    for _i in range(OBJECT_SLOT_COUNT):
        object_slots.append(_new_object_slot())


func _ensure_aux_projectiles() -> void:
    if aux_projectiles.size() == AUX_PROJECTILE_SLOT_COUNT:
        return
    aux_projectiles.clear()
    for _i in range(AUX_PROJECTILE_SLOT_COUNT):
        aux_projectiles.append(_new_aux_projectile_slot())


func _new_object_slot() -> Dictionary:
    return {
        "x": 0,
        "y": 0,
        "direction": 0,
        "state": 0,
        "half_neg": 0,
        "half_pos": 0,
        "unused_6": 0,
        "anim_frame": 0,
        "anim_subtick": 0,
        "spawn_phase": 0,
        "turn_timer": 0,
        "unused_11": 0,
        "color": 0,
        "explosion_x": 0,
        "explosion_y": 0,
    }


func _new_aux_projectile_slot() -> Dictionary:
    return {
        "x": 0,
        "y": 0,
        "direction": 0,
        "state": 0,
        # $FDF4/$FE83 is an attribute mask while live, then the explosion
        # sprite pointer once state becomes $FF.
        "mode_or_pointer": 0,
    }


func _try_spawn_aux_projectile(source: Dictionary) -> int:
    _ensure_aux_projectiles()
    var target_index := -1
    for i in range(AUX_PROJECTILE_SLOT_COUNT):
        if int(aux_projectiles[i]["x"]) == 0:
            target_index = i
            break
    if target_index < 0:
        # $FF58/$FF7E drops the request when both slots are occupied and,
        # importantly, does not consume the primary $FBB9 RNG cursor.
        return -1

    var state := int(source["state"]) & 0xFF
    var slot := _new_aux_projectile_slot()
    slot["x"] = int(source["x"]) & 0xFF
    slot["y"] = int(source["y"]) & 0xFF
    slot["state"] = state
    slot["direction"] = _next_object_random() & 0x07
    # Live $FDF4/$FE83 values are VIC attribute masks, not sprite pointers.
    var shift := 3 if target_index == 0 else 4
    slot["mode_or_pointer"] = (((state & 0x01) ^ 0x01) << shift) & 0xFF
    aux_projectiles[target_index] = slot
    return target_index


func _advance_aux_projectiles(
    craft_vx: int,
    craft_vy: int,
    craft_height: int,
    suppress_craft_collision: bool
) -> Dictionary:
    _ensure_aux_projectiles()
    var events := {
        "craft_collisions": [],
        "despawned": [],
    }

    craft_vx = clampi(craft_vx, -8, 8)
    for i in range(AUX_PROJECTILE_SLOT_COUNT):
        var slot: Dictionary = aux_projectiles[i]
        var state := int(slot["state"])
        if int(slot["x"]) == 0 or state == 0xFF:
            continue

        var direction := int(slot["direction"]) & 0x07
        slot["x"] = (
            int(slot["x"])
            + int(OBJECT_CRAFT_X_COMP[craft_vx + 8])
            + int(OBJECT_DIAGONAL_X[direction])
        ) & 0xFF
        slot["y"] = (
            int(slot["y"])
            + craft_vy
            + int(OBJECT_DIAGONAL_Y[direction])
        ) & 0xFF

        if not _aux_projectile_in_bounds(slot):
            aux_projectiles[i] = _new_aux_projectile_slot()
            events["despawned"].append(i)
        else:
            aux_projectiles[i] = slot

    # $FF0F-$FF3A owns one shared six-frame sprite animation. Each pointer
    # is held for four scheduler ticks: 56,57,58,59,58,57.
    aux_animation_subtick += 1
    if aux_animation_subtick == 4:
        aux_animation_subtick = 0
        aux_animation_index = (aux_animation_index + 1) % AUX_PROJECTILE_ACTIVE_SPRITES.size()

    # $F68F runs before the collision pass, so projectiles which were already
    # exploding advance here; newly colliding projectiles remain at $BE until
    # the following scheduler tick.
    for i in range(AUX_PROJECTILE_SLOT_COUNT):
        var slot: Dictionary = aux_projectiles[i]
        if int(slot["x"]) == 0 or int(slot["state"]) != 0xFF:
            continue
        if _advance_aux_projectile_explosion(slot):
            aux_projectiles[i] = _new_aux_projectile_slot()
            events["despawned"].append(i)
        else:
            aux_projectiles[i] = slot

    if suppress_craft_collision:
        return events

    for i in range(AUX_PROJECTILE_SLOT_COUNT):
        var slot: Dictionary = aux_projectiles[i]
        if int(slot["x"]) == 0 or int(slot["state"]) == 0xFF:
            continue
        if not _object_hits_craft(slot, craft_height):
            continue
        var event_code := int(CRAFT_COLLISION_EVENT_CODES[_next_object_random() & 0x03])
        events["craft_collisions"].append({
            "slot": i,
            "event_code": event_code,
        })
        _mark_aux_projectile_explosion(slot)
        aux_projectiles[i] = slot

    return events


func _aux_projectile_in_bounds(slot: Dictionary) -> bool:
    var x := int(slot["x"]) & 0xFF
    var y := int(slot["y"]) & 0xFF
    return x >= 1 and x < 200 and y >= 5 and y < 250


func _mark_aux_projectile_explosion(slot: Dictionary) -> void:
    slot["state"] = 0xFF
    slot["mode_or_pointer"] = AUX_PROJECTILE_EXPLOSION_START


func _advance_aux_projectile_explosion(slot: Dictionary) -> bool:
    slot["direction"] = (int(slot["direction"]) + 1) & 0xFF
    if (int(slot["direction"]) & 0x01) == 0:
        slot["mode_or_pointer"] = int(slot["mode_or_pointer"]) + 1
    return int(slot["mode_or_pointer"]) >= AUX_PROJECTILE_EXPLOSION_END


func _try_spawn_object(
    slot: Dictionary,
    slot_index: int,
    macro_y: int,
    terrain_sampler: Callable
) -> bool:
    if not terrain_sampler.is_valid():
        return false

    var x := (_next_object_random() & 0x3F) + 0x28
    var y := (_next_object_random() & 0x7F) + 0x32
    var samples: Array = terrain_sampler.call(x, y)
    if samples.size() < 9:
        return false

    var category := 0
    if _all_samples_equal(samples, 0x2A):
        category = 1
    elif _all_samples_void(samples):
        category = 2
    elif slot_index == 0:
        category = 3
    else:
        return false

    slot["x"] = x & 0xFF
    slot["y"] = y & 0xFF
    slot["half_neg"] = 0
    slot["half_pos"] = 0
    slot["anim_frame"] = 0
    slot["anim_subtick"] = 0

    if category == 3:
        var edge_selector := _next_object_random() & 0x04
        slot["turn_timer"] = edge_selector
        if edge_selector != 0:
            slot["y"] = 0x1E
            slot["direction"] = _next_object_random() & 0x02
            if int(slot["direction"]) == 0:
                slot["y"] = 0xB4
        else:
            slot["x"] = 0x02
            slot["direction"] = _next_object_random() & 0x02
            if int(slot["direction"]) == 0:
                slot["y"] = 0xA0
            slot["direction"] = (int(slot["direction"]) + 1) & 0x07
        slot["spawn_phase"] = 0x10
    else:
        slot["direction"] = 4
        slot["spawn_phase"] = 0
        slot["turn_timer"] = 0

    var region := _object_region_index(macro_y)
    slot["state"] = _choose_object_state(category, region)
    slot["color"] = _object_color(region, int(slot["state"]))
    return true


func _choose_object_state(category: int, region: int) -> int:
    var state := category | 0x04
    if (_next_object_random() & 0x04) == 0:
        if (region | 0x04) >= state:
            state ^= 0x04
    return state & 0xFF


func _advance_object_materialization(slot: Dictionary) -> void:
    var phase := int(slot["spawn_phase"])
    if phase == 0x10:
        return

    if phase >= 0x0F:
        slot["spawn_phase"] = (phase + 1) & 0xFF
        return

    phase += 1
    slot["spawn_phase"] = phase
    if phase == 0x0F:
        slot["direction"] = _next_object_random() & 0x03


func _move_object(slot: Dictionary, craft_vx: int, craft_vy: int, terrain_sampler: Callable) -> void:
    var category := int(slot["state"]) & 0x03
    if category == 3:
        _move_edge_object(slot)
    else:
        _move_surface_object(slot, craft_vx, craft_vy, terrain_sampler)


func _move_surface_object(
    slot: Dictionary,
    craft_vx: int,
    craft_vy: int,
    terrain_sampler: Callable
) -> void:
    craft_vx = clampi(craft_vx, -8, 8)

    if craft_vx > 0 and (craft_vx & 1) != 0:
        slot["half_pos"] = int(slot["half_pos"]) + 1
        if int(slot["half_pos"]) == 2:
            slot["half_pos"] = 0
            slot["x"] = (int(slot["x"]) + 1) & 0xFF
    elif craft_vx < 0 and (abs(craft_vx) & 1) != 0:
        slot["half_neg"] = int(slot["half_neg"]) + 1
        if int(slot["half_neg"]) == 2:
            slot["half_neg"] = 0
            slot["x"] = (int(slot["x"]) - 1) & 0xFF

    var base_x := (int(slot["x"]) + int(OBJECT_CRAFT_X_COMP[craft_vx + 8])) & 0xFF
    var base_y := (int(slot["y"]) + craft_vy) & 0xFF
    var direction := int(slot["direction"])
    var dx := 0
    var dy := 0
    if direction >= 0 and direction < OBJECT_CARDINAL_X.size():
        dx = int(OBJECT_CARDINAL_X[direction])
        dy = int(OBJECT_CARDINAL_Y[direction])

    var candidate_x := (base_x + dx) & 0xFF
    var candidate_y := (base_y + dy) & 0xFF
    var samples: Array = terrain_sampler.call(candidate_x, candidate_y) if terrain_sampler.is_valid() else []

    if _object_terrain_passable(int(slot["state"]) & 0x03, samples):
        slot["x"] = candidate_x
        slot["y"] = candidate_y
        return

    var turn := (direction + 1) & 0x03
    if (_next_object_random() & 0x01) != 0:
        turn = (turn - 2) & 0x03
    slot["direction"] = turn
    slot["x"] = base_x
    slot["y"] = base_y


func _move_edge_object(slot: Dictionary) -> void:
    var direction := int(slot["direction"]) & 0x07
    slot["x"] = (int(slot["x"]) + int(OBJECT_DIAGONAL_X[direction])) & 0xFF
    slot["y"] = (int(slot["y"]) + int(OBJECT_DIAGONAL_Y[direction])) & 0xFF

    slot["turn_timer"] = int(slot["turn_timer"]) + 1
    if int(slot["turn_timer"]) != 0x10:
        return

    slot["turn_timer"] = 0
    direction = (direction + 1) & 0x07
    if (_next_object_random() & 0x08) != 0:
        direction = (direction - 2) & 0x07
    slot["direction"] = direction


func _object_terrain_passable(category: int, samples: Array) -> bool:
    if samples.size() < 9:
        return false
    if category == 2:
        return _all_samples_void(samples)
    return _all_samples_equal(samples, 0x2A)


func _all_samples_equal(samples: Array, value: int) -> bool:
    if samples.size() < 9:
        return false
    for i in range(9):
        if (int(samples[i]) & 0xFF) != value:
            return false
    return true


func _all_samples_void(samples: Array) -> bool:
    if samples.size() < 9:
        return false
    for i in range(9):
        var value := int(samples[i]) & 0xFF
        if value < 0x0D or value >= 0x11:
            return false
    return true


func _object_in_bounds(slot: Dictionary) -> bool:
    var x := int(slot["x"]) & 0xFF
    var y := int(slot["y"]) & 0xFF
    return x >= 1 and x < 200 and y >= 5 and y < 250


func _advance_object_animation(slot: Dictionary) -> void:
    if int(slot["spawn_phase"]) < 0x10:
        return
    slot["anim_subtick"] = int(slot["anim_subtick"]) + 1
    if int(slot["anim_subtick"]) == 3:
        slot["anim_subtick"] = 0
        slot["anim_frame"] = (int(slot["anim_frame"]) + 1) & 0xFF


func _object_sprite_pointer(slot: Dictionary) -> int:
    var phase := int(slot["spawn_phase"])
    if phase < 0x10:
        return 0xB1 + (phase >> 2)

    var state := int(slot["state"])
    if not OBJECT_STATE_SPRITES.has(state):
        return -1
    var table: Array = OBJECT_STATE_SPRITES[state]
    return int(table[int(slot["anim_frame"]) & 0x07])


func _object_region_index(macro_y: int) -> int:
    return maxi(0, floori(float(macro_y) / 18.0))


func _object_color(region: int, state: int) -> int:
    var index := region * 8 + (state & 0x07)
    if index < 0 or index >= OBJECT_COLOR_TABLE.size():
        return 0
    return int(OBJECT_COLOR_TABLE[index]) & 0x0F


func _object_hits_craft(slot: Dictionary, craft_height: int) -> bool:
    var state := int(slot["state"])
    if state == 0 or state == 0xFF:
        return false
    var category := state & 0x03
    var band: Vector2i = OBJECT_HEIGHT_BANDS[category]
    if craft_height < band.x or craft_height >= band.y:
        return false
    var dx := (PROJECTILE_START_X - int(slot["x"])) & 0xFF
    var dy := (PROJECTILE_START_Y - int(slot["y"])) & 0xFF
    return _object_delta_hits(dx) and _object_delta_hits(dy)


func _object_overlap_count(slot: Dictionary, current_index: int) -> int:
    var state := int(slot["state"])
    if state == 0 or state == 0xFF:
        return 0
    var category := state & 0x03
    var count := 0

    for i in range(OBJECT_SLOT_COUNT):
        var other: Dictionary = object_slots[i]
        var other_state := int(other["state"])
        if other_state == 0xFF or (other_state & 0x03) != category:
            continue
        var dx := (int(slot["x"]) - int(other["x"])) & 0xFF
        var dy := (int(slot["y"]) - int(other["y"])) & 0xFF
        if _object_delta_hits(dx) and _object_delta_hits(dy):
            count += 1
    return count


func _mark_object_explosion(slot: Dictionary) -> void:
    slot["explosion_x"] = int(slot["x"])
    slot["explosion_y"] = int(slot["y"])
    slot["state"] = 0xFF
    slot["direction"] = 0
    slot["x"] = maxi(0, int(slot["x"]) - 0x0C) >> 2
    slot["y"] = maxi(0, int(slot["y"]) - 0x32) >> 3


func _advance_object_explosion(slot: Dictionary) -> bool:
    slot["direction"] = int(slot["direction"]) + 1
    if int(slot["direction"]) < 0x14:
        return false
    var cleared := _new_object_slot()
    for key in cleared:
        slot[key] = cleared[key]
    return true


func _next_damage_random() -> int:
    damage_random_cursor = (damage_random_cursor + 1) & 0xFF
    if damage_random_bytes.is_empty():
        return damage_random_cursor
    return int(damage_random_bytes[damage_random_cursor % damage_random_bytes.size()]) & 0xFF


func _next_object_random() -> int:
    object_random_cursor = (object_random_cursor + 1) & 0xFF
    if object_random_bytes.is_empty():
        return object_random_cursor
    return int(object_random_bytes[object_random_cursor % object_random_bytes.size()]) & 0xFF


func _next_object_attack_random() -> int:
    object_attack_random_cursor = (object_attack_random_cursor + 1) & 0xFF
    if object_random_bytes.is_empty():
        return object_attack_random_cursor
    return int(object_random_bytes[object_attack_random_cursor % object_random_bytes.size()]) & 0xFF


func _object_delta_hits(delta: int) -> bool:
    delta &= 0xFF
    return delta <= 0x09 or delta >= 0xF5


func _clear_projectile() -> void:
    projectile_x = 0
    projectile_y = 0
    projectile_state = 0
    explosion_counter = 0
    explosion_cadence = 0
    impact_variant = 0
