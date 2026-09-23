extends Node
## Globaler Signal-Bus: entkoppelt Systeme (Spieler, Fahrzeuge, Missionen, Polizei, UI).

# Spieler / Fahrzeuge
signal player_spawned(player: Node)
signal player_entered_vehicle(vehicle: Node)
signal player_exited_vehicle(vehicle: Node)
signal player_died(cause: String)
signal player_busted
signal player_respawned

# Oberfläche
signal notify(text: String, kind: String)              ## kind: info, erfolg, warnung, fehler
signal context_hint(text: String)                     ## leer = ausblenden
signal big_message(title: String, subtitle: String, seconds: float)

# Kriminalität / Polizei
signal crime_reported(kind: String, position: Vector3, witnessed: bool)
signal wanted_changed(level: int)
signal wanted_state_changed(state: String)            ## frei, verfolgung, suche

# Missionen
signal mission_started(mission_id: String)
signal mission_objective(mission_id: String, text: String)
signal mission_completed(mission_id: String, reward: int, first_time: bool)
signal mission_failed(mission_id: String, reason: String)
signal mission_aborted(mission_id: String)
signal dialog_line(speaker: String, text: String)
signal dialog_closed

# Fahrzeugereignisse (für Audio/Polizei)
signal vehicle_collision(vehicle: Node, impulse: float, other: Node)
signal horn(position: Vector3)
