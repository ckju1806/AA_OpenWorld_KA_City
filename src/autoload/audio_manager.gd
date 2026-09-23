extends Node
## Audio-Verwaltung: Busse, Sound-Bibliothek (res://assets/audio/*.wav), 2D/3D-Wiedergabe mit Pool.
## Fehlende Dateien führen nicht zum Absturz (Sound entfällt dann still, einmalige Warnung).

const AUDIO_DIR: String = "res://assets/audio/"
## Vom Spiel verwendete Sounds (Test prüft Vorhandensein; fehlende Dateien -> stumm, kein Absturz)
const REQUIRED_SOUNDS: Array[String] = ["step", "jump", "door", "crash", "horn", "siren", "engine_kompakt",
	"engine_sport", "engine_transporter", "ambience_city", "ui_click", "ui_confirm", "checkpoint",
	"countdown_beep", "countdown_go", "money", "mission_success", "mission_fail", "wanted_up", "music_menu"]
const POOL_3D: int = 16
const POOL_2D: int = 8

var _streams: Dictionary = {}
var _missing: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d: int = 0
var _next2d: int = 0
var _ambience: AudioStreamPlayer
var _music: AudioStreamPlayer


func _enter_tree() -> void:
	_ensure_bus("Musik")
	_ensure_bus("Effekte")
	_ensure_bus("Umgebung")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Effekte"
		p.unit_size = 8.0
		p.max_distance = 120.0
		add_child(p)
		_pool3d.append(p)
	for i: int in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = "Effekte"
		add_child(p2)
		_pool2d.append(p2)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Umgebung"
	_ambience.volume_db = -14.0
	add_child(_ambience)
	_music = AudioStreamPlayer.new()
	_music.bus = "Musik"
	_music.volume_db = -8.0
	add_child(_music)
	Settings.apply()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


## Lädt einen Sound (gecacht). null, wenn nicht vorhanden.
func get_stream(sound_name: String, loop: bool = false) -> AudioStream:
	var key: String = sound_name + ("#loop" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var path: String = AUDIO_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(sound_name):
			_missing[sound_name] = true
			push_warning("Sound fehlt: %s" % path)
		return null
	var s: AudioStream = load(path) as AudioStream
	if s is AudioStreamWAV and loop:
		var w: AudioStreamWAV = (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
		s = w
	_streams[key] = s
	return s


func play_2d(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = get_stream(sound_name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool2d[_next2d]
	_next2d = (_next2d + 1) % _pool2d.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_3d(sound_name: String, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s: AudioStream = get_stream(sound_name)
	if s == null:
		return
	var p: AudioStreamPlayer3D = _pool3d[_next3d]
	_next3d = (_next3d + 1) % _pool3d.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.global_position = position
	p.play()


func play_ambience(sound_name: String) -> void:
	var s: AudioStream = get_stream(sound_name, true)
	if s == null or (_ambience.playing and _ambience.stream == s):
		return
	_ambience.stream = s
	_ambience.play()


func play_music(sound_name: String) -> void:
	var s: AudioStream = get_stream(sound_name, true)
	if s == null or (_music.playing and _music.stream == s):
		return
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_music.stop()


func stop_ambience() -> void:
	_ambience.stop()
