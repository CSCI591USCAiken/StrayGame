extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const AFK_TIMEOUT = 5.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var afk_timer = 0.0



func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		afk_timer = 0.0
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			afk_timer += delta

	move_and_slide()
	
	if not is_on_floor():
		$AnimatedSprite2D.play("jump")
	elif velocity.x == 0:
		if afk_timer >= AFK_TIMEOUT:
			$AnimatedSprite2D.play("idlRest")
		else:
			$AnimatedSprite2D.play("idle")
	else:
		$AnimatedSprite2D.play("run")

	
