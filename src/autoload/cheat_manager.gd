extends Node
## Cheat-Manager: erweiterbare Registry eigener deutscher Codes (keine Codes anderer Spiele).
## Eingabe: während des Spiels einfach den Code tippen (Buchstaben, Groß-/Kleinschreibung egal) oder in der
## Cheat-Konsole (Taste ^) eingeben. Schalt-Cheats lassen sich einzeln aus- oder alle mit ALLESZURUECK zurücksetzen.
## Nur aktiv, wenn in den Optionen erlaubt (Settings.cheats_enabled). Benutzung wird im Spielstand vermerkt.

signal changed
signal activated(code: String, active: bool)

const BUFFER_LEN: int = 24

## Registry: code -> {name, desc, cat, toggle: bool, action: Callable}
var cheats: Dictionary = {}
var active: Dictionary = {}          ## Schalt-Cheats: code -> true
var _buffer: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_defaults()


## Neuen Cheat anmelden (für Erweiterungen).
func register(code: String, cheat_name: String, desc: String, category: String, toggle: bool, action: Callable) -> void:
	cheats[code.to_upper()] = {"name": cheat_name, "desc": desc, "cat": category, "toggle": toggle, "action": action}


func is_active(code: String) -> bool:
	return active.has(code.to_upper())


func _game() -> Node:
	return get_tree().get_first_node_in_group("game") if is_inside_tree() else null


## Code ausführen. Liefert eine Rückmeldung (leer = unbekannt).
func enter(text: String) -> String:
	var code: String = text.strip_edges().to_upper().replace(" ", "")
	if code == "":
		return ""
	if not Settings.cheats_enabled:
		return "Cheats sind in den Optionen deaktiviert."
	if not cheats.has(code):
		return ""
	var c: Dictionary = cheats[code]
	var msg: String = ""
	if bool(c.toggle):
		var on: bool = not active.has(code)
		if on:
			active[code] = true
		else:
			active.erase(code)
		msg = str(c.action.call(on)) if c.action.is_valid() else ""
		if msg == "":
			msg = "%s: %s" % [c.name, "an" if on else "aus"]
		activated.emit(code, on)
	else:
		msg = str(c.action.call()) if c.action.is_valid() else ""
		if msg == "":
			msg = str(c.name)
		activated.emit(code, true)
	GameState.set_flag("cheats_used", true)
	GameState.add_stat("cheats_eingegeben")
	EventBus.notify.emit("Cheat: " + msg, "info")
	AudioManager.play_2d("checkpoint", -8.0)
	changed.emit()
	return msg


func reset_all() -> String:
	for code: String in active.keys():
		var c: Dictionary = cheats.get(code, {})
		if not c.is_empty() and c.action.is_valid():
			c.action.call(false)
	active.clear()
	changed.emit()
	return "Alle Cheats zurückgesetzt"


func _unhandled_input(event: InputEvent) -> void:
	if not Settings.cheats_enabled or get_tree().paused:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ch: int = (event as InputEventKey).unicode
		if ch >= 65 and ch <= 90 or ch >= 97 and ch <= 122:
			_buffer = (_buffer + char(ch).to_upper()).right(BUFFER_LEN)
			for code: String in cheats:
				if _buffer.ends_with(code):
					_buffer = ""
					enter(code)
					return


# ------------------------------------------------------------------ Standard-Cheats

