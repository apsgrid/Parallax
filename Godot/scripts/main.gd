extends Node3D

const FlightModel = preload("res://scripts/flight_model.gd")
const GroundModel = preload("res://scripts/ground_model.gd")
const SupplyModel = preload("res://scripts/supply_model.gd")
const InteriorModel = preload("res://scripts/interior_model.gd")
const ComputerModel = preload("res://scripts/computer_model.gd")
const EncounterModel = preload("res://scripts/encounter_model.gd")
const EndgameModel = preload("res://scripts/endgame_model.gd")

const TILE_SIZE := 2.0
const SIM_UNITS_PER_TILE := 8.0
const WORLD_SCALE := TILE_SIZE / SIM_UNITS_PER_TILE
const HEIGHT_SCALE := 0.25
const WORLD_PATH := "res://data/world_480.json"
const INTERIOR_DATA_PATH := "res://data/interior_runtime.json"
const INITIAL_VIEW_ORIGIN_TILE := Vector2i(10, 30)
const PLAYER_START_TILE := Vector2i(29, 39)
const STREAM_HALF_X := 28
const STREAM_HALF_Y := 22
const STREAM_REBUILD_DISTANCE := 12

var model := FlightModel.new()
var world_tiles: Array = []
var master_tiles: Array = []
var interior_runtime_data: Dictionary = {}
var tile_atlas_images: Array[Image] = []
var interior_atlas_images: Array[Image] = []
var tile_material_cache := {}
var interior_material_cache := {}
var tile_side_material: StandardMaterial3D
var world_root: Node3D
var interior_root: Node3D
var stream_center_tile := Vector2i(-9999, -9999)

var ship: Node3D
var ground_player: Sprite3D
var ground_sprite_textures := {}
var encounter_sprite_textures := {}
var encounter_entity: Sprite3D
var stun_projectile: Sprite3D
var camera: Camera3D
var hud: Label
var hud_panel: PanelContainer
var supply_panel: PanelContainer
var supply_label: Label
var terminal_panel: PanelContainer
var terminal_label: Label
var kard_panel: PanelContainer
var kard_label: Label
var kard_panel_frames := 0
var kard_offer_panel: PanelContainer
var kard_offer_label: Label
var endgame_panel: PanelContainer
var endgame_label: Label

var touch_layer: CanvasLayer
var touch_root: Control
var touch_terminal_panel: PanelContainer
var touch_terminal_input: LineEdit
var touch_kard_panel: PanelContainer
var touch_controls_enabled := false
var touch_pressed := {
    "left": false,
    "right": false,
    "up": false,
    "down": false,
    "fire": false,
    "gear": false,
    "mode": false,
    "shield": false,
    "return": false,
}
var _touch_text_guard := false

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
    _load_interior_data()
    model.configure_interior_runtime(interior_runtime_data)
    model.configure_world_runtime(master_tiles)
    _load_tile_atlases()
    _load_interior_atlases()
    _load_ground_sprites()
    _load_encounter_sprites()
    _build_environment()
    _build_world()
    _build_interior_root()
    _build_ship()
    _build_ground_player()
    _build_encounter_sprites()
    _build_camera()
    _build_hud()
    _build_supply_hud()
    _build_terminal_hud()
    _build_kard_hud()
    _build_kard_offer_hud()
    _build_endgame_hud()
    _build_touch_controls()
    _update_visuals()
    _update_hud()


