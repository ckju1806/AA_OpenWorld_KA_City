extends GameTestCase
## ÖPNV (W5): Linien/Haltestellen/Tunnel geladen, Fahrzeuge fahren und halten, Pendelbetrieb an Endhaltestellen,
## Einsteigen (Fahrschein) an einer U-Haltestelle, Fahrt durch Tunnel und Rampe, Aussteigen am Haltewunsch,
## Bahn bremst vor Hindernis auf dem Gleis.


func before_each() -> void:
	await start_city_game()
	game.police.patrol_enabled = false
	game.transit.enabled = true   # ohne Umgebungsleben sonst abgeschaltet


func after_each() -> void:
	await stop_game()


func _tr() -> TransitSystem:
	return game.transit


func _line_with_stop(name_part: String, mode: String = "tram") -> Array:
	var tr: TransitSystem = _tr()
	for li: int in tr.lines.size():
		var ln: Dictionary = tr.lines[li]
		if ln.mode != mode:
			continue
		for k: int in (ln.stops as Array).size():
			if str(tr.stops[int(ln.stops[k])].name).contains(name_part) and k < (ln.stops as Array).size() - 1:
				return [li, k]
	return []


## Ein virtuelles Fahrzeug der Linie kurz vor Haltestelle k setzen (beschleunigt den Test gegenüber dem Takt).
func _vehicle_before(li: int, k: int, before: float) -> Dictionary:
	var tr: TransitSystem = _tr()
	var vh: Dictionary = {}
	for v: Dictionary in tr.vehicles:
		if int(v.line) == li:
			vh = v
			break
	assert_false(vh.is_empty(), "Fahrzeug auf Linie %d" % li)
	var ln: Dictionary = tr.lines[li]
	vh.s = maxf(0.0, float(ln.s[k]) - before)
	vh.stop_k = k
	vh.v = 6.0
	vh.dwell = 0.0
	if vh.node != null:
		tr._free_node(vh)
	return vh


func test_lines_stops_and_tunnel_loaded() -> void:
	var tr: TransitSystem = _tr()
	assert_true(tr != null and tr.has_lines(), "ÖPNV-Linien geladen")
	var modes: Dictionary = {}
	var tunnels: int = 0
	for ln: Dictionary in tr.lines:
		modes[ln.mode] = true
		tunnels += (ln.tun as Array).size()
		assert_true(int(ln.get("next", -1)) >= 0, "Linie %s hat Gegenrichtung (Pendelbetrieb)" % ln.name)
	assert_true(modes.has("tram") and modes.has("bus"), "Stadtbahn und Bus vorhanden")
	assert_gt(float(tunnels), 0.0, "Tunnelabschnitte (U-Strab)")
	var under: int = 0
	for st: Dictionary in tr.stops:
		if bool(st.underground):
			under += 1
	assert_gt(float(under), 2.0, "Unterirdische Haltestellen (%d)" % under)
	assert_gt(float(tr.tunnel_root.get_child_count()), 3.0, "Tunnelröhre/Stationen gebaut")
	assert_gt(float(tr.vehicles.size()), 5.0, "Fahrzeuge im Takt verteilt (%d)" % tr.vehicles.size())


func test_vehicle_drives_stops_and_turns_around() -> void:
	var tr: TransitSystem = _tr()
	var found: Array = _line_with_stop("Durlacher Tor")
	assert_false(found.is_empty(), "Linie über Durlacher Tor")
	var li: int = found[0]
	var k: int = found[1]
	var vh: Dictionary = _vehicle_before(li, k, 60.0)
	teleport_player(tr.stop_world_pos(int(tr.lines[li].stops[k])) + Vector3(8, 0.2, 0))
	var t: float = 0.0
	while float(vh.dwell) <= 0.0 and t < 40.0:
		await wait_seconds(0.5)
		t += 0.5
	assert_gt(float(vh.dwell), 0.0, "Fahrzeug hält an der Haltestelle")
	assert_true(vh.node != null, "Fahrzeug in Spielernähe sichtbar")
	var front: Node3D = vh.segs[0]
	var sp: Vector3 = tr.stop_world_pos(int(tr.lines[li].stops[k]))
	assert_lt(Vector2(front.global_position.x - sp.x, front.global_position.z - sp.z).length(), 25.0, "Halt an der Haltestelle")
	await wait_seconds(TransitSystem.DWELL + 3.0)
	assert_gt(float(vh.v), 0.5, "Fährt nach der Haltezeit weiter")
	# Endhaltestelle: Wechsel auf Gegenrichtung
	var ln: Dictionary = tr.lines[li]
	var last: int = (ln.stops as Array).size() - 1
	vh.s = float(ln.s[last]) - 0.2
	vh.stop_k = last
	vh.v = 1.0
	await wait_seconds(TransitSystem.DWELL + 2.0)
	assert_eq(int(vh.line), int(ln.next), "Nach Endhaltestelle in Gegenrichtung unterwegs")


