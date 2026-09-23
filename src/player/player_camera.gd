class_name PlayerCamera
extends Node3D
## Third-Person-Kamera: Maussteuerung (Gier/Nick), SpringArm-Kollisionsschutz gegen Gebäude/Boden,
## weicher Wechsel zwischen Fuß- und Fahrzeugmodus, automatisches Nachführen hinter dem Fahrzeug.

const PITCH_MIN: float = -1.25
const PITCH_MAX: float = 0.5
const FOOT_DISTANCE: float = 4.2
const FOOT_OFFSET: Vector3 = Vector3(0.0, 1.6, 0.0)
const AUTO_ALIGN_DELAY: float = 1.2

var yaw: float = 0.0
var pitch: float = -0.28
var target: Node3D = null
var vehicle_mode: bool = false

var _pitch_node: Node3D
var _arm: SpringArm3D
var camera: Camera3D
var _offset: Vector3 = FOOT_OFFSET
var _target_offset: Vector3 = FOOT_OFFSET
var _distance: float = FOOT_DISTANCE
var _target_distance: float = FOOT_DISTANCE
var _mouse_idle: float = 99.0
var _pos: Vector3 = Vector3.ZERO
var _base_fov: float = 72.0
var _excluded: RID = RID()
var _snap_next: bool = true


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_priority = 100
	_pitch_node = Node3D.new()
	_pitch_node.name = "Pitch"
	add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.28
	_arm.shape = sphere
	_arm.collision_mask = Layers.CAMERA_MASK
	_arm.margin = 0.12
	_arm.spring_length = _distance
	_pitch_node.add_child(_arm)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = _base_fov
	camera.near = 0.1
	camera.far = 1400.0
	_arm.add_child(camera)
	camera.current = true


func follow_player(p: Node3D) -> void:
	_set_excluded(RID())
	target = p
	vehicle_mode = false
	_target_offset = FOOT_OFFSET
	_target_distance = FOOT_DISTANCE


func follow_vehicle(v: Node3D) -> void:
	target = v
	vehicle_mode = true
	var dist: float = 7.0
	var h: float = 2.1
	if v.has_method("get_camera_params"):
		var cp: Vector2 = v.call("get_camera_params")
		dist = cp.x
		h = cp.y
	_target_offset = Vector3(0, h, 0)
	_target_distance = dist
	if v is CollisionObject3D:
		_set_excluded((v as CollisionObject3D).get_rid())


func _set_excluded(rid: RID) -> void:
	if _excluded.is_valid():
		_arm.remove_excluded_object(_excluded)
	_excluded = rid
	if rid.is_valid():
		_arm.add_excluded_object(rid)


func snap() -> void:
	_snap_next = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		var sens: float = deg_to_rad(Settings.mouse_sensitivity)
		yaw -= mm.relative.x * sens
		var inv: float = -1.0 if Settings.invert_y else 1.0
		pitch = clampf(pitch - mm.relative.y * sens * inv, PITCH_MIN, PITCH_MAX)
		_mouse_idle = 0.0


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_mouse_idle += delta
	var tpos: Vector3 = target.get_global_transform_interpolated().origin
	var k_pos: float = 1.0 - exp(-delta * (14.0 if vehicle_mode else 18.0))
	var k_blend: float = 1.0 - exp(-delta * 4.0)
	if _snap_next:
		_pos = tpos
		_offset = _target_offset
		_distance = _target_distance
		_snap_next = false
	else:
		_pos = _pos.lerp(tpos, k_pos)
		_offset = _offset.lerp(_target_offset, k_blend)
		_distance = lerpf(_distance, _target_distance, k_blend)

	var speed: float = 0.0
	if vehicle_mode and target.has_method("get_forward_speed"):
		speed = float(target.call("get_forward_speed"))
		# Automatisch hinter das Fahrzeug schwenken, wenn die Maus ruht
		if _mouse_idle > AUTO_ALIGN_DELAY and speed > 3.0:
			var fwd: Vector3 = -target.global_transform.basis.z
			var heading: float = atan2(-fwd.x, -fwd.z)
			yaw = lerp_angle(yaw, heading, clampf(delta * 2.2, 0.0, 1.0))
			pitch = lerpf(pitch, -0.2, clampf(delta * 1.5, 0.0, 1.0))

	global_position = _pos + _offset
	rotation = Vector3(0, yaw, 0)
	_pitch_node.rotation = Vector3(pitch, 0, 0)
	_arm.spring_length = _distance + clampf(speed * 0.04, 0.0, 1.6)
	camera.fov = lerpf(camera.fov, _base_fov + clampf(speed * 0.35, 0.0, 12.0), clampf(delta * 3.0, 0.0, 1.0))


func get_camera() -> Camera3D:
	return camera
