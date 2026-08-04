extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var waiting_ok: bool = not game.is_started and game.active_stones.is_empty() and game.start_overlay.visible
	game.start_game()
	await physics_frame
	var started_ok: bool = game.is_started and game.active_stones.size() == 4 and not game.start_overlay.visible
	if waiting_ok and started_ok:
		print("PASS: title screen waits for input before spawning the first piece")
		quit(0)
	else:
		push_error("FAIL: title screen start transition is invalid")
		quit(1)
