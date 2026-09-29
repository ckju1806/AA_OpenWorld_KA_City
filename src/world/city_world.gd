class_name CityWorld
extends Node3D
## Spielwelt Karlsruhe (1:1): lädt die Weltdaten (tools/worldgen -> data/world/ka), stellt den gemeinsamen
## Straßengraphen bereit und streamt die Sektoren um den Spieler (WorldStreamer).
## Ferne Umgebung: Bodenfläche mit dem Kartenbild als Textur + LOD-Silhouetten.

var world: WorldData
var graph: CityGraph
var streamer: WorldStreamer
var env: EnvironmentSetup
var build_ms: int = 0
var slab_h: float = SectorBuilder.SLAB_H
## Für Tests/Ladebildschirm: Sektoren synchron bauen
var synchronous_streaming: bool = false
var stream_radius_override: int = -1


func build() -> void:
	var t0: int = Time.get_ticks_msec()
	world = WorldData.load_world()
	graph = CityGraph.from_world(world)
	_far_ground()
	_world_bounds()
	streamer = WorldStreamer.new()
	streamer.name = "Streaming"
	add_child(streamer)
	streamer.setup(world, graph)
	streamer.synchronous = synchronous_streaming
	if stream_radius_override >= 0:
		streamer.radius = stream_radius_override
	env = EnvironmentSetup.new()
	env.name = "Umgebung"
	add_child(env)
	env.setup(PackedVector3Array())
	streamer.sector_loaded.connect(func(_ij: Vector2i, _i: Dictionary) -> void: env.lamp_positions = streamer.all_lamps())
	streamer.sector_unloaded.connect(func(_ij: Vector2i) -> void: env.lamp_positions = streamer.all_lamps())
	var spawn: Transform3D = get_spawn()
	streamer.load_now(spawn.origin)
	build_ms = Time.get_ticks_msec() - t0
	print("[Welt] Karlsruhe geladen in %d ms: %d Knoten, %d Kanten, %d Sektoren (Quelle: %s), %d Sektoren gebaut" % [
		build_ms, graph.node_count(), graph.edge_count(), world.sectors.size(), str(world.meta.get("source", "?")), streamer.loaded.size()])


## Fokus für das Streaming (Spieler bzw. Fahrzeug); vom Spiel jeden Frame gesetzt.
func update_focus(pos: Vector3) -> void:
	if streamer != null:
		streamer.set_focus(pos)


## Sofort alles um pos laden (Teleport, Respawn, Missionsstart).
func ensure_loaded(pos: Vector3) -> void:
	if streamer != null:
		streamer.load_now(pos)


func is_loaded_at(pos: Vector3) -> bool:
	return streamer != null and streamer.is_loaded_at(pos)


