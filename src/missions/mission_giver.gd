class_name MissionGiver
extends Node3D
## Auftraggeber-Figur: steht an ihrem POI, zeigt ein Auftragssymbol, wenn eine Mission verfügbar ist,
## und startet die Mission per Interaktion (E).

var mission_id: String = ""
var display_name: String = ""
var prompt: String = "Sprechen"
var done_line: String = ""
var system: Node = null            ## MissionSystem
var interaction_radius: float = 2.8

var _rig: HumanoidRig
var _icon: Label3D
var _t: float = 0.0
var _player: Node3D = null


func setup(p_mission_id: String, giver: Dictionary, p_system: Node) -> void:
	mission_id = p_mission_id
	system = p_system
	display_name = str(giver.get("name", "Auftraggeber"))
	prompt = str(giver.get("prompt", "Mit %s sprechen" % display_name))
	done_line = str(giver.get("done_line", ""))
	var look: Dictionary = giver.get("look", {})
	var colors: Dictionary = {}
	for k: String in ["skin", "shirt", "jacket", "pants", "shoes", "hair"]:
		if look.has(k):
			colors[k] = Color.html(str(look[k]))
	colors["hair_style"] = int(look.get("hair_style", 0))
	_rig = HumanoidRig.new()
	add_child(_rig)
	_rig.build(colors)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	body.add_child(cs)
	add_child(body)
	_icon = Label3D.new()
	_icon.text = "◆"
	_icon.font_size = 128
	_icon.pixel_size = 0.006
	_icon.modulate = Color(0.98, 0.62, 0.22)
	_icon.outline_size = 18
	_icon.outline_modulate = Color(0.12, 0.08, 0.06)
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = false
	_icon.position = Vector3(0, 2.55, 0)
	add_child(_icon)
	var name_lbl := Label3D.new()
	name_lbl.text = display_name
	name_lbl.font_size = 40
	name_lbl.pixel_size = 0.006
	name_lbl.modulate = Color(1, 0.95, 0.88)
	name_lbl.outline_size = 10
	name_lbl.outline_modulate = Color(0.1, 0.08, 0.08)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.position = Vector3(0, 2.15, 0)
	name_lbl.visibility_range_end = 25.0
	add_child(name_lbl)


func _enter_tree() -> void:
	Interactables.register(self)


func _exit_tree() -> void:
	Interactables.unregister(self)


func is_offering() -> bool:
	return system != null and bool(system.call("is_available", mission_id))


func can_interact(p: Player) -> bool:
	if p == null or p.is_in_vehicle() or system == null:
		return false
	if bool(system.call("has_active")):
		return false
	return is_offering() or done_line != ""


func get_interaction_text(_p: Player) -> String:
	return prompt if is_offering() else "Mit %s plaudern" % display_name.split(" ")[0]


func interact(_p: Player) -> void:
	if is_offering():
		system.call("start_mission", mission_id)
	elif done_line != "":
		EventBus.dialog_line.emit(display_name, done_line)


func _process(delta: float) -> void:
	_t += delta
	var offering: bool = is_offering() and not bool(system.call("has_active"))
	_icon.visible = offering
	_icon.position.y = 2.55 + sin(_t * 2.0) * 0.12
	if _player == null or not is_instance_valid(_player):
		var ps: Array[Node] = get_tree().get_nodes_in_group("player")
		_player = ps[0] as Node3D if not ps.is_empty() else null
	var near: bool = _player != null and _player.global_position.distance_to(global_position) < 9.0
	if near:
		var d: Vector3 = _player.global_position - global_position
		var target_yaw: float = atan2(-d.x, -d.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 3.0, 0.0, 1.0))
	_rig.animate(delta, 0.0, HumanoidRig.Pose.WAVE if (near and offering) else HumanoidRig.Pose.IDLE)
