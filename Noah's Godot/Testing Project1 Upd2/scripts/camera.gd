extends Camera2D

# The camera that tracks where the player is going.

# This "unbounded" constant helps ensure the camera is consistantly 
# free-moving throughout any scene.
const UNBOUNDED := 10000000

# "Off" lets the view run freely across a world of rooms (the maze concept).
@export var lock_to_room := true:
	set(value):
		lock_to_room = value
		if not lock_to_room:
			clear_limits()

@export var room_size := Vector2(1152, 648)
@export_range(1.0, 20.0, 0.5) var smoothing := 8.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = smoothing
	if lock_to_room:
		set_room(Rect2(Vector2.ZERO, room_size))
	else:
		clear_limits()


# This calls when the player enters a room to snap the view to it.
func set_room(rect: Rect2) -> void:
	if not lock_to_room:
		return
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
	reset_smoothing()


func clear_limits() -> void:
	limit_left = -UNBOUNDED
	limit_top = -UNBOUNDED
	limit_right = UNBOUNDED
	limit_bottom = UNBOUNDED
