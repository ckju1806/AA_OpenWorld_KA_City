class_name Layers
extends RefCounted
## Physik-Layer (Bitmasken) – zentral definiert, siehe project.godot [layer_names].

const WORLD: int = 1        ## Statische Welt: Boden, Gebäude, Props
const PLAYER: int = 2       ## Spielfigur
const VEHICLE: int = 4      ## Fahrzeuge
const NPC: int = 8          ## Passanten (nur Erkennung, blockieren keine Fahrzeuge)
const TRIGGER: int = 16     ## Missions-/Interaktionsbereiche

const PLAYER_MASK: int = WORLD | VEHICLE
const VEHICLE_MASK: int = WORLD | VEHICLE | PLAYER
const CAMERA_MASK: int = WORLD | VEHICLE
const GROUND_MASK: int = WORLD
