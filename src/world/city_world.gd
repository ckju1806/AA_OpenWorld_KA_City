class_name CityWorld
extends Node3D
## Spielwelt "Fächer-City": baut die Stadt deterministisch aus data/world/karlsruhe_layout.json
## und stellt die gemeinsame Datenbasis (CityGraph) für Verkehr, Polizei, Missionen und Karte bereit.

var graph: CityGraph
var blocks: Array[Dictionary] = []
var env: EnvironmentSetup
var build_ms: int = 0
var slab_h: float = 0.12


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	graph = CityGraphBuilder.build_from_file()
	slab_h = float(graph.layout.get("slab_height", 0.12))
	blocks = GroundBuilder.build(self, graph)
	BuildingBuilder.build(self, graph, blocks)
	LandmarkBuilder.build(self, graph)
	PropsBuilder.build(self, graph, blocks)
	env = EnvironmentSetup.new()
	env.name = "Umgebung"
	add_child(env)
	env.setup(PropsBuilder.lamp_heads)
	build_ms = Time.get_ticks_msec() - t0
	print("[Welt] Stadt aufgebaut in %d ms: %d Knoten, %d Kanten, %d Blöcke, %d Parzellen, %d Laternen" % [
		build_ms, graph.node_count(), graph.edge_count(), blocks.size(), BuildingBuilder.lots.size(), PropsBuilder.lamp_heads.size()])


func get_spawn() -> Transform3D:
	var p: Vector3 = graph.poi_pos3("spawn", slab_h + 0.05)
	return Transform3D(Basis(Vector3.UP, graph.poi_yaw("spawn")), p)


## Bodenhöhe an einer Position (Platten 0,12 m, Straße 0).
func ground_y(p: Vector2) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 30.0, p.y), Vector3(p.x, -2.0, p.y), Layers.WORLD)
	var hit: Dictionary = space.intersect_ray(q)
	return float((hit.position as Vector3).y) if not hit.is_empty() else 0.0


func poi_position(poi_id: String) -> Vector3:
	var p: Vector3 = graph.poi_pos3(poi_id)
	return Vector3(p.x, ground_y(Vector2(p.x, p.z)), p.z)


func get_parked_vehicles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pv: Variant in graph.layout.get("parked_vehicles", []):
		var d: Dictionary = pv
		var spec_id: String = str(d.spec)
		var spec: VehicleSpec = VehicleSpec.get_spec(spec_id)
		var ci: int = int(DetRng.hash01(int(d.pos[0]), int(d.pos[1]), 5) * spec.colors.size()) % spec.colors.size()
		out.append({
			"spec": spec_id, "position": Vector3(float(d.pos[0]), 0.0, float(d.pos[1])),
			"yaw": deg_to_rad(float(d.get("yaw", 0.0))), "color": spec.colors[ci],
			"ownership": Vehicle.Ownership.PARKED_FOREIGN, "locked": bool(d.get("locked", false)),
		})
	return out


## Bergungspunkt: nächster Punkt auf einer befahrbaren Straße (rechte Fahrspur), max. 30 m entfernt.
func find_recovery_point(pos: Vector3, _spec: VehicleSpec) -> Dictionary:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var near: Dictionary = graph.nearest_edge_point(p2, "drive")
	if int(near.edge) < 0 or float(near.dist) > 30.0:
		return {"ok": false}
	var e: int = near.edge
	var a: Vector2 = graph.node_pos[graph.edge_a[e]]
	var b: Vector2 = graph.node_pos[graph.edge_b[e]]
	var dir: Vector2 = (b - a).normalized()
	# Fahrtrichtung so wählen, dass sie zur bisherigen Blickrichtung passt
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var pt: Vector2 = near.point
	var lane: Vector2 = pt + right * 2.6
	var yaw: float = atan2(-dir.x, -dir.y)
	return {"ok": true, "position": Vector3(lane.x, 0.0, lane.y), "yaw": yaw}


## Nächster Respawn-Punkt (Klinik oder Revier).
func respawn_point(kind: String) -> Transform3D:
	var id: String = "klinikum" if kind == "klinik" else "revier"
	return Transform3D(Basis(Vector3.UP, graph.poi_yaw(id)), poi_position(id) + Vector3.UP * 0.05)
