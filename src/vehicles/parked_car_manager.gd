class_name ParkedCarManager
extends Node
## Geparkte Autos sektorweise: erscheinen mit dem Sektor, verschwinden beim Entladen (sofern nicht benutzt).
## Obergrenze gegen wachsende Objektmengen; ein Teil ist unverschlossen (Übernahme möglich).

const MAX_TOTAL: int = 60
const SPECS: Array[String] = ["kompakt", "kompakt", "limousine", "kompakt", "transporter", "sport"]

var game: Node
var _by_sector: Dictionary = {}     ## Vector2i -> Array[Vehicle]
var enabled: bool = true


func setup(p_game: Node, streamer: WorldStreamer) -> void:
	game = p_game
	streamer.sector_loaded.connect(_on_loaded)
	streamer.sector_unloaded.connect(_on_unloaded)
	for ij: Vector2i in streamer.loaded:
		_on_loaded(ij, streamer.loaded[ij])


func total() -> int:
	var n: int = 0
	for ij: Vector2i in _by_sector:
		n += (_by_sector[ij] as Array).size()
	return n


func _on_loaded(ij: Vector2i, info: Dictionary) -> void:
	if not enabled:
		return
	var list: Array[Vehicle] = []
	var budget: int = maxi(0, MAX_TOTAL - total())
	for c: Dictionary in info.get("cars", []):
		if budget <= 0:
			break
		var v: int = int(c.variant)
		var spec: String = SPECS[v % SPECS.size()]
		var sp: VehicleSpec = VehicleSpec.get_spec(spec)
		var veh: Vehicle = game.call("spawn_vehicle", spec, c.position, float(c.yaw), sp.colors[v % sp.colors.size()],
			Vehicle.Ownership.PARKED_FOREIGN, "") as Vehicle
		veh.locked = v % 3 == 0
		veh.add_to_group("parked_cars")
		list.append(veh)
		budget -= 1
	_by_sector[ij] = list


func _on_unloaded(ij: Vector2i) -> void:
	var pl: Player = game.get("player") as Player
	for v: Vehicle in _by_sector.get(ij, []):
		if not is_instance_valid(v):
			continue
		if pl != null and pl.current_vehicle == v:
			continue
		if v.ownership != Vehicle.Ownership.PARKED_FOREIGN:
			continue   # benutzt/übernommen -> bleibt (Game begrenzt benutzte Fahrzeuge)
		v.queue_free()
	_by_sector.erase(ij)
