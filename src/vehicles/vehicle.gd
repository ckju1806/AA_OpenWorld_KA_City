class_name Vehicle
extends RigidBody3D
## Arcade-Fahrzeug: RigidBody3D mit vier Raycast-Federbeinen (Feder/Dämpfer), Quergrip,
## Handbremse (reduzierter Hinterachsgrip), geschwindigkeitsabhängiger Lenkung,
## Aufrichthilfe, Schadensmodell, Licht, Hupe, Ein-/Ausstieg mit Platzprüfung und Bergung.

signal destroyed
signal damaged(amount: float)
signal driver_changed(kind: int)

enum Driver { NONE, PLAYER, AI }
enum Ownership { PUBLIC, PARKED_FOREIGN, TRAFFIC, POLICE, MISSION }

const EXIT_MAX_SPEED: float = 3.0          ## m/s (~11 km/h)
const RECOVER_COOLDOWN: float = 12.0
const IMPACT_THRESHOLD: float = 2.2        ## m/s Geschwindigkeitsänderung pro Frame
const STABILIZE: float = 5.0

var spec: VehicleSpec
var paint_color: Color = Color.WHITE
var ownership: Ownership = Ownership.PUBLIC
var driver: Driver = Driver.NONE
var locked: bool = false
var livery_text: String = ""
var mission_tag: String = ""

var health: float = 1000.0
var max_health: float = 1000.0
var is_destroyed: bool = false
var lights_on: bool = false
var siren_on: bool = false

## Steuerwerte (vom Spieler oder der KI gesetzt)
var input_throttle: float = 0.0   ## 0..1
var input_brake: float = 0.0      ## 0..1 (bei Stillstand: rückwärts)
var input_steer: float = 0.0      ## -1 (links) .. 1 (rechts)
var input_handbrake: bool = false

var ai_controller: RefCounted = null     ## AIDriver/Autopilot (optional)
var player_ref: Player = null

var _steer_angle: float = 0.0
var _wheels: Array[Dictionary] = []
var _grounded_count: int = 0
var _prev_velocity: Vector3 = Vector3.ZERO
var _recover_cd: float = 0.0
var _stuck_time: float = 0.0
var _paint_mat: StandardMaterial3D
var _body_mi: MeshInstance3D
var _front_lights_mi: MeshInstance3D
var _rear_lights_mi: MeshInstance3D
var _beacons: Array[MeshInstance3D] = []
var _spots: Array[SpotLight3D] = []
var _beacon_light: OmniLight3D
var _engine: AudioStreamPlayer3D
var _siren: AudioStreamPlayer3D
var _smoke: GPUParticles3D
var _label_nodes: Array[Label3D] = []
var _beacon_t: float = 0.0
var _audio_check: float = 0.0
var _reverse_mode: bool = false
var _braking_visual: bool = false
var _damage_cooldown: float = 0.0

static var _mat_front_on: StandardMaterial3D
static var _mat_rear_on: StandardMaterial3D
static var _mat_brake: StandardMaterial3D
static var _mat_beacon_on: StandardMaterial3D


## Muss vor add_child aufgerufen werden.
func setup(p_spec: VehicleSpec, color: Color = Color(-1, 0, 0)) -> void:
	spec = p_spec
	paint_color = color if color.r >= 0.0 else spec.colors[0]
	max_health = spec.health
	health = max_health


func _ready() -> void:
	if spec == null:
		spec = VehicleSpec.get_spec("kompakt")
		paint_color = spec.colors[0]
		max_health = spec.health
		health = max_health
	add_to_group("vehicles")
	collision_layer = Layers.VEHICLE
	collision_mask = Layers.VEHICLE_MASK
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, spec.com_height, 0.0)
	angular_damp = 1.2
	linear_damp = 0.02
	contact_monitor = true
	max_contacts_reported = 4
	can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.05
	physics_material_override = pm
	_build_collision()
	_build_visuals()
	_build_wheels()
	_build_audio()
	if _mat_front_on == null:
		_mat_front_on = MatLib.emissive(Color(1.0, 0.95, 0.8), 4.0)
		_mat_rear_on = MatLib.emissive(Color(0.9, 0.08, 0.05), 2.0)
		_mat_brake = MatLib.emissive(Color(1.0, 0.1, 0.05), 6.0)
		_mat_beacon_on = MatLib.emissive(Color(0.2, 0.45, 1.0), 9.0)


