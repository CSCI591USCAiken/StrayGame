@tool
extends Area2D

# This is the test door that allows the player to complete a level and move to the next scene/level.
# The player can currently press "F" to enter. Other ways to enter will be added after we confirm
# what we're fully doing for the game's design. This door is meant to be a template that can be changed
# or scrapped later.

# We need the "world" script loaded for the doors to work properly.
const WorldScript := preload("res://scripts/world.gd")

# The inspector contains a component that allows the user to place in what scene they want the door
# to lead to. "target_scene" is its name. The code will call on this later.
@export var exit_point: Node2D
@export_file("*.tscn") var target_scene: String

# Base for player detection
var player = null


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	World.palette_changed.connect(queue_redraw)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	queue_redraw()

# If the player is standing in front of the door and interacts with it, the player model shrinks and disappears,
# then the scene is moved to the selected one in the inspector (the previous "target_scene" value)
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not event.is_action_pressed("interact"):
		return
	var door_x: float = $CollisionShape2D.global_position.x
	if target_scene:
		player.exit_to_scene(door_x, target_scene)
	else:
		var exit_position: Vector2 = exit_point.global_position if exit_point else player.spawn_position
		player.enter_door(door_x, exit_position)
	queue_redraw()

# Player detected in front of door
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_door"):
		player = body
		queue_redraw()

# Player no longer in front of door
func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		queue_redraw()

# Drawing the door
func _draw() -> void:
	var size: Vector2 = $CollisionShape2D.shape.size
	var rect := Rect2($CollisionShape2D.position - size / 2, size)

	# The black/white look of the world is not viewable in the editor, 
	# so we have to also have a fallback color.
	var frame_color: Color = WorldScript.DARK
	var bg_color: Color = WorldScript.LIGHT
	if not Engine.is_editor_hint():
		frame_color = World.solid_color()
		bg_color = World.background_color()

	draw_rect(rect, frame_color)
	draw_rect(rect.grow_individual(-6, -6, -6, 0), frame_color.lerp(bg_color, 0.6))

	# The "F" prompt, shown only while the player can actually use the door.
	# Gotta fix with different inputs later.
	if player and not player.busy:
		var key := Rect2(rect.get_center().x - 14, rect.position.y - 40, 28, 28)
		draw_rect(key, frame_color)
		draw_string(ThemeDB.fallback_font, key.position + Vector2(0, 20), "F", HORIZONTAL_ALIGNMENT_CENTER, 28, 18, bg_color)
