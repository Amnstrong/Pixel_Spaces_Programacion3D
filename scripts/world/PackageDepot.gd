class_name PackageDepot
extends Interactable
## Pila de paquetes para el nivel de reparto.

@export var packages: int = 3
@export var package_texture: Texture2D

@onready var stack: Node2D = $Stack


func _ready() -> void:
	highlight_path = NodePath("Stack")
	super()
	_refresh()


func can_interact(player: Player) -> bool:
	return packages > 0 and not player.is_carrying()


func get_prompt(_player: Player) -> String:
	return "[E] Tomar paquete (%d)" % packages


func interact(player: Player) -> void:
	packages -= 1
	player.pick_up("package", "Paquete", package_texture)
	GameManager.record_event("pickup", "package")
	AudioManager.play_sfx("pickup", 0.05)
	_refresh()


func _refresh() -> void:
	for i in stack.get_child_count():
		stack.get_child(i).visible = i < packages
