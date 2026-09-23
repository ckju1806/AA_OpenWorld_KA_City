class_name ScreenshotTour
extends Node
## Automatische Screenshot-Tour zur visuellen Kontrolle (nur mit "-- --screenshot-tour").
## Speichert PNGs nach --shot-dir=<Pfad> (Standard: user://screenshots) und beendet das Spiel.

var game: Node = null
var out_dir: String = "user://screenshots"
var _stations: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot-dir="):
			out_dir = a.substr(11)
	DirAccess.make_dir_recursive_absolute(out_dir if out_dir.is_absolute_path() else ProjectSettings.globalize_path(out_dir))
	_run.call_deferred()


## station: { name, setup: Callable, frames: int }
func add_station(station_name: String, setup: Callable, frames: int = 45) -> void:
	_stations.append({"name": station_name, "setup": setup, "frames": frames})


func _run() -> void:
	for i: int in 20:
		await get_tree().process_frame
	if game != null and game.has_method("register_screenshot_stations"):
		game.call("register_screenshot_stations", self)
	var idx: int = 0
	for st: Dictionary in _stations:
		idx += 1
		var setup: Callable = st.setup
		if setup.is_valid():
			await setup.call()
		for f: int in int(st.frames):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/%02d_%s.png" % [out_dir, idx, st.name]
		var err: Error = img.save_png(path)
		print("[screenshot] %s -> %s" % [path, error_string(err)])
	print("[screenshot] Tour beendet (%d Bilder)." % _stations.size())
	get_tree().quit(0)
