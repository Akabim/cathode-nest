extends Camera3D

# --- PENGATURAN ---
@export_group("Gyro Settings")
@export var use_gyro: bool = true
@export var sensitivity: float = 2.0 # Kalau terlalu goyang, kecilin jadi 0.5
@export var max_sway_degree: float = 10.0 # Maksimal miring berapa derajat (biar gak pusing)
@export var smooth_speed: float = 5.0 # Semakin kecil = semakin smooth/lambat

# Posisi awal kamera (biar bisa balik ke tengah)
var initial_rotation_degrees: Vector3

func _ready():
	# Simpan rotasi awal kamera
	initial_rotation_degrees = rotation_degrees

func _process(delta):
	if not use_gyro:
		return
		
	# 1. Ambil data Gyroscope
	# Di HTML5, kadang sumbunya ketuker-tuker tergantung browser,
	# tapi mapping standar Godot biasanya: X=Pitch, Y=Yaw.
	var gyro_data = Input.get_gyroscope()
	
	# 2. Hitung target kemiringan
	# Kita pake gyro.y buat geser Kiri-Kanan (Rotasi Y kamera)
	# Kita pake gyro.x buat geser Atas-Bawah (Rotasi X kamera)
	
	# "clamp" itu biar miringnya ngga kebablasan sampe muter balik
	var target_rot_x = clamp(initial_rotation_degrees.x + (gyro_data.x * sensitivity), initial_rotation_degrees.x - max_sway_degree, initial_rotation_degrees.x + max_sway_degree)
	var target_rot_y = clamp(initial_rotation_degrees.y + (gyro_data.y * sensitivity), initial_rotation_degrees.y - max_sway_degree, initial_rotation_degrees.y + max_sway_degree)
	
	# 3. Gerakkan kamera dengan halus (Interpolasi/Lerp)
	rotation_degrees.x = lerp(rotation_degrees.x, target_rot_x, delta * smooth_speed)
	rotation_degrees.y = lerp(rotation_degrees.y, target_rot_y, delta * smooth_speed)
