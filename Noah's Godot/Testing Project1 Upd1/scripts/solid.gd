@tool
extends StaticBody2D

# A wall or platform. It draws itself from its CollisionShape2D,
# so changing the size below resizes what you see.
# Convienent platforms!

# World doesn't exist in the editor, so colors come from the script there.
const WorldScript := preload("res://scripts/world.gd")

# 0 on both means "keep whatever shape the node already has".
@export_range(0.0, 1200.0, 1.0) var width := 0.0:
	set(value):
		width = value
		resize()

@export_range(0.0, 700.0, 1.0) var height := 0.0:
	set(value):
		height = value
		resize()


func _ready() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	# Adopt an existing shape so platforms built before this still work.
	# (This, as in the new slider system on the platforms).
	if width == 0.0 and height == 0.0 and cs and cs.shape is RectangleShape2D:
		width = cs.shape.size.x
		height = cs.shape.size.y
	else:
		resize()
	# Live redraw while editing.
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		World.palette_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


# New shape per instance, so resizing one never affects the others.
func resize() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or width == 0.0 or height == 0.0:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	cs.shape = rect
	queue_redraw()


func _draw() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null:
		return
	var size: Vector2 = cs.shape.size
	var color: Color = WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()
	draw_rect(Rect2(cs.position - size / 2, size), color)