func _build_collision() -> void:
	var lower := CollisionShape3D.new()
	var lb := BoxShape3D.new()
	var clearance: float = spec.wheel_radius + 0.02
	var top: float = spec.height * (0.62 if spec.body_style != "transporter" else 0.98)
	lb.size = Vector3(spec.width * 0.98, top - clearance, spec.length * 0.98)
	lower.shape = lb
	lower.position = Vector3(0, (top + clearance) * 0.5, 0)
	add_child(lower)
	if spec.body_style != "transporter":
		var cab := CollisionShape3D.new()
		var cb := BoxShape3D.new()
		cb.size = Vector3(spec.width * 0.85, spec.height - top, spec.length * 0.48)
		cab.shape = cb
		cab.position = Vector3(0, top + cb.size.y * 0.5, 0.1)
		add_child(cab)


func _build_visuals() -> void:
	var model: Dictionary = VehicleModelBuilder.get_model(spec)
	_body_mi = MeshInstance3D.new()
	_body_mi.name = "Body"
	_body_mi.mesh = model.body
	_paint_mat = StandardMaterial3D.new()
	_paint_mat.albedo_color = paint_color
	_paint_mat.roughness = 0.3
	_paint_mat.metallic = 0.35
	_body_mi.set_surface_override_material(int(model.paint_surface), _paint_mat)
	add_child(_body_mi)
	_front_lights_mi = MeshInstance3D.new()
	_front_lights_mi.mesh = model.front_lights
	add_child(_front_lights_mi)
	_rear_lights_mi = MeshInstance3D.new()
	_rear_lights_mi.mesh = model.rear_lights
	add_child(_rear_lights_mi)
	if model.has("beacon_left"):
		for key: String in ["beacon_left", "beacon_right"]:
			var b := MeshInstance3D.new()
			b.mesh = model[key]
			add_child(b)
			_beacons.append(b)
	if livery_text != "":
		for sx: float in [-1.0, 1.0]:
			var lbl := Label3D.new()
			lbl.text = livery_text
			lbl.font_size = 64
			lbl.pixel_size = 0.006
			lbl.modulate = Color(0.95, 0.45, 0.1)
			lbl.outline_size = 12
			lbl.outline_modulate = Color(0.1, 0.1, 0.12)
			lbl.position = Vector3(sx * (spec.width * 0.5 + 0.02), spec.height * 0.62, 0.35)
			lbl.rotation = Vector3(0, sx * PI * 0.5, 0)
			lbl.double_sided = false
			add_child(lbl)
			_label_nodes.append(lbl)
	if spec.body_style == "polizei":
		for sx2: float in [-1.0, 1.0]:
			var pl := Label3D.new()
			pl.text = "POLIZEI"
			pl.font_size = 56
			pl.pixel_size = 0.005
			pl.modulate = Color(0.95, 0.97, 1.0)
			pl.outline_size = 8
			pl.outline_modulate = Color(0.05, 0.12, 0.35)
			pl.position = Vector3(sx2 * (spec.width * 0.5 + 0.02), 0.82, 0.45)
			pl.rotation = Vector3(0, sx2 * PI * 0.5, 0)
			pl.double_sided = false
			add_child(pl)


