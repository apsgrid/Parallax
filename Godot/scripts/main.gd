extends Node3D

const FlightModel = preload("res://scripts/flight_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")

const TILE_SIZE := 2.0
const SIM_UNITS_PER_TILE := 8.0
const WORLD_SCALE := TILE_SIZE / SIM_UNITS_PER_TILE
const HEIGHT_SCALE := 0.25
const WORLD_PATH := "res://data/world_480.json"
const INITIAL_VIEW_ORIGIN_TILE := Vector2i(10, 30)
const PLAYER_START_TILE := Vector2i(29, 39)
const STREAM_HALF_X := 28
const STREAM_HALF_Y := 22
const STREAM_REBUILD_DISTANCE := 12

var model := FlightModel.new()
var world_tiles: Array = []
var tile_atlas_images: Array[Image] = []
var tile_material_cache := {}
var tile_side_material: StandardMaterial3D
var world_root: Node3D
var stream_center_tile := Vector2i(-9999, -9999)

var ship: Node3D
var ground_player: Sprite3D
var ground_sprite_textures := {}
var camera: Camera3D
var hud: Label
var hud_panel: PanelContainer
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
var last_debug_hud := false
var last_debug_footprint := false

var debug_hud_visible := false
var debug_footprint_visible := false
var shields_on := true
var status_message := "Recovered C64 flight model active"


func _ready() -> void:
    _load_world_data()
    _load_tile_atlases()
    _load_ground_sprites()
    _build_environment()
    _build_world()
    _build_ship()
    _build_ground_player()
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

    var debug_hud_now := Input.is_key_pressed(KEY_F1)
    if debug_hud_now and not last_debug_hud:
        debug_hud_visible = not debug_hud_visible
        hud_panel.visible = debug_hud_visible
    last_debug_hud = debug_hud_now

    var debug_footprint_now := Input.is_key_pressed(KEY_F2)
    if debug_footprint_now and not last_debug_footprint:
        debug_footprint_visible = not debug_footprint_visible
        for marker in footprint_markers:
            marker.visible = debug_footprint_visible
    last_debug_footprint = debug_footprint_now

    var fire_now := Input.is_key_pressed(KEY_Z)
    var fire_pressed := fire_now and not last_fire
    last_fire = fire_now

    var ground_blocked_bits := 0
    var ground_right_contact_code := -1
    if model.ground_transition_flag and model.ground_initialized:
        var collision := _ground_collision_bridge()
        ground_blocked_bits = int(collision["blocked_bits"])
        ground_right_contact_code = int(collision["right_code"])

    var safe_cells := _sample_footprint()
    var events: Dictionary = model.step(
        input_bits,
        fire_pressed,
        safe_cells,
        ground_blocked_bits,
        ground_right_contact_code
    )

    if events["laser"]:
        _spawn_laser()
        status_message = "Laser fired"
    if events["ground_transition_requested"]:
        status_message = "Landing committed — original $F4 transition flag set"
    if events["entered_ground"]:
        status_message = "GROUND MODE — original $E000 initialization complete"
    if events["exited_ground"]:
        status_message = "Returned to flight — $F4 cleared / $F3 restored"
    if events["ground_moved"]:
        status_message = "ON FOOT — recovered one-pixel movement"
    if events["ground_special_interaction"]:
        status_message = "Ground special contact $C1-$C3 — handler $E444 not reconstructed yet"

    _maybe_stream_world()
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


func _load_tile_atlases() -> void:
    tile_atlas_images.clear()
    for zone in range(6):
        var relative_path := "res://generated/tiles_zone_%d.png" % zone
        var image := Image.load_from_file(ProjectSettings.globalize_path(relative_path))
        if image == null or image.is_empty():
            push_error("Unable to load generated C64 tile atlas: " + relative_path)
            tile_atlas_images.append(Image.create_empty(128, 128, false, Image.FORMAT_RGB8))
        else:
            tile_atlas_images.append(image)




func _load_ground_sprites() -> void:
    ground_sprite_textures.clear()
    for frame in range(0x50, 0x5C):
        var relative_path := "res://generated/ground_sprites/ground_%02X.png" % frame
        var image := Image.load_from_file(ProjectSettings.globalize_path(relative_path))
        if image == null or image.is_empty():
            push_error("Unable to load generated C64 ground sprite: " + relative_path)
            continue
        ground_sprite_textures[frame] = ImageTexture.create_from_image(image)


func _build_world() -> void:
    tile_side_material = _make_material(Color(0.075, 0.08, 0.09))

    safe_material = _make_material(Color(0.20, 0.72, 0.38, 0.68))
    safe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    unsafe_material = _make_material(Color(0.85, 0.25, 0.18, 0.68))
    unsafe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

    world_root = Node3D.new()
    world_root.name = "World"
    add_child(world_root)
    _rebuild_world_chunk(PLAYER_START_TILE)

    for i in range(9):
        var marker := _make_box(
            self,
            Vector3(TILE_SIZE * 0.86, 0.035, TILE_SIZE * 0.86),
            Vector3.ZERO,
            unsafe_material
        )
        marker.visible = debug_footprint_visible
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




