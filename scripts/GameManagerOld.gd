extends Node3D

# ==========================================
# --- 1. REFERENSI NODE (ASSIGN DI INSPECTOR) ---
# ==========================================
@export_group("Core Components")
@export var main_camera: Camera3D
@export var button_parent: Node3D
@export var screen_mesh: MeshInstance3D
@export var arcade_viewport: SubViewport
@export var sfx_steps: AudioStreamPlayer3D

@export_group("Ibu Components")
@export var ibu_ghost: Node3D 
@export var ibu_animator: AnimationPlayer 

@export_group("Cinematic Markers")
@export var pos_coin_cam: Marker3D   
@export var pos_screen_cam: Marker3D 
@export var coin_area: Area3D

@export_group("Level Database")
@export var levels_list: Array[LevelData]

# ==========================================
# --- 2. SETTING IBU (MANUAL COORDINATES) ---
# ==========================================
@export_group("Ibu Settings")
@export var ibu_speed: float = 1.5      
@export var peek_duration: float = 3.0  

@export_subgroup("Coordinates & Rotation")
# Isi koordinat ini sesuai posisi di Editor!
@export var pos_ibu_start: Vector3 = Vector3(-10.0, 0.0, 0.0) 
@export var rot_ibu_walking: Vector3 = Vector3(0.0, 90.0, 0.0) # Hadap Pintu

@export var pos_ibu_peek: Vector3 = Vector3(-4.0, 0.0, 0.0)
@export var rot_ibu_peeking: Vector3 = Vector3(0.0, 0.0, 0.0)  # Hadap Player

@export var rot_ibu_retreat: Vector3 = Vector3(0.0, -90.0, 0.0) # Hadap Belakang

# ==========================================
# --- 3. VARIABEL LOGIC ---
# ==========================================
# Level & Game State
var current_level_res: LevelData
var sequence_index = 0
var spam_counter = 0
var wait_timer = 0.0
var is_level_active = false
var is_game_started = false
var available_level_indices: Array[int] = [] 

# Input Logic (Hold & Swipe)
var current_hold_timer: float = 0.0
var is_holding_button: bool = false
var held_button_node: Node3D = null
var current_swipe_distance: float = 0.0

# Camera State
var camera_state = 1 # 0:Kiri, 1:Tengah, 2:Kanan
var camera_angles = [90.0, 0.0, -45.0]
var head_pos_sit = Vector3() 
var rot_sit_base = Vector3()

@export_group("Sleep Coordinates")
@export var head_pos_sleep: Vector3 = Vector3(2.98, 1.97, -1.20) 
@export var rot_sleep: Vector3 = Vector3(-44.0, 133.0, 0.0) 
var is_sleeping = false
var can_input = false

# Ibu State Machine
enum IbuState { IDLE, APPROACHING, PEEKING, RETREATING, JUMPSCARE }
var ibu_state = IbuState.IDLE
var peek_timer = 0.0 

# ==========================================
# --- 4. SETUP & READY ---
# ==========================================
func _ready():
	# 1. Safety Scale
	if pos_coin_cam: pos_coin_cam.scale = Vector3.ONE
	if pos_screen_cam: pos_screen_cam.scale = Vector3.ONE
	if main_camera: main_camera.scale = Vector3.ONE
	
	# 2. Setup Posisi Awal
	if main_camera and pos_coin_cam:
		main_camera.global_position = pos_coin_cam.global_position
		main_camera.global_rotation = pos_coin_cam.global_rotation
	
	# 3. Setup Sinyal Koin
	if coin_area:
		if not coin_area.coin_inserted.is_connected(_on_coin_inserted):
			coin_area.coin_inserted.connect(_on_coin_inserted)
	
	# 4. FIX BLACK SCREEN VIEWPORT
	setup_screen_texture()
	
	# 5. Reset Ibu
	sfx_steps.stop()
	ibu_ghost.visible = false
	is_game_started = false
	can_input = false
	play_ibu_anim("idle")

