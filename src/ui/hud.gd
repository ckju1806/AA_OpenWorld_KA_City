class_name Hud
extends CanvasLayer
## Spieloberfläche: Missionsziel, Fortschritt, Rennzeit, Kontexthinweise, Dialoge, Meldungen, Großmeldungen,
## Lebenspunkte, Geld, Fahrzeuganzeige (Tacho, Zustand, Licht), Ergebnis-/Wiederholungstafel.
## Minikarte und Fahndungsanzeige werden als eigene Elemente eingehängt.

var game: Node = null

var _objective_panel: PanelContainer
var _mission_title: Label
var _objective: Label
var _progress: ProgressBar
var _progress_label: Label
var _timer_label: Label
var _hint_panel: PanelContainer
var _hint: Label
var _dialog_panel: PanelContainer
var _dialog_speaker: Label
var _dialog_text: Label
var _dialog_hide_t: float = 0.0
var _big_title: Label
var _big_sub: Label
var _big_t: float = 0.0
var _notes: VBoxContainer
var _health_bar: ProgressBar
var _money: Label
var _vehicle_panel: PanelContainer
var _speed: Label
var _vehicle_name: Label
var _damage_bar: ProgressBar
var _veh_status: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_reason: Label
var _wanted_panel: PanelContainer
var _wanted_segments: Array[ColorRect] = []
var _wanted_state: Label
var _arrest_bar: ProgressBar
var _arrest_label: Label
var _blink_t: float = 0.0
var root: Control


func setup(p_game: Node) -> void:
	game = p_game
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_objective()
	_build_hint_and_dialog()
	_build_big()
	_build_notes()
	_build_status()
	_build_vehicle()
	_build_result()
	_build_wanted()
	EventBus.context_hint.connect(_on_hint)
	EventBus.notify.connect(_on_notify)
	EventBus.big_message.connect(_on_big)
	EventBus.dialog_line.connect(_on_dialog)
	EventBus.dialog_closed.connect(func() -> void: _dialog_hide_t = 0.4)
	EventBus.mission_failed.connect(func(_id: String, _r: String) -> void: _refresh_result())
	GameState.money_changed.connect(_on_money)
	_on_money(GameState.money)


func _build_objective() -> void:
	_objective_panel = UiStyle.panel()
	_objective_panel.position = Vector2(36, 32)
	_objective_panel.custom_minimum_size = Vector2(560, 0)
	root.add_child(_objective_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_objective_panel.add_child(v)
	_mission_title = UiStyle.label("", 20, UiStyle.ACCENT)
	v.add_child(_mission_title)
	_objective = UiStyle.label("", 26)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(540, 0)
	v.add_child(_objective)
	_progress_label = UiStyle.label("", 18, UiStyle.TEXT_DIM)
	v.add_child(_progress_label)
	_progress = UiStyle.bar(UiStyle.ACCENT, 10)
	v.add_child(_progress)
	_timer_label = UiStyle.label("", 22, UiStyle.TEXT)
	v.add_child(_timer_label)
	_objective_panel.visible = false


func _build_hint_and_dialog() -> void:
	_hint_panel = UiStyle.panel(false)
	_hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_panel.offset_bottom = -40
	_hint_panel.offset_top = -92
	root.add_child(_hint_panel)
	_hint = UiStyle.label("", 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)
	_hint_panel.visible = false
	_dialog_panel = UiStyle.panel()
	_dialog_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialog_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog_panel.offset_bottom = -120
	_dialog_panel.offset_top = -260
	_dialog_panel.offset_left = -560
	_dialog_panel.offset_right = 560
	root.add_child(_dialog_panel)
	var v := VBoxContainer.new()
	_dialog_panel.add_child(v)
	_dialog_speaker = UiStyle.label("", 24, UiStyle.ACCENT)
	v.add_child(_dialog_speaker)
	_dialog_text = UiStyle.label("", 28)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_dialog_text)
	var skip := UiStyle.label("[E] weiter", 16, UiStyle.TEXT_DIM)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(skip)
	_dialog_panel.visible = false


func _build_big() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_top = -220
	box.offset_bottom = -60
	box.offset_left = -700
	box.offset_right = 700
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	_big_title = UiStyle.label("", 72, UiStyle.ACCENT, 12)
	_big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_big_title)
	_big_sub = UiStyle.label("", 32, UiStyle.TEXT, 8)
	_big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_big_sub)


func _build_notes() -> void:
	_notes = VBoxContainer.new()
	_notes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notes.offset_top = 150
	_notes.offset_right = -36
	_notes.offset_left = -560
	_notes.add_theme_constant_override("separation", 8)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)


