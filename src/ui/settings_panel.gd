class_name SettingsPanel
extends PanelContainer
## Optionsmenü v2 (Hauptmenü und Pausenmenü) mit Reitern: A Grafik, B Audio, C Steuerung + Tastenbelegung,
## D Spielablauf, E Anzeige & Barrierefreiheit, Cheats. Änderungen wirken sofort, soweit technisch möglich;
## Sichtweite/Dichten vollständig nach Neuladen der Umgebung bzw. beim nächsten Spielstart (Hinweis im Menü).

signal closed

var _tabs: TabContainer
var _capture_action: String = ""
var _capture_slot: int = 0
var _capture_btn: Button
var _bind_status: Label
var _bind_buttons: Dictionary = {}     ## "action:slot" -> Button
var _rebuild_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	custom_minimum_size = Vector2(980, 640)
	_build()


func _build() -> void:
	for c: Node in get_children():
		c.queue_free()
	_bind_buttons.clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.label("OPTIONEN", 32, UiStyle.ACCENT))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(940, 500)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 18)
	v.add_child(_tabs)
	_page_graphics()
	_page_audio()
	_page_controls()
	_page_keys()
	_page_gameplay()
	_page_access()
	_page_cheats()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	var back := UiStyle.button("Speichern und zurück")
	back.name = "Zurueck"
	back.pressed.connect(close)
	foot.add_child(back)
	var reset := UiStyle.button("Standard wiederherstellen")
	reset.pressed.connect(func() -> void:
		Settings.reset_to_defaults()
		Settings.apply()
		_rebuild_pending = true)
	foot.add_child(reset)


func _process(_delta: float) -> void:
	if _rebuild_pending:
		_rebuild_pending = false
		var cur: int = _tabs.current_tab if _tabs != null else 0
		_build()
		await get_tree().process_frame
		_tabs.current_tab = cur


func open() -> void:
	visible = true
	var b: Button = find_child("Zurueck", true, false) as Button
	if b != null:
		b.grab_focus.call_deferred()


func close() -> void:
	_capture_action = ""
	Settings.save_settings()
	visible = false
	closed.emit()


# ------------------------------------------------------------------ Seiten

func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(sc)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(rows)
	return rows


func _page_graphics() -> void:
	var p: VBoxContainer = _page("Grafik")
	_option(p, "Qualitätsstufe", Settings.QUALITY_NAMES, Settings.quality, func(i: int) -> void:
		Settings.apply_preset(i)
		_rebuild_pending = true)
	_option(p, "Anzeigemodus", Settings.WINDOW_NAMES, Settings.window_mode, func(i: int) -> void: Settings.window_mode = i)
	_check(p, "V-Sync", Settings.vsync, func(b: bool) -> void: Settings.vsync = b)
	var fps_names: Array[String] = []
	for f: int in Settings.FPS_LIMITS:
		fps_names.append("Unbegrenzt" if f == 0 else "%d FPS" % f)
	_option(p, "Bildratenbegrenzung", fps_names, maxi(0, Settings.FPS_LIMITS.find(Settings.fps_limit)), func(i: int) -> void:
		Settings.fps_limit = Settings.FPS_LIMITS[i])
	_slider(p, "Sichtfeld (FOV)", Settings.fov, 55.0, 100.0, 1.0, func(x: float) -> void: Settings.fov = x, "%d°")
	_section(p, "Details (setzt die Stufe auf „Benutzerdefiniert“)")
	_slider(p, "Renderauflösung", Settings.render_scale, 0.5, 1.0, 0.05, func(x: float) -> void: _custom("render_scale", x), "pct")
	_option(p, "Kantenglättung", Settings.AA_NAMES, Settings.antialias, func(i: int) -> void: _custom("antialias", i))
	_option(p, "Schatten", Settings.SHADOW_NAMES, Settings.shadows, func(i: int) -> void: _custom("shadows", i))
	_slider(p, "Sichtweite", Settings.view_distance_m, 350.0, 1600.0, 50.0, func(x: float) -> void: _custom("view_distance_m", x), "%d m")
	_check(p, "Umgebungsverdeckung (SSAO)", Settings.ssao, func(b: bool) -> void: _custom("ssao", b))
	_check(p, "Indirektes Licht (SSIL)", Settings.ssil, func(b: bool) -> void: _custom("ssil", b))
	_check(p, "Leuchten (Glow)", Settings.glow, func(b: bool) -> void: _custom("glow", b))
	_check(p, "Volumetrischer Nebel", Settings.volumetric_fog, func(b: bool) -> void: _custom("volumetric_fog", b))
	_slider(p, "Vegetationsdichte", Settings.vegetation, 0.0, 1.5, 0.05, func(x: float) -> void: _custom("vegetation", x), "pct")
	_check(p, "FPS anzeigen", Settings.show_fps, func(b: bool) -> void: Settings.show_fps = b)
	p.add_child(UiStyle.label("Sichtweite und Vegetation wirken vollständig für neu geladene Stadtteile.", 15, UiStyle.TEXT_DIM))


