extends Node2D
## Mueve lentamente sus hijos (nubes) y los recicla al salir de pantalla.

@export var speed: float = 6.0
@export var wrap_width: float = 360.0


func _process(delta: float) -> void:
	for c in get_children():
		if c is Node2D:
			c.position.x += speed * delta * (0.6 + 0.4 * float(c.get_index() % 3) / 2.0)
			if c.position.x > wrap_width:
				c.position.x = -40.0
