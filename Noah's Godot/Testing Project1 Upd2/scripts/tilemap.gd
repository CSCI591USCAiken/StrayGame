@tool
extends TileMapLayer

# This code helps the tilemap change color.

const WorldScript := preload("res://scripts/world.gd")


func _ready() -> void:
	if Engine.is_editor_hint():
		modulate = WorldScript.DARK
		return
	World.palette_changed.connect(update_color)
	update_color()


func update_color() -> void:
	modulate = World.solid_color()
