extends Node2D

var image = load("res://skull-perspective.png")

@export var map_position = Vector2(0, 0)
@export var angle = 0.0

# Called when the node enters the scene tree for the first time.
func _init(pos: Vector2, a: float):
	map_position = pos
	angle = a


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