func _physics_process(_delta: float) -> void:
    var terminal_active := model.in_interior() and model.interior_model.terminal_open
    var offer_active := model.in_interior() and model.kard_offer_pending()
    var modal_input := terminal_active or offer_active
    var input_bits := 0
    if not offer_active and (
        Input.is_key_pressed(KEY_RIGHT)
        or (not terminal_active and Input.is_key_pressed(KEY_D))
        or bool(touch_pressed["right"])
    ):
        input_bits |= 0x01
    if not offer_active and (
        Input.is_key_pressed(KEY_LEFT)
        or (not terminal_active and Input.is_key_pressed(KEY_A))
        or bool(touch_pressed["left"])
    ):
        input_bits |= 0x02
    if not offer_active and (
        Input.is_key_pressed(KEY_DOWN)
        or (not terminal_active and Input.is_key_pressed(KEY_S))
        or bool(touch_pressed["down"])
    ):
        input_bits |= 0x04
    if not offer_active and (
        Input.is_key_pressed(KEY_UP)
        or (not terminal_active and Input.is_key_pressed(KEY_W))
        or bool(touch_pressed["up"])
    ):
        input_bits |= 0x08

    var fire_now := Input.is_key_pressed(KEY_Z) or bool(touch_pressed["fire"])
    var fire_pressed := fire_now and not last_fire
    last_fire = fire_now

    var reset_now := Input.is_key_pressed(KEY_R)
    if reset_now and not last_reset:
        model.reset()
        status_message = "Flight state reset"
    last_reset = reset_now

    if model.endgame_active():
        var ending_events: Dictionary = model.step_endgame(input_bits, fire_now)
        if ending_events["ending_overlay_opened"]:
            status_message = "MEGA HERO - recovered ending/name-entry overlay"
        if ending_events["score_disqualified"]:
            status_message = "Score did not beat TODAYS BESTEST SCORE - returned to title"
        if ending_events["name_accepted"]:
            status_message = "ENDING - name character accepted"
        if ending_events["title_returned"] and not ending_events["score_disqualified"]:
            status_message = "TODAYS BESTEST SCORE updated - original title return reached"
        _update_visuals()
        _update_hud()
        return

    var gear_now := Input.is_key_pressed(KEY_SPACE) or bool(touch_pressed["gear"])
    if gear_now and not last_gear:
        model.toggle_landing_gear()
        status_message = "Landing gear %s" % ("DOWN" if model.landing_gear else "UP")
    last_gear = gear_now

    var mode_now := Input.is_key_pressed(KEY_TAB) or bool(touch_pressed["mode"])
    if mode_now and not last_mode:
        model.toggle_speed_mode()
        status_message = "Recovered velocity table mode %d" % model.speed_mode
    last_mode = mode_now

    var shield_now := Input.is_key_pressed(KEY_F7) or bool(touch_pressed["shield"])
    if shield_now and not last_shield:
        shields_on = not shields_on
        status_message = "Shields %s" % ("ON" if shields_on else "OFF")
    last_shield = shield_now

    var return_now := Input.is_key_pressed(KEY_ENTER) or bool(touch_pressed["return"])
    if return_now and not last_return and not modal_input:
        _show_kard_status()
        status_message = "KARD/PASS status"
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

    var ground_blocked_bits := 0
    var ground_right_contact_code := -1
    if model.on_foot():
        var collision := _ground_collision_bridge()
        ground_blocked_bits = int(collision["blocked_bits"])
        ground_right_contact_code = int(collision["right_code"])

    var flight_special_code := -1
    if not model.ground_transition_flag:
        flight_special_code = _flight_special_contact_code()

    var safe_cells := _sample_footprint()
    var events: Dictionary = model.step(
        input_bits,
        fire_pressed,
        safe_cells,
        ground_blocked_bits,
        ground_right_contact_code,
        fire_now,
        flight_special_code
    )

    if events["laser"]:
        _spawn_laser()
        status_message = "Laser fired"
    if events["ground_transition_requested"]:
        status_message = "Landing committed — original $F4 transition flag set"
    if events["entered_ground"]:
        status_message = "SHIP SUPPLY — recovered landing inventory/disembark screen"
    if events["supply_changed"]:
        status_message = "SHIP SUPPLY — inventory updated"
    if int(events["supply_message_code"]) != SupplyModel.MSG_NONE:
        status_message = SupplyModel.message_text(int(events["supply_message_code"]))
    if events["exited_ship"]:
        status_message = "EXIT SHIP — outdoor ground mode active"
    if events["exited_ground"]:
        if events["supply_stay_aboard"]:
            status_message = "STAY ABOARD — returned to flight"
        else:
            status_message = "Returned to flight — $F4 cleared / $F3 restored"
    if events["ground_moved"]:
        status_message = "INTERIOR — recovered one-pixel movement" if model.in_interior() else "ON FOOT — recovered one-pixel movement"
    if events["entered_interior"]:
        _rebuild_interior_room()
        status_message = "ENTER STRUCTURE — recovered $E444 local-area mode ($%02X)" % int(events["interior_entry_code"])
    if events["entity_spawned"]:
        status_message = "LOCAL ENTITY SPAWNED — original current-region encounter"
    if events["stun_projectile_fired"]:
        status_message = "STUN-GUN FIRED — one ammunition used"
    if events["scientist_stunned"]:
        status_message = "SCIENTIST STUNNED — approach for KARD interaction"
    if events["kard_offer_opened"]:
        status_message = "KARD OFFER — Y take / N decline"
    if events["scientist_following"]:
        status_message = "SCIENTIST ACCOMPANYING"
    if events["interior_terminal_opened"]:
        status_message = "%s — recovered terminal interaction" % InteriorModel.terminal_name(int(events["interior_terminal_kind"]))
    if events["exited_interior"]:
        status_message = "EXIT STRUCTURE — outdoor state restored"
    if events["transported"]:
        var destination: Vector2i = events["transport_destination_macro"]
        status_message = "TRANSPORTER — relocated to macro (%d,%d)" % [destination.x, destination.y]
    if events["endgame_triggered"]:
        status_message = "FINAL TRANSPORTER — recovered stage-5 ending gate reached; press Z/FIRE"

    if kard_panel_frames > 0:
        kard_panel_frames -= 1
        if kard_panel_frames == 0 and kard_panel != null:
            kard_panel.visible = false

    _maybe_stream_world()
    _update_bolts()
    _update_visuals()
    _sample_footprint()
    _update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event := event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return

    if model.in_interior() and model.kard_offer_pending():
        if key_event.keycode == KEY_Y:
            var take_events := model.answer_kard_offer(true)
            status_message = "KARD TAKEN — scientist accompanying" if take_events["scientist_following"] else "KARD TAKEN"
        elif key_event.keycode == KEY_N:
            var decline_events := model.answer_kard_offer(false)
            status_message = "KARD DECLINED — scientist accompanying" if decline_events["scientist_following"] else "KARD DECLINED"
        return

    if not (model.in_interior() and model.interior_model.terminal_open):
        return

    var c = model.computer_model
    var events := {}

    if c.state == ComputerModel.STATE_SELECT_KARD:
        if key_event.keycode == KEY_A:
            events = c.select_kard(0)
        elif key_event.keycode == KEY_B:
            events = c.select_kard(1)
        else:
            return
    elif c.state == ComputerModel.STATE_SHOP_OFFER and key_event.keycode == KEY_B:
        events = c.buy_bonanza(model.supply_model)
    elif key_event.keycode == KEY_BACKSPACE:
        c.backspace()
        return
    elif c.state == ComputerModel.STATE_ENTER_KARD_CODE or c.state == ComputerModel.STATE_PASSWORD_ENTRY:
        var character := _terminal_character_for_key(key_event.keycode)
        if character.is_empty():
            return
        events = c.input_character(character)
    elif key_event.keycode == KEY_Z or key_event.keycode == KEY_ENTER:
        events = c.press_action(model.supply_model)
    else:
        return

    _handle_computer_events(events)


