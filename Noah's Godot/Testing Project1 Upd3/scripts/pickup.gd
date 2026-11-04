@tool
extends Area2D

# A collectible. Touching it makes it fade out.
# This is just a test item so there's something in the world to collect.

signal picked_up(body: Node2D)

const WorldScript := preload("res://scripts/Base/world.gd")

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()

# Longest side of the drawn texture. Aspect ratio is kept.
@export_range(8.0, 256.0, 1.0) var display_size := 32.0:
	set(value):
		display_size = value
		queue_redraw()

@export_range(8.0, 200.0, 2.0) var pickup_radius := 24.0:
	set(value):
		pickup_radius = value
		resize()

# "On" recolors the texture to match the world instead of its own colors.
# This might be useful if we keep this script, I mainly got it from the 
# joystick script.
@export var palette_tint := false:
	set(value):
		palette_tint = value
		queue_redraw()

@export_group("Collecting")
@export_range(0.05, 1.5, 0.05) var collect_time := 0.3
@export_range(1.0, 4.0, 0.1) var grow_scale := 1.8

@export_group("Idle")
# 0 keeps it still.
@export_range(0.0, 40.0, 1.0) var bob_height := 0.0
@export_range(0.1, 5.0, 0.1) var bob_time := 1.6

var collected := false
var base_y := 0.0
var time := 0.0


func _ready() -> void:
	resize()
	base_y = position.y
	# Must be set before the editor check. Left on, "_process" would rewrite
	# "position.y" every frame and the node could only be dragged sideways.
	set_process(not Engine.is_editor_hint() and bob_height > 0.0)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	World.palette_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	position.y = base_y + sin(time * TAU / bob_time) * bob_height


# Builds its own shape, so each pickup keeps its own radius.
func resize() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		if not is_node_ready():
			return
		cs = CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		add_child(cs)
	var circle := CircleShape2D.new()
	circle.radius = pickup_radius
	cs.shape = circle
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if collected or not body.is_in_group("player"):
		return
	collected = true
	picked_up.emit(body)
	# Stops a second body collecting it while the animation plays.
	set_deferred("monitoring", false)
	set_process(false)

	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", scale * grow_scale, collect_time) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, collect_time)
	await tween.finished
	queue_free()


func _draw() -> void:
	if texture == null:
		# Visible placeholder until a texture is dropped in.
		draw_circle(Vector2.ZERO, display_size / 2.0, _solid())
		return
	var source := texture.get_size()
	var scaled := source * (display_size / maxf(source.x, source.y))
	draw_texture_rect(texture, Rect2(-scaled / 2.0, scaled), false, _tint())


func _tint() -> Color:
	return _solid() if palette_tint else Color.WHITE


# Editor has no World autoload.
func _solid() -> Color:
	return WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()
