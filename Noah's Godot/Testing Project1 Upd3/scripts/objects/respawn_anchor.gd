class_name RespawnAnchor
extends Area2D

# A checkpoint. Walking into it makes the player respawn here from then on.
# Only one anchor is active at a time.

# Shared by every anchor, so lighting a new one only has to dim the old one.
static var current: RespawnAnchor = null

# Where the player reappears, measured from this node.
@export var spawn_offset := Vector2.ZERO
# Optional animation names. Leave blank to just change opacity.
@export var active_animation := ""
@export var inactive_animation := ""

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# A static var outlives the scene, so it can point at a freed node.
	if current != null and not is_instance_valid(current):
		current = null
	refresh()


func _on_body_entered(body: Node2D) -> void:
	if current == self or not body.is_in_group("player"):
		return
	body.spawn_position = to_global(spawn_offset)
	var previous := current
	current = self
	if previous != null and is_instance_valid(previous):
		previous.refresh()
	refresh()


func refresh() -> void:
	if sprite == null:
		return
	var active := current == self
	var anim := active_animation if active else inactive_animation
	if anim and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
	sprite.modulate.a = 1.0 if active else 0.4
