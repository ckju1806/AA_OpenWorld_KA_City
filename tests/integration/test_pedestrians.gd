extends GameTestCase
## Passanten: Anzahl, keine Figuren in Wänden, Ausweichen, Anfahren wird gemeldet.


func after_each() -> void:
	await stop_game()


func _inside_wall(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var s := SphereShape3D.new()
	s.radius = 0.2
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.2)
	q.collision_mask = Layers.WORLD
	return not space.intersect_shape(q, 1).is_empty()


func test_pedestrians_walk_and_stay_out_of_walls() -> void:
	await start_city_game(true)
	game.traffic.enabled = false
	game.police.patrol_enabled = false
	var ok: bool = await wait_until(func() -> bool: return game.peds.active_count() >= game.peds.max_peds - 2, 20.0)
	assert_true(ok, "Passanten erscheinen (%d)" % game.peds.active_count())
	var start: Dictionary = {}
	for p: Pedestrian in game.peds.peds:
		start[p] = p.global_position
	var inside: int = 0
	var samples: int = 0
	for k: int in 6:
		await wait_seconds(5.0)
		for p2: Pedestrian in game.peds.peds:
			samples += 1
			if _inside_wall(p2.global_position):
				inside += 1
	var moved: int = 0
	for p3: Pedestrian in game.peds.peds:
		if start.has(p3) and (start[p3] as Vector3).distance_to(p3.global_position) > 3.0:
			moved += 1
	assert_lt(float(inside), float(samples) * 0.02 + 0.5, "Passanten nicht in Wänden (%d von %d Proben)" % [inside, samples])
	assert_gt(float(moved), float(game.peds.active_count()) * 0.4, "Passanten bewegen sich (%d)" % moved)


func test_pedestrian_dodges_and_hit_is_reported() -> void:
	await start_city_game(true)
	game.traffic.enabled = false
	game.police.patrol_enabled = false
	await wait_until(func() -> bool: return game.peds.active_count() >= 3, 10.0)
	var ped: Pedestrian = game.peds.peds[0]
	# Passant auf freie Fläche stellen (Marktplatz am Startpunkt – in beiden Kartenquellen offen) und Zeugen daneben
	var sp: Vector3 = city().get_spawn().origin
	var fwd: Vector3 = _free_axis(sp)
	ped.place_in_area(0)
	ped.global_position = sp + fwd * 12.0 + Vector3(0, 0.07, 0)
	ped.state = Pedestrian.State.WAIT
	var witness: Pedestrian = game.peds.peds[1]
	witness.place_in_area(0)
	witness.global_position = sp + fwd * 20.0 + fwd.cross(Vector3.UP) * 6.0 + Vector3(0, 0.07, 0)
	witness.state = Pedestrian.State.WAIT
	# Spieler in einem Auto, das mit hoher Geschwindigkeit auf den Passanten zufährt
	var v: Vehicle = game.spawn_vehicle("kompakt", sp - fwd * 28.0 + Vector3.UP * 0.15, atan2(-fwd.x, -fwd.z))
	await wait_physics(10)
	await enter(v)
	var crimes: Array[String] = []
	var cb: Callable = func(kind: String, _p: Vector3, _w: bool) -> void: crimes.append(kind)
	EventBus.crime_reported.connect(cb)
	v.linear_velocity = fwd * 14.0
	v.set_controls(1.0, 0.0, 0.0, false)
	var seen_states: Dictionary = {}
	for k: int in 60:
		await wait_physics(4)
		seen_states[ped.state] = true
	EventBus.crime_reported.disconnect(cb)
	var reacted: bool = seen_states.has(Pedestrian.State.AVOID) or seen_states.has(Pedestrian.State.DOWN) or seen_states.has(Pedestrian.State.FLEE)
	assert_true(reacted, "Passant reagiert auf nahendes Fahrzeug (Zustände %s)" % str(seen_states.keys()))
	if seen_states.has(Pedestrian.State.DOWN):
		assert_true(crimes.has("fussgaenger"), "Anfahren wird als Tat gemeldet")
		assert_gt(float(game.get_wanted_level()), 0.5, "Beobachtetes Anfahren -> Fahndung")
	print("        Beobachtete Zustände: %s, gemeldete Taten: %s" % [str(seen_states.keys()), str(crimes)])


func test_hit_pedestrian_is_reported_with_witness() -> void:
	await start_city_game(true)
	game.traffic.enabled = false
	game.police.patrol_enabled = false
	await wait_until(func() -> bool: return game.peds.active_count() >= 2, 10.0)
	var ped: Pedestrian = game.peds.peds[0]
	var witness: Pedestrian = game.peds.peds[1]
	ped.global_position = Vector3(20, 0.12, 400)
	witness.global_position = Vector3(28, 0.12, 405)
	witness.state = Pedestrian.State.WAIT
	var v: Vehicle = game.spawn_vehicle("kompakt", Vector3(20, 0.2, 410), 0.0)
	await wait_physics(10)
	await enter(v)
	var crimes: Array[String] = []
	var cb: Callable = func(kind: String, _p: Vector3, _w: bool) -> void: crimes.append(kind)
	EventBus.crime_reported.connect(cb)
	v.linear_velocity = Vector3(0, 0, -12)
	ped._on_body_entered(v)
	await wait_physics(2)
	EventBus.crime_reported.disconnect(cb)
	assert_eq(ped.state, Pedestrian.State.DOWN, "Passant umgestoßen")
	assert_true(crimes.has("fussgaenger"), "Tat gemeldet")
	assert_eq(game.get_wanted_level(), 1, "Mit Zeuge -> Fahndungsstufe 1")


## Richtung, in der vom Punkt aus 45 m (Auto 28 m davor bis Zeuge 20 m dahinter) frei von Gebäuden sind.
func _free_axis(p: Vector3) -> Vector3:
	for deg: float in [0.0, 90.0, 180.0, 270.0, 45.0, 135.0, 225.0, 315.0]:
		var d: Vector3 = Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(deg))
		var free: bool = true
		for k: int in range(-30, 24, 3):
			var q: Vector3 = p + d * float(k)
			if city().is_inside_building(Vector2(q.x, q.z)):
				free = false
				break
		if free:
			return d
	return Vector3(0, 0, -1)