func _custom(prop: String, value: Variant) -> void:
	Settings.set(prop, value)
	if Settings.quality != 4:
		Settings.quality = 4
		_rebuild_pending = true


func _page_audio() -> void:
	var p: VBoxContainer = _page("Audio")
	_slider(p, "Gesamtlautstärke", Settings.master_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.master_volume = x, "pct")
	_slider(p, "Musik", Settings.music_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.music_volume = x, "pct")
	_slider(p, "Effekte", Settings.sfx_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.sfx_volume = x, "pct")
	_slider(p, "Umgebung (Stadt, Wetter, Tiere)", Settings.ambience_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.ambience_volume = x, "pct")
	_slider(p, "Menü-Klänge", Settings.ui_volume, 0.0, 1.0, 0.05, func(x: float) -> void: Settings.ui_volume = x, "pct")


func _page_controls() -> void:
	var p: VBoxContainer = _page("Steuerung")
	_slider(p, "Mausempfindlichkeit", Settings.mouse_sensitivity, 0.05, 0.8, 0.01, func(x: float) -> void: Settings.mouse_sensitivity = x, "%.2f")
	_check(p, "Maus-Y invertieren", Settings.invert_y, func(b: bool) -> void: Settings.invert_y = b)
	_check(p, "Kamera beim Fahren automatisch ausrichten", Settings.camera_autocenter, func(b: bool) -> void: Settings.camera_autocenter = b)
	_check(p, "Geschwindigkeit in mph", Settings.speed_mph, func(b: bool) -> void: Settings.speed_mph = b)


func _page_keys() -> void:
	var p: VBoxContainer = _page("Tastenbelegung")
	_bind_status = UiStyle.label("Auf eine Taste klicken und dann die neue Taste drücken (Esc = abbrechen, Entf = leeren).", 15, UiStyle.TEXT_DIM)
	p.add_child(_bind_status)
	var by_cat: Dictionary = {}
	for action: String in InputSetup.DEFAULTS:
		var lab: Array = InputSetup.LABELS.get(action, [action, "Allgemein"])
		var arr: Array = by_cat.get(lab[1], [])
		arr.append(action)
		by_cat[lab[1]] = arr
	for cat: String in by_cat:
		_section(p, cat)
		for action: String in by_cat[cat]:
			var h: HBoxContainer = _row(p, str(InputSetup.LABELS.get(action, [action])[0]))
			for slot: int in 2:
				var b := Button.new()
				b.custom_minimum_size = Vector2(150, 30)
				b.add_theme_font_size_override("font_size", 17)
				b.text = _key_text(action, slot)
				b.disabled = action in InputSetup.LOCKED
				var a: String = action
				var sl: int = slot
				b.pressed.connect(func() -> void: _start_capture(a, sl, b))
				h.add_child(b)
				_bind_buttons["%s:%d" % [action, slot]] = b
	var rb := UiStyle.button("Tastenbelegung zurücksetzen")
	rb.pressed.connect(func() -> void:
		Settings.bindings = InputSetup.default_bindings()
		InputSetup.register(Settings.bindings)
		_refresh_keys()
		_bind_status.text = "Standardbelegung wiederhergestellt.")
	p.add_child(rb)


func _key_text(action: String, slot: int) -> String:
	var keys: Array = Settings.bindings.get(action, [])
	return InputSetup.key_name(int(keys[slot])) if slot < keys.size() else "—"


func _refresh_keys() -> void:
	for k: String in _bind_buttons:
		var parts: PackedStringArray = k.split(":")
		(_bind_buttons[k] as Button).text = _key_text(parts[0], int(parts[1]))


