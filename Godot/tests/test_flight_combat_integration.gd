extends SceneTree

const FlightModel = preload("res://scripts/flight_model.gd")

var failures := 0


func _initialize() -> void:
    _test_natural_destructible_score_path()

    if failures == 0:
        print("PARALLAX FLIGHT COMBAT INTEGRATION: PASS")
        quit(0)
    else:
        push_error("PARALLAX FLIGHT COMBAT INTEGRATION: %d FAILURE(S)" % failures)
        quit(1)


func _check(condition: bool, message: String) -> void:
    if condition:
        print("PASS: " + message)
    else:
        failures += 1
        push_error("FAIL: " + message)


func _test_natural_destructible_score_path() -> void:
    var m := FlightModel.new()
    m.reset()
    m.heading = 0
    m.flight_height = 0x15

    var events := m.step(0, true, 9, 0, -1, true)
    _check(events["laser"], "held FIRE creates recovered single flight projectile")
    _check(m.flight_combat_model.projectile_active(), "FlightModel owns active recovered projectile state")

    var advance := m.advance_flight_projectile()
    _check(advance["moved"] and advance["needs_collision"], "next original-order frame advances projectile before collision")

    var samples: Array = []
    samples.resize(9)
    samples.fill(0x00)
    samples[4] = 0x48

    var hit := m.resolve_flight_projectile(samples)
    _check(hit["collision"] and hit["destructible"], "class-2 $48 world target enters destructible response")
    _check(hit["score_award"] == 15, "destructible world target produces authentic +15 score")
    _check(m.endgame_model.score_value == 15, "FlightModel feeds +15 into recovered six-digit score state")
    _check(m.endgame_model.score_text() == "000015", "score display is now 000015")
    _check(m.endgame_model.qualifies_for_ending_overlay(), "one authentic +15 hit beats initial CHRIX 000010 record")

    # The shot remains in its original $A1 impact animation rather than being
    # instantly cleared by the scoring bridge.
    _check(m.flight_combat_model.projectile_state == 0xA1, "scoring preserves recovered destructible impact animation")
