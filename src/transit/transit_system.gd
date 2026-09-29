class_name TransitSystem
extends Node
## ÖPNV (W5): Stadtbahn- und Buslinien aus den Weltdaten (world.json -> transit). Jede Linie hat „virtuelle“ Fahrzeuge
## im Takt (ganze Stadt, sehr leicht); sichtbare Fahrzeuge (mit Kollision) nur in Spielernähe. Stadtbahnen fahren im
## U-Strab-Tunnel unter der Kaiserstraße (Rampen), Busse auf der Fahrbahn. Halt an Haltestellen mit Wartezeit, Fahrgäste
## steigen ein/aus, Bahnen haben Vorrang, bremsen aber vor Hindernissen. Der Spieler kann an Haltestellen einsteigen
## (Fahrschein 2,90 €), mitfahren und an der nächsten Haltestelle aussteigen (E).

const TUNNEL_DEPTH: float = -7.5
const RAMP: float = 70.0
const VISIBLE_DIST: float = 480.0
const STOP_SHOW_DIST: float = 320.0
const FARE: int = 3
const HEADWAY: Dictionary = {"tram": 150.0, "bus": 240.0, "train": 400.0}   ## Echtzeit-Sekunden zwischen Fahrzeugen
const SPEED: Dictionary = {"tram": 12.5, "bus": 10.0, "train": 20.0}
const DWELL: float = 14.0

var game: Node
var city: CityWorld
## Fahrzeuge fahren nur mit Umgebungsleben (wie Verkehr/Passanten); Linien/Haltestellen/Tunnel bleiben bestehen.
var enabled: bool = true
var lines: Array[Dictionary] = []      ## {ref, name, mode, colour, pts: PackedVector2Array, cum: PackedFloat32Array, len, stops: [stop_i], s: [..], tun: [[s0, s1]]}
var stops: Array[Dictionary] = []      ## {name, pos: Vector2, modes, underground}
var vehicles: Array[Dictionary] = []   ## virtuell: {line, s, v, dwell, stop_k, node, segs: [], id}
var root: Node3D
var track_offset: float = 0.0          ## seitlicher Versatz je Fahrtrichtung (Bahnen auf gemeinsamer Achse)
var tunnel_root: Node3D
var _stop_nodes: Dictionary = {}       ## stop_i -> Node3D
var _waiting: Dictionary = {}          ## stop_i -> Array[EventActor] (wartende Fahrgäste an sichtbaren Haltestellen)
var _board_point: TransitBoardPoint
var ride: Dictionary = {}              ## aktuelle Fahrt des Spielers: {veh, board_stop, want_exit}
var ride_log: Array[Dictionary] = []   ## {from, to} abgeschlossene Fahrten
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _next_id: int = 0


func setup(p_game: Node, p_city: CityWorld) -> void:
	game = p_game
	city = p_city
	enabled = bool(game.get("ambient_life"))
	_rng.seed = 3131
	root = Node3D.new()
	root.name = "OePNV"
	(game.get("entities") as Node3D).add_child(root)
	var data: Dictionary = city.graph.layout.get("transit", {})
	var qf: float = 1.0 / city.world.q
	for sv: Variant in data.get("stops", []):
		stops.append({"name": str(sv.name), "pos": Vector2(float(sv.pos[0]) * qf, float(sv.pos[1]) * qf), "modes": str(sv.get("modes", "")),
			"underground": false})
	for lv: Variant in data.get("lines", []):
		var flat: Array = lv.pts
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(0, flat.size(), 2):
			pts.append(Vector2(float(flat[i]) * qf, float(flat[i + 1]) * qf))
		if pts.size() < 2:
			continue
		var cum: PackedFloat32Array = PackedFloat32Array([0.0])
		for i2: int in range(1, pts.size()):
			cum.append(cum[i2 - 1] + pts[i2].distance_to(pts[i2 - 1]))
		var tun: Array = []
		for r: Variant in lv.get("tun_m", []):
			tun.append([float(r[0]), float(r[1])])
		for r2: Variant in lv.get("tun", []):   # älteres Format: Punktindizes
			tun.append([cum[int(r2[0])], cum[int(r2[1])]])
		var line: Dictionary = {"ref": str(lv.ref), "name": str(lv.name), "mode": str(lv.mode), "pts": pts, "cum": cum,
			"len": cum[cum.size() - 1], "stops": lv.stops, "s": lv.s, "tun": tun,
			"colour": Color.html(str(lv.colour)) if str(lv.colour).begins_with("#") else Color(0.85, 0.1, 0.1)}
		lines.append(line)
		for k: int in (lv.stops as Array).size():
			if _in_tunnel(line, float(lv.s[k])):
				stops[int(lv.stops[k])]["underground"] = true
	track_offset = float(data.get("track_offset", 0.0))
	_link_lines()
	_build_tunnels()
	# virtuelle Fahrzeuge im Takt verteilen
	for li: int in lines.size():
		var ln: Dictionary = lines[li]
		var spacing: float = float(HEADWAY.get(ln.mode, 200.0)) * float(SPEED.get(ln.mode, 11.0))
		var n: int = maxi(1, int(floor(float(ln.len) / spacing)))
		for k2: int in n:
			_spawn_virtual(li, float(k2) * spacing + _rng.randf() * 60.0)
	_board_point = TransitBoardPoint.new()
	_board_point.system = self
	root.add_child(_board_point)


func has_lines() -> bool:
	return not lines.is_empty()


