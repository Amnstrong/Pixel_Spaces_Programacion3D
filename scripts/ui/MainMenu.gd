extends Control
## Menú principal: Jugar/Continuar, Selección de Nivel, Ranking (SQLite), cambio de nombre y Salir.

const STAR_FULL := preload("res://assets/ui/star_full.png")
const STAR_EMPTY := preload("res://assets/ui/star_empty.png")
const RANK_ROWS := 8

@onready var title: Control = %Title
@onready var menu_area: Control = %MenuArea
@onready var credits: Control = $Credits
@onready var play_button: Button = %PlayButton
@onready var levels_button: Button = %LevelsButton
@onready var ranking_button: Button = %RankingButton
@onready var quit_button: Button = %QuitButton
@onready var player_label: Label = %PlayerLabel
@onready var change_name_button: Button = %ChangeNameButton
# selección de nivel
@onready var level_select: Control = %LevelSelect
@onready var level_grid: GridContainer = %LevelGrid
@onready var level_info: Label = %LevelInfo
@onready var back_button: Button = %BackButton
# nombre
@onready var name_panel: Control = %NamePanel
@onready var name_edit: LineEdit = %NameEdit
@onready var name_ok_button: Button = %NameOkButton
@onready var name_cancel_button: Button = %NameCancelButton
@onready var user_list: VBoxContainer = %UserList
@onready var name_info: Label = %NameInfo
@onready var menu_toast: Label = %MenuToast
# ranking
@onready var ranking_panel: Control = %RankingPanel
@onready var view_label: Label = %ViewLabel
@onready var rank_grid: GridContainer = %RankGrid
@onready var rank_empty: Label = %RankEmpty
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var open_folder_button: Button = %OpenFolderButton
@onready var rank_back_button: Button = %RankBackButton
@onready var dashboard_button: Button = %DashboardButton

var _t: float = 0.0
var _grid_built: bool = false
var _rank_view: int = 0  ## 0 = general, 1..25 = nivel
var _after_name: Callable = Callable()


func _ready() -> void:
	AudioManager.play_music("menu")
	_update_play_button()
	UIUtils.wire_button(play_button, _require_name.bind(GameManager.continue_game))
	UIUtils.wire_button(levels_button, _show.bind("levels"))
	UIUtils.wire_button(ranking_button, _open_ranking)
	UIUtils.wire_button(quit_button, func() -> void: get_tree().quit())
	UIUtils.wire_button(change_name_button, _ask_name.bind(Callable()))
	UIUtils.wire_button(back_button, _show.bind("main"))
	UIUtils.wire_button(name_ok_button, _confirm_name)
	UIUtils.wire_button(name_cancel_button, _show.bind("main"))
	name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	name_edit.text_changed.connect(_on_name_typed)
	menu_toast.modulate.a = 0.0
	UIUtils.wire_button(prev_button, _change_rank_view.bind(-1))
	UIUtils.wire_button(next_button, _change_rank_view.bind(1))
	UIUtils.wire_button(open_folder_button, func() -> void:
		GameLog.info("APP", "Abriendo carpeta de datos")
		OS.shell_open(Database.get_db_folder()))
	UIUtils.wire_button(rank_back_button, _show.bind("main"))
	UIUtils.wire_button(dashboard_button, Database.open_dashboard)
	dashboard_button.visible = Database.dashboard_enabled()  # solo para desarrolladores
	if OS.has_feature("web"):
		quit_button.visible = false
		open_folder_button.visible = false
	_update_player_label()
	_show("main")


func _process(delta: float) -> void:
	_t += delta
	title.position.y = roundf(sin(_t * 2.0) * 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if ranking_panel.visible:
		if event.is_action_pressed("ui_left"):
			_change_rank_view(-1)
		elif event.is_action_pressed("ui_right"):
			_change_rank_view(1)
	if event.is_action_pressed("ui_cancel") and not menu_area.visible:
		_show("main")
		get_viewport().set_input_as_handled()


## Muestra una sola "pantalla" del menú.
func _show(which: String) -> void:
	if which == "levels" and not _grid_built:
		_build_grid()
	var on_main := which == "main"
	title.visible = on_main
	menu_area.visible = on_main
	credits.visible = on_main and menu_toast.modulate.a < 0.01
	menu_toast.visible = on_main
	level_select.visible = which == "levels"
	name_panel.visible = which == "name"
	ranking_panel.visible = which == "ranking"
	match which:
		"main":
			play_button.grab_focus()
		"levels":
			var first := mini(GameManager.unlocked_level, GameManager.LEVEL_COUNT) - 1
			(level_grid.get_child(first).get_child(0) as Button).grab_focus()
		"name":
			name_edit.grab_focus()
		"ranking":
			rank_back_button.grab_focus()


# ---------------------------------------------------------------- usuarios
func _require_name(then: Callable) -> void:
	if GameManager.player_name == "":
		_ask_name(then)
	else:
		then.call()


func _ask_name(then: Callable) -> void:
	_after_name = then
	name_edit.text = ""
	_populate_users()
	_on_name_typed("")
	_show("name")
	if user_list.get_child_count() > 0:
		(user_list.get_child(0) as Button).grab_focus()


func _populate_users() -> void:
	for c in user_list.get_children():
		user_list.remove_child(c)
		c.queue_free()
	for u in GameManager.get_all_users():
		var b := Button.new()
		var won: int = u.get("levels_won", 0)
		b.text = "%s%s   nivel %d, %d estrellas" % [u.name, " (actual)" if u.current else "", u.unlocked, u.stars]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%d niveles ganados" % won
		user_list.add_child(b)
		UIUtils.wire_button(b, _enter_user.bind(u.name))
	user_list.get_parent().visible = user_list.get_child_count() > 0


func _on_name_typed(text: String) -> void:
	var n := GameManager.clean_name(text)
	if n == "":
		name_info.text = "Un usuario nuevo empieza desde el nivel 1."
		return
	var u := GameManager.get_user_summary(n)
	if u.exists:
		name_info.text = "%s ya existe: continúa en el nivel %d." % [u.name, u.unlocked]
	else:
		name_info.text = "Usuario nuevo: empieza desde cero."


func _confirm_name() -> void:
	if GameManager.clean_name(name_edit.text) == "":
		AudioManager.play_sfx("wrong")
		name_edit.grab_focus()
		return
	_enter_user(name_edit.text)


func _enter_user(user_name: String) -> void:
	var r := GameManager.switch_user(user_name)
	if r.is_empty():
		return
	_update_player_label()
	_update_play_button()
	_reset_level_grid()
	if r.is_new:
		_flash("Hola, %s: empiezas desde el nivel 1" % r.name)
	elif r.restored_from_db:
		_flash("%s: avance recuperado de la base de datos (nivel %d)" % [r.name, r.unlocked])
	else:
		_flash("Hola de nuevo, %s: vas en el nivel %d" % [r.name, r.unlocked])
	if _after_name.is_valid():
		var cb := _after_name
		_after_name = Callable()
		cb.call()
	else:
		_show("main")


func _update_player_label() -> void:
	player_label.text = "Jugador: %s" % (GameManager.player_name if GameManager.player_name != "" else "sin usuario")


func _update_play_button() -> void:
	if GameManager.player_name != "" and GameManager.unlocked_level > 1:
		play_button.text = "Continuar (Nivel %d)" % GameManager.unlocked_level
	else:
		play_button.text = "Jugar"


func _reset_level_grid() -> void:
	for c in level_grid.get_children():
		level_grid.remove_child(c)
		c.queue_free()
	_grid_built = false


var _toast_tween: Tween

## Aviso breve en la línea de los créditos (que se ocultan mientras tanto).
func _flash(text: String) -> void:
	menu_toast.text = text
	menu_toast.modulate.a = 1.0
	credits.visible = false
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.0)
	_toast_tween.tween_property(menu_toast, "modulate:a", 0.0, 0.6)
	_toast_tween.tween_callback(func() -> void: credits.visible = menu_area.visible)