# ==========================================
# --- 5. GAME LOOP (PROCESS) ---
# ==========================================
func _process(delta):
	if not is_game_started: return
	
	# Jalanin AI Ibu
	process_ibu_movement(delta)

	if is_sleeping: 
		# Kalau tidur pas lagi nahan tombol, batalin hold-nya
		if is_holding_button: stop_holding()
		return

	# --- LOGIC LEVEL ---
	if is_level_active and current_level_res:
		
		# Tipe WAIT
		if current_level_res.type == LevelData.LevelType.WAIT:
			wait_timer += delta
			if wait_timer >= current_level_res.wait_duration:
				win_level()
		
		# Tipe HOLD (Level 4)
		elif current_level_res.type == LevelData.LevelType.HOLD:
			if is_holding_button:
				current_hold_timer += delta
				# Efek getar tombol visual
				if held_button_node:
					held_button_node.position.x += randf_range(-0.0005, 0.0005)
				
				if current_hold_timer >= current_level_res.hold_duration:
					stop_holding()
					win_level()

# ==========================================
# --- 6. INPUT SYSTEM (KLIK, HOLD, SWIPE) ---
# ==========================================
func _input(event):
	if not is_game_started or not can_input: return
	
	# --- A. KLIK MOUSE (Pressed & Released) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			handle_click(event.position)
		elif not event.pressed:
			# Deteksi Lepas Klik (Untuk Level HOLD)
			if is_holding_button:
				print("Tombol Dilepas! Gagal.")
				stop_holding()
	
	# --- B. GERAK MOUSE (Untuk Level SWIPE) ---
	elif event is InputEventMouseMotion and is_level_active:
		if current_level_res.type == LevelData.LevelType.SWIPE:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				# Cek gerakan horizontal
				var drag_speed = event.relative.x
				if drag_speed > 0: # Cuma hitung kalau geser ke kanan (PUSH)
					current_swipe_distance += drag_speed
					
					# Visual Shake Layar
					if screen_mesh:
						screen_mesh.position.x = randf_range(-0.002, 0.002)
					
					if current_swipe_distance >= current_level_res.swipe_amount:
						if screen_mesh: screen_mesh.position = Vector3.ZERO
						win_level_alt_image() # Menang dengan ganti gambar dulu

func handle_click(mouse_pos):
	var w = get_viewport().get_visible_rect().size.x
	var zone_left = w * 0.2
	var zone_right = w * 0.8
	
	if is_sleeping:
		wake_up_and_return()
		return

	# Logic Navigasi Kamera
	if camera_state == 1: # Tengah
		if mouse_pos.x > zone_right: change_camera_view(2) 
		elif mouse_pos.x < zone_left: change_camera_view(0) 
		else: raycast_check(mouse_pos) # Tengah = Interaksi
		
	elif camera_state == 2: # Kanan
		if mouse_pos.x > zone_right: change_camera_view(1) 
		elif mouse_pos.x < zone_left: change_camera_view(1) 
		else: raycast_check(mouse_pos) # Tengah = Interaksi Kasur
		
	elif camera_state == 0: # Kiri
		if mouse_pos.x > zone_right or mouse_pos.x < zone_left: change_camera_view(1)

func raycast_check(mouse_pos):
	var space = get_world_3d().direct_space_state
	var from = main_camera.project_ray_origin(mouse_pos)
	var to = from + main_camera.project_ray_normal(mouse_pos) * 1000.0
	var res = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	
	if res:
		var col = res.collider
		var obj = col.get_parent()
		var full_name_check = (obj.name + col.name).to_lower()
		
		# 1. Cek Kasur
		if "bed" in full_name_check or "kasur" in full_name_check:
			go_to_sleep()
			return
			
		# 2. Cek Tombol Angka (Regex)
		var regex = RegEx.new()
		regex.compile("\\d+") 
		var result = regex.search(obj.name)
		
		if result:
			var num = int(result.get_string())
			print("Tombol Ditekan: ", num)
			
			# Logic Khusus HOLD Level
			if current_level_res.type == LevelData.LevelType.HOLD:
				if num in current_level_res.correct_buttons:
					start_holding(obj)
				else:
					animate_button(obj)
					lose_level()
			else:
				# Logic Standard
				animate_button(obj)
				check_level_logic(num)