## Pendelbetrieb: jede Linie erhält als Folgelinie die Gegenrichtung (gleiche Nummer, Anfang nahe dem eigenen Ende).
func _link_lines() -> void:
	for li: int in lines.size():
		var ln: Dictionary = lines[li]
		var endp: Vector2 = (ln.pts as PackedVector2Array)[(ln.pts as PackedVector2Array).size() - 1]
		var best: int = -1
		var best_d: float = 120.0
		for lj: int in lines.size():
			var o: Dictionary = lines[lj]
			if lj == li or o.mode != ln.mode:
				continue
			var d: float = endp.distance_to((o.pts as PackedVector2Array)[0]) + (0.0 if o.ref == ln.ref else 60.0)
			if d < best_d:
				best_d = d
				best = lj
		ln["next"] = best


func _spawn_virtual(li: int, s: float) -> void:
	var ln: Dictionary = lines[li]
	var k: int = 0
	var ss: Array = ln.s
	while k < ss.size() and float(ss[k]) < s:
		k += 1
	vehicles.append({"line": li, "s": s, "v": 0.0, "dwell": 0.0, "stop_k": k, "node": null, "segs": [], "id": _next_id, "blocked": 0.0})
	_next_id += 1


func _in_tunnel(ln: Dictionary, s: float) -> bool:
	for r: Array in ln.tun:
		if s >= float(r[0]) and s <= float(r[1]):
			return true
	return false


## Höhe über Grund entlang der Linie (Tunnel mit Rampen).
func height_at(ln: Dictionary, s: float) -> float:
	var y: float = 0.0
	for r: Array in ln.tun:
		var a: float = float(r[0])
		var b: float = float(r[1])
		if s >= a and s <= b:
			return TUNNEL_DEPTH
		if s < a and s > a - RAMP:
			y = minf(y, TUNNEL_DEPTH * (1.0 - (a - s) / RAMP))
		elif s > b and s < b + RAMP:
			y = minf(y, TUNNEL_DEPTH * (1.0 - (s - b) / RAMP))
	return y


## Punkt und Richtung auf der Linie bei Bogenlänge s.
func point_at(ln: Dictionary, s: float) -> Array:
	var cum: PackedFloat32Array = ln.cum
	var pts: PackedVector2Array = ln.pts
	if s < 0.0:
		var d0: Vector2 = (pts[1] - pts[0]).normalized()
		return [pts[0] + d0 * s, d0]
	if s > float(ln.len):
		var n: int = pts.size()
		var d1: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
		return [pts[n - 1] + d1 * (s - float(ln.len)), d1]
	var lo: int = 0
	var hi: int = cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg: float = maxf(cum[hi] - cum[lo], 0.001)
	var t: float = (s - cum[lo]) / seg
	var p: Vector2 = pts[lo].lerp(pts[hi], t)
	var d: Vector2 = (pts[hi] - pts[lo]).normalized()
	return [p, d]


func _process(delta: float) -> void:
	if lines.is_empty():
		return
	_t += delta
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cp: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	if city.env != null:
		city.env.set_underground((-cp.y - 1.5) / 2.5)
	if not enabled:
		for vh0: Dictionary in vehicles:
			if vh0.node != null:
				_free_node(vh0)
		_update_stops(cp)
		return
	for vh: Dictionary in vehicles:
		_advance(vh, delta)
		var ln: Dictionary = lines[int(vh.line)]
		var pd: Array = point_at(ln, float(vh.s))
		var p2: Vector2 = pd[0]
		var near: bool = Vector2(cp.x, cp.z).distance_to(p2) < VISIBLE_DIST or ride.get("veh") == vh
		if near and vh.node == null:
			_make_node(vh)
		elif not near and vh.node != null:
			_free_node(vh)
		if vh.node != null:
			_place_node(vh)
	_update_stops(cp)
	_update_ride(delta)


func _advance(vh: Dictionary, delta: float) -> void:
	var ln: Dictionary = lines[int(vh.line)]
	var vmax: float = float(SPEED.get(ln.mode, 11.0))
	if float(vh.dwell) > 0.0:
		vh.dwell = float(vh.dwell) - delta
		if float(vh.dwell) <= 0.0:
			vh.stop_k = int(vh.stop_k) + 1
			if int(vh.stop_k) >= (ln.stops as Array).size():
				# Endhaltestelle: Rückfahrt als Gegenrichtung (Folgelinie), sonst neuer Umlauf ab Linienanfang
				var nx: int = int(ln.get("next", -1))
				if nx >= 0:
					vh.line = nx
				vh.s = 0.0
				vh.stop_k = 0
				vh.v = 0.0
				if vh.node != null:
					_free_node(vh)   # Wagen wird in der neuen Richtung neu aufgebaut (Front vorn)
		return
	var next_s: float = float(ln.len)
	var k: int = int(vh.stop_k)
	if k < (ln.s as Array).size():
		next_s = float(ln.s[k])
	var dist: float = next_s - float(vh.s)
	var target_v: float = minf(vmax, sqrt(maxf(0.0, 2.0 * 1.1 * dist)) + 0.6)
	# Hindernis vor einem sichtbaren Fahrzeug -> bremsen (Vorrang, aber keine Kollision provozieren)
	if vh.node != null and float(vh.get("check_t", 0.0)) <= 0.0:
		vh.check_t = 0.25
		vh.blocked = _obstacle_ahead(vh)
	vh.check_t = float(vh.get("check_t", 0.0)) - delta
	var brake: float = 2.5
	if float(vh.blocked) > 0.0:
		# Bremskurve bis 5 m vor das Hindernis (Betriebsbremsung, notfalls stärker)
		target_v = minf(target_v, sqrt(maxf(0.0, 2.0 * 2.2 * (float(vh.blocked) - 5.0))))
		brake = 4.5
	var v: float = float(vh.v)
	v = move_toward(v, target_v, (1.2 if target_v > v else brake) * delta)
	vh.v = v
	vh.s = float(vh.s) + v * delta
	if dist <= 0.5 and k < (ln.s as Array).size():
		vh.s = next_s
		vh.v = 0.0
		vh.dwell = DWELL
		_on_arrive(vh, int(ln.stops[k]))


