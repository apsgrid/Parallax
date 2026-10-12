extends Node3D

const FlightModel = preload("res://scripts/flight_model.gd")

const TILE_SIZE := 2.0
const SIM_UNITS_PER_TILE := 16.0
const WORLD_SCALE := TILE_SIZE / SIM_UNITS_PER_TILE
const HEIGHT_SCALE := 0.25
const WORLD_PATH := "res://data/world_480.json"
const SPAWN_TILE := Vector2i(10, 50)
const REGION_MIN := Vector2i(0, 26)
const REGION_MAX := Vector2i(74, 94)

var model := FlightModel.new()
var world_tiles: Array = []

var ship: Node3D
var camera: Camera3D
var hud: Label
var gear_nodes := []
var footprint_markers := []
var bolts := []

var obstacle_cells := {}
var safe_material: StandardMaterial3D
var unsafe_material: StandardMaterial3D
var laser_material: StandardMaterial3D

var last_fire := false
var last_gear := false
var last_reset := false
var last_mode := false
var last_shield := false
var last_return := false

var shields_on := true
var status_message := "Recovered C64 flight model active"


func _ready() -> void:
    _load_world_data()
    _build_environment()
    _build_world()
    _build_ship()
    _build_camera()
    _build_hud()
    _update_visuals()
    _update_hud()


func _physics_process(_delta: float) -> void:
    var input_bits := 0
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
        input_bits |= 0x01
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
        input_bits |= 0x02
    if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
        input_bits |= 0x04
    if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
        input_bits |= 0x08

    var gear_now := Input.is_key_pressed(KEY_SPACE)
    if gear_now and not last_gear:
        model.toggle_landing_gear()
        status_message = "Landing gear %s" % ("DOWN" if model.landing_gear else "UP")
    last_gear = gear_now

    var mode_now := Input.is_key_pressed(KEY_TAB)
    if mode_now and not last_mode:
        model.toggle_speed_mode()
        status_message = "Recovered velocity table mode %d" % model.speed_mode
    last_mode = mode_now

    var reset_now := Input.is_key_pressed(KEY_R)
    if reset_now and not last_reset:
        model.reset()
        status_message = "Flight state reset"
    last_reset = reset_now

    var shield_now := Input.is_key_pressed(KEY_F7)
    if shield_now and not last_shield:
        shields_on = not shields_on
        status_message = "Shields %s" % ("ON" if shields_on else "OFF")
    last_shield = shield_now

    var return_now := Input.is_key_pressed(KEY_ENTER)
    if return_now and not last_return:
        status_message = "Datacard/password computer: not wired yet"
    last_return = return_now

    var fire_now := Input.is_key_pressed(KEY_Z)
    var fire_pressed := fire_now and not last_fire
    last_fire = fire_now

    var safe_cells := _sample_footprint()
    var events: Dictionary = model.step(input_bits, fire_pressed, safe_cells)

    if events["laser"]:
        _spawn_laser()
        status_message = "Laser fired"
    if events["landed"]:
        status_message = "LANDED — flight-to-ground transition reached"

    _update_bolts()
    _update_visuals()
    _sample_footprint()
    _update_hud()


func _build_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.025, 0.03, 0.04, 1.0)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.60, 0.70, 1.0)
    environment.ambient_light_energy = 0.7
    world_environment.environment = environment
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)


func _load_world_data() -> void:
    var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
    if file == null:
        push_error("Unable to load reconstructed Parallax world data")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        world_tiles = parsed.get("tiles", [])


