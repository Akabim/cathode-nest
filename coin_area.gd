extends Area3D

signal coin_inserted

@export var slot_target: Marker3D 
@onready var mesh = $CoinMesh 

# --- PENGATURAN KECEPATAN (Edit di Inspector) ---
@export_group("Animation Settings")
@export var float_duration: float = 2.0  # Waktu terbang ke depan lubang (Detik)
@export var insert_duration: float = 0.8 # Waktu masuk ke dalam lubang (Detik)

var is_clicked = false

func _ready():
	# Animasi Idle (Naik turun dikit)
	var tween = create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y + 0.02, 1.0)
	tween.tween_property(self, "position:y", position.y - 0.02, 1.0)

func _input_event(camera, event, position, normal, shape_idx):
	if not is_clicked and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		insert_into_slot()

func insert_into_slot():
	if not slot_target:
		print("ERROR: Slot Target belum di-assign!")
		return

	is_clicked = true
	print("Koin OTW Slot (Slow Motion)...")
	input_ray_pickable = false 
	
	var tween = create_tween()
	
	# FASE 1: TERBANG (Slow Motion)
	tween.set_parallel(true)
	# Pake EASE_IN_OUT biar awalnya pelan, tengah ngebut, akhirnya pelan (Cinematic)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Pake variabel 'float_duration'
	tween.tween_property(self, "global_position", slot_target.global_position, float_duration)
	tween.tween_property(self, "global_rotation", slot_target.global_rotation, float_duration)
	
	# FASE 2: MASUK (Dorong)
	tween.chain().set_parallel(true) 
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Hitung posisi masuk (Maju 0.2 meter ke dalam Z local target)
	var masuk_pos = slot_target.global_position - (slot_target.global_transform.basis.z * 0.2)
	
	# Pake variabel 'insert_duration'
	tween.tween_property(self, "global_position", masuk_pos, insert_duration)
	tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), insert_duration) # Mengecil pelan2
	
	# Selesai
	tween.chain().tween_callback(finish_insertion)

func finish_insertion():
	visible = false
	emit_signal("coin_inserted")