# ---------------------------------------------------------------- selección de nivel
func _build_grid() -> void:
	_grid_built = true
	level_grid.columns = 7
	for n in range(1, GameManager.LEVEL_COUNT + 1):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(26, 13)
		b.disabled = not GameManager.is_level_unlocked(n)
		cell.add_child(b)
		cell.add_child(_stars_box(GameManager.get_best_stars(n)))
		level_grid.add_child(cell)
		UIUtils.wire_button(b, _require_name.bind(func() -> void:
			GameManager.total_score = 0
			GameManager.load_level(n)
		))
		b.focus_entered.connect(_on_level_focused.bind(n))


func _stars_box(count: int) -> HBoxContainer:
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 1)
	for i in 3:
		var star_rect := TextureRect.new()
		star_rect.texture = STAR_FULL if i < count else STAR_EMPTY
		stars.add_child(star_rect)
	return stars


func _on_level_focused(n: int) -> void:
	var theme_names := {"room": "Habitación", "office": "Oficina", "street": "Calle"}
	var theme_name: String = theme_names[GameManager.get_level_theme(n)]
	level_info.text = "%d. %s (%s)   Récord: %d" % [n, GameManager.get_level_name(n), theme_name, GameManager.get_best_score(n)]


# ---------------------------------------------------------------- ranking
func _open_ranking() -> void:
	_rank_view = 0
	_refresh_ranking()
	_show("ranking")


func _change_rank_view(step: int) -> void:
	_rank_view = wrapi(_rank_view + step, 0, GameManager.LEVEL_COUNT + 1)
	_refresh_ranking()


func _refresh_ranking() -> void:
	for c in rank_grid.get_children():
		rank_grid.remove_child(c)
		c.queue_free()
	if not Database.available:
		view_label.text = "Ranking no disponible"
		rank_empty.text = "No se cargó la extensión SQLite."
		rank_empty.visible = true
		return
	var rows: Array
	var last_col := ""
	if _rank_view == 0:
		view_label.text = "General (todos los niveles)"
		rows = Database.get_global_ranking(RANK_ROWS)
		last_col = "Niveles"
	else:
		view_label.text = "Nivel %d: %s" % [_rank_view, GameManager.get_level_name(_rank_view)]
		rows = Database.get_level_ranking(_rank_view, RANK_ROWS)
		last_col = "Estrellas"
	rank_empty.text = "Aún no hay partidas ganadas aquí."
	rank_empty.visible = rows.is_empty()
	rank_grid.visible = not rows.is_empty()
	if rows.is_empty():
		return
	var widths := [14.0, 100.0, 44.0, 50.0]
	var headers := ["#", "Jugador", "Puntos", last_col]
	for i in headers.size():
		_rank_cell(headers[i], Color(0.7, 0.68, 0.8), widths[i])
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := str(r["name"]).to_lower() == GameManager.player_name.to_lower()
		var col := Color(1.0, 0.83, 0.38) if mine else Color(0.96, 0.93, 0.85)
		_rank_cell(str(i + 1), col, 14)
		_rank_cell(str(r["name"]), col, 100)
		_rank_cell(str(r["score"]), col, 44)
		if _rank_view == 0:
			_rank_cell("%d/%d" % [int(r["levels"]), GameManager.LEVEL_COUNT], col, 50)
		else:
			rank_grid.add_child(_stars_box(int(r["stars"])))


func _rank_cell(text: String, color: Color, min_w: float = 0.0) -> void:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(min_w, 0)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	rank_grid.add_child(l)
