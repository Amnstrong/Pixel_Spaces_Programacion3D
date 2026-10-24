extends Node
# Generador de los niveles 4-25 + ajustes de MainMenu y HUD.
# Ejecutar: godot --headless --path . res://tools/BuildLevels.tscn

const S := "res://assets/sprites/"
const YELLOW := Color(1.0, 0.83, 0.38)
const CREAM := Color(0.96, 0.93, 0.85)
const DARK := Color(0.09, 0.07, 0.12)
const SPEED := 72.0  # velocidad del jugador (px/s)

var tileset: TileSet
var male_frames: SpriteFrames
var female_frames: SpriteFrames
var font_title: FontFile
var _uniques: Array = []
var _pickup_scene: PackedScene
var _drop_scene: PackedScene
var report: Array = []

# ------------------------------------------------ estaciones de la habitación
# [zona, id, nombre objeto, sprite objeto, slot_y, [[mueble, dx, colisiona]], [[decor pared, dx, dy_desde_base]], slot_dx]
const ROOM_STATIONS := [
	["el librero", "books", "Libros", "objects/living_room/books_outside_5.png", -14, [["furniture/living_room/bookshelf_1.png", 0, true]], [], 0],
	["el armario", "backpack", "Mochila", "objects/bedroom/backpack_red.png", -23, [["furniture/bedroom/cabinet_1.png", 0, true]], [], 0],
	["la repisa", "trophy", "Trofeo", "objects/bedroom/trophy.png", -27, [["furniture/bedroom/drawer_medium_1_a.png", 0, true]], [["furniture/living_room/shelf_medium.png", 0, -25]], 0],
	["el fregadero", "pitcher", "Jarra", "objects/kitchen/glass_pitcher_water.png", -10, [["furniture/kitchen/sink.png", 0, true]], [["objects/kitchen/hanging_cooking_pans.png", 0, -28]], 0],
	["el toallero", "towel", "Toalla", "objects/bathroom/bath_towel_long_blue.png", -13, [["furniture/bathroom/sink_bathroom_2.png", 0, true]], [["furniture/bathroom/towel_rail.png", 0, -24]], 0],
	["el refri", "notes", "Notas", "objects/kitchen/refrigerator_sticky_notes_1.png", -6, [["furniture/kitchen/refrigerator_large_white.png", 0, true]], [], 2],
	["la estufa", "pan", "Sartén", "objects/kitchen/cooking_pan.png", -10, [["objects/kitchen/oven.png", 0, true]], [], 0],
	["el estante", "encyclopedia", "Enciclopedia", "objects/living_room/books_inside_1.png", -12, [["furniture/living_room/bookshelf_small.png", 0, true]], [], 0],
	["el buró", "lamp", "Lámpara", "furniture/bedroom/lamp_bedroom_3.png", -13, [["furniture/bedroom/drawer_medium_1_c.png", 0, true]], [], 0],
	["la mesita", "vase", "Florero", "objects/living_room/vase_red.png", -7, [["furniture/living_room/table_medium.png", 0, true]], [], 0],
	["la pared", "poster", "Póster", "objects/bedroom/poster_1.png", -18, [], [], 0],
	["la barra", "blender", "Licuadora", "objects/kitchen/blender_orange.png", -7, [["furniture/kitchen/countertop.png", 0, true]], [], 0],
]
const ROOM_FLOOR := ["furniture/bedroom/bed_red.png", "furniture/bedroom/bed_yellow.png", "furniture/living_room/couch_large_blue.png",
	"furniture/living_room/couch_large_red.png", "furniture/living_room/coffee_table_1.png", "furniture/bathroom/bathtub.png",
	"furniture/living_room/couch_small_green.png", "furniture/bedroom/bunkbed_bottom_red.png", "furniture/living_room/couch_large_2_green.png"]
const WALL_DECOR := ["furniture/living_room/window_square.png", "furniture/living_room/window_circle.png", "objects/bedroom/clock_1_red.png",
	"objects/bedroom/calendar_2.png", "objects/bedroom/clock_1_blue.png", "furniture/bathroom/mirror.png"]
const DESK_ITEMS := [["box", "Caja de archivos", "objects/bedroom/box_blue_large.png"], ["folders", "Carpetas", "objects/living_room/books_outside_1.png"],
	["clock", "Reloj", "objects/bedroom/alarm_clock_red.png"], ["cup", "Taza", "objects/kitchen/blender_cup_red.png"],
	["plant", "Planta", "objects/living_room/flora_aster.png"], ["books", "Libros", "objects/living_room/books_inside_1.png"]]
const BUILDINGS := ["backgrounds/house_large_red.png", "backgrounds/house_small_beige.png", "backgrounds/building_office_gray.png", "backgrounds/building_office_green.png"]
const BUILDING_NAMES := ["la casa roja", "la casa beige", "la oficina gris", "la oficina verde"]


