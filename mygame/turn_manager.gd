extends Node

# TurnManager.gd (autoload)
enum Phase { PLAYER, ENEMY }
var current_phase = Phase.PLAYER
signal phase_started(phase)
signal phase_ended(phase)
var remaining = []


func _ready():
	for squad in get_player_squads() + get_enemy_squads():
		squad.action_completed.connect(_on_squad_completed)

func end_phase():
	emit_signal("phase_ended", current_phase)
	current_phase = Phase.ENEMY if current_phase == Phase.PLAYER else Phase.PLAYER
	emit_signal("phase_started", current_phase)

func _on_phase_started(new_phase):
	remaining = (new_phase == Phase.PLAYER if get_player_squads() else get_enemy_squads())
	for squad in remaining:
		squad.has_acted = false

func _on_squad_completed(squad: Node):   # receive it here
	remaining.erase(squad)
	if remaining.is_empty():
		end_phase()

func _on_action_completed(unit):
	if unit in remaining:
		remaining.erase(unit)
	if remaining.empty():
		end_phase()

func get_player_squads() -> Array:
	var parent := get_tree().get_current_scene().get_node("Units/PlayerSquads")
	return parent.get_children()
	
func get_enemy_squads() -> Array:
	var parent := get_tree().get_current_scene().get_node("Units/EnemySquads")
	return parent.get_children()

func on_squad_selected(squad: Squad) -> void:
	var start := Grid.world_to_map(squad.global_position)
	var dist_map := Grid.dijkstra_reachable(start, squad.move_points, squad)
	$TileMapLayer_MoveOverlay.show_reachable(dist_map)
	squad.cached_reachable = dist_map  # store for validation

func clear_move_overlay():
	$TileMapLayer_MoveOverlay.clear()