func _build_world() -> void:
    var ground_material := _make_material(Color(0.10, 0.12, 0.11))
    var blocker_material := _make_material(Color(0.32, 0.26, 0.20))
    var structure_material := _make_material(Color(0.24, 0.34, 0.39))
    var special_material := _make_material(Color(0.38, 0.30, 0.40))
    var detail_material := _make_material(Color(0.18, 0.22, 0.20))

    safe_material = _make_material(Color(0.20, 0.72, 0.38, 0.68))
    safe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    unsafe_material = _make_material(Color(0.85, 0.25, 0.18, 0.68))
    unsafe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    var region_size := Vector2(
        float(REGION_MAX.x - REGION_MIN.x + 1) * TILE_SIZE,
        float(REGION_MAX.y - REGION_MIN.y + 1) * TILE_SIZE
    )
    plane.size = region_size
    ground.mesh = plane
    ground.position = Vector3(
        float(REGION_MIN.x + REGION_MAX.x - SPAWN_TILE.x * 2) * TILE_SIZE * 0.5,
        0.0,
        float(REGION_MIN.y + REGION_MAX.y - SPAWN_TILE.y * 2) * TILE_SIZE * 0.5
    )
    ground.material_override = ground_material
    add_child(ground)

    for wy in range(REGION_MIN.y, REGION_MAX.y + 1):
        for wx in range(REGION_MIN.x, REGION_MAX.x + 1):
            var code := _tile_code(wx, wy)
            var local_x := float(wx - SPAWN_TILE.x) * TILE_SIZE
            var local_z := float(wy - SPAWN_TILE.y) * TILE_SIZE

            if code >= 0x0D and code <= 0x10:
                _make_box(
                    self,
                    Vector3(TILE_SIZE * 0.92, 1.75, TILE_SIZE * 0.92),
                    Vector3(local_x, 0.875, local_z),
                    blocker_material
                )
            elif code >= 0x31 and code < 0x3D:
                _make_box(
                    self,
                    Vector3(TILE_SIZE * 0.78, 0.85, TILE_SIZE * 0.78),
                    Vector3(local_x, 0.425, local_z),
                    structure_material
                )
            elif code == 0x48 or code == 0x58:
                _make_box(
                    self,
                    Vector3(TILE_SIZE * 0.58, 1.15, TILE_SIZE * 0.58),
                    Vector3(local_x, 0.575, local_z),
                    special_material
                )
            elif code != 0x2A and code != 0x00:
                _make_box(
                    self,
                    Vector3(TILE_SIZE * 0.72, 0.06, TILE_SIZE * 0.72),
                    Vector3(local_x, 0.03, local_z),
                    detail_material
                )

    for i in range(9):
        var marker := _make_box(
            self,
            Vector3(TILE_SIZE * 0.86, 0.035, TILE_SIZE * 0.86),
            Vector3.ZERO,
            unsafe_material
        )
        footprint_markers.append(marker)


func _build_ship() -> void:
    ship = Node3D.new()
    ship.name = "Ship"
    add_child(ship)

    var body_material := _make_material(Color(0.72, 0.76, 0.82))
    var trim_material := _make_material(Color(0.22, 0.36, 0.48))
    var gear_material := _make_material(Color(0.10, 0.11, 0.12))

    _make_box(ship, Vector3(0.82, 0.30, 1.75), Vector3(0.0, 0.0, 0.0), body_material)
    _make_box(ship, Vector3(2.35, 0.12, 0.62), Vector3(0.0, -0.03, 0.05), trim_material)
    _make_box(ship, Vector3(0.42, 0.20, 0.42), Vector3(0.0, 0.03, 1.03), body_material)
    _make_box(ship, Vector3(1.05, 0.16, 0.34), Vector3(0.0, 0.03, -0.82), trim_material)

    for x in [-0.36, 0.36]:
        var leg := _make_box(
            ship,
            Vector3(0.10, 0.48, 0.10),
            Vector3(x, -0.36, 0.18),
            gear_material
        )
        gear_nodes.append(leg)

    laser_material = _make_material(Color(1.0, 0.35, 0.12))
    laser_material.emission_enabled = true
    laser_material.emission = Color(1.0, 0.16, 0.04)
    laser_material.emission_energy_multiplier = 4.0


func _build_camera() -> void:
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 24.0
    camera.current = true
    add_child(camera)


func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    var panel := PanelContainer.new()
    panel.position = Vector2(16, 16)
    panel.custom_minimum_size = Vector2(520, 390)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.015, 0.02, 0.025, 0.84)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.30, 0.48, 0.55, 0.9)
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    panel.add_theme_stylebox_override("panel", style)
    canvas.add_child(panel)

    hud = Label.new()
    hud.custom_minimum_size = Vector2(500, 370)
    hud.add_theme_font_size_override("font_size", 17)
    hud.add_theme_color_override("font_color", Color(0.86, 0.93, 0.96))
    hud.add_theme_constant_override("line_spacing", 3)
    panel.add_child(hud)


func _sample_footprint() -> int:
    var center_x := roundi(float(model.world_x) / SIM_UNITS_PER_TILE)
    var center_y := roundi(float(model.world_y) / SIM_UNITS_PER_TILE)
    var safe_count := 0
    var marker_index := 0

    for dz in range(-1, 2):
        for dx in range(-1, 2):
            var tx := center_x + dx
            var ty := center_y + dz
            var is_safe := _is_landing_tile(tx, ty)
            if is_safe:
                safe_count += 1

            var marker: MeshInstance3D = footprint_markers[marker_index]
            marker.position = Vector3(tx * TILE_SIZE, 0.07, ty * TILE_SIZE)
            marker.material_override = safe_material if is_safe else unsafe_material
            marker_index += 1

    return safe_count


