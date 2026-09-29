class_name CheatConsole
extends CanvasLayer
## Cheat-Konsole (Taste ^): Code eingeben, Enter bestätigt. „HILFE“ listet alle Codes, „AKTIV“ die eingeschalteten.
## Pausiert das Spiel, solange sie offen ist.

var panel: PanelContainer
var input: LineEdit
var output: RichTextLabel


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = UiStyle.panel(true)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 30
	panel.custom_minimum_size = Vector2(0, 280)
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	vb.add_child(UiStyle.label("Cheat-Konsole  (Enter = ausführen, Esc/^ = schließen, HILFE = Liste)", 16, UiStyle.ACCENT))
	output = RichTextLabel.new()
	output.custom_minimum_size = Vector2(0, 200)
	output.scroll_following = true
	output.bbcode_enabled = true
	output.add_theme_color_override("default_color", UiStyle.TEXT)
	vb.add_child(output)
	input = LineEdit.new()
	input.placeholder_text = "Code eingeben …"
	input.text_submitted.connect(_submit)
	vb.add_child(input)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	App.set_mouse_captured(false)
	input.clear()
	input.grab_focus()
	if not Settings.cheats_enabled:
		_print("[color=#f07060]Cheats sind in den Optionen deaktiviert (Spielablauf → Cheats erlauben).[/color]")


func close() -> void:
	visible = false
	get_tree().paused = false
	App.set_mouse_captured(true)


func _submit(text: String) -> void:
	var t: String = text.strip_edges().to_upper()
	input.clear()
	if t == "":
		return
	if t == "HILFE":
		_print(help_text())
		return
	if t == "AKTIV":
		_print("Aktiv: " + (", ".join(CheatManager.active.keys()) if not CheatManager.active.is_empty() else "keine"))
		return
	var msg: String = CheatManager.enter(t)
	_print(("> %s: %s" % [t, msg]) if msg != "" else "[color=#f07060]> %s: unbekannter Code[/color]" % t)


static func help_text() -> String:
	var by_cat: Dictionary = {}
	for code: String in CheatManager.cheats:
		var c: Dictionary = CheatManager.cheats[code]
		var arr: Array = by_cat.get(c.cat, [])
		arr.append("%s – %s%s" % [code, c.desc, " (Schalter)" if c.toggle else ""])
		by_cat[c.cat] = arr
	var out: String = ""
	for cat: String in by_cat:
		out += "[b]%s[/b]\n  %s\n" % [cat, "\n  ".join(by_cat[cat])]
	return out


func _print(t: String) -> void:
	output.append_text(t + "\n")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("cheat_console"):
		close()
		get_viewport().set_input_as_handled()
