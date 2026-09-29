class_name MissionList
extends CanvasLayer
## Auftragsliste (Taste J): Kampagne nach Handlungssträngen mit Status (erledigt / verfügbar / gesperrt + Voraussetzung),
## Auftraggeber und Wegpunkt auf der Karte, wiederholbare Jobs zum direkten Annehmen, Ruf bei den fiktiven Gruppen.
## Pausiert das Spiel, solange sie offen ist.

var game: Node
var _panel: PanelContainer
var _list: VBoxContainer


func setup(p_game: Node) -> void:
	game = p_game
	layer = 13
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = UiStyle.panel(true)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(900, 620)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	_panel.add_child(v)
	v.add_child(UiStyle.label("AUFTRÄGE", 30, UiStyle.ACCENT))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(860, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var close_b := UiStyle.button("Schließen (J / Esc)")
	close_b.pressed.connect(close)
	v.add_child(close_b)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	_rebuild()
	visible = true
	get_tree().paused = true
	App.set_mouse_captured(false)


func close() -> void:
	visible = false
	get_tree().paused = false
	App.set_mouse_captured(true)


func _rebuild() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var ms: MissionSystem = game.get("missions") as MissionSystem
	if ms == null:
		return
	var by_chapter: Dictionary = {}
	var defs: Array = ms.definitions.values()
	defs.sort_custom(func(a: MissionDefinition, b: MissionDefinition) -> bool: return a.order < b.order)
	for d: MissionDefinition in defs:
		if d.id.begins_with("job_"):
			continue
		var ch: String = d.chapter if d.chapter != "" else "Erste Schritte"
		var arr: Array = by_chapter.get(ch, [])
		arr.append(d)
		by_chapter[ch] = arr
	var done: int = 0
	var total: int = 0
	for ch2: String in by_chapter:
		_list.add_child(UiStyle.label(ch2, 22, UiStyle.ACCENT))
		for d2: MissionDefinition in by_chapter[ch2]:
			total += 1
			var completed: bool = GameState.is_mission_completed(d2.id)
			if completed:
				done += 1
			var avail: bool = ms.is_available(d2.id)
			var h := HBoxContainer.new()
			var icon: String = "✔" if completed and not avail else ("◆" if avail else "🔒")
			var col: Color = UiStyle.GOOD if completed and not avail else (UiStyle.ACCENT if avail else UiStyle.TEXT_DIM)
			var l: Label = UiStyle.label("%s  %s" % [icon, d2.title], 19, col)
			l.custom_minimum_size = Vector2(290, 0)
			h.add_child(l)
			var info: String = str(d2.giver.get("name", ""))
			if not avail and not completed:
				var missing: Array[String] = []
				for r: String in d2.requires:
					if not GameState.is_mission_completed(r) and ms.definitions.has(r):
						missing.append((ms.definitions[r] as MissionDefinition).title)
				info += "  ·  erst nach: " + ", ".join(missing)
			elif d2.summary != "":
				info += "  ·  " + d2.summary
			var li: Label = UiStyle.label(info, 15, UiStyle.TEXT_DIM)
			li.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			li.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(li)
			if completed and avail and d2.repeatable:
				var rb := Button.new()
				rb.text = "Wiederholen"
				rb.disabled = ms.has_active()
				var rid: String = d2.id
				rb.pressed.connect(func() -> void:
					close()
					ms.start_mission(rid))
				h.add_child(rb)
			if avail and ms.givers.has(d2.id):
				var wb := Button.new()
				wb.text = "Wegpunkt"
				var gv: MissionGiver = ms.givers[d2.id]
				wb.pressed.connect(func() -> void:
					game.set("waypoint", gv.global_position)
					EventBus.notify.emit("Wegpunkt gesetzt: %s" % gv.display_name, "info"))
				h.add_child(wb)
			_list.add_child(h)
	_list.add_child(UiStyle.label("Fortschritt Kampagne: %d / %d" % [done, total], 17, UiStyle.TEXT))
	# Jobs
	_list.add_child(UiStyle.label("Jobs (wiederholbar)", 22, UiStyle.ACCENT))
	var jobs: JobSystem = game.get("jobs") as JobSystem
	for kind: String in JobSystem.KINDS:
		var h2 := HBoxContainer.new()
		var lj: Label = UiStyle.label("%s – %s" % [JobSystem.KINDS[kind].title, JobSystem.KINDS[kind].desc], 17)
		lj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(lj)
		var b := Button.new()
		b.text = "Annehmen"
		b.disabled = ms.has_active() or jobs == null
		var k: String = kind
		b.pressed.connect(func() -> void:
			close()
			jobs.start_job(k))
		h2.add_child(b)
		_list.add_child(h2)
	# Ruf
	_list.add_child(UiStyle.label("Ruf", 22, UiStyle.ACCENT))
	var names: Dictionary = {"buerger": "Bürgerinnen und Bürger", "hafenkolonne": "Hafenkolonne (fiktiv)", "ringbande": "Ringbande (fiktiv)",
		"nordlichter": "Die Nordlichter (fiktiv)", "turmberg_clique": "Turmberg-Clique (fiktiv)"}
	for gid: String in names:
		var val: int = int(GameState.reputation.get(gid, 0))
		_list.add_child(UiStyle.label("%s: %+d" % [names[gid], val], 16, UiStyle.GOOD if val > 0 else (UiStyle.BAD if val < 0 else UiStyle.TEXT_DIM)))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("mission_list"):
		close()
		get_viewport().set_input_as_handled()