func _build_ground_player() -> void:
    ground_player = Sprite3D.new()
    ground_player.name = "GroundPlayer"
    ground_player.pixel_size = WORLD_SCALE
    ground_player.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    ground_player.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    ground_player.shaded = false
    ground_player.visible = false
    if ground_sprite_textures.has(0x58):
        ground_player.texture = ground_sprite_textures[0x58]
    add_child(ground_player)


func _build_camera() -> void:
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 44.0
    camera.current = true
    add_child(camera)


func _build_hud() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    hud_panel = PanelContainer.new()
    hud_panel.position = Vector2(16, 16)
    hud_panel.custom_minimum_size = Vector2(520, 390)

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
    hud_panel.add_theme_stylebox_override("panel", style)
    hud_panel.visible = debug_hud_visible
    canvas.add_child(hud_panel)

    hud = Label.new()
    hud.custom_minimum_size = Vector2(500, 370)
    hud.add_theme_font_size_override("font_size", 17)
    hud.add_theme_color_override("font_color", Color(0.86, 0.93, 0.96))
    hud.add_theme_constant_override("line_spacing", 3)
    hud_panel.add_child(hud)


func _sample_footprint() -> int:
    # $C1FD adds velocity to fine scroll, while wrap normalization moves
    # the world tile index in the opposite direction.
    var center_x := floori(float(-model.world_x) / SIM_UNITS_PER_TILE)
    var center_y := floori(float(-model.world_y) / SIM_UNITS_PER_TILE)
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
    var wx := PLAYER_START_TILE.x + x
    var wy := PLAYER_START_TILE.y + y
    var code := _tile_code(wx, wy)
    return not (code >= 0x0D and code <= 0x10)


func _tile_code(wx: int, wy: int) -> int:
    if wy < 0 or wy >= world_tiles.size():
        return 0x0D
    var row = world_tiles[wy]
    if typeof(row) != TYPE_ARRAY or wx < 0 or wx >= row.size():
        return 0x0D
    return int(row[wx])


func _zone_for_world_y(wy: int) -> int:
    var macro_y := wy / 5
    if macro_y <= 0:
        return 0
    return clampi((macro_y - 1) / 18, 0, 5)


func _tile_is_visually_blank(code: int) -> bool:
    # Verified all-zero glyphs in the recovered $4000 charset.
    return code in [
        0x0D, 0x0E, 0x0F, 0x10, 0x20, 0x44, 0x5D,
        0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87,
        0x88, 0x89, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F, 0x90,
        0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98,
        0x99, 0x9A, 0x9B, 0x9C, 0xFE, 0xFF
    ]


func _current_world_tile() -> Vector2i:
    if model.landed:
        return _ground_player_world_tile()
    return Vector2i(
        PLAYER_START_TILE.x + floori(float(-model.world_x) / SIM_UNITS_PER_TILE),
        PLAYER_START_TILE.y + floori(float(-model.world_y) / SIM_UNITS_PER_TILE)
    )


func _ground_player_world_tile() -> Vector2i:
    var px := -model.ground_entry_world.x + model.ground_model.player_offset.x
    var py := -model.ground_entry_world.y + model.ground_model.player_offset.y
    return Vector2i(
        PLAYER_START_TILE.x + floori(float(px) / SIM_UNITS_PER_TILE),
        PLAYER_START_TILE.y + floori(float(py) / SIM_UNITS_PER_TILE)
    )


func _ground_collision_bridge() -> Dictionary:
    # The recovered collision classifier and passable-code set are exact.
    # This bridge maps the modern world coordinate back to the expanded
    # world grid. Fine-scroll equivalence to the C64 screen sampler is still
    # a verification target, so keep this boundary explicit.
    var center := _ground_player_world_tile()
    var directions := [
        [GroundModel.RIGHT, Vector2i(1, 0)],
        [GroundModel.LEFT, Vector2i(-1, 0)],
        [GroundModel.DOWN, Vector2i(0, 1)],
        [GroundModel.UP, Vector2i(0, -1)],
    ]

    var blocked_bits := 0
    var right_code := -1
    for entry in directions:
        var bit: int = entry[0]
        var delta: Vector2i = entry[1]
        var code := _tile_code(center.x + delta.x, center.y + delta.y)
        if bit == GroundModel.RIGHT:
            right_code = code
        if not GroundModel.is_passable_tile(code):
            blocked_bits |= bit

    return {
        "blocked_bits": blocked_bits,
        "right_code": right_code,
    }


func _maybe_stream_world() -> void:
    var current := _current_world_tile()
    if abs(current.x - stream_center_tile.x) >= STREAM_REBUILD_DISTANCE:
        _rebuild_world_chunk(current)
        return
    if abs(current.y - stream_center_tile.y) >= STREAM_REBUILD_DISTANCE:
        _rebuild_world_chunk(current)


