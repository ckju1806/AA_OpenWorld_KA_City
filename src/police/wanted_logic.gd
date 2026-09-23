class_name WantedLogic
extends RefCounted
## Fahndungslogik (ohne Engine-Abhängigkeiten, unit-testbar).
## Stufe 0–3. Nur beobachtete Taten erhöhen die Fahndung. Die Polizei kennt nur die zuletzt
## gesehene Position. Ohne erneuten Sichtkontakt endet die Fahndung nach der Suchphase.

signal level_changed(level: int)
signal state_changed(state: String)

const MAX_LEVEL: int = 3
## Mindeststufe je Tat und ob sie bei laufender Verfolgung eskaliert (+1)
const CRIMES: Dictionary = {
	"fahrzeugraub": {"min": 1, "escalate": true, "text": "Fahrzeugraub beobachtet"},
	"fahrzeugdiebstahl": {"min": 1, "escalate": false, "text": "Autodiebstahl beobachtet"},
	"streifenwagen": {"min": 2, "escalate": true, "text": "Streifenwagen gestohlen"},
	"polizei_rammen": {"min": 1, "escalate": true, "text": "Polizeifahrzeug gerammt"},
	"fussgaenger": {"min": 1, "escalate": true, "text": "Passant angefahren"},
	"flucht": {"min": 1, "escalate": false, "text": "Flucht vor der Polizei"},
}

var level: int = 0
var state: String = "frei"               ## frei | verfolgung | suche
var last_known: Vector3 = Vector3.ZERO
var unseen_time: float = 0.0
var search_time: float = 0.0
var lose_sight_delay: float = 2.5        ## s ohne Sicht bis zur Suchphase
var search_durations: Array[float] = [0.0, 18.0, 26.0, 34.0]   ## Suchphase je Stufe (konfigurierbar)
var last_reason: String = ""


## Meldet eine Tat. Nicht beobachtete Taten haben keine Folgen. Rückgabe: neue Stufe.
func report_crime(kind: String, pos: Vector3, witnessed: bool) -> int:
	if not witnessed or not CRIMES.has(kind):
		return level
	var c: Dictionary = CRIMES[kind]
	var new_level: int = maxi(level, int(c.min))
	if level > 0 and bool(c.escalate):
		new_level = maxi(new_level, level + 1)
	last_reason = str(c.text)
	_set_level(mini(new_level, MAX_LEVEL))
	_spotted(pos)
	return level


## Missionen: Stufe direkt setzen (z. B. geskripteter Fahndungsanlass).
func force_level(l: int, pos: Vector3, reason: String = "Missionsereignis") -> void:
	last_reason = reason
	_set_level(clampi(l, 0, MAX_LEVEL))
	if level > 0:
		_spotted(pos)
	else:
		clear()


## Pro Frame: seen = mindestens eine Einheit hat Sichtkontakt.
func update(delta: float, seen: bool, player_pos: Vector3) -> void:
	if level == 0:
		return
	if seen:
		_spotted(player_pos)
		return
	unseen_time += delta
	if state == "verfolgung" and unseen_time >= lose_sight_delay:
		_set_state("suche")
		search_time = 0.0
	if state == "suche":
		search_time += delta
		if search_time >= search_duration():
			clear()


func search_duration() -> float:
	return search_durations[clampi(level, 0, MAX_LEVEL)]


## Verbleibende Suchzeit (0..1) für die Anzeige.
func search_progress() -> float:
	if state != "suche" or search_duration() <= 0.0:
		return 0.0
	return clampf(search_time / search_duration(), 0.0, 1.0)


func clear() -> void:
	_set_level(0)
	_set_state("frei")
	unseen_time = 0.0
	search_time = 0.0


func _spotted(pos: Vector3) -> void:
	last_known = pos
	unseen_time = 0.0
	search_time = 0.0
	_set_state("verfolgung")


func _set_level(l: int) -> void:
	if l != level:
		level = l
		level_changed.emit(level)


func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(state)
