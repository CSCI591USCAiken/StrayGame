extends CharacterBody2D

# This is the script that allows the player to exist. :D

# Chasers reset when this fires.
signal respawned

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
@export var normal_frames: SpriteFrames
@export var swapped_frames: SpriteFrames
@export var fade_out_time := 0.45
@export var respawn_delay := 0.6
@export var fade_in_time := 0.35
@export var crouch_speed := 140.0
@export_range(0.3, 0.9) var crouch_height := 0.55

# What the swapped form changes. 1.0 means "same as normal", so abilities
# can be switched on one at a time while tuning.
@export_group("Swapped form")
@export_range(0.5, 2.0, 0.05) var swapped_speed_scale := 1.15
# Bigger jumps higher, since jump velocity is negative.
@export_range(0.5, 2.0, 0.05) var swapped_jump_scale := 1.12
@export_range(0.5, 2.0, 0.05) var swapped_gravity_scale := 1.0
@export_range(0.5, 2.0, 0.05) var swapped_crouch_speed_scale := 1.0

# What the current form actually moves at. Recalculated on every swap.
var active_speed := 0.0
var active_jump_velocity := 0.0
var active_gravity := 0.0
var active_crouch_speed := 0.0

# Crouching parts
var crouching := false
var stand_size: Vector2
var stand_offset: Vector2
# Where respawning returns to. Set from wherever the player sits within the editor.
var spawn_position: Vector2
# "Is the player currently going through something that requires input to temporarially be disabled?"
# If yes, then label them busy! *thunder noises*
var busy := false

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var sprite_scale := sprite.scale
@onready var collision: CollisionShape2D = $CollisionShape2D

# Spawning
func _ready() -> void:
	# Lets enemies find the player.
	add_to_group("player")
	spawn_position = global_position
	stand_size = collision.shape.size
	stand_offset = collision.position
	# Without duplicate() every player instance would share one shape.
	collision.shape = collision.shape.duplicate()
	World.palette_changed.connect(update_frames)
	update_frames()
	World.palette_changed.connect(apply_form)
	apply_form()
	sprite.modulate.a = 0.0
	create_tween().tween_property(sprite, "modulate:a", 1.0, fade_in_time)

# This is the base code that allows the character to move and be effected by gravity
func _physics_process(delta: float) -> void:
	if busy:
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + active_gravity * delta, max_fall_speed)

	set_crouching(Input.is_action_pressed("crouch") and is_on_floor())

	if Input.is_action_just_pressed("jump") and is_on_floor() and not crouching:
		velocity.y = active_jump_velocity
	# Releasing early cuts the jump short.
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	var top_speed := active_crouch_speed if crouching else active_speed
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * top_speed, acceleration * delta)
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
	update_animation(direction)


# Swapping isn't just a repaint; the other form moves differently.
func apply_form() -> void:
	var swapped := World.swapped
	active_speed = speed * (swapped_speed_scale if swapped else 1.0)
	active_jump_velocity = jump_velocity * (swapped_jump_scale if swapped else 1.0)
	active_gravity = gravity * (swapped_gravity_scale if swapped else 1.0)
	active_crouch_speed = crouch_speed * (swapped_crouch_speed_scale if swapped else 1.0)


func update_frames() -> void:
	var frames: SpriteFrames = swapped_frames if World.swapped else normal_frames
	if frames == null or frames == sprite.sprite_frames:
		return
	var current := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.sprite_frames = frames
	# A missing animation name would error, so only restore what exists.
	if frames.has_animation(current):
		sprite.play(current)
		sprite.set_frame_and_progress(frame, progress)


# Safe to call every frame; play() on the current animation lets it continue.
func update_animation(direction: float) -> void:
	if not is_on_floor():
		play_animation("jump" if velocity.y < 0 else "fall")
	elif crouching:
		# Crawling is just crouching while moving, so it falls back to the pose.
		play_animation("crawl" if direction else "crouch", "crouch")
	elif direction:
		play_animation("run")
	else:
		play_animation("idle")


# A missing name would error every frame, so fall back instead.
func play_animation(animation_name: String, fallback := "idle") -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	if frames.has_animation(animation_name):
		sprite.play(animation_name)
	elif frames.has_animation(fallback):
		sprite.play(fallback)


func set_crouching(value: bool) -> void:
	if value == crouching or (not value and not can_stand()):
		return
	crouching = value
	var size := stand_size
	if crouching:
		size.y = stand_size.y * crouch_height
	collision.shape.size = size
	# Shift the box down by what it lost so the feet stay planted.
	collision.position.y = stand_offset.y + (stand_size.y - size.y) / 2


func can_stand() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	# Slightly undersized so the floor underfoot doesn't count as a blocker.
	shape.size = stand_size * 0.95
	query.shape = shape
	query.transform = Transform2D(0.0, global_position + stand_offset)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func respawn() -> void:
	if busy:
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	sprite.modulate.a = 0.2
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.25)
	respawned.emit()


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
