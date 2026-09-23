class_name TestCase
extends Node
## Basisklasse für Tests. Testmethoden beginnen mit "test_" und dürfen "await" verwenden.

var failures: Array[String] = []
var current_test: String = ""


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "Bedingung nicht erfüllt") -> bool:
	if not cond:
		fail(msg)
	return cond


func assert_false(cond: bool, msg: String = "Bedingung unerwartet erfüllt") -> bool:
	return assert_true(not cond, msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if typeof(actual) != typeof(expected) and not ((actual is int or actual is float) and (expected is int or expected is float)):
		fail("%s erwartet <%s>, erhalten <%s> (Typ)" % [msg, str(expected), str(actual)])
		return false
	if actual != expected:
		fail("%s erwartet <%s>, erhalten <%s>" % [msg, str(expected), str(actual)])
		return false
	return true


func assert_near(actual: float, expected: float, eps: float, msg: String = "") -> bool:
	if absf(actual - expected) > eps:
		fail("%s erwartet %.3f ± %.3f, erhalten %.3f" % [msg, expected, eps, actual])
		return false
	return true


func assert_gt(actual: float, bound: float, msg: String = "") -> bool:
	if not actual > bound:
		fail("%s erwartet > %.3f, erhalten %.3f" % [msg, bound, actual])
		return false
	return true


func assert_lt(actual: float, bound: float, msg: String = "") -> bool:
	if not actual < bound:
		fail("%s erwartet < %.3f, erhalten %.3f" % [msg, bound, actual])
		return false
	return true


# --- Hilfen für Integrationstests (simulierte Zeit bei --fixed-fps 60) ---

func wait_physics(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


func wait_seconds(sim_seconds: float) -> void:
	await wait_physics(int(ceil(sim_seconds * 60.0)))


## Wartet, bis cond.call() true liefert oder die Zeit abläuft. Rückgabe: erfüllt?
func wait_until(cond: Callable, timeout_sim_seconds: float, step_frames: int = 3) -> bool:
	var frames: int = int(timeout_sim_seconds * 60.0)
	var elapsed: int = 0
	while elapsed < frames:
		if bool(cond.call()):
			return true
		await wait_physics(step_frames)
		elapsed += step_frames
	return bool(cond.call())
