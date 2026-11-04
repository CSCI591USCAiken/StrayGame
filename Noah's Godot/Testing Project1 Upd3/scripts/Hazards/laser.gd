@tool
extends Node2D

# Timed laser. Walls stop beam.
# Setup: just a Node2D.
# Rotate node to aim.

const WorldScript := preload("res://scripts/Base/world.gd")

# Turret drawing sizes.
const BODY_SIZE := 28.0
const BARREL_LENGTH := 22.0
const BARREL_WIDTH := 10.0
const MAX_RESULTS := 32

enum Phase { OFF, WARNING, ON }

@export var beam_color := Color(0.88, 0.34, 0.31)
@export_range(2.0, 40.0, 1.0) var beam_width := 8.0
@export_range(16.0, 4000.0, 1.0) var max_length := 1200.0
# Layers that block the beam.
@export_flags_2d_physics var collision_mask := 1

@export_group("Timing")
@export var always_on := false
@export_range(0.0, 10.0, 0.05) var off_time := 1.5
@export_range(0.0, 5.0, 0.05) var warning_time := 0.6
@export_range(0.05, 10.0, 0.05) var on_time := 1.0
# Staggers neighbouring lasers.
@export var time_offset := 0.0

@export_group("Visibility")
# Off-screen lasers hold fire and restart their cycle when seen, so there's
# always a warning before the beam. Off lets them run unseen.
@export var pause_off_screen := true
# Padding around the turret that still counts as on screen. Negative values
# inset it instead, so the turret must be properly in view before it wakes.
@export_range(-64.0, 400.0, 4.0) var screen_margin := 0.0

@export_group("Aiming")
# Tracks player while off.
@export var aim_at_player := false
# Degrees per second.
@export var turn_speed := 120.0
# Max turn either way.
@export_range(0.0, 180.0, 1.0) var aim_limit := 80.0

