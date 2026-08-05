extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var touch_layer := game.get_node_or_null("TouchControls")
	var rotation_actions := [
		game.INPUT_ROTATE_LEFT,
		game.INPUT_ROTATE_RIGHT,
	]
	var touch_ok: bool = touch_layer != null and rotation_actions.all(func(action):
		var button := touch_layer.get_node_or_null(String(action))
		return (button is TouchScreenButton and button.action == action
			and button.visibility_mode == TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY)
	)
	var virtual_stick := touch_layer.get_node_or_null("VirtualStick") if touch_layer else null
	var analog_ok: bool = virtual_stick is TintVirtualStick
	if analog_ok:
		virtual_stick.visible = true
		var press := InputEventScreenTouch.new()
		press.index = 7
		press.pressed = true
		press.position = virtual_stick.global_position + Vector2(20, 20)
		virtual_stick._input(press)
		var drag := InputEventScreenDrag.new()
		drag.index = 7
		drag.position = virtual_stick.global_position + Vector2(34, 28)
		virtual_stick._input(drag)
		analog_ok = virtual_stick.value.x > 0.45 and virtual_stick.value.y > 0.35
		press.pressed = false
		virtual_stick._input(press)
		analog_ok = analog_ok and virtual_stick.value == Vector2.ZERO and virtual_stick.touch_index == -1

	game._show_multiplier_effect(16, Vector2(360, 400))
	var effect := game.get_node_or_null("ScoreMultiplier")
	var effect_ok: bool = effect is Label and effect.text == "x16" and effect.z_index > 100

	if touch_ok and analog_ok and effect_ok:
		print("PASS: virtual analog stick, rotation buttons, and score effect are configured")
		quit(0)
	else:
		push_error("FAIL: touchscreen controls or score multiplier effect is missing")
		quit(1)
