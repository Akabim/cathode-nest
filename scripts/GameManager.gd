extends Node3D

# --- 1. CORE COMPONENTS ---
@export_group("Core Components")
@export var main_camera: Camera3D
@export var button_parent: Node3D
@export var screen_mesh: MeshInstance3D
@export var arcade_viewport: SubViewport
@export var sfx_steps: AudioStreamPlayer3D
@export var player_ref: CharacterBody3D

@export_group("Horror Environment")
@export var room_light: Light3D 
@export var world_env: WorldEnvironment 

# --- 2. IBU & ENEMY ---
@export_group("Ibu Components")
@export var ibu_ghost: Node3D 
@export var ibu_animator: AnimationPlayer 

@export_group("Ibu Settings")
@export var ibu_speed: float = 1.5      
@export var peek_duration: float = 3.0  
@export var pos_ibu_start: Vector3 = Vector3(-10.0, 0.0, 0.0) 
@export var rot_ibu_walking: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var pos_ibu_peek: Vector3 = Vector3(-4.0, 0.0, 0.0)
@export var rot_ibu_peeking: Vector3 = Vector3(0.0, 0.0, 0.0)  
@export var rot_ibu_retreat: Vector3 = Vector3(0.0, -90.0, 0.0)

# --- 3. CINEMATICS & MARKERS ---
@export_group("Cinematic Markers")
@export var pos_coin_cam: Marker3D   
@export var pos_screen_cam: Marker3D 
@export var coin_area: Area3D
@export_group("Sleep System")
@export var pos_sleep_cam: Marker3D  
@export var head_pos_sleep: Vector3 = Vector3(2.98, 1.97, -1.20) 
@export var rot_sleep: Vector3 = Vector3(-44.0, 133.0, 0.0) 

# --- 4. LEVELS & UI ---
@export_group("Level Database")
@export var levels_list: Array[LevelData]

@export_group("Maze & Dialog Settings")
@export var maze_ui_scene: PackedScene
@export var dialog_layer: CanvasLayer
@export var dialog_label: Label
# Dialogs
@export_multiline var maze_start_dialog: String = "Huh? What game is this? I don't remember owning this..."
@export_multiline var dialog_arcade_done: String = "Sigh... Why is Mom always like this when I play?" 
@export_multiline var dialog_lights_out: String = "And now the lights are out. Perfect." 
@export_multiline var dialog_tekad_keluar: String = "I have to get out of this house."
@export_multiline var dialog_memanggil_ibu: String = "Mom? Are you there?"

@export_group("Ending Settings")
@export var cutscene_ui: Control
@export var cutscene_rect: TextureRect
@export var ending_photos: Array[Texture2D]

# --- STATE VARIABLES ---
enum GameState { MENU, ARCADE, TRANSITION, FPS_ROAM }
var current_state = GameState.MENU

# Arcade Vars
var current_level_res: LevelData
var is_level_active = false
var levels_completed_count = 0
var available_level_indices: Array[int] = [] 
var sequence_index = 0
var spam_counter = 0
var wait_timer = 0.0
var current_hold_timer = 0.0
var is_holding_button = false
var held_button_node: Node3D = null
var current_swipe_distance = 0.0

# Camera Vars
var camera_state = 1 
var camera_angles = [90.0, 0.0, -45.0] # Variabel penting untuk noleh
var head_pos_sit = Vector3() 
var rot_sit_base = Vector3()

# Sleep Vars
var is_sleeping = false
var can_input = false
var sleep_timer: float = 0.0 # Variabel penting untuk tidur
var max_sleep_time: float = 10.0 

# Maze Vars (Legacy/Unused but kept for safety)
var is_maze_unlocked = false
var maze_dialog_triggered = false
var maze_instance: Node = null

# Ibu Vars
# DITAMBAHKAN STATE CHASE
enum IbuState { IDLE, APPROACHING, PEEKING, RETREATING, JUMPSCARE, CHASE }
var ibu_state = IbuState.IDLE
var peek_timer = 0.0 
var is_jumpscare_active = false
var jumpscare_timer = 0.0
var original_screen_texture: Texture2D

# Puzzle Vars
var inventory = []
var is_water_running = false 
var is_dialog_running = false

# ==============================================================================
# 1. SETUP & STATE MANAGEMENT
# ==============================================================================
func _ready():
	add_to_group("game_manager")
	
	if coin_area and not coin_area.coin_inserted.is_connected(_on_coin_inserted):
		coin_area.coin_inserted.connect(_on_coin_inserted)
	
	if screen_mesh:
		var mat = screen_mesh.get_active_material(0)
		if mat: original_screen_texture = mat.albedo_texture

	if cutscene_ui: cutscene_ui.hide()
	
	# Start di Menu
	change_state(GameState.MENU)