func _is_landing_tile(x: int, y: int) -> bool:
    var wx := SPAWN_TILE.x + x
    var wy := SPAWN_TILE.y + y
    var code := _tile_code(wx, wy)
    return not (code >= 0x0D and code <= 0x10)


func _tile_code(wx: int, wy: int) -> int:
    if wy < 0 or wy >= world_tiles.size():
        return 0x0D
    var row = world_tiles[wy]
    if typeof(row) != TYPE_ARRAY or wx < 0 or wx >= row.size():
        return 0x0D
    return int(row[wx])


func _update_visuals() -> void:
    var y_height := 0.44 if model.landed else 1.0 + float(model.flight_height - FlightModel.HEIGHT_MIN) * HEIGHT_SCALE
    ship.position = Vector3(
        float(model.world_x) * WORLD_SCALE,
        y_height,
        float(model.world_y) * WORLD_SCALE
    )
    ship.rotation.y = -float(model.heading) * TAU / 16.0

    for leg in gear_nodes:
        leg.visible = model.landing_gear

    var focus := ship.position
    camera.position = focus + Vector3(12.0, 18.0, 12.0)
    camera.look_at(focus, Vector3.UP)


func _spawn_laser() -> void:
    var target := model.target_velocity()
    var direction := Vector3(float(target.x), 0.0, float(target.y)).normalized()
    if direction.length_squared() < 0.01:
        direction = Vector3(0.0, 0.0, 1.0)

    var bolt := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.12, 0.12, 0.72)
    bolt.mesh = mesh
    bolt.material_override = laser_material
    bolt.position = ship.position + direction * 1.15
    bolt.rotation.y = ship.rotation.y
    add_child(bolt)

    bolts.append({
        "node": bolt,
        "direction": direction,
        "life": 80,
    })


func _update_bolts() -> void:
    for i in range(bolts.size() - 1, -1, -1):
        var bolt_data: Dictionary = bolts[i]
        var bolt: MeshInstance3D = bolt_data["node"]
        var direction: Vector3 = bolt_data["direction"]
        bolt.position += direction * 0.48
        bolt_data["life"] = int(bolt_data["life"]) - 1

        if int(bolt_data["life"]) <= 0:
            bolt.queue_free()
            bolts.remove_at(i)
        else:
            bolts[i] = bolt_data


func _update_hud() -> void:
    var target := model.target_velocity()
    var heading_degrees := float(model.heading) * 22.5

    hud.text = (
        "PARALLAX REMAKE — C64 FLIGHT MODEL\n"
        + "Godot 4.7.2 / 50 Hz deterministic reference mode\n\n"
        + "Heading          %02d / 15   (%5.1f°)\n" % [model.heading, heading_degrees]
        + "Target velocity  X %+d   Y %+d   table mode %d\n" % [target.x, target.y, model.speed_mode]
        + "Velocity X       %+d + %3d/256\n" % [model.vx_hi, model.vx_frac]
        + "Velocity Y       %+d + %3d/256\n" % [model.vy_hi, model.vy_frac]
        + "Flight height    %d   [original range 3–40]\n" % model.flight_height
        + "Acceleration     %d   [%s]\n" % [model.acceleration_step, "landing" if model.landing_ready else "normal"]
        + "Landing gear     %s\n" % ("DOWN" if model.landing_gear else "UP")
        + "Footprint        %d / 9 landing cells\n" % model.footprint_safe_cells
        + "Landing ready    %s\n" % ("YES" if model.landing_ready else "no")
        + "Shields          %s\n" % ("ON" if shields_on else "OFF")
        + "World position   %d, %d original units\n" % [model.world_x, model.world_y]
        + "State            %s\n\n" % ("LANDED" if model.landed else "FLIGHT")
        + "Arrows / WASD  turn + climb/dive\n"
        + "Z              fire / commit landing when ready\n"
        + "SPACE          landing gear\n"
        + "F7             shields (UI state for now)\n"
        + "TAB            recovered velocity table mode\n"
        + "R              reset\n\n"
        + status_message
    )


func _make_box(parent: Node, size: Vector3, position_value: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = position_value
    node.material_override = material
    parent.add_child(node)
    return node


func _make_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.82
    return material
