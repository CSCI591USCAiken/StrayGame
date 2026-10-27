extends Node2D

@export var player: CharacterBody2D
@export var room_size := Vector2(1152, 648)
# Get cam from player
@onready var camera: Camera2D = player.get_node("Camera2D")

var current := Vector2i(999, 999)

# Define room size
func _physics_process(_delta: float) -> void:
	var cell := Vector2i((player.global_position / room_size).floor())
	if cell == current:
		return
	current = cell
	camera.set_room(Rect2(Vector2(cell) * room_size, room_size))
