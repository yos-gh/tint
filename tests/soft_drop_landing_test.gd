extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	await physics_frame
	await physics_frame

	var tested_stones: Array = game.active_stones.duplicate()
	for stone in tested_stones:
		stone.gravity_scale = 0.0
		stone.linear_velocity = Vector2.ZERO

	# Reproduce the lock-delay edge case from the recording: the floor has
	# already stopped the stones, but the soft-drop command is still recorded.
	game.active_input_velocity = Vector2(0.0, game.SOFT_DROP_SPEED)
	game._remove_active_input_velocity()
	var stopped_release_y: float = game._average_active_velocity().y

	# In free fall, only the remaining downward command should be removed.
	for stone in tested_stones:
		stone.linear_velocity = Vector2(0.0, game.SOFT_DROP_SPEED * 0.75)
	game.active_input_velocity = Vector2(0.0, game.SOFT_DROP_SPEED)
	game._remove_active_input_velocity()
	var moving_release_y: float = game._average_active_velocity().y

	if stopped_release_y >= -0.01 and absf(moving_release_y) <= 0.01:
		print(
			"PASS: releasing soft drop cannot create upward rebound; velocities = ",
			snappedf(stopped_release_y, 0.01), ", ", snappedf(moving_release_y, 0.01)
		)
		quit(0)
	else:
		push_error(
			"FAIL: soft-drop removal created rebound; stopped=%.2f moving=%.2f"
			% [stopped_release_y, moving_release_y]
		)
		quit(1)
