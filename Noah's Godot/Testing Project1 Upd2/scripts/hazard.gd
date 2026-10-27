@tool
extends Area2D

# Spikes. Touching them sends the player back to the spawn-point.

@export var color := Color(0.88, 0.34, 0.31)

# Width of a single spike. Shown in inspector
@export var spike_width := 20.0

# Width of the base spikes. This value will draw 10 spikes. Shown in inspecor.
@export var width := 200.0:
	set(value):
		width = value
		resize()

# Height of the base spikes. Shown in inspector.
@export var height := 20.0:
	set(value):
		height = value
		resize()


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	resize()
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	queue_redraw()


# This here is important. I have made the spikes into a "package" of sorts that can be
# dragged-and-dropped onto any scene. Packages in Godot work by having singular assets
# (like the spikes) in their own scenes. Scenes can be fully dragged-and-dropped into others
# to implement what they have into the other scene. The downside of this is that the user
# cannot edit much of the packaged scene content within the new scene. 
# What this code does here is allow for individual spikes objects placed in other scenes to have 
# their own values for width and height, with help from the inspector for each. Without this,
# each spike object would have the same width and height throughout the whole project.
func resize() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	cs.shape = rect
	queue_redraw()

# Player touched the spike! Player respawns.
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("respawn"):
		# Deferred so the player isn't moved while respawning.
		body.call_deferred("respawn")

# Drawing the spikes.
func _draw() -> void:
	var size: Vector2 = $CollisionShape2D.shape.size
	var rect := Rect2($CollisionShape2D.position - size / 2, size)
	var count := maxi(1, roundi(size.x / spike_width))
	var w := size.x / count
	# One zigzag outline rather than a triangle each, so a strip of any
	# length costs a single draw call. Optimized!
	var points := PackedVector2Array([Vector2(rect.position.x, rect.end.y)])
	for i in count:
		var x: float = rect.position.x + i * w
		points.append(Vector2(x + w / 2, rect.position.y))
		points.append(Vector2(x + w, rect.end.y))
	draw_colored_polygon(points, color)
