extends Label


func _on_position_change(p: Vector2):
	self.text = "Position: " + str(p)
