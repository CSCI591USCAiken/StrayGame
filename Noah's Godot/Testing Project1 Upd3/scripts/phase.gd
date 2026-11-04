@tool
extends Node2D

# This helps control what items are in what world (normal or swapped/warped).
# Easily put whatever you want under the node2d with this script attached and it'll
# be affected.

@export_enum("Normal", "Swapped") var world: int = 0

# Objects fade instead of immediately disappearing. Collision still switches instantly.
@export_range(0.0, 1.0, 0.05) var fade_time := 0.15

var bodies: Array[CollisionObject2D] = []
var tilemaps: Array[TileMapLayer] = []
# CanvasItems that have to be faded by hand.
var orphans: Array[CanvasItem] = []
# Recorded on the way out, not at startup, so anything that changes its own
# layers while active (a chaser that died, for example) comes back as it went away.
var layers := {}
var masks := {}
var was_active := true
var fade: Tween


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collect(self)
	World.palette_changed.connect(apply)
	apply(true)


func collect(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject2D:
			var body := child as CollisionObject2D
			bodies.append(body)
			layers[body] = body.collision_layer
			masks[body] = body.collision_mask
		elif child is TileMapLayer:
			tilemaps.append(child as TileMapLayer)
		# Fading only passes down through CanvasItems, so anything sitting
		# under a plain Node has to be handled on its own.
		if child is CanvasItem and not (node is CanvasItem):
			orphans.append(child as CanvasItem)
		collect(child)


func apply(instant := false) -> void:
	var active := World.swapped == (world == 1)

	# Physics switches at once; a platform mid-fade shouldn't still hold you.
	if active:
		for body in bodies:
			if is_instance_valid(body):
				body.set_deferred("collision_layer", layers.get(body, body.collision_layer))
				body.set_deferred("collision_mask", masks.get(body, body.collision_mask))
	elif was_active:
		for body in bodies:
			if is_instance_valid(body):
				layers[body] = body.collision_layer
				masks[body] = body.collision_mask
				body.set_deferred("collision_layer", 0)
				body.set_deferred("collision_mask", 0)
	was_active = active

	# One flag covers a tilemap's drawing and its collision together.
	for map in tilemaps:
		if is_instance_valid(map):
			map.enabled = active
	# Anything that moves must stop too, or it falls while "hidden".
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

	if fade:
		fade.kill()
	var alpha := 1.0 if active else 0.0
	if instant or fade_time <= 0.0:
		set_alpha(alpha)
		set_shown(active)
		return
	# Visible during the fade either way; hidden again once it finishes.
	set_shown(true)
	fade = create_tween().set_parallel()
	fade.tween_property(self, "modulate:a", alpha, fade_time)
	for item in orphans:
		if is_instance_valid(item):
			fade.tween_property(item, "modulate:a", alpha, fade_time)
	if not active:
		fade.chain().tween_callback(set_shown.bind(false))


func set_alpha(alpha: float) -> void:
	modulate.a = alpha
	for item in orphans:
		if is_instance_valid(item):
			item.modulate.a = alpha


func set_shown(shown: bool) -> void:
	visible = shown
	for item in orphans:
		if is_instance_valid(item):
			item.visible = shown
