extends Node
## Autoload de audio: pool de AudioStreamPlayer para efectos + reproductor de música en bucle.

const SFX := {
	"click": preload("res://assets/audio/sfx/click.wav"),
	"hover": preload("res://assets/audio/sfx/hover.wav"),
	"pickup": preload("res://assets/audio/sfx/pickup.wav"),
	"place": preload("res://assets/audio/sfx/place.wav"),
	"wrong": preload("res://assets/audio/sfx/wrong.wav"),
	"task": preload("res://assets/audio/sfx/task.wav"),
	"boot": preload("res://assets/audio/sfx/boot.wav"),
	"hit": preload("res://assets/audio/sfx/hit.wav"),
	"level_complete": preload("res://assets/audio/sfx/level_complete.wav"),
	"fail": preload("res://assets/audio/sfx/fail.wav"),
	"tick": preload("res://assets/audio/sfx/tick.wav"),
}
const MUSIC := {
	"menu": preload("res://assets/audio/music/menu_theme.wav"),
	"level": preload("res://assets/audio/music/level_theme.wav"),
}

@export var sfx_volume_db: float = -4.0
@export var music_volume_db: float = -10.0

var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = music_volume_db
	add_child(_music_player)
	_music_player.finished.connect(_on_music_finished)


func play_sfx(sfx_name: String, pitch_variation: float = 0.0) -> void:
	if not SFX.has(sfx_name):
		return
	var player: AudioStreamPlayer = _sfx_players[0]
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	player.stream = SFX[sfx_name]
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()


func play_music(music_name: String) -> void:
	if not MUSIC.has(music_name):
		return
	if _current_music == music_name and _music_player.playing:
		return
	_current_music = music_name
	_music_player.stream = MUSIC[music_name]
	_music_player.play()


func stop_music() -> void:
	_current_music = ""
	_music_player.stop()


func _on_music_finished() -> void:
	if _current_music != "":
		_music_player.play()
