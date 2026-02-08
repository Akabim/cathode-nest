extends CharacterBody3D

@export var speed: float = 3.0
@export var gravity: float = 9.8
@export var mouse_sensitivity: float = 0.003

# Variabel untuk menampung node Head atau Camera
var camera_pivot: Node3D = null 

@onready var raycast = get_node_or_null("Head/Camera3D/InteractionRay")

var is_locked = true # Default TERKUNCI

func _ready():
	add_to_group("player")
	set_mode(true)
	
	# --- PERBAIKAN: CARI KAMERA OTOMATIS ---
	# Coba cari node bernama "Head" dulu
	var head_node = get_node_or_null("Head")
	if head_node:
		camera_pivot = head_node
		print("✅ Player: Node 'Head' ditemukan.")
	else:
		# Kalau Head gak ada, cari Camera3D langsung
		print("⚠️ Player: Node 'Head' TIDAK ADA! Mencari Camera3D...")
		var cam = find_child("Camera3D", true, false)
		if cam:
			camera_pivot = cam
			print("✅ Player: Camera3D ditemukan sebagai pengganti Head.")
		else:
			print("❌ ERROR FATAL: Player tidak punya 'Head' atau 'Camera3D'!")
	# ---------------------------------------

func set_mode(locked: bool):
	is_locked = locked
	print("🔒 Player Locked Status: ", is_locked) # Debug print
	if is_locked:
		velocity = Vector3.ZERO

func _physics_process(delta):
	if is_locked: return

	if not is_on_floor(): velocity.y -= gravity * delta
	
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _input(event):
	# LOGIC FPS (Hanya jalan kalau TIDAK locked)
	if not is_locked:
		
		# FAILSAFE: Klik kiri untuk kunci mouse jika lepas
		if event is InputEventMouseButton and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				print("🖱️ Mouse dipaksa CAPTURED oleh klik player.")
		
		# Gerakin Kamera
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			
			# Putar Badan (Y-Axis)
			rotate_y(-event.relative.x * mouse_sensitivity)
			
			# Putar Kepala/Kamera (X-Axis)
			if camera_pivot:
				camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
				camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))
			else:
				# Kalau sampai sini masih print error, berarti struktur scene kamu salah
				print_debug("❌ Error: Tidak bisa putar kamera karena Pivot NULL")

		# Interaksi
		if event.is_action_pressed("interact"):
			check_interaction()

func check_interaction():
	if raycast and raycast.is_colliding():
		var obj = raycast.get_collider()
		# Logic interaksi tambahan
