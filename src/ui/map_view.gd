class_name MapView
extends Control
## Stadtkarte aus denselben Graphdaten wie Welt, Verkehr und Missionen: Blöcke, Park, Plätze, Straßen
## (Breite in Metern), Beschriftungen, Auftraggeber, Missionsziel, Polizei, Spielerpfeil.
## full = false: Minikarte (folgt dem Spieler, Norden oben); full = true: ganze Stadt mit Legende.

const C_BG: Color = Color(0.09, 0.09, 0.1, 0.92)
const C_BLOCK: Color = Color(0.22, 0.21, 0.22)
const C_PARK: Color = Color(0.2, 0.3, 0.19)
const C_PLAZA: Color = Color(0.46, 0.42, 0.36)
const STREET_COLORS: Dictionary = {
	"ring": Color(0.93, 0.8, 0.55), "main": Color(0.82, 0.8, 0.76), "street": Color(0.66, 0.65, 0.63),
	"narrow": Color(0.52, 0.51, 0.5), "pedestrian": Color(0.62, 0.55, 0.46),
}

var game: Node = null
var graph: CityGraph = null
var full: bool = false
var mini_range: float = 190.0          ## Meter vom Mittelpunkt bis zum Rand (Minikarte)

var _faces: Array[Dictionary] = []     ## { poly: PackedVector2Array, color }
var _edges: Array[Dictionary] = []     ## { a, b, width, color }
var _labels: Array[Dictionary] = []
var _plazas: Array[Dictionary] = []
var _font: Font
var _redraw_t: float = 0.0


func setup(p_game: Node, g: CityGraph, p_full: bool) -> void:
	game = p_game
	graph = g
	full = p_full
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	for f: Dictionary in g.faces:
		var poly: PackedVector2Array = f.get("poly", PackedVector2Array())
		if poly.size() < 3:
			continue
		var kind: String = str(f.get("kind", "block"))
		_faces.append({"poly": poly, "color": C_PARK if kind == "park" else C_BLOCK})
	for e: int in g.edge_count():
		var kind2: String = g.edge_kind(e)
		_edges.append({"a": g.node_pos[g.edge_a[e]], "b": g.node_pos[g.edge_b[e]], "width": g.edge_width(e),
			"color": STREET_COLORS.get(kind2, Color.GRAY), "kind": kind2})
	for c: Dictionary in g.layout.get("clearings", []):
		_plazas.append(c)
	for l: Dictionary in g.layout.get("map_labels", []):
		_labels.append({"text": str(l.text), "pos": Vector2(float(l.pos[0]), float(l.pos[1]))})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.0 if full else 1.0 / 30.0
		queue_redraw()


func _player() -> Player:
	return game.get("player") as Player if game != null else null


func _player_pos() -> Vector3:
	var p: Player = _player()
	if p == null:
		return Vector3.ZERO
	return p.current_vehicle.global_position if p.is_in_vehicle() else p.global_position


func _player_heading() -> float:
	var p: Player = _player()
	if p == null:
		return 0.0
	var n: Node3D = p.current_vehicle if p.is_in_vehicle() else p
	var f: Vector3 = -n.global_basis.z
	return atan2(f.x, -f.z)     ## 0 = Norden, im Uhrzeigersinn


## Weltmaßstab und Mittelpunkt der aktuellen Ansicht.
func view() -> Dictionary:
	if full:
		var world_min: Vector2 = Vector2(-620, -620)
		var world_max: Vector2 = Vector2(620, 700)
		var ext: Vector2 = world_max - world_min
		var s: float = minf((size.x - 80.0) / ext.x, (size.y - 120.0) / ext.y)
		return {"scale": s, "center": (world_min + world_max) * 0.5}
	var pp: Vector3 = _player_pos()
	return {"scale": minf(size.x, size.y) * 0.5 / mini_range, "center": Vector2(pp.x, pp.z)}


func world_to_screen(p: Vector2) -> Vector2:
	var v: Dictionary = view()
	return size * 0.5 + (p - (v.center as Vector2)) * float(v.scale)