func change_state(new_state):
	current_state = new_state
	print("🔄 State Changed to: ", new_state)
	
	match new_state:
		GameState.MENU:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if player_ref: 
				player_ref.set_mode(true) # Kunci Player
				# Blokir kamera biar gak noleh pas geser koin di menu
				if player_ref.has_method("set_view_blocked"):
					player_ref.set_view_blocked(true)
			reset_game_logic()
			
		GameState.ARCADE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if player_ref: 
				player_ref.set_mode(true) # Kunci Player
				# Izinkan kamera noleh lagi buat main arcade
				if player_ref.has_method("set_view_blocked"):
					player_ref.set_view_blocked(false)
			start_arcade_gameplay()
			
		GameState.TRANSITION:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
			if player_ref: player_ref.set_mode(true) 
			
		GameState.FPS_ROAM:
			# INI MOMEN MASUK HORROR UTAMA
			if player_ref: player_ref.set_mode(false) # Buka Kunci Player
			await get_tree().process_frame 
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Hilangkan Mouse
			setup_ibu_stealth_mode()

# ==============================================================================
# 2. LOGIC LOOP
# ==============================================================================
func _process(delta):
	if is_jumpscare_active:
		jumpscare_timer += delta
		if jumpscare_timer >= 1.5: end_jumpscare()
		return

	# Logic Arcade
	if current_state == GameState.ARCADE:
		process_ibu_movement(delta)
		process_level_timers(delta)
	
	# Logic Ibu Chase (FPS Mode)
	if current_state == GameState.FPS_ROAM and ibu_state == IbuState.CHASE:
		process_ibu_movement(delta)
	
	# Logic Tidur
	if is_sleeping:
		sleep_timer += delta
		if sleep_timer >= 10.0: wake_up_and_return()

func process_level_timers(delta):
	if is_level_active and current_level_res:
		if current_level_res.type == LevelData.LevelType.WAIT:
			wait_timer += delta
			if wait_timer >= current_level_res.wait_duration: win_level()
		elif current_level_res.type == LevelData.LevelType.HOLD and is_holding_button:
			current_hold_timer += delta
			if held_button_node: held_button_node.position.x += randf_range(-0.0005, 0.0005)
			if current_hold_timer >= current_level_res.hold_duration:
				stop_holding(); win_level()

func _input(event):
	if current_state == GameState.MENU:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			handle_coin_input(event.position)
			
	elif current_state == GameState.ARCADE:
		if is_sleeping:
			if event is InputEventMouseButton and event.pressed: wake_up_and_return()
			return
			
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: handle_click(event.position)
			elif not event.pressed: stop_holding()
		
		# Swipe Logic
		if event is InputEventMouseMotion and is_level_active and current_level_res.type == LevelData.LevelType.SWIPE:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				current_swipe_distance += event.relative.x
				if screen_mesh: screen_mesh.position.x = randf_range(-0.002, 0.002)
				if current_swipe_distance >= current_level_res.swipe_amount:
					if screen_mesh: screen_mesh.position = Vector3.ZERO
					win_level_alt_image()

# ==============================================================================
# 3. TRANSISI ARCADE SELESAI -> HORROR (NO MAZE)
# ==============================================================================
func start_horror_sequence():
	print("🎬 Arcade Selesai. Memulai Horror Sequence...")
	
	# 1. Masuk State Transisi
	change_state(GameState.TRANSITION)
	
	# Matikan Layar Arcade (Black Screen)
	if screen_mesh:
		var mat = screen_mesh.get_active_material(0)
		if mat: mat.albedo_color = Color.BLACK
	
	# 2. Dialog Keluhan ("Why is Mom always like this...")
	await show_player_dialog_async(dialog_arcade_done)
	
	# 3. Lampu Mati (SFX & Visual)
	trigger_lampu_mati()
	await show_player_dialog_async(dialog_lights_out)
	
	# 4. Tekad & Panggil Ibu
	await show_player_dialog_async(dialog_memanggil_ibu)
	await show_player_dialog_async(dialog_tekad_keluar)
	
	# 5. Masuk State FPS (Bebas Roaming)
	change_state(GameState.FPS_ROAM)

func trigger_lampu_mati():
	print("🔦 LIGHTS OUT!")
	if room_light: room_light.visible = false 
	if world_env:
		world_env.environment.adjustment_enabled = true
		world_env.environment.adjustment_brightness = 0.5

