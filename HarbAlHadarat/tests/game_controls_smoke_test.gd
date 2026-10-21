extends SceneTree

const GameScene: PackedScene = preload("res://scenes/game.tscn")

const EXPECTED_BUTTONS := {
    "هجوم": "_player_attack",
    "ركض": "_toggle_running",
    "صدّ": "_toggle_block",
    "تفادٍ": "_start_dodge",
    "اندفاع": "_start_dash",
    "الشظية": "_use_shard",
}


func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("GAME_CONTROLS_FAIL: " + message)


func _run() -> void:
    var game := GameScene.instantiate()
    if game == null:
        _fail("could not instantiate scenes/game.tscn")
        quit(1)
        return

    get_root().add_child(game)
    await process_frame

    # Force gameplay state so a story intro cannot block control testing.
    game.state = 0
    var failures: PackedStringArray = PackedStringArray()
    var callbacks: Dictionary = {}

    for value in game.pads:
        var entry: Dictionary = value
        var panel: Control = entry.get("ctrl") as Control
        if panel == null or panel.get_child_count() == 0:
            continue
        var label: Label = panel.get_child(0) as Label
        if label == null:
            continue
        var callback: Callable = entry.get("cb", Callable())
        callbacks[String(label.text)] = String(callback.get_method())

    for button_name in EXPECTED_BUTTONS:
        if not callbacks.has(button_name):
            failures.append("missing mobile control: " + String(button_name))
        elif String(callbacks[button_name]) != String(EXPECTED_BUTTONS[button_name]):
            failures.append(
                String(button_name) + " is connected to "
                + String(callbacks[button_name]) + ", expected "
                + String(EXPECTED_BUTTONS[button_name])
            )

    # A front-facing guard should reduce a 20-point hit to 5; a rear hit should not.
    game.player_hp = 100.0
    game.invuln = 0.0
    game.blocking = true
    game.player_yaw = PI
    var front_attacker: Vector3 = game.player.global_position + Vector3(0.0, 0.0, -1.0)
    game._damage_player(20.0, front_attacker)
    if absf(game.player_hp - 95.0) > 0.01:
        failures.append("front guard did not reduce incoming damage by 75 percent")

    game.player_hp = 100.0
    game.invuln = 0.0
    var rear_attacker: Vector3 = game.player.global_position + Vector3(0.0, 0.0, 1.0)
    game._damage_player(20.0, rear_attacker)
    if absf(game.player_hp - 80.0) > 0.01:
        failures.append("guard incorrectly reduced damage from behind")

    game.blocking = false
    game.running = false
    game.attack_t = 0.0
    game.dodge_t = 0.0
    game.dash_t = 0.0
    game.invuln = 0.0

    game._toggle_block()
    if not game.blocking:
        failures.append("block control did not activate guarding")

    game._start_dodge()
    if game.blocking or game.dodge_t <= 0.0 or game.invuln < 0.3:
        failures.append("dodge did not interrupt guard and grant its evasion window")

    game.dodge_t = 0.0
    game.invuln = 0.0
    game._start_dash()
    if game.dash_t <= 0.0:
        failures.append("dash control did not start the dash state")

    game.dash_t = 0.0
    game._toggle_running()
    game._toggle_block()
    if not game.blocking or game.running:
        failures.append("guard control did not disable running")

    game.queue_free()
    await process_frame

    if not failures.is_empty():
        for failure in failures:
            _fail(String(failure))
        _fail(str(failures.size()) + " gameplay-control failure(s)")
        quit(1)
        return

    print("GAME_CONTROLS_PASS: mobile callbacks, guard mitigation, dodge, dash, and run transitions verified.")
    quit(0)
