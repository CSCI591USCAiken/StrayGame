extends CharacterBody2D

# This is a basic enemy script that walks and jumps to the player.

# Slower than player so it's fair (just the default).
@export var speed := 170.0
@export var acceleration := 1400.0
@export var gravity := 1800.0
@export var max_fall_speed := 1400.0

@export_group("Senses")
# Range (pixels)
@export var sight_range := 420.0
# Walls block its view.
@export var needs_line_of_sight := true
# Seconds it keeps chasing blind.
@export_range(0.0, 5.0, 0.1) var memory_time := 1.0
# Return to start position if dumbfounded.
@export var return_home := true
@export var stop_at_ledges := true
# Hazards destroy the enemy in cool destruction way XD 2000 3.0 gladiator
@export var hurt_by_hazards := true
# Seconds spent dead before coming back home. 0 returns instantly.
@export_range(0.0, 60.0, 0.5) var respawn_time := 15.0
# Freezes while off screen, unless it's hunting the player.
@export var pause_off_screen := true

@export_group("Jumping")
@export var can_jump := true
# Negative because y points down in 2D. Weaker than the player's by default.
@export var jump_velocity := -800.0
@export_range(0.0, 3.0, 0.1) var jump_cooldown := 0.4
# How much higher the player has to be before it tries to jump.
@export_range(0.0, 300.0, 5.0) var climb_threshold := 40.0

@export_group("Looks")
# Same as the player's! (for now)
@export var normal_frames: SpriteFrames
@export var swapped_frames: SpriteFrames
# Missing ones use idle.
@export var idle_animation := "idle"
@export var move_animation := "run"
@export var fall_animation := "fall"
@export var jump_animation := "jump"
@export var art_faces_left := false

# This prevents jittering (was once an issue)
# This also helps with when the chaser actually
# makes contact with the player.
const STOP_DISTANCE := 6.0

const TOUCH_MARGIN := 3.0
const LEDGE_LOOK_AHEAD := 12.0

const LEDGE_STEP_DOWN := 24.0

const TOUCH_CHECK_RANGE := 256.0

# Wakes a little before it's actually visible.
const SCREEN_MARGIN := 24.0

var home: Vector2
var sprite: AnimatedSprite2D
var _player: Node2D
var _memory := 0.0
var _chasing := false
var _jump_timer := 0.0
var _dead := false
var _respawn_timer := 0.0
# Put back on revival; a live chaser needs its real layers.
var _home_layer := 0
var _home_mask := 0
var _body_rect := Rect2(-16, -16, 32, 32)
var _touch_range_squared := 0.0
var _ray_query := PhysicsRayQueryParameters2D.new()
var _touch_query := PhysicsShapeQueryParameters2D.new()
var _notifier: VisibleOnScreenNotifier2D
var _fade_tween: Tween


func _ready() -> void:
	home = global_position
	_home_layer = collision_layer
	_home_mask = collision_mask
	for child in get_children():
		if child is AnimatedSprite2D:
			sprite = child as AnimatedSprite2D
		elif child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape:
				# This fixes a scaling bug.
				var to_world := Transform2D(0.0, global_scale.abs(), 0.0, Vector2.ZERO) * cs.transform
				_body_rect = to_world * cs.shape.get_rect()

	_ray_query.collision_mask = collision_mask
	_ray_query.exclude = [get_rid()]

	var touch_shape := RectangleShape2D.new()
	touch_shape.size = _body_rect.size + Vector2.ONE * TOUCH_MARGIN * 2.0
	_touch_query.shape = touch_shape
	# Filtered to the player below.
	_touch_query.collision_mask = 0xFFFFFFFF
	_touch_query.exclude = [get_rid()]
	var reach := _body_rect.size.length() + TOUCH_CHECK_RANGE
	_touch_range_squared = reach * reach

	_notifier = VisibleOnScreenNotifier2D.new()
	_notifier.rect = _body_rect.grow(SCREEN_MARGIN)
	add_child(_notifier)

	World.palette_changed.connect(update_frames)
	update_frames()


func _physics_process(delta: float) -> void:
	# Respawn timer counts down even off screen, 
	# so you never have to watch it come back.
	if _dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			reset()
		return

	if not _should_run():
		return

	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)

	var wanted := _choose_direction(delta)
	var direction := wanted
	var ledge := direction != 0.0 and stop_at_ledges and _ledge_ahead(direction)

	_jump_timer = maxf(_jump_timer - delta, 0.0)
	var jumping := false
	if can_jump and is_on_floor() and _jump_timer <= 0.0 and _wants_jump(direction, ledge):
		velocity.y = jump_velocity
		_jump_timer = jump_cooldown
		jumping = true

	# Stopping at the ledge would turn a running leap into a hop on the spot.
	if ledge and not jumping:
		direction = 0.0
		velocity.x = 0.0

	velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	move_and_slide()

	_check_touching_player()
	_update_animation(wanted)


