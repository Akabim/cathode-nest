# maze_character.gd - Fixed version
extends CharacterBody2D

class_name MazePlayer

signal maze_completed(area_id: int)

@export var speed := 150.0
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D  # Pastikan ini AnimatedSprite2D

var move_direction := Vector2.ZERO
var last_button := -1
var has_reached_exit := false
var can_move := true
var is_moving := false

func _ready():
	add_to_group("maze_player")
	print("✅ Maze Player Ready - Added to 'maze_player' group")
	
	# Setup sprite frames jika belum ada
	setup_sprite_frames()
	
	# Setup collision
	setup_collision()
	
	# Ensure we're not moving at start
	move_direction = Vector2.ZERO
	velocity = Vector2.ZERO
	
	print("🎮 Controls ready: Buttons 2=Down, 4=Left, 6=Right, 8=Up")

func setup_sprite_frames():
	if not sprite:
		print("⚠️  No AnimatedSprite2D found!")
		return
	
	# Cek jika sudah punya SpriteFrames
	if not sprite.sprite_frames:
		print("🔧 Creating default SpriteFrames...")
		create_default_frames()
	
	# Pastikan ada animasi "idle" dan "walk"
	ensure_animations()

func create_default_frames():
	var frames = SpriteFrames.new()
	
	# Buat texture untuk idle (kotak biru)
	var idle_texture = create_color_texture(Color(0, 0.8, 1), 32, 32)
	frames.add_animation("idle")
	frames.add_frame("idle", idle_texture)
	
	# Buat texture untuk walk (kotak biru lebih gelap)
	var walk_texture1 = create_color_texture(Color(0, 0.7, 0.9), 32, 32)
	var walk_texture2 = create_color_texture(Color(0, 0.6, 0.8), 32, 32)
	frames.add_animation("walk")
	frames.add_frame("walk", walk_texture1)
	frames.add_frame("walk", walk_texture2)
	
	sprite.sprite_frames = frames
	print("✅ Created default SpriteFrames")

func create_color_texture(color: Color, width: int, height: int) -> Texture2D:
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func ensure_animations():
	if not sprite.sprite_frames:
		return
	
	# Cek jika animasi "idle" ada
	if not sprite.sprite_frames.has_animation("idle"):
		print("🔧 Adding 'idle' animation...")
		var idle_texture = create_color_texture(Color(0, 0.8, 1), 32, 32)
		sprite.sprite_frames.add_animation("idle")
		sprite.sprite_frames.add_frame("idle", idle_texture)
	
	# Cek jika animasi "walk" ada
	if not sprite.sprite_frames.has_animation("walk"):
		print("🔧 Adding 'walk' animation...")
		var walk_texture1 = create_color_texture(Color(0, 0.7, 0.9), 32, 32)
		var walk_texture2 = create_color_texture(Color(0, 0.6, 0.8), 32, 32)
		sprite.sprite_frames.add_animation("walk")
		sprite.sprite_frames.add_frame("walk", walk_texture1)
		sprite.sprite_frames.add_frame("walk", walk_texture2)
	
	# Set animation speed
	sprite.sprite_frames.set_animation_speed("walk", 5.0)

func setup_collision():
	# Pastikan punya collision shape
	if not has_node("CollisionShape2D"):
		print("🔧 Adding CollisionShape2D...")
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 15
		collision.shape = shape
		add_child(collision)
		collision.name = "CollisionShape2D"
		print("✅ Added CollisionShape2D")

func _physics_process(delta):
	if not can_move or has_reached_exit or not is_moving:
		return
	
	# Apply movement
	velocity = move_direction * speed * delta
	
	# Move and handle collisions
	var collision = move_and_collide(velocity)
	
	if collision:
		# Jika nabrak, berhenti dan mundur sedikit
		velocity = Vector2.ZERO
		move_direction = Vector2.ZERO
		is_moving = false
		print("💥 Collision detected")
		# Mundur sedikit dari collision
		position -= move_direction * 5
	
	update_anim(move_direction)

func move_player(num: int):
	if not can_move or has_reached_exit:
		print("⏸️  Can't move: disabled or at exit")
		return
	
	print("🕹️ Input received: Button", num)
	
	# Toggle: jika tekan tombol sama, berhenti
	if num == last_button:
		stop_movement()
		return
	
	last_button = num
	is_moving = true
	
	# Mapping tombol ke arah
	match num:
		2: move_direction = Vector2(0, 1)    # Down
		8: move_direction = Vector2(0, -1)   # Up
		4: move_direction = Vector2(-1, 0)   # Left
		6: move_direction = Vector2(1, 0)    # Right
		1: move_direction = Vector2(-0.7, 0.7)   # Down-Left
		3: move_direction = Vector2(0.7, 0.7)    # Down-Right
		7: move_direction = Vector2(-0.7, -0.7)  # Up-Left
		9: move_direction = Vector2(0.7, -0.7)   # Up-Right
		5: 
			stop_movement()
			print("⏸️  Stopped (button 5)")
			return
		_:
			print("⚠️  Unknown button:", num)
			stop_movement()
			return
	
	print("📍 Moving direction:", move_direction)

func stop_movement():
	move_direction = Vector2.ZERO
	last_button = -1
	is_moving = false
	update_anim(Vector2.ZERO)

func update_anim(dir: Vector2):
	if not sprite or not sprite.sprite_frames:
		return
	
	if dir.length() == 0:
		# Play idle animation jika ada
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
		return
	
	# Play walk animation jika ada
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	
	# Flip sprite berdasarkan arah horizontal
	if dir.x != 0:
		sprite.flip_h = dir.x < 0

func _on_area_finish_entered(area_id: int):
	if has_reached_exit:
		return
	
	print("🏁 FINISH AREA REACHED! Area ID:", area_id)
	has_reached_exit = true
	can_move = false
	stop_movement()
	
	# Visual celebration
	celebrate_victory()
	
	# Tunggu untuk efek visual
	await get_tree().create_timer(1.0).timeout
	
	# Emit signal
	print("🚀 Emitting maze_completed signal")
	maze_completed.emit(area_id)

func celebrate_victory():
	print("🎉 VICTORY!")
	
	# Change color to green
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0, 1, 0), 0.5)
		
		# Pulse effect
		tween.parallel().tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.3)
		
		# Change to victory animation jika ada
		if sprite.sprite_frames.has_animation("victory"):
			sprite.play("victory")

func print_debug_info():
	print("=== MAZE PLAYER DEBUG ===")
	print("Position:", position)
	print("Can move:", can_move)
	print("Has reached exit:", has_reached_exit)
	print("Is moving:", is_moving)
	print("Move direction:", move_direction)
	print("Last button:", last_button)
	
	if sprite:
		print("Sprite:", sprite.name)
		if sprite.sprite_frames:
			print("Animations:", sprite.sprite_frames.get_animation_names())
		print("Current animation:", sprite.animation)
