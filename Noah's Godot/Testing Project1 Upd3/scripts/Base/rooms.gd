extends Node2D

# This script helps mainly the camera script function when scrolling between rooms.
# This must be in every scene the player is in for the camera to scroll.

# Optional. Left empty, the player is found by group instead.
@export var player: CharacterBody2D
@export var room_size := Vector2(1152, 648)
# Where room (0, 0) starts, if the world doesn't begin at the origin.
@export var grid_offset := Vector2.ZERO

var camera: Camera2D
var current := Vector2i(999, 999)

# Define room size
func _physics_process(_delta: float) -> void:
	if not _find_player():
		return
	var cell := Vector2i(((player.global_position - grid_offset) / room_size).floor())
	if cell == current:
		return
	current = cell
	camera.set_room(Rect2(Vector2(cell) * room_size + grid_offset, room_size))


# Survives scene changes, since a new scene means a new player and camera.
func _find_player() -> bool:
	if is_instance_valid(player) and is_instance_valid(camera):
		return true
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return false
	camera = player.get_node_or_null("Camera2D") as Camera2D
	# A fresh player means the remembered room is meaningless.
	current = Vector2i(999, 999)
	return camera != null