func test_ride_through_tunnel_and_alight() -> void:
	var tr: TransitSystem = _tr()
	var found: Array = _line_with_stop("Kronenplatz")
	assert_false(found.is_empty(), "Linie über Kronenplatz (U)")
	var li: int = found[0]
	var k: int = found[1]
	var si: int = int(tr.lines[li].stops[k])
	assert_true(bool(tr.stops[si].underground), "Kronenplatz ist unterirdisch")
	var vh: Dictionary = _vehicle_before(li, k, 40.0)
	teleport_player(tr.stop_world_pos(si) + Vector3(4, 0.2, 4))
	var t: float = 0.0
	while float(vh.dwell) <= 0.0 and t < 40.0:
		await wait_seconds(0.5)
		t += 0.5
	assert_gt(float(vh.dwell), 0.0, "Bahn hält an der U-Haltestelle")
	assert_lt(float((vh.segs[0] as Node3D).global_position.y), -5.0, "Bahn steht im Tunnel")
	await wait_physics(15)
	var money0: int = GameState.money
	assert_true(interact_nearest(), "Einstiegspunkt gefunden")
	await wait_physics(5)
	assert_true(game.player.is_riding(), "Spieler fährt mit")
	assert_eq(GameState.money, money0 - TransitSystem.FARE, "Fahrschein bezahlt")
	assert_true(game.ride_info.contains("Nächster Halt"), "HUD zeigt nächsten Halt: %s" % game.ride_info)
	interact_nearest()   # Haltewunsch
	await wait_physics(3)
	assert_true(bool(tr.ride.get("want_exit", false)), "Haltewunsch gesetzt")
	var min_y: float = 0.0
	var max_y: float = -99.0
	t = 0.0
	while game.player.is_riding() and t < 150.0:
		await wait_seconds(0.5)
		t += 0.5
		min_y = minf(min_y, game.player.global_position.y)
		max_y = maxf(max_y, game.player.global_position.y)
	assert_false(game.player.is_riding(), "Am nächsten Halt ausgestiegen")
	assert_lt(min_y, -5.0, "Fahrt im Tunnel")
	assert_eq(tr.ride_log.size(), 1, "Fahrt protokolliert")
	var next_si: int = int(tr.lines[li].stops[k + 1])
	assert_true(tr.player_rode_between(str(tr.stops[si].name), str(tr.stops[next_si].name)), "Fahrt %s → %s" % [tr.stops[si].name, tr.stops[next_si].name])
	var pp: Vector3 = game.player.global_position
	var np: Vector3 = tr.stop_world_pos(next_si)
	assert_lt(Vector2(pp.x - np.x, pp.z - np.z).length(), 25.0, "Abgesetzt an der Zielhaltestelle")
	assert_gt(pp.y, -1.0, "Nach dem Aussteigen an der Oberfläche")
	assert_eq(game.ride_info, "", "HUD-Fahrtinfo gelöscht")


func test_tram_brakes_for_obstacle() -> void:
	var tr: TransitSystem = _tr()
	var found: Array = _line_with_stop("Durlacher Tor")
	var li: int = found[0]
	var k: int = found[1]
	var ln: Dictionary = tr.lines[li]
	# Hindernis 120 m hinter der Haltestelle (Oberfläche) auf das Gleis stellen
	var s_obst: float = float(ln.s[k]) + 140.0
	var pd: Array = tr.point_at(ln, s_obst)
	var d: Vector2 = pd[1]
	var right: Vector2 = Vector2(-d.y, d.x)
	var p2: Vector2 = (pd[0] as Vector2) + right * tr.track_offset
	load_at(Vector3(p2.x, 0, p2.y))
	var car: Vehicle = game.spawn_vehicle("kompakt", Vector3(p2.x, city().ground_y(p2) + 0.4, p2.y), atan2(-d.x, -d.y))
	await wait_physics(10)
	var vh: Dictionary = _vehicle_before(li, k + 1, float(ln.s[k + 1]) - float(ln.s[k]) - 10.0)
	vh.s = float(ln.s[k]) + 20.0
	teleport_player(Vector3(p2.x, 0.2, p2.y) + Vector3(right.x, 0, right.y) * 12.0)
	await wait_seconds(30.0)
	assert_true(vh.node != null, "Bahn sichtbar")
	var gap: float = s_obst - float(vh.s)
	assert_gt(gap, 2.0, "Bahn hält vor dem Hindernis (Abstand %.1f m)" % gap)
	assert_lt(float(vh.v), 0.5, "Bahn steht")
	car.queue_free()
	await wait_seconds(8.0)
	assert_gt(float(vh.v), 1.0, "Fährt nach Freigabe weiter")