func _far_ground() -> void:
	var r: Rect2 = world.bounds
	var body := StaticBody3D.new()
	body.name = "Boden"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(r.size.x + 2000.0, 2.0, r.size.y + 2000.0)
	cs.shape = bs
	cs.position = Vector3(r.get_center().x, -1.0, r.get_center().y)
	body.add_child(cs)
	add_child(body)
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load(world.dir + "map.webp") as Texture2D
	mat.albedo_texture = tex
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var kit := MeshKit.new()
	kit.set_material("map", mat)
	var a: Vector3 = Vector3(r.position.x, -0.04, r.position.y)
	var b: Vector3 = Vector3(r.end.x, -0.04, r.position.y)
	var c: Vector3 = Vector3(r.end.x, -0.04, r.end.y)
	var d: Vector3 = Vector3(r.position.x, -0.04, r.end.y)
	kit.add_quad("map", a, b, c, d, Vector3.UP, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	# Umland außerhalb der Karte
	var grass := MeshKit.new()
	grass.set_material("g", CityMaterials.get_mat("field"))
	var big: float = 6000.0
	grass.add_quad("g", a + Vector3(-big, -0.02, -big), b + Vector3(big, -0.02, -big), c + Vector3(big, -0.02, big),
		d + Vector3(-big, -0.02, big), Vector3.UP)
	for k: MeshKit in [kit, grass]:
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _world_bounds() -> void:
	var r: Rect2 = world.bounds.grow(-20.0)
	var body := StaticBody3D.new()
	body.name = "Weltgrenze"
	body.collision_layer = Layers.WORLD
	var c: Vector2 = r.get_center()
	for spec: Array in [[Vector3(c.x, 30, r.position.y), Vector3(r.size.x, 80, 4)], [Vector3(c.x, 30, r.end.y), Vector3(r.size.x, 80, 4)],
			[Vector3(r.position.x, 30, c.y), Vector3(4, 80, r.size.y)], [Vector3(r.end.x, 30, c.y), Vector3(4, 80, r.size.y)]]:
		var wcs := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = spec[1]
		wcs.shape = wb
		wcs.position = spec[0]
		body.add_child(wcs)
	add_child(body)


func get_spawn() -> Transform3D:
	var p: Vector3 = graph.poi_pos3("spawn", slab_h + 0.05)
	return Transform3D(Basis(Vector3.UP, graph.poi_yaw("spawn")), p)


## Bodenhöhe an einer Position (Platten 0,12 m, Straße 0). Nicht geladene Sektoren: 0.
## Liegt der Punkt in einem Gebäudegrundriss? (aus den Sektordaten; Sektor + Nachbarn, da Gebäude
## ihrem Schwerpunkt-Sektor zugeordnet sind). Die Sektorkollision ist ein Hohlkörper, daher diese Datenprüfung.
func is_inside_building(p: Vector2) -> bool:
	var c: Vector2i = world.sector_of(p)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var sec: Dictionary = world.load_sector(c + Vector2i(dx, dz))
			for b: Variant in sec.get("b", []):
				var poly: PackedVector2Array = world.pts(b[0])
				if Geometry2D.is_point_in_polygon(p, poly):
					return true
	return false


func ground_y(p: Vector2) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 30.0, p.y), Vector3(p.x, -2.0, p.y), Layers.WORLD)
	var hit: Dictionary = space.intersect_ray(q)
	return clampf(float((hit.position as Vector3).y), -0.1, 30.0) if not hit.is_empty() else 0.0


func poi_position(poi_id: String) -> Vector3:
	var p: Vector3 = graph.poi_pos3(poi_id)
	return Vector3(p.x, ground_y(Vector2(p.x, p.z)), p.z)


## Geparkte Fahrzeuge werden sektorweise erzeugt (ParkedCarManager); keine globale Liste mehr.
func get_parked_vehicles() -> Array[Dictionary]:
	return []


## Bergungspunkt: nächster Punkt auf einer befahrbaren Straße (rechte Fahrspur), max. 30 m entfernt.
func find_recovery_point(pos: Vector3, _spec: VehicleSpec) -> Dictionary:
	var p2: Vector2 = Vector2(pos.x, pos.z)
	var near: Dictionary = graph.nearest_edge_point(p2, "drive", 40.0)
	if int(near.edge) < 0 or float(near.dist) > 30.0:
		return {"ok": false}
	var e: int = near.edge
	var a: Vector2 = graph.node_pos[graph.edge_a[e]]
	var b: Vector2 = graph.node_pos[graph.edge_b[e]]
	var dir: Vector2 = (b - a).normalized()
	var right: Vector2 = Vector2(-dir.y, dir.x)
	var pt: Vector2 = near.point
	var lane: Vector2 = pt + right * minf(2.6, graph.edge_width(e) * 0.25)
	var yaw: float = atan2(-dir.x, -dir.y)
	return {"ok": true, "position": Vector3(lane.x, 0.0, lane.y), "yaw": yaw}


## Nächster Respawn-Punkt (Klinik oder Revier).
func respawn_point(kind: String) -> Transform3D:
	var id: String = "klinikum" if kind == "klinik" else "revier"
	var p3: Vector3 = graph.poi_pos3(id)
	ensure_loaded(p3)
	return Transform3D(Basis(Vector3.UP, graph.poi_yaw(id)), poi_position(id) + Vector3.UP * 0.05)
