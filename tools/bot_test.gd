extends Node
## Bot que juega cada nivel con física real: A* sobre la rejilla de colisiones, sin esquivar obstáculos móviles.
var levels: Array = []
var skill := 1.0        # velocidad relativa
var wrong_p := 0.0      # probabilidad de llevar un objeto al mueble equivocado
var retries := 2        # reintentos al perder antes de rendirse
var abandon_p := 0.0    # probabilidad de abandonar a mitad
var campaign := false   # juega en orden y se detiene si se rinde
func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		levels.append(int(a))
	if levels.is_empty():
		levels = range(1, 26)
	if OS.has_environment("SKILL"):
		campaign = true
		skill = float(OS.get_environment("SKILL"))
		wrong_p = float(OS.get_environment("WRONG"))
		retries = int(OS.get_environment("RETRIES"))
		abandon_p = float(OS.get_environment("ABANDON"))
		seed(hash(OS.get_environment("BOTNAME")))
	_go.call_deferred()

func _go() -> void:
	var dummy := Node.new(); get_tree().root.add_child(dummy); get_tree().current_scene = dummy
	GameManager.switch_user(OS.get_environment("BOTNAME") if OS.has_environment("BOTNAME") else "Bot")
	var summary := []
	for n in levels:
		var tries := 0
		while true:
			get_tree().change_scene_to_file(GameManager.LEVEL_PATH % n)
			for i in 3: await get_tree().physics_frame
			var r = await play_level(n)
			summary.append(r)
			print(r)
			get_tree().paused = false
			_release_all()
			if not campaign or "GANA" in r: break
			tries += 1
			if tries > retries: break
		if campaign and tries > retries:
			print("SE RINDE en nivel ", n); break
	print("RESUMEN"); for s in summary: print(s)
	get_tree().quit()

var grid: AStarGrid2D
var player: Player

func build_grid(lvl: Node) -> void:
	var ground: TileMapLayer = lvl.get_node("Ground")
	var r := ground.get_used_rect()
	grid = AStarGrid2D.new()
	grid.region = r
	grid.cell_size = Vector2(16, 16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var space := player.get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new(); shape.size = Vector2(10, 7)
	q.shape = shape; q.collision_mask = 1
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			q.transform = Transform2D(0, Vector2(x * 16 + 8, y * 16 + 9))
			if not space.intersect_shape(q, 1).is_empty():
				grid.set_point_solid(Vector2i(x, y), true)

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "interact"]:
		Input.action_release(a)

func steer(dir: Vector2) -> void:
	_release_all()
	if dir.length() < 0.01: return
	dir = dir.normalized()
	if dir.x > 0.05: Input.action_press("move_right", dir.x)
	if dir.x < -0.05: Input.action_press("move_left", -dir.x)
	if dir.y > 0.05: Input.action_press("move_down", dir.y)
	if dir.y < -0.05: Input.action_press("move_up", -dir.y)

func nearest_free(t: Vector2i) -> Vector2i:
	if not grid.is_point_solid(t): return t
	for rad in range(1, 4):
		for dx in range(-rad, rad + 1):
			for dy in range(-rad, rad + 1):
				var c := t + Vector2i(dx, dy)
				if grid.is_in_boundsv(c) and not grid.is_point_solid(c): return c
	return t

func goto(target: Vector2, max_frames: int = 1800) -> bool:
	var frames := 0
	var tgt_tile := nearest_free(Vector2i(floor(target.x / 16), floor(target.y / 16)))
	var my_tile := nearest_free(Vector2i(floor(player.global_position.x / 16), floor(player.global_position.y / 16)))
	var path := grid.get_point_path(my_tile, tgt_tile)
	var wp := 1
	var last_pos := player.global_position
	var still := 0
	while frames < max_frames:
		if not GameManager.level_running: return false
		var aim: Vector2
		if wp < path.size():
			aim = path[wp] + Vector2(8, 9)
			if player.global_position.distance_to(aim) < 5.0:
				wp += 1; continue
		else:
			aim = target
			if player.global_position.distance_to(target) < 6.0:
				_release_all(); return true
		var dir := aim - player.global_position
		if _car_danger(dir):
			_release_all()
		else:
			steer(dir)
		await get_tree().physics_frame
		frames += 1
		if player.global_position.distance_to(last_pos) < 0.3: still += 1
		else: still = 0
		last_pos = player.global_position
		if still > 30:
			var jiggle := Vector2.from_angle(randf() * TAU)
			for j in 12:
				steer(jiggle); await get_tree().physics_frame
			frames += 12
		if still > 30:  # atascado (empujado por un auto, etc.): recalcula
			my_tile = nearest_free(Vector2i(floor(player.global_position.x / 16), floor(player.global_position.y / 16)))
			path = grid.get_point_path(my_tile, tgt_tile); wp = 1; still = 0
	_release_all()
	return false

const ROAD_TILES := [Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 1)]
func _on_road_pos(p: Vector2) -> bool:
	var g: TileMapLayer = get_tree().current_scene.get_node("Ground")
	return g.get_cell_atlas_coords(Vector2i(floor(p.x / 16), floor(p.y / 16))) in ROAD_TILES

