extends TestCase
## Alle vom Spiel verwendeten Sounds sind vorhanden und ladbar; fehlende Sounds führen nicht zum Absturz.


func test_required_sounds_exist() -> void:
	for n: String in AudioManager.REQUIRED_SOUNDS:
		assert_true(AudioManager.get_stream(n) != null, "Sound fehlt oder ist nicht ladbar: " + n)


func test_loop_stream_has_loop_points() -> void:
	var s: AudioStream = AudioManager.get_stream("engine_kompakt", true)
	assert_true(s is AudioStreamWAV, "Motorgeräusch ist WAV")
	var w: AudioStreamWAV = s as AudioStreamWAV
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "Schleifenmodus")
	assert_gt(float(w.loop_end), 1000.0, "Schleifenende gesetzt")


func test_missing_sound_is_graceful() -> void:
	assert_true(AudioManager.get_stream("gibt_es_nicht_123") == null, "Fehlender Sound -> null")
	AudioManager.play_2d("gibt_es_nicht_123")  # darf nicht abstürzen


## Regler „Menü-Klänge“ wirkt: eigener Bus „UI“, Menüklänge laufen darüber, Spiel-Effekte nicht.
func test_ui_volume_controls_menu_sounds() -> void:
	var idx: int = AudioServer.get_bus_index("UI")
	assert_true(idx >= 0, "Audiobus UI vorhanden")
	var old: float = Settings.ui_volume
	Settings.ui_volume = 0.0
	Settings.apply()
	assert_true(AudioServer.is_bus_mute(idx), "UI-Lautstärke 0 schaltet den UI-Bus stumm")
	assert_false(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effekte")) and Settings.sfx_volume > 0.001,
		"Effekte bleiben unabhängig")
	AudioManager.play_2d("ui_click", -60.0)
	var last: AudioStreamPlayer = AudioManager._pool2d[(AudioManager._next2d - 1 + AudioManager._pool2d.size()) % AudioManager._pool2d.size()]
	assert_eq(str(last.bus), "UI", "ui_click läuft über den UI-Bus")
	AudioManager.play_2d("checkpoint", -60.0)
	last = AudioManager._pool2d[(AudioManager._next2d - 1 + AudioManager._pool2d.size()) % AudioManager._pool2d.size()]
	assert_eq(str(last.bus), "Effekte", "Spielklang läuft über Effekte")
	Settings.ui_volume = old
	Settings.apply()
