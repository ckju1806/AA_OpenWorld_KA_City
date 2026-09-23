class_name MissionSystem
extends Node
## Missionsablauf: Auftraggeber, Schritt-Zustandsmaschine, Zielmarkierungen, Fehlschlag/Wiederholung,
## Aufräumen aller Missions-Entitäten und einmalige Belohnung (über GameState).

signal changed

const ABANDON_DISTANCE: float = 150.0
const ABANDON_TIME: float = 8.0
const TEMP_DESPAWN_DISTANCE: float = 120.0

var game: Node = null
var definitions: Dictionary = {}          ## id -> MissionDefinition
var givers: Dictionary = {}               ## id -> MissionGiver
var active: MissionDefinition = null
var step_index: int = -1
var awaiting_retry: bool = false
var last_failed_id: String = ""
var fail_reason: String = ""
var objective: String = ""
var progress: float = -1.0
var progress_label: String = ""
var target: Vector3 = Vector3.ZERO
var has_target: bool = false
var timer_text: String = ""
var race_time: float = 0.0
var checkpoint_info: String = ""
var dialog_active: bool = false
## Für Tests: Dialoge automatisch überspringen
var auto_skip_dialog: bool = false

var _entities: Dictionary = {}
var _markers: Array[Node3D] = []
var _interact_point: MissionInteractPoint = null
var _step: Dictionary = {}
var _st: Dictionary = {}
var _dialog: Array = []
var _dialog_t: float = 0.0
var _abandon_t: float = 0.0
var _start_xf: Transform3D = Transform3D.IDENTITY
var _temp_vehicles: Array[Node3D] = []
var _pending_fail: String = ""
var _frozen: bool = false
var _despawn_t: float = 0.0


func setup(p_game: Node) -> void:
	game = p_game
	var city: CityWorld = game.call("get_city")
	for d: MissionDefinition in MissionDefinition.load_all():
		definitions[d.id] = d
		if city != null:
			for e: String in d.validate(city.graph):
				push_warning("Missionsdaten: " + e)
			_spawn_giver(d, city)
	EventBus.player_died.connect(func(_c: String) -> void: _request_fail("Du wurdest ausgeschaltet."))
	EventBus.player_busted.connect(func() -> void: _request_fail("Du wurdest festgenommen."))


func _spawn_giver(d: MissionDefinition, city: CityWorld) -> void:
	var poi: String = str(d.giver.get("poi", ""))
	if poi.is_empty():
		return
	var giver := MissionGiver.new()
	giver.name = "Auftraggeber_" + d.id
	giver.setup(d.id, d.giver, self)
	game.add_child(giver)
	giver.global_position = city.poi_position(poi)
	giver.rotation.y = city.graph.poi_yaw(poi)
	givers[d.id] = giver


# ------------------------------------------------------------------ Abfragen

func has_active() -> bool:
	return active != null or awaiting_retry


func is_available(mission_id: String) -> bool:
	if not definitions.has(mission_id):
		return false
	var d: MissionDefinition = definitions[mission_id]
	for r: String in d.requires:
		if not GameState.is_mission_completed(r):
			return false
	if GameState.is_mission_completed(mission_id) and not d.repeatable:
		return false
	return true


func get_title() -> String:
	return active.title if active != null else ""


func player() -> Player:
	return game.get("player") as Player


func mission_vehicle(tag: String) -> Vehicle:
	var v: Variant = _entities.get(tag)
	if v != null and is_instance_valid(v):
		return v as Vehicle
	return null


func giver_start_transform(mission_id: String) -> Transform3D:
	var g: MissionGiver = givers.get(mission_id)
	if g == null:
		return player().global_transform
	var fwd: Vector3 = -g.global_basis.z
	var pos: Vector3 = g.global_position + fwd * 2.4 + Vector3.UP * 0.05
	return Transform3D(Basis(Vector3.UP, g.rotation.y + PI), pos)


# ------------------------------------------------------------------ Ablauf

func start_mission(mission_id: String, is_retry: bool = false) -> bool:
	if active != null or not is_available(mission_id):
		return false
	awaiting_retry = false
	active = definitions[mission_id]
	GameState.register_attempt(mission_id)
	_start_xf = giver_start_transform(mission_id)
	_abandon_t = 0.0
	race_time = 0.0
	_pending_fail = ""
	EventBus.mission_started.emit(mission_id)
	AudioManager.play_2d("ui_confirm", -2.0)
	_begin_step(0 if not is_retry else _first_non_talk_index_if_retry())
	return true