func _handle_computer_events(events: Dictionary) -> void:
    if events.is_empty():
        return
    if bool(events.get("shop_purchased", false)):
        status_message = "COMPUTASHOP — BONANZA PACK purchased"
    elif bool(events.get("shop_insufficient_credits", false)):
        status_message = "COMPUTASHOP — insufficient credits"
    elif bool(events.get("password_letter_revealed", false)):
        status_message = "KARD class %d revealed letter %s" % [
            int(events.get("revealed_class", 0)),
            String(events.get("revealed_letter", ""))
        ]
    elif bool(events.get("password_correct", false)):
        status_message = "PASSWORD ACCEPTED — progression %d / 5" % int(events.get("progression_index", 0))
    elif bool(events.get("password_incorrect", false)):
        status_message = "PASSWORD INVALID"
    elif bool(events.get("kard_lost", false)):
        status_message = "INCORRECT — KARD LOST"
    elif bool(events.get("kard_returned", false)):
        status_message = "KARD returned"
    elif int(events.get("credits_changed", 0)) > 0:
        status_message = "%d CREDITS TAKEN" % int(events["credits_changed"])

    if bool(events.get("close_terminal", false)):
        model.close_interior_terminal()


func _terminal_character_for_key(keycode: int) -> String:
    match keycode:
        KEY_0: return "0"
        KEY_1: return "1"
        KEY_2: return "2"
        KEY_3: return "3"
        KEY_4: return "4"
        KEY_5: return "5"
        KEY_6: return "6"
        KEY_7: return "7"
        KEY_8: return "8"
        KEY_9: return "9"
        KEY_A: return "A"
        KEY_B: return "B"
        KEY_C: return "C"
        KEY_D: return "D"
        KEY_E: return "E"
        KEY_F: return "F"
        KEY_G: return "G"
        KEY_H: return "H"
        KEY_I: return "I"
        KEY_J: return "J"
        KEY_K: return "K"
        KEY_L: return "L"
        KEY_M: return "M"
        KEY_N: return "N"
        KEY_O: return "O"
        KEY_P: return "P"
        KEY_Q: return "Q"
        KEY_R: return "R"
        KEY_S: return "S"
        KEY_T: return "T"
        KEY_U: return "U"
        KEY_V: return "V"
        KEY_W: return "W"
        KEY_X: return "X"
        KEY_Y: return "Y"
        KEY_Z: return "Z"
    return ""




