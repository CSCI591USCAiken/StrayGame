extends Control

@onready var knob = $Knob
@onready var center_pos = size / 2.0
@onready var max_distance = size.x / 2.0

var is_dragging = false

func _gui_input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
		else:
			is_dragging = false
			knob.position = center_pos - (knob.size / 2.0) # Snap back
			Input.action_release("move_left")
			Input.action_release("move_right")
			Input.action_release("jump") # Release jump when thumb lifts
			
	if event is InputEventScreenDrag and is_dragging:
		var drag_pos = event.position
		var distance = center_pos.distance_to(drag_pos)
		
		if distance > max_distance:
			drag_pos = center_pos + (drag_pos - center_pos).normalized() * max_distance
			
		knob.position = drag_pos - (knob.size / 2.0)
		
		# --- LEFT / RIGHT ---
		var offset_x = drag_pos.x - center_pos.x
		if offset_x > 10:
			Input.action_press("move_right")
			Input.action_release("move_left")
		elif offset_x < -10:
			Input.action_press("move_left")
			Input.action_release("move_right")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")

		# --- UP / JUMP ---
		var offset_y = drag_pos.y - center_pos.y
		if offset_y < -20: # -20 makes sure they don't accidentally jump while running
			Input.action_press("jump")
		else:
			Input.action_release("jump")