func _ready() -> void:
	tileset = load("res://assets/tiles/pixel_spaces_tileset.tres")
	male_frames = load("res://assets/sprites/characters/male_frames.tres")
	female_frames = load("res://assets/sprites/characters/female_frames.tres")
	font_title = load("res://assets/fonts/press-start-2p.woff2")
	_pickup_scene = load("res://scenes/objects/PickupItem.tscn")
	_drop_scene = load("res://scenes/objects/DropZone.tscn")
	patch_hud()
	patch_main_menu()
	for n in range(4, GameManager.LEVEL_COUNT + 1):
		var d := float(n - 1) / float(GameManager.LEVEL_COUNT - 1)
		var ok := false
		for attempt in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = n * 7919 + attempt * 104729
			var root: Node2D
			match GameManager.get_level_theme(n):
				"room": root = gen_room(n, d, rng)
				"office": root = gen_office(n, d, rng)
				"street": root = gen_street(n, d, rng)
			if root != null:
				save_scene(root, GameManager.LEVEL_PATH % n)
				ok = true
				break
		assert(ok, "No se pudo generar el nivel %d" % n)
	for r in report:
		print(r)
	print("BUILD DONE")
	get_tree().quit()

# =============================================================== helpers
func tex(p: String) -> Texture2D:
	var t := load(S + p) as Texture2D
	assert(t != null, "Missing texture " + p)
	return t

func u(n: Node) -> Node:
	_uniques.append(n)
	return n

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			_own(c, root)

func save_scene(root: Node, path: String) -> void:
	_own(root, root)
	for n in _uniques:
		n.unique_name_in_owner = true
	_uniques.clear()
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK)
	assert(ResourceSaver.save(ps, path) == OK, "save failed " + path)
	root.free()

func add(parent: Node, child: Node, nm: String = "") -> Node:
	if nm != "":
		child.name = nm
	parent.add_child(child, true)
	return child

func full_rect(c: Control) -> Control:
	c.anchor_left = 0; c.anchor_top = 0; c.anchor_right = 1; c.anchor_bottom = 1
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
	return c

