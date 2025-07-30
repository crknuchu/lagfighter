extends Node2D

func _ready():
	$Player1.opponent = $Player2
	$Player2.opponent = $Player1
	
	$Player1.set_health_ui($HeartUI_P1/HeartUI)
	$Player2.set_health_ui($HeartUI_P2/HeartUI)