func _build_touch_controls() -> void:
    touch_controls_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

    touch_layer = CanvasLayer.new()
    touch_layer.layer = 12
    add_child(touch_layer)

    touch_root = Control.new()
    touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    touch_root.visible = touch_controls_enabled
    touch_layer.add_child(touch_root)

    # C64 directional priority is still resolved by the reference models;
    # these buttons only feed the same held-bit state as the keyboard.
    _make_touch_hold_button("UP", Rect2(105, 475, 90, 68), "up")
    _make_touch_hold_button("LEFT", Rect2(15, 545, 90, 68), "left")
    _make_touch_hold_button("RIGHT", Rect2(195, 545, 90, 68), "right")
    _make_touch_hold_button("DOWN", Rect2(105, 615, 90, 68), "down")

    _make_touch_fire_button("FIRE", Rect2(1085, 545, 165, 120))
    _make_touch_hold_button("GEAR", Rect2(940, 610, 125, 55), "gear")
    _make_touch_hold_button("SPEED", Rect2(940, 550, 125, 55), "mode")
    _make_touch_hold_button("SHIELD", Rect2(940, 490, 125, 55), "shield")
    _make_touch_hold_button("STATUS", Rect2(1085, 480, 165, 55), "return")

    touch_kard_panel = PanelContainer.new()
    touch_kard_panel.position = Vector2(500, 515)
    touch_kard_panel.custom_minimum_size = Vector2(280, 90)
    touch_kard_panel.visible = false
    touch_root.add_child(touch_kard_panel)
    var kard_row := HBoxContainer.new()
    kard_row.alignment = BoxContainer.ALIGNMENT_CENTER
    touch_kard_panel.add_child(kard_row)
    var yes_button := Button.new()
    yes_button.text = "YES / TAKE"
    yes_button.custom_minimum_size = Vector2(125, 70)
    yes_button.focus_mode = Control.FOCUS_NONE
    yes_button.pressed.connect(_answer_touch_kard.bind(true))
    kard_row.add_child(yes_button)
    var no_button := Button.new()
    no_button.text = "NO"
    no_button.custom_minimum_size = Vector2(125, 70)
    no_button.focus_mode = Control.FOCUS_NONE
    no_button.pressed.connect(_answer_touch_kard.bind(false))
    kard_row.add_child(no_button)

    touch_terminal_panel = PanelContainer.new()
    touch_terminal_panel.position = Vector2(305, 535)
    touch_terminal_panel.custom_minimum_size = Vector2(620, 155)
    touch_terminal_panel.visible = false
    touch_root.add_child(touch_terminal_panel)

    var terminal_box := VBoxContainer.new()
    touch_terminal_panel.add_child(terminal_box)
    var terminal_hint := Label.new()
    terminal_hint.text = "TERMINAL INPUT — tap field for keyboard"
    terminal_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    terminal_box.add_child(terminal_hint)

    touch_terminal_input = LineEdit.new()
    touch_terminal_input.placeholder_text = "KARD / password"
    touch_terminal_input.virtual_keyboard_enabled = true
    touch_terminal_input.keep_editing_on_text_submit = true
    touch_terminal_input.text_changed.connect(_on_touch_terminal_text_changed)
    terminal_box.add_child(touch_terminal_input)

    var terminal_buttons := HBoxContainer.new()
    terminal_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    terminal_box.add_child(terminal_buttons)
    for spec in [["A", "A"], ["B", "B"]]:
        var b := Button.new()
        b.text = String(spec[0])
        b.custom_minimum_size = Vector2(80, 45)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_touch_terminal_character.bind(String(spec[1])))
        terminal_buttons.add_child(b)

    var back_button := Button.new()
    back_button.text = "BACK"
    back_button.custom_minimum_size = Vector2(100, 45)
    back_button.focus_mode = Control.FOCUS_NONE
    back_button.pressed.connect(_touch_terminal_backspace)
    terminal_buttons.add_child(back_button)

    var action_button := Button.new()
    action_button.text = "ENTER / FIRE"
    action_button.custom_minimum_size = Vector2(145, 45)
    action_button.focus_mode = Control.FOCUS_NONE
    action_button.pressed.connect(_touch_terminal_action)
    terminal_buttons.add_child(action_button)


func _make_touch_hold_button(text_value: String, rect: Rect2, flag: String) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = rect.position
    button.size = rect.size
    button.focus_mode = Control.FOCUS_NONE
    button.modulate = Color(1.0, 1.0, 1.0, 0.72)
    button.add_theme_font_size_override("font_size", 18)
    button.button_down.connect(_set_touch_flag.bind(flag, true))
    button.button_up.connect(_set_touch_flag.bind(flag, false))
    touch_root.add_child(button)
    return button


