extends Camera2D

@export var player_path : NodePath
@export var smooth_speed := 6.0

var player

func _ready():
	player = get_node(player_path)

func _process(delta):

	if not player:
		return

	global_position = global_position.lerp(
		player.global_position,
		delta * smooth_speed
	)


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
