class_name EnvironmentSetup
extends Node3D
## Licht, Himmel und Wetter nach Spielzeit (WorldClock): Sonne/Mond mit Stand nach Uhrzeit, Himmelsfarben
## (Nacht, Dämmerung, Tag, bedeckt), Nebel, Regen (Partikel um die Kamera, nasse Straßen), Laternen und
## erleuchtete Fenster bei Dunkelheit, qualitätsabhängige Schatten/SSAO/SSIL/Volumennebel.

const LAMP_LIGHTS: int = 18

var sun: DirectionalLight3D
var fill: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var rain_fx: GPUParticles3D
var lamp_positions: PackedVector3Array = PackedVector3Array()
var _pool: Array[OmniLight3D] = []
var _timer: float = 0.0
var _env_timer: float = 0.0
var _last_night: float = -1.0
var _last_wet: float = -1.0

# Farbstützstellen: [Himmel oben, Horizont, Sonnenlicht, Nebel, Umgebungslicht]
const C_NIGHT: Array = [Color(0.015, 0.02, 0.05), Color(0.06, 0.07, 0.12), Color(0.45, 0.55, 0.85), Color(0.05, 0.06, 0.1), Color(0.2, 0.24, 0.36)]
const C_DUSK: Array = [Color(0.27, 0.34, 0.58), Color(1.0, 0.62, 0.38), Color(1.0, 0.66, 0.44), Color(0.93, 0.66, 0.5), Color(0.62, 0.55, 0.5)]
const C_DAY: Array = [Color(0.2, 0.42, 0.8), Color(0.66, 0.78, 0.9), Color(1.0, 0.97, 0.9), Color(0.72, 0.8, 0.9), Color(0.6, 0.66, 0.72)]
const C_OVERCAST: Array = [Color(0.46, 0.49, 0.54), Color(0.64, 0.66, 0.68), Color(0.85, 0.87, 0.9), Color(0.6, 0.62, 0.65), Color(0.6, 0.62, 0.66)]


func setup(lamps: PackedVector3Array) -> void:
	lamp_positions = lamps
	sun = DirectionalLight3D.new()
	sun.name = "Sonne"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.name = "Himmelslicht"
	fill.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(60.0), 0.0)
	fill.light_color = Color(0.55, 0.6, 0.85)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.55, 0.4, 0.35)
	sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.14)
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	env.volumetric_fog_density = 0.01
	env.volumetric_fog_length = 120.0
	world_env.environment = env
	add_child(world_env)
	for i: int in LAMP_LIGHTS:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.5)
		l.light_energy = 1.3
		l.omni_range = 13.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)
	_make_rain()
	apply_quality()
	Settings.changed.connect(apply_quality)
	update_environment(true)


func _make_rain() -> void:
	rain_fx = GPUParticles3D.new()
	rain_fx.name = "Regen"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(38.0, 1.0, 38.0)
	pm.direction = Vector3(0.08, -1.0, 0.03)
	pm.spread = 3.0
	pm.initial_velocity_min = 16.0
	pm.initial_velocity_max = 20.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.particle_flag_align_y = true
	rain_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.7)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.8, 0.9, 0.32)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	q.material = m
	rain_fx.draw_pass_1 = q
	rain_fx.lifetime = 1.6
	rain_fx.visibility_aabb = AABB(Vector3(-45, -40, -45), Vector3(90, 50, 90))
	rain_fx.emitting = false
	rain_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain_fx)


