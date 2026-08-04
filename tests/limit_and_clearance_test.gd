extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame

	var tolerance: float = game.STONE_SIZE * 0.45
	var relaxed_pair_ok: bool = game._edge_pair_is_level(300.0, 300.0 + tolerance - 0.1)
	var outside_pair_rejected: bool = not game._edge_pair_is_level(300.0, 300.0 + tolerance + 0.1)

	var blocker := Node2D.new()
	game.add_child(blocker)
	game.stones.clear()
	game.stones.append(blocker)
	blocker.global_position = Vector2(game.SPAWN_POS.x, game.GAME_OVER_LINE_Y - 0.1)
	var above_line_blocks: bool = game._spawn_area_blocked()
	blocker.global_position.y = game.GAME_OVER_LINE_Y + 0.1
	var below_line_is_safe: bool = not game._spawn_area_blocked()

	if relaxed_pair_ok and outside_pair_rejected and above_line_blocks and below_line_is_safe:
		print("PASS: clear tolerance is relaxed and the visible limit matches game-over height")
		quit(0)
	else:
		push_error("FAIL: clear tolerance or game-over limit boundary is inconsistent")
		quit(1)
