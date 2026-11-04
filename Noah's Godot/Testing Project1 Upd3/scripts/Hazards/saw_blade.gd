@tool
extends Area2D

# Saw blade on a stick!

const WorldScript := preload("res://scripts/Base/world.gd")

enum Motion {
	STILL, # Only the blade spins.
	SPIN, # Stick rotates fully.
	SWING, # Stick swings like pendulum.
}

@export_group("Blade")
@export var blade_color := Color(0.88, 0.34, 0.31)
@export_range(8.0, 200.0, 1.0) var blade_radius := 32.0
@export_range(4, 32, 1) var teeth := 12
# Degrees per second.
@export var blade_spin_speed := 540.0
# Smaller hitbox feels fairer to player.
@export_range(0.5, 1.0, 0.05) var hitbox_scale := 0.85

@export_group("Stick")
@export_range(0.0, 800.0, 1.0) var stick_length := 120.0
@export_range(1.0, 30.0, 1.0) var stick_width := 6.0

@export_group("Movement")
@export var motion: Motion = Motion.SPIN
# 0 right, 90 down.
@export_range(0.0, 360.0, 1.0) var start_angle := 90.0
# SPIN only, degrees per second.
@export var spin_speed := 90.0
# SWING only.
@export_range(0.0, 360.0, 1.0) var swing_arc := 120.0
# Seconds per full swing.
@export_range(0.2, 10.0, 0.1) var swing_time := 2.0
# Staggers other saws.
@export var time_offset := 0.0

var hitbox: CollisionShape2D
var _arm: Node2D
var _blade: Node2D
var _time := 0.0
var _arm_angle := 0.0
var _blade_angle := 0.0
var _last_state := []


func _ready() -> void:
	hitbox = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if hitbox == null:
		hitbox = CollisionShape2D.new()
		add_child(hitbox)
	# Own shape per saw (good for different kinds of saws).
	hitbox.shape = CircleShape2D.new()
	_apply_radius()
	_update_pose(time_offset)
	set_process(Engine.is_editor_hint())
	set_physics_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return

	body_entered.connect(_on_body_entered)
	World.palette_changed.connect(_redraw_all)
	# Drawn once, then just rotated.
	_arm = Node2D.new()
	_arm.show_behind_parent = true
	_arm.rotation = _arm_angle
	_arm.draw.connect(func(): _draw_stick(_arm, Vector2(stick_length, 0.0)))
	add_child(_arm)
	_blade = Node2D.new()
	_blade.position = Vector2(stick_length, 0.0)
	_blade.rotation = _blade_angle
	_blade.draw.connect(func(): _draw_blade(_blade, Vector2.ZERO, 0.0))
	_arm.add_child(_blade)


# Editor: redraw only after edits (optimization).
func _process(_delta: float) -> void:
	var state := [blade_color, blade_radius, teeth, blade_spin_speed, hitbox_scale,
			stick_length, stick_width, motion, start_angle, spin_speed,
			swing_arc, swing_time, time_offset]
	if state == _last_state:
		return
	_last_state = state
	_apply_radius()
	_update_pose(time_offset)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	_update_pose(_time + time_offset)
	if motion != Motion.STILL:
		_arm.rotation = _arm_angle
	_blade.rotation = _blade_angle


func _apply_radius() -> void:
	var shape := hitbox.shape as CircleShape2D
	if shape:
		shape.radius = blade_radius * hitbox_scale


func _update_pose(t: float) -> void:
	_arm_angle = _arm_angle_at(t)
	# Wrapping avoids long-run jitter (was once an issue).
	_blade_angle = fposmod(deg_to_rad(blade_spin_speed) * t, TAU)
	var blade_position := Vector2.from_angle(_arm_angle) * stick_length
	if hitbox.position != blade_position:
		hitbox.position = blade_position


func _arm_angle_at(t: float) -> float:
	var middle := deg_to_rad(start_angle)
	match motion:
		Motion.SPIN:
			return fposmod(middle + deg_to_rad(spin_speed) * t, TAU)
		Motion.SWING:
			return middle + sin(t * TAU / swing_time) * deg_to_rad(swing_arc) / 2.0
	return middle


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("respawn"):
		body.call_deferred("respawn")


func _redraw_all() -> void:
	queue_redraw()
	_arm.queue_redraw()
	_blade.queue_redraw()


func _draw() -> void:
	# In game drawing of object.
	if Engine.is_editor_hint():
		var blade_center := Vector2.from_angle(_arm_angle) * stick_length
		_draw_guide()
		_draw_stick(self, blade_center)
		_draw_blade(self, blade_center, _blade_angle)
	draw_circle(Vector2.ZERO, stick_width * 1.5, _solid())
	draw_circle(Vector2.ZERO, stick_width * 0.6, _background())


# Editor guide of blade path.
func _draw_guide() -> void:
	if stick_length <= 0.0:
		return
	var guide := Color(blade_color, 0.3)
	var middle := deg_to_rad(start_angle)
	match motion:
		Motion.SPIN:
			draw_arc(Vector2.ZERO, stick_length, 0.0, TAU, 64, guide, 2.0)
		Motion.SWING:
			var half := deg_to_rad(swing_arc) / 2.0
			draw_arc(Vector2.ZERO, stick_length, middle - half, middle + half, 32, guide, 2.0)


func _draw_stick(canvas: CanvasItem, tip: Vector2) -> void:
	if stick_length > 0.0:
		canvas.draw_line(Vector2.ZERO, tip, _solid(), stick_width)


func _draw_blade(canvas: CanvasItem, center: Vector2, spin: float) -> void:
	# Teeth as one zigzag polygon.
	var inner := blade_radius * 0.75
	var step := TAU / teeth
	var points := PackedVector2Array()
	for i in teeth:
		var a := spin + i * step
		points.append(center + Vector2.from_angle(a) * inner)
		points.append(center + Vector2.from_angle(a + step * 0.8) * blade_radius)
	canvas.draw_colored_polygon(points, blade_color)
	canvas.draw_circle(center, inner * 0.85, blade_color.darkened(0.25))
	# Holes make spinning visible.
	for i in 3:
		var a := spin + i * TAU / 3.0
		canvas.draw_circle(center + Vector2.from_angle(a) * inner * 0.5, inner * 0.14, _background())
	canvas.draw_circle(center, blade_radius * 0.15, _solid())


# Editor has no World autoload.
func _solid() -> Color:
	return WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()


func _background() -> Color:
	return WorldScript.LIGHT if Engine.is_editor_hint() else World.background_color()
