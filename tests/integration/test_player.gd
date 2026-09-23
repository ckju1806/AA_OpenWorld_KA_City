extends TestCase
## Spielfigur auf dem Testgelände: Bodenhaftung, Bewegung, Bordstein, Sprung, Kamera.

var game: Game


func before_each() -> void:
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate() as Game
	game.world_mode = "test"
	add_child(game)
	await wait_physics(30)


func after_each() -> void:
	if is_instance_valid(game):
		game.queue_free()
	await wait_physics(2)


func test_player_stands_on_ground() -> void:
	var p: Player = game.player
	assert_true(p != null, "Spieler existiert")
	await wait_seconds(2.0)
	assert_true(p.is_on_floor(), "Spieler steht auf dem Boden")
	assert_near(p.global_position.y, 0.0, 0.15, "Höhe auf Boden")


func test_walk_and_sprint() -> void:
	var p: Player = game.player
	p.use_sim_input = true
	var start: Vector3 = p.global_position
	p.sim_move = Vector2(0, -1)
	await wait_seconds(2.0)
	var walked: float = start.distance_to(p.global_position)
	assert_gt(walked, 5.0, "Gehstrecke in 2 s")
	var mid: Vector3 = p.global_position
	p.sim_sprint = true
	await wait_seconds(2.0)
	var sprinted: float = mid.distance_to(p.global_position)
	assert_gt(sprinted, walked * 1.6, "Sprinten schneller als Gehen")
	p.sim_move = Vector2.ZERO
	p.sim_sprint = false


func test_step_up_curb() -> void:
	var p: Player = game.player
	p.use_sim_input = true
	p.sim_move = Vector2(1, 0)  # nach rechts (+X) zum Gehweg (Bordstein 0,12 m bei x = 7)
	await wait_seconds(3.5)
	p.sim_move = Vector2.ZERO
	await wait_seconds(0.5)
	assert_gt(p.global_position.x, 7.5, "Spieler hat den Bordstein überquert")
	assert_near(p.global_position.y, 0.12, 0.08, "Spieler steht auf dem Gehweg")


func test_jump() -> void:
	var p: Player = game.player
	p.use_sim_input = true
	await wait_seconds(0.5)
	var y0: float = p.global_position.y
	p.sim_jump = true
	await wait_seconds(0.25)
	assert_gt(p.global_position.y, y0 + 0.4, "Sprunghöhe")
	await wait_seconds(1.5)
	assert_true(p.is_on_floor(), "Nach Sprung wieder am Boden")


func test_damage_and_revive() -> void:
	var p: Player = game.player
	p.take_damage(30.0, "Test")
	assert_near(p.health, 70.0, 0.01, "Schaden")
	p.take_damage(500.0, "Test")
	assert_true(p.is_dead, "Tot bei 0 LP")
	p.revive(Vector3(0, 0.2, 0), 0.0)
	assert_false(p.is_dead, "Wiederbelebt")
	assert_near(p.health, Player.MAX_HEALTH, 0.01, "Volle LP nach Wiederbelebung")


func test_camera_follows_and_avoids_walls() -> void:
	var p: Player = game.player
	var cam: Camera3D = game.camera_rig.get_camera()
	await wait_physics(10)
	assert_lt(cam.global_position.distance_to(p.global_position), 6.0, "Kamera nahe am Spieler")
	# Spieler an die Wand stellen, Kamera zur Wand drehen -> Kamera darf nicht in der Wand stecken
	p.global_position = Vector3(11.5, 0.2, 0)
	game.camera_rig.yaw = PI * 0.5  # Kamera auf +X-Seite (Richtung Wand bei x = 12)
	game.camera_rig.snap()
	await wait_physics(20)
	assert_lt(cam.global_position.x, 12.0, "Kamera vor der Wandfläche (x = 12)")
