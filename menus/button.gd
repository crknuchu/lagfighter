extends Button


func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://level/level.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().change_scene_to_file("res://level/level.tscn")
