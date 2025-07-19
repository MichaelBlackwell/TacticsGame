extends Area2D
class_name Squad

signal action_completed(squad)

@export var move_points : int = 8
@export var actions_left : int = 1
@export var side : int = 1 #Which opponent does this unit belong to?

var has_acted := false

var path : PackedVector2Array
var cached_reachable : Dictionary
var tween : Tween

@onready var preview := $PathPreview
@export var preview_color := Color(0.8, 1.0, 0.2, 0.9)  # pastel green

@export var preview_ok_colour    : Color = Color(0.8, 1.0, 0.2, 0.9)  # pastel green
@export var preview_block_colour : Color = Color(1.0, 0.2, 0.2, 0.9)  # red

@onready var select_ring := $SelectRing      # Sprite2D or TextureRect you add in the scene
var selected := false



func _ready() -> void:
	TurnManager.phase_started.connect(_on_phase_started)
	preview.visible = false
	add_to_group("player_squad")  # used in click filtering
	input_pickable = true         # ensure Area2D can receive input events

func _on_phase_started(new_phase: int) -> void:
	has_acted = false
	set_process_input(new_phase == TurnManager.Phase.PLAYER)
	if new_phase == TurnManager.Phase.ENEMY:
		_take_enemy_action()

func _take_enemy_action() -> void:
	if has_acted: return
	await get_tree().create_timer(0.3).timeout
	_perform_action()

func _input(event: InputEvent) -> void:
	if has_acted: return
	if event is InputEventMouseButton and event.pressed:
		if _is_mouse_over_me(get_global_mouse_position()):
			_perform_action()

func _is_mouse_over_me(point: Vector2) -> bool:
	return (position - point).length() < 16

func _perform_action() -> void:
	has_acted = true
	action_completed.emit(self)
	set_process_input(false)



func show_action_menu():
	pass
	# emit a signal or open a popup listing abilities based on resources
	
func try_move_to(target_map: Vector2i) -> void:
	var start := Grid.world_to_map(global_position)
	path = Grid.astar.get_point_path(start, target_map)
	if path.size() - 1 > move_points:
		return  # too far this turn
	_begin_tween_path(path)

func _begin_tween_path(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return  # already on target or path failed

	if tween: tween.kill()

	tween = create_tween()
	const STEP_TIME := 0.2

	# reserve destination
	var dest_tile := Grid.get_tile_at_map(points[points.size() - 1])
	if dest_tile.occupant:
		return

	# vacate start tile
	var start_tile := Grid.get_tile_at_map(points[0])
	start_tile.occupant = null
	dest_tile.occupant  = self

	for i in range(1, points.size()):
		tween.tween_property(
			self,
			"global_position",
			Grid.map_to_world(points[i]),
			STEP_TIME
		).set_trans(Tween.TRANS_SINE)

	tween.finished.connect(_on_reached_destination)

func _on_reached_destination() -> void:
	move_points -= path.size() - 1
	has_acted = true
	action_completed.emit(self)

func set_selected(enable: bool, reach : Dictionary) -> void:
	print("SET SELECTED")
	cached_reachable = reach
	selected = enable
	if select_ring:
		select_ring.visible = enable
	# anything else you’d like (e.g. modulate sprite, play SFX)
	preview.visible = true
	
func show_path_preview(target_map: Vector2i) -> void:
	if cached_reachable.is_empty():
		preview.visible = false
		return

	# 1. If not reachable by cost, show a simple red stub (no A*)
	# if you want to
	if not cached_reachable.has(target_map):
		_show_unreachable_stub(target_map)
		return

	var remaining_cost_allowed := move_points
	var move_cost = cached_reachable[target_map]  # weighted Dijkstra cost

	# 2. Compute the actual path ONCE (for drawing exact route)
	var start_grid := Grid.world_to_map(global_position)
	var path := Grid.astar.get_point_path(start_grid, target_map)
	if path.is_empty():
		preview.visible = false
		return

	# 3. Decide color using COST (robust for varied terrain)
	var in_range = move_cost <= remaining_cost_allowed
	_set_preview_points(path)
	preview.default_color = preview_ok_colour if in_range else preview_block_colour
	preview.visible = true
	
	assert(Grid.astar != null)
	assert(cached_reachable.has(Grid.world_to_map(global_position)))

func _show_unreachable_stub(target_map: Vector2i) -> void:
	var start_world = global_position
	var end_world   = Grid.map_to_world(target_map)
	preview.points = PackedVector2Array([
		preview.to_local(start_world),
		preview.to_local(end_world)
	])
	preview.default_color = preview_block_colour
	preview.visible = true


func _set_preview_points(grid_points: PackedVector2Array) -> void:
	var local_points: PackedVector2Array = []
	for g in grid_points:
		var world_pt := g              # centre of tile
		local_points.append(preview.to_local(world_pt))      # <<< convert
	preview.points = local_points
	preview.visible = true
	
func hide_path_preview() -> void:
	preview.points = PackedVector2Array()
	preview.visible = false
	
func _on_tile_hovered(map_pos : Vector2i) -> void:
	pass
