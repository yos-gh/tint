extends SceneTree

const RELEASE_TOLERANCE := 1.0


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
	game._spawn_piece("O")
	await physics_frame

	var tested_stones: Array = game.active_stones.duplicate()
	for stone in tested_stones:
		stone.gravity_scale = 0.0
		stone.linear_velocity = Vector2.ZERO

	_set_key(KEY_D, true)
	await physics_frame
	await physics_frame
	var moving_right: bool = _average_velocity(tested_stones).x > game.MOVE_SPEED * 0.8
	_set_key(KEY_D, false)
	await physics_frame
	await physics_frame
	var horizontal_release: float = absf(_average_velocity(tested_stones).x)

	_set_key(KEY_S, true)
	await physics_frame
	await physics_frame
	var dropping: bool = _average_velocity(tested_stones).y > game.SOFT_DROP_SPEED * 0.8
	_set_key(KEY_S, false)
	await physics_frame
	await physics_frame
	var vertical_release: float = absf(_average_velocity(tested_stones).y)

	if (
		moving_right and dropping
		and horizontal_release <= RELEASE_TOLERANCE
		and vertical_release <= RELEASE_TOLERANCE
	):
		print(
			"PASS: movement input stops without inertia; released velocity = (",
			snappedf(horizontal_release, 0.01), ", ", snappedf(vertical_release, 0.01), ")"
		)
		quit(0)
	else:
		push_error(
			"FAIL: input velocity persisted; move=%s drop=%s released=(%.2f, %.2f)"
			% [moving_right, dropping, horizontal_release, vertical_release]
		)
		quit(1)


func _average_velocity(nodes: Array) -> Vector2:
	var velocity := Vector2.ZERO
	for node in nodes:
		velocity += node.linear_velocity
	return velocity / maxf(float(nodes.size()), 1.0)


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