func label(text: String, size: int = 8, color: Color = CREAM, title_font: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		l.add_theme_font_override("font", font_title)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.05, 0.03, 0.08, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func sprite_bottom(t: Texture2D, pos: Vector2, nm: String = "") -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.offset = Vector2(-floor(t.get_width() / 2.0), -t.get_height())
	s.position = pos
	if nm != "":
		s.name = nm
	return s

func sprite_center(t: Texture2D, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.position = pos.round()
	return s

func rect_shape(size: Vector2, pos: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = pos
	return cs

func furniture(parent: Node, path: String, pos: Vector2, collide: bool = true, base_h: int = 6) -> StaticBody2D:
	var t := tex(path)
	var body := StaticBody2D.new()
	body.name = path.get_file().get_basename().to_pascal_case()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body, true)
	body.add_child(sprite_bottom(t, Vector2.ZERO, "Sprite2D"))
	if collide:
		var h := mini(t.get_height(), base_h)
		body.add_child(rect_shape(Vector2(t.get_width() - 2, h), Vector2(0, -h / 2.0)))
	return body

func decor(parent: Node, path: String, pos: Vector2, bottom: bool = false) -> Sprite2D:
	var t := tex(path)
	var s := sprite_bottom(t, pos) if bottom else sprite_center(t, pos)
	s.name = path.get_file().get_basename().to_pascal_case()
	parent.add_child(s, true)
	return s

func stylebox(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.anti_aliasing = false
	sb.content_margin_left = 8; sb.content_margin_top = 6; sb.content_margin_right = 8; sb.content_margin_bottom = 6
	return sb

func tile_for(ch: String, x: int, y: int) -> Vector2i:
	var h := (x * 73856093) ^ (y * 19349663)
	match ch:
		"#": return Vector2i(0, 1)
		"w": return Vector2i(1, 1)
		"b": return Vector2i(2, 1)
		"o": return Vector2i(3, 1)
		"p": return Vector2i(4, 1)
		".": return Vector2i(1, 0) if (y % 2 == 1) else Vector2i(0, 0)
		"c": return Vector2i(3, 0) if abs(h) % 5 == 0 else Vector2i(2, 0)
		"t": return Vector2i(4, 0)
		"a": return Vector2i(5, 0)
		"-": return Vector2i(6, 0)
		"s": return Vector2i(7, 0)
		"g": return Vector2i(9, 0) if abs(h) % 7 == 0 else Vector2i(8, 0)
		"z": return Vector2i(5, 1)
		"k": return Vector2i(6, 1)
		"r": return Vector2i(8, 1)
		"R": return Vector2i(9, 1)
	return Vector2i(-1, -1)

func make_ground(rows: Array) -> TileMapLayer:
	var tm := TileMapLayer.new()
	tm.name = "Ground"
	tm.tile_set = tileset
	tm.z_index = -10
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := tile_for(row[x], x, y)
			if c.x >= 0:
				tm.set_cell(Vector2i(x, y), 0, c)
	return tm

func fill_rows(w: int, h: int, f: Callable) -> Array:
	var rows := []
	for y in h:
		var s := ""
		for x in w:
			s += f.call(x, y)
		rows.append(s)
	return rows

func level_root(n: int, objective: String, d: float, rows: Array) -> Node2D:
	var root := Node2D.new()
	root.name = "Level%d" % n
	root.set_script(load("res://scripts/levels/Level.gd"))
	root.set("level_number", n)
	root.set("level_title", GameManager.get_level_name(n))
	root.set("objective", objective)
	root.set("difficulty", snappedf(d, 0.01))
	root.set("wrong_item_penalty", wrong_penalty(n))
	add(root, make_ground(rows))
	var dec := Node2D.new(); dec.z_index = -5
	add(root, dec, "Decor")
	var ent := Node2D.new(); ent.y_sort_enabled = true
	add(root, ent, "Entities")
	for g in ["Furniture", "Items", "Tasks", "Hazards"]:
		var nd := Node2D.new(); nd.y_sort_enabled = true
		add(ent, nd, g)
	add(root, load("res://scenes/ui/HUD.tscn").instantiate(), "HUD")
	add(root, load("res://scenes/ui/PauseMenu.tscn").instantiate(), "PauseMenu")
	return root

func wrong_penalty(n: int) -> float:
	if n >= 19: return 3.0
	if n >= 10: return 2.0
	return 0.0

func add_player(root: Node2D, pos: Vector2) -> void:
	var p: Node2D = load("res://scenes/player/Player.tscn").instantiate()
	p.position = pos
	add(root.get_node("Entities"), p, "Player")

func pickup(root: Node2D, id: String, nm: String, path: String, pos: Vector2, idx: int) -> void:
	var it: Node2D = _pickup_scene.instantiate()
	var t := tex(path)
	it.set("item_id", id)
	it.set("display_name", nm)
	it.set("texture", t)
	(it.get_node("Sprite2D") as Sprite2D).texture = t
	it.position = pos
	add(root.get_node("Entities/Items"), it, "Pickup%d_%s" % [idx, id.to_pascal_case()])

func dropzone(root: Node2D, id: String, zone: String, path: String, pos: Vector2, slot_pos: Vector2, idx: int, marker: bool = false) -> Node2D:
	var dz: Node2D = _drop_scene.instantiate()
	var t := tex(path)
	dz.set("accepts_item", id)
	dz.set("zone_name", zone)
	dz.set("ghost_texture", t)
	var slot := dz.get_node("Slot") as Sprite2D
	slot.texture = t
	slot.offset = Vector2(-floor(t.get_width() / 2.0), -t.get_height())
	slot.position = slot_pos
	dz.position = pos
	if marker:
		var m := sprite_center(load("res://assets/ui/arrow.png"), Vector2(0, slot_pos.y - t.get_height() - 8))
		m.set_meta("base_y", m.position.y)
		m.z_index = 5
		add(dz, m, "Marker")
	add(root.get_node("Entities/Tasks"), dz, "Drop%d" % idx)
	return dz

func walker(root: Node2D, pos: Vector2, min_x: float, max_x: float, speed: float, male: bool, penalty: float, msg: String, tint: Color, idx: int) -> void:
	var ped: Node2D = load("res://scenes/objects/Pedestrian.tscn").instantiate()
	ped.position = pos
	ped.set("min_x", min_x); ped.set("max_x", max_x); ped.set("speed", speed)
	ped.set("time_penalty", penalty); ped.set("hit_message", msg)
	ped.set("direction", 1 if idx % 2 == 0 else -1)
	var v := ped.get_node("Visual") as AnimatedSprite2D
	if male:
		v.sprite_frames = male_frames
	v.modulate = tint
	add(root.get_node("Entities/Hazards"), ped, "Walker%d" % idx)

# ------------------------------------------------ rejilla de navegación (A*)
func make_grid(w: int, h: int) -> AStarGrid2D:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, w, h)
	g.cell_size = Vector2(16, 16)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	return g

func block_span(g: AStarGrid2D, x_px: float, w_px: float, row: int) -> void:
	var a := int(floor((x_px - w_px / 2.0) / 16.0))
	var b := int(floor((x_px + w_px / 2.0 - 1.0) / 16.0))
	for tx in range(a, b + 1):
		if g.is_in_boundsv(Vector2i(tx, row)):
			g.set_point_solid(Vector2i(tx, row), true)

func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / 16.0)), int(floor(p.y / 16.0)))

func path_len(g: AStarGrid2D, a: Vector2, b: Vector2) -> float:
	var pts := g.get_point_path(tile_of(a), tile_of(b))
	if pts.is_empty():
		return -1.0
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total

