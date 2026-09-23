extends TestCase
## Fahndungslogik: Auslöser, Eskalation, Sichtverlust, Suchphase, Abbau auf 0.


func test_unwitnessed_crime_has_no_effect() -> void:
	var w := WantedLogic.new()
	assert_eq(w.report_crime("fahrzeugraub", Vector3.ZERO, false), 0, "Unbeobachtet -> Stufe 0")
	assert_eq(w.state, "frei", "Zustand frei")


func test_witnessed_crime_sets_level_and_position() -> void:
	var w := WantedLogic.new()
	w.report_crime("fahrzeugdiebstahl", Vector3(10, 0, 20), true)
	assert_eq(w.level, 1, "Stufe 1")
	assert_eq(w.state, "verfolgung", "Verfolgung")
	assert_eq(w.last_known, Vector3(10, 0, 20), "Zuletzt bekannte Position = Tatort")


func test_escalation_capped_at_three() -> void:
	var w := WantedLogic.new()
	w.report_crime("fahrzeugraub", Vector3.ZERO, true)
	w.report_crime("polizei_rammen", Vector3.ZERO, true)
	assert_eq(w.level, 2, "Eskalation auf 2")
	w.report_crime("streifenwagen", Vector3.ZERO, true)
	w.report_crime("polizei_rammen", Vector3.ZERO, true)
	assert_eq(w.level, 3, "Maximal 3")


func test_search_phase_and_decay_to_zero() -> void:
	var w := WantedLogic.new()
	w.force_level(2, Vector3(5, 0, 5))
	# Sichtkontakt hält die Verfolgung aufrecht und aktualisiert die Position
	w.update(1.0, true, Vector3(50, 0, 50))
	assert_eq(w.last_known, Vector3(50, 0, 50), "Position aktualisiert bei Sicht")
	# Ohne Sicht: nach 2,5 s Suchphase
	for i: int in 30:
		w.update(0.1, false, Vector3(999, 0, 999))
	assert_eq(w.state, "suche", "Suchphase nach Sichtverlust")
	assert_eq(w.last_known, Vector3(50, 0, 50), "Polizei kennt die neue Position nicht")
	# Suchphase Stufe 2 = 26 s
	for i2: int in 250:
		w.update(0.1, false, Vector3.ZERO)
	assert_eq(w.level, 2, "Vor Ablauf der Suchzeit noch aktiv")
	for i3: int in 20:
		w.update(0.1, false, Vector3.ZERO)
	assert_eq(w.level, 0, "Fahndung endet nach Suchphase")
	assert_eq(w.state, "frei", "Zustand frei")


func test_resighting_restarts_pursuit() -> void:
	var w := WantedLogic.new()
	w.force_level(1, Vector3.ZERO)
	for i: int in 40:
		w.update(0.1, false, Vector3.ZERO)
	assert_eq(w.state, "suche", "Suche")
	w.update(0.1, true, Vector3(1, 0, 1))
	assert_eq(w.state, "verfolgung", "Wieder Verfolgung bei Sicht")
	assert_near(w.search_time, 0.0, 0.001, "Suchzeit zurückgesetzt")


func test_configurable_search_duration() -> void:
	var w := WantedLogic.new()
	w.search_durations = [0.0, 5.0, 5.0, 5.0]
	w.force_level(3, Vector3.ZERO)
	for i: int in 80:
		w.update(0.1, false, Vector3.ZERO)
	assert_eq(w.level, 0, "Kurze konfigurierte Suchphase")
