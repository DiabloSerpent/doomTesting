extends Sprite2D

var drawn_player_pos = Vector2(0, 0)
var drawn_enemy_pos_list: Array

# Called when the node enters the scene tree for the first time.
func _ready():
	self.centered = false
	get_parent().player_position_changed.connect(_on_position_change)

func _on_position_change(p: Vector2):
	drawn_player_pos = p

# Apparently you don't need to call queue_redraw() every frame
func _draw():
	draw_circle(drawn_player_pos, 5, Color.AQUA)
	
	for e in drawn_enemy_pos_list:
		draw_circle(e.pos, 6, Color.RED)


func _on_game_window_enemy_update(array):
	drawn_enemy_pos_list = array