func _build_wheels() -> void:
	var mount_h: float = spec.mount_height()
	var hx: float = spec.track * 0.5
	var hz: float = spec.wheelbase * 0.5
	var wheel_mesh: ArrayMesh = VehicleModelBuilder.get_wheel_mesh(spec.wheel_radius)
	var defs: Array = [
		[Vector3(-hx, mount_h, -hz), true, false],
		[Vector3(hx, mount_h, -hz), true, true],
		[Vector3(-hx, mount_h, hz), false, false],
		[Vector3(hx, mount_h, hz), false, true],
	]
	for d: Array in defs:
		var pivot := Node3D.new()
		pivot.rotation_order = EULER_ORDER_YXZ
		pivot.position = d[0] - Vector3(0, spec.rest_length, 0)
		add_child(pivot)
		var mi := MeshInstance3D.new()
		mi.mesh = wheel_mesh
		if d[2]:
			mi.rotation.y = PI
		pivot.add_child(mi)
		var driven: bool = spec.drive == "all" or (spec.drive == "front" and d[1]) or (spec.drive == "rear" and not d[1])
		_wheels.append({
			"mount": d[0], "front": d[1], "driven": driven, "pivot": pivot, "mesh": mi,
			"spin": 0.0, "compression": 0.0, "grounded": false, "contact": Vector3.ZERO, "normal": Vector3.UP,
			"load": 0.0,
		})


func _build_audio() -> void:
	_engine = AudioStreamPlayer3D.new()
	_engine.bus = "Effekte"
	_engine.unit_size = 6.0
	_engine.max_distance = 70.0
	_engine.volume_db = -10.0
	add_child(_engine)
	if spec.body_style == "polizei":
		_siren = AudioStreamPlayer3D.new()
		_siren.bus = "Effekte"
		_siren.unit_size = 25.0
		_siren.max_distance = 220.0
		_siren.volume_db = -6.0
		add_child(_siren)


# ---------------------------------------------------------------- Physik

