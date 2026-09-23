class_name Layers
extends RefCounted
## Physik-Layer (Bitmasken) – zentral definiert, siehe project.godot [layer_names].

const WORLD: int = 1        ## Statische Welt: Boden, Gebäude, Props
const PLAYER: int = 2       ## Spielfigur
const VEHICLE: int = 4      ## Fahrzeuge
const NPC: int = 8          ## Passanten (nur Erkennung, blockieren keine Fahrzeuge)
const TRIGGER: int = 16     ## Missions-/Interaktionsbereiche

const PLAYER_MASK: int = WORLD | VEHICLE | NPC
## Fahrzeuge kollidieren nicht physikalisch mit dem Spieler (Treffer über Trefferzone des Spielers),
## sonst würde der kinematische Spieler wie eine Wand wirken.
const VEHICLE_MASK: int = WORLD | VEHICLE | NPC
const CAMERA_MASK: int = WORLD | VEHICLE
const GROUND_MASK: int = WORLD
