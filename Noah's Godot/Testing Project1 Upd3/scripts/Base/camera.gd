extends Camera2D

# Follows the player. Limits keep it from showing the void past a room's edge.

# Godot's own "no limit" values, used when the camera runs free.
const UNBOUNDED := 10000000

# Off lets the view run freely across a world of rooms laid side by side.
@export var lock_to_room := true:
	set(value):
		lock_to_room = value
		if not lock_to_room:
			clear_limits()

@export var room_size := Vector2(1152, 648)
@export_range(1.0, 20.0, 0.5) var smoothing := 8.0

# On glides between rooms instead of cutting straight to the next one.
@export var slide_between_rooms := false
@export_range(0.1, 2.0, 0.05) var slide_time := 0.45

var slide: Tween = null


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing
	if lock_to_room:
		set_room(Rect2(Vector2.ZERO, room_size))
	else:
		clear_limits()


# Call this when the player enters a room to re-clamp the view to it.
# Does nothing while unlocked, so the flag wins over any room manager.
func set_room(rect: Rect2) -> void:
	if not lock_to_room:
		return
	# Snap on the first call, or there'd be a slide in from infinity.
	if not slide_between_rooms or limit_right == UNBOUNDED:
		apply_limits(rect)
		reset_smoothing()
		return

	if slide:
		slide.kill()
	# Limits clamp after smoothing, so animating them is what moves the view.
	slide = create_tween().set_parallel()
	slide.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slide.tween_property(self, "limit_left", int(rect.position.x), slide_time)
	slide.tween_property(self, "limit_top", int(rect.position.y), slide_time)
	slide.tween_property(self, "limit_right", int(rect.end.x), slide_time)
	slide.tween_property(self, "limit_bottom", int(rect.end.y), slide_time)


func apply_limits(rect: Rect2) -> void:
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)


func clear_limits() -> void:
	if slide:
		slide.kill()
	limit_left = -UNBOUNDED
	limit_top = -UNBOUNDED
	limit_right = UNBOUNDED
	limit_bottom = UNBOUNDED
