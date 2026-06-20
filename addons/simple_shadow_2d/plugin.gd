@tool
extends EditorPlugin


func _enter_tree() -> void:
	var icon := load("res://brand/icon.svg") as Texture2D
	if not icon:
		icon = load("icon.svg") as Texture2D
	add_custom_type("Shadow2D", "Node2D", preload("shadow_2d.gd"), icon)



func _exit_tree() -> void:
	remove_custom_type("Shadow2D")
