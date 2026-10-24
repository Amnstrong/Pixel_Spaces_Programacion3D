class_name PickupItem
extends Interactable
## Objeto desordenado que se puede recoger y llevar a su mueble.

@export var item_id: String = "item"
@export var display_name: String = "Objeto"
@export var texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
var _t: float = 0.0
var _taken: bool = false


func _ready() -> void:
	super()
	if texture:
		sprite.texture = texture
	_t = randf() * TAU


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	sprite.position.y = -4.0 + roundf(sin(_t * 3.0) * 1.0)


func can_interact(player: Player) -> bool:
	return not _taken and not player.is_carrying()


func get_prompt(_player: Player) -> String:
	return "[E] Recoger: %s" % display_name


func interact(player: Player) -> void:
	_taken = true
	player.pick_up(item_id, display_name, sprite.texture)
	GameManager.record_event("pickup", item_id)
	AudioManager.play_sfx("pickup", 0.08)
	queue_free()
