extends Sprite2D

var drawn_player_pos = Vector2(0, 0)

# Called when the node enters the scene tree for the first time.
func _ready():
	self.centered = false
	get_parent().player_position_changed.connect(_on_position_change)

func _on_position_change(p: Vector2):
	drawn_player_pos = p

# Apparently you don't need to call queue_redraw() every frame
func _draw():
	draw_circle(drawn_player_pos, 3, Color.AQUA)
