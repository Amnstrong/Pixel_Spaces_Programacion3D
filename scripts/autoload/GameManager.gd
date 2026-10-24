extends Node
## Autoload global: puntaje, tiempo por nivel, tareas, guardado y flujo de escenas.

signal time_changed(time_left: float)
signal tasks_changed(done: int, total: int)
signal level_started(info: Dictionary)
signal level_completed(result: Dictionary)
signal level_failed(reason: String)
signal toast_requested(text: String, color: Color)
signal prompt_changed(text: String)
signal carrying_changed(item_name: String)

const LOADING_SCENE := "res://scenes/ui/LoadingScreen.tscn"
const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const LEVEL_COUNT := 25
const LEVEL_PATH := "res://scenes/levels/Level%d.tscn"
## Escenario de cada nivel: rota habitación -> oficina -> calle.
const THEMES := ["room", "office", "street"]
const LEVEL_NAMES := [
	"La Habitación", "La Oficina", "La Calle",
	"Cuarto Desordenado", "Lunes de Oficina", "Reparto Matutino",
	"Fiesta en Casa", "Cierre de Mes", "Hora Pico",
	"Mudanza Express", "Auditoría Sorpresa", "Barrio Comercial",
	"Visita de la Abuela", "Junta Urgente", "Lluvia de Pedidos",
	"Caos Familiar", "Fusión Corporativa", "Avenida Central",
	"Limpieza Total", "Lanzamiento", "Black Friday",
	"Casa Llena", "Servidores Caídos", "Tráfico Infernal",
	"El Gran Final",
]
## Pon esto en true para probar cualquier nivel sin desbloquearlo.
const UNLOCK_ALL := false
const STAR_THRESHOLDS := [0.2, 0.4]  ## % de tiempo sobrante para 2 y 3 estrellas
const SAVE_PATH := "user://save.cfg"
const POINTS_PER_TASK := 100
const POINTS_PER_SECOND := 10

var next_scene_path: String = MAIN_MENU
var current_level: int = 0
var time_limit: float = 0.0
var time_left: float = 0.0
var tasks_done: int = 0
var tasks_total: int = 0
var level_running: bool = false
var total_score: int = 0
# --- avance del usuario ACTIVO (apuntan al perfil cargado; se guardan en save.cfg)
var best_scores: Dictionary = {}
var best_stars: Dictionary = {}
var unlocked_level: int = 1
var player_name: String = ""
## Todos los usuarios: clave = nombre en minúsculas ->
## {"name", "unlocked", "scores": {nivel: puntos}, "stars": {nivel: estrellas}, "created", "last_played"}
var profiles: Dictionary = {}
var level_info: Dictionary = {}

var _last_whole_second: int = -1
# --- datos de la partida en curso (para el dashboard de desarrollo)
var _attempt: Dictionary = {}
var _events: Array = []
var _elapsed: float = 0.0  ## tiempo activo de juego (no cuenta pausas)
const PATH_INTERVAL := 0.2  ## cada cuánto se guarda la posición del jugador (s)
var _path: PackedInt32Array = PackedInt32Array()  ## x0, y0, x1, y1, ...
var _path_timer: float = 0.0
var _player_ref: Node2D = null


func _ready() -> void:
	# PAUSABLE: el cronómetro se detiene automáticamente con el menú de pausa.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_setup_input()
	_load_save()


# ---------------------------------------------------------------- Escenas
func goto_scene(path: String) -> void:
	if level_running:
		_finish_attempt("abandon")
	GameLog.info("ESCENA", "Cambio a %s" % path.get_file())
	next_scene_path = path
	level_running = false
	get_tree().paused = false
	prompt_changed.emit("")
	get_tree().change_scene_to_file(LOADING_SCENE)


func goto_main_menu() -> void:
	goto_scene(MAIN_MENU)


func start_new_game() -> void:
	total_score = 0
	load_level(1)


func load_level(number: int) -> void:
	if number < 1 or number > LEVEL_COUNT:
		goto_main_menu()
		return
	current_level = number
	goto_scene(LEVEL_PATH % number)


func continue_game() -> void:
	total_score = 0
	load_level(mini(unlocked_level, LEVEL_COUNT))


func get_level_name(number: int) -> String:
	return LEVEL_NAMES[number - 1] if number >= 1 and number <= LEVEL_COUNT else ""


