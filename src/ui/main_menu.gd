extends Control
## Hauptmenü: Neues Spiel, Fortsetzen (nur mit gültigem Spielstand), Einstellungen, Beenden.
## Eigener Hintergrund (MenuBackground), Menümusik.

var _menu: VBoxContainer
var _settings: SettingsPanel
var _status: Label
var _continue: Button
var _save_info: Label
var _confirm: PanelContainer


func _ready() -> void:
	App.set_mouse_captured(false)
	get_tree().paused = false
	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var left := MarginContainer.new()
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_theme_constant_override("margin_left", 110)
	left.add_theme_constant_override("margin_top", 120)
	add_child(left)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 14)
	left.add_child(col)
	col.add_child(UiStyle.label("FÄCHER-CITY", 92, UiStyle.ACCENT, 14))
	col.add_child(UiStyle.label("Asphalt & Schatten", 44, UiStyle.TEXT, 10))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	col.add_child(_menu)
	var b_new: Button = _add("Neues Spiel", _on_new)
	_continue = _add("Fortsetzen", _on_continue)
	_save_info = UiStyle.label("", 18, UiStyle.TEXT_DIM)
	_menu.add_child(_save_info)
	_add("Einstellungen", _on_settings)
	_add("Beenden", App.quit_game)
	_status = UiStyle.label("", 20, UiStyle.BAD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(620, 0)
	_menu.add_child(_status)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_menu.visible = true
		b_new.grab_focus())
	col.add_child(_settings)
	_build_confirm(col)
	var foot: Label = UiStyle.label("Fiktives Spiel in einer künstlerisch verdichteten Karlsruher Innenstadt · Alle Figuren und Firmen sind erfunden · v%s" %
		str(ProjectSettings.get_setting("application/config/version", "0.1.0")), 16, UiStyle.TEXT_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 110
	foot.offset_top = -52
	foot.offset_bottom = -24
	add_child(foot)
	_refresh_save_info()
	b_new.grab_focus.call_deferred()
	AudioManager.stop_ambience()
	AudioManager.play_music("music_menu")
	if App.has_arg("--menu-shot"):
		var tour := ScreenshotTour.new()
		tour.add_station("hauptmenue", Callable(), 90)
		add_child(tour)
		return
	if App.has_arg("--autostart"):
		App.start_new_game.call_deferred()


func _add(text: String, cb: Callable) -> Button:
	var b: Button = UiStyle.button(text)
	b.pressed.connect(cb)
	_menu.add_child(b)
	return b


func _refresh_save_info() -> void:
	var has: bool = SaveManager.has_save()
	_continue.disabled = not has
	if not has:
		_save_info.text = "Kein Spielstand vorhanden."
		return
	var r: Dictionary = SaveManager.load_game()
	if not r.ok:
		_continue.disabled = true
		_save_info.text = "Spielstand nicht lesbar: %s" % r.message
		return
	var st: Dictionary = (r.data as Dictionary).get("state", {})
	var done: int = (st.get("completed_missions", []) as Array).size()
	var when: String = str((r.data as Dictionary).get("saved_at", "")).replace("T", " ").left(16)
	_save_info.text = "Gespeichert %s UTC · %s · Aufträge %d/3%s" % [when, UiStyle.money(int(st.get("money", 0))), done,
		" · aus Sicherungskopie" if str(r.get("source", "")) == "sicherung" else ""]


func _build_confirm(parent: Control) -> void:
	_confirm = UiStyle.panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_confirm.add_child(v)
	v.add_child(UiStyle.label("Neues Spiel beginnen?", 30, UiStyle.ACCENT))
	v.add_child(UiStyle.label("Der vorhandene Spielstand wird beim nächsten Speichern überschrieben.", 20))
	var yes: Button = UiStyle.button("Ja, neu beginnen")
	yes.pressed.connect(App.start_new_game)
	v.add_child(yes)
	var no: Button = UiStyle.button("Abbrechen")
	no.pressed.connect(func() -> void:
		_confirm.visible = false
		_menu.visible = true
		_continue.grab_focus())
	v.add_child(no)
	_confirm.visible = false
	parent.add_child(_confirm)


func _on_new() -> void:
	if SaveManager.has_save():
		_menu.visible = false
		_confirm.visible = true
		(_confirm.get_child(0).get_child(3) as Button).grab_focus.call_deferred()
		return
	App.start_new_game()


func _on_continue() -> void:
	var err: String = App.continue_game()
	if err != "":
		_status.text = err
		_refresh_save_info()


func _on_settings() -> void:
	_menu.visible = false
	_settings.open()
