extends Sprite2D

#  WINDOW SIZE

const WIN_W = 512
const WIN_H = 512

const WIN_ZERO = Vector2i(0, 0)
const WIN_SIZE = Vector2i(WIN_W, WIN_H)

#  DISPLAY PLAYER INFO

var display_data: Control
signal player_position_changed(pos)
signal player_move_change(move)

#  LOADED IMAGES

var grid: Image
var wall_texture: Texture2D
var enemy_textures: Texture2D

#  LOADED IMAGE CONSTANTS

const GRID_SCALE_UP = 32

const WALL_SPRITE_TILE_SIZE = 64
const WALL_SPRITE_WIDTH_BY_TILE = 6
const WALL_SPRITE_HEIGHT_BY_TILE = 1
const WALL_SPRITE_WIDTH = WALL_SPRITE_TILE_SIZE * WALL_SPRITE_WIDTH_BY_TILE
const WALL_SPRITE_HEIGHT = WALL_SPRITE_HEIGHT_BY_TILE * WALL_SPRITE_TILE_SIZE

const ENEMY_TEX_TILE_SIZE = 64
const ENEMY_TEX_TILE_WIDTH = 4
const ENEMY_TEX_TILE_HEIGHT = 1
const ENEMY_TEX_WIDTH = ENEMY_TEX_TILE_SIZE * ENEMY_TEX_TILE_WIDTH
const ENEMY_TEX_HEIGHT = ENEMY_TEX_TILE_SIZE * ENEMY_TEX_TILE_HEIGHT

#  DISPLAYED IMAGES

var gradient_texture: ImageTexture
var gradient_display: Sprite2D
# The main game is drawn directly on the canvas of the node.
# No need for a specific image.

#  DRAW INFORMATION

class DrawColumn:
	var src_tex: Texture2D
	var screen_rect: Rect2
	var src_rect: Rect2
	var dist: float

var screen_col_data: PackedVector2Array
var src_col_data: PackedVector2Array
var src_tile_data: Array
var screen_tilemap = [
	Color8(48, 96, 130),
	Color8(255, 255, 255),
	Color8(172, 50, 50),
	Color8(69, 40, 60),
	Color8(106, 190, 48),
	Color8(153, 229, 80),
]

var enemy_screen_col_data: Array
var enemy_src_col_data: Array
var enemy_sprite_data: Array

#  RENDERING CONSTANTS

# 400 steps to check for walls, each step is 1.6 pixels
const MAX_RENDER_STEPS = 400
const MAX_RENDER_DISTANCE = 640
const RENDER_STEP_SIZE = float(MAX_RENDER_DISTANCE) / MAX_RENDER_STEPS
const WALL_TO_SCREEN_RATIO = 32
const ENEMY_SCALE_UP = 32
const FOV = PI / 3

#  PLAYER CONSTANTS

const LOW_CAMERA_SPEED = 60 * PI / 180
const LOW_ACCELERATION = 5
const HIGH_CAMERA_SPEED = 3 * LOW_CAMERA_SPEED
const HIGH_ACCELERATION = 3 * LOW_ACCELERATION
const DEACCELERATION_FACTOR = 0.9

const PLAYER_START_POS = Vector2(3.456, 2.345) * GRID_SCALE_UP
const PLAYER_START_ANGLE = 90 * PI / 180

#  PLAYER STATE

class Player:
	var pos: Vector2
	var angle: float
	var move: Vector2
	
	var accel: float
	var turn_speed: float
	var is_sprinting: bool
	
	func _init(p, a):
		pos = p
		angle = a
		move = Vector2(0, 0)
		accel = HIGH_ACCELERATION
		turn_speed = HIGH_CAMERA_SPEED
		is_sprinting = true

var player = Player.new(PLAYER_START_POS, PLAYER_START_ANGLE)

#  ENEMY STATE

class Enemy:
	var pos: Vector2
	# offset of enemy texture in terms of tiles
	var tex_tile: int
	
	func _init(p, t):
		pos = p
		tex_tile = t

var enemy_list = [
	Enemy.new(Vector2(1.834, 8.765)  * GRID_SCALE_UP, 0),
	Enemy.new(Vector2(5.323, 5.365)  * GRID_SCALE_UP, 1),
	Enemy.new(Vector2(4.123, 10.265) * GRID_SCALE_UP, 1)
]

signal enemy_update(array)


