class_name TrafficDriver
extends LaneDriver
## Verkehrs-KI: fährt zufällige, aber plausible Routen (bevorzugt geradeaus) im Verkehrsnetz.

var rng: RandomNumberGenerator


func _init(seed_value: int) -> void:
	rng = DetRng.make_rng(seed_value)
	personality = rng.randf_range(0.82, 1.08)


func choose_next(prev: int, cur: int) -> int:
	var options: Array[int] = []
	var weights: Array[float] = []
	var d_in: Vector2 = Vector2.ZERO
	if prev >= 0:
		d_in = (graph.node_pos[cur] - graph.node_pos[prev]).normalized()
	for e: int in graph.node_edges_mode(cur, mode):
		var o: int = graph.other_node(e, cur)
		if o == prev:
			continue
		var d_out: Vector2 = graph.edge_dir(e, cur)
		var straight: float = d_in.dot(d_out) if prev >= 0 else 0.5
		options.append(o)
		weights.append(0.35 + maxf(straight, 0.0) * 1.3)
	if options.is_empty():
		return prev  # Sackgasse: wenden
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = rng.randf() * total
	for i: int in options.size():
		r -= weights[i]
		if r <= 0.0:
			return options[i]
	return options[options.size() - 1]