func _obstacle_ahead(vh: Dictionary) -> float:
	var segs: Array = vh.segs
	if segs.is_empty():
		return 0.0
	var front: Node3D = segs[0]
	if front.global_position.y < -3.0:
		return 0.0
	var fwd: Vector3 = -front.global_basis.z
	var space: PhysicsDirectSpaceState3D = front.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	var reach: float = 42.0   # Bremsweg bei 12,5 m/s ≈ 36 m
	box.size = Vector3(2.4, 1.6, reach)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	q.transform = Transform3D(front.global_basis, front.global_position + fwd * (TransitModels.TRAM_SEG * 0.5 + reach * 0.5) + Vector3.UP * 1.1)
	q.collision_mask = Layers.VEHICLE | Layers.PLAYER | Layers.NPC
	q.collide_with_areas = true
	var ex: Array[RID] = []
	for sg: Variant in segs:
		ex.append((sg as CollisionObject3D).get_rid())
	q.exclude = ex
	var hits: Array[Dictionary] = space.intersect_shape(q, 8)
	var best: float = 0.0
	for h: Dictionary in hits:
		var c: Node3D = h.collider as Node3D
		if c == null:
			continue
		if c.is_in_group("transit") and int(c.get_meta("line", -1)) != int(vh.line):
			continue
		var d: float = (c.global_position - front.global_position).dot(fwd) - TransitModels.TRAM_SEG * 0.5
		if d > 0.0 and (best == 0.0 or d < best):
			best = d
	if best > 0.0 and best < 12.0 and float(vh.get("bell_t", 0.0)) <= 0.0:
		vh.bell_t = 4.0
		AudioManager.play_3d("horn", front.global_position, -8.0, 1.6)
	vh.bell_t = float(vh.get("bell_t", 0.0)) - 0.25
	return best


func _make_node(vh: Dictionary) -> void:
	var ln: Dictionary = lines[int(vh.line)]
	var node := Node3D.new()
	node.name = "%s_%s_%d" % [ln.mode, ln.ref, int(vh.id)]
	root.add_child(node)
	var segs: Array = []
	var n: int = 3 if ln.mode == "tram" else (4 if ln.mode == "train" else 1)
	for i: int in n:
		var body := AnimatableBody3D.new()
		body.sync_to_physics = false
		body.add_to_group("transit")
		body.set_meta("line", int(vh.line))
		body.collision_layer = Layers.VEHICLE
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var L: float = TransitModels.TRAM_SEG if ln.mode != "bus" else TransitModels.BUS_L
		bs.size = Vector3(2.6, 3.0, L)
		cs.shape = bs
		cs.position = Vector3(0, 1.8, 0)
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var kind: String = "bus" if ln.mode == "bus" else ("tram_front" if i == 0 else "tram")
		mi.mesh = TransitModels.segment_mesh(kind, ln.colour)
		body.add_child(mi)
		if i == 0:
			var lbl: Label3D = TransitModels.destination_label(str(ln.ref), _dest_name(ln), ln.colour)
			lbl.position = Vector3(0, 3.1, -L * 0.5 - 0.1)
			lbl.rotation.y = PI
			body.add_child(lbl)
		node.add_child(body)
		segs.append(body)
	vh.node = node
	vh.segs = segs


func _dest_name(ln: Dictionary) -> String:
	var st: Array = ln.stops
	return str(stops[int(st[st.size() - 1])].name) if not st.is_empty() else ""


func _free_node(vh: Dictionary) -> void:
	if vh.node != null and is_instance_valid(vh.node):
		(vh.node as Node).queue_free()
	vh.node = null
	vh.segs = []


func _place_node(vh: Dictionary) -> void:
	var ln: Dictionary = lines[int(vh.line)]
	var L: float = TransitModels.TRAM_SEG if ln.mode != "bus" else TransitModels.BUS_L
	var off_side: float = 2.4 if ln.mode == "bus" else track_offset
	var s0: float = float(vh.s)
	var segs: Array = vh.segs
	for i: int in segs.size():
		var sc: float = s0 - L * 0.5 - float(i) * (L + TransitModels.TRAM_GAP)
		var pa: Array = point_at(ln, sc + L * 0.45)
		var pb: Array = point_at(ln, sc - L * 0.45)
		var a: Vector2 = pa[0]
		var b: Vector2 = pb[0]
		var dir: Vector2 = (a - b).normalized() if a.distance_to(b) > 0.01 else (pa[1] as Vector2)
		var right: Vector2 = Vector2(-dir.y, dir.x)
		var c: Vector2 = (a + b) * 0.5 + right * off_side
		var y: float = height_at(ln, sc) + (0.0 if ln.mode == "bus" else 0.02)
		var yaw: float = atan2(-dir.x, -dir.y)
		(segs[i] as Node3D).global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, y, c.y))


# ------------------------------------------------------------------ Tunnel (U-Strab)

const TUBE_H: float = 5.8        ## lichte Höhe der Röhre
const BOX_H: float = 4.9         ## Rampenbauwerk: Höhe über Gelände
const PIECE: float = 6.0         ## Stücklänge beim Aufbau
const STATION_HALF: float = 9.6  ## halbe Breite an U-Haltestellen (Bahnsteige beidseitig)
const STATION_LEN: float = 36.0  ## halbe Bahnsteiglänge

static var _tmats: Dictionary = {}