func create_gradient_map():
	# This could all prolly be saved to a png or smth
	# and have this function removed, but whatevs
	
	var gradient = Image.create(WIN_W, WIN_H, false, Image.FORMAT_RGBA8)
	
	# Draw the gradient_map
	for y in WIN_H:
		for x in WIN_W:
			gradient.set_pixel(
				x, y,
				Color(float(y) / WIN_H, float(x) / WIN_W, 0)
			)
	
	# Draw the grid on top of the gradient texture
	# A lil goofy, but whatevs
	gradient.blit_rect_mask(
		grid,
		grid,
		Rect2(Vector2(0, 0),
		Vector2(WIN_W, WIN_H)), Vector2(0, 0)
	)
	
	gradient_texture = ImageTexture.create_from_image(gradient)


func _ready():
	
	grid = load("res://images/TinyRendererMapColor.png").get_image()
	assert(grid.get_size() * GRID_SCALE_UP == Vector2i(WIN_W, WIN_H))
	grid.resize(WIN_W, WIN_H, Image.INTERPOLATE_NEAREST)
	
	wall_texture = load("res://images/walltext.png")
	assert(wall_texture.get_height() == WALL_SPRITE_HEIGHT)
	assert(wall_texture.get_width() == WALL_SPRITE_WIDTH)
	
	enemy_textures = load("res://images/monsters.png")
	assert(enemy_textures.get_height() == ENEMY_TEX_HEIGHT)
	assert(enemy_textures.get_width() == ENEMY_TEX_WIDTH)
	
	create_gradient_map()
	gradient_display = $MapWindow
	gradient_display.set_position(Vector2(WIN_W, 0))
	gradient_display.set_texture(gradient_texture)
	
	display_data = $DisplayControl
	display_data.set_position(Vector2(0, WIN_H))
	
	screen_col_data = PackedVector2Array()
	screen_col_data.resize(WIN_W)
	screen_col_data.fill(Vector2i(0, 0))
	
	src_col_data = PackedVector2Array()
	src_col_data.resize(WIN_W)
	src_col_data.fill(Vector2i(0, WALL_SPRITE_TILE_SIZE))
	
	src_tile_data = []
	src_tile_data.resize(WIN_W)
	src_tile_data.fill(0)
	
	enemy_update.emit(enemy_list)
	
	# This is not what enemy_screen_col_data is intended for
	enemy_screen_col_data = PackedVector2Array()
	enemy_screen_col_data.resize(enemy_list.size() * 2)
	enemy_screen_col_data.fill(Vector2i(0, 0))
	
	enemy_src_col_data = PackedVector2Array()
	enemy_src_col_data.resize(WIN_W)
	enemy_src_col_data.fill(Vector2i(0, ENEMY_TEX_TILE_HEIGHT))


func _input(event):
	# Isn't it a lil' dumb that this doesn't process ALL input?
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	
	if event is InputEventKey:
		if event.is_released() and event.keycode == KEY_F:
			if player.is_sprinting:
				player.accel = LOW_ACCELERATION
				player.turn_speed = LOW_CAMERA_SPEED
			else:
				player.accel = HIGH_ACCELERATION
				player.turn_speed = HIGH_CAMERA_SPEED
			
			player.is_sprinting = not player.is_sprinting
		
		if event.is_released() and event.keycode == KEY_G:
			gradient_display.visible = not gradient_display.visible


func _process(delta):
	#  Handle Input
	var camera_left  = int(Input.is_physical_key_pressed(KEY_LEFT))
	var camera_right = int(Input.is_physical_key_pressed(KEY_RIGHT))
	
	# Keep player.angle between -PI and PI for enemy drawing logic
	player.angle += (camera_right - camera_left) * player.turn_speed * delta
	if player.angle > PI:
		player.angle -= 2 * PI
	if player.angle < -PI:
		player.angle += 2 * PI
	
	var right = int(Input.is_physical_key_pressed(KEY_D))
	var left  = int(Input.is_physical_key_pressed(KEY_A))
	var up    = int(Input.is_physical_key_pressed(KEY_W))
	var down  = int(Input.is_physical_key_pressed(KEY_S))
	
	player.move += Vector2((up - down), (right - left)) * player.accel * delta
	player.move *= DEACCELERATION_FACTOR
	
	player.pos += player.move.rotated(player.angle)
	
	# This seems kinda inconvenient but whatevs
	player_position_changed.emit(player.pos)
	player_move_change.emit(player.move)
	
	#  Generate frame information
	generate_frame()
	
	#  Generate enemy information
	generate_enemy_draw_data()
	
	#  Update screen
	queue_redraw()