func _make_touch_fire_button(text_value: String, rect: Rect2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = rect.position
    button.size = rect.size
    button.focus_mode = Control.FOCUS_NONE
    button.modulate = Color(1.0, 1.0, 1.0, 0.78)
    button.add_theme_font_size_override("font_size", 22)
    button.button_down.connect(_touch_fire_down)
    button.button_up.connect(_touch_fire_up)
    touch_root.add_child(button)
    return button


func _set_touch_flag(flag: String, pressed: bool) -> void:
    if touch_pressed.has(flag):
        touch_pressed[flag] = pressed


func _touch_fire_down() -> void:
    if model.in_interior() and model.interior_model.terminal_open:
        _touch_terminal_action()
        touch_pressed["fire"] = false
        return
    touch_pressed["fire"] = true


func _touch_fire_up() -> void:
    touch_pressed["fire"] = false


func _answer_touch_kard(take: bool) -> void:
    if not model.kard_offer_pending():
        return
    var answer := model.answer_kard_offer(take)
    if take:
        status_message = "KARD TAKEN — scientist accompanying" if answer["scientist_following"] else "KARD TAKEN"
    else:
        status_message = "KARD DECLINED — scientist accompanying" if answer["scientist_following"] else "KARD DECLINED"


func _on_touch_terminal_text_changed(value: String) -> void:
    if _touch_text_guard or value.is_empty():
        return
    _touch_text_guard = true
    for character in value.to_upper():
        if (character >= "0" and character <= "9") or (character >= "A" and character <= "Z"):
            _touch_terminal_character(character)
    touch_terminal_input.text = ""
    _touch_text_guard = false


func _touch_terminal_character(character: String) -> void:
    if not (model.in_interior() and model.interior_model.terminal_open):
        return
    var c = model.computer_model
    var events := {}
    if c.state == ComputerModel.STATE_SELECT_KARD:
        if character == "A":
            events = c.select_kard(0)
        elif character == "B":
            events = c.select_kard(1)
        else:
            return
    elif c.state == ComputerModel.STATE_SHOP_OFFER and character == "B":
        events = c.buy_bonanza(model.supply_model)
    elif c.state == ComputerModel.STATE_ENTER_KARD_CODE or c.state == ComputerModel.STATE_PASSWORD_ENTRY:
        events = c.input_character(character)
    else:
        return
    _handle_computer_events(events)


func _touch_terminal_backspace() -> void:
    if model.in_interior() and model.interior_model.terminal_open:
        model.computer_model.backspace()


func _touch_terminal_action() -> void:
    if not (model.in_interior() and model.interior_model.terminal_open):
        return
    var events := model.computer_model.press_action(model.supply_model)
    _handle_computer_events(events)


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
        master_tiles = parsed.get("master_tiles", [])


func _load_interior_data() -> void:
    var file := FileAccess.open(INTERIOR_DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Unable to load reconstructed Parallax interior data")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        interior_runtime_data = parsed


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




func _load_interior_atlases() -> void:
    interior_atlas_images.clear()
    interior_material_cache.clear()
    for zone in range(6):
        var relative_path := "res://generated/interior_tiles_zone_%d.png" % zone
        var image := Image.load_from_file(ProjectSettings.globalize_path(relative_path))
        if image == null or image.is_empty():
            push_error("Unable to load generated C64 interior tile atlas: " + relative_path)
            interior_atlas_images.append(Image.create_empty(128, 128, false, Image.FORMAT_RGB8))
        else:
            interior_atlas_images.append(image)


func _load_ground_sprites() -> void:
    ground_sprite_textures.clear()
    for frame in range(0x50, 0x5C):
        var relative_path := "res://generated/ground_sprites/ground_%02X.png" % frame
        var image := Image.load_from_file(ProjectSettings.globalize_path(relative_path))
        if image == null or image.is_empty():
            push_error("Unable to load generated C64 ground sprite: " + relative_path)
            continue
        ground_sprite_textures[frame] = ImageTexture.create_from_image(image)


func _load_encounter_sprites() -> void:
    encounter_sprite_textures.clear()
    var pointers := []
    for ptr in range(0x40, 0x48):
        pointers.append(ptr)
    pointers.append(0x55)
    for ptr in range(0x9D, 0xB1):
        pointers.append(ptr)

    for ptr in pointers:
        var relative_path := "res://generated/encounter_sprites/ptr_%02X.png" % ptr
        var image := Image.load_from_file(ProjectSettings.globalize_path(relative_path))
        if image == null or image.is_empty():
            push_error("Unable to load generated C64 encounter sprite: " + relative_path)
            continue
        encounter_sprite_textures[ptr] = ImageTexture.create_from_image(image)


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


func _build_interior_root() -> void:
    interior_root = Node3D.new()
    interior_root.name = "Interior"
    interior_root.visible = false
    add_child(interior_root)


func _rebuild_interior_room() -> void:
    if interior_root == null:
        return
    for child in interior_root.get_children():
        child.queue_free()

    var layout: Array = model.interior_model.layout
    var exterior_tile := _ground_player_world_tile()
    var zone := _zone_for_world_y(exterior_tile.y)
    for y in range(layout.size()):
        var row: Array = layout[y]
        for x in range(row.size()):
            var code := int(row[x])
            if code == 0x20:
                continue
            var passable := GroundModel.is_passable_tile(code)
            var height := 0.035 if passable else 0.42
            var position_value := Vector3(
                float(x - 20) * TILE_SIZE,
                0.0,
                float(y - 10) * TILE_SIZE
            )
            var material := _interior_tile_material(code, zone)
            _make_interior_tile(position_value, height, material)


func _make_interior_tile(origin: Vector3, height: float, material: StandardMaterial3D) -> void:
    if height > 0.05:
        _make_box(
            interior_root,
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
    interior_root.add_child(top)


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


func _build_encounter_sprites() -> void:
    encounter_entity = Sprite3D.new()
    encounter_entity.name = "EncounterEntity"
    encounter_entity.pixel_size = WORLD_SCALE
    encounter_entity.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    encounter_entity.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    encounter_entity.shaded = false
    encounter_entity.visible = false
    add_child(encounter_entity)

    stun_projectile = Sprite3D.new()
    stun_projectile.name = "StunProjectile"
    stun_projectile.pixel_size = WORLD_SCALE
    stun_projectile.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    stun_projectile.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    stun_projectile.shaded = false
    stun_projectile.visible = false
    add_child(stun_projectile)


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


func _build_supply_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 5
    add_child(canvas)

    supply_panel = PanelContainer.new()
    supply_panel.position = Vector2(360, 115)
    supply_panel.custom_minimum_size = Vector2(560, 460)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.01, 0.012, 0.018, 0.94)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.62, 0.72, 0.78, 0.95)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    supply_panel.add_theme_stylebox_override("panel", style)
    supply_panel.visible = false
    canvas.add_child(supply_panel)

    supply_label = Label.new()
    supply_label.custom_minimum_size = Vector2(530, 430)
    supply_label.add_theme_font_size_override("font_size", 22)
    supply_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.90))
    supply_label.add_theme_constant_override("line_spacing", 6)
    supply_panel.add_child(supply_label)