func _rebuild_world_chunk(center: Vector2i) -> void:
    stream_center_tile = center

    if world_root != null:
        for child in world_root.get_children():
            child.queue_free()

    var min_x := maxi(0, center.x - STREAM_HALF_X)
    var max_x := mini(479, center.x + STREAM_HALF_X)
    var min_y := maxi(0, center.y - STREAM_HALF_Y)
    var max_y := mini(479, center.y + STREAM_HALF_Y)

    for wy in range(min_y, max_y + 1):
        for wx in range(min_x, max_x + 1):
            var code := _tile_code(wx, wy)
            if _tile_is_visually_blank(code):
                continue

            var local_x := float(wx - PLAYER_START_TILE.x) * TILE_SIZE
            var local_z := float(wy - PLAYER_START_TILE.y) * TILE_SIZE
            var zone := _zone_for_world_y(wy)
            var tile_material := _tile_material(code, zone)
            var tile_height := _tile_visual_height(code)

            _make_world_tile(
                Vector3(local_x, 0.0, local_z),
                tile_height,
                tile_material
            )


func _tile_visual_height(code: int) -> float:
    # Only collision classes verified in the original classifier get
    # meaningful extrusion. Keep the relief shallow so the C64 artwork
    # remains the dominant visual signal.
    if code >= 0x31 and code <= 0x3C:
        return 0.20
    if code == 0x48:
        return 0.32
    if code == 0x58:
        return 0.42
    return 0.035


func _tile_material(code: int, zone: int) -> StandardMaterial3D:
    var key := zone * 256 + code
    if tile_material_cache.has(key):
        return tile_material_cache[key]

    var atlas_image: Image = tile_atlas_images[zone]
    var region := Rect2i(
        (code & 0x0F) * 8,
        (code >> 4) * 8,
        8,
        8
    )
    var glyph_image := atlas_image.get_region(region)
    var glyph_texture := ImageTexture.create_from_image(glyph_image)

    var material := StandardMaterial3D.new()
    material.albedo_texture = glyph_texture
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    material.texture_repeat = false
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.roughness = 0.88
    material.metallic = 0.0
    tile_material_cache[key] = material
    return material


func _make_world_tile(origin: Vector3, height: float, material: StandardMaterial3D) -> void:
    if height > 0.05:
        _make_box(
            world_root,
            Vector3(TILE_SIZE, height, TILE_SIZE),
            origin + Vector3(0.0, height * 0.5, 0.0),
            tile_side_material
        )

    var top := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(TILE_SIZE, TILE_SIZE)
    top.mesh = mesh
    top.position = origin + Vector3(0.0, maxf(height, 0.025) + 0.003, 0.0)
    top.material_override = material
    world_root.add_child(top)


func _update_visuals() -> void:
    var y_height := 0.44 if model.landed else 1.0 + float(model.flight_height - FlightModel.HEIGHT_MIN) * HEIGHT_SCALE
    ship.position = Vector3(
        float(-model.world_x) * WORLD_SCALE,
        y_height,
        float(-model.world_y) * WORLD_SCALE
    )
    ship.rotation.y = -float(model.heading) * TAU / 16.0

    for leg in gear_nodes:
        leg.visible = model.landing_gear

    ground_player.visible = model.landed
    if model.landed:
        ground_player.position = ship.position + Vector3(
            float(model.ground_model.player_offset.x) * WORLD_SCALE,
            0.65,
            float(model.ground_model.player_offset.y) * WORLD_SCALE
        )
        var frame := model.ground_model.frame_code
        if ground_sprite_textures.has(frame):
            ground_player.texture = ground_sprite_textures[frame]

    var focus := ground_player.position if model.landed else ship.position
    camera.position = focus + Vector3(8.0, 34.0, 8.0)
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
        + "Scroll accum      %d, %d original units\n" % [model.world_x, model.world_y]
        + "World tile        %d, %d\n" % [_current_world_tile().x, _current_world_tile().y]
        + "$F4 ground flag  %s\n" % ("SET" if model.ground_transition_flag else "clear")
        + "$F3 flight mode  %s\n" % ("1" if model.flight_raster_mode else "0")
        + "$E049 init guard %s\n" % ("SET" if model.ground_initialized else "clear")
        + "State            %s\n\n" % ("GROUND" if model.landed else ("TRANSITION" if model.ground_transition_flag else "FLIGHT"))
        + "Arrows / WASD  turn + climb/dive (flight)\n"
        + "Z              fire / land / return to ship\n"
        + "SPACE          landing gear\n"
        + "F7             shields (UI state for now)\n"
        + "TAB            recovered velocity table mode\n"
        + "R              reset\n"
        + "F1             debug HUD\n"
        + "F2             landing footprint\n\n"
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