func _physics_process(delta: float) -> void:
	if spec == null:
		return
	_recover_cd = maxf(0.0, _recover_cd - delta)
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	if driver == Driver.PLAYER:
		_read_player_input()
	elif driver == Driver.AI and ai_controller != null:
		ai_controller.call("update", self, delta)
	elif driver == Driver.NONE:
		input_throttle = 0.0
		input_brake = 0.0
		input_steer = 0.0
		input_handbrake = true
	if is_destroyed:
		input_throttle = 0.0
		input_handbrake = true

	var up: Vector3 = global_basis.y
	var fwd_body: Vector3 = -global_basis.z
	var speed_fwd: float = linear_velocity.dot(fwd_body)
	var speed_abs: float = linear_velocity.length()

	# Lenkung (geschwindigkeitsabhängig)
	var t: float = clampf(absf(speed_fwd) / spec.steer_speed_ref, 0.0, 1.0)
	var max_steer: float = deg_to_rad(lerpf(spec.steer_max_deg, spec.steer_min_deg, t))
	var target_steer: float = -input_steer * max_steer
	_steer_angle = move_toward(_steer_angle, target_steer, spec.steer_rate * delta)

	# Gas/Bremse/Rückwärts-Logik
	var drive_cmd: float = 0.0
	var brake_cmd: float = 0.0
	if input_throttle > 0.01:
		if speed_fwd < -1.0:
			brake_cmd = input_throttle
		else:
			drive_cmd = input_throttle
			_reverse_mode = false
	if input_brake > 0.01:
		if speed_fwd > 1.0 and not _reverse_mode:
			brake_cmd = maxf(brake_cmd, input_brake)
		else:
			_reverse_mode = true
			drive_cmd = -input_brake
	if input_throttle <= 0.01 and input_brake <= 0.01:
		_reverse_mode = false
	_braking_visual = brake_cmd > 0.1 or (input_handbrake and speed_abs > 1.0)

	var wheel_mass: float = mass * 0.25
	var k: float = spec.spring_k()
	var c: float = spec.damper_c()
	var ray_len: float = spec.rest_length + spec.wheel_radius
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_grounded_count = 0
	var driven_count: int = 0
	for w: Dictionary in _wheels:
		if w.driven:
			driven_count += 1

	for w: Dictionary in _wheels:
		var origin: Vector3 = global_transform * (w.mount as Vector3)
		var q := PhysicsRayQueryParameters3D.create(origin + up * 0.05, origin - up * ray_len, Layers.WORLD)
		q.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			w.grounded = false
			w.compression = 0.0
			w.load = 0.0
			continue
		var hit_pos: Vector3 = hit.position
		var n: Vector3 = hit.normal
		var dist: float = origin.distance_to(hit_pos)
		var compression: float = clampf(ray_len - dist, 0.0, spec.rest_length)
		var rel: Vector3 = hit_pos - global_position
		var vel_at: Vector3 = linear_velocity + angular_velocity.cross(rel)
		var comp_speed: float = -vel_at.dot(up)
		var f_susp: float = maxf(0.0, k * compression + c * comp_speed)
		# Anschlag: harte Kraft bei vollständiger Kompression
		if compression >= spec.rest_length * 0.98:
			f_susp += wheel_mass * 30.0
		apply_force(up * f_susp, origin - global_position)
		w.grounded = true
		w.compression = compression
		w.contact = hit_pos
		w.normal = n
		w.load = f_susp
		_grounded_count += 1

		# Reifenkräfte
		var wheel_fwd: Vector3 = fwd_body
		if w.front:
			wheel_fwd = fwd_body.rotated(up, _steer_angle)
		wheel_fwd = (wheel_fwd - n * wheel_fwd.dot(n)).normalized()
		var wheel_right: Vector3 = wheel_fwd.cross(n).normalized()
		var v_long: float = vel_at.dot(wheel_fwd)
		var v_lat: float = vel_at.dot(wheel_right)
		var grip: float = spec.grip_front if w.front else spec.grip_rear
		if input_handbrake and not w.front:
			grip *= spec.handbrake_grip
		var max_lat: float = grip * maxf(f_susp, wheel_mass * 4.0)
		var f_lat: float = clampf(-v_lat * wheel_mass / delta * 0.9, -max_lat, max_lat)
		var f_long: float = 0.0
		if w.driven and driven_count > 0 and not is_destroyed:
			var dmg_factor: float = 0.55 + 0.45 * clampf(health / max_health, 0.0, 1.0)
			if drive_cmd > 0.0:
				var ratio: float = clampf(speed_fwd / spec.max_speed, 0.0, 1.0)
				f_long += drive_cmd * spec.engine_force * dmg_factor * (1.0 - ratio * ratio) / float(driven_count)
			elif drive_cmd < 0.0:
				var rratio: float = clampf(-speed_fwd / spec.reverse_speed, 0.0, 1.0)
				f_long += drive_cmd * spec.engine_force * 0.6 * (1.0 - rratio) / float(driven_count)
		var brake_force: float = brake_cmd * spec.brake_decel * wheel_mass
		if input_handbrake and not w.front:
			brake_force = maxf(brake_force, spec.brake_decel * wheel_mass * 0.8)
		if drive_cmd == 0.0 and brake_cmd == 0.0 and not input_handbrake:
			brake_force = maxf(brake_force, wheel_mass * 0.9)  # Rollwiderstand / Motorbremse
		if brake_force > 0.0:
			var stop_force: float = absf(v_long) * wheel_mass / delta
			f_long -= signf(v_long) * minf(brake_force, stop_force)
		var max_long: float = grip * 1.2 * maxf(f_susp, wheel_mass * 4.0)
		f_long = clampf(f_long, -max_long, max_long)
		# Kraftangriff auf Schwerpunkthöhe (verhindert Überschlag durch Querkräfte)
		var apply_at: Vector3 = hit_pos + up * (spec.com_height * 0.85)
		apply_force(wheel_fwd * f_long + wheel_right * f_lat, apply_at - global_position)

	# Luftwiderstand und Aufrichthilfe
	apply_central_force(-linear_velocity * speed_abs * 0.35)
	if _grounded_count >= 2:
		var tilt: Vector3 = up.cross(Vector3.UP)
		apply_torque(tilt * mass * STABILIZE)
		# Leichter Abtrieb für Bodenhaftung bei hoher Geschwindigkeit
		apply_central_force(-up * speed_abs * mass * 0.03)
	else:
		# In der Luft: Rotation dämpfen
		apply_torque(-angular_velocity * mass * 0.4)

	_detect_impacts(delta)
	_update_stuck(delta, speed_abs)
	_prev_velocity = linear_velocity


