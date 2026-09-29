class_name MissionStepsExt
extends RefCounted
## Erweiterte Missionsschritte (W8), vom MissionSystem aufgerufen:
##   spawn_npc_vehicle – Fahrzeug einer Figur (verschlossen), fährt bei follow/protect selbstständig
##   follow            – NPC-Fahrzeug unauffällig folgen (min/max Abstand), bis es am Ziel ist
##   protect           – NPC-Fahrzeug begleiten und schützen (Verfolger versuchen es zu rammen)
##   escape_area       – Bereich um einen Ort verlassen
##   observe           – Ort aus sicherem Abstand beobachten (zu nah = entdeckt)
##   collect           – mehrere Orte anfahren/ablaufen (beliebige Reihenfolge)
##   multi_drop        – mehrere Abgaben in fester Reihenfolge unter Zeitlimit (je kurzer Halt)
##   destroy           – Kistenstapel umwerfen (rammen/schieben)
##   taxi              – Fahrgast abholen und absetzen
##   ride_transit      – mit der Bahn von Haltestelle A nach B fahren (ohne ÖPNV-Daten: zu Fuß zum Ziel)
##   reputation, set_flag, notify – sofortige Schritte
## Alle Schritte sind restartbar (Aufräumen über MissionSystem._cleanup_entities / cleanup_extras).

const HANDLED: Array[String] = ["spawn_npc_vehicle", "follow", "protect", "escape_area", "observe", "collect", "multi_drop",
	"destroy", "taxi", "ride_transit", "reputation", "set_flag", "notify"]


static func handles(t: String) -> bool:
	return t in HANDLED


static func _city(ms: MissionSystem) -> CityWorld:
	return ms.game.call("get_city") as CityWorld


## POI-Name oder [x, z] -> Weltposition
static func _at(ms: MissionSystem, v: Variant) -> Vector3:
	if v is Array:
		var a: Array = v
		return Vector3(float(a[0]), _city(ms).ground_y(Vector2(float(a[0]), float(a[1]))), float(a[1]))
	return _city(ms).poi_position(str(v))


static func _focus(ms: MissionSystem) -> Node3D:
	var p: Player = ms.player()
	return p.current_vehicle if p.is_in_vehicle() else p


## Schritt beginnen. Rückgabe false = Schritt ist sofort erledigt (weiter zum nächsten).
static func begin(ms: MissionSystem, t: String, s: Dictionary) -> bool:
	match t:
		"spawn_npc_vehicle":
			ms._spawn_vehicle(s)
			var v: Vehicle = ms.mission_vehicle(str(s.tag))
			if v != null:
				v.locked = true
				v.driver = Vehicle.Driver.NONE
			return false
		"reputation":
			GameState.add_reputation(str(s.get("group", "")), int(s.get("amount", 0)))
			return false
		"set_flag":
			GameState.set_flag(str(s.get("flag", "")), s.get("value", true))
			return false
		"notify":
			EventBus.big_message.emit(str(s.get("title", "")), str(s.get("subtitle", "")), float(s.get("seconds", 3.0)))
			return false
		"follow", "protect":
			var v2: Vehicle = ms.mission_vehicle(str(s.tag))
			if v2 == null:
				ms.fail("Das Zielfahrzeug fehlt.")
				return true
			_npc_drive(ms, v2, str(s.dest), float(s.get("speed", 11.0)))
			var m: MissionMarker = ms._add_marker("fahrzeug", 2.5, v2.global_position)
			m.follow = v2
			ms._set_target(v2.global_position)
			ms._st["lost"] = 0.0
			ms._st["close"] = 0.0
			if t == "protect":
				_spawn_chasers(ms, v2, int(s.get("chasers", 2)))
		"escape_area":
			var c: Vector3 = ms._step_pos(s) if s.has("poi") else _focus(ms).global_position
			ms._st["center"] = c
		"observe":
			var op: Vector3 = ms._step_pos(s)
			ms._add_marker("ziel", float(s.get("max", 80.0)) * 0.1, op)
			ms._set_target(op)
			ms._st["t"] = 0.0
			ms._st["close"] = 0.0
		"collect":
			var items: Array = []
			for poi: Variant in s.get("items", []):
				var ip: Vector3 = _at(ms, poi)
				var mk: MissionMarker = ms._add_marker(str(s.get("marker", "abholung")), float(s.get("radius", 5.0)), ip)
				items.append({"poi": str(poi), "pos": ip, "marker": mk})
			ms._st["items"] = items
			ms._st["total"] = items.size()
			if not items.is_empty():
				ms._set_target(items[0].pos)
		"multi_drop":
			ms._st["idx"] = 0
			ms._st["time"] = 0.0
			ms._st["wait"] = 0.0
			_show_drop(ms, s)
		"destroy":
			_spawn_crates(ms, ms._step_pos(s), int(s.get("crates", 6)))
			ms._set_target(ms._step_pos(s))
			ms._add_marker("ziel", 6.0, ms._step_pos(s))
		"taxi":
			var pp: Vector3 = _at(ms, s.pickup)
			var ev_actor := EventActor.new()
			ms.game.add_child(ev_actor)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(ms.active.id)
			ev_actor.setup(_city(ms), rng.randi(), EventActor.look_for(rng))
			ev_actor.place(pp)
			ms.extras.append(ev_actor)
			ms._st["pax"] = ev_actor
			ms._st["stage"] = 0
			ms._add_marker("abholung", float(s.get("radius", 8.0)), pp)
			ms._set_target(pp)
		"ride_transit":
			var transit: Node = ms.game.get("transit") as Node
			ms._st["transit"] = transit != null and bool(transit.call("has_lines"))
			var to: Vector3 = _city(ms).poi_position(str(s.to_poi))
			ms._add_marker("ziel", 5.0, to)
			ms._set_target(to)
			if not bool(ms._st.transit):
				ms.objective = str(s.get("fallback_text", "Geh zum Treffpunkt."))
	return true