# ==============================================================================
# 4. RESET & ARCADE LOGIC
# ==============================================================================
func reset_game_logic():
	is_level_active = false
	levels_completed_count = 0
	inventory.clear()
	is_water_running = false
	
	if main_camera and pos_coin_cam:
		main_camera.global_position = pos_coin_cam.global_position
		main_camera.global_rotation = pos_coin_cam.global_rotation
	if coin_area: 
		coin_area.visible = true; coin_area.scale = Vector3.ONE 
	if room_light: room_light.visible = true 
	
	if screen_mesh:
		var m = screen_mesh.get_active_material(0)
		if m: m.albedo_color = Color.WHITE; m.emission = Color.BLACK; if original_screen_texture: m.albedo_texture = original_screen_texture
	var i = get_ui_node("LevelImage")
	if i: i.texture = null; i.visible = true

func start_arcade_gameplay():
	if pos_screen_cam:
		head_pos_sit = pos_screen_cam.global_position
	
	# Refill Levels
	available_level_indices.clear()
	for i in range(levels_list.size()): available_level_indices.append(i)
	if available_level_indices.has(0): available_level_indices.erase(0)
	
	load_level_from_list(0)
	
	# Reset Ibu AI (Patroli Arcade)
	ibu_state = IbuState.IDLE
	ibu_ghost.visible = false
	ibu_ghost.global_position = pos_ibu_start
	
	# MULAI PATROLI
	start_ibu_arcade_patrol()

# ==============================================================================
# 5. BUTTON LOGIC (TANPA MAZE)
# ==============================================================================
func handle_click(mouse_pos):
	var w = get_viewport().get_visible_rect().size.x
	if camera_state == 1:
		if mouse_pos.x > w * 0.8: change_camera_view(2) 
		elif mouse_pos.x < w * 0.2: change_camera_view(0) 
		else: raycast_check(mouse_pos)
	else:
		change_camera_view(1)

func raycast_check(mouse_pos):
	var space = get_world_3d().direct_space_state
	var from = main_camera.project_ray_origin(mouse_pos)
	var to = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var res = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	
	if res:
		var col = res.collider
		var obj = col.get_parent()
		var full_name = (obj.name + col.name).to_lower()
		
		if "bed" in full_name or "kasur" in full_name: go_to_sleep(); return
		
		var regex = RegEx.new()
		regex.compile("\\d+") 
		var result = null
		if obj: result = regex.search(obj.name) 
		if not result: result = regex.search(col.name) 
		
		if result: process_button_logic(int(result.get_string()), obj)

func process_button_logic(num, node):
	# Kalau level aktif
	if is_level_active and current_level_res:
		if current_level_res.type == LevelData.LevelType.HOLD:
			if num in current_level_res.correct_buttons: start_holding(node)
			else: animate_button(node); lose_level()
		else:
			animate_button(node)
			check_level_logic(num)

# ==============================================================================
# 6. WIN/LOSE LOGIC
# ==============================================================================
func win_level():
	is_level_active = false
	levels_completed_count += 1
	await get_tree().create_timer(0.5).timeout
	
	# --- CEK APAKAH SUDAH 5 LEVEL ---
	if levels_completed_count >= 5:
		start_horror_sequence() # LANGSUNG MASUK HORROR (NO MAZE)
	else:
		# Load Next Level
		if available_level_indices.is_empty():
			for i in range(1, levels_list.size()): available_level_indices.append(i)
		
		if available_level_indices.is_empty(): load_level_from_list(0)
		else:
			var idx = randi() % available_level_indices.size()
			var lvl_idx = available_level_indices[idx]
			available_level_indices.remove_at(idx)
			load_level_from_list(lvl_idx)

func win_level_alt_image():
	if current_level_res.level_image_alt:
		update_screen_image(current_level_res.level_image_alt)
		is_level_active = false
		await get_tree().create_timer(1.0).timeout
	win_level()

func check_level_logic(num):
	if not is_level_active: return
	var correct = false
	match current_level_res.type:
		LevelData.LevelType.STANDARD:
			if num in current_level_res.correct_buttons: correct = true
		LevelData.LevelType.SEQUENCE:
			if num == current_level_res.sequence_order[sequence_index]:
				sequence_index += 1
				if sequence_index >= current_level_res.sequence_order.size(): correct = true
			else: sequence_index = 0
		LevelData.LevelType.SPAM:
			if num in current_level_res.correct_buttons:
				spam_counter += 1
				if spam_counter >= current_level_res.spam_amount: correct = true

	if correct: win_level_alt_image()
	elif current_level_res.type == LevelData.LevelType.STANDARD: lose_level()

