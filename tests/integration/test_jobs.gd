extends GameTestCase
## Wiederholbare Jobs (W8): Kurier, Taxi, Lieferrunde werden erzeugt, sind abschließbar und zahlen bei jedem Abschluss.


func before_each() -> void:
	await start_city_game()


func after_each() -> void:
	await stop_game()


func _finish_current(max_t: float = 200.0) -> bool:
	var ms: MissionSystem = game.missions
	var guard: float = 0.0
	while ms.active != null and guard < max_t:
		var t: String = str(ms._step.get("type", ""))
		var s: Dictionary = ms._step
		match t:
			"enter_vehicle":
				var jv: Vehicle = ms.mission_vehicle(str(s.tag))
				if game.player.current_vehicle != jv:
					await enter(jv)
				await wait_physics(3)
			"goto", "wait_zone":
				var p: Vector3 = ms._step_pos(s)
				load_at(p)
				var v: Vehicle = game.player.current_vehicle as Vehicle
				v.teleport_to(Vector3(p.x, city().ground_y(Vector2(p.x, p.z)) + 0.2, p.z), v.rotation.y)
				await wait_seconds(3.0)
			"multi_drop":
				var d: Array = s.drops[int(ms._st.idx)]
				load_at(Vector3(float(d[0]), 0, float(d[1])))
				var v2: Vehicle = game.player.current_vehicle as Vehicle
				v2.teleport_to(Vector3(float(d[0]), 0.3, float(d[1])), v2.rotation.y)
				await wait_seconds(3.0)
			"taxi":
				var st: int = int(ms._st.stage)
				var tgt: Array = s.pickup if st < 2 else s.dest
				load_at(Vector3(float(tgt[0]), 0, float(tgt[1])))
				var v3: Vehicle = game.player.current_vehicle as Vehicle
				if st != 1:
					v3.teleport_to(Vector3(float(tgt[0]), 0.3, float(tgt[1])), v3.rotation.y)
				await wait_seconds(1.5)
			_:
				await wait_physics(10)
		guard += 1.0
		if ms.awaiting_retry:
			fail("Job fehlgeschlagen: " + ms.fail_reason)
			return false
	return ms.active == null


func test_jobs_pay_every_time() -> void:
	for kind: String in ["job_kurier", "job_taxi", "job_lieferung"]:
		for round_i: int in 2:
			var money0: int = GameState.money
			assert_true(game.jobs.start_job(kind), "%s gestartet (Runde %d)" % [kind, round_i])
			var reward: int = game.missions.active.reward
			assert_gt(float(reward), 30.0, "%s: Bezahlung nach Entfernung (%d €)" % [kind, reward])
			assert_true(await _finish_current(), "%s abgeschlossen (Runde %d)" % [kind, round_i])
			assert_eq(GameState.money, money0 + reward, "%s: bezahlt (Runde %d)" % [kind, round_i])
			if game.player.is_in_vehicle():
				game.player.toggle_vehicle()
			await wait_physics(10)


func test_mission_list_opens_and_waypoint() -> void:
	game.mission_list.open()
	await wait_physics(3)
	assert_true(game.mission_list.is_open(), "Auftragsliste offen")
	assert_true(get_tree().paused, "Spiel pausiert")
	game.mission_list.close()
	game.waypoint = game.player.global_position + Vector3(5, 0, 0)
	await wait_physics(5)
	assert_eq(game.waypoint, Vector3.INF, "Wegpunkt beim Erreichen gelöscht")
