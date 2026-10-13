extends CharacterBody2D

# This is the script that allows the player to exist. :D

# Each of these vars are parts that can be edited through the inspector.
# Godot is sometimes fidgety with this, so if all else fails, the values can
# be edited directly here in the code if needed.
@export var speed := 320.0
@export var acceleration := 2400.0
@export var friction := 2600.0
@export var gravity := 1800.0
# Negative because y points down in 2D.
@export var jump_velocity := -950.0
@export var max_fall_speed := 1400.0
# The normal texture is the base and the swapped is the "warped" world's texture.
# It is currently named "swapped" for simplicity and for if we changed the warped world's
# name later.
@export var normal_texture: Texture2D
@export var swapped_texture: Texture2D
@export var fade_out_time := 0.45
@export var respawn_delay := 0.6
@export var fade_in_time := 0.35

# Where respawning returns to. Set from wherever the player sits within the editor.
var spawn_position: Vector2
# "Is the player currently going through something that requires input to temporarially be disabled?"
# If yes, then label them busy! *thunder noises*
var busy := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite_scale := sprite.scale

# Spawning
func _ready() -> void:
	spawn_position = global_position
	World.palette_changed.connect(update_texture)
	update_texture()
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, fade_in_time)

# This is the base code that allows the character to move and be effected by gravity
func _physics_process(delta: float) -> void:
	if busy:
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	# Releasing early cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()


func update_texture() -> void:
	sprite.texture = swapped_texture if World.swapped else normal_texture


func respawn() -> void:
	if busy:
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite.modulate.a = 0.2
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.25)


# This allows the character to go "into" the door. 
func fade_out(door_x: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position:x", door_x, 0.15)
	tween.tween_property(sprite, "modulate:a", 0.0, fade_out_time)
	tween.parallel().tween_property(sprite, "scale", sprite_scale * 0.85, fade_out_time)
	await tween.finished
# This comment means nothing. Why did I put this here? Burrito Burger. Burrurger.

func enter_door(door_x: float, exit_position: Vector2) -> void:
	if busy or not is_on_floor():
		return
	busy = true
	velocity = Vector2.ZERO

	# Exiting stage through door. The new scene would load from here.
	await fade_out(door_x)
	await get_tree().create_timer(respawn_delay).timeout
	global_position = exit_position

	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, fade_in_time)
	tween.parallel().tween_property(sprite, "scale", sprite_scale, fade_in_time)
	await tween.finished
	busy = false


func exit_to_scene(door_x: float, scene_path: String) -> void:
	if busy or not is_on_floor():
		return
	busy = true
	velocity = Vector2.ZERO

	await fade_out(door_x)
	get_tree().change_scene_to_file(scene_path)
