extends TestCase
## Fahrzeuge auf dem Testgelände: Stabilität, Fahren, Lenken, Ein-/Ausstieg, Schaden, Bergung.

var game: Game


func before_each() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Game
	game.world_mode = "test"
	add_child(game)
	game.player.use_sim_input = true
	await wait_physics(30)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await wait_physics(2)


func _vehicle(spec_id: String) -> Vehicle:
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		if (v as Vehicle).spec.id == spec_id:
			return v as Vehicle
	return null


func _drive(v: Vehicle) -> void:
	game.player.global_position = v.global_position + v.global_basis.x * -2.2
	await wait_physics(12)
	v.enter(game.player)


func test_vehicles_rest_stably() -> void:
	await wait_seconds(3.0)
	for v: Node in get_tree().get_nodes_in_group("vehicles"):
		var veh: Vehicle = v as Vehicle
		assert_false(veh.is_flipped(), "%s steht aufrecht" % veh.spec.id)
		assert_lt(veh.linear_velocity.length(), 0.3, "%s steht still" % veh.spec.id)
		assert_near(veh.global_position.y, 0.0, 0.25, "%s Höhe über Boden" % veh.spec.id)


func test_accelerate_brake_reverse() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	assert_true(game.player.is_in_vehicle(), "Spieler sitzt im Fahrzeug")
	v.set_controls(1.0, 0.0, 0.0, false)
	await wait_seconds(5.0)
	var top: float = v.get_forward_speed()
	assert_gt(top, 17.0, "Geschwindigkeit nach 5 s Vollgas (m/s)")
	assert_false(v.is_flipped(), "Nicht überschlagen")
	var p0: Vector3 = v.global_position
	v.set_controls(0.0, 1.0, 0.0, false)
	var stopped: bool = await wait_until(func() -> bool: return v.get_forward_speed() < 0.5, 6.0)
	assert_true(stopped, "Fahrzeug kommt zum Stehen")
	assert_lt(p0.distance_to(v.global_position), top * top / (2.0 * 6.0), "Bremsweg plausibel")
	await wait_seconds(2.0)
	assert_lt(v.get_forward_speed(), -2.0, "Rückwärtsfahrt bei gehaltener Bremse im Stand")
	v.set_controls(0.0, 0.0, 0.0, false)


func test_steering_turns_right_and_speed_dependent() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	v.set_controls(0.7, 0.0, 0.0, false)
	await wait_seconds(2.0)
	var yaw0: float = v.global_rotation.y
	v.set_controls(0.4, 0.0, 1.0, false)
	await wait_seconds(0.8)
	var dyaw: float = wrapf(v.global_rotation.y - yaw0, -PI, PI)
	assert_lt(dyaw, -0.1, "Rechtslenkung dreht im Uhrzeigersinn (Gier nimmt ab)")
	assert_false(v.is_flipped(), "Kurvenfahrt ohne Überschlag")
	# Geschwindigkeitsabhängige Lenkung: max. Lenkwinkel bei hoher Geschwindigkeit kleiner
	var s: VehicleSpec = v.spec
	var low: float = lerpf(s.steer_max_deg, s.steer_min_deg, clampf(2.0 / s.steer_speed_ref, 0.0, 1.0))
	var high: float = lerpf(s.steer_max_deg, s.steer_min_deg, clampf(30.0 / s.steer_speed_ref, 0.0, 1.0))
	assert_gt(low, high * 2.0, "Lenkwinkel sinkt mit der Geschwindigkeit")


func test_handbrake_slows_down() -> void:
	var v: Vehicle = _vehicle("sport")
	v.teleport_to(Vector3(-3, 0, -20), 0.0)  # freie Spur Richtung -Z
	await wait_physics(10)
	await _drive(v)
	v.set_controls(1.0, 0.0, 0.0, false)
	await wait_seconds(3.0)
	var sp: float = v.get_forward_speed()
	v.set_controls(0.0, 0.0, 0.0, true)
	await wait_seconds(1.5)
	assert_lt(v.get_forward_speed(), sp - 5.0, "Handbremse verzögert")
	assert_false(v.is_flipped(), "Handbremse ohne Überschlag")


