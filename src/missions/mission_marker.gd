class_name MissionMarker
extends Node3D
## Eigenes Zielmarkierungs-Design: Lichtsäule, Bodenring und schwebender Pfeil.
## Typen: ziel (orange), abholung (blau), fahrzeug (grün), kontrollpunkt (weiß), vorschau (blass).

const COLORS: Dictionary = {
	"ziel": Color(0.98, 0.62, 0.22, 0.32),
	"abholung": Color(0.3, 0.64, 1.0, 0.32),
	"fahrzeug": Color(0.42, 0.85, 0.48, 0.3),
	"kontrollpunkt": Color(1.0, 0.95, 0.85, 0.3),
	"vorschau": Color(1.0, 0.95, 0.85, 0.1),
}

var kind: String = "ziel"
var radius: float = 4.0
var follow: Node3D = null
var _arrow: MeshInstance3D
var _t: float = 0.0


func setup(p_kind: String, p_radius: float) -> void:
	kind = p_kind
	radius = p_radius


func _ready() -> void:
	var col: Color = COLORS.get(kind, COLORS.ziel)
	var mat: StandardMaterial3D = MatLib.glow_transparent(col)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9 if kind != "vorschau" else 0.5
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 70.0
	cyl.radial_segments = 12
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	beam.material_override = mat
	beam.position = Vector3(0, 35.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(radius - 0.35, 0.3)
	torus.outer_radius = radius
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = MatLib.glow_transparent(Color(col.r, col.g, col.b, 0.75))
	ring.position = Vector3(0, 0.2, 0)
	ring.scale = Vector3(1, 0.15, 1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	if kind != "vorschau":
		_arrow = MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(1.2, 1.2, 0.35)
		_arrow.mesh = prism
		_arrow.material_override = MatLib.emissive(Color(col.r, col.g, col.b), 2.5)
		_arrow.rotation = Vector3(0, 0, PI)
		_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_arrow)


func _process(delta: float) -> void:
	_t += delta
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	if _arrow != null:
		_arrow.position = Vector3(0, 3.6 + sin(_t * 2.5) * 0.3 + (1.8 if follow != null else 0.0), 0)
		_arrow.rotation.y = _t * 1.5
