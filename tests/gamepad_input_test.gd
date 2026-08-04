extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var mappings_ok := (
		_has_axis(game.INPUT_MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)
		and _has_button(game.INPUT_MOVE_LEFT, JOY_BUTTON_DPAD_LEFT)
		and _has_axis(game.INPUT_MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)
		and _has_button(game.INPUT_MOVE_RIGHT, JOY_BUTTON_DPAD_RIGHT)
		and _has_axis(game.INPUT_DROP, JOY_AXIS_LEFT_Y, 1.0)
		and _has_button(game.INPUT_DROP, JOY_BUTTON_DPAD_DOWN)
		and _has_button(game.INPUT_ROTATE_LEFT, JOY_BUTTON_A)
		and _has_button(game.INPUT_ROTATE_LEFT, JOY_BUTTON_X)
		and _has_button(game.INPUT_ROTATE_RIGHT, JOY_BUTTON_B)
		and _has_button(game.INPUT_ROTATE_RIGHT, JOY_BUTTON_Y)
	)
	var deadzones_ok := (
		is_equal_approx(InputMap.action_get_deadzone(game.INPUT_MOVE_LEFT), game.GAMEPAD_DEADZONE)
		and is_equal_approx(InputMap.action_get_deadzone(game.INPUT_DROP), game.GAMEPAD_DEADZONE)
	)

	if mappings_ok and deadzones_ok:
		print("PASS: D-pad, left stick, and face-button gamepad mappings are configured")
		quit(0)
	else:
		push_error("FAIL: gamepad input mappings are incomplete")
		quit(1)


func _has_button(action: StringName, button: JoyButton) -> bool:
	return InputMap.action_get_events(action).any(func(event):
		return event is InputEventJoypadButton and event.button_index == button
	)


func _has_axis(action: StringName, axis: JoyAxis, direction: float) -> bool:
	return InputMap.action_get_events(action).any(func(event):
		return (event is InputEventJoypadMotion and event.axis == axis
			and signf(event.axis_value) == signf(direction))
	)
