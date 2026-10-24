extends Node
## Ranking persistente en SQLite usando el addon godot-sqlite (res://addons/godot-sqlite).
## Archivo: user://ranking.db
##
## Tablas:
##   players(id, name, created_at)
##   scores(id, player_id, level, score, stars, time_left, time_limit, created_at)   <- solo victorias (ranking)
##   attempts(...)  <- TODAS las partidas: victoria, derrota o abandono, con métricas
##   events(...)    <- eventos de cada partida con tiempo y posición (golpes, errores, tareas...)
##   paths(attempt_id, interval, points)  <- recorrido del jugador: [x0, y0, x1, y1, ...] cada `interval` s
##   meta(key, value)
##
## En modo desarrollo (OS.is_debug_build) también mantiene el dashboard en user://dashboard/:
##   dashboard.html (copiado de res://tools/dashboard) + dashboard_data.js (se reescribe tras cada partida)

const DB_PATH := "user://ranking.db"
const SCHEMA_VERSION := 3
const DASHBOARD_DIR := "user://dashboard"
const DASHBOARD_SRC := "res://tools/dashboard/dashboard.html"

var available: bool = false
var _db: Object = null  # SQLite (se crea con ClassDB para no romper el juego si falta el addon)


func _ready() -> void:
	if not ClassDB.class_exists("SQLite"):
		GameLog.error("DB", "La extensión godot-sqlite no está cargada: el ranking queda desactivado")
		return
	_db = ClassDB.instantiate("SQLite")
	_db.path = DB_PATH
	_db.verbosity_level = 0  # QUIET: los errores los registramos nosotros
	_db.foreign_keys = true
	if not _db.open_db():
		GameLog.error("DB", "No se pudo abrir %s: %s" % [DB_PATH, _db.error_message])
		return
	available = true
	_create_schema()
	GameLog.info("DB", "Base de datos lista: %s (%d jugadores, %d partidas ganadas)" % [
		ProjectSettings.globalize_path(DB_PATH), _count("players"), _count("scores")])
	if dashboard_enabled():
		_install_dashboard()
		export_dashboard_data.call_deferred()


func _create_schema() -> void:
	_exec("""CREATE TABLE IF NOT EXISTS players (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL UNIQUE COLLATE NOCASE,
		created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')))""")
	_exec("""CREATE TABLE IF NOT EXISTS scores (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		player_id INTEGER NOT NULL REFERENCES players(id),
		level INTEGER NOT NULL,
		score INTEGER NOT NULL,
		stars INTEGER NOT NULL,
		time_left REAL NOT NULL,
		time_limit REAL NOT NULL,
		created_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')))""")
	_exec("CREATE INDEX IF NOT EXISTS idx_scores_level ON scores(level, score DESC)")
	_exec("""CREATE TABLE IF NOT EXISTS attempts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		player_id INTEGER NOT NULL REFERENCES players(id),
		session_id TEXT, game_version TEXT,
		level INTEGER NOT NULL, level_name TEXT, theme TEXT, difficulty REAL,
		result TEXT NOT NULL CHECK (result IN ('win', 'fail', 'abandon')),
		score INTEGER NOT NULL DEFAULT 0, stars INTEGER NOT NULL DEFAULT 0,
		tasks_done INTEGER NOT NULL, tasks_total INTEGER NOT NULL,
		time_limit REAL NOT NULL, time_used REAL NOT NULL, time_left REAL NOT NULL,
		hits_car INTEGER NOT NULL DEFAULT 0, hits_person INTEGER NOT NULL DEFAULT 0,
		wrong_items INTEGER NOT NULL DEFAULT 0, pauses INTEGER NOT NULL DEFAULT 0,
		started_at TEXT NOT NULL, ended_at TEXT NOT NULL DEFAULT (datetime('now', 'localtime')))""")
	_exec("""CREATE TABLE IF NOT EXISTS events (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		attempt_id INTEGER NOT NULL REFERENCES attempts(id) ON DELETE CASCADE,
		t REAL NOT NULL, type TEXT NOT NULL, detail TEXT, x REAL, y REAL)""")
	_exec("CREATE INDEX IF NOT EXISTS idx_attempts_level ON attempts(level, result)")
	_exec("CREATE INDEX IF NOT EXISTS idx_events_attempt ON events(attempt_id)")
	_exec("""CREATE TABLE IF NOT EXISTS paths (
		attempt_id INTEGER PRIMARY KEY REFERENCES attempts(id) ON DELETE CASCADE,
		interval REAL NOT NULL, points TEXT NOT NULL)""")
	_exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")
	_exec("INSERT OR REPLACE INTO meta (key, value) VALUES ('schema_version', ?)", [str(SCHEMA_VERSION)])


