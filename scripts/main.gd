extends Node2D

const StoneScene = preload("res://scripts/stone.gd")

const STONE_SIZE := 38.0
const FIELD_COLUMNS := 10
const FIELD_ROWS := 20
const FIELD_CENTER_X := 360.0
const FIELD_LEFT := FIELD_CENTER_X - STONE_SIZE * FIELD_COLUMNS * 0.5
const FIELD_RIGHT := FIELD_CENTER_X + STONE_SIZE * FIELD_COLUMNS * 0.5
const FIELD_TOP := 95.0
const BOWL_EDGE_Y := FIELD_TOP + STONE_SIZE * FIELD_ROWS
const BOWL_DEPTH := 60.0
const PIECE_GAP := 42.0
const SPAWN_POS := Vector2(360.0, 135.0)
const GAME_OVER_LINE_Y := FIELD_TOP + 105.0
const SPAWN_BLOCK_HALF_WIDTH := 125.0
const PAIR_HEIGHT_TOLERANCE := STONE_SIZE * 0.45
const CLEAR_BAND_HALF_WIDTH := STONE_SIZE * 0.45

const MOVE_FORCE := 2750.0
const SOFT_DROP_FORCE := 2800.0
const TARGET_ROTATION_SPEED := TAU # One full turn per second.

# Shape springs use the upper end of Godot's practical stiffness range.
# The weaker all-pair support springs resist folding while still allowing
# the tetromino to squash a little under pressure.
const EDGE_SPRING_STIFFNESS := 64.0
const SUPPORT_SPRING_STIFFNESS := 48.0
const EDGE_SPRING_DAMPING := 12.0
const SUPPORT_SPRING_DAMPING := 8.0

# Springs provide local squash and bounce. This proportional-derivative shape
# memory prevents the whole tetromino from folding flat under a pile.
const SHAPE_MEMORY_STIFFNESS := 3400.0
const SHAPE_MEMORY_DAMPING := 55.0
# Keep small errors stiff, but saturate large collision errors before one
# physics tick can inject enough energy to launch a stone across the screen.
const SHAPE_MEMORY_MAX_FORCE := 20000.0
const SETTLED_SHAPE_STIFFNESS := 1100.0
const SETTLED_SHAPE_DAMPING := 38.0
const SETTLED_SHAPE_MAX_FORCE := 6000.0
const ROTATION_DEFORMATION_LIMIT := STONE_SIZE * 0.40
const LOCK_DELAY := 0.3
const NEAR_CLEAR_SCAN_INTERVAL := 0.12
const MIN_HEIGHT_MULTIPLIER := 1
const MAX_HEIGHT_MULTIPLIER := 16

const SHAPES := {
	"I": [Vector2(-1.5, 0), Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(1.5, 0)],
	"O": [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5)],
	"T": [Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)],
	"L": [Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	"J": [Vector2(-1, 1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0)],
	"S": [Vector2(-1, 1), Vector2(0, 1), Vector2(0, 0), Vector2(1, 0)],
	"Z": [Vector2(-1, 0), Vector2(0, 0), Vector2(0, 1), Vector2(1, 1)],
}

const COLORS := [
	Color("55d6be"), Color("ff6b8a"), Color("ffd166"),
	Color("6c9cff"), Color("bd7cff"), Color("ff9f55"), Color("72e06a")
]

var stones: Array[Node] = []
var links: Array[Dictionary] = []
var shape_groups: Array[Dictionary] = []
var active_stones: Array[Node] = []
var active_group_id := -1
var active_age := 0.0
var settle_age := 0.0
var group_counter := 0
var score := 0
var cleared := 0
var last_height_multiplier := 1
var is_game_over := false
var elimination_cooldown := 0.0
var near_clear_cooldown := 0.0
var flash_lines: Array[Dictionary] = []

var score_label: Label
var status_label: Label
var help_label: Label
var start_overlay: ColorRect
var is_started := false


func _ready() -> void:
	randomize()
	_build_world()
	_build_ui()
	_build_start_overlay()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_started and event is InputEventKey and event.pressed and not event.echo:
		start_game()
		get_viewport().set_input_as_handled()