func lose_level():
	if ibu_state == IbuState.APPROACHING: enter_peeking_phase()

# ==============================================================================
# 7. HELPERS & UTILS
# ==============================================================================
func handle_coin_input(mouse_pos):
	var space = get_world_3d().direct_space_state
	var from = main_camera.project_ray_origin(mouse_pos)
	var to = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var res = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if res:
		var col = res.collider
		if col == coin_area or "coin" in col.name.to_lower():
			trigger_coin_animation(col); return
		var parent = col.get_parent()
		if parent and (parent == coin_area or "coin" in parent.name.to_lower()):
			trigger_coin_animation(parent)

func trigger_coin_animation(coin_node):
	if coin_area.has_method("trigger_insertion"): coin_area.trigger_insertion()
	elif coin_node.has_method("play_insert_animation"): coin_node.play_insert_animation()
	else: _on_coin_inserted()

func _on_coin_inserted():
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(main_camera, "global_position", pos_screen_cam.global_position, 2.5)
	tw.tween_property(main_camera, "global_rotation_degrees", pos_screen_cam.global_rotation_degrees, 2.5)
	tw.chain().tween_callback(func(): change_state(GameState.ARCADE))

func show_player_dialog_async(content):
	if is_dialog_running: return
	if dialog_layer and dialog_label:
		is_dialog_running = true
		dialog_label.text = content
		var box = dialog_layer.get_child(0)
		if box:
			box.modulate.a = 0.0; dialog_layer.show()
			var t = create_tween(); t.tween_property(box, "modulate:a", 1.0, 0.3)
			await get_tree().create_timer(4.0).timeout
			var t2 = create_tween(); t2.tween_property(box, "modulate:a", 0.0, 0.3)
			await t2.finished
		dialog_layer.hide()
		is_dialog_running = false

func add_to_inventory(item_name):
	if not inventory.has(item_name):
		inventory.append(item_name)
		show_player_dialog_async("Picked up " + item_name)

func has_item(item_name): return inventory.has(item_name)

func get_ui_node(n):
	if not arcade_viewport or arcade_viewport.get_child_count() == 0: return null
	return arcade_viewport.get_child(0).find_child(n, true, false)
func update_screen_image(t):
	var i = get_ui_node("LevelImage"); if i: i.texture = t
func setup_screen_texture():
	if arcade_viewport: arcade_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if screen_mesh and arcade_viewport:
		await get_tree().process_frame
		var mat = screen_mesh.get_active_material(0)
		if mat: mat.albedo_texture = arcade_viewport.get_texture()
func load_level_from_list(idx):
	if levels_list.is_empty() or levels_list[idx] == null: return
	current_level_res = levels_list[idx]
	sequence_index = 0; spam_counter = 0; wait_timer = 0.0; current_swipe_distance = 0.0
	is_level_active = true
	update_screen_image(current_level_res.level_image)
	var lbl = get_ui_node("LabelPrompt"); if lbl: lbl.text = current_level_res.prompt_text

func animate_button(b):
	var t = create_tween()
	t.tween_property(b, "position:y", b.position.y - 0.01, 0.05)
	t.tween_property(b, "position:y", b.position.y, 0.05)
func stop_holding(): is_holding_button = false; held_button_node = null
func start_holding(b): is_holding_button = true; held_button_node = b; current_hold_timer = 0.0
func change_camera_view(s): camera_state = s; update_camera_transform()
func play_ibu_anim(n): if ibu_animator: ibu_animator.play(n)
func go_to_sleep(): is_sleeping = true; update_camera_transform()
func wake_up_and_return(): is_sleeping = false; camera_state = 1; update_camera_transform()
func update_camera_transform():
	# Kita pake Tween biar gerakannya mulus
	var tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if is_sleeping:
		# Posisi Tidur
		if pos_sleep_cam:
			tw.tween_property(main_camera, "global_position", pos_sleep_cam.global_position, 0.5)
			tw.tween_property(main_camera, "global_rotation", pos_sleep_cam.global_rotation, 0.5)
	else:
		# Posisi Duduk (Arcade)
		# 1. Gerakin Posisi
		tw.tween_property(main_camera, "global_position", head_pos_sit, 0.5)
		
		# 2. Gerakin Rotasi (Fix Noleh)
		var base_rot_y = pos_screen_cam.global_rotation_degrees.y
		var target_rot_y = base_rot_y + camera_angles[camera_state]
		
		tw.tween_property(main_camera, "global_rotation_degrees:y", target_rot_y, 0.5)
		tw.tween_property(main_camera, "global_rotation_degrees:x", pos_screen_cam.global_rotation_degrees.x, 0.5)
		tw.tween_property(main_camera, "global_rotation_degrees:z", 0.0, 0.5)

