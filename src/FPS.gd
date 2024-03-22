extends Label


var time_count = 0.0
var frame_count = 0
var fps = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	time_count += delta
	frame_count += 1
	
	if time_count > 1:
		fps = frame_count
		frame_count = 0
		time_count = 0
	
	text = "FPS: " + str(fps)
