extends Sprite2D

# This variable can be revived
#const MAX_RENDER_DISTANCE = 400
const WIN_W = 512
const WIN_H = 512

var display_data: Control
signal player_position_changed(Vector2)
signal player_move_change(Vector2)

var gradient: Image
var grid: Image
var screen: Image
var wall_texture

var screen_texture: ImageTexture
var gradient_texture: ImageTexture

var gradient_display: Sprite2D

# These could be replaced with PackedRectArrays
var screen_data: PackedVector2Array
var src_data: PackedVector2Array
#var screen_colors: PackedColorArray
var screen_tile_info: Array

var screen_tilemap: Array

const FOV = PI/3
const LOW_CAMERA_SPEED = 60*PI/180
const LOW_ACCELERATION = 5
const HIGH_CAMERA_SPEED = 3*LOW_CAMERA_SPEED
const HIGH_ACCELERATION = 3*LOW_ACCELERATION
const DEACCELERATION_FACTOR = 0.9

var player_pos: Vector2
var player_angle: float
var player_move: Vector2
var ACCELERATION = LOW_ACCELERATION
var CAMERA_SPEED = LOW_CAMERA_SPEED

func create_gradient_map():
	# This could all prolly be saved to a png or smth and have this function removed, but whatevs

	gradient = Image.create(WIN_W, WIN_H, false, Image.FORMAT_RGBA8)
	
	# Draw the gradient_map
	for y in WIN_H:
		for x in WIN_W:
			gradient.set_pixel(x, y, Color(float(y)/WIN_H, float(x)/WIN_W, 0))
	
	# Draw the grid on top of the gradient texture
	# A lil goofy, but whatevs
	gradient.blit_rect_mask(grid, grid, Rect2(Vector2(0, 0), Vector2(WIN_W, WIN_H)), Vector2(0, 0))
	
	gradient_texture = ImageTexture.create_from_image(gradient)

func generate_column_raycast(x: int, a: float, g_frame: Image):
	var c_pos
	var c_color
	var dist = 400*1.6
	for c in range(1, 400): # 400 steps to check for walls, each step is 1.6 pixels
		c_pos = (player_pos + c*1.6*Vector2(cos(a), sin(a))).clamp(Vector2i(0, 0), Vector2i(WIN_W, WIN_H))
		c_color = grid.get_pixelv(Vector2i(c_pos))
		#print(c_color)
		#g_frame.set_pixelv(Vector2i(c_pos), Color.WHITE)
		if c_color.a != 0:
			dist = c*1.6
			break
	
#	var column_data = PackedByteArray()
#	column_data.resize(WIN_H*4)
	var height = int(WIN_H * 32 / (dist*cos(a - player_angle)))
	var start = (WIN_H - height) / 2.0
	var line = Vector2(start, height).clamp(Vector2(0, 0), Vector2(WIN_H, WIN_H))
	
	screen_data[x] = line
	
	
	if height > WIN_H:
		var shrink = int((height - WIN_H) * 64.0 / height / 2) # 64.0 and 2 are kept apart for clarity
		var src_h = 64 - shrink*2
		
		src_data[x] = Vector2(shrink, src_h)
		#print(src_data[x])
	else:
		src_data[x] = Vector2(0, 64)
	
	
	
#	if c_color != Color(0, 0, 0, 0):
#		#print(c_color)
#		for y in range(WIN_H):
#			var pixel = c_color if y in range(start, start+height) else Color.TRANSPARENT
#			column_data[y*4+0] = pixel.r8
#			column_data[y*4+1] = pixel.g8
#			column_data[y*4+2] = pixel.b8
#			column_data[y*4+3] = pixel.a8
	
	
	var cheaty_scaled = c_pos / 32.0
	cheaty_scaled = cheaty_scaled - (cheaty_scaled+Vector2(0.5, 0.5)).floor()
	var hit_column = cheaty_scaled.x if abs(cheaty_scaled.x) > abs(cheaty_scaled.y) else cheaty_scaled.y
	hit_column *= 64
	hit_column = hit_column if hit_column > 0 else hit_column + 64
	var texture_column = screen_tilemap.find(c_color) * 64 + int(hit_column)
	
	screen_tile_info[x] = clamp(texture_column, 0, 384)
	
#	screen_colors[x] = c_color
	
#	var column = Image.create_from_data(1, WIN_H, false, Image.FORMAT_RGBA8, column_data)
#	screen.blit_rect(column, Rect2(0, 0, 1, WIN_H), Vector2(x, 0))

# Should this be consolidated under a draw function?
func generate_frame():
	var gradient_frame = gradient_texture.get_image()
	var start_angle = player_angle - (FOV / 2)
	
	for x in WIN_W:
		var angle = start_angle + (FOV * x / WIN_W)
		generate_column_raycast(x, angle, gradient_frame)
	
	gradient_display.set_texture(ImageTexture.create_from_image(gradient_frame))
	

