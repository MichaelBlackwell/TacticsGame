# Level.gd  (root of your level scene)
extends Node2D

@onready var layers := [
	$TileMapLayer_Ground,
	$TileMapLayer_Walls,
	$TileMapLayer_Props
]

var scene = preload("res://tile.tscn")
@onready var tilemaplayer_ground := $TileMapLayer_Ground

@export var grid_width  : int = 32   # set in Inspector
@export var grid_height : int = 24

signal tile_hovered(map_pos : Vector2i)

@onready var ground_layer := $TileMapLayer_Ground   # pick one layer

var _last_hover : Vector2i = Vector2i(-999, -999)   # impossible start value

@onready var move_overlay := $TileMapLayer_MoveOverlay

var selected_squad : Squad

var reachable_cache : Dictionary = {}

signal squad_selected(squad)


@export var squad_pick_mask: int = 1 << 0   # layer bit used by player squads



func _ready() -> void:
	set_process_input(true)            # keep _input() alive
	set_process_unhandled_input(true)  # keep _unhandled_input() alive	
	
	for layer : TileMapLayer in layers:
		var nav_enabled := layer.navigation_enabled   # Ground usually true, Walls false
		for cell in layer.get_used_cells():           # '0' = primary tile layer
			var t := Tile.new()
			t.grid_pos = cell

			# Decide terrain from per-layer flag OR per-tile custom data
			if nav_enabled:
				t.terrain = Tile.Terrain.PLAIN
			else:
				t.terrain = Tile.Terrain.OBSTACLE

			Grid.register_tile(t)
	
	print("Tiles registered: ", Grid.tile_dict.size())
	
	await get_tree().process_frame
	Grid.bake(grid_width, grid_height)   # safe to build the AStar grid
	
	tile_hovered.connect(_on_tile_hovered)
	
	for s in get_tree().get_nodes_in_group("player_squad"):
		# Disconnect first to avoid duplicates (optional safety)
		get_tree().current_scene.tile_hovered.disconnect(s._on_tile_hovered) \
			if get_tree().current_scene.tile_hovered.is_connected(s._on_tile_hovered) else null
		
		# Correct connection
		get_tree().current_scene.tile_hovered.connect(s._on_tile_hovered)


func _input(event : InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local = layers[0].get_local_mouse_position()  # layer space
		var map_pos = layers[0].local_to_map(local)       # Vector2i
		if map_pos != _last_hover:
			_last_hover = map_pos
			emit_signal("tile_hovered", map_pos)
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed:
		_handle_left_click()

func _handle_left_click() -> void:
	var world_pos: Vector2 = get_global_mouse_position()

	# --- 1. Physics pick: what’s under the cursor? ---
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collision_mask = squad_pick_mask
	params.collide_with_areas = true      # squads are Area2D
	params.collide_with_bodies = true     # safety if you switch to bodies later

	var hits := get_world_2d().direct_space_state.intersect_point(params)
	# hits = Array[Dictionary]; each dict has "collider", "rid", etc.  (see docs)
	# We'll select the *topmost* squad hit (first is fine unless you need sorting)
	for hit in hits:
		var c = hit.collider
		if c and c.is_in_group("player_squad"):
			_select_squad(c)
			set_process_input(true) 
			return

	# --- 2. No squad hit → treat as board click (move / deselect) ---
	if selected_squad:
		var map_pos = ground_layer.local_to_map(ground_layer.to_local(world_pos))
		_try_move_selected_to(map_pos)
	else:
		# click on empty space with no selection: nothing (or deselect anyway)
		_clear_selection()
		
func _select_squad(s: Squad) -> void:
	if selected_squad == s:
		return  # already selected
	_clear_selection()
	selected_squad = s
	
	# compute movement range immediately
	var start = Grid.world_to_map(s.global_position)
	reachable_cache = Grid.dijkstra_reachable(start, s.move_points, s)
	
	s.set_selected(true, reachable_cache)
	
	print("reachable:", reachable_cache.size())
	move_overlay.show_reachable(reachable_cache, s.move_points)
	squad_selected.emit(s)
	
	

	

	
func _try_move_selected_to(map_pos: Vector2i) -> void:
	if not selected_squad:
		return
	# Only allow if tile is reachable this turn:
	if not reachable_cache.has(map_pos):
		selected_squad.show_out_of_range_preview(map_pos) # red line / error SFX
		return
	# Build path (A*) and order squad to move
	selected_squad.try_move_to(map_pos)
	_after_squad_orders()

func _on_tile_hovered(map_pos: Vector2i) -> void:

	if not selected_squad:
		return
	
	selected_squad.show_path_preview(map_pos)
		
# --------------------------------------------------------------------
# Deselect whatever is currently active and wipe visuals.
# --------------------------------------------------------------------
func _clear_selection() -> void:
	if selected_squad:
		selected_squad.set_selected(false, {})           # turn off ring / modulate
	selected_squad   = null
	reachable_cache  = {}                            # forget old range
	move_overlay.clear()                             # clear TileMapLayer
	# Hide any lingering path preview
	for s in get_tree().get_nodes_in_group("player_squad"):
		s.hide_path_preview()
		
# --------------------------------------------------------------------
# Called IMMEDIATELY AFTER we tell a squad to move (issue_move).
# Disables input until the squad finishes its tween, then either
# re-selects it (if it still has actions) or ends the phase.
# --------------------------------------------------------------------
func _after_squad_orders() -> void:
	# 1) Prevent further clicks until move completes
	set_process_input(false)
	
	# 2) Listen once to the squad’s turn-completion signal
	if not selected_squad.action_completed.is_connected(_on_squad_finished):
		selected_squad.action_completed.connect(_on_squad_finished)

func _on_squad_finished(squad: Squad) -> void:
	# Re-enable click handling
	set_process_input(true)
	
	# Mark squad has acted for TurnManager tracking
	TurnManager.notify_squad_acted(squad)    # add this helper in TurnManager
	
	# Auto-end phase if everyone acted
	if TurnManager.all_friendly_acted():
		TurnManager.end_phase()              # swaps to ENEMY phase
		_clear_selection()
		return

	# Otherwise keep the squad selected so player can attack, breach, etc.
	# Re-compute range with remaining move points, if any.
	if squad.move_points > 0:
		reachable_cache = Grid.dijkstra_reachable(
			Grid.world_to_map(squad.global_position),
			squad.move_points,
			squad
		)
		move_overlay.show_reachable(reachable_cache, squad.move_points)
	else:
		_clear_selection()
