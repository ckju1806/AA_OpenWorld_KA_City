class_name Player
extends CharacterBody3D
## Spielfigur: Gehen/Rennen/Springen, Stufensteigen (Bordsteine), Lebenspunkte,
## Interaktion (E) und Fahrzeugwechsel (F). Kamera-relativ gesteuert.

signal health_changed(value: float, max_value: float)
signal died(cause: String)

const WALK_SPEED: float = 3.4
const SPRINT_SPEED: float = 7.2
const GROUND_ACCEL: float = 16.0
const AIR_ACCEL: float = 3.5
const JUMP_VELOCITY: float = 5.4
const GRAVITY_MULT: float = 1.8
const MAX_HEALTH: float = 100.0
const STEP_HEIGHT: float = 0.38
const VEHICLE_ENTER_RADIUS: float = 3.2
const FALL_DAMAGE_SPEED: float = 11.0
const REGEN_DELAY: float = 6.0
const REGEN_RATE: float = 2.5

var health: float = MAX_HEALTH
var camera_rig: Node3D = null            ## PlayerCamera
var current_vehicle: Node3D = null       ## Vehicle
var rig: HumanoidRig
var input_enabled: bool = true
var is_dead: bool = false

## Teststeuerung (ersetzt Tastatur, wenn use_sim_input = true)
var use_sim_input: bool = false
var sim_move: Vector2 = Vector2.ZERO
var sim_sprint: bool = false
var sim_jump: bool = false

var _gravity: float = 9.8
var _knockdown: float = 0.0
var _since_damage: float = 99.0
var _interact_target: Node3D = null
var _vehicle_target: Node3D = null
var _scan_timer: float = 0.0
var _last_hint: String = ""
var _air_time: float = 0.0
var _max_fall_speed: float = 0.0
var _collision: CollisionShape3D
var _hit_area: Area3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.PLAYER_MASK
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	safe_margin = 0.02
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * GRAVITY_MULT
	_collision = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.8
	_collision.shape = cap
	_collision.position = Vector3(0, 0.9, 0)
	add_child(_collision)
	_hit_area = Area3D.new()
	_hit_area.name = "Trefferzone"
	_hit_area.collision_layer = 0
	_hit_area.collision_mask = Layers.VEHICLE
	var hs := CollisionShape3D.new()
	var hcap := CapsuleShape3D.new()
	hcap.radius = 0.42
	hcap.height = 1.8
	hs.shape = hcap
	hs.position = Vector3(0, 0.9, 0)
	_hit_area.add_child(hs)
	add_child(_hit_area)
	_hit_area.body_entered.connect(_on_vehicle_touch)
	rig = HumanoidRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build({
		"skin": Color(0.86, 0.68, 0.55),
		"shirt": Color(0.78, 0.36, 0.16),
		"jacket": Color(0.16, 0.18, 0.22),
		"pants": Color(0.2, 0.24, 0.34),
		"shoes": Color(0.92, 0.92, 0.9),
		"hair": Color(0.12, 0.09, 0.07),
		"hair_style": 0,
	})
	EventBus.player_spawned.emit(self)


func is_in_vehicle() -> bool:
	return current_vehicle != null


func _physics_process(delta: float) -> void:
	_since_damage += delta
	if not is_dead and health < MAX_HEALTH and _since_damage > REGEN_DELAY:
		set_health(minf(MAX_HEALTH, health + REGEN_RATE * delta))
	if is_in_vehicle():
		return
	_move(delta)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.1
		_update_targets()