func get_level_theme(number: int) -> String:
	return THEMES[(number - 1) % THEMES.size()]


func is_level_unlocked(number: int) -> bool:
	return UNLOCK_ALL or number <= unlocked_level


func restart_level() -> void:
	load_level(current_level)


func has_next_level() -> bool:
	return current_level < LEVEL_COUNT


func next_level() -> void:
	if has_next_level():
		load_level(current_level + 1)
	else:
		goto_main_menu()


# ---------------------------------------------------------------- Nivel
func begin_level(number: int, limit: float, total: int, info: Dictionary) -> void:
	current_level = number
	time_limit = limit
	time_left = limit
	tasks_done = 0
	tasks_total = total
	level_info = info
	level_running = true
	_last_whole_second = -1
	_elapsed = 0.0
	_events.clear()
	_path = PackedInt32Array()
	_path_timer = PATH_INTERVAL  # primera muestra en el primer frame
	_player_ref = null
	_attempt = {"started_at": Time.get_datetime_string_from_system(false, true),
		"hits_car": 0, "hits_person": 0, "wrong_items": 0, "pauses": 0}
	level_started.emit(info)
	tasks_changed.emit(tasks_done, tasks_total)
	time_changed.emit(time_left)


func _process(delta: float) -> void:
	if not level_running:
		return
	_elapsed += delta
	_path_timer += delta
	if _path_timer >= PATH_INTERVAL:
		_path_timer -= PATH_INTERVAL
		_sample_path()
	time_left = maxf(0.0, time_left - delta)
	time_changed.emit(time_left)
	var whole := int(ceil(time_left))
	if whole != _last_whole_second:
		_last_whole_second = whole
		if whole > 0 and whole <= 10:
			AudioManager.play_sfx("tick")
	if time_left <= 0.0:
		_fail("¡Se acabó el tiempo!")


func add_time(seconds: float) -> void:
	if not level_running:
		return
	time_left = clampf(time_left + seconds, 0.0, 999.0)
	time_changed.emit(time_left)


func complete_task(label: String = "") -> void:
	if not level_running:
		return
	tasks_done += 1
	record_event("task", label)
	GameLog.info("TAREA", "%s (%d/%d) | quedan %.1fs" % [label, tasks_done, tasks_total, time_left])
	tasks_changed.emit(tasks_done, tasks_total)
	AudioManager.play_sfx("task")
	if label != "":
		toast("¡Listo! " + label, Color(0.6, 1.0, 0.6))
	if tasks_done >= tasks_total:
		_win()


func _win() -> void:
	level_running = false
	prompt_changed.emit("")
	var bonus := int(ceil(time_left)) * POINTS_PER_SECOND
	var score := tasks_done * POINTS_PER_TASK + bonus
	total_score += score
	var ratio := time_left / maxf(time_limit, 1.0)
	var stars := 1
	if ratio >= STAR_THRESHOLDS[1]:
		stars = 3
	elif ratio >= STAR_THRESHOLDS[0]:
		stars = 2
	var previous_best: int = best_scores.get(current_level, 0)
	var new_record := score > previous_best
	if new_record:
		best_scores[current_level] = score
	best_stars[current_level] = maxi(stars, best_stars.get(current_level, 0))
	unlocked_level = clampi(maxi(unlocked_level, current_level + 1), 1, LEVEL_COUNT)
	_save()
	_finish_attempt("win", score, stars)
	var db_result := Database.save_score(get_player_name(), current_level, score, stars, time_left, time_limit)
	AudioManager.play_sfx("level_complete")
	get_tree().paused = true
	level_completed.emit({
		"level": current_level,
		"tasks": tasks_done,
		"task_points": tasks_done * POINTS_PER_TASK,
		"bonus": bonus,
		"score": score,
		"best": maxi(score, previous_best),
		"new_record": new_record,
		"stars": stars,
		"rank": db_result.get("rank", 0),
		"rank_players": db_result.get("players", 0),
		"total_score": total_score,
		"has_next": has_next_level(),
	})


func _fail(reason: String) -> void:
	level_running = false
	_finish_attempt("fail")
	prompt_changed.emit("")
	AudioManager.play_sfx("fail")
	get_tree().paused = true
	level_failed.emit(reason)


