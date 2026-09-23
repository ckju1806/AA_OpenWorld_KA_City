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