func _move(delta: float) -> void:
	var move2: Vector2 = Vector2.ZERO
	var sprint: bool = false
	var jump: bool = false
	var controllable: bool = input_enabled and not is_dead and _knockdown <= 0.0
	if controllable:
		if use_sim_input:
			move2 = sim_move.limit_length(1.0)
			sprint = sim_sprint
			jump = sim_jump
			sim_jump = false
		elif not get_tree().paused:
			move2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			sprint = Input.is_action_pressed("sprint")
			jump = Input.is_action_just_pressed("jump")
	_knockdown = maxf(0.0, _knockdown - delta)

	var yaw: float = 0.0
	if camera_rig != null:
		yaw = float(camera_rig.get("yaw"))
	var dir: Vector3 = Vector3(move2.x, 0, move2.y).rotated(Vector3.UP, yaw)
	var target_speed: float = SPRINT_SPEED if sprint else WALK_SPEED
	var target_vel: Vector3 = dir * target_speed
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var hv: Vector3 = Vector3(velocity.x, 0, velocity.z)
	hv = hv.move_toward(target_vel, accel * target_speed * delta * 0.5 + accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if is_on_floor():
		if _air_time > 0.25 and _max_fall_speed > FALL_DAMAGE_SPEED:
			take_damage((_max_fall_speed - FALL_DAMAGE_SPEED) * 9.0, "Sturz")
		_air_time = 0.0
		_max_fall_speed = 0.0
		if jump:
			velocity.y = JUMP_VELOCITY
			AudioManager.play_3d("jump", global_position, -8.0)
	else:
		_air_time += delta
		velocity.y -= _gravity * delta
		_max_fall_speed = maxf(_max_fall_speed, -velocity.y)

	var pre_vel: Vector3 = velocity
	move_and_slide()
	if dir.length() > 0.1 and is_on_floor():
		_try_step_up(Vector3(pre_vel.x, 0, pre_vel.z) * delta)

	# Blickrichtung zur Bewegung drehen
	if hv.length() > 0.3:
		var target_yaw: float = atan2(-hv.x, -hv.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 12.0, 0.0, 1.0))

	# Animation
	var speed: float = hv.length()
	var p: HumanoidRig.Pose = HumanoidRig.Pose.IDLE
	if is_dead or _knockdown > 0.0:
		p = HumanoidRig.Pose.DOWN
	elif not is_on_floor():
		p = HumanoidRig.Pose.JUMP if velocity.y > -2.0 else HumanoidRig.Pose.FALL
	elif speed > 4.5:
		p = HumanoidRig.Pose.RUN
	elif speed > 0.4:
		p = HumanoidRig.Pose.WALK
	rig.animate(delta, speed, p)
	_footsteps(delta, speed)


var _step_acc: float = 0.0


func _footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or speed < 0.5:
		_step_acc = 0.0
		return
	_step_acc += delta * speed
	var stride: float = 1.1 if speed > 4.5 else 0.75
	if _step_acc > stride:
		_step_acc = 0.0
		AudioManager.play_3d("step", global_position, -14.0 if speed < 4.5 else -9.0, randf_range(0.9, 1.1))


## Stufensteigen: niedrige Hindernisse (Bordsteine, Treppenstufen) automatisch überwinden.
func _try_step_up(motion_h: Vector3) -> void:
	if motion_h.length() < 0.001:
		return
	var blocked_low: bool = false
	for i: int in get_slide_collision_count():
		var col: KinematicCollision3D = get_slide_collision(i)
		var n: Vector3 = col.get_normal()
		# kein begehbarer Boden (Kante trifft die abgerundete Kapsel schräg)
		if n.y < cos(floor_max_angle) + 0.02:
			var h: float = col.get_position().y - global_position.y
			if h < STEP_HEIGHT + 0.05:
				blocked_low = true
	if not blocked_low:
		return
	var up: Vector3 = Vector3.UP * STEP_HEIGHT
	var t: Transform3D = global_transform
	if test_move(t, up):
		return
	var t_up: Transform3D = t.translated(up)
	var fwd: Vector3 = motion_h.normalized() * maxf(motion_h.length(), 0.12)
	if test_move(t_up, fwd):
		return
	var t_fwd: Transform3D = t_up.translated(fwd)
	var col2 := KinematicCollision3D.new()
	if test_move(t_fwd, -up * 1.05, col2):
		var new_pos: Vector3 = t_fwd.origin + col2.get_travel()
		if new_pos.y > global_position.y + 0.02 and col2.get_normal().y > 0.7:
			global_position = new_pos


func _unhandled_input(event: InputEvent) -> void:
	if is_dead or not input_enabled or use_sim_input:
		return
	if event.is_action_pressed("enter_exit"):
		toggle_vehicle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not is_in_vehicle():
		if _interact_target != null and is_instance_valid(_interact_target):
			_interact_target.call("interact", self)
			_scan_timer = 0.0
			get_viewport().set_input_as_handled()


## F: Einsteigen/Aussteigen. Rückgabe: Erfolg.
func toggle_vehicle() -> bool:
	if is_in_vehicle():
		var res: Dictionary = current_vehicle.call("request_exit", self)
		if not res.get("ok", false):
			EventBus.notify.emit(str(res.get("reason", "Aussteigen nicht möglich.")), "warnung")
			return false
		return true
	if _vehicle_target == null:
		_update_targets()
	if _vehicle_target != null and is_instance_valid(_vehicle_target):
		_vehicle_target.call("enter", self)
		return true
	return false