func _read_player_input() -> void:
	if get_tree().paused or player_ref == null or not player_ref.input_enabled:
		input_throttle = 0.0
		input_brake = 0.0
		input_steer = 0.0
		return
	if player_ref.use_sim_input:
		return  # Tests setzen die Werte direkt
	input_throttle = Input.get_action_strength("move_forward")
	input_brake = Input.get_action_strength("move_back")
	input_steer = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_handbrake = Input.is_action_pressed("handbrake")


func _unhandled_input(event: InputEvent) -> void:
	if driver != Driver.PLAYER or get_tree().paused:
		return
	if event.is_action_pressed("horn"):
		honk()
	elif event.is_action_pressed("lights"):
		set_lights(not lights_on)
	elif event.is_action_pressed("recover_vehicle"):
		var res: Dictionary = try_recover()
		EventBus.notify.emit(str(res.message), "info" if res.ok else "warnung")


func _detect_impacts(_delta: float) -> void:
	var dv: float = (linear_velocity - _prev_velocity).length()
	if dv < IMPACT_THRESHOLD or _damage_cooldown > 0.0:
		return
	_damage_cooldown = 0.15
	var other: Node = null
	for b: Node in get_colliding_bodies():
		other = b
		if b is Vehicle:
			break
	var dmg: float = (dv - IMPACT_THRESHOLD) * 38.0
	apply_damage(dmg)
	AudioManager.play_3d("crash", global_position, clampf(-14.0 + dv * 1.5, -14.0, 4.0), randf_range(0.85, 1.1))
	EventBus.vehicle_collision.emit(self, dv, other)


func apply_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damaged.emit(amount)
	var ratio: float = health / max_health
	_paint_mat.albedo_color = paint_color.lerp(Color(0.12, 0.11, 0.1), clampf((1.0 - ratio) * 0.55, 0.0, 0.55))
	if ratio < 0.35:
		_ensure_smoke()
	if health <= 0.0:
		_destroy()


func repair() -> void:
	health = max_health
	is_destroyed = false
	_paint_mat.albedo_color = paint_color
	if _smoke != null:
		_smoke.emitting = false


func _destroy() -> void:
	is_destroyed = true
	_ensure_smoke()
	_smoke.amount_ratio = 1.0
	set_lights(false)
	set_siren(false)
	if _engine != null:
		_engine.stop()
	destroyed.emit()
	if driver == Driver.PLAYER:
		EventBus.notify.emit("Totalschaden! Der Motor ist hinüber.", "fehler")


func _ensure_smoke() -> void:
	if _smoke != null:
		_smoke.emitting = true
		return
	_smoke = GPUParticles3D.new()
	_smoke.amount = 24
	_smoke.lifetime = 2.2
	_smoke.position = Vector3(0, spec.height * 0.7, -spec.length * 0.35)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	pm.color = Color(0.2, 0.2, 0.2, 0.6)
	_smoke.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.25, 0.25, 0.25, 0.5)
	quad.material = sm
	_smoke.draw_pass_1 = quad
	add_child(_smoke)
	_smoke.emitting = true


func _update_stuck(delta: float, speed_abs: float) -> void:
	if (input_throttle > 0.3 or input_brake > 0.3) and speed_abs < 0.6:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)


func is_flipped() -> bool:
	return global_basis.y.dot(Vector3.UP) < 0.35


func get_stuck_time() -> float:
	return _stuck_time


# ---------------------------------------------------------------- Darstellung

