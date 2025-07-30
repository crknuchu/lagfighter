extends HBoxContainer

@export var max_hearts: int = 3
@export var current_hearts: int = 5

func _ready() -> void:
	update_hearts()

func set_health(value: int) -> void:
	current_hearts = clamp(value, 0, max_hearts)
	update_hearts()

func update_hearts() -> void:
	for i in range(max_hearts):
		var heart = get_child(i) as TextureRect
		heart.visible = i < current_hearts
