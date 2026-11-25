extends Node2D # Attached to the root node of your main scene

# --- Set the X and Y coordinates where your quadrants divide ---
@export var split_x: float = 1152.0
@export var split_y: float = 648.0

# 1. QUADRANT CHARACTER ARRAYS
const QUAD_TOP_LEFT: Array[PackedScene] = [
	preload("res://11-5-frog.tscn"),
	preload("res://11_5_o.tscn"),
	preload("res://11_5_q.tscn")
]

const QUAD_TOP_RIGHT: Array[PackedScene] = [
	preload("res://11_5_f.tscn"),
	preload("res://11_5_o.tscn"),
	preload("res://11_5_c.tscn")
]

const QUAD_BOTTOM_LEFT: Array[PackedScene] = [
	preload("res://11_5_f.tscn"),
	preload("res://11_5_o.tscn"),
	preload("res://11_5_c.tscn")
]

const QUAD_BOTTOM_RIGHT: Array[PackedScene] = [
	preload("res://11_5_f.tscn"),
	preload("res://11_5_o.tscn"),
	preload("res://11_5_c.tscn")
]

# Drag your Marker2D nodes here in the Inspector
@export var spawn_point: Marker2D 
@export var center_top_left: Marker2D
@export var center_top_right: Marker2D
@export var center_bottom_left: Marker2D
@export var center_bottom_right: Marker2D

@onready var camera: Camera2D = $Camera2D
@onready var end_screen: CanvasLayer = $EndScreen

var current_player: CharacterBody2D = null
var current_quadrant: String = ""
var camera_tween: Tween

func _ready() -> void:
	var start_pos := spawn_point.global_position if spawn_point else Vector2.ZERO
	
	# Automatically figure out which quadrant spawn_point starts in
	current_quadrant = _get_quadrant_at(start_pos)
	_apply_quadrant_instant(current_quadrant, start_pos)
	end_screen.hide()

func _on_end_trigger_body_entered(body: Node2D):
	if body == current_player:
		end_screen.show()

func _process(_delta: float) -> void:
	if not is_instance_valid(current_player):
		return
		
	var detected_quadrant := _get_quadrant_at(current_player.global_position)
	
	if detected_quadrant != current_quadrant:
		print("Crossed border at ", current_player.global_position, " -> Switching from ", current_quadrant, " to ", detected_quadrant)
		_switch_to_quadrant(detected_quadrant)

# Determines which quadrant any given coordinate belongs to
func _get_quadrant_at(pos: Vector2) -> String:
	var is_right := pos.x >= split_x
	var is_bottom := pos.y >= split_y
	
	if not is_right and not is_bottom:
		return "top_left"
	elif is_right and not is_bottom:
		return "top_right"
	elif not is_right and is_bottom:
		return "bottom_left"
	else:
		return "bottom_right"

# Used at startup so the camera snaps immediately without sliding
func _apply_quadrant_instant(quad_name: String, start_pos: Vector2) -> void:
	var view_size := get_viewport_rect().size
	match quad_name:
		"top_left":
			spawn_character_from_pool(QUAD_TOP_LEFT, start_pos, Vector2.ZERO, true)
			camera.global_position = center_top_left.global_position if center_top_left else Vector2(split_x - view_size.x * 0.5, split_y - view_size.y * 0.5)
		"top_right":
			spawn_character_from_pool(QUAD_TOP_RIGHT, start_pos, Vector2.ZERO, true)
			camera.global_position = center_top_right.global_position if center_top_right else Vector2(split_x + view_size.x * 0.5, split_y - view_size.y * 0.5)
		"bottom_left":
			spawn_character_from_pool(QUAD_BOTTOM_LEFT, start_pos, Vector2.ZERO, true)
			camera.global_position = center_bottom_left.global_position if center_bottom_left else Vector2(split_x - view_size.x * 0.5, split_y + view_size.y * 0.5)
		"bottom_right":
			spawn_character_from_pool(QUAD_BOTTOM_RIGHT, start_pos, Vector2.ZERO, true)
			camera.global_position = center_bottom_right.global_position if center_bottom_right else Vector2(split_x + view_size.x * 0.5, split_y + view_size.y * 0.5)

# Used during gameplay when crossing off-screen into another quadrant
func _switch_to_quadrant(quad_name: String) -> void:
	current_quadrant = quad_name
	var saved_pos := current_player.global_position
	var saved_vel := current_player.velocity
	
	var view_size := get_viewport_rect().size
	var target_cam_pos := camera.global_position
	
	match quad_name:
		"top_left":
			spawn_character_from_pool(QUAD_TOP_LEFT, saved_pos, saved_vel, false)
			target_cam_pos = center_top_left.global_position if center_top_left else Vector2(split_x - view_size.x * 0.5, split_y - view_size.y * 0.5)
		"top_right":
			spawn_character_from_pool(QUAD_TOP_RIGHT, saved_pos, saved_vel, false)
			target_cam_pos = center_top_right.global_position if center_top_right else Vector2(split_x + view_size.x * 0.5, split_y - view_size.y * 0.5)
		"bottom_left":
			spawn_character_from_pool(QUAD_BOTTOM_LEFT, saved_pos, saved_vel, false)
			target_cam_pos = center_bottom_left.global_position if center_bottom_left else Vector2(split_x - view_size.x * 0.5, split_y + view_size.y * 0.5)
		"bottom_right":
			spawn_character_from_pool(QUAD_BOTTOM_RIGHT, saved_pos, saved_vel, false)
			target_cam_pos = center_bottom_right.global_position if center_bottom_right else Vector2(split_x + view_size.x * 0.5, split_y + view_size.y * 0.5)
			
	print("Sliding camera to: ", target_cam_pos)
	slide_camera_to(target_cam_pos)

func spawn_character_from_pool(pool: Array[PackedScene], target_pos: Vector2, keep_velocity: Vector2, is_initial_spawn: bool = false) -> void:
	if pool.is_empty():
		return
		
	var chosen_scene: PackedScene = pool.pick_random()
	var new_player := chosen_scene.instantiate() as CharacterBody2D
	
	if is_initial_spawn:
		add_child(new_player)
		new_player.global_position = target_pos
		new_player.velocity = keep_velocity
	else:
		add_child.call_deferred(new_player)
		new_player.set_deferred("global_position", target_pos)
		new_player.set_deferred("velocity", keep_velocity)
	
	if current_player:
		current_player.queue_free()
		
	current_player = new_player

func slide_camera_to(target_pos: Vector2) -> void:
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
		
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "global_position", target_pos, 0.45)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
