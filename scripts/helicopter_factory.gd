extends Node
class_name HelicopterFactory

# Optional: preload different Player scene variants (if you split visuals)
export(PackedScene) var player_scene


func spawn_heli(position: Vector2, config: HelicopterConfig) -> Node2D:
	var scene := player_scene if player_scene != null else preload("res://scenes/player.tscn")
	var heli: Node2D = scene.instance()
	if heli.has_method("set"):
		heli.set("config", config)
	heli.position = position
	return heli