## Recorrido "ladrón": siempre ve al objeto más cercano y luego a su destino.
func tour_items(g: AStarGrid2D, start: Vector2, pairs: Array) -> float:
	var pos := start
	var left := pairs.duplicate()
	var total := 0.0
	while not left.is_empty():
		var best := -1
		var best_d := INF
		for i in left.size():
			var dd := path_len(g, pos, left[i][0])
			if dd >= 0.0 and dd < best_d:
				best_d = dd; best = i
		if best < 0:
			return -1.0
		var leg := path_len(g, left[best][0], left[best][1])
		if leg < 0.0:
			return -1.0
		total += best_d + leg
		pos = left[best][1]
		left.remove_at(best)
	return total

func finish_time(est_seconds: float, slack: float) -> float:
	return maxf(30.0, ceil(est_seconds * slack / 5.0) * 5.0)

# =============================================================== HABITACIÓN
func gen_room(n: int, d: float, rng: RandomNumberGenerator) -> Node2D:
	var W := 22 + int(round(d * 12.0))
	var H := 13 + int(round(d * 4.0))
	var k := 5 + int(round(d * 5.0))          # objetos: 5 -> 10
	var n_obst := 2 + int(round(d * 4.0))      # muebles en el suelo
	var n_walk := int(floor(d * 3.4))          # familiares caminando: 0 -> 3
	var split := int(W * 0.62)
	var rows := fill_rows(W, H, func(x: int, y: int) -> String:
		if y == 0 or y == H - 1 or x == 0 or x == W - 1: return "#"
		if y == 1: return "w"
		if y == 2: return "b"
		return "t" if x > split else "."
	)
	var g := make_grid(W, H)
	for x in W:
		for y in [0, 1, 2, H - 1]:
			g.set_point_solid(Vector2i(x, y), true)
	for y in H:
		g.set_point_solid(Vector2i(0, y), true); g.set_point_solid(Vector2i(W - 1, y), true)
	var extra := " Cuidado con la familia: chocar resta 3s." if n_walk > 0 else ""
	var pen := wrong_penalty(n)
	var pen_txt := " Equivocarte de mueble resta %ds." % int(pen) if pen > 0 else ""
	var root := level_root(n, "Ordena la casa: lleva los %d objetos a su lugar.%s%s" % [k, extra, pen_txt], d, rows)
	var dec := root.get_node("Decor")
	var fur := root.get_node("Entities/Furniture")
	# estaciones contra la pared
	var pool := ROOM_STATIONS.duplicate()
	_shuffle(pool, rng)
	var stations := pool.slice(0, k)
	var inner := float((W - 2) * 16)
	var seg := inner / k
	var pairs := []
	var station_pos := []
	for i in k:
		var st: Array = stations[i]
		var x := roundf(16.0 + seg * (i + 0.5) + rng.randf_range(-seg * 0.2, seg * 0.2))
		station_pos.append(x)
		var parts: Array = st[5]
		for part in parts:
			furniture(fur, part[0], Vector2(x + part[1], 58), part[2])
			block_span(g, x, tex(part[0]).get_width(), 3)
		for wd in st[6]:
			decor(dec, wd[0], Vector2(x + wd[1], 58 + wd[2]))
		dropzone(root, st[1], st[0], st[3], Vector2(x, 66), Vector2(st[7], st[4] - 8), i)
	# decoración de pared en los huecos
	for i in k - 1:
		var gap: float = station_pos[i + 1] - station_pos[i]
		if gap >= 34.0 and rng.randf() < 0.8:
			decor(dec, WALL_DECOR[rng.randi() % WALL_DECOR.size()], Vector2(roundf((station_pos[i] + station_pos[i + 1]) / 2.0), 29))
	# filas reservadas para los que caminan
	var walk_rows := []
	var candidate_rows := range(6, H - 2)
	_shuffle(candidate_rows, rng)
	for i in n_walk:
		walk_rows.append(candidate_rows[i])
	# jugador
	var start := Vector2(W / 2 * 16 + 8, (H - 2) * 16 + 12)
	var reserved := {tile_of(start): true}
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			reserved[tile_of(start) + Vector2i(dx, dy)] = true
	# muebles en el suelo
	var placed := 0
	for tries in 200:
		if placed >= n_obst: break
		var path: String = ROOM_FLOOR[rng.randi() % ROOM_FLOOR.size()]
		var w := tex(path).get_width()
		var tw := int(ceil(w / 16.0))
		var tx := rng.randi_range(1, W - 2 - tw)
		var ty := rng.randi_range(6, H - 3)
		if ty in walk_rows: continue
		var free := true
		for xx in range(tx - 1, tx + tw + 1):
			for yy in range(ty - 1, ty + 2):
				var c := Vector2i(xx, yy)
				if not g.is_in_boundsv(c) or g.is_point_solid(c) or reserved.has(c):
					free = false
		if not free: continue
		var fx := tx * 16 + w / 2.0
		var body := furniture(fur, path, Vector2(roundf(fx), ty * 16 + 12))
		if path.ends_with("coffee_table_1.png"):
			body.add_child(sprite_bottom(tex("objects/living_room/flowerpot_small_red.png"), Vector2(0, -7), "Pot"))
			body.add_child(sprite_bottom(tex("objects/living_room/flora_poppy.png"), Vector2(0, -10), "Flower"))
		for xx in range(tx, tx + tw):
			g.set_point_solid(Vector2i(xx, ty), true)
		placed += 1
	# objetos tirados
	var item_tiles := []
	for i in k:
		var st: Array = stations[i]
		var done := false
		for tries in 300:
			var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(5, H - 2))
			if g.is_point_solid(c) or reserved.has(c): continue
			if abs(c.x * 16 + 8 - station_pos[i]) < 80.0 and c.y < 8: continue
			var near := false
			for o in item_tiles:
				if (o - c).length() < 2.5: near = true
			if near: continue
			item_tiles.append(c)
			var pos := Vector2(c.x * 16 + 8, c.y * 16 + 11)
			pickup(root, st[1], st[2], st[3], pos, i)
			pairs.append([pos, Vector2(station_pos[i], 70)])
			done = true
			break
		if not done:
			root.free(); return null
	var dist := tour_items(g, start, pairs)
	if dist < 0.0:
		root.free(); return null
	for i in n_walk:
		var y: int = walk_rows[i] * 16 + 12
		walker(root, Vector2(rng.randf_range(60, W * 16 - 60), y), 24.0, W * 16 - 24.0, lerpf(18.0, 34.0, d), i % 2 == 0,
			3.0, "¡Chocaste con alguien! -3s", Color(1.0, 0.9, 0.8) if i % 2 == 0 else Color(0.85, 0.95, 1.0), i)
	add_player(root, start)
	var est := dist / SPEED + k * 0.8
	var slack := lerpf(2.3, 1.45, d) + n_walk * 0.04
	var t := finish_time(est, slack)
	root.set("time_limit", t)
	report.append("L%02d room   %dx%d objetos=%d obst=%d familia=%d  recorrido=%.0fpx est=%.1fs -> tiempo=%ds" % [n, W, H, k, placed, n_walk, dist, est, t])
	return root

