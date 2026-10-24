class_name Hazard
extends Area2D
## Obstáculo móvil (auto o peatón). Va y viene / cruza la pantalla y penaliza al chocar.

@export var speed: float = 60.0
@export var direction: int = 1
@export var min_x: float = -40.0
@export var max_x: float = 1060.0
@export var wrap_around: bool = true  ## true: reaparece por el otro lado (autos). false: da la vuelta (peatones)
@export var time_penalty: float = 5.0
@export var hit_message: String = "¡Cuidado! -5s"
@export var pause_at_ends: float = 0.8

@onready var visual: Node2D = $Visual

var _wait: float = 0.0


func _ready() -> void:
	collision_layer = 8  # capa 4: hazards
	collision_mask = 2   # detecta al jugador
	monitoring = true
	_apply_facing()


func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_set_anim("walk")
	else:
		position.x += speed * direction * delta
		if wrap_around:
			if direction > 0 and position.x > max_x:
				position.x = min_x
			elif direction < 0 and position.x < min_x:
				position.x = max_x
		elif (direction > 0 and position.x >= max_x) or (direction < 0 and position.x <= min_x):
			position.x = clampf(position.x, min_x, max_x)
			direction *= -1
			_apply_facing()
			_wait = pause_at_ends
			_set_anim("idle")
	for body in get_overlapping_bodies():
		if body is Player:
			body.hit(global_position + Vector2(0, -4), time_penalty, hit_message, "car" if wrap_around else "person")


func _apply_facing() -> void:
	if visual is Sprite2D:
		(visual as Sprite2D).flip_h = direction < 0
	elif visual is AnimatedSprite2D:
		(visual as AnimatedSprite2D).flip_h = direction < 0


func _set_anim(anim: String) -> void:
	if visual is AnimatedSprite2D and (visual as AnimatedSprite2D).sprite_frames.has_animation(anim):
		(visual as AnimatedSprite2D).play(anim)