static func _tunnel_mat(key: String) -> Material:
	if _tmats.has(key):
		return _tmats[key]
	var m: Material
	match key:
		"t":
			m = MatLib.vertex_color(0.9)
		"l":
			m = MatLib.emissive(Color(1.0, 0.95, 0.86), 3.5)
		_:
			var b := StandardMaterial3D.new()
			b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			b.albedo_color = Color(0.01, 0.01, 0.012)
			m = b
	_tmats[key] = m
	return m


func _new_tunnel_kit() -> MeshKit:
	var kit := MeshKit.new()
	for k: String in ["t", "l", "b"]:
		kit.set_material(k, _tunnel_mat(k))
	return kit


## Röhren, U-Haltestellen und Rampenbauwerke aus den Tunnelbereichen der Linien. Deckungsgleiche Abschnitte
## (Gegenrichtung, mehrere Linien im selben Tunnel) werden nur einmal gebaut. Kamera-Kollision eigener Layer.
func _build_tunnels() -> void:
	tunnel_root = Node3D.new()
	tunnel_root.name = "Tunnel"
	root.add_child(tunnel_root)
	var half: float = 4.3 if track_offset > 0.0 else 5.6
	var built: Dictionary = {}
	var signed: Dictionary = {}
	var kit: MeshKit = _new_tunnel_kit()
	var faces := PackedVector3Array()
	var count: int = 0
	for ln: Dictionary in lines:
		if ln.mode == "bus":
			continue
		var st_ranges: Array = []
		for k: int in (ln.stops as Array).size():
			var sk: float = float(ln.s[k])
			if _in_tunnel(ln, sk):
				st_ranges.append([sk - STATION_LEN, sk + STATION_LEN, int(ln.stops[k]), sk])
		for r: Array in ln.tun:
			var r0: float = float(r[0])
			var r1: float = float(r[1])
			var s0: float = maxf(0.0, r0 - RAMP)
			var s1: float = minf(float(ln.len), r1 + RAMP)
			var n: int = maxi(1, ceili((s1 - s0) / PIECE))
			for i: int in n:
				var sa: float = s0 + (s1 - s0) * float(i) / float(n)
				var sb: float = s0 + (s1 - s0) * float(i + 1) / float(n)
				var a: Vector2 = point_at(ln, sa)[0]
				var b: Vector2 = point_at(ln, sb)[0]
				var mid: Vector2 = (a + b) * 0.5
				if _cell_seen(built, mid, 4.5):
					continue
				_cell_mark(built, mid)
				var ya: float = height_at(ln, sa)
				var yb: float = height_at(ln, sb)
				var sm: float = (sa + sb) * 0.5
				if sm >= r0 and sm <= r1:
					var station: Array = []
					for sr: Array in st_ranges:
						if sm >= float(sr[0]) and sm <= float(sr[1]):
							station = sr
					var hw: float = STATION_HALF if not station.is_empty() else half
					_tube_piece(kit, faces, a, b, ya, yb, hw, i % 3 == 0 or not station.is_empty())
					if not station.is_empty():
						_platform_piece(kit, a, b, ya, half)
						if sa - PIECE * 0.5 < float(station[0]):
							_tube_cap(kit, faces, a, (b - a).normalized(), ya, half, hw)
						if sb + PIECE * 0.5 > float(station[1]):
							_tube_cap(kit, faces, b, (a - b).normalized(), yb, half, hw)
						var si: int = int(station[2])
						if not signed.has(si):
							signed[si] = true
							_station_signs(ln, float(station[3]), si)
				else:
					var entering: bool = sm < r0
					_ramp_piece(kit, faces, a, b, ya, yb, half - 0.4)
					var outer: bool = (entering and sa <= s0 + 0.01 and s0 > 0.0) or (not entering and sb >= s1 - 0.01 and s1 < float(ln.len))
					if outer:
						var p_end: Vector2 = a if entering else b
						var outward: Vector2 = (a - b).normalized() if entering else (b - a).normalized()
						_portal(kit, p_end, outward, half - 0.4)
					var inner: bool = (entering and sb >= r0 - 0.01) or (not entering and sa <= r1 + 0.01)
					if inner:
						var p_in: Vector2 = b if entering else a
						var toward_ramp: Vector2 = (a - b).normalized() if entering else (b - a).normalized()
						_portal_back(kit, faces, p_in, toward_ramp, TUNNEL_DEPTH, half)
				count += 1
				if count % 40 == 0:
					_flush_tunnel(kit, faces)
					kit = _new_tunnel_kit()
					faces = PackedVector3Array()
	_flush_tunnel(kit, faces)


func _cell_seen(built: Dictionary, p: Vector2, r: float) -> bool:
	var c: Vector2i = Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			for q: Vector2 in built.get(c + Vector2i(dx, dz), []):
				if q.distance_to(p) < r:
					return true
	return false


func _cell_mark(built: Dictionary, p: Vector2) -> void:
	var c: Vector2i = Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	var arr: Array = built.get(c, [])
	arr.append(p)
	built[c] = arr


func _flush_tunnel(kit: MeshKit, faces: PackedVector3Array) -> void:
	if kit.is_empty():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tunnel_root.add_child(mi)
	if faces.size() >= 3:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.CAMERA_ONLY
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		cs.shape = sh
		body.add_child(cs)
		tunnel_root.add_child(body)


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


