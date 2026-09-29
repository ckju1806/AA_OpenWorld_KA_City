class_name EventsBasic
extends RefCounted
## Konkrete Zufallsereignisse (W7): Rangelei/Revierstreit, Taschendiebstahl mit Flucht, Straßenrennen,
## Kundgebung (kann zur Unruhe eskalieren), Polizeikontrolle. Fabrik: create(kind).


static func create(kind: String) -> GameEvent:
	match kind:
		"scuffle":
			return Scuffle.new()
		"theft":
			return Theft.new()
		"race":
			return Race.new()
		"rally":
			return Rally.new()
		"police_check":
			return PoliceCheck.new()
	return null


## Rangelei zwischen zwei fiktiven Gruppen (Revierstreit an der Grenze zweier Reviere).
class Scuffle extends GameEvent:
	var side_a: Array[EventActor] = []
	var side_b: Array[EventActor] = []
	var phase: int = 0

	func start() -> bool:
		kind = "scuffle"
		var g: Array = director.gangs_near(pos)
		title = "Revierstreit" if g.size() >= 2 else "Rangelei"
		max_time = 75.0
		var col_a: Color = director.gang_color(g[0]) if g.size() > 0 else Color(-1, 0, 0)
		var col_b: Color = director.gang_color(g[1]) if g.size() > 1 else Color(-1, 0, 0)
		var n: int = 2 + rng.randi() % 2
		for i: int in n:
			side_a.append(spawn_actor(pos + Vector3(-5.0 - float(i), 0, float(i) * 1.2), col_a))
			side_b.append(spawn_actor(pos + Vector3(5.0 + float(i), 0, float(i) * 1.2 - 0.6), col_b))
		for a: EventActor in side_a:
			a.go_to(pos + Vector3(-1.2, 0, rng.randf_range(-1.5, 1.5)), 1.8)
		for b: EventActor in side_b:
			b.go_to(pos + Vector3(1.2, 0, rng.randf_range(-1.5, 1.5)), 1.8)
		return true

	func update(_delta: float) -> void:
		if phase == 0 and t > 4.0:
			phase = 1
			bark(side_a[0], director.line("scuffle_lines"))
		if phase >= 1 and rng.randf() < 0.08:
			var a: EventActor = side_a[rng.randi() % side_a.size()]
			var b: EventActor = side_b[rng.randi() % side_b.size()]
			if rng.randf() < 0.5:
				a.shove(b.global_position)
				if rng.randf() < 0.25:
					b.knock_down(false)
			else:
				b.shove(a.global_position)
			if rng.randf() < 0.2:
				bark(b, director.line("scuffle_lines"))
		if t > 18.0:
			call_police(40.0)
		# Polizei vor Ort -> Gruppen zerstreuen sich
		if phase < 2 and director.police_near(pos, 30.0):
			phase = 2
			for a2: EventActor in actors:
				a2.flee_from(pos, 40.0)
			bark(actors[0], "Weg hier, Polizei!")
			max_time = t + 12.0
		# Spieler mischt sich ein (nah + Hupe o. ä. ist egal): Gruppe B flieht, wenn A am Boden
		var down_a: int = 0
		for x: EventActor in side_a:
			if x.is_down():
				down_a += 1
		if down_a == side_a.size() and phase < 2:
			phase = 2
			for y: EventActor in side_b:
				y.flee_from(pos, 35.0)
			max_time = t + 10.0


## Taschendiebstahl: Täter rennt weg, Opfer ruft um Hilfe. Den Täter umrennen (zu Fuß, sprintend) = Belohnung.
class Theft extends GameEvent:
	var thief: EventActor
	var victim: EventActor
	var caught: bool = false

	func start() -> bool:
		kind = "theft"
		title = "Taschendiebstahl"
		max_time = 60.0
		victim = spawn_actor(pos)
		thief = spawn_actor(pos + Vector3(1.0, 0, 0.5))
		var away: Vector3 = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		thief.target = pos + away * 70.0
		thief.speed = 4.2
		thief.mode = EventActor.Mode.FLEE
		bark(victim, director.line("theft_lines"))
		EventBus.notify.emit("In der Nähe: Taschendieb auf der Flucht! (umrennen)", "info")
		return true

	func update(_delta: float) -> void:
		if not caught and thief.is_down():
			caught = true
			GameState.add_money(80)
			GameState.add_reputation("buerger", 2)
			GameState.add_stat("diebe_gestellt")
			EventBus.notify.emit("Dieb gestellt: +80 € Finderlohn", "erfolg")
			AudioManager.play_2d("money", -4.0)
			bark(victim, "Danke! Endlich!")
			call_police(25.0)
			max_time = t + 15.0
		if not caught and t > 6.0 and thief.mode == EventActor.Mode.STAND:
			# Täter entkommen: verschwindet in der Menge
			thief.flee_from(director.player_pos(), 40.0)
		if t > 10.0 and not caught:
			call_police(30.0)


