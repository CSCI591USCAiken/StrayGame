extends Node

# This is the script that allows the world to have its colors changed from
# black to white (and vise-versa) and also allows input to be registered.
# A sort of "base" code needed for every scene. Automatically loaded though; simple.

signal palette_changed

# I chose to have the black/white shades render not perfectly white and black
# to both differentiate from the original game inspiration and to sort of
# give off a "testing" feel, I'd suppose? It can be easily changed regardless.
const LIGHT := Color(0.949, 0.937, 0.914)
const DARK := Color(0.25, 0.25, 0.27)

# Registered in code so the project runs with no Input Map setup.
# We will have to fix this to work with mobile and potentially controllers later.
const KEYS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"swap_colors": [KEY_E],
	"interact": [KEY_F],
}

# First loaded in, no swap for you! You no press swap button! :(
var swapped := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(background_color())
	for action in KEYS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

# Gorsh! The swapping!
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("swap_colors"):
		swapped = not swapped
		RenderingServer.set_default_clear_color(background_color())
		palette_changed.emit()

func background_color() -> Color:
	return DARK if swapped else LIGHT


func solid_color() -> Color:
	return LIGHT if swapped else DARK
