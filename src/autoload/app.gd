extends Node
## Spielablauf auf oberster Ebene: Szenenwechsel (Hauptmenü <-> Spiel), Mausmodus,
## Übergabe geladener Spielstände an die Spielszene.

const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const GAME_SCENE: String = "res://scenes/game.tscn"

## Vom Hauptmenü an die Spielszene übergebene Startdaten.
var pending_load: Dictionary = {}
var pending_message: String = ""
## Kommandozeilen-Optionen (nach "--"): --screenshot-tour, --autostart
var user_args: PackedStringArray = PackedStringArray()


var _cb_layer: CanvasLayer
var _cb_mat: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	user_args = OS.get_cmdline_user_args()
	get_tree().root.focus_exited.connect(_on_focus_lost)
	# Farbfilter (Barrierefreiheit), über allem
	_cb_layer = CanvasLayer.new()
	_cb_layer.layer = 120
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cb_mat = ShaderMaterial.new()
	_cb_mat.shader = load("res://assets/shaders/colorblind.gdshader")
	rect.material = _cb_mat
	_cb_layer.add_child(rect)
	add_child(_cb_layer)
	Settings.changed.connect(_apply_colorblind)
	_apply_colorblind()


func _apply_colorblind() -> void:
	_cb_layer.visible = Settings.colorblind > 0
	_cb_mat.set_shader_parameter("mode", Settings.colorblind)


func has_arg(arg: String) -> bool:
	return user_args.has(arg)


func start_new_game() -> void:
	GameState.reset_new_game()
	pending_load = {}
	pending_message = ""
	_change_scene(GAME_SCENE)


## Lädt den Spielstand und startet das Spiel. Rückgabe: Fehlermeldung oder "".
func continue_game() -> String:
	var res: Dictionary = SaveManager.load_game()
	if not res.ok:
		return str(res.message)
	var data: Dictionary = res.data
	GameState.from_dict(data.get("state", {}))
	pending_load = data.get("player", {})
	var notes: Array[String] = []
	if str(res.get("message", "")) != "":
		notes.append(str(res.message))
	for w: Variant in res.get("warnings", []):
		notes.append(str(w))
	pending_message = " ".join(notes)
	_change_scene(GAME_SCENE)
	return ""


func goto_main_menu() -> void:
	get_tree().paused = false
	set_mouse_captured(false)
	_change_scene(MAIN_MENU_SCENE)


func quit_game() -> void:
	Settings.save_settings()
	get_tree().quit()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Szene konnte nicht geladen werden: %s (%s)" % [path, error_string(err)])


func set_mouse_captured(captured: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func _on_focus_lost() -> void:
	# Fensterfokus verloren -> Spiel pausieren (verhindert "gefangene" Maus und Weiterlaufen)
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("request_pause"):
		scene.call("request_pause")
