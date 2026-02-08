extends Control

signal coin_inserted # Signal buat ngasih tau GameManager

@onready var coin = $TextureRect
var start_pos = Vector2.ZERO
var is_dragging = false
var drag_threshold = -200.0 # Seberapa jauh harus geser ke atas biar dianggap "Masuk"

func _ready():
	# Simpan posisi awal koin (di bawah tengah)
	start_pos = coin.position

func _gui_input(event):
	# LOGIC DRAG & DROP
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# Mulai Drag (Cek apa jarinya kena koin?)
			if coin.get_rect().has_point(event.position):
				is_dragging = true
		else:
			# Lepas Drag (Cek apakah sudah cukup tinggi?)
			is_dragging = false
			check_insert()

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		if is_dragging:
			# Gerakkan koin ngikutin jari (hanya sumbu Y ke atas)
			# Kita batasi biar gak bisa ditarik ke bawah layar
			var new_y = event.position.y - (coin.size.y / 2)
			if new_y < start_pos.y: 
				coin.position.y = new_y

func check_insert():
	# Hitung jarak dari posisi awal
	var distance = coin.position.y - start_pos.y
	
	# Kalau ditarik cukup tinggi (melewati threshold negatif/atas)
	if distance < drag_threshold:
		print("Koin Masuk!")
		animate_insert()
	else:
		# Kalau belum cukup tinggi, balikin ke bawah (Snap back)
		var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(coin, "position", start_pos, 0.5)

func animate_insert():
	# Matikan input biar gak bisa di-drag lagi
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Animasi koin mengecil & hilang ke atas (seolah masuk lobang)
	var tween = create_tween()
	tween.tween_property(coin, "position:y", coin.position.y - 100, 0.2)
	tween.parallel().tween_property(coin, "scale", Vector2(0.5, 0.5), 0.2)
	tween.parallel().tween_property(coin, "modulate:a", 0.0, 0.2)
	
	# Panggil signal setelah animasi selesai
	tween.chain().tween_callback(func(): emit_signal("coin_inserted"))
	
	# Hancurkan UI ini nanti
	tween.chain().tween_callback(queue_free)