func _process(delta: float) -> void:
	if spec == null:
		return
	var fwd_speed: float = get_forward_speed()
	for w: Dictionary in _wheels:
		var pivot: Node3D = w.pivot
		var target_y: float = (w.mount as Vector3).y - spec.rest_length + float(w.compression)
		pivot.position.y = lerpf(pivot.position.y, target_y, clampf(delta * 20.0, 0.0, 1.0))
		w.spin = wrapf(float(w.spin) + fwd_speed / spec.wheel_radius * delta, -TAU, TAU)
		if input_handbrake and not w.front and absf(fwd_speed) > 1.0:
			pass  # blockiertes Rad: Drehung einfrieren
		else:
			pivot.rotation = Vector3(-float(w.spin), _steer_angle if w.front else 0.0, 0.0)
	# Bremslicht
	if _rear_lights_mi != null:
		if _braking_visual:
			_rear_lights_mi.material_override = _mat_brake
		elif lights_on:
			_rear_lights_mi.material_override = _mat_rear_on
		else:
			_rear_lights_mi.material_override = null
	# Blaulicht
	if siren_on and not _beacons.is_empty():
		_beacon_t += delta
		var phase: bool = fmod(_beacon_t, 0.5) < 0.25
		_beacons[0].material_override = _mat_beacon_on if phase else null
		_beacons[1].material_override = null if phase else _mat_beacon_on
		if _beacon_light != null:
			_beacon_light.light_energy = 3.0 if phase else 1.2
	_audio_check -= delta
	if _audio_check <= 0.0:
		_audio_check = 0.25
		_update_engine_audio()
	if _engine != null and _engine.playing:
		var ratio: float = clampf(absf(fwd_speed) / spec.max_speed, 0.0, 1.0)
		var gear_ratio: float = fmod(ratio * 4.0, 1.0) * 0.5 + ratio * 0.6
		_engine.pitch_scale = spec.engine_pitch * (0.7 + gear_ratio + input_throttle * 0.12)
		_engine.volume_db = lerpf(_engine.volume_db, -16.0 + input_throttle * 6.0 + ratio * 4.0, clampf(delta * 5.0, 0.0, 1.0))


func _update_engine_audio() -> void:
	if _engine == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var near: bool = cam != null and cam.global_position.distance_to(global_position) < 55.0
	var should_play: bool = near and not is_destroyed and (driver != Driver.NONE)
	if should_play and not _engine.playing:
		_engine.stream = AudioManager.get_stream(spec.engine_sound, true)
		if _engine.stream != null:
			_engine.play()
	elif not should_play and _engine.playing:
		_engine.stop()


func set_lights(on: bool) -> void:
	lights_on = on and not is_destroyed
	if _front_lights_mi != null:
		_front_lights_mi.material_override = _mat_front_on if lights_on else null
	var want_spots: bool = lights_on and (driver == Driver.PLAYER or ownership == Ownership.POLICE)
	if want_spots and _spots.is_empty():
		var model: Dictionary = VehicleModelBuilder.get_model(spec)
		for sx: float in [-1.0, 1.0]:
			var sl := SpotLight3D.new()
			sl.position = Vector3(sx * (spec.width * 0.5 - 0.3), float(model.front_light_y), -spec.length * 0.5 - 0.05)
			sl.spot_range = 38.0
			sl.spot_angle = 32.0
			sl.light_energy = 3.5
			sl.light_color = Color(1.0, 0.95, 0.85)
			sl.shadow_enabled = false
			add_child(sl)
			_spots.append(sl)
	for s: SpotLight3D in _spots:
		s.visible = want_spots


func set_siren(on: bool) -> void:
	siren_on = on and not is_destroyed
	if not siren_on:
		for b: MeshInstance3D in _beacons:
			b.material_override = null
	if siren_on and _beacon_light == null and not _beacons.is_empty():
		_beacon_light = OmniLight3D.new()
		_beacon_light.light_color = Color(0.25, 0.45, 1.0)
		_beacon_light.omni_range = 14.0
		_beacon_light.position = Vector3(0, spec.height + 0.3, 0.25)
		add_child(_beacon_light)
	if _beacon_light != null:
		_beacon_light.visible = siren_on
	if _siren != null:
		if siren_on and not _siren.playing:
			_siren.stream = AudioManager.get_stream("siren", true)
			if _siren.stream != null:
				_siren.play()
		elif not siren_on:
			_siren.stop()


func honk() -> void:
	AudioManager.play_3d("horn", global_position, 0.0)
	EventBus.horn.emit(global_position)


# ---------------------------------------------------------------- Ein-/Ausstieg

