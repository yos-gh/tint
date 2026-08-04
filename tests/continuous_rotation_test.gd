extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	await physics_frame
	await physics_frame

	for stone in game.stones.duplicate():
		game._remove_stone_and_links(stone)
	await process_frame
	game.shape_groups.clear()
	game._spawn_piece("I")
	await physics_frame

	var tested_stones: Array = game.active_stones.duplicate()
	var center: Vector2 = game._center_of(tested_stones)
	for stone in tested_stones:
		stone.global_position += Vector2(360.0, 350.0) - center
		stone.linear_velocity = Vector2.ZERO
		stone.gravity_scale = 0.0

	_set_key(KEY_M, true)
	var reversed_frames := 0
	var stationary_streak := 0
	var longest_stationary_streak := 0
	var previous_rotation: float = game._fitted_group_rotation(game.shape_groups[0])
	var accumulated_rotation := 0.0
	for frame in range(120):
		await physics_frame
		var group: Dictionary = game.shape_groups[0]
		var rotation: float = game._fitted_group_rotation(group)
		var step := angle_difference(previous_rotation, rotation)
		if step < -0.01:
			reversed_frames += 1
		if frame > 10 and absf(step) < 0.005:
			stationary_streak += 1
			longest_stationary_streak = maxi(longest_stationary_streak, stationary_streak)
		else:
			stationary_streak = 0
		accumulated_rotation += step
		previous_rotation = rotation
	_set_key(KEY_M, false)

	if reversed_frames <= 4 and longest_stationary_streak <= 3 and accumulated_rotation > PI * 1.5:
		print(
			"PASS: held rotation remained continuous; rotation = ",
			snappedf(accumulated_rotation, 0.01),
			", reversed frames = ", reversed_frames,
			", longest stationary streak = ", longest_stationary_streak
		)
		quit(0)
	else:
		push_error(
			"FAIL: held rotation stalled or jittered; stationary streak = %d, reversed frames = %d, rotation = %.2f"
			% [longest_stationary_streak, reversed_frames, accumulated_rotation]
		)
		quit(1)


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
