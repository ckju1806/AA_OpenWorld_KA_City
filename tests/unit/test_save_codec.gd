extends TestCase
## Speicherformat: Roundtrip, beschädigte Daten, fehlende Felder, zukünftige Version, ungültige Position.


func test_roundtrip() -> void:
	var text: String = SaveCodec.encode({"money": 500, "completed_missions": ["m01"]},
		{"position": SaveCodec.vec3_to_array(Vector3(10, 0.5, -20)), "yaw": 1.0, "health": 80.0})
	var res: Dictionary = SaveCodec.decode(text)
	assert_true(res.ok, "Decode ok")
	var p: Dictionary = res.data.player
	assert_true(p.has("position"), "Position vorhanden")
	assert_near((p.position as Vector3).x, 10.0, 0.01, "Position x")
	assert_near(float(p.health), 80.0, 0.01, "Lebenspunkte")
	assert_eq(int(res.data.state.money), 500, "Geld")


func test_corrupt_json() -> void:
	var res: Dictionary = SaveCodec.decode("{ \"format\": \"faecherstadt-save\", \"version\": 1, ")
	assert_false(res.ok, "Beschädigtes JSON muss abgelehnt werden")
	assert_true(str(res.error).length() > 0, "Fehlermeldung vorhanden")


func test_empty_and_wrong_format() -> void:
	assert_false(SaveCodec.decode("").ok, "Leere Datei")
	assert_false(SaveCodec.decode("[1,2,3]").ok, "Array statt Objekt")
	assert_false(SaveCodec.decode("{\"format\": \"anderes-spiel\", \"version\": 1}").ok, "Fremdes Format")


func test_future_version_rejected() -> void:
	var res: Dictionary = SaveCodec.decode("{\"format\": \"faecherstadt-save\", \"version\": 99, \"state\": {}}")
	assert_false(res.ok, "Zukünftige Version")


func test_missing_fields_use_defaults() -> void:
	var res: Dictionary = SaveCodec.decode("{\"format\": \"faecherstadt-save\", \"version\": 1}")
	assert_true(res.ok, "Minimaler Spielstand ist gültig")
	assert_false((res.data.player as Dictionary).has("position"), "Keine Position -> Startpunkt")
	assert_true((res.warnings as Array).size() >= 1, "Warnung für fehlende Daten")


func test_invalid_position_dropped() -> void:
	var text: String = SaveCodec.encode({}, {"position": [99999.0, 0.0, 0.0], "yaw": 0.0, "health": 100.0})
	var res: Dictionary = SaveCodec.decode(text)
	assert_true(res.ok, "Decode ok")
	assert_false((res.data.player as Dictionary).has("position"), "Position außerhalb der Welt verworfen")
	var text2: String = "{\"format\": \"faecherstadt-save\", \"version\": 1, \"player\": {\"position\": [\"a\", 1, 2], \"health\": 0}}"
	var res2: Dictionary = SaveCodec.decode(text2)
	assert_true(res2.ok, "Decode ok")
	assert_false((res2.data.player as Dictionary).has("position"), "Nicht-numerische Position verworfen")
	assert_near(float(res2.data.player.health), 10.0, 0.01, "Lebenspunkte auf Minimum angehoben")
