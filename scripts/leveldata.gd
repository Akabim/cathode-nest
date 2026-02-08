extends Resource
class_name LevelData

# 1. Tambah SWIPE ke Enum
enum LevelType { STANDARD, SEQUENCE, WAIT, SPAM, SWIPE, HOLD }

@export_group("Visuals")
@export var level_id: int = 1
@export_multiline var prompt_text: String = "Instructions here"
@export var level_image: Texture2D      # Gambar Loading 90%
@export var level_image_alt: Texture2D  # Gambar Loading 100% (Done)

@export_group("Logic")
@export var type: LevelType = LevelType.STANDARD
@export var correct_buttons: Array[int] = [] 
@export var sequence_order: Array[int] = []  
@export var wait_duration: float = 5.0        
@export var spam_amount: int = 5              

# 2. Tambah Target Swipe (Pixel Distance)
@export var swipe_amount: float = 1000.0 # Butuh geser sejauh 1000 pixel