func start_game() -> void:
	if is_started:
		return
	is_started = true
	start_overlay.visible = false
	_spawn_piece()


func _build_world() -> void:
	var boundary := StaticBody2D.new()
	boundary.name = "Boundary"
	add_child(boundary)

	_add_wall(boundary, FIELD_LEFT, true)
	_add_wall(boundary, FIELD_RIGHT, false)

	var previous := Vector2(FIELD_LEFT, _bowl_y(FIELD_LEFT))
	for index in range(1, 25):
		var x := lerpf(FIELD_LEFT, FIELD_RIGHT, float(index) / 24.0)
		var current := Vector2(x, _bowl_y(x))
		_add_segment(boundary, previous, current)
		previous = current


func _add_wall(body: StaticBody2D, inner_x: float, is_left: bool) -> void:
	const WALL_THICKNESS := 48.0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	# Extend well beyond the viewport so a collision cannot launch a stone over
	# the wall's top endpoint and around the outside of the field.
	var top := FIELD_TOP - 2000.0
	var bottom := BOWL_EDGE_Y + 2000.0
	rectangle.size = Vector2(WALL_THICKNESS, bottom - top)
	collision.shape = rectangle
	# Keep the visible field width unchanged; all wall thickness extends outward.
	collision.position = Vector2(
		inner_x + (-WALL_THICKNESS * 0.5 if is_left else WALL_THICKNESS * 0.5),
		(top + bottom) * 0.5
	)
	body.add_child(collision)


func _add_segment(body: StaticBody2D, from: Vector2, to: Vector2) -> void:
	var collision := CollisionShape2D.new()
	var segment := SegmentShape2D.new()
	segment.a = from
	segment.b = to
	collision.shape = segment
	body.add_child(collision)


func _build_ui() -> void:
	var title := Label.new()
	title.text = "T I N T"
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color("e8efff"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "TINT is not Tetris"
	subtitle.position = Vector2(31, 57)
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color("8292b8"))
	add_child(subtitle)

	score_label = Label.new()
	score_label.position = Vector2(410, 27)
	score_label.size = Vector2(275, 35)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.add_theme_font_size_override("font_size", 20)
	add_child(score_label)

	status_label = Label.new()
	status_label.position = Vector2(120, 455)
	status_label.size = Vector2(480, 100)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", Color("fff3c4"))
	status_label.add_theme_constant_override("outline_size", 7)
	status_label.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.06, 0.98))
	status_label.z_index = 100
	status_label.visible = false
	add_child(status_label)

	help_label = Label.new()
	help_label.text = "A / D or ← / →  MOVE     S or ↓  DROP     N / M  ROTATE"
	help_label.position = Vector2(70, 926)
	help_label.size = Vector2(580, 24)
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color("91a0c5"))
	add_child(help_label)
	_update_ui()


func _build_start_overlay() -> void:
	start_overlay = ColorRect.new()
	start_overlay.position = Vector2.ZERO
	start_overlay.size = Vector2(720, 960)
	start_overlay.color = Color(0.025, 0.035, 0.06, 0.97)
	start_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.z_index = 200
	add_child(start_overlay)

	var start_title := _start_label("T I N T", Vector2(0, 270), Vector2(720, 80), 56, Color("e8efff"))
	start_overlay.add_child(start_title)
	var start_subtitle := _start_label("TINT is not Tetris", Vector2(0, 345), Vector2(720, 34), 18, Color("8292b8"))
	start_overlay.add_child(start_subtitle)
	var prompt := _start_label("PRESS ANY KEY", Vector2(0, 470), Vector2(720, 50), 24, Color("fff3c4"))
	start_overlay.add_child(prompt)
	var controls := _start_label(
		"A / D  MOVE     S  DROP     N / M  ROTATE",
		Vector2(0, 555), Vector2(720, 30), 14, Color("91a0c5")
	)
	start_overlay.add_child(controls)


