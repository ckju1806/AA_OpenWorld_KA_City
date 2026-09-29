class_name GameEvent
extends RefCounted
## Basis für Zufallsereignisse (W7). Der EventDirector ruft start() einmal, danach update() je Takt, bis done;
## cleanup() entfernt alle erzeugten Figuren/Fahrzeuge. Ereignisse sind vollständig fiktiv.

var director: EventDirector
var kind: String = ""
var title: String = ""
var pos: Vector3 = Vector3.ZERO
var t: float = 0.0
var max_time: float = 120.0
var done: bool = false
var actors: Array[EventActor] = []
var vehicles: Array[Vehicle] = []
var police_called: bool = false
var rng := RandomNumberGenerator.new()


func start() -> bool:
	return false


func update(_delta: float) -> void:
	pass


## Fortschritt je Takt; beendet das Ereignis nach max_time oder wenn der Spieler weit entfernt ist.
func tick(delta: float, player_pos: Vector3) -> void:
	t += delta
	update(delta)
	if t > max_time or player_pos.distance_to(pos) > 330.0:
		done = true


func spawn_actor(p: Vector3, jacket: Color = Color(-1, 0, 0)) -> EventActor:
	var a := EventActor.new()
	director.root.add_child(a)
	a.setup(director.city, rng.randi(), EventActor.look_for(rng, jacket))
	a.place(p)
	a.knocked_down.connect(director.on_actor_down)
	actors.append(a)
	return a


func bark(actor: Node3D, text: String) -> void:
	if actor != null and is_instance_valid(actor):
		EventBus.bark.emit(title, text, actor.global_position)


func call_police(duration: float = 45.0) -> void:
	if police_called or not Settings.events_police:
		return
	police_called = true
	director.dispatch_police(pos, duration)


func cleanup() -> void:
	for a: EventActor in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()
	for v: Vehicle in vehicles:
		if is_instance_valid(v) and v.driver != Vehicle.Driver.PLAYER:
			v.queue_free()
	vehicles.clear()