# ---------------------------------------------------------------- Telemetría
## Registra un evento de la partida actual. Si no se da posición, usa la del jugador.
func record_event(type: String, detail: String = "", pos: Variant = null) -> void:
	if _attempt.is_empty():
		return
	if pos == null:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p:
			pos = p.global_position
	_events.append({"t": snappedf(_elapsed, 0.01), "type": type, "detail": detail,
		"x": roundf(pos.x) if pos != null else null, "y": roundf(pos.y) if pos != null else null})
	match type:
		"hit_car": _attempt.hits_car += 1
		"hit_person": _attempt.hits_person += 1
		"wrong_item": _attempt.wrong_items += 1
		"pause": _attempt.pauses += 1


func _sample_path() -> void:
	if not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	if _player_ref:
		_path.append(roundi(_player_ref.global_position.x))
		_path.append(roundi(_player_ref.global_position.y))


func _finish_attempt(result: String, score: int = 0, stars: int = 0) -> void:
	if _attempt.is_empty():
		return
	_sample_path()
	var a := _attempt
	_attempt = {}
	a.merge({
		"player": get_player_name(), "session_id": GameLog.session_id,
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"level": current_level, "level_name": get_level_name(current_level), "theme": get_level_theme(current_level),
		"difficulty": float(level_info.get("difficulty", 0.0)), "result": result, "score": score, "stars": stars,
		"tasks_done": tasks_done, "tasks_total": tasks_total, "time_limit": time_limit,
		"time_used": snappedf(_elapsed, 0.01), "time_left": snappedf(time_left, 0.01),
	})
	Database.save_attempt(a, _events, _path, PATH_INTERVAL)
	_events = []
	_path = PackedInt32Array()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and level_running:
		level_running = false
		_finish_attempt("abandon")


# ---------------------------------------------------------------- UI helpers
func toast(text: String, color: Color = Color.WHITE) -> void:
	toast_requested.emit(text, color)


func notify_prompt(text: String) -> void:
	prompt_changed.emit(text)


func get_best_score(level: int) -> int:
	return best_scores.get(level, 0)


func get_best_stars(level: int) -> int:
	return best_stars.get(level, 0)


func get_player_name() -> String:
	return player_name if player_name != "" else "Jugador"


# ---------------------------------------------------------------- Usuarios
static func _profile_key(user_name: String) -> String:
	return user_name.strip_edges().to_lower()


static func clean_name(user_name: String) -> String:
	return user_name.strip_edges().substr(0, 16)


func _new_profile(user_name: String) -> Dictionary:
	var now := Time.get_datetime_string_from_system(false, true)
	return {"name": user_name, "unlocked": 1, "scores": {}, "stars": {}, "created": now, "last_played": now}


## Describe un usuario sin cargarlo: si existe y hasta dónde llegó.
func get_user_summary(user_name: String) -> Dictionary:
	user_name = clean_name(user_name)
	var key := _profile_key(user_name)
	var p: Dictionary = profiles.get(key, {})
	if p.is_empty():
		var prog := Database.get_player_progress(user_name)
		if not prog.get("exists", false):
			return {"exists": false, "name": user_name}
		p = prog
	var stars := 0
	for v in p.stars.values():
		stars += int(v)
	return {"exists": true, "name": p.name, "unlocked": int(p.unlocked), "stars": stars, "levels_won": p.scores.size()}


## Lista de usuarios conocidos (save.cfg + base de datos), los más recientes primero.
func get_all_users() -> Array:
	var names := {}
	for k in profiles:
		names[k] = profiles[k].name
	for n in Database.get_player_names():
		if not names.has(_profile_key(n)):
			names[_profile_key(n)] = n
	var out := []
	for k in names:
		var summary := get_user_summary(names[k])
		summary["last_played"] = profiles[k].get("last_played", "") if profiles.has(k) else ""
		summary["current"] = k == _profile_key(player_name)
		out.append(summary)
	out.sort_custom(func(a, b): return a.last_played > b.last_played if a.last_played != b.last_played else a.name.naturalnocasecmp_to(b.name) < 0)
	return out


