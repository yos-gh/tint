extends SceneTree

const FIELD_LEFT := 170.0
const FIELD_RIGHT := 550.0
const STONE_HALF_SIZE := 19.0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var right_ok := await _exercise_wall(false)
	var left_ok := await _exercise_wall(true)
	if right_ok and left_ok:
		print("PASS: rotating pieces remained inside both side walls")
		quit(0)
	else:
		push_error("FAIL: a rotating piece crossed a side wall")
		quit(1)


func _exercise_wall(left: bool) -> bool:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	await physics_frame
	await physics_frame
	var tested_stones: Array = game.active_stones.duplicate()
	var extreme := INF if left else -INF
	for stone in tested_stones:
		extreme = minf(extreme, stone.global_position.x) if left else maxf(extreme, stone.global_position.x)
	var target := FIELD_LEFT + STONE_HALF_SIZE + 1.0 if left else FIELD_RIGHT - STONE_HALF_SIZE - 1.0
	var shift := target - extreme
	for stone in tested_stones:
		stone.global_position.x += shift
		stone.linear_velocity = Vector2.ZERO

	_set_key(KEY_A if left else KEY_D, true)
	_set_key(KEY_N if left else KEY_M, true)
	for frame in range(60):
		await physics_frame
	_set_key(KEY_A if left else KEY_D, false)
	_set_key(KEY_N if left else KEY_M, false)

	var stayed_inside := true
	for stone in tested_stones:
		if not is_instance_valid(stone):
			continue
		if stone.global_position.x < FIELD_LEFT - 1.0 or stone.global_position.x > FIELD_RIGHT + 1.0:
			stayed_inside = false
	game.queue_free()
	await process_frame
	return stayed_inside


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
