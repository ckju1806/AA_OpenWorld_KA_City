class_name WorldStreamer
extends Node3D
## Sektor-Streaming: hält Sektoren im Radius um einen Fokuspunkt (Spieler/Fahrzeug/Kamera) geladen, baut neue
## Sektoren auf Worker-Threads (SectorBuilder) und hängt fertige Sektoren im Hauptthread mit Zeitbudget ein.
## Entfernte Sektoren werden mit Abstand (Hysterese) entladen. Ferne Bebauung als LOD-Silhouetten je 1-km-Kachel.
## synchronous = true (Tests, Ladebildschirm): sofortiges Bauen im Hauptthread.

signal sector_loaded(ij: Vector2i, info: Dictionary)
signal sector_unloaded(ij: Vector2i)

var world: WorldData
var graph: CityGraph
var radius: int = 2                  ## Sektoren (Chebyshev-Abstand) mit voller Detailtiefe
var lod_radius: float = 2600.0       ## LOD-Kacheln bis zu dieser Entfernung
var synchronous: bool = false
var focus: Vector3 = Vector3.ZERO
var max_parallel_jobs: int = 3
var attach_budget_ms: float = 6.0
var enabled_lod: bool = true

var loaded: Dictionary = {}          ## Vector2i -> { node, lamps, cars }
var _jobs: Dictionary = {}           ## Vector2i -> task id
var _results: Dictionary = {}        ## Vector2i -> result (fertig gebaut, noch nicht eingehängt)
var _mutex: Mutex = Mutex.new()
var _lod_nodes: Dictionary = {}      ## Vector2i -> Node3D
var _check_t: float = 0.0
var _quality: int = 1
var stats: Dictionary = {"built": 0, "unloaded": 0, "last_build_ms": 0.0, "max_build_ms": 0.0}


func setup(w: WorldData, g: CityGraph) -> void:
	world = w
	graph = g
	_quality = Settings.quality
	radius = Settings.sector_radius()
	lod_radius = [1600.0, 2600.0, 3600.0][clampi(Settings.quality, 0, 2)]
	SectorBuilder.warm_up()


## Alles im Umkreis sofort laden (Ladebildschirm, Tests, Teleport).
func load_now(pos: Vector3) -> void:
	focus = pos
	var was_sync: bool = synchronous
	synchronous = true
	_update(true)
	synchronous = was_sync


func set_focus(pos: Vector3) -> void:
	focus = pos


func is_loaded_at(p: Vector3) -> bool:
	return loaded.has(world.sector_of(Vector2(p.x, p.z)))


func all_lamps() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	for ij: Vector2i in loaded:
		out.append_array(loaded[ij].lamps)
	return out


func pending_count() -> int:
	return _jobs.size() + _results.size()


func _process(_delta: float) -> void:
	if world == null:
		return
	_check_t -= _delta
	if _check_t <= 0.0:
		_check_t = 0.25
		_update(false)
	_attach_results()


func _wanted() -> Array[Vector2i]:
	var c: Vector2i = world.sector_of(Vector2(focus.x, focus.z))
	var out: Array[Vector2i] = []
	for r: int in radius + 1:
		for dx: int in range(-r, r + 1):
			for dz: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var ij: Vector2i = c + Vector2i(dx, dz)
				if world.has_sector(ij):
					out.append(ij)
	return out   # nach Abstand sortiert (innen zuerst)


func _update(force_sync: bool) -> void:
	var c: Vector2i = world.sector_of(Vector2(focus.x, focus.z))
	# Entladen (Hysterese: radius + 1)
	for ij: Vector2i in loaded.keys():
		if maxi(absi(ij.x - c.x), absi(ij.y - c.y)) > radius + 1:
			_unload(ij)
	var wanted: Array[Vector2i] = _wanted()
	for ij2: Vector2i in wanted:
		if loaded.has(ij2) or _jobs.has(ij2) or _results.has(ij2):
			continue
		if synchronous or force_sync:
			var t0: int = Time.get_ticks_usec()
			var res: Dictionary = SectorBuilder.build(world, graph, ij2, world.load_sector(ij2), _quality)
			_note_build(Time.get_ticks_usec() - t0)
			_attach(ij2, res)
		elif _jobs.size() < max_parallel_jobs:
			var captured: Vector2i = ij2
			_jobs[ij2] = WorkerThreadPool.add_task(func() -> void: _build_job(captured))
	if enabled_lod:
		_update_lod()


func _build_job(ij: Vector2i) -> void:
	var t0: int = Time.get_ticks_usec()
	var res: Dictionary = SectorBuilder.build(world, graph, ij, world.load_sector(ij), _quality)
	res["us"] = Time.get_ticks_usec() - t0
	_mutex.lock()
	_results[ij] = res
	_mutex.unlock()