# =============================================================== OFICINA
func gen_office(n: int, d: float, rng: RandomNumberGenerator) -> Node2D:
	var W := 24 + int(round(d * 12.0))
	var H := 13 + int(round(d * 5.0))
	var k := 3 + int(round(d * 3.0))           # PCs y escritorios: 3 -> 6
	var hold := snappedf(lerpf(1.1, 2.0, d), 0.1)
	var n_walk := int(round(d * 4.0))           # compañeros: 0 -> 4
	var rows := fill_rows(W, H, func(x: int, y: int) -> String:
		if y == 0 or y == H - 1 or x == 0 or x == W - 1: return "#"
		if y == 1: return "o"
		if y == 2: return "p"
		return "c"
	)
	var g := make_grid(W, H)
	for x in W:
		for y in [0, 1, 2, H - 1]:
			g.set_point_solid(Vector2i(x, y), true)
	for y in H:
		g.set_point_solid(Vector2i(0, y), true); g.set_point_solid(Vector2i(W - 1, y), true)
	var pen := wrong_penalty(n)
	var pen_txt := " Equivocarte resta %ds." % int(pen) if pen > 0 else ""
	var walk_txt := " Esquiva a tus compañeros." if n_walk > 0 else ""
	var root := level_root(n, "Mantén [E] para encender %d PCs y deja en cada escritorio su objeto.%s%s" % [k, walk_txt, pen_txt], d, rows)
	var dec := root.get_node("Decor")
	var fur := root.get_node("Entities/Furniture")
	# muebles y decoración contra la pared
	var wall_furn := ["furniture/living_room/bookshelf_1.png", "furniture/living_room/bookshelf_small.png", "furniture/elevator_closed.png",
		"furniture/door_opened.png", "furniture/bedroom/cabinet_1.png", "objects/bedroom/box_green_medium.png"]
	var x := 24.0
	while x < W * 16 - 30:
		if rng.randf() < 0.45:
			var p: String = wall_furn[rng.randi() % wall_furn.size()]
			var w := tex(p).get_width()
			furniture(fur, p, Vector2(roundf(x + w / 2.0), 58))
			block_span(g, x + w / 2.0, w, 3)
			x += w + 10
		elif rng.randf() < 0.6:
			decor(dec, ["furniture/living_room/window_square.png", "furniture/living_room/window_circle.png", "objects/bedroom/calendar_2.png", "objects/bedroom/clock_1_blue.png"][rng.randi() % 4], Vector2(roundf(x + 8), 29))
			x += 26
		else:
			x += 18
	# escritorios en rejilla
	var cands := []
	var desk_rows := range(6, H - 2, 3)
	for ty in desk_rows:
		for tx in range(2, W - 3, 5):
			cands.append(Vector2i(tx, ty))
	if cands.size() < k:
		root.free(); return null
	_shuffle(cands, rng)
	var desks := cands.slice(0, k)
	var pc_scene: PackedScene = load("res://scenes/objects/Computer.tscn")
	var items := DESK_ITEMS.duplicate()
	_shuffle(items, rng)
	var pairs := []
	var pcs := []
	var desk_px := []
	for i in k:
		var c: Vector2i = desks[i]
		var p := Vector2(c.x * 16 + 16, c.y * 16 + 12)
		desk_px.append(p)
		furniture(fur, "furniture/living_room/table_long.png", p).name = "Desk%d" % (i + 1)
		g.set_point_solid(c, true); g.set_point_solid(c + Vector2i(1, 0), true)
		var pc: Node2D = pc_scene.instantiate()
		pc.set("pc_name", "PC %d" % (i + 1))
		pc.set("hold_time", hold)
		pc.position = p + Vector2(-7, 4)
		add(root.get_node("Entities/Tasks"), pc, "Computer%d" % (i + 1))
		pcs.append(pc.position + Vector2(0, 4))
		var it: Array = items[i]
		dropzone(root, it[0], "Escritorio %d" % (i + 1), it[2], p + Vector2(8, 4), Vector2(0, -11), i)
	# plantas decorativas libres
	for i in 2 + int(d * 3):
		var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(4, H - 2))
		if g.is_point_solid(c) or c.y in desk_rows: continue
		furniture(fur, "objects/living_room/flowerpot_medium_green.png", Vector2(c.x * 16 + 8, c.y * 16 + 12)).add_child(
			sprite_bottom(tex("objects/living_room/flora_daisy_4.png"), Vector2(0, -3), "Plant"))
		g.set_point_solid(c, true)
	var start := Vector2(W / 2 * 16 + 8, (H - 2) * 16 + 12)
	if g.is_point_solid(tile_of(start)):
		root.free(); return null
	# objetos
	var used := {}
	for i in k:
		var it: Array = items[i]
		var done := false
		for tries in 300:
			var c := Vector2i(rng.randi_range(1, W - 2), rng.randi_range(4, H - 2))
			if g.is_point_solid(c) or used.has(c) or c == tile_of(start): continue
			if (Vector2(c * 16) - desk_px[i]).length() < 70.0: continue
			used[c] = true
			var pos := Vector2(c.x * 16 + 8, c.y * 16 + 11)
			pickup(root, it[0], it[1], it[2], pos, i)
			pairs.append([pos, desk_px[i] + Vector2(8, 8)])
			done = true
			break
		if not done:
			root.free(); return null
	# las PCs también son "visitas": se modelan como pares (pc -> pc)
	for pcp in pcs:
		pairs.append([pcp, pcp])
	var dist := tour_items(g, start, pairs)
	if dist < 0.0:
		root.free(); return null
	# compañeros caminando por los pasillos frente a los escritorios
	var walk_rows := []
	for ty in desk_rows:
		walk_rows.append(ty + 1)
	walk_rows.append(4)
	_shuffle(walk_rows, rng)
	for i in n_walk:
		var y: int = walk_rows[i % walk_rows.size()] * 16 + 12
		walker(root, Vector2(rng.randf_range(60, W * 16 - 60), y), 24.0, W * 16 - 24.0, lerpf(20.0, 36.0, d), i % 2 == 1,
			3.0, "¡Chocaste con un compañero! -3s", Color(0.85, 1.0, 0.85) if i % 2 == 0 else Color(1.0, 0.85, 1.0), i)
	add_player(root, start)
	var est := dist / SPEED + k * (hold + 0.8)
	var slack := lerpf(2.3, 1.45, d) + n_walk * 0.04
	var t := finish_time(est, slack)
	root.set("time_limit", t)
	report.append("L%02d office %dx%d PCs=%d hold=%.1fs compañeros=%d recorrido=%.0fpx est=%.1fs -> tiempo=%ds" % [n, W, H, k, hold, n_walk, dist, est, t])
	return root