## Straßenrennen: zwei Fahrzeuge rasen über Hauptstraßen, ignorieren Ampeln; Polizei folgt ggf.
class Race extends GameEvent:
	func start() -> bool:
		kind = "race"
		title = "Illegales Straßenrennen"
		max_time = 70.0
		var spots: Array = director.race_start(pos)
		if spots.is_empty():
			return false
		for i: int in 2:
			var sp: Dictionary = spots[i]
			var v: Vehicle = director.game.call("spawn_vehicle", "sport" if i == 0 else "kompakt", sp.pos, sp.yaw,
				[Color(0.9, 0.85, 0.1), Color(0.1, 0.6, 0.9)][i], Vehicle.Ownership.TRAFFIC, "") as Vehicle
			var drv := TrafficDriver.new(rng.randi())
			drv.setup(director.graph, director.lights, sp.plan)
			drv.ignore_lights = true
			drv.speed_limit_override = 24.0 + float(i) * 2.0
			drv.personality = 1.0
			v.ai_controller = drv
			v.driver = Vehicle.Driver.AI
			v.set_lights(true)
			v.add_to_group("racers")
			vehicles.append(v)
		EventBus.notify.emit("Straßenrennen in der Nähe!", "warnung")
		AudioManager.play_3d("engine_sport", vehicles[0].global_position, 0.0, 1.3)
		return true

	func update(_delta: float) -> void:
		if t > 8.0:
			call_police(50.0)
		var all_gone: bool = true
		for v: Vehicle in vehicles:
			if is_instance_valid(v):
				all_gone = false
				pos = v.global_position
		if all_gone:
			done = true


## Kundgebung auf einem Platz (friedlich, fiktive Anliegen); kann bei Polizeipräsenz/Chaos-Modus zur Unruhe eskalieren.
class Rally extends GameEvent:
	var slogan: String = ""
	var escalated: bool = false
	var signs: Array[Node3D] = []

	func start() -> bool:
		kind = "rally"
		title = "Kundgebung"
		max_time = 150.0
		slogan = director.line("rally_slogans")
		var n: int = 10 + rng.randi() % 8
		for i: int in n:
			var ang: float = rng.randf() * TAU
			var r: float = rng.randf_range(1.5, 7.0)
			var a: EventActor = spawn_actor(pos + Vector3(cos(ang) * r, 0, sin(ang) * r))
			a.mode = EventActor.Mode.CHEER
			a.rotation.y = rng.randf() * TAU
			if i % 3 == 0:
				_sign(a)
		EventBus.notify.emit("Kundgebung in der Nähe: „%s“" % slogan, "info")
		return true

	func _sign(a: EventActor) -> void:
		var kit := MeshKit.new()
		kit.set_material("m", MatLib.vertex_color(0.8))
		kit.color = Color(0.45, 0.32, 0.2)
		kit.add_box("m", Vector3(0.35, 1.5, 0), Vector3(0.05, 1.4, 0.05))
		kit.color = [Color(0.95, 0.95, 0.9), Color(0.95, 0.85, 0.2), Color(0.3, 0.75, 0.4)][rng.randi() % 3]
		kit.add_box("m", Vector3(0.35, 2.3, 0), Vector3(0.9, 0.6, 0.04))
		var mi := MeshInstance3D.new()
		mi.mesh = kit.commit()
		a.add_child(mi)
		signs.append(mi)

	func update(_delta: float) -> void:
		if rng.randf() < 0.05 and not actors.is_empty():
			bark(actors[rng.randi() % actors.size()], slogan)
		if not escalated and Settings.events_unrest and t > 30.0 and rng.randf() < (0.02 if CheatManager.is_active("CHAOSTAG") else 0.004):
			escalated = true
			title = "Unruhe"
			EventBus.notify.emit("Die Kundgebung kippt – Unruhe am Platz!", "warnung")
			call_police(60.0)
			for a: EventActor in actors:
				if rng.randf() < 0.4:
					a.go_to(pos + Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)), 3.5)
		if escalated and rng.randf() < 0.06 and actors.size() > 1:
			var a1: EventActor = actors[rng.randi() % actors.size()]
			var a2: EventActor = actors[rng.randi() % actors.size()]
			if a1 != a2:
				a1.shove(a2.global_position)
		if escalated and director.police_near(pos, 35.0) and t > max_time - 30.0:
			for a3: EventActor in actors:
				a3.flee_from(pos, 30.0)


## Polizeikontrolle: Streifenwagen am Fahrbahnrand hält ein Fahrzeug an; wer mit Fahndung vorbeifährt, fällt auf.
class PoliceCheck extends GameEvent:
	var officer: EventActor
	var noticed: bool = false

	func start() -> bool:
		kind = "police_check"
		title = "Verkehrskontrolle"
		max_time = 90.0
		var spot: Dictionary = director.curb_spot(pos)
		if spot.is_empty():
			return false
		pos = spot.pos
		var p: Vehicle = director.game.call("spawn_vehicle", "polizei", spot.pos, spot.yaw, Color(-1, 0, 0), Vehicle.Ownership.POLICE, "") as Vehicle
		p.set_lights(true)
		p.add_to_group("police_check")
		vehicles.append(p)
		var fwd: Vector3 = Vector3(-sin(spot.yaw), 0, -cos(spot.yaw))
		var c: Vehicle = director.game.call("spawn_vehicle", "kompakt", spot.pos + fwd * 9.0, spot.yaw) as Vehicle
		vehicles.append(c)
		var side: Vector3 = fwd.cross(Vector3.UP).normalized()
		officer = spawn_actor(spot.pos + fwd * 8.0 + side * 1.6, Color(0.1, 0.2, 0.45))
		officer.rotation.y = spot.yaw + PI * 0.5
		return true

	func update(_delta: float) -> void:
		if noticed:
			return
		var pp: Vector3 = director.player_pos()
		if pp.distance_to(pos) < 25.0 and int(director.game.call("get_wanted_level")) > 0:
			noticed = true
			bark(officer, "Halt! Stehen bleiben!")
			director.game.call("set_wanted", maxi(int(director.game.call("get_wanted_level")), 2), "An Kontrolle erkannt", pp)
