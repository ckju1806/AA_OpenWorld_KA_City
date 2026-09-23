class_name HumanoidRig
extends Node3D
## Prozedurale Gliederpuppe (menschliche Silhouette) mit codebasierten Animationen.
## Wird für Spielfigur und Passanten genutzt. Blickrichtung: -Z.

enum Pose { IDLE, WALK, RUN, JUMP, FALL, DOWN, SIT, WAVE }

const HIP_HEIGHT: float = 0.95

var pose: Pose = Pose.IDLE
var move_speed: float = 0.0

var _root: Node3D
var _hips: Node3D
var _spine: Node3D
var _head: Node3D
var _thigh: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _arm: Array[Node3D] = []
var _forearm: Array[Node3D] = []
var _phase: float = 0.0
var _down_amount: float = 0.0
var _time: float = 0.0

static var _meshes: Dictionary = {}


## colors: skin, shirt, pants, shoes, hair (Color); optional "hair_style" (0..2), "height" (Skalierung)
func build(colors: Dictionary) -> void:
	for c: Node in get_children():
		c.queue_free()
	_thigh.clear()
	_shin.clear()
	_arm.clear()
	_forearm.clear()
	var skin: Material = MatLib.solid(colors.get("skin", Color(0.87, 0.7, 0.58)), 0.7)
	var shirt: Material = MatLib.solid(colors.get("shirt", Color(0.2, 0.3, 0.5)), 0.9)
	var pants: Material = MatLib.solid(colors.get("pants", Color(0.15, 0.15, 0.18)), 0.9)
	var shoes: Material = MatLib.solid(colors.get("shoes", Color(0.1, 0.08, 0.07)), 0.6)
	var hair: Material = MatLib.solid(colors.get("hair", Color(0.2, 0.13, 0.08)), 0.8)
	var jacket_col: Variant = colors.get("jacket", null)
	var height_scale: float = float(colors.get("height", 1.0))

	_root = Node3D.new()
	_root.name = "Root"
	_root.scale = Vector3.ONE * height_scale
	add_child(_root)

	_hips = _joint(_root, "Hips", Vector3(0, HIP_HEIGHT, 0))
	_part(_hips, "pelvis", _box_mesh(Vector3(0.32, 0.2, 0.2)), pants, Vector3(0, -0.02, 0))

	_spine = _joint(_hips, "Spine", Vector3(0, 0.06, 0))
	var torso_mat: Material = shirt
	var sleeve_mat: Material = shirt
	if jacket_col != null:
		# Offene Jacke: Torso und Ärmel in Jackenfarbe, Hemd als Einsatz vorne
		torso_mat = MatLib.solid(jacket_col, 0.85)
		sleeve_mat = torso_mat
	_part(_spine, "torso", _capsule_mesh(0.17, 0.58), torso_mat, Vector3(0, 0.27, 0), Vector3(1.12, 1.0, 0.72))
	if jacket_col != null:
		_part(_spine, "shirt_front", _box_mesh(Vector3(0.13, 0.34, 0.02)), shirt, Vector3(0, 0.33, -0.118))

	var neck: Node3D = _joint(_spine, "Neck", Vector3(0, 0.56, 0))
	_part(neck, "neck", _capsule_mesh(0.05, 0.14), skin, Vector3(0, 0.03, 0))
	_head = _joint(neck, "Head", Vector3(0, 0.08, 0))
	_part(_head, "head", _sphere_mesh(0.115), skin, Vector3(0, 0.11, 0), Vector3(0.92, 1.05, 1.0))
	_part(_head, "nose", _box_mesh(Vector3(0.03, 0.045, 0.04)), skin, Vector3(0, 0.1, -0.11))
	var eye_mat: Material = MatLib.solid(Color(0.08, 0.07, 0.07), 0.4)
	_part(_head, "eye_l", _box_mesh(Vector3(0.022, 0.018, 0.01)), eye_mat, Vector3(-0.04, 0.13, -0.104))
	_part(_head, "eye_r", _box_mesh(Vector3(0.022, 0.018, 0.01)), eye_mat, Vector3(0.04, 0.13, -0.104))
	var hs: int = int(colors.get("hair_style", 0))
	if hs == 0:
		_part(_head, "hair", _sphere_mesh(0.12), hair, Vector3(0, 0.155, 0.015), Vector3(0.98, 0.62, 1.02))
	elif hs == 1:
		_part(_head, "hair", _sphere_mesh(0.125), hair, Vector3(0, 0.13, 0.03), Vector3(1.0, 0.95, 1.0))
	else:
		_part(_head, "cap", _cylinder_mesh(0.12, 0.07), hair, Vector3(0, 0.2, 0.0))
		_part(_head, "visor", _box_mesh(Vector3(0.16, 0.015, 0.1)), hair, Vector3(0, 0.17, -0.12))

	for side: int in 2:
		var sx: float = -1.0 if side == 0 else 1.0
		var thigh: Node3D = _joint(_hips, "Thigh%d" % side, Vector3(0.1 * sx, -0.04, 0))
		_part(thigh, "thigh", _capsule_mesh(0.075, 0.48), pants, Vector3(0, -0.22, 0))
		var shin: Node3D = _joint(thigh, "Shin%d" % side, Vector3(0, -0.45, 0))
		_part(shin, "shin", _capsule_mesh(0.062, 0.46), pants, Vector3(0, -0.21, 0))
		_part(shin, "foot", _box_mesh(Vector3(0.1, 0.07, 0.25)), shoes, Vector3(0, -0.435, -0.05))
		_thigh.append(thigh)
		_shin.append(shin)
		var arm: Node3D = _joint(_spine, "Arm%d" % side, Vector3(0.215 * sx, 0.5, 0))
		_part(arm, "upper", _capsule_mesh(0.052, 0.32), sleeve_mat, Vector3(0, -0.15, 0))
		var fore: Node3D = _joint(arm, "Fore%d" % side, Vector3(0, -0.3, 0))
		_part(fore, "fore", _capsule_mesh(0.045, 0.28), skin if colors.get("short_sleeves", false) else sleeve_mat, Vector3(0, -0.13, 0))
		_part(fore, "hand", _sphere_mesh(0.048), skin, Vector3(0, -0.29, 0))
		_arm.append(arm)
		_forearm.append(fore)
		arm.rotation.z = 0.08 * sx