func _first_non_talk_index_if_retry() -> int:
	# Beim Wiederholen wird der einleitende Dialog übersprungen
	if active.steps.size() > 1 and str(active.steps[0].get("type", "")) == "talk":
		return 1
	return 0


func retry() -> void:
	if not awaiting_retry or last_failed_id.is_empty():
		return
	awaiting_retry = false
	if game.has_method("prepare_mission_retry"):
		game.call("prepare_mission_retry", last_failed_id, giver_start_transform(last_failed_id))
	start_mission(last_failed_id, true)
	changed.emit()


func abort() -> void:
	awaiting_retry = false
	fail_reason = ""
	changed.emit()


func _begin_step(i: int) -> void:
	_clear_step_visuals()
	step_index = i
	if active == null:
		return
	if i >= active.steps.size():
		_complete()
		return
	_step = active.steps[i]
	_st = {}
	progress = -1.0
	progress_label = ""
	has_target = false
	if _step.has("text"):
		objective = str(_step.text)
	var t: String = str(_step.get("type", ""))
	match t:
		"talk":
			_dialog = (_step.get("lines", []) as Array).duplicate()
			dialog_active = true
			if not player().is_in_vehicle():
				_freeze(true)
			_next_dialog_line()
		"spawn_vehicle":
			_spawn_vehicle(_step)
			_begin_step(i + 1)
			return
		"enter_vehicle":
			var v: Vehicle = mission_vehicle(str(_step.tag))
			if v != null:
				var m: MissionMarker = _add_marker("fahrzeug", 2.5, v.global_position)
				m.follow = v
				_set_target(v.global_position)
		"goto", "wait_zone":
			var pos: Vector3 = _step_pos(_step)
			_add_marker(str(_step.get("marker", "ziel")), float(_step.get("radius", 6.0)), pos)
			_set_target(pos)
		"interact":
			var ipos: Vector3 = _step_pos(_step)
			_interact_point = MissionInteractPoint.new()
			_interact_point.prompt = str(_step.get("prompt", "Interagieren"))
			_interact_point.interaction_radius = float(_step.get("radius", 2.5))
			game.add_child(_interact_point)
			_interact_point.global_position = ipos
			_interact_point.used.connect(func() -> void: _st["done"] = true)
			_add_marker("ziel", 1.2, ipos)
			_set_target(ipos)
			player().refresh_hint()
		"countdown":
			_st["t"] = 0.0
			_st["shown"] = -1
			_freeze(true)
		"checkpoints":
			_st["idx"] = 0
			_st["time"] = 0.0
			_show_checkpoint(0)
		"trigger_wanted":
			if game.has_method("set_wanted"):
				game.call("set_wanted", int(_step.get("level", 2)), str(_step.get("reason", "Missionsereignis")), player().global_position)
			if _step.has("message"):
				EventBus.big_message.emit(str(_step.message), "", 2.5)
			_begin_step(i + 1)
			return
		"lose_wanted":
			pass
	EventBus.mission_objective.emit(active.id, objective)
	changed.emit()


func _step_pos(s: Dictionary) -> Vector3:
	var city: CityWorld = game.call("get_city")
	if s.has("poi"):
		return city.poi_position(str(s.poi))
	if s.has("pos"):
		var p: Array = s.pos
		return Vector3(float(p[0]), city.ground_y(Vector2(float(p[0]), float(p[1]))), float(p[1]))
	return Vector3.ZERO


func _set_target(p: Vector3) -> void:
	target = p
	has_target = true


func _spawn_vehicle(s: Dictionary) -> void:
	var tag: String = str(s.get("tag", "fahrzeug"))
	var old: Vehicle = mission_vehicle(tag)
	if old != null:
		_remove_vehicle(old)
	var city: CityWorld = game.call("get_city")
	var poi: String = str(s.get("poi", ""))
	var pos: Vector3 = city.poi_position(poi)
	var yaw: float = city.graph.poi_yaw(poi)
	if game.has_method("clear_area"):
		game.call("clear_area", pos, 7.0)
	var col: Color = Color.html(str(s.color)) if s.has("color") else Color(-1, 0, 0)
	var v: Vehicle = game.call("spawn_vehicle", str(s.get("spec", "kompakt")), Vector3(pos.x, 0.0, pos.z) + Vector3.UP * pos.y,
		yaw, col, Vehicle.Ownership.MISSION, str(s.get("livery", "")))
	v.mission_tag = tag
	v.add_to_group("mission_vehicles")
	_entities[tag] = v