func _start_capture(action: String, slot: int, b: Button) -> void:
	_capture_action = action
	_capture_slot = slot
	_capture_btn = b
	b.text = "Taste drücken …"
	_bind_status.text = "Neue Taste für „%s“ drücken." % str(InputSetup.LABELS.get(action, [action])[0])


func _input(event: InputEvent) -> void:
	if _capture_action == "" or not visible:
		return
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	get_viewport().set_input_as_handled()
	var key: int = (event as InputEventKey).physical_keycode
	var action: String = _capture_action
	_capture_action = ""
	if key == KEY_ESCAPE:
		_refresh_keys()
		_bind_status.text = "Abgebrochen."
		return
	var keys: Array[int] = []
	for k: Variant in Settings.bindings.get(action, []):
		keys.append(int(k))
	if key == KEY_DELETE:
		if _capture_slot < keys.size():
			keys.remove_at(_capture_slot)
		Settings.set_binding(action, keys)
		_refresh_keys()
		_bind_status.text = "Belegung entfernt."
		return
	var note: String = ""
	for other: String in Settings.binding_conflicts(action, key):
		var ok: Array[int] = []
		for k2: Variant in Settings.bindings[other]:
			if int(k2) != key:
				ok.append(int(k2))
		Settings.bindings[other] = ok
		note += " Taste bei „%s“ entfernt." % str(InputSetup.LABELS.get(other, [other])[0])
	if _capture_slot < keys.size():
		keys[_capture_slot] = key
	else:
		keys.append(key)
	Settings.set_binding(action, keys)
	_refresh_keys()
	_bind_status.text = "„%s“ = %s.%s" % [str(InputSetup.LABELS.get(action, [action])[0]), InputSetup.key_name(key), note]


func _page_gameplay() -> void:
	var p: VBoxContainer = _page("Spielablauf")
	_section(p, "Stadtleben")
	_slider(p, "Verkehrsdichte", Settings.traffic_density, 0.25, 1.5, 0.05, func(x: float) -> void: Settings.traffic_density = x, "pct")
	_slider(p, "Passantendichte", Settings.pedestrian_density, 0.25, 1.5, 0.05, func(x: float) -> void: Settings.pedestrian_density = x, "pct")
	_slider(p, "Tiere", Settings.animal_density, 0.0, 1.5, 0.05, func(x: float) -> void: Settings.animal_density = x, "pct")
	_option(p, "Polizei", Settings.DIFFICULTY_NAMES, Settings.police_difficulty, func(i: int) -> void: Settings.police_difficulty = i)
	_section(p, "Ereignisse")
	_check(p, "Bandenaktivität", Settings.events_gangs, func(b: bool) -> void: Settings.events_gangs = b)
	_check(p, "Unruhen / Kundgebungen", Settings.events_unrest, func(b: bool) -> void: Settings.events_unrest = b)
	_check(p, "Polizeieinsätze", Settings.events_police, func(b: bool) -> void: Settings.events_police = b)
	_slider(p, "Ereignishäufigkeit", Settings.event_frequency, 0.25, 2.0, 0.05, func(x: float) -> void: Settings.event_frequency = x, "pct")
	_section(p, "Zeit und Wetter")
	_slider(p, "Zeitgeschwindigkeit (Spielminuten/s)", Settings.time_speed, 0.0, 6.0, 0.25, func(x: float) -> void: Settings.time_speed = x, "%.2f")
	_option(p, "Wetter", Settings.WEATHER_NAMES, Settings.weather_mode, func(i: int) -> void: Settings.weather_mode = i)
	_section(p, "Aufträge")
	_check(p, "Hilfsmarkierungen", Settings.assist_markers, func(b: bool) -> void: Settings.assist_markers = b)
	_check(p, "Vereinfachte Aufträge (mehr Zeit, mildere Polizei)", Settings.simplified_missions, func(b: bool) -> void: Settings.simplified_missions = b)
	_check(p, "Automatisch speichern", Settings.autosave, func(b: bool) -> void: Settings.autosave = b)
	_check(p, "Cheats erlauben", Settings.cheats_enabled, func(b: bool) -> void: Settings.cheats_enabled = b)


