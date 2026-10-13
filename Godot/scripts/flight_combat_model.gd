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

var projectile_x := 0
var projectile_y := 0
var projectile_state := 0
var projectile_height := 0
var projectile_heading := 0

# $CF02 is cleared by the state-block initializer and only directly read by
# the resident laser fire handler. Preserve the gate without inventing a name.
var cf02_gate_state := 0

# Dynamic collision band starts at $94/$93 and is animated elsewhere.
var dynamic_upper_threshold := 0x94
var dynamic_lower_threshold := 0x93

var explosion_counter := 0
var explosion_cadence := 0
var impact_variant := 0


func reset() -> void:
    projectile_x = 0
    projectile_y = 0
    projectile_state = 0
    projectile_height = 0
    projectile_heading = 0
    cf02_gate_state = 0
    dynamic_upper_threshold = 0x94
    dynamic_lower_threshold = 0x93
    explosion_counter = 0
    explosion_cadence = 0
    impact_variant = 0


func projectile_active() -> bool:
    return projectile_state != 0


func projectile_exploding() -> bool:
    return (projectile_state & 0x80) != 0


func can_fire() -> bool:
    return cf02_gate_state < 7 and not projectile_active()


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