var _time := 0.0
var _phase: Phase = Phase.OFF
# Relative to node rotation.
var _aim := 0.0
var _beam_length := 0.0
var _player: Node2D
var _on_screen := false
var _notifier: VisibleOnScreenNotifier2D
var _barrel: Node2D
var _beam: Node2D
var _lens: Node2D
var _last_state := []
var _ray_query := PhysicsRayQueryParameters2D.new()
var _hurt_shape := RectangleShape2D.new()
var _hurt_query := PhysicsShapeQueryParameters2D.new()


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	set_physics_process(not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	_hurt_query.shape = _hurt_shape
	# Filtered by respawn() instead.
	_hurt_query.collision_mask = 0xFFFFFFFF
	World.palette_changed.connect(_redraw_all)

	# Drawn once, then just moved.
	_barrel = Node2D.new()
	_barrel.show_behind_parent = true
	_barrel.draw.connect(func(): _draw_barrel(_barrel))
	add_child(_barrel)
	_beam = Node2D.new()
	_beam.position = Vector2(BARREL_LENGTH, 0.0)
	_beam.visible = false
	_beam.draw.connect(_draw_beam)
	_barrel.add_child(_beam)
	_lens = Node2D.new()
	_lens.modulate.a = 0.0
	_lens.draw.connect(func(): _lens.draw_circle(Vector2.ZERO, BODY_SIZE * 0.25, beam_color))
	add_child(_lens)

	# Covers the turret only. Sizing it to the beam's reach would make the
	# rect bigger than the screen, so it would never count as off screen.
	_notifier = VisibleOnScreenNotifier2D.new()
	# Floored so a large negative margin can't collapse the box to nothing.
	var half := maxf(2.0, BODY_SIZE / 2.0 + screen_margin)
	_notifier.rect = Rect2(-half, -half, half * 2.0, half * 2.0)
	add_child(_notifier)


# Editor: redraw only after edits.
func _process(_delta: float) -> void:
	var state := [beam_color, max_length, beam_width, always_on, off_time,
			warning_time, on_time, time_offset, aim_at_player, turn_speed, aim_limit]
	if state == _last_state:
		return
	_last_state = state
	queue_redraw()


func _physics_process(delta: float) -> void:
	if pause_off_screen:
		var seen := _notifier.is_on_screen()
		if seen and not _on_screen:
			# Back to the top of the cycle, so the player always gets the warning.
			_time = -time_offset
		_on_screen = seen
		if not seen:
			if _phase != Phase.OFF:
				_phase = Phase.OFF
				_beam.visible = false
				_beam.modulate.a = 0.0
				_lens.modulate.a = 0.0
			return
	_time += delta
	var old_phase := _phase
	var old_length := _beam_length
	_phase = _phase_at(_time + time_offset)

	if aim_at_player and (_phase == Phase.OFF or always_on):
		_turn_toward_player(delta)
		_barrel.rotation = _aim

	if _phase != Phase.OFF:
		_beam_length = _cast_beam()
		if _phase == Phase.ON:
			_hurt_things_in_beam()

	# Redraw beam only on change.
	if _phase != old_phase or _beam_length != old_length:
		_beam.visible = _phase != Phase.OFF
		_beam.queue_redraw()

	# Flicker via fading, not redrawing.
	var glow := 0.0
	if _phase == Phase.WARNING:
		glow = 0.4 + 0.4 * sin(_time * 40.0)
	elif _phase == Phase.ON:
		glow = 1.0
	_beam.modulate.a = glow
	_lens.modulate.a = glow


func _phase_at(t: float) -> Phase:
	if always_on:
		return Phase.ON
	var cycle := off_time + warning_time + on_time
	var c := fposmod(t, cycle)
	if c < off_time:
		return Phase.OFF
	if c < off_time + warning_time:
		return Phase.WARNING
	return Phase.ON


func _cast_beam() -> float:
	var direction := Vector2.from_angle(global_rotation + _aim)
	var from := global_position + direction * BARREL_LENGTH
	_ray_query.from = from
	_ray_query.to = from + direction * max_length
	_ray_query.collision_mask = collision_mask
	# Characters don't block the beam.
	var ignored: Array[RID] = []
	for _attempt in 8:
		_ray_query.exclude = ignored
		var hit := get_world_2d().direct_space_state.intersect_ray(_ray_query)
		if hit.is_empty():
			return max_length
		if hit.collider is CharacterBody2D:
			ignored.append(hit.rid)
		else:
			return from.distance_to(hit.position)
	return max_length


func _hurt_things_in_beam() -> void:
	if _beam_length < 1.0:
		return
	var angle := global_rotation + _aim
	var direction := Vector2.from_angle(angle)
	var from := global_position + direction * BARREL_LENGTH
	_hurt_shape.size = Vector2(_beam_length, beam_width)
	_hurt_query.transform = Transform2D(angle, from + direction * _beam_length / 2.0)
	# Re-query if walls fill results.
	var seen: Array[RID] = []
	for _attempt in 4:
		_hurt_query.exclude = seen
		var results := get_world_2d().direct_space_state.intersect_shape(_hurt_query, MAX_RESULTS)
		for result in results:
			var rid: RID = result.rid
			if rid in seen:
				continue
			seen.append(rid)
			var body: Object = result.collider
			if body and body.has_method("respawn"):
				body.call_deferred("respawn")
		if results.size() < MAX_RESULTS:
			return


func _turn_toward_player(delta: float) -> void:
	var player := _get_player()
	if player == null:
		return
	var to_player := player.global_position - global_position
	if to_player.length_squared() > max_length * max_length:
		return
	var limit := deg_to_rad(aim_limit)
	var target := clampf(wrapf(to_player.angle() - global_rotation, -PI, PI), -limit, limit)
	# Short way, capped by speed.
	var difference := wrapf(target - _aim, -PI, PI)
	var step := deg_to_rad(turn_speed) * delta
	_aim = wrapf(_aim + clampf(difference, -step, step), -PI, PI)


# Needs player.gd's group line.
func _get_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player


func _redraw_all() -> void:
	queue_redraw()
	_barrel.queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		# Shows aim and reach.
		var muzzle := Vector2(BARREL_LENGTH, 0.0)
		draw_line(muzzle, muzzle + Vector2(max_length, 0.0), Color(beam_color, 0.3), 2.0)
		_draw_barrel(self)
	draw_rect(Rect2(Vector2.ONE * -BODY_SIZE / 2.0, Vector2.ONE * BODY_SIZE), _solid())
	# Lens doubles as status light.
	draw_circle(Vector2.ZERO, BODY_SIZE * 0.25, _background())


func _draw_barrel(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(0.0, -BARREL_WIDTH / 2.0, BARREL_LENGTH, BARREL_WIDTH), _solid())


func _draw_beam() -> void:
	var end := Vector2(_beam_length, 0.0)
	if _phase == Phase.WARNING:
		_beam.draw_line(Vector2.ZERO, end, beam_color, 2.0)
	elif _phase == Phase.ON:
		_beam.draw_line(Vector2.ZERO, end, Color(beam_color, 0.3), beam_width * 2.0) # soft glow
		_beam.draw_line(Vector2.ZERO, end, beam_color, beam_width)
		_beam.draw_line(Vector2.ZERO, end, beam_color.lightened(0.6), beam_width * 0.3) # hot core
		_beam.draw_circle(end, beam_width * 0.8, beam_color) # impact


# Editor has no World autoload.
func _solid() -> Color:
	return WorldScript.DARK if Engine.is_editor_hint() else World.solid_color()


func _background() -> Color:
	return WorldScript.LIGHT if Engine.is_editor_hint() else World.background_color()
