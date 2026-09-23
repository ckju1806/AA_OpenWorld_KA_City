extends TestCase
## Straßengraph der Stadt: Aufbau, Planarität, Zusammenhang, Sackgassen, Blöcke, Wegsuche.

static var _g: CityGraph


func _graph() -> CityGraph:
	if _g == null:
		_g = CityGraphBuilder.build_from_file()
	return _g


func test_graph_builds() -> void:
	var g: CityGraph = _graph()
	assert_gt(float(g.node_count()), 80.0, "Knotenanzahl")
	assert_gt(float(g.edge_count()), 100.0, "Kantenanzahl")
	print("        Graph: %d Knoten, %d Kanten, %d Flächen" % [g.node_count(), g.edge_count(), g.faces.size()])


func test_no_crossing_edges() -> void:
	var g: CityGraph = _graph()
	var crossings: int = 0
	for i: int in g.edge_count():
		var a1: Vector2 = g.node_pos[g.edge_a[i]]
		var b1: Vector2 = g.node_pos[g.edge_b[i]]
		for j: int in range(i + 1, g.edge_count()):
			if g.edge_a[j] == g.edge_a[i] or g.edge_a[j] == g.edge_b[i] or g.edge_b[j] == g.edge_a[i] or g.edge_b[j] == g.edge_b[i]:
				continue
			var ip: Variant = Geometry2D.segment_intersects_segment(a1, b1, g.node_pos[g.edge_a[j]], g.node_pos[g.edge_b[j]])
			if ip != null:
				crossings += 1
				if crossings < 4:
					fail("Kreuzung ohne Knoten: Kante %d / %d bei %s" % [i, j, str(ip)])
	assert_eq(crossings, 0, "Anzahl Kreuzungen ohne Knoten")


func test_drive_network_connected() -> void:
	var g: CityGraph = _graph()
	assert_eq(g.component_count("drive"), 1, "Befahrbares Netz zusammenhängend")
	assert_eq(g.component_count("traffic"), 1, "Verkehrsnetz zusammenhängend")
	assert_eq(g.component_count("all"), 1, "Gesamtnetz zusammenhängend")


func test_no_dead_ends_for_traffic() -> void:
	var g: CityGraph = _graph()
	for n: int in g.node_count():
		var d: int = g.degree(n, "traffic")
		if d == 1:
			fail("Sackgasse im Verkehrsnetz bei %s" % str(g.node_pos[n]))
		if g.degree(n, "all") == 1:
			fail("Sackgasse im Gesamtnetz bei %s" % str(g.node_pos[n]))


func test_blocks_and_park() -> void:
	var g: CityGraph = _graph()
	var parks: int = 0
	var blocks: int = 0
	for f: Dictionary in g.faces:
		if f.kind == "park":
			parks += 1
		else:
			blocks += 1
	assert_eq(parks, 1, "Schlossbezirk als Park erkannt")
	assert_gt(float(blocks), 40.0, "Anzahl Häuserblöcke")
	assert_gt(float(g.outer_boundary.size()), 10.0, "Außenrand gefunden")


func test_fan_streets_start_at_zirkel() -> void:
	var g: CityGraph = _graph()
	# Jeder Fächerstrahl beginnt auf dem Zirkel (r = 200) an einem Knoten
	for ang: float in [-45.0, -33.75, -22.5, -11.25, 0.0, 11.25, 22.5, 33.75, 45.0]:
		var p: Vector2 = PolyUtil.polar(Vector2.ZERO, 200.0, ang)
		var n: int = g.nearest_node(p, "all")
		assert_lt(g.node_pos[n].distance_to(p), 1.0, "Knoten am Zirkel für Winkel %.2f" % ang)
		assert_true(g.degree(n, "all") >= 3, "Einmündung am Zirkel (Winkel %.2f)" % ang)


func test_paths_between_pois() -> void:
	var g: CityGraph = _graph()
	var ids: Array[String] = ["hanne", "baeckerei_parken", "kanzlei_parken", "rennwagen", "riegel_wagen", "lager", "maeule", "klinikum", "revier"]
	var start: int = g.nearest_node(Vector2(560, 640), "drive")  # Südost-Ecke des Rundkurses
	for id: String in ids:
		var p3: Vector3 = g.poi_pos3(id)
		var target: int = g.nearest_node(Vector2(p3.x, p3.z), "drive")
		var path: PackedInt32Array = g.find_path(start, target, "drive")
		assert_gt(float(path.size()), 1.0, "Weg zum POI %s" % id)
