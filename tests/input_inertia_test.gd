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
	var drop_velocity: float = _average_velocity(tested_stones).y
	var dropping: bool = drop_velocity > 0.0
	_set_key(KEY_S, false)
	await physics_frame
	await physics_frame
	var retained_drop_velocity: float = _average_velocity(tested_stones).y

	if (
		moving_right and dropping
		and horizontal_release <= RELEASE_TOLERANCE
		and retained_drop_velocity > 0.0
	):
		print(
			"PASS: horizontal input stops on release while soft-drop momentum remains; values = (",
			snappedf(horizontal_release, 0.01), ", ", snappedf(retained_drop_velocity, 0.01), ")"
		)
		quit(0)
	else:
		push_error(
			"FAIL: hybrid movement behavior is incorrect; move=%s drop=%s released=(%.2f, %.2f)"
			% [moving_right, dropping, horizontal_release, retained_drop_velocity]
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
