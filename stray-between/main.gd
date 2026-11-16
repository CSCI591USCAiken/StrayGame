extends Node2D # Attached to the root node of your main scene

# 1. PUT THE ARRAY HERE (Top of the script)
const CHARACTER_SCENES: Array[PackedScene] = [
	preload("res://11_5_f.tscn"),
	preload("res://11_5_o.tscn"),
	preload("res://11_5_c.tscn")
]

# Optional: Drag a Marker2D node here in the Inspector to set the spawn location
@export var spawn_point: Marker2D 

# 2. CALL THE SPAWN LOGIC IN _ready()
func _ready() -> void:
	var chosen_scene = CHARACTER_SCENES.pick_random()
	var player = chosen_scene.instantiate()
	add_child(player)
	
	if spawn_point:
		player.global_position = spawn_point.global_position
