extends GameTestCase
## Kampagne W8: jede neue Mission (M4–M15) wird von einem generischen „Löser“ abgeschlossen.
## Testvereinfachung (dokumentiert): Anfahrten zu Zielen per Versetzen des Fahrzeugs; Verfolgen/Begleiten mit echter
## Fahrt des NPC-Fahrzeugs (Autopilot), der Spieler wird hinterhergeführt. Geprüft werden Ablauf, Abschluss,
## einmalige Belohnung, Ruf-Änderungen und Aufräumen.

const TIMEOUT_STEP: float = 420.0


func before_each() -> void:
	await start_city_game()
	game.police.patrol_enabled = false


func after_each() -> void:
	await stop_game()


func _prepare(mid: String) -> void:
	var d: MissionDefinition = game.missions.definitions[mid]
	for r: String in d.requires:
		_complete_chain(r)


func _complete_chain(mid: String) -> void:
	var d: MissionDefinition = game.missions.definitions[mid]
	for r: String in d.requires:
		_complete_chain(r)
	GameState.complete_mission(mid, 0)


func _start(mid: String) -> bool:
	var ms: MissionSystem = game.missions
	ms.refresh_givers()
	var giver: MissionGiver = ms.givers[mid]
	teleport_player(giver.global_position + (-giver.global_basis.z) * 2.0 + Vector3.UP * 0.1)
	await wait_physics(10)
	assert_true(giver.visible, "Auftraggeber sichtbar (%s)" % mid)
	return interact_nearest()


func _step_type() -> String:
	return str(game.missions._step.get("type", ""))


func _veh() -> Vehicle:
	return game.player.current_vehicle as Vehicle


func _put_vehicle(pos: Vector3, yaw: float = INF) -> void:
	load_at(pos)
	var v: Vehicle = _veh()
	if v != null:
		v.teleport_to(Vector3(pos.x, city().ground_y(Vector2(pos.x, pos.z)) + 0.2, pos.z), v.rotation.y if yaw == INF else yaw)
	else:
		teleport_player(pos)


## Missions-Löser: arbeitet Schritt für Schritt, bis die Mission beendet ist.
func _solve(mid: String) -> bool:
	var ms: MissionSystem = game.missions
	var guard: float = 0.0
	while ms.active != null and guard < 1800.0:
		var t: String = _step_type()
		var s: Dictionary = ms._step
		var idx: int = ms.step_index
		match t:
			"talk", "countdown":
				await wait_physics(10)
			"enter_vehicle":
				var v: Vehicle = ms.mission_vehicle(str(s.tag))
				if game.player.current_vehicle != v:
					assert_true(await enter(v), "Einsteigen (%s)" % mid)
				await wait_physics(3)
			"exit_vehicle":
				game.player.toggle_vehicle()
			"goto", "wait_zone":
				_put_vehicle(ms._step_pos(s))
				await wait_seconds(float(s.get("seconds", 1.0)) + 1.0)
			"interact":
				if game.player.is_in_vehicle():
					game.player.toggle_vehicle()
					await wait_physics(10)
				teleport_player(ms._step_pos(s))
				await wait_physics(10)
				interact_nearest()
			"multi_drop":
				var drops: Array = s.drops
				var di: int = int(ms._st.get("idx", 0))
				_put_vehicle(city().poi_position(str(drops[di])))
				await wait_seconds(float(s.get("wait", 2.0)) + 1.0)
			"collect":
				if bool(s.get("on_foot", false)) and game.player.is_in_vehicle():
					game.player.toggle_vehicle()
					await wait_physics(10)
				var items: Array = ms._st.get("items", [])
				if not items.is_empty():
					_put_vehicle(items[0].pos)
				await wait_physics(15)
			"observe":
				var op: Vector3 = ms._step_pos(s)
				var dist: float = (float(s.get("min", 25.0)) + float(s.get("max", 80.0))) * 0.5
				var ne: Dictionary = city().graph.nearest_edge_point(Vector2(op.x + dist, op.z), "all", 200.0)
				var q: Vector2 = ne.point if int(ne.edge) >= 0 else Vector2(op.x + dist, op.z)
				if Vector2(q.x - op.x, q.y - op.z).length() < float(s.get("min", 25.0)) + 2.0:
					q = Vector2(op.x + dist, op.z)
				_put_vehicle(Vector3(q.x, 0, q.y))
				await wait_seconds(float(s.get("seconds", 20.0)) + 2.0)
			"escape_area":
				var c: Vector3 = ms._st.center
				var r: float = float(s.get("radius", 150.0))
				var ne2: Dictionary = city().graph.nearest_edge_point(Vector2(c.x + r + 60.0, c.z), "drive", 300.0)
				var q2: Vector2 = ne2.point if int(ne2.edge) >= 0 else Vector2(c.x + r + 60.0, c.z)
				_put_vehicle(Vector3(q2.x, 0, q2.y))
				await wait_physics(20)
			"follow", "protect":
				var npc: Vehicle = ms.mission_vehicle(str(s.tag))
				if t == "protect":
					# Verfolger vorhanden? Danach neutralisieren (Löser prüft den Ablauf, nicht das Fahrkönnen)
					assert_gt(float(get_tree().get_nodes_in_group("mission_chasers").size()), 0.0, "Verfolger erzeugt (%s)" % mid)
					for ch: Node in get_tree().get_nodes_in_group("mission_chasers"):
						(ch as Vehicle).ai_controller = null
						(ch as Vehicle).driver = Vehicle.Driver.NONE
				var keep: float = (float(s.get("min", 0.0)) + 20.0) if float(s.get("min", 0.0)) > 0.0 else 25.0
				while ms.active != null and ms.step_index == idx and npc != null and is_instance_valid(npc):
					var back: Vector3 = npc.global_position + npc.global_basis.z * keep
					_put_vehicle(back, npc.rotation.y)
					await wait_seconds(1.0)
					guard += 1.0
					if guard > 1700.0:
						break
			"destroy":
				var crates: Array = ms._st.get("crates", [])
				_put_vehicle(ms._step_pos(s) + Vector3(0, 0, 12))
				await wait_physics(10)
				for cd: Variant in crates:
					var b: RigidBody3D = cd.body
					if is_instance_valid(b):
						b.apply_central_impulse(Vector3(randf_range(-1, 1), 0.5, 1.0).normalized() * 180.0)
				await wait_seconds(2.0)
			"taxi":
				var stage: int = int(ms._st.get("stage", 0))
				if stage == 0:
					_put_vehicle(city().poi_position(str(s.pickup)))
					await wait_seconds(1.0)
				elif stage == 1:
					await wait_seconds(1.0)
				else:
					_put_vehicle(city().poi_position(str(s.dest)))
					await wait_seconds(1.0)
			"trigger_wanted":
				await wait_physics(3)
			"lose_wanted":
				game.reset_wanted()
				await wait_physics(10)
			"ride_transit":
				if game.player.is_in_vehicle():
					game.player.toggle_vehicle()
					await wait_physics(10)
				var tr: Node = game.get("transit") as Node
				if tr != null and bool(tr.call("has_lines")):
					tr.call("debug_mark_ride", str(s.from_stop), str(s.to_stop))
				teleport_player(city().poi_position(str(s.to_poi)))
				await wait_physics(20)
			_:
				await wait_physics(5)
		guard += 0.5
		if ms.awaiting_retry:
			fail("%s fehlgeschlagen in Schritt %d (%s): %s" % [mid, idx, t, ms.fail_reason])
			return false
	return ms.active == null and not ms.awaiting_retry