func _register_defaults() -> void:
	# Spieler
	register("GESUNDBRUNNEN", "Volle Gesundheit", "Lebenspunkte auffüllen", "Spieler", false, func() -> String:
		var g: Node = _game()
		if g != null:
			(g.get("player") as Player).set_health(Player.MAX_HEALTH)
		return "Volle Gesundheit")
	register("UNVERWUNDBAR", "Unverwundbar", "Kein Schaden für die Spielfigur", "Spieler", true, Callable())
	register("SUPERSPRUNG", "Supersprung", "Deutlich höhere Sprünge", "Spieler", true, Callable())
	register("TURBOSCHUHE", "Turboschuhe", "Schneller rennen", "Spieler", true, Callable())
	register("GELDREGEN", "Geldregen", "+10 000 €", "Spieler", false, func() -> String:
		GameState.add_money(10000)
		return "Geldregen: +10 000 €")
	register("AUSRUESTUNG", "Ausrüstung", "Platzhalter (kein Waffensystem im Spiel)", "Spieler", false, func() -> String:
		return "Ausrüstung: Platzhalter – das Spiel hat bewusst kein Waffensystem")
	# Fahndung
	register("BLAULICHTWEG", "Fahndung löschen", "Fahndungsstufe auf 0", "Polizei", false, func() -> String:
		var g: Node = _game()
		if g != null:
			g.call("reset_wanted")
		return "Fahndung gelöscht")
	register("SIRENENALARM", "Fahndung erhöhen", "Fahndungsstufe +1", "Polizei", false, func() -> String:
		var g: Node = _game()
		if g != null:
			var pl: Node3D = g.get("player")
			g.call("set_wanted", mini(int(g.call("get_wanted_level")) + 1, 3), "Cheat", pl.global_position)
		return "Fahndungsstufe erhöht")
	register("UNSICHTBAR", "Polizei ignoriert dich", "Keine neuen Fahndungen", "Polizei", true, Callable())
	# Fahrzeuge
	register("FAECHERFLITZER", "Sportwagen", "Sportwagen neben dir", "Fahrzeuge", false, func() -> String: return _spawn_car("sport"))
	register("LIEFERDIENST", "Transporter", "Transporter neben dir", "Fahrzeuge", false, func() -> String: return _spawn_car("transporter"))
	register("DIENSTWAGEN", "Limousine", "Limousine neben dir", "Fahrzeuge", false, func() -> String: return _spawn_car("limousine"))
	register("KLEINWAGEN", "Kompaktwagen", "Kompaktwagen neben dir", "Fahrzeuge", false, func() -> String: return _spawn_car("kompakt"))
	register("WERKSTATT", "Reparatur", "Aktuelles Fahrzeug reparieren", "Fahrzeuge", false, func() -> String:
		var g: Node = _game()
		var pl: Player = g.get("player") if g != null else null
		if pl == null or not pl.is_in_vehicle():
			return "Werkstatt: nur im Fahrzeug"
		(pl.current_vehicle as Vehicle).repair()
		return "Fahrzeug repariert")
	register("PANZERGLAS", "Unzerstörbares Fahrzeug", "Eigenes Fahrzeug nimmt keinen Schaden", "Fahrzeuge", true, Callable())
	register("MONDFAHRT", "Mondfahrt", "Geringe Schwerkraft für Fahrzeuge", "Fahrzeuge", true, func(on: bool) -> String:
		for v: Node in get_tree().get_nodes_in_group("vehicles"):
			(v as RigidBody3D).gravity_scale = 0.35 if on else 1.0
		return "Mondfahrt: %s" % ("an" if on else "aus"))
	# Welt
	register("MORGENSONNE", "Morgen", "Uhrzeit 08:00", "Welt", false, func() -> String: return _time(8.0))
	register("MITTAGSPAUSE", "Mittag", "Uhrzeit 13:00", "Welt", false, func() -> String: return _time(13.0))
	register("FEIERABEND", "Abend", "Uhrzeit 19:30", "Welt", false, func() -> String: return _time(19.5))
	register("KARLSRUHESCHLAEFT", "Nacht", "Uhrzeit 23:30", "Welt", false, func() -> String: return _time(23.5))
	register("ZEITSTOPP", "Zeit anhalten", "Tageszeit bleibt stehen", "Welt", true, func(on: bool) -> String:
		WorldClock.paused = on
		return "Zeit angehalten" if on else "Zeit läuft wieder")
	register("ZEITRAFFER", "Zeitraffer", "Tageszeit läuft 10-mal schneller", "Welt", true, func(on: bool) -> String:
		WorldClock.speed_mult = 10.0 if on else 1.0
		return "Zeitraffer: %s" % ("an" if on else "aus"))
	register("BADISCHESONNE", "Sonnenschein", "Wetter klar", "Welt", false, func() -> String: return _weather("klar"))
	register("WOLKENDECKE", "Bewölkt", "Wetter bewölkt", "Welt", false, func() -> String: return _weather("bewoelkt"))
	register("DAUERREGEN", "Regen", "Wetter Regen", "Welt", false, func() -> String: return _weather("regen"))
	register("NEBELSUPPE", "Nebel", "Wetter Nebel", "Welt", false, func() -> String: return _weather("nebel"))
	register("LEERESTADT", "Leere Stadt", "Kein Verkehr, keine Passanten", "Welt", true, func(on: bool) -> String:
		active.erase("RUSHHOUR")
		Settings.changed.emit()
		return "Leere Stadt: %s" % ("an" if on else "aus"))
	register("RUSHHOUR", "Berufsverkehr", "Doppelter Verkehr und mehr Passanten", "Welt", true, func(on: bool) -> String:
		active.erase("LEERESTADT")
		Settings.changed.emit()
		return "Berufsverkehr: %s" % ("an" if on else "aus"))
	register("CHAOSTAG", "Chaos-Modus", "Häufige Ereignisse, gereizte Stadt", "Welt", true, Callable())
	register("RUHETAG", "Ruhetag", "Keine Zufallsereignisse", "Welt", true, Callable())
	# Teleport
	for t: Array in [["ZUMSCHLOSS", "Schloss", "schloss", Vector2(0, 120)], ["ZUMMARKTPLATZ", "Marktplatz", "pyramide", Vector2(0, 25)],
			["ZUMBAHNHOF", "Hauptbahnhof", "hauptbahnhof", Vector2(0, -60)], ["ZUMZOO", "Zoo", "zoo", Vector2(0, 290)],
			["ZUMSTADION", "Stadion", "stadion", Vector2(0, 110)], ["ZUMHAFEN", "Rheinhafen", "hafenkran", Vector2(0, 40)],
			["NACHDURLACH", "Durlach (Turmberg)", "turmberg", Vector2(0, -30)]]:
		var lm_type: String = t[2]
		var off: Vector2 = t[3]
		register(t[0], "Teleport: " + str(t[1]), "Zum Ort " + str(t[1]), "Teleport", false, func() -> String:
			return _teleport_landmark(lm_type, off, str(t[1])))
	register("ALLESZURUECK", "Alles zurücksetzen", "Alle Schalt-Cheats aus", "System", false, func() -> String: return reset_all())