# ==========================================
# --- 7. LOGIC IBU (MANUAL COORDINATES) ---
# ==========================================
func process_ibu_movement(delta):
	match ibu_state:
		IbuState.APPROACHING:
			var target = pos_ibu_peek
			var current = ibu_ghost.global_position
			var direction = (target - current).normalized()
			
			ibu_ghost.global_position += direction * ibu_speed * delta
			ibu_ghost.rotation_degrees = rot_ibu_walking # Manual Rot
			
			play_ibu_anim("walking")
			if not sfx_steps.playing: sfx_steps.play()
			
			if current.distance_to(target) < 0.1:
				enter_peeking_phase()

		IbuState.PEEKING:
			if sfx_steps.playing: sfx_steps.stop()
			ibu_ghost.global_position = pos_ibu_peek
			ibu_ghost.rotation_degrees = rot_ibu_peeking # Manual Rot
			
			play_ibu_anim("peeking")
			
			if is_sleeping:
				enter_retreat_phase()
				return
			
			peek_timer += delta
			if peek_timer > peek_duration:
				game_over("Ibu melihatmu tidak tidur!")

		IbuState.RETREATING:
			var target = pos_ibu_start
			var current = ibu_ghost.global_position
			var direction = (target - current).normalized()
			
			ibu_ghost.global_position += direction * (ibu_speed * 1.5) * delta
			ibu_ghost.rotation_degrees = rot_ibu_retreat # Manual Rot
			
			play_ibu_anim("walking")
			if not sfx_steps.playing: sfx_steps.play()
			
			if not is_sleeping and current.distance_to(pos_ibu_peek) < 2.0:
				game_over("Kamu bangun terlalu cepat!")
				
			if current.distance_to(target) < 0.5:
				reset_ibu_cycle()

# ==========================================
# --- 8. LEVEL CHECKER & WIN/LOSE ---
# ==========================================
func check_level_logic(num):
	if not is_level_active or not current_level_res: return
	var type = current_level_res.type
	
	if type == LevelData.LevelType.STANDARD:
		if num in current_level_res.correct_buttons:
			win_level_alt_image() # Cek gambar kedua dulu
		else:
			lose_level()
			
	elif type == LevelData.LevelType.SEQUENCE:
		var target_seq = current_level_res.sequence_order
		if sequence_index < target_seq.size():
			if num == target_seq[sequence_index]:
				sequence_index += 1
				if sequence_index >= target_seq.size(): win_level()
			else: sequence_index = 0
			
	elif type == LevelData.LevelType.WAIT: lose_level()
	
	elif type == LevelData.LevelType.SPAM:
		if num in current_level_res.correct_buttons:
			spam_counter += 1
			if spam_counter >= current_level_res.spam_amount: win_level()

func win_level_alt_image():
	# Helper khusus buat nampilin gambar kedua (Ular Belok / Loading 100%)
	if current_level_res.level_image_alt:
		update_screen_image(current_level_res.level_image_alt)
		can_input = false
		await get_tree().create_timer(1.0).timeout
		can_input = true
	win_level()

func win_level():
	print("LEVEL MENANG!")
	is_level_active = false
	if is_holding_button: stop_holding()
	
	await get_tree().create_timer(1.0).timeout
	
	# Load Next Level
	if available_level_indices.is_empty():
		for i in range(levels_list.size()):
			if i != 0: available_level_indices.append(i)
	var random_pick_index = randi() % available_level_indices.size()
	var next_level_idx = available_level_indices[random_pick_index]
	available_level_indices.remove_at(random_pick_index)
	load_level_from_list(next_level_idx)

func lose_level():
	print("SALAH!")
	if ibu_state == IbuState.APPROACHING:
		enter_peeking_phase() # Hukuman

func load_level_from_list(idx):
	if levels_list.is_empty(): return
	current_level_res = levels_list[idx]
	print("LOAD LEVEL: ", current_level_res.prompt_text)
	
	# Reset
	sequence_index = 0
	spam_counter = 0
	wait_timer = 0.0
	current_swipe_distance = 0.0
	is_level_active = true
	
	# Load Gambar Utama (Dengan Safety Check)
	if current_level_res.level_image:
		update_screen_image(current_level_res.level_image)
	else:
		# Bersihkan layar kalo gak ada gambar (pake null atau tekstur kosong)
		update_screen_image(null)
	
	# Update Text Prompt (Dengan Safety Check)
	var lbl = get_ui_node("LabelPrompt")
	if lbl:
		lbl.text = current_level_res.prompt_text
	else:
		print("WARNING: LabelPrompt tidak ditemukan di Scene UI!")

# ==========================================
# --- 9. HELPERS (VISUAL FIX & UTILS) ---
# ==========================================

# FUNGSI PINTAR: Cari node UI dimanapun dia berada (dalam container dll)
func get_ui_node(node_name: String) -> Node:
	if not arcade_viewport or arcade_viewport.get_child_count() == 0:
		return null
	var ui_root = arcade_viewport.get_child(0)
	return ui_root.find_child(node_name, true, false)

