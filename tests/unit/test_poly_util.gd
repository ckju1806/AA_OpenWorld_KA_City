extends TestCase
## Polygonhilfen: Fläche, Orientierung, Einrücken pro Kante.


func _square(s: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0, 0), Vector2(s, 0), Vector2(s, s), Vector2(0, s)])


func test_area_and_orientation() -> void:
	var sq: PackedVector2Array = _square(10)
	assert_near(PolyUtil.area(sq), 100.0, 0.001, "Fläche")
	var rev: PackedVector2Array = sq.duplicate()
	rev.reverse()
	assert_true(PolyUtil.signed_area(PolyUtil.ensure_ccw(rev)) > 0.0, "ensure_ccw")


func test_inset_uniform() -> void:
	var sq: PackedVector2Array = PolyUtil.ensure_ccw(_square(10))
	var d: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1])
	var ins: PackedVector2Array = PolyUtil.inset_per_edge(sq, d)
	assert_eq(ins.size(), 4, "Punktanzahl bleibt")
	assert_near(PolyUtil.area(ins), 64.0, 0.01, "Fläche nach 1 m Einrücken")


func test_inset_per_edge() -> void:
	var sq: PackedVector2Array = PolyUtil.ensure_ccw(_square(10))
	var d: PackedFloat32Array = PackedFloat32Array([2, 0, 0, 0])
	var ins: PackedVector2Array = PolyUtil.inset_per_edge(sq, d)
	assert_near(PolyUtil.area(ins), 80.0, 0.01, "Fläche nach einseitigem Einrücken")


func test_inset_collapse_returns_empty() -> void:
	var sq: PackedVector2Array = PolyUtil.ensure_ccw(_square(4))
	var ins: PackedVector2Array = PolyUtil.inset_per_edge(sq, PackedFloat32Array([3, 3, 3, 3]))
	assert_eq(ins.size(), 0, "Zu starkes Einrücken -> leer")


func test_polar() -> void:
	var p: Vector2 = PolyUtil.polar(Vector2.ZERO, 100.0, 0.0)
	assert_near(p.y, 100.0, 0.001, "0 Grad = Süden (+Z)")
	var e: Vector2 = PolyUtil.polar(Vector2.ZERO, 100.0, 90.0)
	assert_near(e.x, 100.0, 0.001, "90 Grad = Osten (+X)")