func _build_status() -> void:
	var p := UiStyle.panel()
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 36
	p.offset_bottom = -36
	p.offset_right = 356
	p.offset_top = -120
	root.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(UiStyle.label("♥", 22, UiStyle.BAD))
	_health_bar = UiStyle.bar(UiStyle.BAD, 14)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_health_bar.max_value = 100
	_health_bar.value = 100
	row.add_child(_health_bar)
	_money = UiStyle.label("0 €", 30, UiStyle.GOOD)
	v.add_child(_money)


func _build_vehicle() -> void:
	_vehicle_panel = UiStyle.panel()
	_vehicle_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_vehicle_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_vehicle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_vehicle_panel.offset_right = -36
	_vehicle_panel.offset_bottom = -36
	_vehicle_panel.offset_left = -336
	_vehicle_panel.offset_top = -180
	root.add_child(_vehicle_panel)
	var v := VBoxContainer.new()
	_vehicle_panel.add_child(v)
	_vehicle_name = UiStyle.label("", 18, UiStyle.TEXT_DIM)
	v.add_child(_vehicle_name)
	var row := HBoxContainer.new()
	v.add_child(row)
	_speed = UiStyle.label("0", 56, UiStyle.TEXT)
	row.add_child(_speed)
	var unit := UiStyle.label(" km/h", 22, UiStyle.TEXT_DIM)
	unit.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(unit)
	_damage_bar = UiStyle.bar(UiStyle.GOOD, 10)
	_damage_bar.max_value = 1.0
	_damage_bar.step = 0.001
	v.add_child(_damage_bar)
	_veh_status = UiStyle.label("", 16, UiStyle.TEXT_DIM)
	v.add_child(_veh_status)
	_vehicle_panel.visible = false


func _build_result() -> void:
	_result_panel = UiStyle.panel()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.offset_left = -380
	_result_panel.offset_right = 380
	_result_panel.offset_top = 40
	_result_panel.offset_bottom = 230
	root.add_child(_result_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_result_panel.add_child(v)
	_result_title = UiStyle.label("AUFTRAG GESCHEITERT", 34, UiStyle.BAD)
	v.add_child(_result_title)
	_result_reason = UiStyle.label("", 24)
	_result_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_result_reason)
	v.add_child(UiStyle.label("[Enter] Erneut versuchen     [Rücktaste] Abbrechen", 22, UiStyle.ACCENT))
	_result_panel.visible = false


