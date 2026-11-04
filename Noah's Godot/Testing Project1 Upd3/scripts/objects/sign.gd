@tool
extends Area2D

# A sign that shows its text when the player stands near it.

const WorldScript := preload("res://scripts/Base/world.gd")

const PADDING := 10.0
const POST_WIDTH := 6.0
const BOARD_SIZE := Vector2(36.0, 20.0)
const BUBBLE_GAP := 12.0

@export_multiline var text := "Test Text 123.":
	set(value):
		text = value
		queue_redraw()

@export_range(8, 48, 1) var font_size := 16:
	set(value):
		font_size = value
		queue_redraw()

# Longer lines wrap at this width.
@export_range(80.0, 600.0, 10.0) var max_width := 240.0:
	set(value):
		max_width = value
		queue_redraw()

@export_range(10.0, 600.0, 2.0) var post_height := 44.0:
	set(value):
		post_height = value
		# Moves the detection shape too, since it rides on the board.
		resize()

# Nudges the textbox on screen (Negative y is up).
# Applied after the rotation is cancelled, so it ignores how the sign is turned.
@export var bubble_offset := Vector2.ZERO:
	set(value):
		bubble_offset = value
		queue_redraw()

# How close the player has to be.
@export_range(20.0, 400.0, 5.0) var detect_radius := 90.0:
	set(value):
		detect_radius = value
		resize()

# This helps keep the text upright when the sign is rotated.
@export var detect_offset := Vector2.ZERO:
	set(value):
		detect_offset = value
		resize()

# On keeps the text up even with nobody nearby.
@export var always_show := false:
	set(value):
		always_show = value
		queue_redraw()

var reading := false


func _ready() -> void:
	resize()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	World.palette_changed.connect(queue_redraw)


# Builds its own shape, so each sign keeps its own radius.
func resize() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		if not is_node_ready():
			return
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var circle := CircleShape2D.new()
	circle.radius = detect_radius
	cs.shape = circle
	# On the board rather than the root, so a sign on a long post is noticed
	# where the sign actually hangs.
	cs.position = board_center() + detect_offset
	queue_redraw()


# Middle of the board, in local space.
func board_center() -> Vector2:
	return Vector2(0.0, -post_height - BOARD_SIZE.y / 2.0)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		reading = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		reading = false
		queue_redraw()


func _draw() -> void:
	var solid := _solid()
	var background := _background()

	draw_rect(Rect2(-POST_WIDTH / 2.0, -post_height, POST_WIDTH, post_height), solid)
	var board := Rect2(-BOARD_SIZE.x / 2.0, -post_height - BOARD_SIZE.y, BOARD_SIZE.x, BOARD_SIZE.y)
	draw_rect(board, solid)
	draw_rect(board.grow(-4.0), background)

	if text.is_empty() or not (reading or always_show or Engine.is_editor_hint()):
		return

	var font := ThemeDB.fallback_font
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_width, font_size)
	# Cancelling the node's rotation keeps the text upright and above the
	# board on screen (however the sign itself is turned).
	draw_set_transform(board_center(), -global_rotation, Vector2.ONE)
	var bubble := Rect2(
			bubble_offset.x - size.x / 2.0 - PADDING,
			bubble_offset.y - BOARD_SIZE.y / 2.0 - BUBBLE_GAP - size.y - PADDING * 2.0,
			size.x + PADDING * 2.0,
			size.y + PADDING * 2.0)
	draw_rect(bubble, background)
	draw_rect(bubble, solid, false, 2.0)
	# "draw_multiline_string" starts at the first line's baseline, not its top.
	var start := bubble.position + Vector2(PADDING, PADDING + font.get_ascent(font_size))
	draw_multiline_string(font, start, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, -1, solid)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Editor has no World autoload.
func _solid() -> Color:
	return WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()


func _background() -> Color:
	return WorldScript.LIGHT if Engine.is_editor_hint() else World.background_color()