static func update(ms: MissionSystem, t: String, s: Dictionary, delta: float) -> void:
	var p: Player = ms.player()
	var f: Node3D = _focus(ms)
	match t:
		"follow", "protect":
			var v: Vehicle = ms.mission_vehicle(str(s.tag))
			if v == null or v.is_destroyed:
				ms.fail("Das Zielfahrzeug ist hinüber." if t == "protect" else "Das Ziel ist entkommen.")
				return
			ms._set_target(v.global_position)
			var d: float = f.global_position.distance_to(v.global_position)
			var lose: float = float(s.get("max", 130.0 if t == "follow" else 90.0))
			ms._st["lost"] = float(ms._st.lost) + delta if d > lose else 0.0
			if float(ms._st.lost) > 7.0:
				ms.fail("Du hast das Ziel aus den Augen verloren." if t == "follow" else "Du warst nicht zur Stelle.")
				return
			var mn: float = float(s.get("min", 0.0))
			if mn > 0.0:
				ms._st["close"] = float(ms._st.close) + delta if d < mn else maxf(0.0, float(ms._st.close) - delta)
				if float(ms._st.close) > 3.0:
					ms.fail("Du bist aufgefallen – zu dicht dran.")
					return
				ms.progress_label = "Abstand %d m (unauffällig: %d–%d m)" % [roundi(d), roundi(mn), roundi(lose)]
				ms.progress = clampf(1.0 - float(ms._st.close) / 3.0, 0.0, 1.0)
			if t == "protect":
				var ratio: float = v.health / maxf(v.max_health, 1.0)
				ms.progress = ratio
				ms.progress_label = "Zustand des Fahrzeugs"
				if ratio < float(s.get("min_health", 0.3)):
					ms.fail("Das Fahrzeug wurde zu stark beschädigt.")
					return
				_steer_chasers(ms, v, delta)
			var ap: Autopilot = v.ai_controller as Autopilot
			if ap != null and ap.finished and v.linear_velocity.length() < 1.0:
				ms._begin_step(ms.step_index + 1)
		"escape_area":
			var c: Vector3 = ms._st.center
			var r: float = float(s.get("radius", 150.0))
			var d2: float = Vector2(f.global_position.x - c.x, f.global_position.z - c.z).length()
			ms.progress = clampf(d2 / r, 0.0, 1.0)
			ms.progress_label = "Abstand %d / %d m" % [roundi(d2), roundi(r)]
			if d2 > r:
				ms._begin_step(ms.step_index + 1)
		"observe":
			var op: Vector3 = ms._step_pos(s)
			var d3: float = Vector2(f.global_position.x - op.x, f.global_position.z - op.z).length()
			var mn2: float = float(s.get("min", 25.0))
			var mx: float = float(s.get("max", 80.0))
			if d3 < mn2:
				ms._st["close"] = float(ms._st.close) + delta
				if float(ms._st.close) > 2.0:
					ms.fail("Du bist entdeckt worden – zu nah am Objekt.")
					return
			else:
				ms._st["close"] = 0.0
			if d3 >= mn2 and d3 <= mx:
				ms._st["t"] = float(ms._st.t) + delta
			ms.progress = clampf(float(ms._st.t) / float(s.get("seconds", 20.0)), 0.0, 1.0)
			ms.progress_label = "Beobachten (%d–%d m Abstand)" % [roundi(mn2), roundi(mx)]
			if ms.progress >= 1.0:
				ms._begin_step(ms.step_index + 1)
		"collect":
			var items: Array = ms._st.items
			var r2: float = float(s.get("radius", 5.0))
			for i: int in range(items.size() - 1, -1, -1):
				var it: Dictionary = items[i]
				if bool(s.get("on_foot", false)) and p.is_in_vehicle():
					continue
				var ip: Vector3 = it.pos
				if Vector2(f.global_position.x - ip.x, f.global_position.z - ip.z).length() < r2:
					if is_instance_valid(it.marker):
						(it.marker as Node).queue_free()
					items.remove_at(i)
					AudioManager.play_2d("checkpoint", -4.0)
					EventBus.notify.emit("%s (%d/%d)" % [str(s.get("collected_text", "Eingesammelt")), int(ms._st.total) - items.size(), int(ms._st.total)], "erfolg")
			ms.progress = 1.0 - float(items.size()) / maxf(float(ms._st.total), 1.0)
			ms.progress_label = "%d von %d" % [int(ms._st.total) - items.size(), int(ms._st.total)]
			if not items.is_empty():
				var best: Vector3 = items[0].pos
				for it2: Dictionary in items:
					if f.global_position.distance_to(it2.pos) < f.global_position.distance_to(best):
						best = it2.pos
				ms._set_target(best)
			else:
				ms._begin_step(ms.step_index + 1)
		"multi_drop":
			_update_drop(ms, s, delta, p, f)
		"destroy":
			var crates: Array = ms._st.get("crates", [])
			var down: int = 0
			for c2: Dictionary in crates:
				var b: RigidBody3D = c2.body
				if not is_instance_valid(b):
					down += 1
					continue
				if b.global_position.distance_to(c2.origin) > 1.6 or b.global_basis.y.dot(Vector3.UP) < 0.7:
					down += 1
			var need: int = int(s.get("need", crates.size() - 1))
			ms.progress = clampf(float(down) / float(maxi(need, 1)), 0.0, 1.0)
			ms.progress_label = "Kisten umgeworfen: %d/%d" % [mini(down, need), need]
			if down >= need:
				ms._begin_step(ms.step_index + 1)
		"taxi":
			_update_taxi(ms, s, delta, p, f)
		"ride_transit":
			var to: Vector3 = _city(ms).poi_position(str(s.to_poi))
			var at_goal: bool = Vector2(p.global_position.x - to.x, p.global_position.z - to.z).length() < float(s.get("radius", 25.0))
			if bool(ms._st.transit):
				var transit: Node = ms.game.get("transit") as Node
				var rode: bool = bool(transit.call("player_rode_between", str(s.from_stop), str(s.to_stop)))
				if rode and at_goal and not p.is_in_vehicle():
					ms._begin_step(ms.step_index + 1)
			elif at_goal and not p.is_in_vehicle():
				ms._begin_step(ms.step_index + 1)