# =============================================================== CALLE
func gen_street(n: int, d: float, rng: RandomNumberGenerator) -> Node2D:
	var W := 50 + int(round(d * 36.0))
	var m := 3 + int(round(d * 3.0))            # entregas: 3 -> 6
	var four := d >= 0.5                        # 4 carriles con camellón central
	# filas: 0-3 pasto, 4 acera, 5 bordillo, calzada..., acera inferior (2 filas), pasto
	var road_rows := [6, 7, 9, 10] if four else [6, 7, 8, 9]
	var line_rows := [6, 9] if four else [7]
	var median_row := 8 if four else -1
	var sw0 := 11 if four else 10              # primera fila de la acera inferior
	var H := sw0 + 5
	var crosses := []
	for cx in range(10, W - 4, 18):
		crosses.append(cx); crosses.append(cx + 1)
	var rows := fill_rows(W, H, func(x: int, y: int) -> String:
		if y <= 3 or y >= sw0 + 2: return "g"
		if y == 4 or y == sw0 or y == sw0 + 1 or y == median_row: return "s"
		if y == 5: return "k"
		if x in crosses: return "z"
		if y in line_rows: return "-"
		return "a"
	)
	var walk_txt := " Usa el camellón central para cruzar en dos tiempos." if four else ""
	var root := level_root(n, "Reparte %d paquetes desde el depósito central. ¡Autos -8s, peatones -3s!%s" % [m, walk_txt], d, rows)
	var dec := root.get_node("Decor")
	var fur := root.get_node("Entities/Furniture")
	var g := make_grid(W, H)
	for x in W:
		for y in range(0, 4):
			g.set_point_solid(Vector2i(x, y), true)
	var bot_y := float(H * 16)
	var bounds := StaticBody2D.new(); bounds.collision_layer = 1; bounds.collision_mask = 0
	add(root, bounds, "Bounds")
	add(bounds, rect_shape(Vector2(W * 16, 16), Vector2(W * 8, 56)), "Top")
	add(bounds, rect_shape(Vector2(W * 16, 16), Vector2(W * 8, bot_y + 8)), "Bottom")
	add(bounds, rect_shape(Vector2(16, bot_y), Vector2(-8, bot_y / 2)), "Left")
	add(bounds, rect_shape(Vector2(16, bot_y), Vector2(W * 16 + 8, bot_y / 2)), "Right")
	# edificios con entrega
	var margin := 90.0
	var span := W * 16 - margin * 2
	var bx := []
	for i in m:
		var x := roundf(margin + span * (i + 0.5) / m + rng.randf_range(-20, 20))
		bx.append(x)
		var bi := rng.randi() % BUILDINGS.size()
		decor(dec, BUILDINGS[bi], Vector2(x, 66), true)
		dropzone(root, "package", BUILDING_NAMES[bi], "objects/bedroom/moving_package_large.png", Vector2(x, 76), Vector2(0, -2), i, true)
	for i in m + 1:
		var tx := margin * 0.5 + span * i / float(m) + 10
		if rng.randf() < 0.85:
			decor(dec, "backgrounds/tree_medium.png", Vector2(roundf(tx), 64), true)
	# depósito central (acera inferior)
	var sw_top := sw0 * 16.0
	var depot_x := roundf(W * 8.0)
	var dep: Node2D = load("res://scenes/objects/PackageDepot.tscn").instantiate()
	dep.position = Vector2(depot_x, sw_top + 22)
	dep.set("packages", m)
	var stack := dep.get_node("Stack")
	var pkg := tex("objects/bedroom/moving_package_large.png")
	for i in range(3, m):
		stack.add_child(sprite_bottom(pkg, Vector2((i % 2) * 2 - 1, -i * 9)), true)
		stack.get_child(stack.get_child_count() - 1).name = "Package%d" % (i + 1)
	add(root.get_node("Entities/Items"), dep, "PackageDepot")
	# obstáculos fijos en las aceras
	var obst_paths := ["objects/bedroom/box_green_large.png", "objects/bedroom/moving_package_large.png", "furniture/living_room/couch_small_2_red.png",
		"objects/bedroom/box_blue_large.png", "objects/living_room/flowerpot_medium_red.png"]
	var n_obst := 4 + int(round(d * 8.0))
	var placed := 0
	var obst_x := []
	for tries in 300:
		if placed >= n_obst: break
		var top := rng.randf() < 0.5
		var x := roundf(rng.randf_range(40, W * 16 - 40))
		var y := 82.0 if top else (sw_top + 12.0 if rng.randf() < 0.5 else sw_top + 26.0)
		var bad := false
		for b in bx:
			if top and absf(x - b) < 36: bad = true
		if not top and absf(x - depot_x) < 50: bad = true
		for o in obst_x:
			if absf(x - o.x) < 44 and absf(y - o.y) < 20: bad = true
		if bad: continue
		var p: String = obst_paths[rng.randi() % obst_paths.size()]
		var body := furniture(fur, p, Vector2(x, y))
		if p.ends_with("flowerpot_medium_red.png"):
			body.add_child(sprite_bottom(tex("objects/living_room/flora_aster.png"), Vector2(0, -3), "Plant"))
		block_span(g, x, tex(p).get_width(), int(floor((y - 1) / 16.0)))
		obst_x.append(Vector2(x, y))
		placed += 1
	if four:  # plantas decorativas en el camellón (sin colisión)
		for i in int(W / 6):
			var px := roundf(rng.randf_range(20, W * 16 - 20))
			if int(px / 16) in crosses: continue
			decor(dec, "objects/living_room/flora_daisy.png", Vector2(px, median_row * 16 + 8 + rng.randi_range(-3, 3)))
	for i in int(W / 16):
		var tx := roundf(rng.randf_range(60, W * 16 - 60))
		if absf(tx - depot_x) < 60: continue
		furniture(fur, "backgrounds/tree_medium.png", Vector2(tx, bot_y - 4), true, 4)
		g.set_point_solid(Vector2i(int(tx / 16), H - 1), true)
	# tráfico
	var lanes := [[124.0, 1], [156.0, -1]]
	if four:
		lanes = [[109.0, 1], [123.0, 1], [159.0, -1], [173.0, -1]]
	var spacing := lerpf(400.0, 260.0, d)
	var car_scene: PackedScene = load("res://scenes/objects/Car.tscn")
	var colors := ["car_red", "car_blue", "car_yellow", "car_green"]
	var ci := 0
	for lane in lanes:
		var count := int(ceil(W * 16 / spacing))
		var off := rng.randf_range(0, spacing)
		var lane_speed := lerpf(70.0, 115.0, d) + rng.randf_range(-12, 12)
		for i in count:
			var car: Node2D = car_scene.instantiate()
			car.position = Vector2(roundf(off + i * spacing + rng.randf_range(-40, 40)), lane[0])
			car.set("direction", lane[1])
			car.set("speed", lane_speed)
			car.set("max_x", W * 16 + 40.0)
			(car.get_node("Visual") as Sprite2D).texture = tex("vehicles/%s.png" % colors[ci % colors.size()])
			add(root.get_node("Entities/Hazards"), car, "Car%d" % ci)
			ci += 1
	# peatones
	var n_ped := 2 + int(round(d * 6.0))
	for i in n_ped:
		var top := i % 2 == 0
		var a := rng.randf_range(40, W * 16 - 400)
		var b := a + rng.randf_range(220, 380)
		walker(root, Vector2(rng.randf_range(a, b), 94.0 if top else sw_top + 30.0), a, b, lerpf(22.0, 45.0, d), i % 3 == 0,
			3.0, "¡Choque con un peatón! -3s", [Color.WHITE, Color(1, 0.85, 0.75), Color(0.85, 0.9, 1)][i % 3], i)
	var start := Vector2(depot_x + 30, sw_top + 40)
	add_player(root, start)
	# estimación: depósito -> edificio -> depósito ...
	var depot := Vector2(depot_x, sw_top + 36)
	var dist := path_len(g, start, depot)
	for x in bx:
		var leg := path_len(g, depot, Vector2(x, 84))
		if leg < 0.0:
			root.free(); return null
		dist += leg * 2.0
	var crossings := m * 2 * lerpf(2.0, 3.5, d)  # espera media para cruzar
	var est := dist / SPEED + crossings + m * 0.8
	var slack := lerpf(1.8, 1.35, d)
	var t := finish_time(est, slack)
	root.set("time_limit", t)
	report.append("L%02d street W=%d entregas=%d carriles=%d autos=%d peatones=%d obst=%d recorrido=%.0fpx est=%.1fs -> tiempo=%ds" % [n, W, m, lanes.size(), ci, n_ped, placed, dist, est, t])
	return root

