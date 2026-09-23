class_name DetRng
extends RefCounted
## Deterministische Hilfsfunktionen: gleiche Eingabe -> gleiches Ergebnis auf jedem Start/Rechner.


static func hash_int(a: int, b: int = 0, c: int = 0) -> int:
	var h: int = a * 73856093 ^ b * 19349663 ^ c * 83492791
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)


## Gleichverteilter Wert in [0, 1) aus bis zu drei Ganzzahlen.
static func hash01(a: int, b: int = 0, c: int = 0) -> float:
	return float(hash_int(a, b, c) % 100003) / 100003.0


static func make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng
