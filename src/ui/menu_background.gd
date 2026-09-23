class_name MenuBackground
extends Control
## Eigener Menühintergrund: stilisierter Fächergrundriss (Schlossturm oben, 32 Strahlen, Zirkel, Kaiserstraße)
## in Abendfarben, mit wandernden Lichtpunkten auf den Strahlen (Autos bei Nacht).

var _t: float = 0.0
var _lights: Array[Vector2] = []     ## x = Strahlindex, y = Phase


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := DetRng.make_rng(77)
	for i: int in 70:
		_lights.append(Vector2(rng.randi_range(0, 31), rng.randf()))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Himmel-/Bodenverlauf (Abend)
	var steps: int = 24
	for i: int in steps:
		var f: float = float(i) / float(steps)
		var col: Color = Color(0.11, 0.07, 0.1).lerp(Color(0.03, 0.03, 0.05), f)
		draw_rect(Rect2(0, h * f, w, h / float(steps) + 1.0), col)
	var tower: Vector2 = Vector2(w * 0.66, h * 0.12)
	var unit: float = h * 0.0016
	# Schlossgarten-Schimmer
	draw_circle(tower, 200.0 * unit, Color(0.1, 0.13, 0.09, 0.35))
	# Strahlen (32, alle 11,25°), unterer Halbkreis betont
	for k: int in 32:
		var a: float = deg_to_rad(float(k) * 11.25)
		var dir: Vector2 = Vector2(sin(a), cos(a))
		var south: bool = dir.y > 0.05
		var length: float = (1100.0 if south else 420.0) * unit
		var col2: Color = Color(0.95, 0.62, 0.25, 0.28 if south else 0.1)
		if absf(dir.x) < 0.01 and south:
			col2 = Color(1.0, 0.75, 0.4, 0.55)
		draw_line(tower + dir * 30.0 * unit, tower + dir * length, col2, 2.0 if south else 1.0, true)
	# Zirkel und Kaiserstraße
	draw_arc(tower, 200.0 * unit, 0.0, PI, 64, Color(0.95, 0.62, 0.25, 0.45), 3.0, true)
	draw_arc(tower, 560.0 * unit, PI, TAU, 96, Color(0.95, 0.62, 0.25, 0.18), 2.0, true)
	var ky: float = tower.y + 330.0 * unit
	draw_line(Vector2(tower.x - 560.0 * unit, ky), Vector2(tower.x + 560.0 * unit, ky), Color(0.95, 0.62, 0.25, 0.4), 3.0, true)
	# Pyramide am Marktplatz
	var py: Vector2 = Vector2(tower.x, tower.y + 395.0 * unit)
	draw_colored_polygon(PackedVector2Array([py + Vector2(0, -16) * unit * 3.0, py + Vector2(7, 4) * unit * 3.0, py + Vector2(-7, 4) * unit * 3.0]), Color(0.95, 0.62, 0.25, 0.7))
	# Schlossturm
	draw_circle(tower, 9.0 * unit * 2.0, Color(1.0, 0.8, 0.5, 0.9))
	# Lichtpunkte, die auf den Strahlen nach außen wandern
	for l: Vector2 in _lights:
		var a2: float = deg_to_rad(l.x * 11.25)
		var d2: Vector2 = Vector2(sin(a2), cos(a2))
		if d2.y <= 0.05:
			continue
		var ph: float = fmod(l.y + _t * 0.035, 1.0)
		var p: Vector2 = tower + d2 * lerpf(210.0, 1100.0, ph) * unit
		var warm: bool = int(l.x) % 2 == 0
		draw_circle(p, 2.6, Color(1.0, 0.85, 0.55, 0.9) if warm else Color(1.0, 0.3, 0.25, 0.8))
	# Vignette
	draw_rect(Rect2(0, h * 0.82, w, h * 0.18), Color(0, 0, 0, 0.35))
