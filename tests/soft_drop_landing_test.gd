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

	# Vertical motion is no longer recorded as removable input velocity. When
	# lock delay removes horizontal control, an existing fall or collision
	# response must therefore remain unchanged and cannot become upward recoil.
	for stone in tested_stones:
		stone.linear_velocity = Vector2(game.MOVE_SPEED, 24.0)
	game.active_input_velocity = Vector2(game.MOVE_SPEED, 0.0)
	game._remove_active_input_velocity()
	var released_velocity: Vector2 = game._average_active_velocity()

	if absf(released_velocity.x) <= 0.01 and is_equal_approx(released_velocity.y, 24.0):
		print(
			"PASS: locking removes horizontal input without altering vertical motion; velocity = ",
			released_velocity
		)
		quit(0)
	else:
		push_error(
			"FAIL: locking altered vertical motion; velocity=%s" % released_velocity
		)
		quit(1)