func _run_mission(mid: String) -> void:
	_prepare(mid)
	var money0: int = GameState.money
	var d: MissionDefinition = game.missions.definitions[mid]
	var rep0: Dictionary = GameState.reputation.duplicate()
	assert_true(game.missions.is_available(mid), "%s verfügbar nach Voraussetzungen" % mid)
	assert_true(await _start(mid), "%s gestartet" % mid)
	assert_true(await _solve(mid), "%s abgeschlossen" % mid)
	assert_true(GameState.is_mission_completed(mid), "%s gespeichert" % mid)
	assert_eq(GameState.money, money0 + d.reward, "%s: Belohnung %d €" % [mid, d.reward])
	for grp: Variant in d.reputation:
		assert_eq(int(GameState.reputation.get(grp, 0)), int(rep0.get(grp, 0)) + int(d.reputation[grp]), "%s: Ruf %s" % [mid, grp])
	await wait_physics(5)
	assert_eq(game.missions.extras.size(), 0, "%s: Zusatzobjekte aufgeräumt" % mid)
	assert_eq(get_tree().get_nodes_in_group("mission_chasers").size(), 0, "%s: keine Verfolger übrig" % mid)


func test_m04() -> void:
	await _run_mission("m04_eilzustellung")


func test_m05() -> void:
	await _run_mission("m05_nachtschicht")


func test_m06() -> void:
	await _run_mission("m06_ersatzteile")


func test_m07() -> void:
	await _run_mission("m07_probefahrt")


func test_m08() -> void:
	await _run_mission("m08_die_kiste")


func test_m09() -> void:
	await _run_mission("m09_spurensuche")


func test_m10() -> void:
	await _run_mission("m10_der_transporter")


func test_m11() -> void:
	await _run_mission("m11_hafenfreundschaft")


func test_m12() -> void:
	await _run_mission("m12_ring_frei")


func test_m13() -> void:
	await _run_mission("m13_doppeltes_spiel")


func test_m14() -> void:
	await _run_mission("m14_stadtbahn")


func test_m15() -> void:
	await _run_mission("m15_asphalt_und_schatten")


func test_givers_share_figure_and_campaign_order() -> void:
	var ms: MissionSystem = game.missions
	ms.refresh_givers()
	var visible_hanne: int = 0
	for id: String in ["m01_erste_schicht", "m04_eilzustellung", "m05_nachtschicht"]:
		if ms.givers[id].visible:
			visible_hanne += 1
	assert_eq(visible_hanne, 1, "Hanne erscheint genau einmal")
	assert_true(ms.givers["m01_erste_schicht"].visible, "Zuerst Mission 1 sichtbar")
	GameState.complete_mission("m01_erste_schicht", 0)
	ms.refresh_givers()
	assert_true(ms.givers["m04_eilzustellung"].visible, "Danach Eilzustellung sichtbar")
	assert_false(ms.is_available("m15_asphalt_und_schatten"), "Finale erst nach allen Strängen")
	var errs: Array[String] = []
	for id2: String in ms.definitions:
		errs.append_array((ms.definitions[id2] as MissionDefinition).validate(city().graph))
	assert_eq(errs.size(), 0, "Alle Missionsdaten gültig: %s" % str(errs))