## Activa un usuario. Si no existe se crea desde cero; si existe se carga su avance.
## Devuelve {"name", "is_new", "unlocked", "restored_from_db"}.
func switch_user(user_name: String) -> Dictionary:
	user_name = clean_name(user_name)
	if user_name == "":
		return {}
	var key := _profile_key(user_name)
	var is_new := false
	var from_db := false
	if not profiles.has(key):
		var prog := Database.get_player_progress(user_name)
		if prog.get("exists", false):
			# existía en la base de datos (p. ej. se borró save.cfg): se reconstruye su avance
			profiles[key] = _new_profile(prog.name)
			profiles[key].merge({"unlocked": prog.unlocked, "scores": prog.scores, "stars": prog.stars}, true)
			from_db = true
		else:
			profiles[key] = _new_profile(user_name)
			is_new = true
	_apply_profile(key)
	_save()
	GameLog.info("JUGADOR", "Usuario activo: %s (%s) | desbloqueado hasta el nivel %d | %d niveles ganados" % [
		player_name, "nuevo" if is_new else ("recuperado de la base de datos" if from_db else "existente"),
		unlocked_level, best_scores.size()])
	return {"name": player_name, "is_new": is_new, "unlocked": unlocked_level, "restored_from_db": from_db}


func _apply_profile(key: String) -> void:
	var p: Dictionary = profiles[key]
	player_name = p.name
	unlocked_level = clampi(int(p.unlocked), 1, LEVEL_COUNT)
	best_scores = p.scores   # mismo diccionario: lo que se gane se guarda en el perfil
	best_stars = p.stars
	total_score = 0
	p.last_played = Time.get_datetime_string_from_system(false, true)


func set_carrying(item_name: String) -> void:
	carrying_changed.emit(item_name)


# ---------------------------------------------------------------- Guardado
## save.cfg: [profiles] list = [perfil, perfil, ...] y current = usuario activo.
func _save() -> void:
	var key := _profile_key(player_name)
	if profiles.has(key):
		profiles[key].unlocked = unlocked_level
	var cfg := ConfigFile.new()
	cfg.set_value("profiles", "list", profiles.values())
	cfg.set_value("profiles", "current", key)
	cfg.set_value("meta", "save_version", 2)
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if cfg.has_section("profiles"):
		for p in cfg.get_value("profiles", "list", []):
			if p is Dictionary and p.has("name"):
				var prof := _new_profile(p.name)
				prof.merge(p, true)
				profiles[_profile_key(p.name)] = prof
		var current: String = cfg.get_value("profiles", "current", "")
		if profiles.has(current):
			_apply_profile(current)
		return
	# Formato anterior (un solo avance global): se convierte en el perfil del jugador que había
	var old_name := clean_name(str(cfg.get_value("player", "name", "")))
	var old_unlocked := int(cfg.get_value("progress", "unlocked_level", 1))
	if old_name == "" and old_unlocked <= 1:
		return
	if old_name == "":
		old_name = "Jugador"
	var prof := _new_profile(old_name)
	prof.unlocked = clampi(old_unlocked, 1, LEVEL_COUNT)
	for k in range(1, LEVEL_COUNT + 1):
		var sc := int(cfg.get_value("scores", "level_%d" % k, 0))
		var st := int(cfg.get_value("stars", "level_%d" % k, 0))
		if sc > 0:
			prof.scores[k] = sc
		if st > 0:
			prof.stars[k] = st
	profiles[_profile_key(old_name)] = prof
	_apply_profile(_profile_key(old_name))
	_save()
	GameLog.info("JUGADOR", "Avance anterior convertido al usuario '%s'" % old_name)


# ---------------------------------------------------------------- Controles
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [], [JOY_AXIS_LEFT_X, -1.0], [JOY_BUTTON_DPAD_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT], [], [JOY_AXIS_LEFT_X, 1.0], [JOY_BUTTON_DPAD_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP], [], [JOY_AXIS_LEFT_Y, -1.0], [JOY_BUTTON_DPAD_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN], [], [JOY_AXIS_LEFT_Y, 1.0], [JOY_BUTTON_DPAD_DOWN])
	_add_action("interact", [KEY_E, KEY_SPACE], [JOY_BUTTON_A])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _add_action(action: String, keys: Array, buttons: Array = [], axis: Array = [], extra_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons + extra_buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis.size() == 2:
		var jm := InputEventJoypadMotion.new()
		jm.axis = axis[0]
		jm.axis_value = axis[1]
		InputMap.action_add_event(action, jm)