# ------------------------------------------------------------------ Hilfen

static func _npc_drive(ms: MissionSystem, v: Vehicle, dest_poi: String, speed: float) -> void:
	var city: CityWorld = _city(ms)
	var g: CityGraph = city.graph
	var dest: Vector3 = g.poi_pos3(dest_poi)
	# NPC-Fahrzeuge fahren wie der Verkehr: Einbahnstraßen nur in Fahrtrichtung (sonst Gegenspur, Unfälle, Stillstand)
	var n0: int = g.nearest_node(Vector2(v.global_position.x, v.global_position.z), "drive_dir")
	var n1: int = g.nearest_node(Vector2(dest.x, dest.z), "drive_dir")
	var path: PackedInt32Array = g.find_path(n0, n1, "drive_dir")
	if path.size() < 2:
		path = g.find_path(g.nearest_node(Vector2(v.global_position.x, v.global_position.z), "drive"),
			g.nearest_node(Vector2(dest.x, dest.z), "drive"), "drive")
	var pts: PackedVector3Array = PackedVector3Array([v.global_position])
	pts.append_array(g.lane_path(path, 2.6))
	pts.append(city.poi_position(dest_poi))
	var ap := Autopilot.new()
	ap.set_path(pts, speed)
	ap.arrive_radius = 5.0
	ap.avoid_obstacles = true
	v.ai_controller = ap
	v.driver = Vehicle.Driver.AI
	v.locked = true


