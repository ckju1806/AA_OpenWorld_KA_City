extends Control
## Hauptmenü (vorläufige Fassung – wird in Meilenstein G ausgebaut).


func _ready() -> void:
	App.set_mouse_captured(false)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(box)
	var title := Label.new()
	title.text = "Fächer-City: Asphalt & Schatten"
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var b_new := Button.new()
	b_new.text = "Neues Spiel"
	b_new.pressed.connect(App.start_new_game)
	box.add_child(b_new)
	var b_quit := Button.new()
	b_quit.text = "Beenden"
	b_quit.pressed.connect(App.quit_game)
	box.add_child(b_quit)
	if App.has_arg("--autostart"):
		App.start_new_game.call_deferred()
