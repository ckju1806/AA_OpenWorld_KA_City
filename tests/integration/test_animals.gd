extends GameTestCase
## Tiere (W6): Zoo-Tiere erscheinen bei Annäherung und bleiben im Gehege, Vögel fliegen bei Hupe auf,
## Obergrenze, Abbau beim Entfernen, Einstellung „Tiere“ = 0 entfernt alle.


func before_each() -> void:
	await start_city_game()
	game.animals.enabled = true


func after_each() -> void:
	Settings.animal_density = 1.0
	await stop_game()


func _zoo() -> Dictionary:
	for lm: Variant in city().graph.layout.landmarks:
		if str(lm.type) == "zoo":
			return lm
	return {}


func test_zoo_animals_stay_in_enclosures() -> void:
	var lm: Dictionary = _zoo()
	assert_false(lm.is_empty(), "Zoo-Landmarke vorhanden")
	var c: Vector3 = Vector3(float(lm.pos[0]), 0.2, float(lm.pos[1]) + 300.0)
	teleport_player(c)
	await wait_physics(60)
	var zoo: Array[AnimalAgent] = game.animals.zoo_animals
	assert_gt(float(zoo.size()), 20.0, "Zoo-Tiere erzeugt (%d)" % zoo.size())
	var species: Dictionary = {}
	for a: AnimalAgent in zoo:
		species[a.sid] = true
	assert_gt(float(species.size()), 8.0, "Mindestens 9 Arten im Zoo")
	await wait_seconds(20.0)
	var outside: int = 0
	for a2: AnimalAgent in zoo:
		if not a2.in_area(Vector2(a2.global_position.x, a2.global_position.z)):
			outside += 1
	assert_eq(outside, 0, "Alle Zoo-Tiere in ihren Gehegen")
	# weit weg -> Zoo-Tiere abgebaut
	teleport_player(Vector3(3000, 0.2, 0))
	await wait_physics(60)
	assert_eq(game.animals.zoo_animals.size(), 0, "Zoo-Tiere entfernt")


func test_birds_fly_off_on_horn_and_cap() -> void:
	var a := AnimalAgent.new()
	a.setup("taube", 3)
	a.area_kind = "circle"
	a.area_center = Vector2(game.player.global_position.x + 8.0, game.player.global_position.z)
	a.area_half = Vector2(6, 6)
	game.animals._root.add_child(a)
	a.global_position = Vector3(a.area_center.x, 0.12, a.area_center.y)
	game.animals.animals.append(a)
	EventBus.horn.emit(a.global_position + Vector3(3, 0, 0))
	assert_eq(a.state, AnimalAgent.State.FLY, "Taube fliegt bei Hupe auf")
	var y0: float = a.global_position.y
	await wait_seconds(1.5)
	if is_instance_valid(a):
		assert_gt(a.global_position.y, y0 + 1.0, "Taube steigt auf")
	assert_true(game.animals.count() <= game.animals.cap() + 1, "Obergrenze eingehalten")


func test_density_zero_removes_all() -> void:
	var lm: Dictionary = _zoo()
	teleport_player(Vector3(float(lm.pos[0]), 0.2, float(lm.pos[1]) + 300.0))
	await wait_physics(40)
	Settings.animal_density = 0.0
	await wait_physics(60)
	assert_eq(game.animals.count(), 0, "Keine Tiere bei Dichte 0")