static func _add_faces(faces: PackedVector3Array, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	faces.append_array(PackedVector3Array([p0, p1, p2, p0, p2, p3]))


## Röhrenstück: Boden, Decke, Wände (nach innen sichtbar), optional Deckenleuchte.
func _tube_piece(kit: MeshKit, faces: PackedVector3Array, a0: Vector2, b0: Vector2, ya: float, yb: float, hw: float, lamp: bool) -> void:
	var d: Vector2 = (b0 - a0).normalized()
	var a: Vector2 = a0 - d * 0.3
	var b: Vector2 = b0 + d * 0.3
	var r: Vector2 = Vector2(-d.y, d.x)
	var aL: Vector2 = a - r * hw
	var aR: Vector2 = a + r * hw
	var bL: Vector2 = b - r * hw
	var bR: Vector2 = b + r * hw
	kit.color = Color(0.3, 0.3, 0.31)
	kit.add_quad("t", _v3(aL, ya), _v3(aR, ya), _v3(bR, yb), _v3(bL, yb), Vector3.UP)
	# Gleisbett (dunkler) je Richtung
	kit.color = Color(0.17, 0.16, 0.15)
	for off: float in ([-track_offset, track_offset] if track_offset > 0.0 else [0.0]):
		var c1: Vector2 = a + r * (off - 1.1)
		var c2: Vector2 = a + r * (off + 1.1)
		var c3: Vector2 = b + r * (off + 1.1)
		var c4: Vector2 = b + r * (off - 1.1)
		kit.add_quad("t", _v3(c1, ya + 0.03), _v3(c2, ya + 0.03), _v3(c3, yb + 0.03), _v3(c4, yb + 0.03), Vector3.UP)
	kit.color = Color(0.52, 0.52, 0.5)
	var h: float = TUBE_H
	kit.add_quad("t", _v3(aL, ya + h), _v3(aR, ya + h), _v3(bR, yb + h), _v3(bL, yb + h), Vector3.DOWN)
	kit.color = Color(0.62, 0.6, 0.56)
	kit.add_quad("t", _v3(aL, ya), _v3(bL, yb), _v3(bL, yb + h), _v3(aL, ya + h), Vector3(r.x, 0, r.y))
	kit.add_quad("t", _v3(aR, ya), _v3(bR, yb), _v3(bR, yb + h), _v3(aR, ya + h), Vector3(-r.x, 0, -r.y))
	_add_faces(faces, _v3(aL, ya + h), _v3(aR, ya + h), _v3(bR, yb + h), _v3(bL, yb + h))
	_add_faces(faces, _v3(aL, ya), _v3(bL, yb), _v3(bL, yb + h), _v3(aL, ya + h))
	_add_faces(faces, _v3(aR, ya), _v3(bR, yb), _v3(bR, yb + h), _v3(aR, ya + h))
	if lamp:
		var c: Vector2 = (a0 + b0) * 0.5
		var yaw: float = atan2(-d.x, -d.y)
		kit.color = Color.WHITE
		for off2: float in [-hw * 0.45, hw * 0.45]:
			var lp: Vector2 = c + r * off2
			kit.add_box("l", Vector3(lp.x, (ya + yb) * 0.5 + h - 0.08, lp.y), Vector3(0.35, 0.08, 2.6), Basis(Vector3.UP, yaw))


## Abschluss der Stationserweiterung (Stufe zwischen Röhre und Bahnsteighalle).
func _tube_cap(kit: MeshKit, faces: PackedVector3Array, p: Vector2, into: Vector2, y: float, hw_small: float, hw_big: float) -> void:
	var r: Vector2 = Vector2(-into.y, into.x)
	kit.color = Color(0.62, 0.6, 0.56)
	for sgn: float in [-1.0, 1.0]:
		var p0: Vector2 = p + r * (hw_small * sgn)
		var p1: Vector2 = p + r * (hw_big * sgn)
		kit.add_quad("t", _v3(p0, y), _v3(p1, y), _v3(p1, y + TUBE_H), _v3(p0, y + TUBE_H), Vector3(into.x, 0, into.y))
		_add_faces(faces, _v3(p0, y), _v3(p1, y), _v3(p1, y + TUBE_H), _v3(p0, y + TUBE_H))


## Bahnsteige beidseitig (außerhalb der Gleise) mit Kante und Stützen.
func _platform_piece(kit: MeshKit, a: Vector2, b: Vector2, y: float, inner: float) -> void:
	var d: Vector2 = (b - a).normalized()
	var r: Vector2 = Vector2(-d.y, d.x)
	var c: Vector2 = (a + b) * 0.5
	var L: float = a.distance_to(b) + 0.6
	var yaw: float = atan2(-d.x, -d.y)
	var w: float = STATION_HALF - inner - 0.1
	for sgn: float in [-1.0, 1.0]:
		var pc: Vector2 = c + r * sgn * (inner + w * 0.5)
		kit.color = Color(0.72, 0.7, 0.66)
		kit.add_box("t", Vector3(pc.x, y + 0.5, pc.y), Vector3(w, 1.0, L), Basis(Vector3.UP, yaw))
		var edge: Vector2 = c + r * sgn * (inner + 0.25)
		kit.color = Color(0.95, 0.85, 0.2)
		kit.add_box("t", Vector3(edge.x, y + 1.01, edge.y), Vector3(0.3, 0.02, L), Basis(Vector3.UP, yaw))
		kit.color = Color(0.55, 0.55, 0.57)
		var col: Vector2 = c + r * sgn * (inner + w * 0.7)
		kit.add_box("t", Vector3(col.x, y + 1.0 + (TUBE_H - 1.0) * 0.5, col.y), Vector3(0.5, TUBE_H - 1.0, 0.5), Basis(Vector3.UP, yaw))


func _station_signs(ln: Dictionary, s: float, si: int) -> void:
	var y: float = height_at(ln, s)
	for off: float in [-24.0, 0.0, 24.0]:
		var pd: Array = point_at(ln, s + off)
		var p: Vector2 = pd[0]
		var d: Vector2 = pd[1]
		var r: Vector2 = Vector2(-d.y, d.x)
		for sgn: float in [-1.0, 1.0]:
			var q: Vector2 = p + r * sgn * (STATION_HALF - 0.05)
			var l := Label3D.new()
			l.text = str(stops[si].name)
			l.font_size = 56
			l.pixel_size = 0.01
			l.modulate = Color(0.95, 0.95, 0.95)
			l.outline_size = 10
			l.outline_modulate = Color(0.05, 0.25, 0.55)
			l.position = Vector3(q.x, y + 3.2, q.y)
			l.rotation.y = atan2(-r.x * sgn, -r.y * sgn)
			l.visibility_range_end = 70.0
			tunnel_root.add_child(l)


## Rampe: Trog mit überdachtem Rampenbauwerk (verdeckt die Absenkung durch die Straßenoberfläche).
func _ramp_piece(kit: MeshKit, faces: PackedVector3Array, a0: Vector2, b0: Vector2, ya: float, yb: float, hw: float) -> void:
	var d: Vector2 = (b0 - a0).normalized()
	var a: Vector2 = a0 - d * 0.3
	var b: Vector2 = b0 + d * 0.3
	var r: Vector2 = Vector2(-d.y, d.x)
	var aL: Vector2 = a - r * hw
	var aR: Vector2 = a + r * hw
	var bL: Vector2 = b - r * hw
	var bR: Vector2 = b + r * hw
	var top: float = BOX_H
	kit.color = Color(0.3, 0.3, 0.31)
	kit.add_quad("t", _v3(aL, ya + 0.02), _v3(aR, ya + 0.02), _v3(bR, yb + 0.02), _v3(bL, yb + 0.02), Vector3.UP)
	kit.color = Color(0.6, 0.59, 0.56)
	# Innenwände
	kit.add_quad("t", _v3(aL, ya), _v3(bL, yb), _v3(bL, top), _v3(aL, top), Vector3(r.x, 0, r.y))
	kit.add_quad("t", _v3(aR, ya), _v3(bR, yb), _v3(bR, top), _v3(aR, top), Vector3(-r.x, 0, -r.y))
	# Außenwände (über Gelände) und Dach
	kit.color = Color(0.66, 0.65, 0.62)
	var oL_a: Vector2 = a - r * (hw + 0.3)
	var oL_b: Vector2 = b - r * (hw + 0.3)
	var oR_a: Vector2 = a + r * (hw + 0.3)
	var oR_b: Vector2 = b + r * (hw + 0.3)
	kit.add_quad("t", _v3(oL_a, -0.3), _v3(oL_b, -0.3), _v3(oL_b, top + 0.3), _v3(oL_a, top + 0.3), Vector3(-r.x, 0, -r.y))
	kit.add_quad("t", _v3(oR_a, -0.3), _v3(oR_b, -0.3), _v3(oR_b, top + 0.3), _v3(oR_a, top + 0.3), Vector3(r.x, 0, r.y))
	kit.color = Color(0.42, 0.5, 0.36)
	kit.add_quad("t", _v3(oL_a, top + 0.3), _v3(oR_a, top + 0.3), _v3(oR_b, top + 0.3), _v3(oL_b, top + 0.3), Vector3.UP)
	kit.color = Color(0.5, 0.5, 0.49)
	kit.add_quad("t", _v3(aL, top), _v3(aR, top), _v3(bR, top), _v3(bL, top), Vector3.DOWN)
	_add_faces(faces, _v3(aL, ya), _v3(bL, yb), _v3(bL, top), _v3(aL, top))
	_add_faces(faces, _v3(aR, ya), _v3(bR, yb), _v3(bR, top), _v3(aR, top))
	_add_faces(faces, _v3(aL, top), _v3(aR, top), _v3(bR, top), _v3(bL, top))


## Portal (Einfahrt ins Rampenbauwerk): Rahmen und dunkle Öffnung (nur von außen sichtbar).
func _portal(kit: MeshKit, p: Vector2, outward: Vector2, hw: float) -> void:
	var r: Vector2 = Vector2(-outward.y, outward.x)
	var q: Vector2 = p + outward * 0.05
	var n3: Vector3 = Vector3(outward.x, 0, outward.y)
	kit.add_quad("b", _v3(q - r * hw, 0.0), _v3(q + r * hw, 0.0), _v3(q + r * hw, BOX_H), _v3(q - r * hw, BOX_H), n3)
	var yaw: float = atan2(-outward.x, -outward.y)
	kit.color = Color(0.72, 0.71, 0.68)
	var f: Vector2 = p + outward * 0.25
	kit.add_box("t", Vector3(f.x, BOX_H + 0.1, f.y), Vector3(hw * 2.0 + 1.2, 0.8, 0.5), Basis(Vector3.UP, yaw))
	for sgn: float in [-1.0, 1.0]:
		var c: Vector2 = f + r * sgn * (hw + 0.3)
		kit.add_box("t", Vector3(c.x, BOX_H * 0.5, c.y), Vector3(0.6, BOX_H, 0.5), Basis(Vector3.UP, yaw))
	# Schild „U“
	kit.color = Color(0.1, 0.3, 0.65)
	kit.add_box("t", Vector3(f.x, BOX_H + 0.1, f.y) + n3 * 0.27, Vector3(1.2, 0.6, 0.04), Basis(Vector3.UP, yaw))


## Stirnwand am Übergang Rampenbauwerk -> Röhre (zwischen Röhrendecke und Dach des Bauwerks).
func _portal_back(kit: MeshKit, faces: PackedVector3Array, p: Vector2, toward_ramp: Vector2, depth: float, hw: float) -> void:
	var r: Vector2 = Vector2(-toward_ramp.y, toward_ramp.x)
	var y0: float = depth + TUBE_H
	kit.color = Color(0.55, 0.55, 0.53)
	var n3: Vector3 = Vector3(toward_ramp.x, 0, toward_ramp.y)
	kit.add_quad("t", _v3(p - r * hw, y0), _v3(p + r * hw, y0), _v3(p + r * hw, BOX_H), _v3(p - r * hw, BOX_H), n3)
	_add_faces(faces, _v3(p - r * hw, y0), _v3(p + r * hw, y0), _v3(p + r * hw, BOX_H), _v3(p - r * hw, BOX_H))


# ------------------------------------------------------------------ Haltestellen

func _update_stops(cp: Vector3) -> void:
	for si: int in stops.size():
		var st: Dictionary = stops[si]
		var d: float = Vector2(cp.x, cp.z).distance_to(st.pos)
		var has: bool = _stop_nodes.has(si)
		if d < STOP_SHOW_DIST and not has:
			var n: Node3D = TransitModels.stop_shelter(str(st.name), bool(st.underground))
			root.add_child(n)
			var side: Vector2 = _stop_side(si)
			var p2: Vector2 = (st.pos as Vector2) + side * (5.5 if not bool(st.underground) else 9.0)
			n.global_position = Vector3(p2.x, city.ground_y(p2), p2.y)
			n.rotation.y = atan2(side.x, side.y)
			_stop_nodes[si] = n
			_spawn_waiting(si, n, 1 + _rng.randi() % 3)
		elif d > STOP_SHOW_DIST + 60.0 and has:
			(_stop_nodes[si] as Node).queue_free()
			_stop_nodes.erase(si)
			for a: Variant in _waiting.get(si, []):
				if is_instance_valid(a):
					(a as Node).queue_free()
			_waiting.erase(si)
		elif has and d < 90.0 and (_waiting.get(si, []) as Array).is_empty() and _rng.randf() < 0.004:
			_spawn_waiting(si, _stop_nodes[si], 1 + _rng.randi() % 2)   # neue Fahrgäste kommen nach


## Wartende Fahrgäste am Wartehäuschen (bzw. am Abgang der U-Haltestelle).
func _spawn_waiting(si: int, shelter: Node3D, n: int) -> void:
	if game.get("peds") == null or not bool(game.get("ambient_life")) or Settings.max_pedestrians() <= 0:
		return
	var arr: Array = []
	for i: int in n:
		var a := EventActor.new()
		root.add_child(a)
		a.setup(city, _rng.randi(), EventActor.look_for(_rng))
		a.remove_from_group("event_actors")   # Fahrgäste gehören zu keinem Ereignis
		a.add_to_group("transit_passengers")
		var off: Vector3 = shelter.global_basis.x * _rng.randf_range(-1.6, 1.6) + shelter.global_basis.z * _rng.randf_range(0.6, 1.8)
		a.place(shelter.global_position + off)
		a.rotation.y = shelter.rotation.y + PI + _rng.randf_range(-0.6, 0.6)
		arr.append(a)
	_waiting[si] = arr


## Seite (rechts der ersten Linie, die hier hält) für das Wartehäuschen.
func _stop_side(si: int) -> Vector2:
	for ln: Dictionary in lines:
		var st: Array = ln.stops
		for k: int in st.size():
			if int(st[k]) == si:
				var pd: Array = point_at(ln, float(ln.s[k]))
				var d: Vector2 = pd[1]
				return Vector2(-d.y, d.x)
	return Vector2.RIGHT


func stop_world_pos(si: int) -> Vector3:
	var p: Vector2 = stops[si].pos
	return Vector3(p.x, city.ground_y(p), p.y)


func _on_arrive(vh: Dictionary, si: int) -> void:
	if vh.node == null:
		return
	# Fahrgäste steigen aus/ein (kosmetisch; nur an sichtbaren Haltestellen an der Oberfläche)
	if not bool(stops[si].underground):
		var n_out: int = _rng.randi() % 3
		for i: int in n_out:
			var a := EventActor.new()
			root.add_child(a)
			a.setup(city, _rng.randi(), EventActor.look_for(_rng))
			a.remove_from_group("event_actors")
			a.add_to_group("transit_passengers")
			var door: Vector3 = (vh.segs[0] as Node3D).global_position + (vh.segs[0] as Node3D).global_basis.x * 2.0
			a.place(door)
			a.go_to(door + Vector3(_rng.randf_range(-12, 12), 0, _rng.randf_range(-12, 12)), 1.4)
			get_tree().create_timer(14.0).timeout.connect(a.queue_free)
		# Wartende Fahrgäste und Passanten in der Nähe steigen ein (gehen zur Tür und verschwinden)
		var door2: Vector3 = (vh.segs[0] as Node3D).global_position + (vh.segs[0] as Node3D).global_basis.x * 1.6
		for w: Variant in _waiting.get(si, []):
			if is_instance_valid(w):
				var wa: EventActor = w
				wa.go_to(door2 + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), 1.5)
				get_tree().create_timer(DWELL * 0.7).timeout.connect(wa.queue_free)
		_waiting[si] = []
		var boarded: int = 0
		for p: Node in get_tree().get_nodes_in_group("pedestrians"):
			var ped: Node3D = p as Node3D
			if boarded < 3 and ped != null and ped.has_method("board_transit") and ped.global_position.distance_to(stop_world_pos(si)) < 16.0 \
					and _rng.randf() < 0.5:
				ped.call("board_transit", door2)
				boarded += 1
	if ride.get("veh") == vh:
		var ln: Dictionary = lines[int(vh.line)]
		EventBus.notify.emit("Halt: %s" % str(stops[si].name), "info")
		if bool(ride.get("want_exit", false)) or int(vh.stop_k) >= (ln.stops as Array).size() - 1:
			alight(si)


