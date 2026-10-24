extends CanvasLayer
## Menú de pausa (ESC / P / botón Start).

@onready var root: Control = %Root
@onready var objective_label: Label = %ObjectiveLabel
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	root.visible = false
	UIUtils.wire_button(resume_button, close)
	UIUtils.wire_button(restart_button, GameManager.restart_level)
	UIUtils.wire_button(menu_button, GameManager.goto_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if root.visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if not GameManager.level_running or root.visible:
		return
	objective_label.text = GameManager.level_info.get("objective", "")
	root.visible = true
	get_tree().paused = true
	GameManager.record_event("pause")
	GameLog.info("PAUSA", "Pausa en nivel %d | quedan %.1fs" % [GameManager.current_level, GameManager.time_left])
	resume_button.grab_focus()


func close() -> void:
	if not root.visible:
		return
	root.visible = false
	get_tree().paused = false
	GameManager.record_event("resume")
	GameLog.info("PAUSA", "Reanudado")
