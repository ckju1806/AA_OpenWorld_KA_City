extends TestCase
## Zufallsereignisse sind Raten pro Sekunde – unabhängig von der Bildrate (Befund: vorher Wahrscheinlichkeit je Bild).


func _count(rate: float, hz: float, seconds: float, seed_value: int) -> int:
	var ev := GameEvent.new()
	ev.rng.seed = seed_value
	var n: int = 0
	for i: int in int(seconds * hz):
		if ev.chance(rate, 1.0 / hz):
			n += 1
	return n


func test_rate_independent_of_frame_rate() -> void:
	# 1,2 Ereignisse/s über 200 s -> Erwartung 240, bei 30 Hz und 120 Hz gleich (± Zufallsstreuung)
	var slow: int = _count(1.2, 30.0, 200.0, 7)
	var fast: int = _count(1.2, 120.0, 200.0, 7)
	for n: int in [slow, fast]:
		assert_gt(float(n), 200.0, "Rate nicht zu klein (%d)" % n)
		assert_lt(float(n), 280.0, "Rate nicht zu groß (%d)" % n)


func test_rally_escalation_not_near_certain() -> void:
	# Eskalationsrate 1/90 s: nach 30 s Kundgebung eskaliert im Mittel nur ein Teil (vorher bei 60 Hz ≈ 99 %)
	var escalated: int = 0
	for s: int in 200:
		var ev := GameEvent.new()
		ev.rng.seed = 1000 + s
		for i: int in 30 * 60:
			if ev.chance(1.0 / 90.0, 1.0 / 60.0):
				escalated += 1
				break
	var share: float = float(escalated) / 200.0
	assert_gt(share, 0.18, "Eskalation möglich (%.2f)" % share)
	assert_lt(share, 0.40, "Eskalation nicht fast sicher (%.2f), Erwartung 0,28" % share)
