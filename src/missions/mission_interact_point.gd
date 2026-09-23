class_name MissionInteractPoint
extends Node3D
## Interaktionspunkt eines Missionsschritts (z. B. "Sendung abgeben"). Nur zu Fuß nutzbar.

signal used

var prompt: String = "Interagieren"
var interaction_radius: float = 2.5
var enabled: bool = true


func _enter_tree() -> void:
	Interactables.register(self)


func _exit_tree() -> void:
	Interactables.unregister(self)


func can_interact(p: Player) -> bool:
	return enabled and p != null and not p.is_in_vehicle() and not p.is_dead


func get_interaction_text(_p: Player) -> String:
	return prompt


func interact(_p: Player) -> void:
	if not enabled:
		return
	enabled = false
	AudioManager.play_2d("ui_confirm", -4.0)
	used.emit()
