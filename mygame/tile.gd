## Tile.gd  – dropped on every grid cell
extends Node2D
class_name Tile

## --- DATA ----------------------------------------------------------
enum Terrain { PLAIN, FOREST, WATER, OBSTACLE }
@export var terrain : Terrain = Terrain.PLAIN   # set per-instance in the editor
var blocked = false
var occupant : Node = null                      # squad currently on the tile
var grid_pos: Vector2i

## --- HELPERS -------------------------------------------------------
#func _ready() -> void:
	#grid_pos = Grid.world_to_map(global_position)

func is_walkable(owner_side) -> bool:
	# you can refine this later (e.g. allow WALK on WATER if a bridge)
	var walkable : bool = false
	if occupant and occupant.side != owner_side:
		return false
	else:
		return terrain != Terrain.OBSTACLE
		

func movement_cost() -> int:
	match terrain:
		Terrain.PLAIN: 
			return 1
		Terrain.FOREST: 
			return 2
		Terrain.WATER: 
			return 999  # unless bridged
		_: 
			return 1