func _build_terminal_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 6
    add_child(canvas)

    terminal_panel = PanelContainer.new()
    terminal_panel.position = Vector2(410, 150)
    terminal_panel.custom_minimum_size = Vector2(460, 360)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.005, 0.008, 0.012, 0.96)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.48, 0.78, 0.66, 0.95)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    terminal_panel.add_theme_stylebox_override("panel", style)
    terminal_panel.visible = false
    canvas.add_child(terminal_panel)

    terminal_label = Label.new()
    terminal_label.custom_minimum_size = Vector2(430, 330)
    terminal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    terminal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    terminal_label.add_theme_font_size_override("font_size", 24)
    terminal_label.add_theme_color_override("font_color", Color(0.84, 1.0, 0.90))
    terminal_label.add_theme_constant_override("line_spacing", 7)
    terminal_panel.add_child(terminal_label)


func _build_kard_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 4
    add_child(canvas)

    kard_panel = PanelContainer.new()
    kard_panel.position = Vector2(850, 22)
    kard_panel.custom_minimum_size = Vector2(400, 150)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.01, 0.012, 0.018, 0.92)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = Color(0.58, 0.68, 0.74, 0.9)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    kard_panel.add_theme_stylebox_override("panel", style)
    kard_panel.visible = false
    canvas.add_child(kard_panel)

    kard_label = Label.new()
    kard_label.custom_minimum_size = Vector2(380, 130)
    kard_label.add_theme_font_size_override("font_size", 21)
    kard_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.90))
    kard_label.add_theme_constant_override("line_spacing", 5)
    kard_panel.add_child(kard_label)


func _show_kard_status() -> void:
    var c = model.computer_model
    var lines := []
    if c.kard_count() >= 1:
        lines.append("KARD A  " + c.kard_text(c.kards[0]))
    if c.kard_count() >= 2:
        lines.append("KARD B  " + c.kard_text(c.kards[1]))
    if lines.is_empty():
        lines.append("NO KARD")
    lines.append("PASS    " + "".join(c.password_display))
    kard_label.text = "\n".join(lines)
    kard_panel.visible = true
    kard_panel_frames = 150


func _build_kard_offer_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 7
    add_child(canvas)

    kard_offer_panel = PanelContainer.new()
    kard_offer_panel.position = Vector2(450, 190)
    kard_offer_panel.custom_minimum_size = Vector2(380, 270)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.006, 0.008, 0.012, 0.97)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = Color(0.82, 0.88, 0.58, 0.96)
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    kard_offer_panel.add_theme_stylebox_override("panel", style)
    kard_offer_panel.visible = false
    canvas.add_child(kard_offer_panel)

    kard_offer_label = Label.new()
    kard_offer_label.custom_minimum_size = Vector2(350, 240)
    kard_offer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    kard_offer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    kard_offer_label.add_theme_font_size_override("font_size", 27)
    kard_offer_label.add_theme_color_override("font_color", Color(0.96, 0.98, 0.80))
    kard_offer_label.add_theme_constant_override("line_spacing", 8)
    kard_offer_panel.add_child(kard_offer_label)


func _build_endgame_hud() -> void:
    var canvas := CanvasLayer.new()
    canvas.layer = 9
    add_child(canvas)

    endgame_panel = PanelContainer.new()
    endgame_panel.position = Vector2(250, 92)
    endgame_panel.custom_minimum_size = Vector2(780, 530)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.004, 0.006, 0.010, 0.98)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.border_color = Color(0.88, 0.86, 0.56, 0.98)
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    endgame_panel.add_theme_stylebox_override("panel", style)
    endgame_panel.visible = false
    canvas.add_child(endgame_panel)

    endgame_label = Label.new()
    endgame_label.custom_minimum_size = Vector2(740, 490)
    endgame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    endgame_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    endgame_label.add_theme_font_size_override("font_size", 24)
    endgame_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.78))
    endgame_label.add_theme_constant_override("line_spacing", 7)
    endgame_panel.add_child(endgame_label)


func _update_endgame_hud() -> void:
    if endgame_panel == null:
        return
    var e = model.endgame_model
    endgame_panel.visible = e.active()
    if not endgame_panel.visible:
        return

    match e.state:
        EndgameModel.STATE_FINAL_EFFECT_WAIT_FIRE:
            endgame_label.text = "SCORE  %s\n\nFINAL TRANSPORTER\n\nZ / FIRE" % e.score_text()
        EndgameModel.STATE_NAME_ENTRY:
            endgame_label.text = "SCORE  %s\n\n%s\n\nUP / DOWN SELECT   Z / FIRE ACCEPT" % [
                e.score_text(),
                e.ending_message()
            ]
        EndgameModel.STATE_TITLE_RETURN:
            endgame_label.text = "PARALLAX\n\n%s\n\nR  NEW GAME" % e.title_return_message()


func _update_terminal_hud() -> void:
    var c = model.computer_model
    var header := "CREDITS %02d   KARDS %d   PASS %s   STAGE %d/5\n\n" % [
        c.credits,
        c.kard_count(),
        "".join(c.password_display),
        c.progression_index,
    ]
    terminal_label.text = header + c.screen_text()


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
    if model.on_foot():
        return _ground_player_world_tile()
    return Vector2i(
        PLAYER_START_TILE.x + floori(float(-model.world_x) / SIM_UNITS_PER_TILE),
        PLAYER_START_TILE.y + floori(float(-model.world_y) / SIM_UNITS_PER_TILE)
    )


