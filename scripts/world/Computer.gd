class_name Computer
extends Interactable
## Computadora que se enciende manteniendo [E]. Cuenta como tarea.

@export var pc_name: String = "PC"

@onready var screen: Sprite2D = $Sprite2D
@onready var hold_bar: Node2D = $HoldBar
@onready var hold_fill: ColorRect = $HoldBar/Fill
@onready var led: ColorRect = $Led

var is_on: bool = false
var _t: float = 0.0


func _ready() -> void:
	if hold_time <= 0.0:
		hold_time = 1.2
	super()
	add_to_group("level_task")
	screen.modulate = Color(0.4, 0.4, 0.55)
	hold_bar.visible = false
	led.color = Color(0.85, 0.2, 0.2)


func _process(delta: float) -> void:
	super(delta)
	if is_on:
		_t += delta
		led.color = Color(0.3, 1.0, 0.4) if int(_t * 3.0) % 2 == 0 else Color(0.2, 0.7, 0.3)


func can_interact(_player: Player) -> bool:
	return not is_on


func get_prompt(_player: Player) -> String:
	return "Mantén [E]: encender %s" % pc_name


func set_hold_progress(value: float) -> void:
	hold_bar.visible = value > 0.0 and not is_on
	hold_fill.size.x = roundf(14.0 * clampf(value, 0.0, 1.0))


func interact(_player: Player) -> void:
	is_on = true
	hold_bar.visible = false
	set_highlight(false)
	screen.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(screen, "self_modulate", Color(1.8, 1.8, 1.4), 0.08)
	tw.tween_property(screen, "self_modulate", Color.WHITE, 0.25)
	AudioManager.play_sfx("boot")
	GameManager.complete_task("%s encendida" % pc_name)
