extends SceneTree


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var floor_multiplier: int = game._height_score_multiplier(Vector2(170, 855), Vector2(550, 855))
	var top_multiplier: int = game._height_score_multiplier(Vector2(170, 95), Vector2(550, 95))
	if floor_multiplier == 1 and top_multiplier == 16:
		print("PASS: height score multiplier maps floor x1 to top x16")
		quit(0)
	else:
		push_error("FAIL: expected floor x1/top x16, got x%s/x%s" % [floor_multiplier, top_multiplier])
		quit(1)
