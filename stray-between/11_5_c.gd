extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const AFK_TIMEOUT_1 = 5.0   # First rest stage
const AFK_TIMEOUT_2 = 10.0  # Deep AFK stage (after 10 total seconds)
const AFK_TIMEOUT_3 = 20.0  # Deepest AFK stage (after 15 total seconds)
const wall_jump_velocity = Vector2(-400, -300)
const wall_pushback_force = 200.0
const wall_gravity = 1600.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var afk_timer = 0.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		if is_on_wall():
			velocity.y += wall_gravity * delta
			velocity.y = min(velocity.y, wall_gravity)
		else:
			velocity.y += gravity * delta

	# Handle jump (also resets the AFK timer).
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		afk_timer = 0.0
	elif Input.is_action_just_pressed("ui_accept") and is_on_wall():
		velocity = wall_jump_velocity
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * wall_pushback_force
		afk_timer = 0.0

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		afk_timer = 0.0
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, direction * SPEED, SPEED * delta * 5.0)
		if is_on_floor() and velocity.x == 0:
			afk_timer += delta

	move_and_slide()
	
	# Animation states
	if not is_on_floor():
		if is_on_wall():
			$AnimatedSprite2D.play("fall")
		else:
			$AnimatedSprite2D.play("jump")
	elif velocity.x == 0:
		# Check the LONGEST timer first
		if afk_timer >= AFK_TIMEOUT_3:
			$AnimatedSprite2D.play("sleep")
		elif afk_timer >= AFK_TIMEOUT_2:
			$AnimatedSprite2D.play("afk")
		elif afk_timer >= AFK_TIMEOUT_1:
			$AnimatedSprite2D.play("idlRest")
		else:
			$AnimatedSprite2D.play("idle")
	else:
		$AnimatedSprite2D.play("run")