func set_controls(throttle: float, brake: float, steer: float, handbrake: bool) -> void:
	input_throttle = clampf(throttle, 0.0, 1.0)
	input_brake = clampf(brake, 0.0, 1.0)
	input_steer = clampf(steer, -1.0, 1.0)
	input_handbrake = handbrake


func get_forward_speed() -> float:
	return linear_velocity.dot(-global_basis.z)


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func get_camera_params() -> Vector2:
	return Vector2(spec.camera_distance, spec.camera_height)


func _door_points() -> Array[Vector3]:
	var hw: float = spec.width * 0.5 + 0.55
	var z: float = -spec.wheelbase * 0.12
	return [global_transform * Vector3(-hw, 0.3, z), global_transform * Vector3(hw, 0.3, z)]


func distance_to_door(pos: Vector3) -> float:
	var best: float = INF
	for p: Vector3 in _door_points():
		best = minf(best, Vector2(p.x - pos.x, p.z - pos.z).length())
	return best


func can_enter(p: Player) -> bool:
	if p == null or p.is_in_vehicle() or locked or is_destroyed:
		return false
	if driver == Driver.PLAYER:
		return false
	if driver == Driver.AI and linear_velocity.length() > 2.5:
		return false
	return true


func get_enter_text(_p: Player) -> String:
	match ownership:
		Ownership.TRAFFIC:
			return "Fahrzeug übernehmen (wird gemeldet)"
		Ownership.PARKED_FOREIGN:
			return "Fahrzeug übernehmen"
		Ownership.POLICE:
			return "Streifenwagen stehlen (wird gemeldet)"
		Ownership.MISSION:
			return "Einsteigen (%s)" % spec.display_name
		_:
			return "Einsteigen (%s)" % spec.display_name


func enter(p: Player) -> void:
	if not can_enter(p):
		return
	var was_ai: bool = driver == Driver.AI
	if was_ai:
		ai_controller = null
		EventBus.crime_reported.emit("fahrzeugraub", global_position, true)
		_on_driver_ejected()
	elif ownership == Ownership.PARKED_FOREIGN:
		EventBus.crime_reported.emit("fahrzeugdiebstahl", global_position, false)
	elif ownership == Ownership.POLICE:
		EventBus.crime_reported.emit("streifenwagen", global_position, true)
	if ownership != Ownership.MISSION:
		ownership = Ownership.PUBLIC
	player_ref = p
	driver = Driver.PLAYER
	input_handbrake = false
	sleeping = false
	continuous_cd = true
	p.attach_to_vehicle(self)
	AudioManager.play_3d("door", global_position, -4.0)
	driver_changed.emit(driver)
	if _engine != null:
		_audio_check = 0.0


## Fahrer (KI) wird herausgezogen – NPC-System erzeugt einen flüchtenden Passanten.
func _on_driver_ejected() -> void:
	var g: Node = get_tree().current_scene
	if g != null and g.has_method("on_driver_ejected"):
		g.call("on_driver_ejected", self)


## Prüft Ausstiegsmöglichkeiten. Rückgabe: { ok, reason }
func request_exit(p: Player) -> Dictionary:
	if linear_velocity.length() > EXIT_MAX_SPEED:
		return {"ok": false, "reason": "Zu schnell zum Aussteigen – erst abbremsen."}
	var exit_info: Dictionary = find_exit_position()
	if not exit_info.ok:
		return {"ok": false, "reason": "Kein Platz zum Aussteigen."}
	driver = Driver.NONE
	player_ref = null
	continuous_cd = false
	set_controls(0.0, 0.0, 0.0, true)
	p.detach_from_vehicle(exit_info.position, exit_info.yaw)
	AudioManager.play_3d("door", global_position, -4.0)
	driver_changed.emit(driver)
	return {"ok": true, "reason": ""}