func _attach_results() -> void:
	# Abgeschlossene Jobs einsammeln
	for ij: Vector2i in _jobs.keys():
		if WorkerThreadPool.is_task_completed(_jobs[ij]):
			WorkerThreadPool.wait_for_task_completion(_jobs[ij])
			_jobs.erase(ij)
	var t0: int = Time.get_ticks_msec()
	_mutex.lock()
	var ready: Array = _results.keys()
	_mutex.unlock()
	var c: Vector2i = world.sector_of(Vector2(focus.x, focus.z))
	for ij: Vector2i in ready:
		_mutex.lock()
		var res: Dictionary = _results[ij]
		_results.erase(ij)
		_mutex.unlock()
		_note_build(int(res.get("us", 0)))
		if maxi(absi(ij.x - c.x), absi(ij.y - c.y)) > radius + 1:
			(res.node as Node).queue_free()
			continue
		_attach(ij, res)
		if float(Time.get_ticks_msec() - t0) > attach_budget_ms:
			break


func _note_build(us: int) -> void:
	var ms: float = float(us) / 1000.0
	stats.last_build_ms = ms
	stats.max_build_ms = maxf(float(stats.max_build_ms), ms)


func _attach(ij: Vector2i, res: Dictionary) -> void:
	add_child(res.node)
	loaded[ij] = res
	stats.built = int(stats.built) + 1
	var lod_ij: Vector2i = world.lod_of(world.sector_rect(ij).get_center())
	sector_loaded.emit(ij, res)
	_refresh_lod_cutout(lod_ij)


func _unload(ij: Vector2i) -> void:
	var res: Dictionary = loaded[ij]
	loaded.erase(ij)
	(res.node as Node).queue_free()
	stats.unloaded = int(stats.unloaded) + 1
	sector_unloaded.emit(ij)
	_refresh_lod_cutout(world.lod_of(world.sector_rect(ij).get_center()))


func unload_all() -> void:
	for ij: Vector2i in loaded.keys():
		_unload(ij)
	for t: Vector2i in _lod_nodes.keys():
		(_lod_nodes[t] as Node).queue_free()
	_lod_nodes.clear()


# ------------------------------------------------------------------ LOD

func _update_lod() -> void:
	var f2: Vector2 = Vector2(focus.x, focus.z)
	var r_tiles: int = int(ceil(lod_radius / world.lod_tile))
	var c: Vector2i = world.lod_of(f2)
	for t: Vector2i in _lod_nodes.keys():
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) > r_tiles + 1:
			(_lod_nodes[t] as Node).queue_free()
			_lod_nodes.erase(t)
	for dx: int in range(-r_tiles, r_tiles + 1):
		for dz: int in range(-r_tiles, r_tiles + 1):
			var t2: Vector2i = c + Vector2i(dx, dz)
			if _lod_nodes.has(t2) or not world.lod_tiles.has(t2):
				continue
			_lod_nodes[t2] = _build_lod(t2)
			add_child(_lod_nodes[t2])
			_refresh_lod_cutout(t2)


## LOD-Kachel: gedrehte Quader je Gebäude, je Sektor ein eigenes Mesh (keine Kollision, keine Schatten).
func _build_lod(t: Vector2i) -> Node3D:
	var arr: Array = world.load_lod(t)
	var node := Node3D.new()
	node.name = "LOD_%d_%d" % [t.x, t.y]
	var kits: Dictionary = {}   # Vector2i (Sektor) -> MeshKit
	var inv: float = 1.0 / world.q
	for i: int in range(0, arr.size(), 8):
		var cx: float = float(arr[i]) * inv
		var cz: float = float(arr[i + 1]) * inv
		var w: float = float(arr[i + 2]) * inv
		var d: float = float(arr[i + 3]) * inv
		var ang: float = float(arr[i + 4]) / 1000.0
		var h: float = float(arr[i + 5]) * inv
		var ci: int = int(arr[i + 6])
		var st: int = int(arr[i + 7])
		var ij: Vector2i = world.sector_of(Vector2(cx, cz))
		if not kits.has(ij):
			var k := MeshKit.new()
			k.set_material("v", CityMaterials.get_mat("flat"))
			kits[ij] = k
		var kit: MeshKit = kits[ij]
		var col: Color = SectorBuilder.MODERN_COLORS[ci % 4] if st in [1, 3, 4, 5] else SectorBuilder.WALL_COLORS[ci % 12]
		kit.color = col.darkened(0.1)
		kit.add_box("v", Vector3(cx, h * 0.5 + 0.12, cz), Vector3(w, h, d), Basis(Vector3.UP, -ang))
	for ij2: Vector2i in kits:
		var mi := MeshInstance3D.new()
		mi.name = "S_%d_%d" % [ij2.x, ij2.y]
		mi.mesh = (kits[ij2] as MeshKit).commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("sector", ij2)
		node.add_child(mi)
	return node


## LOD-Teilmeshes der voll geladenen Sektoren ausblenden (keine doppelte Bebauung).
func _refresh_lod_cutout(t: Vector2i) -> void:
	if not _lod_nodes.has(t):
		return
	for ch: Node in (_lod_nodes[t] as Node3D).get_children():
		(ch as Node3D).visible = not loaded.has(ch.get_meta("sector"))
