class_name Level
extends Node2D
## Script base de cada nivel: registra tareas, tiempo y cámara en el GameManager.

@export var level_number: int = 1
@export var level_title: String = "Nivel"
@export_multiline var objective: String = ""
@export var time_limit: float = 90.0
@export var music: String = "level"
@export_range(0.0, 1.0) var difficulty: float = 0.0  ## Solo informativo (0 = fácil, 1 = máximo)
@export var wrong_item_penalty: float = 0.0  ## Segundos que resta dejar un objeto en el lugar equivocado

@onready var ground: TileMapLayer = $Ground
@onready var player: Player = $Entities/Player


func _ready() -> void:
	_setup_camera()
	AudioManager.play_music(music)
	var total := get_tree().get_nodes_in_group("level_task").size()
	GameManager.begin_level(level_number, time_limit, total, {
		"title": level_title,
		"objective": objective,
		"number": level_number,
		"wrong_penalty": wrong_item_penalty,
		"difficulty": difficulty,
	})


func _setup_camera() -> void:
	var rect := ground.get_used_rect()
	var ts := ground.tile_set.tile_size
	var cam := player.camera
	cam.limit_left = rect.position.x * ts.x
	cam.limit_top = rect.position.y * ts.y - 16  # deja espacio bajo la barra del HUD
	cam.limit_right = rect.end.x * ts.x
	cam.limit_bottom = rect.end.y * ts.y
	cam.reset_smoothing()