func _flight_special_contact_code() -> int:
    # $0FD0-$0FD4 checks the cross-shaped five cells from the 3x3 flight
    # footprint for tile $70 after the normal collision sampler returns zero.
    var center := _current_world_tile()
    var offsets := [
        Vector2i(0, -1),
        Vector2i(-1, 0),
        Vector2i.ZERO,
        Vector2i(1, 0),
        Vector2i(0, 1),
    ]
    for offset in offsets:
        if _tile_code(center.x + offset.x, center.y + offset.y) == EndgameModel.TRANSPORT_TRIGGER_TILE:
            return EndgameModel.TRANSPORT_TRIGGER_TILE
    return -1


func _ground_screen_origin_tile() -> Vector2i:
    # Flight and ground use the same $0703-$0708 scroll state. At landing,
    # ground_entry_world is the accumulated flight scroll in original pixel
    # units. Accepted ground movement adds the inverse $E250 scroll delta.
    var total_scroll := model.ground_entry_world + model.ground_model.scroll_offset
    return GroundModel.screen_origin_tile(INITIAL_VIEW_ORIGIN_TILE, total_scroll)


func _ground_player_world_tile() -> Vector2i:
    return _ground_screen_origin_tile() + GroundModel.PLAYER_SCREEN_CELL


func _ground_collision_bridge() -> Dictionary:
    # Exact $E280 geometry. Its zero-page pointer bytes are low=$7B,
    # high=$79/$7D, i.e. $797B/$7D7B — not $7B79/$7F79.
    # Relative to $7800/$7C00 the four sampled screen cells are:
    # UP (19,9), LEFT (18,10), RIGHT (20,10), DOWN (19,11).
    var origin := _ground_screen_origin_tile()
    var samples := [
        [GroundModel.RIGHT, GroundModel.COLLISION_RIGHT_CELL],
        [GroundModel.LEFT, GroundModel.COLLISION_LEFT_CELL],
        [GroundModel.DOWN, GroundModel.COLLISION_DOWN_CELL],
        [GroundModel.UP, GroundModel.COLLISION_UP_CELL],
    ]

    var blocked_bits := 0
    var right_code := -1
    for entry in samples:
        var bit: int = entry[0]
        var cell: Vector2i = entry[1]
        var code := _tile_code(origin.x + cell.x, origin.y + cell.y)
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


func _interior_tile_material(code: int, zone: int) -> StandardMaterial3D:
    var key := zone * 256 + code
    if interior_material_cache.has(key):
        return interior_material_cache[key]

    var atlas_image: Image = interior_atlas_images[zone]
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
    interior_material_cache[key] = material
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


func _interior_pixel_to_world(position_value: Vector2i, y_value: float = 0.65) -> Vector3:
    var cell_x := float(position_value.x - 0x0C) / 8.0
    var cell_y := float(position_value.y - 0x2D) / 8.0 + 1.0
    return Vector3(
        (cell_x - 20.0) * TILE_SIZE,
        y_value,
        (cell_y - 10.0) * TILE_SIZE
    )


