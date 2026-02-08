# maze_scene.gd - Fixed version
extends Node2D

signal maze_completed(area_id: int)

@onready var maze_player: CharacterBody2D = get_node("CharacterBody2D")  # Sesuaikan path
@onready var finish_area: Area2D = get_node("FinishArea")  # Sesuaikan path
@onready var camera: Camera2D = get_node("Camera2D")  # Optional

func _ready():
	print("🎮 Maze Scene Ready!")
	
	# Setup camera jika ada
	if camera:
		camera.make_current()
		print("✅ Camera activated")
	
	# Connect signals
	setup_signals()
	
	# Position player di start position (sesuaikan dengan map kamu)
	if maze_player:
		# Misal start di posisi tertentu
		maze_player.position = Vector2(100, 100)  # Ganti dengan koordinat start di map kamu
		print("✅ Player positioned at:", maze_player.position)
	
	# Position exit jika perlu (atau sudah diatur di editor)
	if finish_area:
		print("✅ Exit area ready at:", finish_area.position)
		# Debug: tampilkan area finish
		show_finish_area_debug()
	
	print("📍 Use arcade buttons 2/4/6/8 to move the character")
	print("🎯 Find the finish area to continue to FPS mode")

func setup_signals():
	# Connect Area2D signal
	if finish_area and maze_player:
		if not finish_area.body_entered.is_connected(_on_finish_area_entered):
			finish_area.body_entered.connect(_on_finish_area_entered)
			print("✅ FinishArea signal connected to maze scene")
	else:
		print("⚠️  FinishArea or MazePlayer not found!")
		
		# FIX: Gunakan string class name, bukan GDScript type
		if not finish_area:
			finish_area = find_node_by_class("Area2D")
			if finish_area:
				print("✅ Found FinishArea recursively:", finish_area.name)
		
		if not maze_player:
			maze_player = find_node_by_class("CharacterBody2D")
			if maze_player:
				print("✅ Found MazePlayer recursively:", maze_player.name)
				
				# Coba connect signal jika baru ditemukan
				if finish_area and not finish_area.body_entered.is_connected(_on_finish_area_entered):
					finish_area.body_entered.connect(_on_finish_area_entered)

# FIXED VERSION: Menerima string class name, bukan GDScript type
func find_node_by_class(className: String) -> Node:
	"""
	Cari node berdasarkan class name (string)
	Contoh: "Area2D", "CharacterBody2D", "Sprite2D"
	"""
	for child in get_children():
		if child.get_class() == className:
			return child
		# Search recursively
		var found = _find_node_recursive_by_class(child, className)
		if found:
			return found
	return null

func _find_node_recursive_by_class(parent: Node, className: String) -> Node:
	for child in parent.get_children():
		if child.get_class() == className:
			return child
		var found = _find_node_recursive_by_class(child, className)
		if found:
			return found
	return null

func _on_finish_area_entered(body: Node2D):
	print("🎯 FinishArea: Body entered - ", body.name)
	
	# Cek jika yang masuk adalah player
	if body == maze_player or body.name == "MazePlayer" or body.is_in_group("maze_player"):
		print("🎉 MAZE COMPLETED! Player reached finish area!")
		
		# Area ID (1 = hallway, 2 = back door, etc)
		var area_id = 1  # Default
		
		# Cek jika area punya metadata untuk ID
		if finish_area.has_meta("area_id"):
			area_id = finish_area.get_meta("area_id")
		
		# Visual feedback
		if maze_player.has_method("celebrate_victory"):
			maze_player.celebrate_victory()
		
		# Tunggu sebentar untuk efek visual
		await get_tree().create_timer(1.5).timeout
		
		# Emit signal ke game manager
		print("🚀 Emitting maze_completed signal with area_id:", area_id)
		maze_completed.emit(area_id)

func show_finish_area_debug():
	# Visual debug untuk finish area
	var debug_sprite = Sprite2D.new()
	var debug_texture = create_debug_texture()
	debug_sprite.texture = debug_texture
	debug_sprite.position = finish_area.position
	debug_sprite.modulate = Color(0, 1, 0, 0.3)  # Hijau transparan
	debug_sprite.z_index = 10  # Pastikan di atas layer lain
	add_child(debug_sprite)
	print("🔍 Debug: Green circle shows finish area location")

func create_debug_texture():
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Gambar circle
	var center = Vector2(32, 32)
	var radius = 30
	
	for y in range(64):
		for x in range(64):
			var pos = Vector2(x, y)
			if pos.distance_to(center) <= radius:
				image.set_pixel(x, y, Color(0, 1, 0, 0.5))
	
	return ImageTexture.create_from_image(image)

# ALTERNATIVE: Function yang lebih reliable untuk mencari node
func find_node_with_signal(signal_name: String) -> Node:
	"""
	Cari node yang memiliki signal tertentu
	"""
	for child in get_children():
		if child.has_signal(signal_name):
			return child
		var found = _find_node_with_signal_recursive(child, signal_name)
		if found:
			return found
	return null

func _find_node_with_signal_recursive(parent: Node, signal_name: String) -> Node:
	for child in parent.get_children():
		if child.has_signal(signal_name):
			return child
		var found = _find_node_with_signal_recursive(child, signal_name)
		if found:
			return found
	return null

# Debug function
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				print("🔧 DEBUG: Force maze completion")
				if maze_player:
					_on_finish_area_entered(maze_player)
			KEY_F2:
				print("🔧 DEBUG: Print scene info")
				print("Player at:", maze_player.position if maze_player else "N/A")
				print("Finish area at:", finish_area.position if finish_area else "N/A")
				print("Player in group 'maze_player':", maze_player.is_in_group("maze_player") if maze_player else "N/A")
			KEY_F3:
				print("🔧 DEBUG: Print all Area2D nodes")
				var areas = find_all_nodes_by_class("Area2D")
				for area in areas:
					print("  -", area.name, " at ", area.position)
			KEY_F4:
				print("🔧 DEBUG: Print all CharacterBody2D nodes")
				var bodies = find_all_nodes_by_class("CharacterBody2D")
				for body in bodies:
					print("  -", body.name, " at ", body.position)

func find_all_nodes_by_class(className: String) -> Array:
	var result = []
	_find_all_nodes_by_class_recursive(self, className, result)
	return result

func _find_all_nodes_by_class_recursive(node: Node, className: String, result: Array):
	if node.get_class() == className:
		result.append(node)
	
	for child in node.get_children():
		_find_all_nodes_by_class_recursive(child, className, result)