func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp

# =============================================================== UI patches
func patch_hud() -> void:
	var hud: Node = load("res://scenes/ui/HUD.tscn").instantiate()
	hud.set_script(load("res://scripts/ui/HUD.gd"))
	var ll := hud.get_node("Root/TopBar/HBox/LevelLabel") as Label
	ll.clip_text = true
	ll.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var vbox := hud.get_node("Root/CompletePanel/Panel/VBox")
	if not vbox.has_node("StarsBox"):
		var sb := HBoxContainer.new()
		sb.alignment = BoxContainer.ALIGNMENT_CENTER
		sb.add_theme_constant_override("separation", 3)
		add(vbox, u(sb), "StarsBox")
		vbox.move_child(sb, 1)
		for i in 3:
			var tr := TextureRect.new()
			tr.texture = load("res://assets/ui/star_empty.png")
			add(sb, tr, "Star%d" % (i + 1))
	save_scene(hud, "res://scenes/ui/HUD.tscn")

func patch_main_menu() -> void:
	var menu: Control = load("res://scenes/ui/MainMenu.tscn").instantiate()
	menu.set_script(load("res://scripts/ui/MainMenu.gd"))
	var old := menu.get_node_or_null("MenuArea/Center/LevelPanel")
	if old:
		old.get_parent().remove_child(old)
		old.free()
	var ma := menu.get_node("MenuArea") as Control
	ma.unique_name_in_owner = false
	_uniques.append(ma)
	if not menu.has_node("LevelSelect"):
		var cc := CenterContainer.new()
		full_rect(cc)
		add(menu, u(cc), "LevelSelect")
		menu.move_child(cc, menu.get_node("Credits").get_index())
		var p := PanelContainer.new()
		add(cc, p, "Panel")
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		add(p, v, "VBox")
		add(v, label("SELECCIONA NIVEL", 8, YELLOW, true), "Header")
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 2)
		add(v, u(grid), "LevelGrid")
		var info := label("", 8, CREAM)
		info.custom_minimum_size = Vector2(230, 0)
		add(v, u(info), "LevelInfo")
		var back := Button.new(); back.text = "Volver"; back.custom_minimum_size = Vector2(110, 14)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add(v, u(back), "BackButton")
	save_scene(menu, "res://scenes/ui/MainMenu.tscn")
