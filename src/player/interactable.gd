class_name Interactables
extends RefCounted
## Leichtgewichtiges Register für interagierbare Objekte (keine Weltsuche pro Frame).
## Ein Objekt registriert sich selbst und implementiert:
##   can_interact(player) -> bool, get_interaction_text(player) -> String, interact(player) -> void
##   optional: interaction_radius (float)

static var items: Array[Node3D] = []


static func register(n: Node3D) -> void:
	if not items.has(n):
		items.append(n)


static func unregister(n: Node3D) -> void:
	items.erase(n)


static func find_best(player: Node3D, max_default_radius: float = 2.2) -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	var ppos: Vector3 = player.global_position
	for n: Node3D in items:
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var r: float = float(n.get("interaction_radius")) if n.get("interaction_radius") != null else max_default_radius
		var d: float = n.global_position.distance_to(ppos)
		if d > r or d >= best_d:
			continue
		if not bool(n.call("can_interact", player)):
			continue
		best = n
		best_d = d
	return best
