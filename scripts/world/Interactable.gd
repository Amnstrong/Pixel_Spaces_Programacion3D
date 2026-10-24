class_name Interactable
extends Area2D
## Clase base para todo lo que el jugador puede usar con [E].

@export var hold_time: float = 0.0  ## 0 = pulsar; >0 = mantener pulsado X segundos
@export var highlight_path: NodePath = NodePath("Sprite2D")

var _highlighted: bool = false
var _hl_time: float = 0.0


func _ready() -> void:
	collision_layer = 4  # capa 3: interactables
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")


func can_interact(_player: Player) -> bool:
	return true


func get_prompt(_player: Player) -> String:
	return ""


func interact(_player: Player) -> void:
	pass


func set_hold_progress(_value: float) -> void:
	pass


func set_highlight(on: bool) -> void:
	_highlighted = on
	var n := _get_highlight_node()
	if n and not on:
		n.self_modulate = Color.WHITE


func _get_highlight_node() -> CanvasItem:
	return get_node_or_null(highlight_path) as CanvasItem


func _process(delta: float) -> void:
	if _highlighted:
		_hl_time += delta
		var n := _get_highlight_node()
		if n:
			var k := (sin(_hl_time * 9.0) + 1.0) * 0.5
			n.self_modulate = Color.WHITE.lerp(Color(1.7, 1.55, 1.1), k)
