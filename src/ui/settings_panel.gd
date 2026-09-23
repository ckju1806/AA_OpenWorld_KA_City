class_name SettingsPanel
extends PanelContainer
## Einstellungen (Hauptmenü und Pausenmenü): Audio, Maus, Grafik, Verkehrsdichte.
## Änderungen wirken sofort (Audio/Fenster/Maus); Qualität und Dichte vollständig beim nächsten Spielstart.

signal closed

var _rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiStyle.label("EINSTELLUNGEN", 34, UiStyle.ACCENT))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	v.add_child(_rows)
	_section("Audio")
	_slider("Gesamtlautstärke", Settings.master_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.master_volume = x, true)
	_slider("Musik", Settings.music_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.music_volume = x, true)
	_slider("Effekte", Settings.sfx_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.sfx_volume = x, true)
	_section("Steuerung")
	_slider("Mausempfindlichkeit", Settings.mouse_sensitivity, 0.05, 0.8, 0.01, func(x: float) -> void: Settings.mouse_sensitivity = x, false)
	_check("Maus-Y invertieren", Settings.invert_y, func(b: bool) -> void: Settings.invert_y = b)
	_section("Grafik")
	_check("Vollbild", Settings.fullscreen, func(b: bool) -> void: Settings.fullscreen = b)
	_check("V-Sync", Settings.vsync, func(b: bool) -> void: Settings.vsync = b)
	_option("Qualität", Settings.QUALITY_NAMES, Settings.quality, func(i: int) -> void: Settings.quality = i)
	_check("FPS anzeigen", Settings.show_fps, func(b: bool) -> void: Settings.show_fps = b)
	_section("Spielwelt")
	_slider("Verkehrs-/Passantendichte", Settings.traffic_density, 0.25, 1.5, 0.05, func(x: float) -> void: Settings.traffic_density = x, true)
	v.add_child(UiStyle.label("Qualität und Dichte wirken vollständig beim nächsten Spielstart.", 16, UiStyle.TEXT_DIM))
	var back := UiStyle.button("Speichern und zurück")
	back.name = "Zurueck"
	back.pressed.connect(close)
	v.add_child(back)


func open() -> void:
	visible = true
	var b: Button = find_child("Zurueck", true, false) as Button
	if b != null:
		b.grab_focus.call_deferred()


func close() -> void:
	Settings.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _section(title: String) -> void:
	var l: Label = UiStyle.label(title, 22, UiStyle.ACCENT)
	_rows.add_child(l)


func _row(title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l: Label = UiStyle.label(title, 20)
	l.custom_minimum_size = Vector2(330, 0)
	h.add_child(l)
	_rows.add_child(h)
	return h


func _slider(title: String, value: float, lo: float, hi: float, step: float, setter: Callable, percent: bool) -> void:
	var h: HBoxContainer = _row(title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var val: Label = UiStyle.label("", 20, UiStyle.TEXT_DIM)
	h.add_child(val)
	var fmt: Callable = func(x: float) -> String: return ("%d %%" % roundi(x * 100.0)) if percent else ("%.2f" % x)
	val.text = fmt.call(value)
	s.value_changed.connect(func(x: float) -> void:
		setter.call(x)
		val.text = fmt.call(x)
		Settings.apply())


func _check(title: String, value: bool, setter: Callable) -> void:
	var h: HBoxContainer = _row(title)
	var c := CheckButton.new()
	c.button_pressed = value
	h.add_child(c)
	c.toggled.connect(func(b: bool) -> void:
		setter.call(b)
		Settings.apply())


func _option(title: String, names: Array[String], index: int, setter: Callable) -> void:
	var h: HBoxContainer = _row(title)
	var o := OptionButton.new()
	for n: String in names:
		o.add_item(n)
	o.selected = index
	o.add_theme_font_size_override("font_size", 20)
	h.add_child(o)
	o.item_selected.connect(func(i: int) -> void:
		setter.call(i)
		Settings.apply())
