extends Label


func _on_move_change(v: Vector2):
	text = "Movement: " + str(v)
