extends CanvasLayer
## HUD del nivel: tiempo, tareas, objetivo, ayudas y paneles de victoria/derrota.

@onready var level_label: Label = %LevelLabel
@onready var tasks_label: Label = %TasksLabel
@onready var timer_label: Label = %TimerLabel
@onready var pause_button: Button = %PauseButton
@onready var objective_panel: Control = %ObjectivePanel
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt_panel: Control = %PromptPanel
@onready var prompt_label: Label = %PromptLabel
@onready var carry_label: Label = %CarryLabel
@onready var toast_label: Label = %ToastLabel
@onready var dim: ColorRect = %Dim
@onready var complete_panel: Control = %CompletePanel
@onready var complete_title: Label = %CompleteTitle
@onready var complete_stats: Label = %CompleteStats
@onready var stars_box: HBoxContainer = %StarsBox
@onready var next_button: Button = %NextButton
@onready var complete_menu_button: Button = %CompleteMenuButton
@onready var fail_panel: Control = %FailPanel
@onready var fail_title: Label = %FailTitle
@onready var retry_button: Button = %RetryButton
@onready var fail_menu_button: Button = %FailMenuButton

var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.level_started.connect(_on_level_started)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.tasks_changed.connect(_on_tasks_changed)
	GameManager.prompt_changed.connect(_on_prompt_changed)
	GameManager.carrying_changed.connect(_on_carrying_changed)
	GameManager.toast_requested.connect(_on_toast)
	GameManager.level_completed.connect(_on_level_completed)
	GameManager.level_failed.connect(_on_level_failed)
	UIUtils.wire_button(pause_button, func() -> void: get_tree().call_group("pause_menu", "open"))
	UIUtils.wire_button(next_button, GameManager.next_level)
	UIUtils.wire_button(complete_menu_button, GameManager.goto_main_menu)
	UIUtils.wire_button(retry_button, GameManager.restart_level)
	UIUtils.wire_button(fail_menu_button, GameManager.goto_main_menu)
	dim.visible = false
	complete_panel.visible = false
	fail_panel.visible = false
	prompt_panel.visible = false
	carry_label.text = ""
	toast_label.modulate.a = 0.0


func _on_level_started(info: Dictionary) -> void:
	level_label.text = "N%d %s" % [info.get("number", 1), info.get("title", "")]
	objective_label.text = info.get("objective", "")
	objective_panel.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(objective_panel, "modulate:a", 0.0, 0.8)


func _on_time_changed(t: float) -> void:
	var secs := int(ceil(t))
	timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
	if secs <= 10:
		timer_label.modulate = Color(1, 0.35, 0.35) if int(t * 4.0) % 2 == 0 else Color.WHITE
	elif secs <= 20:
		timer_label.modulate = Color(1, 0.8, 0.4)
	else:
		timer_label.modulate = Color.WHITE


func _on_tasks_changed(done: int, total: int) -> void:
	tasks_label.text = "Tareas %d/%d" % [done, total]
	var tw := create_tween()
	tasks_label.scale = Vector2(1.2, 1.2)
	tw.tween_property(tasks_label, "scale", Vector2.ONE, 0.2)


func _on_prompt_changed(text: String) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = text


func _on_carrying_changed(item_name: String) -> void:
	carry_label.text = "Llevas: %s" % item_name if item_name != "" else ""


func _on_toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.modulate = color
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _on_level_completed(result: Dictionary) -> void:
	prompt_panel.visible = false
	objective_panel.visible = false
	dim.visible = true
	complete_panel.visible = true
	var last: bool = not result.get("has_next", false)
	complete_title.text = "¡JUEGO COMPLETADO!" if last else "¡NIVEL COMPLETADO!"
	var stars: int = result.get("stars", 1)
	for i in stars_box.get_child_count():
		var star := stars_box.get_child(i) as TextureRect
		star.texture = preload("res://assets/ui/star_full.png") if i < stars else preload("res://assets/ui/star_empty.png")
		star.pivot_offset = Vector2(3.5, 3.5)
		star.scale = Vector2.ZERO
		var tw := create_tween()
		tw.tween_interval(0.25 * i + 0.1)
		tw.tween_property(star, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var lines := [
		"Tareas: %d  (+%d)" % [result.tasks, result.task_points],
		"Bonus de tiempo: +%d" % result.bonus,
		"Puntaje del nivel: %d" % result.score,
		("¡NUEVO RÉCORD!" if result.new_record else "Récord: %d" % result.best),
		"Puntaje total: %d" % result.total_score,
	]
	if result.get("rank", 0) > 0:
		lines.append("Ranking del nivel: #%d de %d" % [result.rank, result.rank_players])
	complete_stats.text = "\n".join(lines)
	next_button.visible = not last
	if last:
		complete_menu_button.grab_focus()
	else:
		next_button.grab_focus()


func _on_level_failed(reason: String) -> void:
	prompt_panel.visible = false
	objective_panel.visible = false
	dim.visible = true
	fail_panel.visible = true
	fail_title.text = reason.to_upper()
	retry_button.grab_focus()