func _start_label(text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _physics_process(delta: float) -> void:
	if not is_started:
		return
	if Input.is_key_pressed(KEY_R) and is_game_over:
		get_tree().reload_current_scene()
		return
	if is_game_over:
		return

	active_age += delta
	elimination_cooldown -= delta
	near_clear_cooldown -= delta
	_prune_invalid_stones()
	_control_active_piece(delta)
	_apply_shape_memory()
	_update_active_piece(delta)

	if elimination_cooldown <= 0.0 and active_stones.is_empty():
		elimination_cooldown = 0.35
		_check_for_elimination()
	if near_clear_cooldown <= 0.0:
		near_clear_cooldown = NEAR_CLEAR_SCAN_INTERVAL
		_update_near_clear_highlights()

	for flash in flash_lines:
		flash["life"] -= delta
	flash_lines = flash_lines.filter(func(item): return item["life"] > 0.0)
	queue_redraw()


func _control_active_piece(delta: float) -> void:
	if active_stones.is_empty():
		return
	var horizontal := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1.0
	if horizontal < 0.0 and active_stones.any(func(stone): return stone.touching_left_wall):
		horizontal = 0.0
	elif horizontal > 0.0 and active_stones.any(func(stone): return stone.touching_right_wall):
		horizontal = 0.0
	var dropping := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var rotate_dir := 0.0
	if Input.is_key_pressed(KEY_M):
		rotate_dir += 1.0
	if Input.is_key_pressed(KEY_N):
		rotate_dir -= 1.0

	# Advance a fixed-radius target layout instead of applying tangential force
	# at the stones' current radius. If an impact deforms the piece too far,
	# pause the requested rotation until shape memory has pulled it together.
	for group in shape_groups:
		if group["id"] != active_group_id:
			continue
		var shape_error := _shape_error(group)
		if rotate_dir != 0.0 and shape_error <= ROTATION_DEFORMATION_LIMIT:
			group["target_rotation"] = float(group["target_rotation"]) + rotate_dir * TARGET_ROTATION_SPEED * delta
			group["target_angular_velocity"] = rotate_dir * TARGET_ROTATION_SPEED
		else:
			group["target_angular_velocity"] = 0.0
		break

	for stone in active_stones:
		if not is_instance_valid(stone):
			continue
		stone.apply_central_force(Vector2(horizontal * MOVE_FORCE, SOFT_DROP_FORCE if dropping else 0.0))

	# Rotation must not become translational lift. Remove only the shared upward
	# velocity of the piece; relative velocities that form the rotation remain.
	if rotate_dir != 0.0:
		var average_vertical_velocity := 0.0
		var valid_count := 0
		for stone in active_stones:
			if is_instance_valid(stone):
				average_vertical_velocity += stone.linear_velocity.y
				valid_count += 1
		average_vertical_velocity /= maxf(float(valid_count), 1.0)
		if average_vertical_velocity < 0.0:
			for stone in active_stones:
				if is_instance_valid(stone):
					stone.linear_velocity.y -= average_vertical_velocity


func _shape_error(group: Dictionary) -> float:
	var group_stones: Array = group["stones"].filter(
		func(stone): return is_instance_valid(stone) and not stone.is_queued_for_deletion()
	)
	if group_stones.is_empty():
		return 0.0
	var current_center := Vector2.ZERO
	var reference_center := Vector2.ZERO
	for stone in group_stones:
		current_center += stone.global_position
		reference_center += group["offsets"][stone.get_instance_id()]
	current_center /= float(group_stones.size())
	reference_center /= float(group_stones.size())
	var maximum_error := 0.0
	var target_rotation: float = group["target_rotation"]
	for stone in group_stones:
		var reference: Vector2 = group["offsets"][stone.get_instance_id()] - reference_center
		var target: Vector2 = current_center + reference.rotated(target_rotation)
		maximum_error = maxf(maximum_error, stone.global_position.distance_to(target))
	return maximum_error


func _update_active_piece(delta: float) -> void:
	if active_stones.is_empty():
		return

	# Start the lock delay as soon as any stone is supported by the bowl or by
	# a stone from an older piece. Side-wall and same-piece contacts do not lock.
	var supported := active_stones.any(func(stone): return stone.is_supported)
	if supported:
		settle_age += delta
	else:
		settle_age = 0.0

	if settle_age >= LOCK_DELAY:
		active_group_id = -1
		active_stones.clear()
		settle_age = 0.0
		_check_for_elimination()
		if not is_game_over:
			_spawn_piece.call_deferred()


func _spawn_piece(shape_override: String = "") -> void:
	if _spawn_area_blocked():
		_game_over()
		return
	group_counter += 1
	active_group_id = group_counter
	active_age = 0.0
	settle_age = 0.0
	var names := SHAPES.keys()
	var shape_name: String = shape_override if SHAPES.has(shape_override) else names[randi() % names.size()]
	var offsets: Array = SHAPES[shape_name]
	var color: Color = COLORS[randi() % COLORS.size()]
	var new_stones: Array[Node] = []
	var reference_offsets := {}

	for offset in offsets:
		var stone := StoneScene.new()
		stone.name = "Stone_%d_%d" % [group_counter, new_stones.size()]
		stone.position = SPAWN_POS + offset * PIECE_GAP
		stone.setup(color, group_counter)
		add_child(stone)
		stones.append(stone)
		new_stones.append(stone)
		reference_offsets[stone.get_instance_id()] = offset * PIECE_GAP

	# Every pair is softly connected. Edge springs carry most of the shape,
	# while weaker diagonal springs keep it recognizable without making it rigid.
	for first in range(new_stones.size()):
		for second in range(first + 1, new_stones.size()):
			var distance: float = new_stones[first].position.distance_to(new_stones[second].position)
			var adjacent := distance < PIECE_GAP * 1.15
			_add_spring(new_stones[first], new_stones[second], distance, adjacent)
	shape_groups.append({
		"id": group_counter,
		"stones": new_stones.duplicate(),
		"offsets": reference_offsets,
		"target_rotation": 0.0,
		"target_angular_velocity": 0.0,
	})
	active_stones = new_stones


func _apply_shape_memory() -> void:
	for group_index in range(shape_groups.size() - 1, -1, -1):
		var group := shape_groups[group_index]
		var group_stones: Array = group["stones"].filter(
			func(stone): return is_instance_valid(stone) and not stone.is_queued_for_deletion()
		)
		group["stones"] = group_stones
		if group_stones.size() < 2:
			shape_groups.remove_at(group_index)
			continue

		var current_center := Vector2.ZERO
		var reference_center := Vector2.ZERO
		var average_velocity := Vector2.ZERO
		for stone in group_stones:
			current_center += stone.global_position
			reference_center += group["offsets"][stone.get_instance_id()]
			average_velocity += stone.linear_velocity
		current_center /= float(group_stones.size())
		reference_center /= float(group_stones.size())
		average_velocity /= float(group_stones.size())

		# Preserve rigid-body rotation while damping only motion that deforms the
		# remembered shape. Damping all center-relative velocity would fight the
		# player's rotation input and make the piece feel sluggish.
		var group_angular_velocity := 0.0
		var group_moment := 0.0
		for stone in group_stones:
			var current: Vector2 = stone.global_position - current_center
			group_angular_velocity += current.cross(stone.linear_velocity - average_velocity)
			group_moment += current.length_squared()
		group_angular_velocity /= maxf(group_moment, 0.001)

		# Find the rotation that best aligns the remembered layout with the
		# current one. The piece may rotate freely while retaining its silhouette.
		var dot_sum := 0.0
		var cross_sum := 0.0
		for stone in group_stones:
			var reference: Vector2 = group["offsets"][stone.get_instance_id()] - reference_center
			var current: Vector2 = stone.global_position - current_center
			dot_sum += reference.dot(current)
			cross_sum += reference.cross(current)
		var fitted_rotation := atan2(cross_sum, dot_sum)
		var controlled: bool = group["id"] == active_group_id
		var target_rotation: float = group["target_rotation"] if controlled else fitted_rotation
		var target_angular_velocity: float = group["target_angular_velocity"] if controlled else group_angular_velocity
		var supported: bool = group_stones.any(func(stone): return stone.is_supported)
		var use_settled_gains: bool = not controlled or supported
		var stiffness: float = SETTLED_SHAPE_STIFFNESS if use_settled_gains else SHAPE_MEMORY_STIFFNESS
		var damping: float = SETTLED_SHAPE_DAMPING if use_settled_gains else SHAPE_MEMORY_DAMPING
		var maximum_force: float = SETTLED_SHAPE_MAX_FORCE if use_settled_gains else SHAPE_MEMORY_MAX_FORCE

		var pending_forces: Array[Vector2] = []
		var force_sum := Vector2.ZERO
		for stone in group_stones:
			var reference: Vector2 = group["offsets"][stone.get_instance_id()] - reference_center
			var target_relative := reference.rotated(target_rotation)
			var target: Vector2 = current_center + target_relative
			var position_error: Vector2 = target - stone.global_position
			var rigid_rotation_velocity := Vector2(-target_relative.y, target_relative.x) * target_angular_velocity
			var deformation_velocity: Vector2 = stone.linear_velocity - average_velocity - rigid_rotation_velocity
			var restoring_force: Vector2 = position_error * stiffness - deformation_velocity * damping
			pending_forces.append(restoring_force)
			force_sum += restoring_force

		# Shape memory is an internal constraint, so its net force must be zero.
		# Per-stone clamping broke that invariant and could turn rotation into lift.
		var mean_force := force_sum / float(group_stones.size())
		var strongest_force := 0.0
		for index in range(pending_forces.size()):
			pending_forces[index] -= mean_force
			strongest_force = maxf(strongest_force, pending_forces[index].length())
		var common_scale := minf(1.0, maximum_force / maxf(strongest_force, 0.001))
		for index in range(group_stones.size()):
			group_stones[index].apply_central_force(pending_forces[index] * common_scale)


func _add_spring(a: Node, b: Node, rest_distance: float, adjacent: bool) -> void:
	var joint := DampedSpringJoint2D.new()
	# DampedSpringJoint2D builds its two physical anchors from the joint's
	# position, rotation and length. Place those anchors at the stone centers;
	# leaving the joint at (0, 0) makes the visible cord and physical spring
	# disagree, which lets a piece appear to fall apart on impact.
	joint.position = a.position
	joint.rotation = (b.position - a.position).angle() - PI * 0.5
	joint.length = rest_distance
	joint.rest_length = rest_distance
	joint.stiffness = EDGE_SPRING_STIFFNESS if adjacent else SUPPORT_SPRING_STIFFNESS
	joint.damping = EDGE_SPRING_DAMPING if adjacent else SUPPORT_SPRING_DAMPING
	add_child(joint)
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)

	var line := Line2D.new()
	line.width = 7.0 if adjacent else 3.0
	line.default_color = a.tint_color.darkened(0.28) if adjacent else Color(a.tint_color, 0.38)
	line.z_index = -1
	line.antialiased = true
	add_child(line)
	links.append({"a": a, "b": b, "joint": joint, "line": line, "adjacent": adjacent})


