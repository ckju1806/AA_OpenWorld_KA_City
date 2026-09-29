extends TestCase
## Straßengraph aus den Weltdaten (Karlsruhe 1:1): Aufbau, Planarität, Zusammenhang, Rasterindex,
## Fächerstruktur, Wegsuche zwischen Missionsorten, Speicherbudget der Weltdaten.

static var _w: WorldData
static var _g: CityGraph


func _graph() -> CityGraph:
	if _g == null:
		_w = WorldData.load_world()
		_g = CityGraph.from_world(_w)
	return _g


func test_graph_builds() -> void:
	var g: CityGraph = _graph()
	assert_gt(float(g.node_count()), 5000.0, "Knotenanzahl (große Stadt)")
	assert_gt(float(g.edge_count()), 5000.0, "Kantenanzahl")
	assert_gt(_w.bounds.size.x, 15000.0, "Kartenbreite > 15 km (1:1)")
	assert_gt(_w.bounds.size.y, 9000.0, "Kartenhöhe > 9 km (1:1)")
	print("        Graph: %d Knoten, %d Kanten, %d Sektoren, Quelle %s" % [g.node_count(), g.edge_count(), _w.sectors.size(), _w.meta.get("source", "?")])


func test_no_crossing_edges() -> void:
	var g: CityGraph = _graph()
	var crossings: int = 0
	for i: int in g.edge_count():
		var a1: Vector2 = g.node_pos[g.edge_a[i]]
		var b1: Vector2 = g.node_pos[g.edge_b[i]]
		for j: int in g.edges_near((a1 + b1) * 0.5, a1.distance_to(b1) * 0.5 + 1.0):
			if j <= i:
				continue
			if g.edge_a[j] == g.edge_a[i] or g.edge_a[j] == g.edge_b[i] or g.edge_b[j] == g.edge_a[i] or g.edge_b[j] == g.edge_b[i]:
				continue
			# Brücken/Tunnel kreuzen andere Wege planmäßig ohne gemeinsamen Knoten (OSM)
			if g.is_bridge(i) or g.is_bridge(j) or g.is_tunnel(i) or g.is_tunnel(j):
				continue
			var ip: Variant = Geometry2D.segment_intersects_segment(a1, b1, g.node_pos[g.edge_a[j]], g.node_pos[g.edge_b[j]])
			if ip != null:
				crossings += 1
				if crossings < 4:
					fail("Kreuzung ohne Knoten: Kante %d / %d bei %s" % [i, j, str(ip)])
	assert_eq(crossings, 0, "Anzahl Kreuzungen ohne Knoten")


func test_spatial_index_matches_brute_force() -> void:
	var g: CityGraph = _graph()
	var rng := DetRng.make_rng(5)
	for k: int in 40:
		var p: Vector2 = Vector2(rng.randf_range(-3000, 3000), rng.randf_range(-1500, 3000))
		var fast: Dictionary = g.nearest_edge_point(p, "drive", 5000.0)
		var best: float = INF
		for e: int in g.edge_count():
			if g.is_drivable(e):
				best = minf(best, PolyUtil.dist_point_segment(p, g.node_pos[g.edge_a[e]], g.node_pos[g.edge_b[e]]))
		assert_near(float(fast.dist), best, 0.01, "Nächste Kante über Rasterindex = Brute-Force (%s)" % str(p))


func test_drive_network_connected() -> void:
	var g: CityGraph = _graph()
	# Echte Kartendaten: Randgebiete hängen teils nur außerhalb des Kartenausschnitts zusammen. Gefordert ist daher,
	# dass (nahezu) das gesamte Netz eine Komponente bildet und alle Spielorte darin liegen (siehe test_paths_between_pois).
	for mode: String in ["drive", "traffic"]:
		var sizes: Array[int] = g.component_sizes(mode)
		var total: int = 0
		for sz: int in sizes:
			total += sz
		assert_gt(float(sizes[0]) / float(maxi(total, 1)), 0.97, "%s-Netz: größte Komponente %d von %d Knoten (%d Komponenten)" % [mode, sizes[0], total, sizes.size()])


func test_few_dead_ends_for_traffic() -> void:
	var g: CityGraph = _graph()
	var dead: int = 0
	for n: int in g.node_count():
		if g.degree(n, "traffic") == 1:
			dead += 1
	assert_lt(float(dead), float(g.node_count()) * 0.02, "Sackgassen im Verkehrsnetz < 2 %% (%d)" % dead)