func _physics_process(delta: float) -> void:
	_despawn_t -= delta
	if _despawn_t <= 0.0:
		_despawn_t = 2.0
		_despawn_temp_vehicles()
	if active == null:
		return
	if _pending_fail != "":
		var r: String = _pending_fail
		_pending_fail = ""
		fail(r)
		return
	if _check_fail(delta):
		return
	var p: Player = player()
	var t: String = str(_step.get("type", ""))
	match t:
		"talk":
			if auto_skip_dialog:
				_dialog_t = 0.0
			_dialog_t -= delta
			if _dialog_t <= 0.0:
				_next_dialog_line()
		"enter_vehicle":
			var v: Vehicle = mission_vehicle(str(_step.tag))
			if v != null and p.current_vehicle == v:
				_begin_step(step_index + 1)
		"goto":
			if _in_zone(_step, p):
				if bool(_step.get("require_clean", false)) and not _is_clean():
					objective = str(_step.get("dirty_text", "Die Polizei ist noch zu nah – erst abschütteln!"))
					changed.emit()
				else:
					_begin_step(step_index + 1)
			elif bool(_step.get("require_clean", false)) and objective != str(_step.get("text", "")):
				objective = str(_step.get("text", ""))
				changed.emit()
		"wait_zone":
			var ok: bool = _in_zone(_step, p)
			var veh: Vehicle = p.current_vehicle as Vehicle
			if ok and veh != null and veh.linear_velocity.length() > float(_step.get("max_speed", 2.0)):
				ok = false
			var tt: float = float(_st.get("t", 0.0))
			tt = tt + delta if ok else maxf(0.0, tt - delta * 2.0)
			_st["t"] = tt
			progress = clampf(tt / float(_step.get("seconds", 3.0)), 0.0, 1.0)
			progress_label = str(_step.get("progress", ""))
			if progress >= 1.0:
				_begin_step(step_index + 1)
		"exit_vehicle":
			if not p.is_in_vehicle():
				_begin_step(step_index + 1)
		"interact":
			if bool(_st.get("done", false)):
				_begin_step(step_index + 1)
		"countdown":
			_update_countdown(delta)
		"checkpoints":
			_update_checkpoints(delta, p)
		"lose_wanted":
			var lvl: int = int(game.call("get_wanted_level")) if game.has_method("get_wanted_level") else 0
			if lvl == 0:
				EventBus.notify.emit("Verfolger abgeschüttelt.", "erfolg")
				_begin_step(step_index + 1)


func _in_zone(s: Dictionary, p: Player) -> bool:
	var pos: Vector3 = _step_pos(s)
	var r: float = float(s.get("radius", 6.0))
	var pp: Vector3 = p.current_vehicle.global_position if p.is_in_vehicle() else p.global_position
	if Vector2(pp.x - pos.x, pp.z - pos.z).length() > r:
		return false
	if s.has("vehicle"):
		var v: Vehicle = mission_vehicle(str(s.vehicle))
		return v != null and p.current_vehicle == v
	if bool(s.get("on_foot", false)):
		return not p.is_in_vehicle()
	return true


func _is_clean() -> bool:
	var lvl: int = int(game.call("get_wanted_level")) if game.has_method("get_wanted_level") else 0
	if lvl > 0:
		return false
	if game.has_method("police_within"):
		var pp: Vector3 = player().global_position
		return not bool(game.call("police_within", pp, float(_step.get("clean_radius", 60.0))))
	return true


func _next_dialog_line() -> void:
	if _dialog.is_empty():
		dialog_active = false
		EventBus.dialog_closed.emit()
		_freeze(false)
		_begin_step(step_index + 1)
		return
	var line: Array = _dialog.pop_front()
	var text: String = str(line[1])
	EventBus.dialog_line.emit(str(line[0]), text)
	_dialog_t = clampf(float(text.length()) * 0.055, 2.4, 6.5)


## E / Eingabe: Dialogzeile überspringen.
func advance_dialog() -> void:
	if active != null and str(_step.get("type", "")) == "talk":
		_next_dialog_line()