func _joint(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	return j


func _part(parent: Node3D, n: String, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _capsule_mesh(r: float, h: float) -> Mesh:
	var key: String = "c%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0 + 0.01)
		m.radial_segments = 10
		m.rings = 3
		_meshes[key] = m
	return _meshes[key]


static func _box_mesh(s: Vector3) -> Mesh:
	var key: String = "b%.3f_%.3f_%.3f" % [s.x, s.y, s.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = s
		_meshes[key] = m
	return _meshes[key]


static func _sphere_mesh(r: float) -> Mesh:
	var key: String = "s%.3f" % r
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 12
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


static func _cylinder_mesh(r: float, h: float) -> Mesh:
	var key: String = "y%.3f_%.3f" % [r, h]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 12
		_meshes[key] = m
	return _meshes[key]


## Pro Frame aufrufen. speed = horizontale Geschwindigkeit (m/s).
func animate(delta: float, speed: float, new_pose: Pose) -> void:
	if _hips == null:
		return
	pose = new_pose
	move_speed = speed
	_time += delta
	var k: float = clampf(delta * 12.0, 0.0, 1.0)

	var down_target: float = 1.0 if pose == Pose.DOWN else 0.0
	_down_amount = move_toward(_down_amount, down_target, delta * 3.0)
	_root.rotation.x = -PI * 0.5 * _down_amount
	_root.position.y = 0.18 * _down_amount

	var thigh_t: Array[float] = [0.0, 0.0]
	var shin_t: Array[float] = [0.0, 0.0]
	var arm_t: Array[float] = [0.0, 0.0]
	var fore_t: Array[float] = [0.15, 0.15]
	var spine_t: float = 0.0
	var hips_y: float = HIP_HEIGHT
	var arm_side: float = 0.08

	match pose:
		Pose.IDLE:
			var breathe: float = sin(_time * 1.6) * 0.012
			hips_y = HIP_HEIGHT + breathe * 0.3
			spine_t = breathe
			arm_t = [0.02 + breathe, 0.02 + breathe]
		Pose.WALK, Pose.RUN:
			var running: bool = pose == Pose.RUN
			var stride: float = 2.3 if running else 1.45
			_phase += delta * TAU * speed / stride
			var amp: float = (0.85 if running else 0.5) * clampf(speed / (5.5 if running else 2.8), 0.3, 1.1)
			var s: float = sin(_phase)
			thigh_t = [s * amp, -s * amp]
			shin_t = [-maxf(0.0, sin(_phase - 1.3)) * amp * 1.4, -maxf(0.0, sin(_phase - 1.3 + PI)) * amp * 1.4]
			arm_t = [-s * amp * 0.8, s * amp * 0.8]
			fore_t = [0.25 + (0.9 if running else 0.2), 0.25 + (0.9 if running else 0.2)]
			spine_t = -0.2 if running else -0.04
			hips_y = HIP_HEIGHT - 0.02 + absf(cos(_phase)) * (0.06 if running else 0.03)
		Pose.JUMP:
			thigh_t = [0.7, 0.25]
			shin_t = [-1.0, -0.5]
			arm_t = [0.9, 0.9]
			fore_t = [0.5, 0.5]
			spine_t = -0.1
			arm_side = 0.35
		Pose.FALL:
			thigh_t = [0.3, -0.1]
			shin_t = [-0.5, -0.3]
			arm_t = [2.3 + sin(_time * 9.0) * 0.3, 2.3 - sin(_time * 9.0) * 0.3]
			arm_side = 0.5
		Pose.DOWN:
			thigh_t = [0.2, -0.1]
			shin_t = [-0.3, -0.1]
			arm_t = [-2.6, 0.3]
			arm_side = 0.3
		Pose.SIT:
			thigh_t = [1.45, 1.45]
			shin_t = [-1.35, -1.35]
			arm_t = [0.95, 0.95]
			fore_t = [0.6, 0.6]
			hips_y = 0.5
		Pose.WAVE:
			arm_t = [0.0, 2.7 + sin(_time * 8.0) * 0.25]
			fore_t = [0.1, 0.4]
			arm_side = 0.1

	_hips.position.y = lerpf(_hips.position.y, hips_y, k)
	_spine.rotation.x = lerp_angle(_spine.rotation.x, spine_t, k)
	for i: int in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_thigh[i].rotation.x = lerp_angle(_thigh[i].rotation.x, thigh_t[i], k)
		_shin[i].rotation.x = lerp_angle(_shin[i].rotation.x, shin_t[i], k)
		_arm[i].rotation.x = lerp_angle(_arm[i].rotation.x, arm_t[i], k)
		_arm[i].rotation.z = lerp_angle(_arm[i].rotation.z, arm_side * sx, k)
		_forearm[i].rotation.x = lerp_angle(_forearm[i].rotation.x, fore_t[i], k)
	if pose == Pose.WALK or pose == Pose.RUN:
		_head.rotation.x = -_spine.rotation.x * 0.6
	else:
		_head.rotation.x = lerp_angle(_head.rotation.x, 0.0, k)