func test_fan_streets_start_at_zirkel() -> void:
	var g: CityGraph = _graph()
	# Jede der neun Fächerstraßen hat einen gemeinsamen Knoten mit dem Zirkel (Einmündung) – quellenunabhängig über Namen
	var zirkel: Dictionary = {}
	for e: int in g.edge_count():
		if g.edge_name(e) == "Zirkel":
			zirkel[g.edge_a[e]] = true
			zirkel[g.edge_b[e]] = true
	assert_gt(float(zirkel.size()), 5.0, "Zirkel im Netz")
	for street: String in ["Waldstraße", "Herrenstraße", "Ritterstraße", "Lammstraße", "Karl-Friedrich-Straße", "Kreuzstraße",
			"Adlerstraße", "Kronenstraße", "Waldhornstraße"]:
		var joins: bool = false
		var exists: bool = false
		for e2: int in g.edge_count():
			if g.edge_name(e2) != street:
				continue
			exists = true
			if zirkel.has(g.edge_a[e2]) or zirkel.has(g.edge_b[e2]):
				var n: int = g.edge_a[e2] if zirkel.has(g.edge_a[e2]) else g.edge_b[e2]
				joins = joins or g.node_pos[n].length() < 400.0
		assert_true(exists, "%s im Netz" % street)
		assert_true(joins, "%s mündet in den Zirkel" % street)


func test_landmark_positions_real_scale() -> void:
	var g: CityGraph = _graph()
	var hbf: Vector3 = g.poi_pos3("spawn")
	assert_lt(Vector2(hbf.x, hbf.z).distance_to(Vector2(0, 500)), 60.0, "Start am Marktplatz ~500 m südlich des Schlosses")
	var found: Dictionary = {}
	for lm: Variant in g.layout.landmarks:
		found[str(lm.type)] = Vector2(float(lm.pos[0]), float(lm.pos[1]))
	for t: String in ["schloss", "pyramide", "hauptbahnhof", "zoo"]:
		assert_true(found.has(t), "Landmarke vorhanden: %s" % t)
	# Schloss -> Hauptbahnhof real ca. 2,2–2,3 km
	var d: float = (found["schloss"] as Vector2).distance_to(found["hauptbahnhof"])
	assert_gt(d, 2000.0, "Schloss–Hbf > 2 km (%.0f m)" % d)
	assert_lt(d, 2500.0, "Schloss–Hbf < 2,5 km (%.0f m)" % d)


func test_paths_between_pois() -> void:
	var g: CityGraph = _graph()
	var ids: Array[String] = ["depot_van", "baeckerei_parken", "kanzlei_parken", "rennwagen", "riegel_wagen", "lager", "maeule",
		"klinikum", "revier", "m2_cp01", "m2_cp06", "m2_cp12"]
	var start: int = g.nearest_node(Vector2(-18, 505), "drive")
	for id: String in ids:
		var p: Vector3 = g.poi_pos3(id)
		assert_true(p != Vector3.ZERO, "POI vorhanden: %s" % id)
		var n: int = g.nearest_node(Vector2(p.x, p.z), "drive")
		var path: PackedInt32Array = g.find_path(start, n, "drive")
		assert_gt(float(path.size()), 1.0, "Weg zu %s" % id)


func test_world_data_budget() -> void:
	var total: int = 0
	var dir := DirAccess.open(WorldData.DIR)
	assert_true(dir != null, "Weltdatenordner vorhanden")
	for f: String in dir.get_files():
		if not f.ends_with(".import"):
			total += FileAccess.get_file_as_bytes(WorldData.DIR + f).size()
	for sub: String in ["sectors", "lod"]:
		var d2 := DirAccess.open(WorldData.DIR + sub)
		for f2: String in d2.get_files():
			total += FileAccess.get_file_as_bytes(WorldData.DIR + sub + "/" + f2).size()
	assert_lt(float(total), 40.0 * 1048576.0, "Weltdaten im Speicherbudget (%.1f MB)" % (float(total) / 1048576.0))


## NPC-Fahrten in Aufträgen (Verfolgen/Begleiten) halten Einbahnstraßen ein (Modus "drive_dir").
func test_npc_routes_respect_one_way() -> void:
	var g: CityGraph = _graph()
	var oneways: int = 0
	for route: Array in [["kunde_wagen", "kunde_ziel"], ["vesper_transporter", "vesper_halle"], ["mira_wagen2", "revier"]]:
		var a: Vector3 = g.poi_pos3(str(route[0]))
		var b: Vector3 = g.poi_pos3(str(route[1]))
		var path: PackedInt32Array = g.find_path(g.nearest_node(Vector2(a.x, a.z), "drive_dir"),
			g.nearest_node(Vector2(b.x, b.z), "drive_dir"), "drive_dir")
		assert_gt(float(path.size()), 1.0, "Weg %s -> %s gefunden" % route)
		var wrong: int = 0
		for i: int in range(1, path.size()):
			var e: int = g.find_edge(path[i - 1], path[i])
			if e >= 0 and g.is_oneway(e):
				oneways += 1
				if not g.can_leave(e, path[i - 1]):
					wrong += 1
		assert_eq(wrong, 0, "Keine Einbahnstraße gegen die Richtung (%s -> %s)" % route)
	# Gegenprobe: das Netz enthält auf diesen Routen tatsächlich Einbahnstraßen (Test prüft etwas)
	assert_gt(float(oneways), 0.0, "Routen führen über Einbahnstraßen")
