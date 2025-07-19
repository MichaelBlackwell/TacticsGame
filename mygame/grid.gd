# res://Grid.gd   (autoload)
extends Node

const TILE_SIZE := Vector2(16, 16)   # match your TileMap

var tile_dict: Dictionary = {}        # { Vector2i => Tile }
var astar = AStarGrid2D.new()

const DIRS_4 := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func occupy(tile: Tile, new_occupant: Node) -> void:
	tile.occupant = new_occupant
	Grid.refresh_walkable(tile)

func bake(w: int, h: int) -> void:
	astar.region = Rect2i(Vector2i.ZERO, Vector2i(w, h))
	astar.cell_size = TILE_SIZE
	astar.update()

func register_tile(tile: Tile) -> void:
	tile_dict[tile.grid_pos] = tile

func get_tile_at_map(coords: Vector2i) -> Tile:
	return tile_dict.get(coords)

func map_to_world(coords: Vector2i) -> Vector2:
	return Vector2i(Vector2(coords) * TILE_SIZE + TILE_SIZE)      # centre of tile

func world_to_map(pos: Vector2) -> Vector2i:
	return Vector2i(pos / TILE_SIZE)

	
# Returns {cell: total_cost} for all cells you can reach within max_cost.
func dijkstra_reachable(start: Vector2i, max_cost: int, squad) -> Dictionary:
	var dist := {start: 0}
	var frontier : Array[Vector2i] = [start]   # queue
	
	while not frontier.is_empty():
		# Pop the lowest-cost entry (linear scan - good enough for small sets)
		var best_i := 0
		var best_cost := INF
		for i in frontier.size():
			var c = dist[frontier[i]]
			if c < best_cost:
				best_cost = c
				best_i = i
		var current : Vector2i = frontier[best_i]
		frontier.remove_at(best_i)
		
		# If we've already exceeded the allowance, skip expanding
		if best_cost >= max_cost:
			continue
		
		for dir in DIRS_4:
			var nb = current + dir
			#if not is_in_bounds(nb):
				#continue
			
			var tile = tile_dict.get(nb)
			if tile == null:
				continue
			
			# Hard blocks (walls, impassable) or enemy units
			if not _tile_can_enter(tile, squad):
				continue
			
			# Movement cost for this squad on that tile
			var step_cost = _tile_cost(tile, squad)
			if step_cost <= 0:
				step_cost = 1  # safety
			
			var new_cost = best_cost + step_cost
			if new_cost > max_cost:
				continue
			
			var old_cost = dist.get(nb, INF)
			if new_cost < old_cost:
				dist[nb] = new_cost
				frontier.push_back(nb)
	
	return dist                                # key=tile, value=cost

func _tile_can_enter(tile: Tile, squad) -> bool:
	if tile.blocked:
		return false
	# Example: block enemy-occupied cells; allow friendly?
	if tile.occupant and tile.occupant != squad:
		return false
	return true

func _tile_cost(tile: Tile, squad) -> int:
	# Basic switch; replace with per-terrain table
	match tile.terrain:
		Tile.Terrain.PLAIN: return 1
		Tile.Terrain.FOREST: return 2
		Tile.Terrain.WATER: return 99  # effectively blocked for foot
		_:
			return 1
