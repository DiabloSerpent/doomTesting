extends Sprite2D

const WIN_W = 512
const WIN_H = 512

# This ought to be bundled more closely with the source image
const WALL_SPRITE_TILE_SIZE = 64
const WALL_SPRITE_WIDTH_BY_TILE = 6
const WALL_SPRITE_HEIGHT_BY_TILE = 1
const WALL_SPRITE_WIDTH = WALL_SPRITE_TILE_SIZE * WALL_SPRITE_WIDTH_BY_TILE
const WALL_SPRITE_HEIGHT = WALL_SPRITE_HEIGHT_BY_TILE * WALL_SPRITE_TILE_SIZE

var display_data: Control
signal player_position_changed(Vector2)
signal player_move_change(Vector2)

var gradient: Image
var grid: Image
var wall_texture

var screen_texture: ImageTexture
var gradient_texture: ImageTexture

var gradient_display: Sprite2D
# The main game is drawn directly canvas of the sprite

# These could be replaced with PackedRectArrays
var screen_data: PackedVector2Array
var src_data: PackedVector2Array
var screen_tile_info: Array

var screen_tilemap: Array

# 400 steps to check for walls, each step is 1.6 pixels
const MAX_RENDER_STEPS = 400
const MAX_RENDER_DISTANCE = 640
const RENDER_STEP_SIZE = float(MAX_RENDER_DISTANCE) / MAX_RENDER_STEPS
const WALL_TO_SCREEN_RATIO = 32

const FOV = PI / 3
const LOW_CAMERA_SPEED = 60 * PI / 180
const LOW_ACCELERATION = 5
const HIGH_CAMERA_SPEED = 3 * LOW_CAMERA_SPEED
const HIGH_ACCELERATION = 3 * LOW_ACCELERATION
const DEACCELERATION_FACTOR = 0.9

const PLAYER_START_POS = Vector2(3.456 * 32, 2.345 * 32)
const PLAYER_START_ANGLE = 90 * PI / 180

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
			gradient.set_pixel(x, y, Color(float(y) / WIN_H, float(x) / WIN_W, 0))
	
	# Draw the grid on top of the gradient texture
	# A lil goofy, but whatevs
	gradient.blit_rect_mask(grid, grid, Rect2(Vector2(0, 0), Vector2(WIN_W, WIN_H)), Vector2(0, 0))
	
	gradient_texture = ImageTexture.create_from_image(gradient)


# Called when the node enters the scene tree for the first time.
func _ready():
	screen_tilemap = [
		Color8(48, 96, 130),
		Color8(255, 255, 255),
		Color8(172, 50, 50),
		Color8(69, 40, 60),
		Color8(106, 190, 48),
		Color8(153, 229, 80),
	]
	
	grid = load("res://images/TinyRendererMapColor.png").get_image()
	grid.resize(WIN_H, WIN_H, Image.INTERPOLATE_NEAREST)
	
	wall_texture = load("res://images/walltext.png")
	assert(wall_texture.get_height() == WALL_SPRITE_HEIGHT)
	assert(wall_texture.get_width() == WALL_SPRITE_WIDTH)
	
	create_gradient_map()
	gradient_display = $MapWindow
	gradient_display.set_position(Vector2(WIN_W, 0))
	gradient_display.set_texture(gradient_texture)
	
	player_pos = PLAYER_START_POS
	player_angle = PLAYER_START_ANGLE
	
	display_data = $DisplayControl
	display_data.set_position(Vector2(0, WIN_H))
	
	screen_data = PackedVector2Array()
	screen_data.resize(WIN_W)
	screen_data.fill(Vector2i(0, 0))
	
	src_data = PackedVector2Array()
	src_data.resize(WIN_W)
	src_data.fill(Vector2i(0, WALL_SPRITE_TILE_SIZE))
	
	screen_tile_info = []
	screen_tile_info.resize(WIN_W)
	screen_tile_info.fill(0)


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
	
	player_move += Vector2((left - right), (up - down)) * delta
	player_move *= DEACCELERATION_FACTOR
	
	player_pos += player_move.rotated(player_angle - (PI / 2))
	
	# This seems kinda inconvenient but whatevs
	player_position_changed.emit(player_pos)
	player_move_change.emit(player_move)
	
	# Generate frame information
	generate_frame()
	
	# Update screen
	queue_redraw()


func _draw():
	draw_rect(Rect2(0, 0, WIN_W, WIN_H), Color.GRAY)
	
	for x in WIN_H:
		draw_texture_rect_region(
			wall_texture,
			Rect2(x, screen_data[x].x, 1, screen_data[x].y),
			Rect2(screen_tile_info[x], src_data[x].x, 1, src_data[x].y)
		)


func generate_frame():
	var gradient_frame = gradient_texture.get_image()
	var start_angle = player_angle - (FOV / 2)
	
	for x in WIN_W:
		var angle = start_angle + (FOV * x / WIN_W)
		generate_column_raycast(x, angle, gradient_frame)
	
	gradient_display.set_texture(ImageTexture.create_from_image(gradient_frame))


func generate_column_raycast(x: int, a: float, g_frame: Image):
	var c_pos = player_pos
	var c_color
	var dist = MAX_RENDER_DISTANCE
	var step_vector = RENDER_STEP_SIZE * Vector2(cos(a), sin(a))
	
	for c in range(1, MAX_RENDER_STEPS):
		c_pos += step_vector
		c_pos.clamp(Vector2i(0, 0), Vector2i(WIN_W, WIN_H))
		c_color = grid.get_pixelv(Vector2i(c_pos).clamp(Vector2(0, 0), Vector2(WIN_W-1, WIN_H-1)))
		
		g_frame.set_pixelv(Vector2i(c_pos).clamp(Vector2(0, 0), Vector2(WIN_W-1, WIN_H-1)), Color.WHITE)
		
		if c_color.a != 0:
			dist = c * RENDER_STEP_SIZE
			break
	
	var height = int(WIN_H * WALL_TO_SCREEN_RATIO / (dist * cos(a - player_angle)))
	var start = (WIN_H - height) / 2.0
	var line = Vector2(start, height).clamp(Vector2(0, 0), Vector2(WIN_H, WIN_H))
	
	screen_data[x] = line
	
	if height > WIN_H:
		var shrink = int((height - WIN_H) / 2.0 * WALL_SPRITE_TILE_SIZE / height)
		var src_h = WALL_SPRITE_TILE_SIZE - (shrink * 2)
		src_data[x] = Vector2(shrink, src_h)
	else:
		src_data[x] = Vector2(0, WALL_SPRITE_TILE_SIZE)
	
	var cheaty_scaled = c_pos / WALL_TO_SCREEN_RATIO
	cheaty_scaled = cheaty_scaled - (cheaty_scaled+Vector2(0.5, 0.5)).floor()
	var hit_column = cheaty_scaled.x
	if abs(cheaty_scaled.y) > abs(cheaty_scaled.x):
		hit_column = cheaty_scaled.y
	hit_column *= WALL_SPRITE_TILE_SIZE
	if hit_column < 0:
		hit_column += WALL_SPRITE_TILE_SIZE
	var texture_column = screen_tilemap.find(c_color) * WALL_SPRITE_TILE_SIZE + int(hit_column)
	
	screen_tile_info[x] = clamp(texture_column, 0, WALL_SPRITE_WIDTH)