## Antes de entrar a la calzada: predice cuándo llegará a cada carril y dónde estará cada auto entonces.
func _car_danger(dir: Vector2) -> bool:
	var p := player.global_position
	var nd := dir.normalized()
	var nxt := p + nd * 18.0
	if _on_road_pos(p) or not _on_road_pos(nxt) or absf(nd.y) < 0.2:
		return false
	var vy := absf(nd.y) * player.speed
	for h in get_tree().current_scene.find_children("*", "Area2D", true, false):
		if not (h is Hazard and h.wrap_around): continue
		var lane_y: float = h.global_position.y - 5.0
		var dy := lane_y - p.y
		if signf(dy) != signf(nd.y) or absf(dy) > 80.0: continue
		# ignora carriles detrás del camellón: ahí se volverá a evaluar
		var blocked := false
		var yy := p.y + signf(dy) * 16.0
		var entered := false
		while absf(yy - p.y) < absf(dy):
			var on := _on_road_pos(Vector2(p.x, yy))
			if on: entered = true
			elif entered: blocked = true
			yy += signf(dy) * 4.0
		if blocked: continue
		var t_reach := absf(dy) / vy
		var tt := t_reach - 0.4
		while tt <= t_reach + 0.4:
			var cx: float = h.global_position.x + h.speed * h.direction * tt
			var px := p.x + nd.x * player.speed * tt
			if absf(cx - px) < 24.0:
				return true
			tt += 0.1
	return false

func press(hold: float = 0.0) -> void:
	_release_all()
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_press("interact")
	var f := int(hold * 60.0) + 2
	for i in f: await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().physics_frame

func play_level(n: int) -> String:
	var lvl := get_tree().current_scene
	player = lvl.get_node("Entities/Player")
	player.speed = 72.0 * skill * randf_range(0.9, 1.05)
	build_grid(lvl)
	var will_abandon := campaign and randf() < abandon_p
	var abandon_at := randf_range(0.2, 0.7)
	var limit := GameManager.time_limit
	var hits := [0, 0]
	var cb := func(t, c):
		if "auto" in t: hits[0] += 1
		elif "Choc" in t or "peat" in t: hits[1] += 1
	GameManager.toast_requested.connect(cb)
	var guard := 0
	while GameManager.level_running and guard < 60:
		guard += 1
		if will_abandon and GameManager.tasks_done >= GameManager.tasks_total * abandon_at:
			if randf() < 0.5:
				get_tree().call_group("pause_menu", "open")
				for i in 40: await get_tree().process_frame
			GameManager.goto_main_menu()
			for i in 30: await get_tree().process_frame
			return "L%02d %-6s ABANDONA" % [n, GameManager.get_level_theme(n)]
		var target: Node2D = null
		var best := INF
		var go_wrong := campaign and player.is_carrying() and randf() < wrong_p and player.carried_item_id != "package"
		if player.is_carrying():
			for t in get_tree().get_nodes_in_group("level_task"):
				if t is DropZone and not t.is_filled and (t.accepts_item == player.carried_item_id) != go_wrong:
					var dd := player.global_position.distance_to(t.global_position)
					if dd < best: best = dd; target = t
		else:
			var cands := []
			for t in get_tree().get_nodes_in_group("level_task"):
				if t is Computer and not t.is_on: cands.append(t)
			for i in lvl.get_node("Entities/Items").get_children():
				if i is PickupItem and not i._taken: cands.append(i)
				if i is PackageDepot and i.packages > 0: cands.append(i)
			for t in cands:
				var dd := player.global_position.distance_to(t.global_position)
				if dd < best: best = dd; target = t
		if target == null and go_wrong:
			continue  # no hay mueble equivocado disponible: vuelve a intentarlo bien
		if target == null: break
		var dest := target.global_position + (Vector2(0, -2) if target is PackageDepot else Vector2.ZERO)
		var ok_go = await goto(dest)
		if OS.has_environment("BOTDBG"): print("  -> ", target.name, " ", dest, " llegó=", ok_go, " pos=", player.global_position, " target_jugador=", player._target)
		if not GameManager.level_running: break
		await press(target.hold_time + 0.15 if target is Computer else 0.0)
		if campaign and randf() < (1.0 - skill) * 0.5:  # duda un momento
			for i in int(randf_range(20, 90)): await get_tree().physics_frame
	if GameManager.level_running:  # el bot no supo terminar: lo registra como abandono, igual que un jugador real
		GameManager.goto_main_menu()
		for i in 30: await get_tree().process_frame
	GameManager.toast_requested.disconnect(cb)
	var won := not GameManager.level_running and GameManager.tasks_done >= GameManager.tasks_total
	var used := limit - GameManager.time_left
	return "L%02d %-6s %s  tiempo usado %5.1fs de %3ds (sobra %4.1f%%)  tareas %d/%d  autos %d peatones %d" % [n, GameManager.get_level_theme(n), "GANA " if won else "PIERDE", used, int(limit), 100.0 * GameManager.time_left / limit, GameManager.tasks_done, GameManager.tasks_total, hits[0], hits[1]]