# ------------------------------------------------------------------ Mitfahren

## Fahrzeug, das an einer Haltestelle nahe p steht (für den Einstieg).
func dwelling_near(p: Vector3, r: float = 12.0) -> Dictionary:
	for vh: Dictionary in vehicles:
		if float(vh.dwell) <= 0.0:
			continue
		var ln: Dictionary = lines[int(vh.line)]
		var k: int = int(vh.stop_k)
		if k >= (ln.stops as Array).size():
			continue
		var si: int = int(ln.stops[k])
		var sp: Vector3 = stop_world_pos(si)
		if Vector2(sp.x - p.x, sp.z - p.z).length() < r + (10.0 if bool(stops[si].underground) else 0.0):
			return vh
	return {}


func board(vh: Dictionary) -> bool:
	var p: Player = game.get("player") as Player
	if p == null or p.is_in_vehicle() or not ride.is_empty():
		return false
	if GameState.money < FARE:
		EventBus.notify.emit("Kein Geld für den Fahrschein.", "warnung")
		return false
	GameState.add_money(-FARE)
	var ln: Dictionary = lines[int(vh.line)]
	var si: int = int(ln.stops[int(vh.stop_k)])
	ride = {"veh": vh, "board_stop": si, "want_exit": false}
	if vh.node == null:
		_make_node(vh)
		_place_node(vh)
	p.begin_ride(vh.segs[(vh.segs as Array).size() - 1])
	EventBus.notify.emit("Eingestiegen: Linie %s Richtung %s (Fahrschein %d €). E = am nächsten Halt aussteigen" % [ln.ref, _dest_name(ln), FARE], "info")
	GameState.add_stat("oepnv_fahrten")
	return true


