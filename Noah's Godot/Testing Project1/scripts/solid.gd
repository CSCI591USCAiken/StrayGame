@tool
extends StaticBody2D

# A basic wall or platform. Versatile! It draws itself from its CollisionShape2D,
# so resizing the shape resizes what you see.

# The black/white look of the world can't be seen in the editor, so we need to have a fallback color
# to view the world on.
const WorldScript := preload("res://scripts/world.gd")


func _ready() -> void:
	# Live redraw while editing; at runtime it only redraws on a palette swap. Optimized!
	set_process(Engine.is_editor_hint())
	if not Engine.is_editor_hint():
		World.palette_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()

# Color of world in-game
func _draw() -> void:
	var size: Vector2 = $CollisionShape2D.shape.size
	var color: Color = WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()
	draw_rect(Rect2($CollisionShape2D.position - size / 2, size), color)
