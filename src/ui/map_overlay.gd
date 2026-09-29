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
	# Start: auf den Spieler zentriert, Stadtteil-Zoom
	var pp: Vector3 = view._player_pos()
	view.zoom = 3.0
	view.center_override = Vector2(pp.x, pp.z)
	get_tree().paused = true
	App.set_mouse_captured(false)
	view.queue_redraw()
	AudioManager.play_2d("ui_click", -6.0)


func close() -> void:
	visible = false
	get_tree().paused = false
	App.set_mouse_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("map") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
		return
	var zoom_step: float = 0.0
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step = 1.25
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step = 0.8
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k: InputEventKey = event
		match k.physical_keycode:
			KEY_EQUAL, KEY_KP_ADD, KEY_PLUS:
				zoom_step = 1.25
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_step = 0.8
			KEY_LEFT, KEY_A:
				_pan(Vector2(-1, 0))
			KEY_RIGHT, KEY_D:
				_pan(Vector2(1, 0))
			KEY_UP, KEY_W:
				_pan(Vector2(0, -1))
			KEY_DOWN, KEY_S:
				_pan(Vector2(0, 1))
	elif event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var mm: InputEventMouseMotion = event
		var s: float = float(view.view().scale)
		view.center_override -= mm.relative / maxf(s, 0.0001)
		view.queue_redraw()
	if zoom_step != 0.0:
		view.zoom = clampf(view.zoom * zoom_step, 1.0, 14.0)
		view.queue_redraw()
		get_viewport().set_input_as_handled()


func _pan(dir: Vector2) -> void:
	var s: float = float(view.view().scale)
	view.center_override += dir * 150.0 / maxf(s, 0.0001) * 0.5
	view.queue_redraw()