func _page_access() -> void:
	var p: VBoxContainer = _page("Anzeige")
	_slider(p, "Schriftgröße / Oberflächenskalierung", Settings.ui_scale, 0.8, 1.5, 0.05, func(x: float) -> void: Settings.ui_scale = x, "pct")
	_slider(p, "HUD-Deckkraft", Settings.hud_opacity, 0.3, 1.0, 0.05, func(x: float) -> void: Settings.hud_opacity = x, "pct")
	_check(p, "Minikarte", Settings.minimap, func(b: bool) -> void: Settings.minimap = b)
	_check(p, "Untertitel / Zurufe als Text", Settings.subtitles, func(b: bool) -> void: Settings.subtitles = b)
	_check(p, "Kamerawackeln", Settings.camera_shake, func(b: bool) -> void: Settings.camera_shake = b)
	_option(p, "Farbfilter (Farbfehlsichtigkeit)", Settings.COLORBLIND_NAMES, Settings.colorblind, func(i: int) -> void: Settings.colorblind = i)


func _page_cheats() -> void:
	var p: VBoxContainer = _page("Cheats")
	p.add_child(UiStyle.label("Codes im Spiel eintippen oder in der Konsole (Taste ^) eingeben. Schalter lassen sich hier direkt umschalten.", 15, UiStyle.TEXT_DIM))
	if not Settings.cheats_enabled:
		p.add_child(UiStyle.label("Cheats sind deaktiviert (Spielablauf → Cheats erlauben).", 17, UiStyle.BAD))
	var by_cat: Dictionary = {}
	for code: String in CheatManager.cheats:
		var c: Dictionary = CheatManager.cheats[code]
		var arr: Array = by_cat.get(c.cat, [])
		arr.append(code)
		by_cat[c.cat] = arr
	for cat: String in by_cat:
		_section(p, cat)
		for code: String in by_cat[cat]:
			var c2: Dictionary = CheatManager.cheats[code]
			var h := HBoxContainer.new()
			var l1: Label = UiStyle.label(code, 17, UiStyle.ACCENT)
			l1.custom_minimum_size = Vector2(250, 0)
			h.add_child(l1)
			var l2: Label = UiStyle.label(str(c2.desc), 17)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l2)
			if bool(c2.toggle):
				var cb := CheckButton.new()
				cb.button_pressed = CheatManager.is_active(code)
				cb.disabled = not Settings.cheats_enabled
				var cd: String = code
				cb.toggled.connect(func(on: bool) -> void:
					if on != CheatManager.is_active(cd):
						CheatManager.enter(cd))
				h.add_child(cb)
			p.add_child(h)
	var rb := UiStyle.button("Alle Cheats zurücksetzen")
	rb.pressed.connect(func() -> void:
		CheatManager.reset_all()
		_rebuild_pending = true)
	p.add_child(rb)


# ------------------------------------------------------------------ Bausteine

func _unhandled_input(event: InputEvent) -> void:
	if visible and _capture_action == "" and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _section(p: VBoxContainer, title: String) -> void:
	p.add_child(UiStyle.label(title, 20, UiStyle.ACCENT))


func _row(p: VBoxContainer, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l: Label = UiStyle.label(title, 18)
	l.custom_minimum_size = Vector2(390, 0)
	h.add_child(l)
	p.add_child(h)
	return h


func _slider(p: VBoxContainer, title: String, value: float, lo: float, hi: float, step: float, setter: Callable, fmt: String) -> void:
	var h: HBoxContainer = _row(p, title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var val: Label = UiStyle.label("", 18, UiStyle.TEXT_DIM)
	h.add_child(val)
	var f: Callable = func(x: float) -> String:
		if fmt == "pct":
			return "%d %%" % roundi(x * 100.0)
		return fmt % (roundi(x) if fmt.contains("%d") else x)
	val.text = f.call(value)
	s.value_changed.connect(func(x: float) -> void:
		setter.call(x)
		val.text = f.call(x)
		Settings.apply())


func _check(p: VBoxContainer, title: String, value: bool, setter: Callable) -> void:
	var h: HBoxContainer = _row(p, title)
	var c := CheckButton.new()
	c.button_pressed = value
	h.add_child(c)
	c.toggled.connect(func(b: bool) -> void:
		setter.call(b)
		Settings.apply())


func _option(p: VBoxContainer, title: String, names: Array[String], index: int, setter: Callable) -> void:
	var h: HBoxContainer = _row(p, title)
	var o := OptionButton.new()
	for n: String in names:
		o.add_item(n)
	o.selected = clampi(index, 0, names.size() - 1)
	o.add_theme_font_size_override("font_size", 18)
	h.add_child(o)
	o.item_selected.connect(func(i: int) -> void:
		setter.call(i)
		Settings.apply())