# Called when the node enters the scene tree for the first time.
func _ready():
#	self.set_position(Vector2(WIN_W/2.0, WIN_H/2.0))
	screen = Image.create(WIN_W, WIN_H, false, Image.FORMAT_RGBA8)
	#screen.fill(Color8(255, 255, 255))
	
	screen_tilemap = [
		Color8(48, 96, 130),
		Color8(255, 255, 255),
		Color8(172, 50, 50),
		Color8(69, 40, 60),
		Color8(106, 190, 48),
		Color8(153, 229, 80),
	]
	
	grid = load("res://images/TinyRendererMapColor.png").get_image()
	# RGBA8
	#print("Format: ", grid.get_format())
#	var ggg = grid.get_data()
#	for x in 16:
#		for y in 16:
#			var c = grid.get_pixel(x, y)
#			# This is bullshit
#			if c.a != 0 and c not in screen_tilemap:
#				print(ggg[(y*16+x)*4+0], " ",  ggg[(y*16+x)*4+1], " ", ggg[(y*16+x)*4+2], " ", ggg[(y*16+x)*4+3])
	grid.resize(WIN_H, WIN_H, Image.INTERPOLATE_NEAREST)
	
	wall_texture = load("res://images/walltext.png")
	
	create_gradient_map()
	gradient_display = $MapWindow
	gradient_display.set_position(Vector2(WIN_W, 0))
	gradient_display.set_texture(gradient_texture)
	
	player_pos = Vector2(3.456*32, 2.345*32)
	player_angle = 90 * PI / 180
	
	display_data = $DisplayControl
	display_data.set_position(Vector2(0, WIN_H))
	
	screen_data = PackedVector2Array()
	screen_data.resize(WIN_W)
	screen_data.fill(Vector2i(0, 0))
	
	src_data = PackedVector2Array()
	src_data.resize(WIN_W)
	src_data.fill(Vector2i(0, 64))
	
#	screen_colors = PackedColorArray()
#	screen_colors.resize(WIN_W)
#	screen_colors.fill(Color.WHITE)
	
	screen_tile_info = []
	screen_tile_info.resize(WIN_W)
	screen_tile_info.fill(0)
	
#	var f = FileAccess.open("data.txt", FileAccess.WRITE)
#	print(str(gradient.get_data()[player_pos.y*4*WIN_H+player_pos.x*4+0]))
#	print(str(gradient.get_data()[player_pos.y*4*WIN_H+player_pos.x*4+1]))
#	print(str(gradient.get_data()[player_pos.y*4*WIN_H+player_pos.x*4+2]))
#	print(str(gradient.get_data()[player_pos.y*4*WIN_H+player_pos.x*4+3]))

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	if event is InputEventKey:
		if event.is_released() and event.keycode == KEY_F:
			# Kinda cringe, don't sue me
			ACCELERATION = LOW_ACCELERATION if ACCELERATION == HIGH_ACCELERATION else HIGH_ACCELERATION
			CAMERA_SPEED = LOW_CAMERA_SPEED if ACCELERATION == HIGH_CAMERA_SPEED else HIGH_CAMERA_SPEED
		if event.is_released() and event.keycode == KEY_G:
			gradient_display.visible = not gradient_display.visible


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var camera_left = CAMERA_SPEED if Input.is_physical_key_pressed(KEY_LEFT) else 0.0
	var camera_right = CAMERA_SPEED if Input.is_physical_key_pressed(KEY_RIGHT) else 0.0
	
	player_angle += (camera_right - camera_left) * delta
	
	# Handle Input
	var right = ACCELERATION if Input.is_physical_key_pressed(KEY_D) else 0
	var left = ACCELERATION if Input.is_physical_key_pressed(KEY_A) else 0
	var up = ACCELERATION if Input.is_physical_key_pressed(KEY_W) else 0
	var down = ACCELERATION if Input.is_physical_key_pressed(KEY_S) else 0
	
	player_move += Vector2(left-right, up-down) * delta
	player_move *= DEACCELERATION_FACTOR
	
	player_pos += player_move.rotated(player_angle-PI/2)

	# This seems kinda inconvenient but whatevs
	player_position_changed.emit(player_pos)
	player_move_change.emit(player_move)
	
	# Generate frame information
	generate_frame()
	
	# Update screen
#	screen_texture = ImageTexture.create_from_image(screen)
#	self.set_texture(screen_texture)
	queue_redraw()

func _draw():
#	var nppos = player_pos+Vector2(100, 0)
#	draw_circle(nppos, 10, Color.AQUA)
#	draw_line(nppos, nppos+(player_move*10), Color.BLUE)
#	draw_line(nppos, nppos+(player_move.rotated(player_angle-PI/2)*10), Color.RED)
	draw_rect(Rect2(0, 0, WIN_W, WIN_H), Color.GRAY)
#	for x in WIN_W:
#		draw_line(Vector2(x, screen_data[x].x), Vector2(x, screen_data[x].x+screen_data[x].y), Color.WHITE)

#	draw_multiline_colors(screen_data, screen_colors)

#	draw_texture_rect_region(wall_texture, Rect2(100, 100, 128, 128), Rect2(64, 0, 64, 64))
	for x in WIN_H:
		draw_texture_rect_region(
			wall_texture,
			Rect2(x, screen_data[x].x, 1, screen_data[x].y),
			Rect2(screen_tile_info[x], src_data[x].x, 1, src_data[x].y)
		)
	
	if gradient_display.visible:
		draw_circle(gradient_display.position + player_pos, 5, Color.AQUA)