func _time(h: float) -> String:
	WorldClock.set_time(h)
	return "Uhrzeit %s" % WorldClock.time_text()


func _weather(kind: String) -> String:
	WorldClock.set_weather(kind, true)
	return "Wetter: %s" % WorldClock.LABELS.get(kind, kind)


func _spawn_car(spec: String) -> String:
	var g: Node = _game()
	if g == null:
		return "Nur im Spiel"
	var pl: Player = g.get("player")
	var fwd: Vector3 = -pl.global_basis.z
	if pl.is_in_vehicle():
		fwd = -(pl.current_vehicle as Node3D).global_basis.z
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var pos: Vector3 = pl.global_position + right * 4.5 + fwd * 3.0 + Vector3.UP * 0.4
	g.call("spawn_vehicle", spec, pos, atan2(-fwd.x, -fwd.z))
	return "Fahrzeug bereitgestellt: %s" % VehicleSpec.get_spec(spec).display_name


func _teleport_landmark(lm_type: String, offset: Vector2, label: String) -> String:
	var g: Node = _game()
	if g == null:
		return "Nur im Spiel"
	var cw: CityWorld = g.call("get_city")
	if cw == null:
		return "Nur in der Stadt"
	for lm: Variant in cw.graph.layout.landmarks:
		if str(lm.type) == lm_type:
			var c: Vector2 = Vector2(float(lm.pos[0]), float(lm.pos[1]))
			var ne: Dictionary = cw.graph.nearest_edge_point(c + offset, "all", 400.0)
			var p2: Vector2 = ne.point if int(ne.edge) >= 0 else c + offset
			g.call("teleport_player", Vector3(p2.x, 0.0, p2.y))
			return "Teleport: " + label
	return "Ort nicht gefunden"


## Dichte-Faktor für Verkehr/Passanten (Cheats „Leere Stadt“ / „Berufsverkehr“).
func density_mult() -> float:
	if active.has("LEERESTADT"):
		return 0.0
	if active.has("RUSHHOUR"):
		return 2.0
	return 1.0