func _update_visuals() -> void:
    var in_interior := model.in_interior()
    var in_endgame := model.endgame_active()
    var y_height := 0.44 if model.landed else 1.0 + float(model.flight_height - FlightModel.HEIGHT_MIN) * HEIGHT_SCALE
    ship.position = Vector3(
        float(-model.world_x) * WORLD_SCALE,
        y_height,
        float(-model.world_y) * WORLD_SCALE
    )
    ship.rotation.y = -float(model.heading) * TAU / 16.0
    ship.visible = not in_interior and not in_endgame

    if world_root != null:
        world_root.visible = not in_interior and not in_endgame
    if interior_root != null:
        interior_root.visible = in_interior and not in_endgame

    for leg in gear_nodes:
        leg.visible = model.landing_gear and not in_interior and not in_endgame

    ground_player.visible = (model.on_foot() or in_interior) and not in_endgame
    if model.on_foot():
        ground_player.position = ship.position + Vector3(
            float(model.ground_model.player_offset.x) * WORLD_SCALE,
            0.65,
            float(model.ground_model.player_offset.y) * WORLD_SCALE
        )
        var frame := model.ground_model.frame_code
        if ground_sprite_textures.has(frame):
            ground_player.texture = ground_sprite_textures[frame]
    elif in_interior:
        ground_player.position = _interior_pixel_to_world(model.interior_model.local_position)
        var frame := model.interior_model.frame_code
        if ground_sprite_textures.has(frame):
            ground_player.texture = ground_sprite_textures[frame]

    if encounter_entity != null:
        var entity_visible := (
            in_interior
            and model.encounter_model.entity_type != EncounterModel.TYPE_NONE
            and model.encounter_model.entity_position.x != 0
        )
        encounter_entity.visible = entity_visible
        if entity_visible:
            var entity_ptr := model.encounter_model.entity_sprite_pointer(
                model.interior_model.frame_code,
                model.computer_model.password_solved_this_trip
            )
            if encounter_sprite_textures.has(entity_ptr):
                encounter_entity.texture = encounter_sprite_textures[entity_ptr]
            encounter_entity.position = _interior_pixel_to_world(model.encounter_model.entity_position, 0.66)

    if stun_projectile != null:
        var projectile_visible := in_interior and model.encounter_model.projectile_active
        stun_projectile.visible = projectile_visible
        if projectile_visible:
            var projectile_ptr := model.encounter_model.projectile_sprite_pointer()
            if encounter_sprite_textures.has(projectile_ptr):
                stun_projectile.texture = encounter_sprite_textures[projectile_ptr]
            stun_projectile.position = _interior_pixel_to_world(model.encounter_model.projectile_position, 0.72)

    if supply_panel != null:
        supply_panel.visible = model.in_supply_menu()
        if model.in_supply_menu():
            _update_supply_hud()

    if terminal_panel != null:
        terminal_panel.visible = (
            in_interior
            and model.interior_model.terminal_open
            and not model.kard_offer_pending()
        )
        if terminal_panel.visible:
            _update_terminal_hud()

    if kard_offer_panel != null:
        kard_offer_panel.visible = in_interior and model.kard_offer_pending()
        if kard_offer_panel.visible:
            kard_offer_label.text = model.encounter_model.kard_offer_text(model.computer_model)

    for bolt_data in bolts:
        var bolt_node: MeshInstance3D = bolt_data["node"]
        bolt_node.visible = not in_endgame

    if touch_root != null:
        touch_root.visible = touch_controls_enabled
    if touch_terminal_panel != null:
        touch_terminal_panel.visible = (
            touch_controls_enabled
            and in_interior
            and model.interior_model.terminal_open
            and not model.kard_offer_pending()
        )
    if touch_kard_panel != null:
        touch_kard_panel.visible = touch_controls_enabled and in_interior and model.kard_offer_pending()

    _update_endgame_hud()

    var focus := ship.position
    if model.on_foot() or in_interior:
        focus = ground_player.position
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


func _update_supply_hud() -> void:
    var s = model.supply_model
    var left_mark := "<" if not s.side_right else " "
    var right_mark := ">" if s.side_right else " "
    var rows := [
        ["OXYGEN", s.ship_oxygen, s.carried_oxygen],
        ["STUN-GUNS", s.ship_stun_guns, s.carried_stun_guns],
        ["AMMUNITION", s.ship_ammunition, s.carried_ammunition],
        ["DRUGS", s.drugs, 0],
        ["SCIENTISTS", s.ship_scientists, s.carried_scientists],
    ]

    var text_value := "              SHIP SUPPLY                 TAKE AWAY\n\n"
    for i in range(rows.size()):
        var sel := i + 1
        var marker_left := left_mark if s.selection == sel else " "
        var marker_right := right_mark if s.selection == sel else " "
        text_value += "%s %-12s %3d        %s %-12s %3d\n" % [
            marker_left, rows[i][0], rows[i][1],
            marker_right, rows[i][0], rows[i][2]
        ]

    text_value += "\n"
    text_value += ("%s STANDARD KIT\n" % (left_mark if s.selection == SupplyModel.SEL_STANDARD_KIT else " "))
    text_value += "\n"
    text_value += "%s STAY ABOARD                 EXIT SHIP %s\n" % [
        left_mark if s.selection == SupplyModel.SEL_EXIT_ROW else " ",
        right_mark if s.selection == SupplyModel.SEL_EXIT_ROW else " "
    ]
    text_value += "\nArrows/WASD move cursor • Z selects on release\n"
    if s.last_message_code != SupplyModel.MSG_NONE:
        text_value += "\n" + SupplyModel.message_text(s.last_message_code)

    supply_label.text = text_value


func _update_hud() -> void:
    var target := model.target_velocity()
    var heading_degrees := float(model.heading) * 22.5
    var state_label := "FLIGHT"
    if model.endgame_active():
        state_label = "ENDING"
    elif model.in_supply_menu():
        state_label = "SUPPLY"
    elif model.in_interior():
        state_label = "INTERIOR / TERMINAL" if model.interior_model.terminal_open else "INTERIOR"
    elif model.on_foot():
        state_label = "GROUND"
    elif model.ground_transition_flag:
        state_label = "TRANSITION"

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
        + "Viewport macro    %d, %d\n" % [model.viewport_macro().x, model.viewport_macro().y]
        + "Score             %s   best %s %s\n" % [
            model.endgame_model.score_text(),
            model.endgame_model.high_score_text(),
            model.endgame_model.high_score_name
        ]
        + "$F4 ground flag  %s\n" % ("SET" if model.ground_transition_flag else "clear")
        + "$F3 flight mode  %s\n" % ("1" if model.flight_raster_mode else "0")
        + "$E049 init guard %s\n" % ("SET" if model.ground_initialized else "clear")
        + "State            %s\n\n" % state_label
        + "Arrows / WASD  flight / supply cursor / on-foot / interior movement\n"
        + "Z              fire / land / return to ship\n"
        + "ENTER          close active interior terminal\n"
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
