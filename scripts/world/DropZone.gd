class_name DropZone
extends Interactable
## Lugar correcto para un objeto. Muestra una silueta del objeto esperado. Cuenta como tarea.

signal filled

@export var accepts_item: String = "item"
@export var zone_name: String = "Mueble"
@export var ghost_texture: Texture2D
@export var counts_as_task: bool = true

@onready var slot: Sprite2D = $Slot
@onready var marker: Sprite2D = get_node_or_null("Marker")

var is_filled: bool = false
var _t: float = 0.0


func _ready() -> void:
	highlight_path = NodePath("Slot")
	super()
	if counts_as_task:
		add_to_group("level_task")
	if ghost_texture:
		slot.texture = ghost_texture


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if not is_filled:
		slot.modulate = Color(0.75, 0.85, 1.0, 0.3 + 0.15 * sin(_t * 4.0))
		if marker:
			marker.position.y = marker.get_meta("base_y", marker.position.y) + roundf(sin(_t * 5.0) * 2.0)


func can_interact(player: Player) -> bool:
	return not is_filled and player.is_carrying()


func get_prompt(player: Player) -> String:
	return "[E] Dejar %s en %s" % [player.carried_item_name, zone_name]


func interact(player: Player) -> void:
	if player.carried_item_id != accepts_item:
		AudioManager.play_sfx("wrong")
		var msg := "%s no va en %s" % [player.carried_item_name, zone_name]
		var penalty: float = GameManager.level_info.get("wrong_penalty", 0.0)
		if penalty > 0.0:
			GameManager.add_time(-penalty)
			msg += " -%ds" % int(penalty)
		GameManager.toast(msg, Color(1.0, 0.55, 0.45))
		GameManager.record_event("wrong_item", "%s -> %s" % [player.carried_item_id, accepts_item])
		GameLog.info("OBJETO", "Lugar equivocado: %s en %s (esperaba '%s')" % [player.carried_item_name, zone_name, accepts_item])
		return
	var item_name := player.carried_item_name
	if player.carried_texture:
		slot.texture = player.carried_texture
	player.drop_item()
	is_filled = true
	set_highlight(false)
	slot.modulate = Color.WHITE
	if marker:
		marker.visible = false
	var tw := create_tween()
	slot.scale = Vector2(1.6, 1.6)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_sfx("place")
	filled.emit()
	if counts_as_task:
		GameManager.complete_task("%s en %s" % [item_name, zone_name])