func _unhandled_input(event: InputEvent) -> void:
	if dialog_active and (event.is_action_pressed("interact") or event.is_action_pressed("retry")):
		advance_dialog()
		get_viewport().set_input_as_handled()


func _update_countdown(delta: float) -> void:
	var t: float = float(_st.t) + delta
	_st["t"] = t
	var secs: int = int(_step.get("seconds", 3))
	var shown: int = int(_st.shown)
	var cur: int = int(floor(t))
	if cur != shown:
		_st["shown"] = cur
		if cur < secs:
			EventBus.big_message.emit(str(secs - cur), "", 0.9)
			AudioManager.play_2d("countdown_beep", -3.0)
		else:
			EventBus.big_message.emit("LOS!", "", 1.0)
			AudioManager.play_2d("countdown_go", -2.0)
			_freeze(false)
			_begin_step(step_index + 1)


func _show_checkpoint(idx: int) -> void:
	_clear_markers()
	var pts: Array = _step.get("points", [])
	var r: float = float(_step.get("radius", 9.0))
	var p: Vector3 = _cp_pos(pts[idx])
	_add_marker("kontrollpunkt", r, p)
	if idx + 1 < pts.size():
		_add_marker("vorschau", r * 0.7, _cp_pos(pts[idx + 1]))
	_set_target(p)
	checkpoint_info = "Kontrollpunkt %d/%d" % [idx + 1, pts.size()]
	objective = str(_step.get("text", "Fahre die Kontrollpunkte ab."))


func _cp_pos(v: Variant) -> Vector3:
	var city: CityWorld = game.call("get_city")
	if v is String:
		return city.poi_position(v)
	var a: Array = v
	return Vector3(float(a[0]), 0.0, float(a[1]))


func _update_checkpoints(delta: float, p: Player) -> void:
	var tt: float = float(_st.time) + delta
	_st["time"] = tt
	race_time = tt
	var limit: float = float(_step.get("time_limit", 999.0))
	var key: String = active.best_time_key if active.best_time_key != "" else active.id
	var best: float = GameState.get_best_time(key)
	timer_text = "Zeit %s / %s%s" % [_fmt_time(tt), _fmt_time(limit), ("   Bestzeit %s" % _fmt_time(best)) if best > 0.0 else ""]
	if tt > limit:
		fail("Die Zeit ist abgelaufen.")
		return
	var pts: Array = _step.get("points", [])
	var idx: int = int(_st.idx)
	var cp: Vector3 = _cp_pos(pts[idx])
	var pp: Vector3 = p.current_vehicle.global_position if p.is_in_vehicle() else p.global_position
	var need_vehicle: bool = _step.has("vehicle")
	var in_vehicle_ok: bool = not need_vehicle or (p.current_vehicle == mission_vehicle(str(_step.vehicle)))
	if in_vehicle_ok and Vector2(pp.x - cp.x, pp.z - cp.z).length() < float(_step.get("radius", 9.0)):
		AudioManager.play_2d("checkpoint", -3.0)
		idx += 1
		_st["idx"] = idx
		if idx >= pts.size():
			var rec: bool = GameState.submit_best_time(key, tt)
			EventBus.notify.emit("Ziel erreicht in %s%s" % [_fmt_time(tt), " – neue Bestzeit!" if rec else ""], "erfolg")
			timer_text = ""
			checkpoint_info = ""
			_begin_step(step_index + 1)
		else:
			_show_checkpoint(idx)
			changed.emit()


static func _fmt_time(t: float) -> String:
	if t <= 0.0:
		return "--:--"
	var m: int = int(t) / 60
	var s: float = fmod(t, 60.0)
	return "%02d:%04.1f" % [m, s]


## Prüft Fehlschlagbedingungen. Rückgabe: true, wenn die Mission gescheitert ist.
func _check_fail(delta: float) -> bool:
	if active.fail_vehicle != "" and _entities.has(active.fail_vehicle):
		var v: Vehicle = mission_vehicle(active.fail_vehicle)
		if v == null:
			fail("Das Fahrzeug ist verschwunden.")
			return true
		if v.is_destroyed:
			fail("Das Fahrzeug ist hinüber.")
			return true
		var p: Player = player()
		var needs: bool = _step.has("vehicle") or str(_step.get("type", "")) in ["goto", "wait_zone", "checkpoints", "lose_wanted"]
		if needs and p.current_vehicle != v:
			var d: float = p.global_position.distance_to(v.global_position)
			if d > ABANDON_DISTANCE:
				_abandon_t += delta
				if _abandon_t > ABANDON_TIME:
					fail("Du hast das Fahrzeug zurückgelassen.")
					return true
			else:
				_abandon_t = 0.0
		else:
			_abandon_t = 0.0
	return false


