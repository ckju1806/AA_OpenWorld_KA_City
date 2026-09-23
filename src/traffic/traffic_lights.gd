class_name TrafficLights
extends Node3D
## Ampelanlagen an Kreuzungen mit Haupt-/Ringstraßen. Zwei Phasengruppen (Achsen), fester Zyklus
## mit Versatz je Kreuzung. Visuals: Mast mit drei Lichtern je Zufahrt, Haltelinien.

enum Light { RED, YELLOW, GREEN }

const T_GREEN: float = 11.0
const T_YELLOW: float = 2.5
const T_ALLRED: float = 1.3
const CYCLE: float = (T_GREEN + T_YELLOW + T_ALLRED) * 2.0

var graph: CityGraph
var time: float = 0.0
var signals: Dictionary = {}      ## node -> { groups: {edge: 0|1}, offset, mi, last_phase }

static var _mat_on: Dictionary = {}
static var _mat_off: Dictionary = {}


func setup(g: CityGraph, slab_h: float) -> void:
	graph = g
	_init_materials()
	var marks := MeshKit.new()
	marks.set_material("m", CityMaterials.get_mat("marking"))
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	add_child(body)
	for n: int in g.node_count():
		var edges: PackedInt32Array = g.node_edges_mode(n, "traffic")
		if edges.size() < 3:
			continue
		var major: bool = false
		for e: int in edges:
			if g.edge_kind(e) in ["main", "ring"]:
				major = true
		if not major:
			continue
		var groups: Dictionary = {}
		var ref: Vector2 = g.edge_dir(edges[0], n)
		for e2: int in edges:
			var d: Vector2 = g.edge_dir(e2, n)
			groups[e2] = 0 if absf(d.dot(ref)) > 0.7 else 1
		var kit := MeshKit.new()
		kit.set_material("pole", MatLib.solid(Color(0.2, 0.22, 0.22), 0.5, 0.4))
		for key: String in ["0_r", "0_y", "0_g", "1_r", "1_y", "1_g"]:
			kit.set_material(key, _mat_off[key.substr(2)])
		var r: float = g.node_radius(n, "all")
		for e3: int in edges:
			var d3: Vector2 = g.edge_dir(e3, n)
			var app: Vector2 = -d3
			var right: Vector2 = Vector2(-app.y, app.x)
			var w: float = g.edge_width(e3)
			# Mast neben der Fahrbahn platzieren; an spitzwinkligen Kreuzungen weiter zurücksetzen
			var base: Vector2 = Vector2.INF
			for extra: float in [2.5, 5.0, 8.0, 12.0, 16.0]:
				var cand: Vector2 = g.node_pos[n] + d3 * (r + extra) + right * (w * 0.5 + 0.7)
				if not _on_road(g, cand):
					base = cand
					break
			if base == Vector2.INF:
				continue
			var yaw: float = atan2(-d3.x, -d3.y) + PI
			var b := Basis(Vector3.UP, yaw)
			var p3: Vector3 = Vector3(base.x, slab_h, base.y)
			kit.color = Color.WHITE
			kit.add_cylinder("pole", p3, 0.08, 0.07, 3.6, 8)
			kit.add_box("pole", p3 + Vector3(0, 3.2, 0) + b * Vector3(0, 0, 0.05), Vector3(0.36, 1.05, 0.28), b)
			var grp: String = str(groups[e3])
			for li: int in 3:
				var key2: String = grp + "_" + ["r", "y", "g"][li]
				var lp: Vector3 = p3 + Vector3(0, 3.55 - float(li) * 0.33, 0) + b * Vector3(0, 0, 0.2)
				kit.add_sphere(key2, lp, Vector3(0.12, 0.12, 0.06), 4, 8)
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.12
			cyl.height = 3.6
			cs.shape = cyl
			cs.position = p3 + Vector3(0, 1.8, 0)
			body.add_child(cs)
			# Haltelinie über die rechte Fahrbahnhälfte
			var sl: Vector2 = g.node_pos[n] + d3 * (r + 1.2) + right * (w * 0.25)
			var syaw: float = atan2(-right.y, right.x)
			marks.color = Color(0.92, 0.92, 0.88)
			marks.add_box("m", Vector3(sl.x, 0.013, sl.y), Vector3(w * 0.5 - 0.3, 0.01, 0.4), Basis(Vector3.UP, syaw))
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		add_child(mi)
		signals[n] = {"groups": groups, "offset": DetRng.hash01(n, 3, 7) * CYCLE, "mi": mi, "surf": kit.surface_index.duplicate(), "last": -1}
	var mmi := MeshInstance3D.new()
	mmi.mesh = marks.commit()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_update_visuals(true)


## Liegt ein Punkt auf einer Fahrbahn (inkl. Sicherheitsabstand)?
static func _on_road(g: CityGraph, p: Vector2) -> bool:
	for e: int in g.edge_count():
		if not g.is_drivable(e):
			continue
		var d: float = PolyUtil.dist_point_segment(p, g.node_pos[g.edge_a[e]], g.node_pos[g.edge_b[e]])
		if d < g.edge_width(e) * 0.5 + 0.4:
			return true
	return false


static func _init_materials() -> void:
	if not _mat_on.is_empty():
		return
	_mat_on = {"r": MatLib.emissive(Color(1.0, 0.12, 0.08), 6.0), "y": MatLib.emissive(Color(1.0, 0.7, 0.1), 6.0), "g": MatLib.emissive(Color(0.2, 1.0, 0.45), 6.0)}
	_mat_off = {"r": MatLib.solid(Color(0.25, 0.05, 0.05), 0.4), "y": MatLib.solid(Color(0.25, 0.18, 0.04), 0.4), "g": MatLib.solid(Color(0.05, 0.2, 0.08), 0.4)}


func is_signalized(n: int) -> bool:
	return signals.has(n)


## Zustand für ein Fahrzeug, das über Kante edge_in auf Knoten n zufährt.
func light_for(n: int, edge_in: int) -> Light:
	if not signals.has(n):
		return Light.GREEN
	var s: Dictionary = signals[n]
	var grp: int = int((s.groups as Dictionary).get(edge_in, 0))
	return _group_light(grp, fmod(time + float(s.offset), CYCLE))


static func _group_light(grp: int, t: float) -> Light:
	var half: float = CYCLE * 0.5
	var local: float = t - (half if grp == 1 else 0.0)
	if local < 0.0:
		local += CYCLE
	if local < T_GREEN:
		return Light.GREEN
	if local < T_GREEN + T_YELLOW:
		return Light.YELLOW
	return Light.RED


func _process(delta: float) -> void:
	time += delta
	_update_visuals(false)


func _update_visuals(force: bool) -> void:
	for n: int in signals:
		var s: Dictionary = signals[n]
		var t: float = fmod(time + float(s.offset), CYCLE)
		var phase: int = int(_group_light(0, t)) * 3 + int(_group_light(1, t))
		if phase == int(s.last) and not force:
			continue
		s["last"] = phase
		var mi: MeshInstance3D = s.mi
		var surf: Dictionary = s.surf
		for grp: int in 2:
			var l: Light = _group_light(grp, t)
			for c: String in ["r", "y", "g"]:
				var key: String = "%d_%s" % [grp, c]
				if not surf.has(key):
					continue
				var on: bool = (c == "r" and l == Light.RED) or (c == "y" and l == Light.YELLOW) or (c == "g" and l == Light.GREEN)
				mi.set_surface_override_material(int(surf[key]), _mat_on[c] if on else _mat_off[c])
