extends Control

# On-screen movement joystick (for mobile users).

@export_range(0.0, 0.9, 0.05) var dead_zone := 0.2
# Tilt needed to jump/crouch.
@export_range(0.1, 1.0, 0.05) var vertical_threshold := 0.6
# Blank means no action.
@export var up_action := "jump"
@export var down_action := "crouch"
# Off keeps the control on screen whatever the last input was.
@export var auto_hide := true

@export_group("Textures")
@export var base_texture: Texture2D:
	set(value):
		base_texture = value
		queue_redraw()
@export var knob_texture: Texture2D:
	set(value):
		knob_texture = value
		queue_redraw()
# Knob radius versus base.
@export_range(0.1, 1.0, 0.05) var knob_scale := 0.4
# Recolor with World palette.
@export var palette_tint := true
@export_range(0.0, 1.0, 0.05) var idle_alpha := 0.4
@export_range(0.0, 1.0, 0.05) var pressed_alpha := 0.65

var _finger := -1
var _knob := Vector2.ZERO
var _held := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	World.palette_changed.connect(queue_redraw)
	World.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(World.touch_mode)


func _on_input_mode_changed(touch: bool) -> void:
	# Stays listening while hidden, so a tap can bring it back.
	visible = touch or not auto_hide


func _input(event: InputEvent) -> void:
	# Hidden means a tap should fall through to World and switch modes.
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _finger == -1 and _to_center(touch.position).length() <= _radius() * 1.2:
			_finger = touch.index
			_move_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _finger:
			_release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			_move_knob(drag.position)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Prevents stuck input.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			_release()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_release()


func _radius() -> float:
	return minf(size.x, size.y) / 2.0


# Screen point to center offset.
func _to_center(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position - size / 2.0


func _move_knob(screen_position: Vector2) -> void:
	var radius := _radius()
	if radius <= 0.0:
		return
	_knob = _to_center(screen_position).limit_length(radius)
	var stick := _knob / radius
	var push := clampf((absf(stick.x) - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	_set_action("move_left", push if stick.x < 0.0 else 0.0)
	_set_action("move_right", push if stick.x > 0.0 else 0.0)
	_set_action(up_action, 1.0 if stick.y < -vertical_threshold else 0.0)
	_set_action(down_action, 1.0 if stick.y > vertical_threshold else 0.0)
	queue_redraw()


func _release() -> void:
	_finger = -1
	_knob = Vector2.ZERO
	for action in _held.keys():
		Input.action_release(action)
	_held.clear()
	queue_redraw()


# Only tells Input about changes.
func _set_action(action: String, strength: float) -> void:
	if action.is_empty() or _held.get(action, 0.0) == strength:
		return
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = strength
	else:
		Input.action_release(action)
		_held.erase(action)


func _tint() -> Color:
	return World.solid_color() if palette_tint else Color.WHITE


# Square rect around a point.
func _square(center: Vector2, radius: float) -> Rect2:
	return Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)


func _draw() -> void:
	var tint := _tint()
	var center := size / 2.0
	var radius := _radius()
	if base_texture:
		draw_texture_rect(base_texture, _square(center, radius), false, Color(tint, idle_alpha))
	if knob_texture:
		var alpha := pressed_alpha if _finger != -1 else idle_alpha
		draw_texture_rect(knob_texture, _square(center + _knob, radius * knob_scale), false, Color(tint, alpha))
