class_name TransitBoardPoint
extends Node3D
## Interaktionspunkt „Einsteigen“: folgt dem Spieler und ist aktiv, wenn an einer nahen Haltestelle ein Fahrzeug hält.
## Während der Fahrt: „Aussteigen am nächsten Halt“.

var system: TransitSystem
var interaction_radius: float = 3.0


func _enter_tree() -> void:
	Interactables.register(self)


func _exit_tree() -> void:
	Interactables.unregister(self)


func _process(_delta: float) -> void:
	var p: Player = system.game.get("player") as Player
	if p != null:
		global_position = p.global_position


func can_interact(p: Player) -> bool:
	if system.is_riding():
		return true
	if p.is_in_vehicle():
		return false
	return not system.dwelling_near(p.global_position).is_empty()


func get_interaction_text(p: Player) -> String:
	if system.is_riding():
		return "Aussteigen am nächsten Halt"
	var vh: Dictionary = system.dwelling_near(p.global_position)
	if vh.is_empty():
		return ""
	var ln: Dictionary = system.lines[int(vh.line)]
	return "Einsteigen: Linie %s → %s (%d €)" % [ln.ref, system._dest_name(ln), TransitSystem.FARE]


func interact(p: Player) -> void:
	if system.is_riding():
		system.request_exit()
		return
	var vh: Dictionary = system.dwelling_near(p.global_position)
	if not vh.is_empty():
		system.board(vh)