## Fahndungsanzeige: drei Blaulicht-Segmente, Zustand, Festnahme-Balken.
func _build_wanted() -> void:
	_wanted_panel = UiStyle.panel()
	_wanted_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wanted_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_wanted_panel.offset_right = -36
	_wanted_panel.offset_top = 32
	_wanted_panel.offset_left = -330
	root.add_child(_wanted_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_wanted_panel.add_child(v)
	v.add_child(UiStyle.label("FAHNDUNG", 18, UiStyle.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for i: int in 3:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(76, 18)
		seg.color = Color(0.15, 0.17, 0.25)
		row.add_child(seg)
		_wanted_segments.append(seg)
	_wanted_state = UiStyle.label("", 20)
	v.add_child(_wanted_state)
	_arrest_label = UiStyle.label("Festnahme droht!", 18, UiStyle.BAD)
	v.add_child(_arrest_label)
	_arrest_bar = UiStyle.bar(UiStyle.BAD, 8)
	_arrest_bar.max_value = 1.0
	_arrest_bar.step = 0.01
	v.add_child(_arrest_bar)
	_wanted_panel.visible = false


func _update_wanted(delta: float) -> void:
	var pm: PoliceManager = game.get("police") as PoliceManager
	if pm == null:
		_wanted_panel.visible = false
		return
	var w: WantedLogic = pm.wanted
	_wanted_panel.visible = w.level > 0
	if w.level == 0:
		return
	_blink_t += delta
	var blink: bool = fmod(_blink_t, 0.5) < 0.25
	for i: int in 3:
		var on: bool = i < w.level
		var c: Color = Color(0.15, 0.17, 0.25)
		if on:
			if w.state == "verfolgung":
				c = UiStyle.POLICE_BLUE if (blink != (i % 2 == 0)) else Color(0.9, 0.2, 0.25)
			else:
				c = UiStyle.POLICE_BLUE.darkened(0.35)
		_wanted_segments[i].color = c
	if w.state == "verfolgung":
		_wanted_state.text = "Verfolgung – Sichtkontakt"
		_wanted_state.add_theme_color_override("font_color", UiStyle.BAD)
	else:
		var rest: float = w.search_duration() - w.search_time
		_wanted_state.text = "Suche läuft – noch %d s" % int(ceil(rest))
		_wanted_state.add_theme_color_override("font_color", UiStyle.ACCENT)
	_arrest_bar.visible = pm.arrest_progress > 0.01
	_arrest_label.visible = _arrest_bar.visible
	_arrest_bar.value = pm.arrest_progress


# ------------------------------------------------------------------ Ereignisse

func _on_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = text != "" and not _dialog_panel.visible


func _on_notify(text: String, kind: String) -> void:
	var p := UiStyle.panel()
	var col: Color = UiStyle.TEXT
	match kind:
		"erfolg":
			col = UiStyle.GOOD
		"warnung":
			col = UiStyle.ACCENT
		"fehler":
			col = UiStyle.BAD
	var l := UiStyle.label(text, 22, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	p.add_child(l)
	_notes.add_child(p)
	if _notes.get_child_count() > 4:
		_notes.get_child(0).queue_free()
	var tw: Tween = p.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _on_big(title: String, subtitle: String, seconds: float) -> void:
	_big_title.text = title
	_big_sub.text = subtitle
	_big_t = seconds
	_big_title.modulate.a = 1.0
	_big_sub.modulate.a = 1.0


func _on_dialog(speaker: String, text: String) -> void:
	_dialog_speaker.text = speaker
	_dialog_text.text = text
	_dialog_panel.visible = true
	_hint_panel.visible = false
	_dialog_hide_t = clampf(float(text.length()) * 0.06, 3.0, 7.0) + 0.5


func _on_money(v: int) -> void:
	_money.text = UiStyle.money(v)


func _refresh_result() -> void:
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if ms == null:
		return
	_result_reason.text = ms.fail_reason


func _process(delta: float) -> void:
	if game == null:
		return
	var ms: MissionSystem = game.get("missions") as MissionSystem
	var p: Player = game.get("player") as Player
	# Missionsziel
	if ms != null and ms.active != null:
		_objective_panel.visible = ms.objective != "" or ms.timer_text != ""
		_mission_title.text = ms.get_title().to_upper() + (("   ·   " + ms.checkpoint_info) if ms.checkpoint_info != "" else "")
		_objective.text = ms.objective
		_progress.visible = ms.progress >= 0.0
		_progress.value = ms.progress * 100.0
		_progress_label.visible = ms.progress >= 0.0 and ms.progress_label != ""
		_progress_label.text = ms.progress_label
		_timer_label.visible = ms.timer_text != ""
		_timer_label.text = ms.timer_text
	else:
		_objective_panel.visible = false
	# Ergebnis-Tafel
	var show_result: bool = ms != null and ms.awaiting_retry and p != null and not p.is_dead
	if show_result and not _result_panel.visible:
		_result_reason.text = ms.fail_reason
	_result_panel.visible = show_result
	# Dialog ausblenden
	if _dialog_panel.visible:
		_dialog_hide_t -= delta
		if _dialog_hide_t <= 0.0 and (ms == null or not ms.dialog_active):
			_dialog_panel.visible = false
			_hint_panel.visible = _hint.text != ""
	# Großmeldung
	if _big_t > 0.0:
		_big_t -= delta
		var a: float = clampf(_big_t / 0.5, 0.0, 1.0)
		_big_title.modulate.a = a
		_big_sub.modulate.a = a
	elif _big_title.text != "":
		_big_title.text = ""
		_big_sub.text = ""
	_update_wanted(delta)
	# Status
	if p != null:
		_health_bar.value = p.health
		var v: Vehicle = p.current_vehicle as Vehicle
		_vehicle_panel.visible = v != null
		if v != null:
			_vehicle_name.text = v.spec.display_name
			_speed.text = str(int(round(absf(v.get_forward_speed()) * 3.6)))
			var h: float = v.health / v.max_health
			_damage_bar.value = h
			var fill: StyleBoxFlat = _damage_bar.get_theme_stylebox("fill") as StyleBoxFlat
			fill.bg_color = UiStyle.GOOD.lerp(UiStyle.BAD, 1.0 - h)
			var st: Array[String] = []
			st.append("Zustand %d %%" % int(round(h * 100.0)))
			if v.lights_on:
				st.append("Licht an")
			if v.is_destroyed:
				st.append("TOTALSCHADEN")
			_veh_status.text = "   ".join(st)


func _unhandled_input(event: InputEvent) -> void:
	if not _result_panel.visible:
		return
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if event.is_action_pressed("retry"):
		ms.retry()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		ms.abort()
		get_viewport().set_input_as_handled()