## Wird vom Fahrzeug beim Einsteigen aufgerufen.
func attach_to_vehicle(v: Node3D) -> void:
	current_vehicle = v
	velocity = Vector3.ZERO
	_collision.disabled = true
	_hit_area.set_deferred("monitoring", false)
	rig.visible = false
	_set_hint("")
	if camera_rig != null:
		camera_rig.call("follow_vehicle", v)
	EventBus.player_entered_vehicle.emit(v)


## Wird vom Fahrzeug beim Aussteigen aufgerufen (Position bereits geprüft).
func detach_from_vehicle(exit_pos: Vector3, facing_yaw: float) -> void:
	var v: Node3D = current_vehicle
	current_vehicle = null
	global_position = exit_pos
	rotation = Vector3(0, facing_yaw, 0)
	velocity = Vector3.ZERO
	_collision.disabled = false
	_hit_area.set_deferred("monitoring", true)
	rig.visible = true
	reset_physics_interpolation()
	if camera_rig != null:
		camera_rig.call("follow_player", self)
	EventBus.player_exited_vehicle.emit(v)


## Verlässt ein Fahrzeug ohne Prüfung (z. B. bei Neustart/Respawn).
func force_leave_vehicle(pos: Vector3) -> void:
	if current_vehicle != null and is_instance_valid(current_vehicle) and current_vehicle.has_method("release_driver"):
		current_vehicle.call("release_driver")
	current_vehicle = null
	_collision.disabled = false
	_hit_area.set_deferred("monitoring", true)
	rig.visible = true
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if camera_rig != null:
		camera_rig.call("follow_player", self)


func _update_targets() -> void:
	if is_in_vehicle() or is_dead:
		_interact_target = null
		_vehicle_target = null
		_set_hint("")
		return
	_interact_target = Interactables.find_best(self)
	_vehicle_target = _find_vehicle()
	var hint: String = ""
	if _interact_target != null:
		hint = "[E] " + str(_interact_target.call("get_interaction_text", self))
	if _vehicle_target != null:
		var vt: String = "[F] " + str(_vehicle_target.call("get_enter_text", self))
		hint = vt if hint == "" else hint + "     " + vt
	_set_hint(hint)


func _find_vehicle() -> Node3D:
	var best: Node3D = null
	var best_d: float = VEHICLE_ENTER_RADIUS
	for v: Node3D in get_tree().get_nodes_in_group("vehicles"):
		var d: float = v.global_position.distance_to(global_position)
		if d < best_d + 2.0 and bool(v.call("can_enter", self)):
			var dd: float = float(v.call("distance_to_door", global_position))
			if dd < best_d:
				best_d = dd
				best = v
	return best


func _set_hint(text: String) -> void:
	if text != _last_hint:
		_last_hint = text
		EventBus.context_hint.emit(text)


func refresh_hint() -> void:
	_last_hint = "#"
	_scan_timer = 0.0


func set_health(v: float) -> void:
	health = clampf(v, 0.0, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: float, cause: String = "") -> void:
	if is_dead or amount <= 0.0:
		return
	_since_damage = 0.0
	set_health(health - amount)
	if health <= 0.0:
		die(cause)


func _on_vehicle_touch(body: Node3D) -> void:
	if is_in_vehicle() or is_dead or not body is Vehicle or body == current_vehicle:
		return
	var v: Vehicle = body as Vehicle
	var vel: Vector3 = v.linear_velocity
	var spd: float = vel.length()
	if spd < 2.5:
		# Langsames Fahrzeug schiebt den Spieler nur zur Seite
		var push: Vector3 = global_position - v.global_position
		push.y = 0.0
		velocity += push.normalized() * 2.0
		return
	knock_down(vel * 0.45, (spd - 2.5) * 7.0)
	AudioManager.play_3d("crash", global_position, -6.0, 1.3)


## Umgestoßen werden (z. B. von einem Fahrzeug erfasst).
func knock_down(impulse: Vector3, damage: float) -> void:
	if is_in_vehicle() or is_dead:
		return
	velocity = impulse + Vector3.UP * 3.0
	_knockdown = 1.4
	take_damage(damage, "Unfall")


func die(cause: String) -> void:
	if is_dead:
		return
	is_dead = true
	health = 0.0
	health_changed.emit(health, MAX_HEALTH)
	_set_hint("")
	died.emit(cause)
	EventBus.player_died.emit(cause)


func revive(pos: Vector3, yaw: float) -> void:
	if is_in_vehicle():
		force_leave_vehicle(pos)
	is_dead = false
	_knockdown = 0.0
	set_health(MAX_HEALTH)
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	_air_time = 0.0
	_max_fall_speed = 0.0
	reset_physics_interpolation()
	refresh_hint()