func request_exit() -> void:
	if not ride.is_empty():
		ride["want_exit"] = true
		EventBus.notify.emit("Haltewunsch: Ausstieg an der nächsten Haltestelle.", "info")


func alight(si: int) -> void:
	var p: Player = game.get("player") as Player
	if p == null or ride.is_empty():
		return
	var board_si: int = int(ride.board_stop)
	ride = {}
	var sp: Vector3 = stop_world_pos(si)
	var side: Vector2 = _stop_side(si)
	var pos: Vector3 = sp + Vector3(side.x, 0, side.y) * (3.6 if not bool(stops[si].underground) else 8.0) + Vector3.UP * 0.2
	city.ensure_loaded(pos)
	pos.y = city.ground_y(Vector2(pos.x, pos.z)) + 0.1
	p.end_ride(pos)
	game.set("ride_info", "")
	ride_log.append({"from": str(stops[board_si].name), "to": str(stops[si].name)})
	EventBus.notify.emit("Ausgestiegen: %s" % str(stops[si].name), "info")


## Fahrt ohne Ausstieg an einer Haltestelle beenden (Teleport, Neustart, Respawn).
func cancel_ride() -> void:
	ride = {}
	game.set("ride_info", "")


func _update_ride(_delta: float) -> void:
	if ride.is_empty():
		return
	var p: Player = game.get("player") as Player
	if p == null or not p.is_riding():
		cancel_ride()   # z. B. durch Respawn/Neustart beendet
		return
	var vh: Dictionary = ride.veh
	var ln: Dictionary = lines[int(vh.line)]
	var k: int = mini(int(vh.stop_k) + (1 if float(vh.dwell) > 0.0 else 0), (ln.stops as Array).size() - 1)
	var hud_text: String = "Linie %s · Nächster Halt: %s%s" % [ln.ref, str(stops[int(ln.stops[k])].name), "  (Haltewunsch)" if bool(ride.want_exit) else ""]
	game.set("ride_info", hud_text)


