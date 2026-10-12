extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")

var failures := 0


func _initialize() -> void:
    _test_heading_table()
    _test_input_repeat()
    _test_height_controls()
    _test_velocity_convergence()
    _test_landing_regime()
    _test_laser_event()

    if failures == 0:
        print("PARALLAX FLIGHT TESTS: PASS")
        quit(0)
    else:
        push_error("PARALLAX FLIGHT TESTS: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _test_heading_table() -> void:
    var m := FlightModel.new()
    _check(m.heading == 4, "default heading matches recovered post-startup state")
    _check(m.flight_height == 0x15, "default height matches recovered post-startup state")
    m.heading = 0
    _check(m.target_velocity() == Vector2i(0, 2), "heading 0 recovered vector is (0,2)")
    m.heading = 4
    _check(m.target_velocity() == Vector2i(-2, 0), "heading 4 recovered vector is (-2,0)")
    m.heading = 8
    _check(m.target_velocity() == Vector2i(0, -2), "heading 8 recovered vector is (0,-2)")
    m.heading = 12
    _check(m.target_velocity() == Vector2i(2, 0), "heading 12 recovered vector is (2,0)")
    m.speed_mode = 1
    m.heading = 2
    _check(m.target_velocity() == Vector2i(-3, 3), "mode 1 recovered heading vector is exact")


func _test_input_repeat() -> void:
    var m := FlightModel.new()
    m.heading = 0
    for i in range(3):
        m.step(0x01, false, 0)
    _check(m.heading == 0, "turn input waits for four-frame repeat threshold")
    m.step(0x01, false, 0)
    _check(m.heading == 1, "RIGHT advances one of sixteen headings on frame four")


func _test_height_controls() -> void:
    var m := FlightModel.new()
    var start_height := m.flight_height
    m.step(0x04, false, 0)
    _check(m.flight_height == start_height + 1, "DOWN climbs by one original height unit")
    m.step(0x08, false, 0)
    _check(m.flight_height == start_height, "UP dives by one original height unit")


func _test_velocity_convergence() -> void:
    var m := FlightModel.new()
    m.heading = 4
    for i in range(7):
        m.step(0, false, 0)
    _check(m.vx_hi == -2, "fixed-point X velocity converges to recovered heading target")
    _check(m.vy_hi == 0, "orthogonal axis remains at recovered target")


func _test_landing_regime() -> void:
    var m := FlightModel.new()
    m.flight_height = FlightModel.LANDING_HEIGHT
    m.landing_gear = true

    m.step(0, false, 9)
    _check(m.landing_ready, "gear + landing height + 3x3 clear footprint enables landing regime")
    _check(m.acceleration_step == FlightModel.ACCEL_LANDING, "landing regime selects recovered $0C acceleration")
    _check(m.vx_hi == 0 and m.vy_hi == 0, "recovered landing brake holds zero integer velocity")

    var events := m.step(0, true, 9)
    _check(events["landed"] and m.landed, "fire commits flight-to-ground transition when landing-ready and stopped")


func _test_laser_event() -> void:
    var m := FlightModel.new()
    var events := m.step(0, true, 0)
    _check(events["laser"], "fire produces laser event outside landing regime")