func _draw() -> void:
	if graph == null:
		return
	var v: Dictionary = view()
	var s: float = v.scale
	var off: Vector2 = size * 0.5 - (v.center as Vector2) * s
	draw_rect(Rect2(Vector2.ZERO, size), Color(C_BG, 1.0) if full else C_BG)
	# Geometrie in Weltkoordinaten zeichnen (Straßenbreiten in Metern)
	draw_set_transform(off, 0.0, Vector2(s, s))
	for f: Dictionary in _faces:
		draw_colored_polygon(f.poly, f.color)
	for c: Dictionary in _plazas:
		if c.has("circle"):
			var ci: Array = c.circle
			draw_circle(Vector2(float(ci[0]), float(ci[1])), float(ci[2]), C_PLAZA)
		elif c.has("rect"):
			var r: Array = c.rect
			draw_rect(Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])), C_PLAZA)
	var min_w: float = 2.0 / s
	for e: Dictionary in _edges:
		if e.kind == "pedestrian":
			draw_line(e.a, e.b, e.color, maxf(float(e.width) * 0.7, min_w))
	for e2: Dictionary in _edges:
		if e2.kind != "pedestrian":
			draw_line(e2.a, e2.b, e2.color, maxf(float(e2.width), min_w))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if full:
		for l: Dictionary in _labels:
			_text_centered(world_to_screen(l.pos), str(l.text), 20, Color(1, 0.97, 0.9))
	_draw_markers()
	if full:
		_draw_legend()
	else:
		draw_rect(Rect2(Vector2.ZERO, size), UiStyle.ACCENT, false, 3.0)
		_text_centered(Vector2(size.x * 0.5, 16), "N", 18, UiStyle.ACCENT)


func _draw_markers() -> void:
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if ms != null:
		if not ms.has_active():
			for id: String in ms.givers:
				var g: MissionGiver = ms.givers[id]
				if g.is_offering():
					_marker(Vector2(g.global_position.x, g.global_position.z), UiStyle.ACCENT, "◆", full)
		if ms.active != null and ms.has_target:
			_marker(Vector2(ms.target.x, ms.target.z), Color(1.0, 0.85, 0.3), "●", true)
	var police: PoliceManager = game.get("police") as PoliceManager
	if police != null and police.wanted_level() > 0:
		var blink: bool = int(Time.get_ticks_msec() / 300) % 2 == 0
		for u: Vehicle in police.units:
			if is_instance_valid(u):
				var sp: Vector2 = world_to_screen(Vector2(u.global_position.x, u.global_position.z))
				if Rect2(Vector2.ZERO, size).has_point(sp):
					draw_circle(sp, 6.0, UiStyle.POLICE_BLUE if blink else UiStyle.BAD)
	# Spielerpfeil
	var pp: Vector3 = _player_pos()
	var c: Vector2 = world_to_screen(Vector2(pp.x, pp.z))
	var h: float = _player_heading()
	var fwd: Vector2 = Vector2(sin(h), -cos(h))
	var right: Vector2 = Vector2(-fwd.y, fwd.x)
	var k: float = 11.0
	var tri: PackedVector2Array = PackedVector2Array([c + fwd * k, c - fwd * k * 0.7 + right * k * 0.7, c - fwd * k * 0.35, c - fwd * k * 0.7 - right * k * 0.7])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0.1, 0.1, 0.1), 2.0)


## Markierung; clamp = am Rand festhalten, wenn außerhalb (Richtungsanzeige).
func _marker(world: Vector2, col: Color, glyph: String, clamp_to_edge: bool) -> void:
	var sp: Vector2 = world_to_screen(world)
	var rect: Rect2 = Rect2(Vector2(14, 14), size - Vector2(28, 28))
	if not rect.has_point(sp):
		if not clamp_to_edge:
			return
		var c: Vector2 = size * 0.5
		var d: Vector2 = sp - c
		var t: float = minf(absf((rect.size.x * 0.5) / maxf(absf(d.x), 0.001)), absf((rect.size.y * 0.5) / maxf(absf(d.y), 0.001)))
		sp = c + d * t
	draw_circle(sp, 10.0, Color(0, 0, 0, 0.6))
	_text_centered(sp + Vector2(0, 1), glyph, 20, col)


func _text_centered(p: Vector2, text: String, fs: int, col: Color) -> void:
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos: Vector2 = p + Vector2(-w * 0.5, fs * 0.35)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.85))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_legend() -> void:
	var x: float = 40.0
	var y: float = size.y - 40.0
	var items: Array = [["◆", UiStyle.ACCENT, "Auftrag"], ["●", Color(1.0, 0.85, 0.3), "Missionsziel"],
		["▲", Color.WHITE, "Du"], ["●", UiStyle.POLICE_BLUE, "Polizei"], ["━", STREET_COLORS.ring, "Ring"],
		["━", STREET_COLORS.pedestrian, "Fußgängerzone"], ["■", C_PARK, "Park"]]
	for it: Array in items:
		draw_string(_font, Vector2(x, y), str(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, it[1])
		draw_string(_font, Vector2(x + 28, y), str(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.TEXT)
		x += 40.0 + _font.get_string_size(str(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 26.0
	_text_centered(Vector2(size.x * 0.5, 34), "KARTE  ·  Fächer-City (künstlerisch verdichtet)", 28, UiStyle.ACCENT)
	var hint: String = "[M] oder [Esc] schließen"
	draw_string(_font, Vector2(size.x - 40 - _font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, y), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiStyle.TEXT_DIM)