func generate_frame():
	var gradient_frame = gradient_texture.get_image()
	var start_angle = player.angle - (FOV / 2)
	
	for x in WIN_W:
		var angle = start_angle + (FOV * x / WIN_W)
		generate_column_raycast(x, angle, gradient_frame)
	
	gradient_display.set_texture(ImageTexture.create_from_image(gradient_frame))


func generate_enemy_draw_data():
	for e in enemy_list.size():
		var enemy = enemy_list[e]
		var sprite_dist = enemy.pos - player.pos
		var sprite_dir = atan2(sprite_dist.y, sprite_dist.x)  # need rotation guard
		sprite_dist = sprite_dist.length()
		var sprite_size = WIN_H / sprite_dist * ENEMY_SCALE_UP
		
		var h_offset = (sprite_dir - player.angle) * WIN_W / FOV + (WIN_W - sprite_size) / 2.0
		var v_offset = (WIN_H - sprite_size) / 2.0
		var screen_offset = Vector2(h_offset, v_offset)
		
		enemy_screen_col_data[2 * e] = screen_offset
		enemy_screen_col_data[2 * e + 1] = Vector2(sprite_size, sprite_size)
		
		# sprite_dist = length between player(the camera) and enemy
		# sprite_dir = angle between player and enemy from origin
		# displayed_size = screen height / sprite_dist
		# displayed_center = *math noises*
		# displayed_offset = (center of screen) - (displayed_size / 2) + displayed_center


func _draw():
	draw_rect(Rect2(0, 0, WIN_W, WIN_H), Color.GRAY)
	
	for x in WIN_H:
		draw_texture_rect_region(
			wall_texture,
			Rect2(x, screen_col_data[x].x, 1, screen_col_data[x].y),
			Rect2(src_tile_data[x], src_col_data[x].x, 1, src_col_data[x].y)
		)
	
	for e in enemy_list.size():
		draw_texture_rect_region(
			enemy_textures,
			Rect2(enemy_screen_col_data[2*e], enemy_screen_col_data[2*e+1]),
			Rect2(enemy_list[e].tex_tile * ENEMY_TEX_TILE_SIZE, 0, ENEMY_TEX_TILE_SIZE, ENEMY_TEX_TILE_SIZE)
		)


func generate_column_raycast(x: int, a: float, g_frame: Image):
	var c_pos = player.pos
	var c_color
	var dist = MAX_RENDER_DISTANCE
	var step_vector = RENDER_STEP_SIZE * Vector2(cos(a), sin(a))
	
	for c in range(1, MAX_RENDER_STEPS):
		c_pos += step_vector
		c_pos = c_pos.clamp(Vector2(0, 0), Vector2(WIN_W-1, WIN_H-1))
		c_color = grid.get_pixelv(Vector2i(c_pos))
		
		g_frame.set_pixelv(Vector2i(c_pos), Color.WHITE)
		
		if c_color.a != 0:
			dist = c * RENDER_STEP_SIZE
			break
	
	var height = int(WIN_H * WALL_TO_SCREEN_RATIO / (dist * cos(a - player.angle)))
	var start = (WIN_H - height) / 2.0
	var line = Vector2(start, height).clamp(Vector2(0, 0), Vector2(WIN_H, WIN_H))
	
	screen_col_data[x] = line
	
	if height > WIN_H:
		var shrink = int((height - WIN_H) / 2.0 * WALL_SPRITE_TILE_SIZE / height)
		var src_h = WALL_SPRITE_TILE_SIZE - (shrink * 2)
		src_col_data[x] = Vector2(shrink, src_h)
	else:
		src_col_data[x] = Vector2(0, WALL_SPRITE_TILE_SIZE)
	
	var cheaty_scaled = c_pos / GRID_SCALE_UP
	cheaty_scaled = cheaty_scaled - (cheaty_scaled + Vector2(0.5, 0.5)).floor()
	var hit_column = cheaty_scaled.x
	if abs(cheaty_scaled.y) > abs(cheaty_scaled.x):
		hit_column = cheaty_scaled.y
	hit_column *= WALL_SPRITE_TILE_SIZE
	if hit_column < 0:
		hit_column += WALL_SPRITE_TILE_SIZE
	var texture_column = screen_tilemap.find(c_color) * WALL_SPRITE_TILE_SIZE + int(hit_column)
	
	src_tile_data[x] = clamp(texture_column, 0, WALL_SPRITE_WIDTH)