## Sucht eine freie, begehbare Ausstiegsposition (Fahrerseite zuerst).
func find_exit_position() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hw: float = spec.width * 0.5 + 0.7
	var hl: float = spec.length * 0.5 + 0.9
	var locals: Array[Vector3] = [
		Vector3(-hw, 0, -spec.wheelbase * 0.12), Vector3(hw, 0, -spec.wheelbase * 0.12),
		Vector3(0, 0, hl), Vector3(0, 0, -hl), Vector3(-hw, 0, spec.wheelbase * 0.3), Vector3(hw, 0, spec.wheelbase * 0.3),
	]
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.75
	var center: Vector3 = global_position + global_basis.y * 0.9
	for lp: Vector3 in locals:
		var gp: Vector3 = global_transform * lp
		# 1) Boden unter dem Punkt?
		var rq := PhysicsRayQueryParameters3D.create(gp + Vector3.UP * 2.0, gp + Vector3.DOWN * 3.0, Layers.WORLD)
		rq.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(rq)
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			continue
		var ground: Vector3 = hit.position
		if absf(ground.y - global_position.y) > 1.5:
			continue
		# 2) Kein Durchgang durch eine Wand (Sichtlinie Fahrzeugmitte -> Ausstieg)
		var wq := PhysicsRayQueryParameters3D.create(center, ground + Vector3.UP * 0.9, Layers.WORLD)
		wq.exclude = [get_rid()]
		if not space.intersect_ray(wq).is_empty():
			continue
		# 3) Platz für die Spielfigur?
		var sq := PhysicsShapeQueryParameters3D.new()
		sq.shape = capsule
		sq.transform = Transform3D(Basis.IDENTITY, ground + Vector3.UP * 0.95)
		sq.collision_mask = Layers.WORLD | Layers.VEHICLE
		sq.exclude = [get_rid()]
		sq.margin = 0.02
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var away: Vector3 = (ground - global_position)
		var yaw: float = atan2(-away.x, -away.z)
		return {"ok": true, "position": ground + Vector3.UP * 0.02, "yaw": yaw}
	return {"ok": false}


## Gibt den Spieler frei, ohne Prüfung (Neustart/Respawn).
func release_driver() -> void:
	if driver == Driver.PLAYER:
		driver = Driver.NONE
		player_ref = null
		continuous_cd = false
		set_controls(0.0, 0.0, 0.0, true)
		driver_changed.emit(driver)


# ---------------------------------------------------------------- Bergung

## Setzt ein festgefahrenes/umgekipptes Fahrzeug auf einen geprüften Straßenpunkt in der Nähe.
## Fahndung und Missionszustand bleiben unverändert.
func try_recover() -> Dictionary:
	if _recover_cd > 0.0:
		return {"ok": false, "message": "Bergung erst in %d s wieder möglich." % int(ceil(_recover_cd))}
	if linear_velocity.length() > 2.0:
		return {"ok": false, "message": "Bergung nur im Stillstand möglich."}
	if not is_flipped() and _stuck_time < 2.5:
		return {"ok": false, "message": "Fahrzeug ist weder umgekippt noch festgefahren."}
	var target: Dictionary = {"ok": false}
	var g: Node = get_tree().current_scene
	if g != null and g.has_method("find_recovery_point"):
		target = g.call("find_recovery_point", global_position, spec)
	else:
		target = {"ok": true, "position": global_position + Vector3.UP * 0.6, "yaw": global_rotation.y}
	if not target.ok:
		return {"ok": false, "message": "Keine sichere Position in der Nähe gefunden."}
	if not is_space_free(target.position, target.yaw):
		return {"ok": false, "message": "Bergungspunkt ist belegt."}
	teleport_to(target.position, target.yaw)
	_recover_cd = RECOVER_COOLDOWN
	_stuck_time = 0.0
	return {"ok": true, "message": "Fahrzeug geborgen."}


func is_space_free(pos: Vector3, yaw: float) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(spec.width + 0.3, spec.height * 0.8, spec.length + 0.4)
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = box
	sq.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * (spec.height * 0.5 + 0.15))
	sq.collision_mask = Layers.WORLD | Layers.VEHICLE
	sq.exclude = [get_rid()]
	return space.intersect_shape(sq, 1).is_empty()


func teleport_to(pos: Vector3, yaw: float) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * 0.1)
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	reset_physics_interpolation()
	sleeping = false