static func _spawn_chasers(ms: MissionSystem, target: Vehicle, n: int) -> void:
	var chasers: Array = []
	for i: int in n:
		var back: Vector3 = target.global_basis.z * (35.0 + float(i) * 12.0) + target.global_basis.x * (3.0 if i % 2 == 0 else -3.0)
		var pos: Vector3 = target.global_position + back + Vector3.UP * 0.3
		var c: Vehicle = ms.game.call("spawn_vehicle", "limousine", pos, target.rotation.y, Color(0.12, 0.12, 0.14),
			Vehicle.Ownership.MISSION, "") as Vehicle
		c.locked = true
		c.add_to_group("mission_chasers")
		var ap := Autopilot.new()
		ap.set_path(PackedVector3Array([target.global_position]), 17.0)
		ap.corner_slowdown = false
		c.ai_controller = ap
		c.driver = Vehicle.Driver.AI
		ms.extras.append(c)
		chasers.append(c)
	ms._st["chasers"] = chasers
	ms._st["chase_t"] = 0.0


static func _steer_chasers(ms: MissionSystem, target: Vehicle, delta: float) -> void:
	ms._st["chase_t"] = float(ms._st.get("chase_t", 0.0)) - delta
	if float(ms._st.chase_t) > 0.0:
		return
	ms._st["chase_t"] = 0.6
	for c: Variant in ms._st.get("chasers", []):
		if not is_instance_valid(c):
			continue
		var cv: Vehicle = c as Vehicle
		if cv.is_destroyed:
			continue
		var ap: Autopilot = cv.ai_controller as Autopilot
		if ap == null:
			continue
		var aim: Vector3 = target.global_position + target.linear_velocity * 0.7
		ap.set_path(PackedVector3Array([aim]), 19.0)


static func _spawn_crates(ms: MissionSystem, pos: Vector3, n: int) -> void:
	var crates: Array = []
	var mat: StandardMaterial3D = MatLib.solid(Color(0.55, 0.4, 0.25), 0.9)
	for i: int in n:
		var b := RigidBody3D.new()
		b.mass = 25.0
		b.collision_layer = Layers.WORLD
		b.collision_mask = Layers.WORLD | Layers.VEHICLE | Layers.PLAYER
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.9, 0.9, 0.9)
		cs.shape = box
		b.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, 0.9)
		bm.material = mat
		mi.mesh = bm
		b.add_child(mi)
		ms.game.add_child(b)
		var layer: int = 0 if i < 3 else (1 if i < 5 else 2)
		var col: float = float(i if i < 3 else (i - 3 if i < 5 else 0)) - (1.0 if layer == 0 else (0.5 if layer == 1 else 0.0))
		var origin: Vector3 = pos + Vector3(col * 0.95, 0.46 + float(layer) * 0.92, 0)
		b.global_position = origin
		ms.extras.append(b)
		crates.append({"body": b, "origin": origin})
	ms._st["crates"] = crates