func test_multiple_enter_exit_and_switch() -> void:
	var p: Player = game.player
	for round_i: int in 2:
		for id: String in ["kompakt", "sport", "transporter"]:
			var v: Vehicle = _vehicle(id)
			p.global_position = v.global_position + v.global_basis.x * -2.4 + Vector3.UP * 0.1
			await wait_physics(15)
			var ok: bool = p.toggle_vehicle()
			assert_true(ok and p.current_vehicle == v, "Einsteigen in %s (Runde %d)" % [id, round_i])
			await wait_physics(10)
			assert_true(p.toggle_vehicle(), "Aussteigen aus %s" % id)
			assert_false(p.is_in_vehicle(), "Nach Aussteigen zu Fuß")
			await wait_physics(30)
			assert_true(p.is_on_floor(), "Nach Aussteigen auf dem Boden (%s)" % id)
			assert_gt(p.global_position.distance_to(v.global_position), 1.2, "Ausstieg nicht im Fahrzeug")
			assert_eq(v.driver, Vehicle.Driver.NONE, "Fahrzeug ohne Fahrer")
	var group_count: int = get_tree().get_nodes_in_group("vehicles").size()
	assert_eq(group_count, 4, "Keine zusätzlichen Fahrzeuge durch Wechsel")


func test_exit_refused_when_fast() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	v.set_controls(1.0, 0.0, 0.0, false)
	await wait_seconds(2.0)
	var res: Dictionary = v.request_exit(game.player)
	assert_false(res.ok, "Aussteigen bei Fahrt verweigert")
	assert_true(game.player.is_in_vehicle(), "Spieler bleibt im Fahrzeug")


func test_exit_refused_when_boxed_in() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	await wait_seconds(0.5)
	var walls: Array[StaticBody3D] = []
	var c: Vector3 = v.global_position
	var fx: Vector3 = v.global_basis.x
	var fz: Vector3 = v.global_basis.z
	for off: Vector3 in [fx * 1.5, -fx * 1.5, fz * 2.8, -fz * 2.8]:
		var sb := StaticBody3D.new()
		sb.collision_layer = Layers.WORLD
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.6 if absf(off.dot(fx)) > 0.1 else 6.0, 3.0, 6.0 if absf(off.dot(fx)) > 0.1 else 0.6)
		cs.shape = bs
		sb.add_child(cs)
		game.add_child(sb)
		sb.global_transform = Transform3D(v.global_basis, c + off + Vector3.UP * 1.5)
		walls.append(sb)
	await wait_physics(5)
	var res: Dictionary = v.request_exit(game.player)
	assert_false(res.ok, "Aussteigen blockiert, wenn rundum Wände stehen")
	walls[0].queue_free()
	await wait_physics(5)
	var res2: Dictionary = v.request_exit(game.player)
	assert_true(res2.ok, "Aussteigen möglich, sobald eine Seite frei ist")
	assert_gt(game.player.global_position.dot(fx) - c.dot(fx), 0.5, "Ausstieg auf der freien Seite")


func test_crash_causes_damage() -> void:
	var v: Vehicle = _vehicle("kompakt")
	# Fahrzeug quer zur Straße platzieren (Richtung +X) -> Anlauf bis zur Häuserwand bei x = 12
	v.teleport_to(Vector3(-5, 0.1, 60), -PI * 0.5)
	await wait_physics(10)
	await _drive(v)
	var h0: float = v.health
	v.set_controls(1.0, 0.0, 0.0, false)
	var hit: bool = await wait_until(func() -> bool: return v.health < h0, 8.0)
	assert_true(hit, "Aufprall verursacht Schaden")
	assert_lt(v.health, h0, "Lebenspunkte gesunken")
	assert_lt(v.global_position.x, 12.0, "Fahrzeug nicht durch die Wand gefahren")


