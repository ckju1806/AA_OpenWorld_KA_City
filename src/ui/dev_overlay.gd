class_name DevOverlay
extends CanvasLayer
## Entwickleranzeige (F3): Bildrate, Renderstatistik, Objektzahlen, Position, Fahrzeug, Fahndung, Mission.
## Unabhängig davon zeigt die Einstellung "FPS anzeigen" nur die Bildrate.

var game: Node = null
var _label: Label
var _fps: Label
var _t: float = 0.0
var detailed: bool = false


func setup(p_game: Node) -> void:
	game = p_game
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel: PanelContainer = UiStyle.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 32
	add_child(panel)
	_label = UiStyle.label("", 17)
	panel.add_child(_label)
	panel.visible = false
	_fps = UiStyle.label("", 18, UiStyle.GOOD, 6)
	_fps.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps.offset_left = -130
	_fps.offset_right = -12
	_fps.offset_top = 4
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fps)


func toggle() -> void:
	detailed = not detailed
	(_label.get_parent() as Control).visible = detailed
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	_refresh()


func _refresh() -> void:
	_fps.visible = Settings.show_fps and not detailed
	_fps.text = "%d FPS" % Engine.get_frames_per_second()
	if not detailed or game == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS %d   Frame %.1f ms   Physik %.1f ms" % [Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("Draw Calls %d   Objekte %d   Knoten %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	lines.append("Videospeicher %.0f MB   Qualität %s" % [Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Settings.QUALITY_NAMES[Settings.quality]])
	var p: Player = game.get("player") as Player
	if p != null:
		var pos: Vector3 = p.global_position
		lines.append("Spieler %.1f / %.1f / %.1f   HP %.0f" % [pos.x, pos.y, pos.z, p.health])
		if p.is_in_vehicle():
			var v: Vehicle = p.current_vehicle as Vehicle
			lines.append("Fahrzeug %s   %.0f km/h   Zustand %.0f" % [v.spec.id, absf(v.get_forward_speed()) * 3.6, v.health])
	var traffic: TrafficManager = game.get("traffic") as TrafficManager
	var peds: PedestrianManager = game.get("peds") as PedestrianManager
	var police: PoliceManager = game.get("police") as PoliceManager
	if traffic != null and peds != null and police != null:
		lines.append("Verkehr %d/%d   Passanten %d/%d   Polizei %d" % [traffic.active_count(), traffic.max_vehicles,
			peds.active_count(), peds.max_peds, police.active_units()])
		lines.append("Fahndung %d (%s)   Festnahme %.0f %%" % [police.wanted_level(), police.wanted.state, police.arrest_progress * 100.0])
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if ms != null and ms.active != null:
		lines.append("Mission %s   Schritt %d (%s)" % [ms.active.id, ms.step_index, str(ms._step.get("type", ""))])
	_label.text = "\n".join(lines)