# ==============================================================================
# 8. IBU AI (STEALTH MODE & ARCADE PATROL) - IMPROVED
# ==============================================================================

# Loop Patroli Arcade (Sering muncul)
func start_ibu_arcade_patrol():
	while current_state == GameState.ARCADE:
		# Tunggu Random 5 - 12 detik
		var wait_time = randf_range(5.0, 12.0)
		await get_tree().create_timer(wait_time).timeout
		
		# Cek lagi apakah masih mode Arcade & Ibu sedang Idle
		if current_state == GameState.ARCADE and ibu_state == IbuState.IDLE:
			ibu_state = IbuState.APPROACHING
			ibu_ghost.visible = true
			ibu_ghost.global_position = pos_ibu_start 
			
			# Tunggu sampai Ibu selesai cycle ini sebelum loop lagi
			while ibu_state != IbuState.IDLE and current_state == GameState.ARCADE:
				await get_tree().process_frame

func setup_ibu_stealth_mode():
	# Matikan AI Arcade dulu
	ibu_state = IbuState.IDLE
	ibu_ghost.visible = false
	
	print("👻 Ibu Despawn (Menunggu 10 detik sebelum Chase...)")
	# TUNGGU 10 DETIK SEBELUM MUNCUL (Bisa ubah ke 60.0 nanti)
	await get_tree().create_timer(10.0).timeout 
	
	if current_state == GameState.FPS_ROAM:
		print("😱 IBU MUNCUL & MENGEJAR!")
		show_player_dialog_async("Run!! She's coming!!")
		
		ibu_ghost.global_position = pos_ibu_start 
		ibu_ghost.visible = true
		ibu_state = IbuState.CHASE

func process_ibu_movement(delta):
	match ibu_state:
		# --- MODE ARCADE (PATROL) ---
		IbuState.APPROACHING:
			var target = pos_ibu_peek
			var dir = (target - ibu_ghost.global_position).normalized()
			ibu_ghost.global_position += dir * ibu_speed * delta
			ibu_ghost.rotation_degrees = Vector3(0, 90, 0)
			play_ibu_anim("walking")
			if not sfx_steps.playing: sfx_steps.play()
			if ibu_ghost.global_position.distance_to(target) < 0.1: enter_peeking_phase()

		IbuState.PEEKING:
			if sfx_steps.playing: sfx_steps.stop()
			ibu_ghost.rotation_degrees = Vector3.ZERO 
			play_ibu_anim("peeking")
			peek_timer += delta
			if peek_timer > peek_duration: game_over("Ibu caught you!")

		IbuState.RETREATING:
			var target = pos_ibu_start
			var dir = (target - ibu_ghost.global_position).normalized()
			ibu_ghost.global_position += dir * (ibu_speed * 1.5) * delta
			ibu_ghost.rotation_degrees = Vector3(0, -90, 0)
			play_ibu_anim("walking")
			if not sfx_steps.playing: sfx_steps.play()
			
			# Kalau player bangun pas Ibu masih dekat -> Mati
			if not is_sleeping and ibu_ghost.global_position.distance_to(pos_ibu_peek) < 2.0:
				game_over("You woke up too soon!")
				
			if ibu_ghost.global_position.distance_to(target) < 0.5:
				ibu_state = IbuState.IDLE; ibu_ghost.visible = false; sfx_steps.stop()

		# --- MODE FPS (CHASE) ---
		IbuState.CHASE:
			if player_ref:
				var target = player_ref.global_position
				var dir = (target - ibu_ghost.global_position).normalized()
				var chase_speed = 2.5 
				
				ibu_ghost.global_position += dir * chase_speed * delta
				ibu_ghost.look_at(Vector3(target.x, ibu_ghost.global_position.y, target.z))
				play_ibu_anim("walking")
				if not sfx_steps.playing: sfx_steps.play()
				
				if ibu_ghost.global_position.distance_to(target) < 1.0:
					game_over("Caught by Ibu in Chase Mode")

func enter_peeking_phase(): ibu_state = IbuState.PEEKING; peek_timer = 0.0
func game_over(reason): trigger_wajah_jumpscare()
func trigger_wajah_jumpscare(): change_state(GameState.MENU) 
func end_jumpscare(): is_jumpscare_active = false; change_state(GameState.MENU)