func test_recovery_when_flipped() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	v.global_transform = Transform3D(Basis(Vector3.FORWARD, PI), v.global_position + Vector3.UP * 1.0)
	await wait_seconds(2.5)
	assert_true(v.is_flipped(), "Fahrzeug liegt auf dem Dach")
	var res: Dictionary = v.try_recover()
	assert_true(res.ok, "Bergung erfolgreich: " + str(res.message))
	await wait_seconds(1.0)
	assert_false(v.is_flipped(), "Nach Bergung aufrecht")
	var res2: Dictionary = v.try_recover()
	assert_false(res2.ok, "Abklingzeit verhindert sofortige erneute Bergung")


func test_lights_and_horn() -> void:
	var v: Vehicle = _vehicle("kompakt")
	await _drive(v)
	var honked: Array[bool] = [false]
	var cb: Callable = func(_p: Vector3) -> void: honked[0] = true
	EventBus.horn.connect(cb)
	v.honk()
	EventBus.horn.disconnect(cb)
	assert_true(honked[0], "Hupe löst Ereignis aus")
	v.set_lights(true)
	assert_true(v.lights_on, "Licht an")
	v.set_lights(false)
	assert_false(v.lights_on, "Licht aus")


func test_autopilot_drives_200m() -> void:
	var v: Vehicle = _vehicle("transporter")
	var ap := Autopilot.new()
	var start: Vector3 = v.global_position
	ap.set_path(PackedVector3Array([Vector3(3, 0, -40), Vector3(3, 0, -110), Vector3(-3, 0, -110), Vector3(-3, 0, 60)]), 13.0)
	v.ai_controller = ap
	v.driver = Vehicle.Driver.AI
	var done: bool = await wait_until(func() -> bool: return ap.finished, 60.0)
	assert_true(done, "Autopilot erreicht das Ziel (Wende inklusive)")
	assert_false(v.is_flipped(), "Kein Überschlag")
	assert_gt(start.distance_to(Vector3(3, 0, -110)), 100.0, "Strecke > 100 m je Richtung")


func test_all_vehicle_types_drive_brake_and_steer() -> void:
	var speeds: Dictionary = {}
	var i: int = 0
	for id: String in ["kompakt", "limousine", "sport", "transporter", "polizei"]:
		var v: Vehicle = game.spawn_vehicle(id, Vector3(100.0 + float(i) * 25.0, 0.1, 0.0), 0.0)
		i += 1
		await wait_physics(30)
		v.driver = Vehicle.Driver.AI
		v.set_controls(1.0, 0.0, 0.0, false)
		await wait_seconds(4.0)
		speeds[id] = v.get_forward_speed()
		assert_gt(v.get_forward_speed(), 12.0, "%s beschleunigt (%.1f m/s)" % [id, v.get_forward_speed()])
		var yaw0: float = v.rotation.y
		v.set_controls(0.5, 0.0, 0.6, false)
		await wait_seconds(1.5)
		assert_gt(absf(angle_difference(yaw0, v.rotation.y)), 0.3, "%s lenkt ein" % id)
		v.set_controls(0.0, 1.0, 0.0, false)
		var stopped: bool = await wait_until(func() -> bool: return absf(v.get_forward_speed()) < 0.5, 8.0)
		assert_true(stopped, "%s bremst bis zum Stillstand" % id)
		assert_false(v.is_flipped(), "%s nicht überschlagen" % id)
		v.set_controls(0.0, 0.0, 0.0, true)
		v.queue_free()
		await wait_physics(2)
	assert_gt(float(speeds.sport), float(speeds.transporter), "Sportwagen schneller als Transporter")
	print("        Geschwindigkeit nach 4 s: %s" % str(speeds))
