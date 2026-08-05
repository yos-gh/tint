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
	game._spawn_piece("O")
	await physics_frame

	var tested_stones: Array = game.active_stones.duplicate()
	var center: Vector2 = game._center_of(tested_stones)
	for stone in tested_stones:
		stone.global_position += Vector2(game.FIELD_LEFT + 40.0, 300.0) - center
		stone.linear_velocity = Vector2.ZERO
	await physics_frame

	var initial_y: float = game._center_of(tested_stones).y
	_set_key(KEY_A, true)
	for frame in range(45):
		await physics_frame
	_set_key(KEY_A, false)
	var descent: float = game._center_of(tested_stones).y - initial_y

	if descent >= 80.0:
		print("PASS: wall input did not brake descent; distance = ", snappedf(descent, 0.1))
		quit(0)
	else:
		push_error("FAIL: pressing into wall slowed descent; distance = %.2f" % descent)
		quit(1)


func _set_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