func apply_quality() -> void:
	if sun == null:
		return
	var q: int = Settings.level()
	sun.shadow_enabled = Settings.shadows > 0
	sun.directional_shadow_max_distance = maxf(Settings.shadow_distance(), 1.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if Settings.shadows <= 1 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	var env: Environment = world_env.environment
	env.ssao_enabled = Settings.ssao
	env.ssil_enabled = Settings.ssil
	env.sdfgi_enabled = false
	env.glow_enabled = Settings.glow
	env.volumetric_fog_enabled = Settings.volumetric_fog
	rain_fx.amount = [900, 1800, 3200, 5000][q]
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.far = Settings.view_distance() + 300.0
		cam.fov = Settings.fov


func _process(delta: float) -> void:
	_env_timer -= delta
	if _env_timer <= 0.0:
		_env_timer = 0.1
		update_environment(false)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and rain_fx.emitting:
		rain_fx.global_position = cam.global_position + Vector3(0, 22.0, 0) - cam.global_basis.z * 12.0
	_timer -= delta
	if _timer > 0.0 or lamp_positions.is_empty():
		return
	_timer = 0.4
	_update_lamp_pool(cam)


## Sonne, Himmel, Nebel, Materialien aus Uhrzeit und Wetter setzen.
func update_environment(force: bool) -> void:
	if sun == null:
		return
	var el: float = WorldClock.sun_elevation()
	var az: float = WorldClock.sun_azimuth()
	var night: float = WorldClock.night_factor()
	var cloud: float = WorldClock.cloud
	var fogv: float = WorldClock.fog
	# Farben: Nacht -> Dämmerung -> Tag nach Sonnenhöhe, dann Richtung „bedeckt“ nach Bewölkung
	var t_dusk: float = clampf(inverse_lerp(-8.0, 4.0, el), 0.0, 1.0)
	var t_day: float = clampf(inverse_lerp(6.0, 26.0, el), 0.0, 1.0)
	var cols: Array = []
	for i: int in 5:
		var c: Color = (C_NIGHT[i] as Color).lerp(C_DUSK[i], t_dusk).lerp(C_DAY[i], t_day)
		var over: Color = (C_OVERCAST[i] as Color) * lerpf(0.18, 1.0, 1.0 - night)
		cols.append(c.lerp(over, cloud * 0.85))
	sky_mat.sky_top_color = cols[0]
	sky_mat.sky_horizon_color = cols[1]
	sky_mat.ground_horizon_color = (cols[1] as Color).darkened(0.35)
	# Sonne bzw. Mond
	var is_moon: bool = el < -4.0
	var e_rad: float = deg_to_rad(maxf(el, 6.0) if not is_moon else 35.0)
	var a_rad: float = deg_to_rad(az if not is_moon else fposmod(az + 180.0, 360.0))
	var to_sun: Vector3 = Vector3(sin(a_rad) * cos(e_rad), sin(e_rad), -cos(a_rad) * cos(e_rad))
	sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.98 else Vector3.FORWARD)
	sun.light_color = cols[2]
	var e_sun: float = lerpf(0.0, 1.6, clampf(inverse_lerp(-4.0, 10.0, el), 0.0, 1.0)) * lerpf(1.0, 0.3, cloud)
	var e_moon: float = 0.1 * night * lerpf(1.0, 0.4, cloud)
	sun.light_energy = maxf(e_sun, e_moon)
	sun.shadow_opacity = lerpf(1.0, 0.35, cloud)
	fill.light_energy = lerpf(0.18, 0.06, night)
	var env: Environment = world_env.environment
	env.ambient_light_color = cols[4]
	env.ambient_light_energy = lerpf(0.7, 0.35, night) * lerpf(1.0, 1.15, cloud)
	env.fog_light_color = cols[3]
	env.fog_density = lerpf(0.0009, 0.0008, night) + fogv * 0.012 + WorldClock.rain * 0.0025
	env.fog_sun_scatter = lerpf(0.25, 0.02, cloud)
	env.tonemap_exposure = lerpf(1.05, 1.35, night)
	env.volumetric_fog_density = 0.005 + fogv * 0.03
	env.volumetric_fog_albedo = cols[3]
	# Regen
	var raining: bool = WorldClock.rain > 0.15
	if rain_fx.emitting != raining:
		rain_fx.emitting = raining
	# Materialien (nur bei merklicher Änderung)
	if force or absf(night - _last_night) > 0.02:
		_last_night = night
		CityMaterials.set_night(night)
	if force or absf(WorldClock.wetness - _last_wet) > 0.02:
		_last_wet = WorldClock.wetness
		CityMaterials.set_wetness(WorldClock.wetness)


func _update_lamp_pool(cam: Camera3D) -> void:
	if cam == null:
		return
	var night: float = WorldClock.night_factor()
	var on: bool = night > 0.25 or WorldClock.fog > 0.6
	var cp: Vector3 = cam.global_position
	# Die nächsten Laternen bekommen echte Lichtquellen (keine vollständige Sortierung nötig)
	var best: Array[Vector2] = []  # (Distanz², Index)
	var count: int = mini(_pool.size(), [6, 12, 18, 18][Settings.level()]) if on else 0
	for i: int in lamp_positions.size():
		if count == 0:
			break
		var d2: float = lamp_positions[i].distance_squared_to(cp)
		if d2 > 90.0 * 90.0:
			continue
		if best.size() < count:
			best.append(Vector2(d2, i))
			best.sort()
		elif d2 < best[best.size() - 1].x:
			best[best.size() - 1] = Vector2(d2, i)
			best.sort()
	for k: int in _pool.size():
		if k < best.size():
			_pool[k].position = lamp_positions[int(best[k].y)] - Vector3(0, 0.4, 0)
			_pool[k].light_energy = 1.3 * clampf(night * 1.4, 0.3, 1.0)
			_pool[k].visible = true
		else:
			_pool[k].visible = false
