extends Node
## Spielstand im Speicher: Geld, abgeschlossene Missionen, Bestzeiten.
## Belohnungen werden idempotent vergeben (keine doppelte Auszahlung).

signal money_changed(value: int)

const START_MONEY: int = 150

var money: int = START_MONEY
var completed_missions: Dictionary = {}   ## mission_id -> true
var best_times: Dictionary = {}           ## mission_id -> Sekunden (float)
var mission_attempts: Dictionary = {}     ## mission_id -> Anzahl Versuche
var play_time: float = 0.0


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func reset_new_game() -> void:
	money = START_MONEY
	completed_missions.clear()
	best_times.clear()
	mission_attempts.clear()
	play_time = 0.0
	money_changed.emit(money)


func add_money(amount: int) -> void:
	money = maxi(0, money + amount)
	money_changed.emit(money)


func is_mission_completed(mission_id: String) -> bool:
	return completed_missions.has(mission_id)


## Markiert eine Mission als abgeschlossen. Gibt true zurück, wenn es der erste Abschluss war
## (nur dann wird die Belohnung ausgezahlt).
func complete_mission(mission_id: String, reward: int) -> bool:
	if completed_missions.has(mission_id):
		return false
	completed_missions[mission_id] = true
	if reward > 0:
		add_money(reward)
	return true


func register_attempt(mission_id: String) -> void:
	mission_attempts[mission_id] = int(mission_attempts.get(mission_id, 0)) + 1


## Übernimmt eine Zeit als Bestzeit, wenn sie besser ist. Rückgabe: neuer Rekord?
func submit_best_time(mission_id: String, seconds: float) -> bool:
	if seconds <= 0.0:
		return false
	if not best_times.has(mission_id) or seconds < float(best_times[mission_id]):
		best_times[mission_id] = seconds
		return true
	return false


func get_best_time(mission_id: String) -> float:
	return float(best_times.get(mission_id, -1.0))


func to_dict() -> Dictionary:
	return {
		"money": money,
		"completed_missions": completed_missions.keys(),
		"best_times": best_times.duplicate(),
		"mission_attempts": mission_attempts.duplicate(),
		"play_time": play_time,
	}


func from_dict(d: Dictionary) -> void:
	money = maxi(0, int(d.get("money", START_MONEY)))
	completed_missions.clear()
	var cm: Variant = d.get("completed_missions", [])
	if cm is Array:
		for id: Variant in cm:
			if id is String:
				completed_missions[id] = true
	best_times.clear()
	var bt: Variant = d.get("best_times", {})
	if bt is Dictionary:
		for k: Variant in bt:
			var v: float = float(bt[k])
			if k is String and v > 0.0:
				best_times[k] = v
	mission_attempts.clear()
	var ma: Variant = d.get("mission_attempts", {})
	if ma is Dictionary:
		for k: Variant in ma:
			if k is String:
				mission_attempts[k] = maxi(0, int(ma[k]))
	play_time = maxf(0.0, float(d.get("play_time", 0.0)))
	money_changed.emit(money)