func _process(_delta: float) -> void:
	for link in links:
		if is_instance_valid(link["a"]) and is_instance_valid(link["b"]) and is_instance_valid(link["line"]):
			link["line"].points = PackedVector2Array([link["a"].global_position, link["b"].global_position])


func _check_for_elimination() -> void:
	_prune_invalid_stones()
	var left_stones: Array[Node] = []
	var right_stones: Array[Node] = []
	for stone in stones:
		if stone.global_position.x - STONE_SIZE * 0.5 <= FIELD_LEFT + 8.0:
			left_stones.append(stone)
		if stone.global_position.x + STONE_SIZE * 0.5 >= FIELD_RIGHT - 8.0:
			right_stones.append(stone)

	var best_band: Array[Node] = []
	var best_from := Vector2.ZERO
	var best_to := Vector2.ZERO
	for left in left_stones:
		for right in right_stones:
			if not _edge_pair_is_level(left.global_position.y, right.global_position.y):
				continue
			var from: Vector2 = left.global_position
			var to: Vector2 = right.global_position
			var band := _stones_near_segment(from, to)
			var required := _required_stones_between(from, to)
			if band.size() >= required and band.size() > best_band.size():
				best_band = band
				best_from = from
				best_to = to

	if not best_band.is_empty():
		_eliminate(best_band, best_from, best_to)


func _update_near_clear_highlights() -> void:
	var left_stones: Array[Node] = []
	var right_stones: Array[Node] = []
	for stone in stones:
		if stone.global_position.x - STONE_SIZE * 0.5 <= FIELD_LEFT + 8.0:
			left_stones.append(stone)
		if stone.global_position.x + STONE_SIZE * 0.5 >= FIELD_RIGHT - 8.0:
			right_stones.append(stone)

	var highlighted := {}
	for left in left_stones:
		for right in right_stones:
			if not _edge_pair_is_level(left.global_position.y, right.global_position.y):
				continue
			var from: Vector2 = left.global_position
			var to: Vector2 = right.global_position
			var band := _stones_near_segment(from, to)
			var required := _required_stones_between(from, to)
			if band.size() == required - 1:
				for stone in band:
					highlighted[stone.get_instance_id()] = true

	for stone in stones:
		stone.set_near_clear(highlighted.has(stone.get_instance_id()))


func _edge_pair_is_level(left_y: float, right_y: float) -> bool:
	return absf(left_y - right_y) <= PAIR_HEIGHT_TOLERANCE


func _stones_near_segment(from: Vector2, to: Vector2) -> Array[Node]:
	var result: Array[Node] = []
	var segment := to - from
	var length_squared := segment.length_squared()
	if length_squared < 1.0:
		return result
	for stone in stones:
		var amount := clampf((stone.global_position - from).dot(segment) / length_squared, 0.0, 1.0)
		var closest := from + segment * amount
		if stone.global_position.distance_to(closest) <= CLEAR_BAND_HALF_WIDTH:
			result.append(stone)
	return result


func _required_stones_between(from: Vector2, to: Vector2) -> int:
	# Distance between centers counts intervals, not stones. Add both endpoint
	# occupancy correctly: a 10-stone-wide field has 9 center intervals but
	# requires 10 stones to clear.
	return maxi(5, ceili(from.distance_to(to) / STONE_SIZE) + 1)


func _eliminate(targets: Array[Node], from: Vector2, to: Vector2) -> void:
	last_height_multiplier = _height_score_multiplier(from, to)
	cleared += targets.size()
	score += targets.size() * 100 * last_height_multiplier
	flash_lines.append({"from": from, "to": to, "life": 0.42})
	for stone in targets:
		_remove_stone_and_links(stone)
	_update_ui()
	elimination_cooldown = 0.55


func _height_score_multiplier(from: Vector2, to: Vector2) -> int:
	var line_y := (from.y + to.y) * 0.5
	# A clear line must reach both side walls, whose lowest usable point is
	# BOWL_EDGE_Y. Map that height linearly from x1 at the floor to x16 at top.
	var height_ratio := clampf(
		(BOWL_EDGE_Y - line_y) / maxf(BOWL_EDGE_Y - FIELD_TOP, 1.0),
		0.0,
		1.0
	)
	return roundi(lerpf(MIN_HEIGHT_MULTIPLIER, MAX_HEIGHT_MULTIPLIER, height_ratio))


func _remove_stone_and_links(stone: Node) -> void:
	for index in range(links.size() - 1, -1, -1):
		var link := links[index]
		if link["a"] == stone or link["b"] == stone:
			if is_instance_valid(link["joint"]):
				link["joint"].queue_free()
			if is_instance_valid(link["line"]):
				link["line"].queue_free()
			links.remove_at(index)
	stones.erase(stone)
	active_stones.erase(stone)
	stone.queue_free()


func _prune_invalid_stones() -> void:
	stones = stones.filter(func(stone): return is_instance_valid(stone) and not stone.is_queued_for_deletion())
	active_stones = active_stones.filter(func(stone): return is_instance_valid(stone) and not stone.is_queued_for_deletion())


func _spawn_area_blocked() -> bool:
	for stone in stones:
		if stone.global_position.y < GAME_OVER_LINE_Y and absf(stone.global_position.x - SPAWN_POS.x) < SPAWN_BLOCK_HALF_WIDTH:
			return true
	return false


func _game_over() -> void:
	is_game_over = true
	status_label.text = "PILE JAMMED\nPress R to restart"
	status_label.visible = true
	help_label.text = "R  RESTART"


func _center_of(nodes: Array[Node]) -> Vector2:
	var center := Vector2.ZERO
	var count := 0
	for node in nodes:
		if is_instance_valid(node):
			center += node.global_position
			count += 1
	return center / maxf(float(count), 1.0)


func _bowl_y(x: float) -> float:
	var half_width := (FIELD_RIGHT - FIELD_LEFT) * 0.5
	var normalized := (x - (FIELD_LEFT + FIELD_RIGHT) * 0.5) / half_width
	return BOWL_EDGE_Y + BOWL_DEPTH * (1.0 - normalized * normalized)


func _update_ui() -> void:
	score_label.text = "%06d  ·  x%d  ·  %d stones" % [score, last_height_multiplier, cleared]


func _draw() -> void:
	# Field fill and soft guide bands.
	var polygon := PackedVector2Array([Vector2(FIELD_LEFT, FIELD_TOP), Vector2(FIELD_RIGHT, FIELD_TOP)])
	for index in range(24, -1, -1):
		var x := lerpf(FIELD_LEFT, FIELD_RIGHT, float(index) / 24.0)
		polygon.append(Vector2(x, _bowl_y(x)))
	draw_colored_polygon(polygon, Color("101a2c"))

	for y in range(200, 801, 100):
		if absf(float(y) - GAME_OVER_LINE_Y) > 1.0:
			draw_dashed_line(Vector2(FIELD_LEFT + 12, y), Vector2(FIELD_RIGHT - 12, y), Color(0.35, 0.44, 0.65, 0.12), 1.0, 8.0)

	# The visible warning uses the exact height checked before the next piece
	# spawns, so the player can judge how much safe headroom remains.
	draw_rect(
		Rect2(FIELD_LEFT + 5.0, GAME_OVER_LINE_Y - 5.0, FIELD_RIGHT - FIELD_LEFT - 10.0, 10.0),
		Color(1.0, 0.36, 0.45, 0.07)
	)
	draw_dashed_line(
		Vector2(FIELD_LEFT + 8.0, GAME_OVER_LINE_Y),
		Vector2(FIELD_RIGHT - 8.0, GAME_OVER_LINE_Y),
		Color(1.0, 0.48, 0.55, 0.52),
		2.0,
		10.0
	)

	draw_line(Vector2(FIELD_LEFT, FIELD_TOP), Vector2(FIELD_LEFT, BOWL_EDGE_Y), Color("52658e"), 6.0, true)
	draw_line(Vector2(FIELD_RIGHT, FIELD_TOP), Vector2(FIELD_RIGHT, BOWL_EDGE_Y), Color("52658e"), 6.0, true)
	var bowl_points := PackedVector2Array()
	for index in range(25):
		var x := lerpf(FIELD_LEFT, FIELD_RIGHT, float(index) / 24.0)
		bowl_points.append(Vector2(x, _bowl_y(x)))
	draw_polyline(bowl_points, Color("52658e"), 7.0, true)

	# Contact zones explain the left/right pairing rule without a grid.
	draw_rect(Rect2(FIELD_LEFT - 3, FIELD_TOP, 13, BOWL_EDGE_Y - FIELD_TOP), Color(0.35, 0.85, 0.75, 0.08))
	draw_rect(Rect2(FIELD_RIGHT - 10, FIELD_TOP, 13, BOWL_EDGE_Y - FIELD_TOP), Color(0.35, 0.85, 0.75, 0.08))

	for flash in flash_lines:
		var alpha: float = clampf(flash["life"] / 0.42, 0.0, 1.0)
		draw_line(flash["from"], flash["to"], Color(1.0, 0.95, 0.65, alpha), 18.0 * alpha, true)
