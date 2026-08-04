extends SceneTree

const MAX_EXPECTED_SPEED := 605.0
const MAX_EXPECTED_SPAN := 170.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	await physics_frame
	await physics_frame

	# Replace the random opening piece with a deterministic horizontal I piece.
	for stone in game.stones.duplicate():
		game._remove_stone_and_links(stone)
	await process_frame
	game.shape_groups.clear()
	game._spawn_piece("I")
	await physics_frame
	var tested_stones: Array = game.active_stones.duplicate()

	var center: Vector2 = game._center_of(tested_stones)
	for stone in tested_stones:
		stone.global_position += Vector2(360.0, 300.0) - center
		stone.linear_velocity = Vector2.ZERO

	# A tall obstacle catches the rotating tip and produces the high-error case
	# that previously caused the shape-memory forces to explode.
	var obstacle := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(46.0, 330.0)
	collision.shape = rectangle
	collision.position = Vector2(465.0, 350.0)
	obstacle.add_child(collision)
	game.add_child(obstacle)

	_set_key(KEY_D, true)
	_set_key(KEY_M, true)
	var maximum_speed := 0.0
	var maximum_span := 0.0
	var maximum_abs_x := 0.0
	var maximum_abs_y := 0.0
	var initial_center_y: float = game._center_of(tested_stones).y
	var minimum_center_y: float = initial_center_y
	var stayed_finite := true
	for frame in range(150):
		await physics_frame
		var current_center: Vector2 = game._center_of(tested_stones)
		minimum_center_y = minf(minimum_center_y, current_center.y)
		for stone in tested_stones:
			if not is_instance_valid(stone):
				continue
			maximum_speed = maxf(maximum_speed, stone.linear_velocity.length())
			maximum_abs_x = maxf(maximum_abs_x, absf(stone.global_position.x))
			maximum_abs_y = maxf(maximum_abs_y, absf(stone.global_position.y))
			if not is_finite(stone.global_position.x) or not is_finite(stone.global_position.y):
				stayed_finite = false
			if absf(stone.global_position.x) > 1000.0 or absf(stone.global_position.y) > 1300.0:
				stayed_finite = false
		for first in range(tested_stones.size()):
			for second in range(first + 1, tested_stones.size()):
				if is_instance_valid(tested_stones[first]) and is_instance_valid(tested_stones[second]):
					maximum_span = maxf(
						maximum_span,
						tested_stones[first].global_position.distance_to(tested_stones[second].global_position)
					)
	_set_key(KEY_D, false)
	_set_key(KEY_M, false)

	var maximum_lift := initial_center_y - minimum_center_y
	if (
		stayed_finite
		and maximum_speed <= MAX_EXPECTED_SPEED
		and maximum_span <= MAX_EXPECTED_SPAN
		and maximum_lift <= 12.0
	):
		print(
			"PASS: I-piece remained stable; max speed = ", snappedf(maximum_speed, 0.1),
			", max span = ", snappedf(maximum_span, 0.1),
			", max lift = ", snappedf(maximum_lift, 0.1),
			", max abs position = (", snappedf(maximum_abs_x, 0.1), ", ", snappedf(maximum_abs_y, 0.1), ")"
		)
		quit(0)
	else:
		push_error(
			"FAIL: I-piece became unstable; max speed = %s, max span = %s, max lift = %s, max abs position = (%s, %s)"
			% [maximum_speed, maximum_span, maximum_lift, maximum_abs_x, maximum_abs_y]
		)
		quit(1)


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
