extends SceneTree

const MAX_EXPECTED_SPAN := 170.0


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

	_set_key(KEY_S, true)
	_set_key(KEY_M, true)
	var previous_rotation: float = game._fitted_group_rotation(game.shape_groups[0])
	var accumulated_rotation := 0.0
	var reversed_frames := 0
	var maximum_span := 0.0
	var maximum_shape_error := 0.0
	var longest_stall := 0
	var stall_frames := 0
	for frame in range(300):
		await physics_frame
		# Keep the test piece away from the bowl while preserving its shared
		# downward velocity and all relative motion caused by soft drop.
		var current_center: Vector2 = game._center_of(tested_stones)
		for stone in tested_stones:
			stone.global_position.y += 350.0 - current_center.y
		var rotation: float = game._fitted_group_rotation(game.shape_groups[0])
		maximum_shape_error = maxf(maximum_shape_error, game._shape_error(game.shape_groups[0]))
		var step := angle_difference(previous_rotation, rotation)
		if step < -0.01:
			reversed_frames += 1
		if frame > 20 and absf(step) < 0.005:
			stall_frames += 1
			longest_stall = maxi(longest_stall, stall_frames)
		else:
			stall_frames = 0
		accumulated_rotation += step
		previous_rotation = rotation
		for first in range(tested_stones.size()):
			for second in range(first + 1, tested_stones.size()):
				maximum_span = maxf(
					maximum_span,
					tested_stones[first].global_position.distance_to(tested_stones[second].global_position)
				)
	_set_key(KEY_S, false)
	_set_key(KEY_M, false)

	if (
		accumulated_rotation > TAU * 2.0
		and reversed_frames <= 6
		and longest_stall <= 3
		and maximum_span <= MAX_EXPECTED_SPAN
	):
		print(
			"PASS: soft-drop rotation stayed smooth for multiple turns; rotation = ",
			snappedf(accumulated_rotation, 0.01), ", max span = ", snappedf(maximum_span, 0.1)
		)
		quit(0)
	else:
		push_error(
			"FAIL: soft-drop rotation degraded; rotation = %.2f, reversed = %d, stall = %d, span = %.2f, error = %.2f"
			% [accumulated_rotation, reversed_frames, longest_stall, maximum_span, maximum_shape_error]
		)
		quit(1)


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
