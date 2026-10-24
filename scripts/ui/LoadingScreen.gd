extends Control
## Pantalla de carga con ResourceLoader.load_threaded_request():
## carga la siguiente escena en segundo plano y anima la barra sin congelar el juego.

const MIN_DISPLAY_TIME := 0.8
const TIPS := [
	"Consejo: las siluetas brillantes muestran dónde va cada objeto.",
	"Consejo: mantén [E] para encender las computadoras.",
	"Consejo: los autos y peatones te restan segundos.",
	"Consejo: el tiempo que te sobre suma puntos extra.",
	"Consejo: pulsa ESC para pausar el juego.",
	"Consejo: desde el nivel 10, equivocarte de mueble resta segundos.",
	"Consejo: termina rápido para ganar 3 estrellas.",
]

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var loading_label: Label = %LoadingLabel
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel
@onready var runner: AnimatedSprite2D = %Runner

var _target: String = ""
var _elapsed: float = 0.0
var _shown: float = 0.0
var _progress: Array = []
var _done: bool = false
var _failed: bool = false


func _ready() -> void:
	get_tree().paused = false
	_target = GameManager.next_scene_path
	if _target == "" or not ResourceLoader.exists(_target):
		_target = GameManager.MAIN_MENU
	tip_label.text = TIPS.pick_random()
	runner.play("walk")
	# use_sub_threads = false: con true el TileSet llega sin texturas en el renderer Compatibility.
	var err := ResourceLoader.load_threaded_request(_target, "PackedScene", false)
	if err != OK:
		_fail_load()


func _process(delta: float) -> void:
	_elapsed += delta
	loading_label.text = "Cargando" + ".".repeat(int(_elapsed * 3.0) % 4)
	if _failed or _done:
		return

	var status := ResourceLoader.load_threaded_get_status(_target, _progress)
	var real := 0.0
	if _progress.size() > 0:
		real = float(_progress[0])
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			real = 1.0
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_fail_load()
			return

	# La barra avanza de forma suave y nunca más rápido que el tiempo mínimo.
	var time_cap := clampf(_elapsed / MIN_DISPLAY_TIME, 0.0, 1.0)
	_shown = move_toward(_shown, minf(real, time_cap), delta * 2.5)
	progress_bar.value = _shown * 100.0
	percent_label.text = "%d%%" % int(_shown * 100.0)
	var bar_rect := progress_bar.get_global_rect()
	runner.global_position = Vector2(lerpf(bar_rect.position.x + 4.0, bar_rect.end.x - 4.0, _shown), bar_rect.position.y - 1.0)

	if status == ResourceLoader.THREAD_LOAD_LOADED and _shown >= 0.999:
		_done = true
		var packed := ResourceLoader.load_threaded_get(_target) as PackedScene
		get_tree().change_scene_to_packed(packed)


func _fail_load() -> void:
	_failed = true
	loading_label.text = "Error al cargar"
	push_error("No se pudo cargar: %s" % _target)
	await get_tree().create_timer(1.5).timeout
	if _target != GameManager.MAIN_MENU:
		GameManager.goto_main_menu()
