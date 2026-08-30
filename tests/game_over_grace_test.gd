extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_game()
	await physics_frame

	for stone in game.stones.duplicate():
		game._remove_stone_and_links(stone)
	await process_frame
	game.shape_groups.clear()
	game.active_stones.clear()
	game.active_group_id = -1

	var blocker: Node = game.StoneScene.new()
	blocker.setup(Color.WHITE, 999)
	blocker.global_position = Vector2(game.FIELD_CENTER_X, game.GAME_OVER_LINE_Y - 1.0)
	game.add_child(blocker)
	game.stones.append(blocker)

	game._update_game_over_state(4.9)
	var grace_ok: bool = (
		not game.is_game_over
		and game.limit_label.visible
		and game._limit_warning_alpha() > 0.0
	)
	blocker.global_position.y = game.GAME_OVER_LINE_Y + 1.0
	game._update_game_over_state(0.1)
	var reset_ok: bool = (
		not game.is_game_over
		and game.game_over_exposure == 0.0
		and game._limit_warning_alpha() == 0.0
	)
	blocker.global_position.y = game.GAME_OVER_LINE_Y - 1.0
	game._update_game_over_state(5.01)
	var timeout_ok: bool = game.is_game_over

	if grace_ok and reset_ok and timeout_ok:
		print("PASS: game over requires five continuous seconds above the limit")
		quit(0)
	else:
		push_error("FAIL: game-over grace period or reset behavior is incorrect")
		quit(1)
