extends Control

@onready var prompt_label = $LabelPrompt # Label teks atas
@onready var visual_container = $HBoxContainer # Container di tengah

# Fungsi ini dipanggil otomatis sama GameManager
func setup_visuals_from_resource(data: LevelData):
	# 1. Update Teks
	prompt_label.text = data.prompt_text
	
	# 2. Hapus visual lama
	for child in visual_container.get_children():
		child.queue_free()
	
	# 3. Spawn Gambar Baru
	if data.level_image:
		# Kalau level 1 (Apel) dan mau spawn 3 biji, kita bisa hardcode logic-nya sedikit 
		# atau tambah variabel 'count' di Resource. 
		# Buat simpel, kita tampilin gambarnya aja dulu.
		
		var rect = TextureRect.new()
		rect.texture = data.level_image
		rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		visual_container.add_child(rect)
