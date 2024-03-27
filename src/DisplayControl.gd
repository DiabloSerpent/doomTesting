extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	var player_pos = $PlayerPos
	get_parent().player_position_changed.connect(player_pos._on_position_change)
	
	var player_move = $PlayerMove
	get_parent().player_move_change.connect(player_move._on_move_change)
