extends Control

# On-screen button for an action (for mobile users).
# (This is currently only for the warp button but could be used for
# something else in the future).

@export var action := "swap_colors"
# Off keeps the control on screen whatever the last input was.
@export var auto_hide := true

@export_group("Textures")
@export var normal_texture: Texture2D:
	set(value):
		normal_texture = value
		queue_redraw()
# Blank reuses normal texture.
@export var pressed_texture: Texture2D:
	set(value):
		pressed_texture = value
		queue_redraw()
# Recolor with World palette.
@export var palette_tint := true
@export_range(0.0, 1.0, 0.05) var idle_alpha := 0.45
@export_range(0.0, 1.0, 0.05) var pressed_alpha := 0.7

var _finger := -1


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
	if not visible or not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if touch.pressed and _finger == -1 and _is_inside(touch.position):
		_finger = touch.index
		_send(true)
		get_viewport().set_input_as_handled()
	elif not touch.pressed and touch.index == _finger:
		_release()


func _notification(what: int) -> void:
	# Prevents stuck input.
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED, NOTIFICATION_EXIT_TREE:
			_release()
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_release()


func _release() -> void:
	if _finger == -1:
		return
	_finger = -1
	_send(false)


func _is_inside(screen_position: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_position
	return local.distance_to(size / 2.0) <= minf(size.x, size.y) / 2.0


# Acts like a keypress.
func _send(pressed: bool) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = pressed
	Input.parse_input_event(press)
	queue_redraw()


func _draw() -> void:
	var held := _finger != -1
	var texture := pressed_texture if held and pressed_texture else normal_texture
	if not texture:
		return
	var tint := World.solid_color() if palette_tint else Color.WHITE
	var side := minf(size.x, size.y)
	var rect := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_texture_rect(texture, rect, false, Color(tint, pressed_alpha if held else idle_alpha))
