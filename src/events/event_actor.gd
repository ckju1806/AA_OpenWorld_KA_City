class_name EventActor
extends Node3D
## Figur für Zufallsereignisse (W7): gleiche Optik wie Passanten, aber geskriptet (Ziel ansteuern, rennen,
## schubsen, jubeln/rufen, umgestoßen werden). Wird ein Akteur vom Spieler angefahren, meldet der Direktor eine Tat.

signal knocked_down(actor: EventActor, by_player: bool)

enum Mode { STAND, GOTO, FLEE, SHOVE, CHEER, DOWN, FOLLOW }

var mode: Mode = Mode.STAND
var target: Vector3 = Vector3.ZERO
var follow_node: Node3D = null
var speed: float = 1.4
var group_id: String = ""
var rig: HumanoidRig
var area: Area3D
var ground_y: float = 0.12
var _t: float = 0.0
var _down_t: float = 0.0
var _shove_t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _city: CityWorld


func setup(city: CityWorld, seed_value: int, look: Dictionary) -> void:
	_city = city
	_rng.seed = seed_value
	add_to_group("event_actors")
	rig = HumanoidRig.new()
	add_child(rig)
	rig.build(look)
	area = Area3D.new()
	area.collision_layer = Layers.NPC
	area.collision_mask = Layers.VEHICLE | Layers.PLAYER
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


## Zufälliges Aussehen; Gruppenfarbe (Jacke) optional.
static func look_for(rng: RandomNumberGenerator, jacket: Color = Color(-1, 0, 0)) -> Dictionary:
	var skins: Array[Color] = [Color(0.96, 0.8, 0.68), Color(0.87, 0.67, 0.52), Color(0.72, 0.52, 0.38), Color(0.5, 0.35, 0.25), Color(0.36, 0.25, 0.18)]
	var shirts: Array[Color] = [Color(0.2, 0.3, 0.5), Color(0.6, 0.15, 0.15), Color(0.85, 0.8, 0.7), Color(0.15, 0.15, 0.17), Color(0.45, 0.25, 0.45)]
	var d: Dictionary = {"skin": skins[rng.randi() % skins.size()], "shirt": shirts[rng.randi() % shirts.size()],
		"pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.9, 0.9, 0.9) if rng.randf() < 0.4 else Color(0.1, 0.1, 0.1),
		"hair": Color(0.1, 0.08, 0.06), "hair_style": rng.randi() % 3, "height": rng.randf_range(0.93, 1.06)}
	if jacket.r >= 0.0:
		d["jacket"] = jacket
	return d


func place(p: Vector3) -> void:
	global_position = Vector3(p.x, _ground(Vector2(p.x, p.z)), p.z)
	target = global_position


func go_to(p: Vector3, spd: float = 1.4) -> void:
	if mode == Mode.DOWN:
		return
	target = p
	speed = spd
	mode = Mode.GOTO


func flee_from(p: Vector3, dist: float = 25.0) -> void:
	if mode == Mode.DOWN:
		return
	var d: Vector3 = global_position - p
	d.y = 0.0
	if d.length() < 0.1:
		d = Vector3(1, 0, 0)
	target = global_position + d.normalized() * dist
	speed = 4.6
	mode = Mode.FLEE


func shove(toward: Vector3) -> void:
	if mode == Mode.DOWN:
		return
	target = toward
	mode = Mode.SHOVE
	_shove_t = 0.8


func knock_down(by_player: bool = false) -> void:
	if mode == Mode.DOWN:
		return
	mode = Mode.DOWN
	_down_t = 5.0
	knocked_down.emit(self, by_player)


func is_down() -> bool:
	return mode == Mode.DOWN


func arrived(r: float = 1.0) -> bool:
	return Vector2(global_position.x - target.x, global_position.z - target.z).length() < r


func _ground(p: Vector2) -> float:
	return _city.ground_y(p) if _city != null else 0.12


func _physics_process(delta: float) -> void:
	_t += delta
	var pose: HumanoidRig.Pose = HumanoidRig.Pose.IDLE
	var spd: float = 0.0
	match mode:
		Mode.DOWN:
			pose = HumanoidRig.Pose.DOWN
			_down_t -= delta
			if _down_t <= 0.0:
				mode = Mode.STAND
		Mode.GOTO, Mode.FLEE, Mode.FOLLOW:
			if mode == Mode.FOLLOW and follow_node != null and is_instance_valid(follow_node):
				target = follow_node.global_position - follow_node.global_basis.z * -1.6
			var d: Vector3 = target - global_position
			d.y = 0.0
			var dl: float = d.length()
			if dl > 0.6:
				spd = speed
				var step: Vector3 = d / dl * minf(dl, speed * delta)
				global_position += step
				rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 8.0, 0.0, 1.0))
				pose = HumanoidRig.Pose.RUN if speed > 3.0 else HumanoidRig.Pose.WALK
			elif mode != Mode.FOLLOW:
				mode = Mode.STAND
		Mode.SHOVE:
			_shove_t -= delta
			var d2: Vector3 = target - global_position
			rotation.y = lerp_angle(rotation.y, atan2(-d2.x, -d2.z), clampf(delta * 10.0, 0.0, 1.0))
			pose = HumanoidRig.Pose.WAVE
			if _shove_t <= 0.0:
				mode = Mode.STAND
		Mode.CHEER:
			pose = HumanoidRig.Pose.WAVE if fmod(_t, 2.0) < 1.2 else HumanoidRig.Pose.IDLE
	if int(_t * 4.0) != int((_t - delta) * 4.0) and spd > 0.0:
		ground_y = _ground(Vector2(global_position.x, global_position.z))
	global_position.y = ground_y
	if rig != null:
		rig.animate(delta, spd, pose)


func _on_body_entered(body: Node3D) -> void:
	if mode == Mode.DOWN:
		return
	if body is Vehicle:
		var v: Vehicle = body as Vehicle
		if v.linear_velocity.length() > 2.5:
			AudioManager.play_3d("crash", global_position, -10.0, 1.4)
			knock_down(v.driver == Vehicle.Driver.PLAYER)
	elif body is Player:
		var pl: Player = body as Player
		if pl.velocity.length() > 5.0:
			knock_down(true)
