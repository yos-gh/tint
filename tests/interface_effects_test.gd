extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var touch_layer := game.get_node_or_null("TouchControls")
	var touch_actions := [
		game.INPUT_MOVE_LEFT,
		game.INPUT_MOVE_RIGHT,
		game.INPUT_DROP,
		game.INPUT_ROTATE_LEFT,
		game.INPUT_ROTATE_RIGHT,
	]
	var touch_ok: bool = touch_layer != null and touch_actions.all(func(action):
		var button := touch_layer.get_node_or_null(String(action))
		return (button is TouchScreenButton and button.action == action
			and button.visibility_mode == TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY)
	)

	game._show_multiplier_effect(16, Vector2(360, 400))
	var effect := game.get_node_or_null("ScoreMultiplier")
	var effect_ok: bool = effect is Label and effect.text == "x16" and effect.z_index > 100

	if touch_ok and effect_ok:
		print("PASS: touchscreen controls and score multiplier effect are configured")
		quit(0)
	else:
		push_error("FAIL: touchscreen controls or score multiplier effect is missing")
		quit(1)