func _request_fail(reason: String) -> void:
	if active != null:
		_pending_fail = reason


func fail(reason: String) -> void:
	if active == null:
		return
	var id: String = active.id
	_freeze(false)
	dialog_active = false
	EventBus.dialog_closed.emit()
	_clear_step_visuals()
	_cleanup_entities(true)
	last_failed_id = id
	fail_reason = reason
	active = null
	step_index = -1
	awaiting_retry = true
	objective = ""
	has_target = false
	timer_text = ""
	checkpoint_info = ""
	progress = -1.0
	AudioManager.play_2d("mission_fail", -2.0)
	EventBus.mission_failed.emit(id, reason)
	changed.emit()


func _complete() -> void:
	var d: MissionDefinition = active
	var first: bool = GameState.complete_mission(d.id, d.reward)
	_clear_step_visuals()
	_cleanup_entities(false)
	active = null
	step_index = -1
	objective = ""
	has_target = false
	timer_text = ""
	checkpoint_info = ""
	progress = -1.0
	AudioManager.play_2d("mission_success", -1.0)
	EventBus.mission_completed.emit(d.id, d.reward if first else 0, first)
	EventBus.big_message.emit("AUFTRAG ERLEDIGT", ("+%d €" % d.reward) if first else "Keine erneute Belohnung", 4.0)
	if game.has_method("on_mission_completed"):
		game.call("on_mission_completed", d.id)
	changed.emit()


func _freeze(on: bool) -> void:
	_frozen = on
	var p: Player = player()
	if p != null:
		p.input_enabled = not on


func _add_marker(kind: String, radius: float, pos: Vector3) -> MissionMarker:
	var m := MissionMarker.new()
	m.setup(kind, radius)
	game.add_child(m)
	m.global_position = pos
	_markers.append(m)
	return m


func _clear_markers() -> void:
	for m: Node3D in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


func _clear_step_visuals() -> void:
	_clear_markers()
	if _interact_point != null and is_instance_valid(_interact_point):
		_interact_point.queue_free()
	_interact_point = null
	var p: Player = player()
	if p != null:
		p.refresh_hint()


## Missionsfahrzeuge: bei Fehlschlag entfernen, bei Erfolg als normale Fahrzeuge später ausblenden.
func _cleanup_entities(delete_now: bool) -> void:
	for tag: String in _entities.keys():
		var v: Vehicle = mission_vehicle(tag)
		if v == null:
			continue
		if delete_now:
			_remove_vehicle(v)
		else:
			v.ownership = Vehicle.Ownership.PUBLIC
			v.remove_from_group("mission_vehicles")
			_temp_vehicles.append(v)
	_entities.clear()


func _remove_vehicle(v: Vehicle) -> void:
	var p: Player = player()
	if p != null and p.current_vehicle == v:
		var exit_info: Dictionary = v.find_exit_position()
		var pos: Vector3 = exit_info.position if exit_info.ok else v.global_position + Vector3(0, 0.5, 0) + v.global_basis.x * -2.5
		p.force_leave_vehicle(pos)
	v.queue_free()


func _despawn_temp_vehicles() -> void:
	var p: Player = player()
	if p == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	for i: int in range(_temp_vehicles.size() - 1, -1, -1):
		var v: Node3D = _temp_vehicles[i]
		if not is_instance_valid(v):
			_temp_vehicles.remove_at(i)
			continue
		if p.current_vehicle == v:
			continue
		var far: bool = v.global_position.distance_to(p.global_position) > TEMP_DESPAWN_DISTANCE
		var visible: bool = cam != null and cam.is_position_in_frustum(v.global_position) and v.global_position.distance_to(cam.global_position) < 250.0
		if far and not visible:
			v.queue_free()
			_temp_vehicles.remove_at(i)


func temp_vehicle_count() -> int:
	return _temp_vehicles.size()