static func _show_drop(ms: MissionSystem, s: Dictionary) -> void:
	ms._clear_markers()
	var drops: Array = s.get("drops", [])
	var idx: int = int(ms._st.idx)
	if idx >= drops.size():
		return
	var dp: Vector3 = _at(ms, drops[idx])
	ms._add_marker("ziel", float(s.get("radius", 8.0)), dp)
	if idx + 1 < drops.size():
		ms._add_marker("vorschau", float(s.get("radius", 8.0)) * 0.7, _at(ms, drops[idx + 1]))
	ms._set_target(dp)
	ms.checkpoint_info = "Abgabe %d/%d" % [idx + 1, drops.size()]


static func _update_drop(ms: MissionSystem, s: Dictionary, delta: float, p: Player, f: Node3D) -> void:
	var drops: Array = s.get("drops", [])
	var limit: float = float(s.get("time_limit", 600.0)) * (1.5 if Settings.simplified_missions else 1.0)
	ms._st["time"] = float(ms._st.time) + delta
	ms.timer_text = "Zeit %s / %s" % [ms._fmt_time(float(ms._st.time)), ms._fmt_time(limit)]
	if float(ms._st.time) > limit:
		ms.fail("Die Zeit ist abgelaufen.")
		return
	var idx: int = int(ms._st.idx)
	var dp: Vector3 = _at(ms, drops[idx])
	var ok: bool = Vector2(f.global_position.x - dp.x, f.global_position.z - dp.z).length() < float(s.get("radius", 8.0))
	if s.has("vehicle"):
		ok = ok and p.current_vehicle == ms.mission_vehicle(str(s.vehicle)) and (p.current_vehicle as Vehicle).linear_velocity.length() < 2.0
	ms._st["wait"] = float(ms._st.wait) + delta if ok else 0.0
	ms.progress = clampf(float(ms._st.wait) / float(s.get("wait", 2.0)), 0.0, 1.0) if ok else -1.0
	ms.progress_label = "Abgabe …"
	if float(ms._st.wait) >= float(s.get("wait", 2.0)):
		AudioManager.play_2d("checkpoint", -3.0)
		ms._st["idx"] = idx + 1
		ms._st["wait"] = 0.0
		if idx + 1 >= drops.size():
			ms.timer_text = ""
			ms.checkpoint_info = ""
			ms._begin_step(ms.step_index + 1)
		else:
			_show_drop(ms, s)


static func _update_taxi(ms: MissionSystem, s: Dictionary, delta: float, p: Player, f: Node3D) -> void:
	var pax: EventActor = ms._st.get("pax") as EventActor
	if pax == null or not is_instance_valid(pax):
		ms.fail("Der Fahrgast ist weg.")
		return
	var stage: int = int(ms._st.stage)
	var car: Vehicle = p.current_vehicle as Vehicle
	match stage:
		0:
			var pp: Vector3 = _at(ms, s.pickup)
			if car != null and car.global_position.distance_to(pp) < float(s.get("radius", 8.0)) and car.linear_velocity.length() < 1.5:
				ms._st["stage"] = 1
				pax.go_to(car.global_position + car.global_basis.x * 1.6, 2.0)
				ms.objective = str(s.get("board_text", "Warte, bis der Fahrgast eingestiegen ist."))
		1:
			if car == null:
				return
			pax.go_to(car.global_position + car.global_basis.x * 1.6, 2.0)
			if pax.global_position.distance_to(car.global_position) < 3.0:
				pax.visible = false
				pax.set_physics_process(false)
				ms._st["stage"] = 2
				ms._clear_markers()
				var dp: Vector3 = _at(ms, s.dest)
				ms._add_marker("ziel", float(s.get("radius", 8.0)), dp)
				ms._set_target(dp)
				ms.objective = str(s.get("drive_text", "Bring den Fahrgast ans Ziel."))
				ms.changed.emit()
		2:
			if car != null:
				pax.global_position = car.global_position
			var dp2: Vector3 = _at(ms, s.dest)
			if car != null and car.global_position.distance_to(dp2) < float(s.get("radius", 8.0)) and car.linear_velocity.length() < 1.5:
				pax.visible = true
				pax.set_physics_process(true)
				pax.place(car.global_position + car.global_basis.x * 2.0)
				pax.go_to(car.global_position + car.global_basis.x * 12.0, 1.4)
				ms._begin_step(ms.step_index + 1)
