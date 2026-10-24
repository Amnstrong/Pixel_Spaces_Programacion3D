class_name Player
extends CharacterBody2D
## Jugador top-down: movimiento en 8 direcciones, cargar objetos e interactuar.

@export var speed: float = 72.0
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
@export var eight_directions: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var held_sprite: Sprite2D = $HeldItem
@onready var interaction_area: Area2D = $InteractionArea
@onready var camera: Camera2D = $Camera2D

var carried_item_id: String = ""
var carried_item_name: String = ""
var carried_texture: Texture2D = null
var controls_enabled: bool = true

var _target: Interactable = null
var _hold_progress: float = 0.0
var _action_timer: float = 0.0
var _invulnerable: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _last_prompt: String = ""
var _time: float = 0.0


func _ready() -> void:
	add_to_group("player")
	held_sprite.visible = false
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	_time += delta
	_action_timer = maxf(0.0, _action_timer - delta)
	_invulnerable = maxf(0.0, _invulnerable - delta)
	sprite.visible = _invulnerable <= 0.0 or int(_time * 20.0) % 2 == 0

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if not eight_directions and input != Vector2.ZERO:
			input = Vector2(signf(input.x), 0) if absf(input.x) > absf(input.y) else Vector2(0, signf(input.y))

	if _knockback.length() > 5.0:
		velocity = _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	elif input != Vector2.ZERO:
		velocity = velocity.move_toward(input * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()

	_update_animation(input)
	_update_target()
	_handle_interaction(delta)
	if held_sprite.visible:
		held_sprite.position.y = -22.0 + roundf(sin(_time * 5.0))


func _update_animation(input: Vector2) -> void:
	if input.x != 0.0:
		sprite.flip_h = input.x < 0.0
	var anim := "idle"
	if _action_timer > 0.0:
		anim = "interact"
	elif velocity.length() > 8.0:
		anim = "walk"
	if sprite.animation != anim:
		sprite.play(anim)


# ---------------------------------------------------------------- Interacción
func _update_target() -> void:
	var best: Interactable = null
	var best_dist := INF
	if controls_enabled:
		var origin := global_position + Vector2(0, -6)
		for area in interaction_area.get_overlapping_areas():
			if area is Interactable and area.can_interact(self):
				var d := origin.distance_squared_to(area.global_position)
				if d < best_dist:
					best_dist = d
					best = area
	if best != _target:
		if is_instance_valid(_target):
			_target.set_highlight(false)
			_target.set_hold_progress(0.0)
		_target = best
		_hold_progress = 0.0
		if _target:
			_target.set_highlight(true)
	var prompt := _target.get_prompt(self) if _target else ""
	if prompt != _last_prompt:
		_last_prompt = prompt
		GameManager.notify_prompt(prompt)


func _handle_interaction(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_hold_progress = 0.0
		return
	if _target.hold_time <= 0.0:
		if Input.is_action_just_pressed("interact"):
			_do_interact()
	elif Input.is_action_pressed("interact"):
		_hold_progress += delta
		_action_timer = 0.12
		_target.set_hold_progress(_hold_progress / _target.hold_time)
		if _hold_progress >= _target.hold_time:
			_hold_progress = 0.0
			_do_interact()
	elif _hold_progress > 0.0:
		_hold_progress = 0.0
		_target.set_hold_progress(0.0)


func _do_interact() -> void:
	_action_timer = 0.3
	var t := _target
	t.set_hold_progress(0.0)
	t.interact(self)
	_last_prompt = "<refresh>"  # fuerza refrescar el texto de ayuda


# ---------------------------------------------------------------- Carga
func is_carrying() -> bool:
	return carried_item_id != ""


func pick_up(item_id: String, item_name: String, texture: Texture2D) -> void:
	carried_item_id = item_id
	carried_item_name = item_name
	carried_texture = texture
	held_sprite.texture = texture
	held_sprite.visible = true
	GameManager.set_carrying(item_name)


func drop_item() -> void:
	carried_item_id = ""
	carried_item_name = ""
	carried_texture = null
	held_sprite.visible = false
	GameManager.set_carrying("")


# ---------------------------------------------------------------- Daño
func hit(from_position: Vector2, time_penalty: float, message: String, kind: String = "car") -> void:
	if _invulnerable > 0.0:
		return
	GameManager.record_event("hit_" + kind, message, global_position)
	_invulnerable = 1.4
	var dir := (global_position - from_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	_knockback = dir * 190.0
	GameManager.add_time(-time_penalty)
	GameManager.toast(message, Color(1.0, 0.45, 0.45))
	GameLog.info("GOLPE", "%s | pos (%d, %d) | quedan %.1fs" % [message, global_position.x, global_position.y, GameManager.time_left])
	AudioManager.play_sfx("hit")
	_shake_camera()


func _shake_camera() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(camera, "offset", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.03)
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.03)