# Off-screen chasers hold still, but one that's already hunting keeps coming
# so you can't escape it just by walking out of view.
func _should_run() -> bool:
	if not pause_off_screen or _notifier.is_on_screen():
		return true
	if _memory > 0.0:
		return true
	# Distance only
	var player := _get_player()
	return player != null and \
			global_position.distance_squared_to(player.global_position) <= sight_range * sight_range


# Returns -1, 0 or 1.
func _choose_direction(delta: float) -> float:
	var player := _get_player()
	var sees_player := player != null and _can_see(player)
	if sees_player:
		_memory = memory_time
	else:
		_memory = maxf(_memory - delta, 0.0)

	var target_x: float
	_chasing = player != null and (sees_player or _memory > 0.0)
	if _chasing:
		target_x = player.global_position.x
	elif return_home:
		target_x = home.x
	else:
		return 0.0

	var gap := target_x - global_position.x
	if absf(gap) < STOP_DISTANCE:
		return 0.0
	return signf(gap)


# Only jumps while pursuing, so a patrolling one doesn't constantly jump.
func _wants_jump(direction: float, ledge: bool) -> bool:
	if direction == 0.0 or not _chasing:
		return false
	# A gap it wants to cross, or something in the way.
	if ledge or is_on_wall():
		return true
	var player := _get_player()
	return player != null and player.global_position.y < global_position.y - climb_threshold


func _can_see(player: Node2D) -> bool:
	var eyes := global_position + _body_rect.get_center()
	if eyes.distance_squared_to(player.global_position) > sight_range * sight_range:
		return false
	if not needs_line_of_sight:
		return true
	var hit := _cast_ray(eyes, player.global_position)
	# Other characters don't block sight.
	return hit.is_empty() or hit.collider is CharacterBody2D


func _ledge_ahead(direction: float) -> bool:
	if not is_on_floor():
		return false
	var front_x := _body_rect.end.x if direction > 0.0 else _body_rect.position.x
	var from := global_position + Vector2(front_x + direction * LEDGE_LOOK_AHEAD, _body_rect.get_center().y)
	var to := Vector2(from.x, global_position.y + _body_rect.end.y + LEDGE_STEP_DOWN)
	return _cast_ray(from, to).is_empty()


func _cast_ray(from: Vector2, to: Vector2) -> Dictionary:
	_ray_query.from = from
	_ray_query.to = to
	return get_world_2d().direct_space_state.intersect_ray(_ray_query)


func _check_touching_player() -> void:
	var player := _get_player()
	if player == null:
		return
	# Distance check
	if global_position.distance_squared_to(player.global_position) > _touch_range_squared:
		return
	_touch_query.transform = Transform2D(0.0, global_position + _body_rect.get_center())
	for result in get_world_2d().direct_space_state.intersect_shape(_touch_query, 8):
		if result.collider == player:
			player.call_deferred("respawn")
			return


func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player and _player.has_signal("respawned") and not _player.is_connected("respawned", reset):
			_player.connect("respawned", reset)
	return _player


# Also runs when player respawns, which clears any pending revival too.
func reset() -> void:
	if _dead:
		_dead = false
		_respawn_timer = 0.0
		collision_layer = _home_layer
		collision_mask = _home_mask
	global_position = home
	velocity = Vector2.ZERO
	_memory = 0.0
	if sprite:
		# Stops fades stacking up.
		if _fade_tween:
			_fade_tween.kill()
		sprite.modulate.a = 0.0
		_fade_tween = create_tween()
		_fade_tween.tween_property(sprite, "modulate:a", 1.0, 0.3)


# Hazards call this!
func respawn() -> void:
	if not hurt_by_hazards or _dead:
		return
	if respawn_time <= 0.0:
		reset()
		return
	_dead = true
	_respawn_timer = respawn_time
	velocity = Vector2.ZERO
	_memory = 0.0
	_chasing = false
	# Harmless and untouchable while dead. It stops moving, so it won't fall.
	collision_layer = 0
	collision_mask = 0
	if sprite:
		if _fade_tween:
			_fade_tween.kill()
		sprite.modulate.a = 0.0


func _update_animation(facing: float) -> void:
	if sprite == null:
		return
	if facing != 0.0:
		sprite.flip_h = (facing < 0.0) != art_faces_left
	if not is_on_floor():
		_play(jump_animation if velocity.y < 0.0 else fall_animation)
	elif absf(velocity.x) > 5.0:
		_play(move_animation)
	else:
		_play(idle_animation)


func _play(animation_name: String) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	if not frames.has_animation(animation_name):
		animation_name = idle_animation
	# Skip if already playing.
	if sprite.animation == animation_name and sprite.is_playing():
		return
	if frames.has_animation(animation_name):
		sprite.play(animation_name)


# Copied from the player. Coding!
func update_frames() -> void:
	if sprite == null:
		return
	var frames: SpriteFrames = swapped_frames if World.swapped else normal_frames
	if frames == null or frames == sprite.sprite_frames:
		return
	var current := sprite.animation
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.sprite_frames = frames
	# Avoids missing-animation errors.
	if frames.has_animation(current):
		sprite.play(current)
		sprite.set_frame_and_progress(frame, progress)