func update_screen_image(tex: Texture2D):
	# Update Gambar dengan pencarian node yang aman
	var img_node = get_ui_node("LevelImage")
	if img_node:
		img_node.texture = tex
	else:
		print("WARNING: LevelImage tidak ditemukan di Scene UI!")

func setup_screen_texture():
	# FIX BLACK SCREEN: Pastikan viewport selalu update
	if arcade_viewport:
		arcade_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Paksa material mesh ambil tekstur dari viewport
	if screen_mesh and arcade_viewport:
		await get_tree().process_frame # Tunggu viewport siap
		var mat = screen_mesh.get_active_material(0)
		if mat:
			mat.albedo_texture = arcade_viewport.get_texture()
			# Opsi tambahan biar gak gelap
			# mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 

func start_holding(btn_obj):
	if is_holding_button: return
	is_holding_button = true
	held_button_node = btn_obj
	current_hold_timer = 0.0
	var t = create_tween()
	t.tween_property(btn_obj, "position:y", btn_obj.position.y - 0.01, 0.05)

func stop_holding():
	if not is_holding_button: return
	is_holding_button = false
	current_hold_timer = 0.0
	if held_button_node:
		var t = create_tween()
		t.tween_property(held_button_node, "position:y", held_button_node.position.y + 0.01, 0.05)
	held_button_node = null

func animate_button(btn):
	var t = create_tween()
	t.tween_property(btn, "position:y", btn.position.y - 0.01, 0.05)
	t.tween_property(btn, "position:y", btn.position.y, 0.05)

# Camera Logic
func change_camera_view(new_state):
	camera_state = new_state
	update_camera_transform()

func go_to_sleep():
	if is_sleeping: return
	is_sleeping = true
	update_camera_transform()

func wake_up_and_return():
	is_sleeping = false
	change_camera_view(1)

func update_camera_transform():
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	var target_pos = Vector3()
	var target_rot = Vector3()
	if is_sleeping:
		target_pos = head_pos_sleep
		target_rot = rot_sleep
	else:
		target_pos = head_pos_sit
		var y_offset = camera_angles[camera_state]
		target_rot = Vector3(rot_sit_base.x, rot_sit_base.y + y_offset, rot_sit_base.z)
	tween.tween_property(main_camera, "global_position", target_pos, 0.5)
	tween.tween_property(main_camera, "global_rotation_degrees", target_rot, 0.5)

# Ibu Helpers
func reset_ibu_cycle():
	ibu_state = IbuState.IDLE
	ibu_ghost.visible = false
	sfx_steps.stop()
	ibu_ghost.global_position = pos_ibu_start
	play_ibu_anim("idle")
	await get_tree().create_timer(randf_range(5.0, 10.0)).timeout
	if can_input and is_game_started:
		ibu_state = IbuState.APPROACHING
		ibu_ghost.visible = true

func enter_peeking_phase():
	ibu_state = IbuState.PEEKING
	peek_timer = 0.0
	ibu_ghost.global_position = pos_ibu_peek
	ibu_ghost.rotation_degrees = rot_ibu_peeking

func enter_retreat_phase():
	ibu_state = IbuState.RETREATING

func game_over(reason):
	print("GAME OVER: ", reason)
	can_input = false
	sfx_steps.stop()
	ibu_state = IbuState.JUMPSCARE
	ibu_ghost.visible = true
	play_ibu_anim("peeking")
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(ibu_ghost, "global_position", main_camera.global_position, 0.2)

func play_ibu_anim(anim_name):
	if ibu_animator:
		if ibu_animator.current_animation != anim_name:
			ibu_animator.play(anim_name, 0.2)

# Start Game Logic
func _on_coin_inserted():
	main_camera.scale = Vector3.ONE
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(main_camera, "global_position", pos_screen_cam.global_position, 2.5)
	tween.tween_property(main_camera, "global_rotation_degrees", pos_screen_cam.global_rotation_degrees, 2.5)
	tween.chain().tween_callback(start_actual_game)

func start_actual_game():
	print("Game Mulai!")
	is_game_started = true
	can_input = true
	head_pos_sit = pos_screen_cam.global_position
	rot_sit_base = pos_screen_cam.global_rotation_degrees
	available_level_indices.clear()
	for i in range(levels_list.size()):
		available_level_indices.append(i)
	if available_level_indices.has(0): available_level_indices.erase(0)
	load_level_from_list(0) 
	reset_ibu_cycle()