## Für Missionen: ist der Spieler (zuletzt) zwischen zwei Haltestellen gefahren? (Namensteile genügen)
func player_rode_between(from_name: String, to_name: String) -> bool:
	for r: Dictionary in ride_log:
		if str(r.from).contains(from_name) and str(r.to).contains(to_name):
			return true
	return false


## Nur für Tests: Fahrt eintragen.
func debug_mark_ride(from_name: String, to_name: String) -> void:
	ride_log.append({"from": from_name, "to": to_name})


## Tests/Screenshot-Tour: ein Fahrzeug der passenden Linie an (oder `before` m vor) die Haltestelle setzen.
## Rückgabe: Fahrzeug-Dictionary (leer, wenn keine Linie hält).
func debug_place_at_stop(name_part: String, mode: String, before: float = 0.0) -> Dictionary:
	for li: int in lines.size():
		var ln: Dictionary = lines[li]
		if ln.mode != mode:
			continue
		for k: int in (ln.stops as Array).size() - 1:
			if not str(stops[int(ln.stops[k])].name).contains(name_part):
				continue
			for vh: Dictionary in vehicles:
				if int(vh.line) != li or ride.get("veh") == vh:
					continue
				vh.s = float(ln.s[k]) - before
				vh.stop_k = k
				vh.v = 0.0 if before <= 0.0 else 8.0
				vh.dwell = DWELL * 3.0 if before <= 0.0 else 0.0
				if vh.node != null:
					_free_node(vh)
				_make_node(vh)
				_place_node(vh)
				return vh
	return {}


func stop_index(name_part: String) -> int:
	for si: int in stops.size():
		if str(stops[si].name).contains(name_part):
			return si
	return -1


func is_riding() -> bool:
	return not ride.is_empty()


func ride_speed() -> float:
	return float((ride.veh as Dictionary).v) if not ride.is_empty() else 0.0
