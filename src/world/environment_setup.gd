class_name EnvironmentSetup
extends Node3D
## Warme Abendstimmung: tief stehende Sonne im Westen, prozeduraler Himmel, Nebel, Glow,
## qualitätsabhängige Schatten/SSAO und ein Lichtpool für Straßenlaternen (nächste Laternen).

const LAMP_LIGHTS: int = 18

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var lamp_positions: PackedVector3Array = PackedVector3Array()
var _pool: Array[OmniLight3D] = []
var _timer: float = 0.0


func setup(lamps: PackedVector3Array) -> void:
	lamp_positions = lamps
	sun = DirectionalLight3D.new()
	sun.name = "Abendsonne"
	# Sonne tief im Westen (Licht fällt nach Osten), leicht aus Süden
	sun.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(-104.0), 0.0)
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Himmelslicht"
	fill.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(60.0), 0.0)
	fill.light_color = Color(0.55, 0.6, 0.85)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.27, 0.34, 0.58)
	sm.sky_horizon_color = Color(1.0, 0.66, 0.42)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.55, 0.4, 0.35)
	sm.ground_bottom_color = Color(0.15, 0.13, 0.14)
	sm.sun_angle_max = 12.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.62, 0.57, 0.52)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.68, 0.5)
	env.fog_density = 0.0009
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
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
	apply_quality()
	Settings.changed.connect(apply_quality)


func apply_quality() -> void:
	if sun == null:
		return
	var q: int = Settings.quality
	sun.directional_shadow_max_distance = Settings.shadow_distance()
	var env: Environment = world_env.environment
	env.ssao_enabled = q >= 2
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = q >= 1
	for i: int in _pool.size():
		_pool[i].visible = _pool[i].visible and i < (6 if q == 0 else LAMP_LIGHTS)
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		cam.far = Settings.view_distance() + 300.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or lamp_positions.is_empty():
		return
	_timer = 0.4
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp: Vector3 = cam.global_position
	# Die nächsten Laternen bekommen echte Lichtquellen (keine vollständige Sortierung nötig)
	var best: Array[Vector2] = []  # (Distanz², Index)
	var count: int = mini(_pool.size(), 6 if Settings.quality == 0 else LAMP_LIGHTS)
	for i: int in lamp_positions.size():
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
			_pool[k].visible = true
		else:
			_pool[k].visible = false
