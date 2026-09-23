extends TestCase
## Fahrzeugdaten: Vollständigkeit, Plausibilität, unterscheidbare Fahrparameter.


func test_catalog_loads_required_types() -> void:
	var cat: Dictionary = VehicleSpec.load_catalog()
	for id: String in ["kompakt", "sport", "transporter", "polizei", "limousine"]:
		assert_true(cat.has(id), "Fahrzeugtyp fehlt: " + id)


func test_all_specs_valid() -> void:
	for s: VehicleSpec in VehicleSpec.load_catalog().values():
		var errs: Array[String] = s.validate()
		assert_true(errs.is_empty(), "Ungültige Spezifikation: " + ", ".join(errs))
		assert_gt(s.mount_height(), s.wheel_radius, "%s: Aufhängungspunkt über Radmitte" % s.id)


func test_types_differ_in_handling() -> void:
	var k: VehicleSpec = VehicleSpec.get_spec("kompakt")
	var s: VehicleSpec = VehicleSpec.get_spec("sport")
	var t: VehicleSpec = VehicleSpec.get_spec("transporter")
	assert_gt(s.max_speed, k.max_speed, "Sportwagen schneller als Kompakt")
	assert_gt(k.max_speed, t.max_speed, "Kompakt schneller als Transporter")
	assert_gt(s.engine_force / s.mass, t.engine_force / t.mass, "Sportwagen beschleunigt stärker")
	assert_gt(t.mass, k.mass, "Transporter schwerer")


func test_unknown_spec_falls_back() -> void:
	var s: VehicleSpec = VehicleSpec.get_spec("gibt_es_nicht")
	assert_eq(s.id, "kompakt", "Fallback auf Kompaktwagen")
