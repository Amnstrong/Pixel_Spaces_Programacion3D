extends Node
## Registro de eventos del juego en archivos de texto (uno por día):
##   user://logs/game_AAAA-MM-DD.log
## Formato: [fecha hora] [NIVEL] [CATEGORÍA] mensaje

enum Severity { DEBUG, INFO, WARN, ERROR }
const LEVEL_NAMES := ["DEBUG", "INFO", "WARN", "ERROR"]
const LOG_DIR := "user://logs"
const MAX_LOG_FILES := 14  ## Se borran los archivos más antiguos

@export var min_level: Severity = Severity.INFO
@export var echo_to_console: bool = true

var log_path: String = ""
var session_id: String = ""
var _file: FileAccess


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	log_path = "%s/game_%s.log" % [LOG_DIR, Time.get_date_string_from_system()]
	if FileAccess.file_exists(log_path):
		_file = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if _file:
			_file.seek_end()
	else:
		_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		push_error("GameLog: no se pudo abrir %s (%s)" % [log_path, error_string(FileAccess.get_open_error())])
	session_id = "%x" % (int(Time.get_unix_time_from_system()) ^ (randi() & 0xffff))
	_rotate_old_files()
	_write("")
	_write("===== Sesión %s =====" % session_id)
	info("APP", "Inicio de %s | Godot %s | %s | idioma %s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string, OS.get_name(), OS.get_locale()])
	_connect_game_signals()


func debug(category: String, message: String) -> void:
	_log(Severity.DEBUG, category, message)


func info(category: String, message: String) -> void:
	_log(Severity.INFO, category, message)


func warn(category: String, message: String) -> void:
	_log(Severity.WARN, category, message)


func error(category: String, message: String) -> void:
	_log(Severity.ERROR, category, message)


func get_log_folder() -> String:
	return ProjectSettings.globalize_path(LOG_DIR)


func _log(level: Severity, category: String, message: String) -> void:
	if level < min_level:
		return
	var line := "[%s] [%-5s] [%s] %s" % [Time.get_datetime_string_from_system(false, true), LEVEL_NAMES[level], category, message]
	_write(line)
	if echo_to_console:
		if level == Severity.ERROR:
			push_error(line)  # aparece también en el panel de Depurador
		else:
			print(line)


func _write(line: String) -> void:
	if _file:
		_file.store_line(line)
		_file.flush()  # que no se pierda nada si el juego se cierra de golpe


func _connect_game_signals() -> void:
	GameManager.level_started.connect(func(data: Dictionary) -> void:
		info("NIVEL", "Inicio nivel %d '%s' | límite %ds | tareas %d | dificultad %.2f" % [
			data.get("number", 0), data.get("title", ""), int(GameManager.time_limit),
			GameManager.tasks_total, data.get("difficulty", 0.0)]))
	GameManager.level_completed.connect(func(r: Dictionary) -> void:
		info("NIVEL", "COMPLETADO nivel %d | puntaje %d (tareas %d + bonus %d) | estrellas %d | sobraron %.1fs | ranking #%s" % [
			r.level, r.score, r.task_points, r.bonus, r.stars, GameManager.time_left, str(r.get("rank", "-"))]))
	GameManager.level_failed.connect(func(reason: String) -> void:
		warn("NIVEL", "FALLIDO nivel %d: %s | tareas %d/%d" % [
			GameManager.current_level, reason, GameManager.tasks_done, GameManager.tasks_total]))


func _rotate_old_files() -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(LOG_DIR):
		if f.begins_with("game_") and f.ends_with(".log"):
			files.append(f)
	files.sort()
	while files.size() > MAX_LOG_FILES:
		DirAccess.remove_absolute("%s/%s" % [LOG_DIR, files.pop_front()])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _file:
			info("APP", "Cierre del juego")
			_file.close()
			_file = null