# ---------------------------------------------------------------- API
## Guarda una victoria y devuelve {"rank": posición en el ranking del nivel, "players": total de jugadores del nivel}.
func save_score(player_name: String, level: int, score: int, stars: int, time_left: float, time_limit: float) -> Dictionary:
	if not available:
		return {}
	var pid := _get_or_create_player(player_name)
	if pid < 0:
		return {}
	if not _exec("INSERT INTO scores (player_id, level, score, stars, time_left, time_limit) VALUES (?, ?, ?, ?, ?, ?)",
			[pid, level, score, stars, time_left, time_limit]):
		return {}
	var rank := get_level_rank(level, score)
	var players := _scalar("SELECT COUNT(DISTINCT player_id) AS n FROM scores WHERE level = ?", [level])
	GameLog.info("DB", "Puntaje guardado: %s | nivel %d | %d pts | %d estrellas | puesto #%d de %d" % [player_name, level, score, stars, rank, players])
	return {"rank": rank, "players": players}


## Guarda una partida completa (gane, pierda o abandone) y sus eventos en una sola transacción.
func save_attempt(a: Dictionary, events: Array, path: PackedInt32Array = PackedInt32Array(), path_interval: float = 0.2) -> int:
	if not available:
		return -1
	var pid := _get_or_create_player(a.player)
	if pid < 0:
		return -1
	_exec("BEGIN TRANSACTION")
	var ok := _exec("""INSERT INTO attempts (player_id, session_id, game_version, level, level_name, theme, difficulty,
		result, score, stars, tasks_done, tasks_total, time_limit, time_used, time_left,
		hits_car, hits_person, wrong_items, pauses, started_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
		[pid, a.session_id, a.version, a.level, a.level_name, a.theme, a.difficulty,
		a.result, a.score, a.stars, a.tasks_done, a.tasks_total, a.time_limit, a.time_used, a.time_left,
		a.hits_car, a.hits_person, a.wrong_items, a.pauses, a.started_at])
	if not ok:
		_exec("ROLLBACK")
		return -1
	var aid: int = _db.last_insert_rowid
	for e in events:
		_exec("INSERT INTO events (attempt_id, t, type, detail, x, y) VALUES (?, ?, ?, ?, ?, ?)",
			[aid, e.t, e.type, e.detail, e.x, e.y])
	if path.size() >= 2:
		_exec("INSERT INTO paths (attempt_id, interval, points) VALUES (?, ?, ?)",
			[aid, path_interval, JSON.stringify(Array(path))])
	_exec("COMMIT")
	GameLog.info("DB", "Partida #%d guardada: %s | nivel %d | %s | %d eventos | %d puntos de recorrido" % [aid, a.player, a.level, a.result, events.size(), path.size() / 2])
	if dashboard_enabled():
		export_dashboard_data.call_deferred()
	return aid


## Avance de un jugador reconstruido desde sus victorias: {"exists", "name", "unlocked", "scores", "stars"}.
func get_player_progress(player_name: String) -> Dictionary:
	if not available:
		return {"exists": false}
	var rows := _select("SELECT id, name FROM players WHERE name = ?", [player_name])
	if rows.is_empty():
		return {"exists": false}
	var scores := {}
	var stars := {}
	var max_won := 0
	for r in _select("SELECT level, MAX(score) AS score, MAX(stars) AS stars FROM scores WHERE player_id = ? GROUP BY level", [rows[0]["id"]]):
		scores[int(r["level"])] = int(r["score"])
		stars[int(r["level"])] = int(r["stars"])
		max_won = maxi(max_won, int(r["level"]))
	return {"exists": true, "name": str(rows[0]["name"]), "unlocked": clampi(max_won + 1, 1, GameManager.LEVEL_COUNT),
		"scores": scores, "stars": stars}


func get_player_names() -> Array:
	var out := []
	for r in _select("SELECT name FROM players ORDER BY name"):
		out.append(str(r["name"]))
	return out


# ---------------------------------------------------------------- Dashboard de desarrollo
## Solo en modo desarrollo (ejecutando desde el editor o una exportación debug).
func dashboard_enabled() -> bool:
	return available and OS.is_debug_build()


func get_dashboard_path() -> String:
	return ProjectSettings.globalize_path(DASHBOARD_DIR + "/dashboard.html")


## Copia el dashboard del proyecto a la carpeta de datos si cambió.
func _install_dashboard() -> void:
	if not FileAccess.file_exists(DASHBOARD_SRC):
		return
	DirAccess.make_dir_recursive_absolute(DASHBOARD_DIR)
	var dst := DASHBOARD_DIR + "/dashboard.html"
	if FileAccess.file_exists(dst) and FileAccess.get_md5(dst) == FileAccess.get_md5(DASHBOARD_SRC):
		return
	var err := DirAccess.copy_absolute(DASHBOARD_SRC, dst)
	if err == OK:
		GameLog.info("DASHBOARD", "Dashboard instalado en %s" % get_dashboard_path())
	else:
		GameLog.error("DASHBOARD", "No se pudo copiar el dashboard: %s" % error_string(err))


## Escribe todos los datos en dashboard_data.js; el dashboard abierto lo vuelve a leer cada pocos segundos.
func export_dashboard_data() -> void:
	if not dashboard_enabled():
		return
	var t0 := Time.get_ticks_msec()
	var data := {
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"db_path": ProjectSettings.globalize_path(DB_PATH),
		"players": _table("SELECT name, created_at FROM players ORDER BY name"),
		"attempts": _table("SELECT a.*, p.name AS player FROM attempts a JOIN players p ON p.id = a.player_id ORDER BY a.started_at, a.id"),
		"events": _table("SELECT attempt_id, t, type, detail, x, y FROM events ORDER BY attempt_id, t"),
		"paths": "__PATHS__",
	}
	# los recorridos ya están guardados como JSON: se insertan tal cual para no volver a convertirlos
	var parts := PackedStringArray()
	for r in _select("SELECT attempt_id, interval, points FROM paths"):
		parts.append('"%d":{"i":%s,"p":%s}' % [int(r["attempt_id"]), str(r["interval"]), r["points"]])
	var text := JSON.stringify(data).replace('"__PATHS__"', "{" + ",".join(parts) + "}")
	DirAccess.make_dir_recursive_absolute(DASHBOARD_DIR)
	var f := FileAccess.open(DASHBOARD_DIR + "/dashboard_data.js", FileAccess.WRITE)
	if f == null:
		GameLog.error("DASHBOARD", "No se pudo escribir dashboard_data.js: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string("window.PSM_DATA = %s;\nif (window.PSM_onData) window.PSM_onData();\n" % text)
	f.close()
	GameLog.debug("DASHBOARD", "Datos exportados en %d ms (%d KB)" % [Time.get_ticks_msec() - t0, text.length() / 1024])


func open_dashboard() -> void:
	_install_dashboard()
	export_dashboard_data()
	GameLog.info("DASHBOARD", "Abriendo %s" % get_dashboard_path())
	OS.shell_open(get_dashboard_path())


## SELECT -> {"cols": [...], "rows": [[...], ...]} (más compacto que una lista de diccionarios).
func _table(sql: String) -> Dictionary:
	var rows := _select(sql)
	if rows.is_empty():
		return {"cols": [], "rows": []}
	var cols: Array = rows[0].keys()
	var out := []
	for r in rows:
		var vals := []
		for c in cols:
			vals.append(r[c])
		out.append(vals)
	return {"cols": cols, "rows": out}


## Mejor puntaje de cada jugador en un nivel (top N).
func get_level_ranking(level: int, limit: int = 8) -> Array:
	return _select("""SELECT p.name AS name, MAX(s.score) AS score, s.stars AS stars, s.created_at AS date
		FROM scores s JOIN players p ON p.id = s.player_id
		WHERE s.level = ?
		GROUP BY s.player_id
		ORDER BY score DESC, date ASC
		LIMIT ?""", [level, limit])


## Ranking general: suma del mejor puntaje de cada nivel por jugador.
func get_global_ranking(limit: int = 8) -> Array:
	return _select("""SELECT p.name AS name, SUM(b.best) AS score, COUNT(*) AS levels, SUM(b.stars) AS stars
		FROM (SELECT player_id, level, MAX(score) AS best, MAX(stars) AS stars
			FROM scores GROUP BY player_id, level) b
		JOIN players p ON p.id = b.player_id
		GROUP BY b.player_id
		ORDER BY score DESC
		LIMIT ?""", [limit])


## Posición que ocupa un puntaje dentro del ranking de un nivel (1 = primero).
func get_level_rank(level: int, score: int) -> int:
	return _scalar("""SELECT COUNT(*) AS n FROM
		(SELECT MAX(score) AS best FROM scores WHERE level = ? GROUP BY player_id)
		WHERE best > ?""", [level, score]) + 1


func get_db_folder() -> String:
	return ProjectSettings.globalize_path("user://")


# ---------------------------------------------------------------- internos
func _get_or_create_player(player_name: String) -> int:
	_exec("INSERT OR IGNORE INTO players (name) VALUES (?)", [player_name])
	var rows := _select("SELECT id FROM players WHERE name = ?", [player_name])
	return int(rows[0]["id"]) if rows.size() > 0 else -1


func _exec(sql: String, bindings: Array = []) -> bool:
	if not available:
		return false
	var ok: bool = _db.query_with_bindings(sql, bindings) if bindings.size() > 0 else _db.query(sql)
	if not ok:
		GameLog.error("DB", "%s | SQL: %s" % [_db.error_message, sql.strip_edges().replace("\n", " ").replace("\t", "")])
	return ok


## Ejecuta un SELECT y devuelve filas con claves String (el addon devuelve StringName).
func _select(sql: String, bindings: Array = []) -> Array:
	if not _exec(sql, bindings):
		return []
	var rows := []
	for r in _db.query_result:
		var row := {}
		for k in r:
			row[str(k)] = r[k]
		rows.append(row)
	return rows


func _scalar(sql: String, bindings: Array = []) -> int:
	var rows := _select(sql, bindings)
	return int(rows[0]["n"]) if rows.size() > 0 and rows[0].has("n") else 0


func _count(table: String) -> int:
	return _scalar("SELECT COUNT(*) AS n FROM %s" % table)


func _exit_tree() -> void:
	if available and _db:
		_db.close_db()
		available = false
