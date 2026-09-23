class_name MapOverlay
extends CanvasLayer
## Vollbildkarte (M). Pausiert das Spiel, solange sie offen ist; M oder Esc schließt.

var view: MapView


func setup(game: Node, g: CityGraph) -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	view = MapView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	view.setup(game, g, true)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	get_tree().paused = true
	view.queue_redraw()
	AudioManager.play_2d("ui_click", -6.0)


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
