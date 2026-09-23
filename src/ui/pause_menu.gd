class_name PauseMenu
extends CanvasLayer
## Pausenmenü (Esc): Fortsetzen, Speichern, Einstellungen, Steuerung, Hauptmenü, Beenden.
## Pausiert den Szenenbaum und gibt die Maus frei.

const CONTROLS_TEXT: String = """Zu Fuß: W A S D bewegen · Maus umsehen · Umschalt rennen · Leertaste springen
E interagieren / sprechen · F einsteigen / aussteigen · M Karte · Esc Pause · F3 Entwickleranzeige

Im Fahrzeug: W Gas · S Bremse / rückwärts · A D lenken · Leertaste Handbremse
H Hupe · L Licht · R Fahrzeug bergen (umgekippt/festgefahren) · F aussteigen (nur langsam)

Missionen: E überspringt Dialogzeilen · Eingabe = erneut versuchen · Rücktaste = Auftrag abbrechen"""

var game: Node = null
var _root: Control
var _menu: VBoxContainer
var _settings: SettingsPanel
var _controls: PanelContainer
var _status: Label


func setup(p_game: Node) -> void:
	game = p_game
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	stack.add_child(_menu)
	_menu.add_child(UiStyle.label("PAUSE", 56, UiStyle.ACCENT, 8))
	_add_button("Fortsetzen", close)
	_add_button("Spiel speichern", _on_save)
	_add_button("Einstellungen", _on_settings)
	_add_button("Steuerung", _on_controls)
	_add_button("Zum Hauptmenü (speichert)", _on_main_menu)
	_add_button("Spiel beenden (speichert)", _on_quit)
	_status = UiStyle.label("", 20, UiStyle.TEXT_DIM)
	_menu.add_child(_status)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_show_menu)
	stack.add_child(_settings)
	_controls = UiStyle.panel()
	var cv := VBoxContainer.new()
	_controls.add_child(cv)
	cv.add_child(UiStyle.label("STEUERUNG", 34, UiStyle.ACCENT))
	cv.add_child(UiStyle.label(CONTROLS_TEXT, 22))
	var back := UiStyle.button("Zurück")
	back.pressed.connect(_show_menu)
	cv.add_child(back)
	_controls.visible = false
	stack.add_child(_controls)
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if _root.visible:
		return
	_root.visible = true
	_status.text = ""
	_show_menu()
	get_tree().paused = true
	App.set_mouse_captured(false)
	AudioManager.play_2d("ui_click", -6.0)


func close() -> void:
	if not _root.visible:
		return
	if _settings.visible:
		Settings.save_settings()
	_root.visible = false
	get_tree().paused = false
	App.set_mouse_captured(true)


func _show_menu() -> void:
	_menu.visible = true
	_settings.visible = false
	_controls.visible = false
	(_menu.get_child(1) as Button).grab_focus.call_deferred()


func _add_button(text: String, cb: Callable) -> void:
	var b: Button = UiStyle.button(text)
	b.pressed.connect(cb)
	_menu.add_child(b)


func _on_save() -> void:
	var r: Dictionary = game.call("save_now")
	_status.text = str(r.message)
	_status.add_theme_color_override("font_color", UiStyle.GOOD if r.ok else UiStyle.BAD)


func _on_settings() -> void:
	_menu.visible = false
	_settings.open()


func _on_controls() -> void:
	_menu.visible = false
	_controls.visible = true


func _on_main_menu() -> void:
	game.call("save_now")
	App.goto_main_menu()


func _on_quit() -> void:
	game.call("save_now")
	App.quit_game()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		if _controls.visible:
			_show_menu()
		elif not _settings.visible:
			close()
		get_viewport().set_input_as_handled()
