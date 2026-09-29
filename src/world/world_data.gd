class_name WorldData
extends RefCounted
## Zugriff auf die von tools/worldgen erzeugten Weltdaten (data/world/ka/):
## world.json.gz (Graph, POIs, Gehwegnetz, Metadaten), sectors/*.json.gz (Inhalt je 256-m-Sektor),
## lod/*.json.gz (Fern-Silhouetten je 1-km-Kachel), map.webp (Kartenbild).
## Koordinaten sind in den Dateien als Ganzzahlen in Dezimetern gespeichert (Faktor q).

const DIR: String = "res://data/world/ka/"

var dir: String = DIR
var meta: Dictionary = {}
var q: float = 10.0
var bounds: Rect2 = Rect2()
var sector_size: float = 256.0
var sectors: Dictionary = {}        ## Vector2i -> true (vorhandene Sektordateien)
var lod_tile: float = 1024.0
var lod_tiles: Dictionary = {}      ## Vector2i -> true
var area_kinds: PackedStringArray = PackedStringArray()
var prop_kinds: PackedStringArray = PackedStringArray()
var landmarks: Array = []
var veg_block: Array[PackedVector2Array] = []   ## Landmarken-Grundrisse (dort keine Laufzeit-Vegetation)
var veg_block_rect: Array[Rect2] = []
var map_m_per_px: float = 4.0


static func load_world(p_dir: String = DIR) -> WorldData:
	var w := WorldData.new()
	w.dir = p_dir
	var d: Variant = read_gz_json(p_dir + "world.json.gz")
	if not d is Dictionary:
		push_error("Weltdaten fehlen oder sind beschädigt: %sworld.json.gz" % p_dir)
		return null
	w.meta = d
	w.q = float(d.get("q", 10.0))
	var b: Array = d.bounds
	w.bounds = Rect2(Vector2(float(b[0]), float(b[1])), Vector2(float(b[2]) - float(b[0]), float(b[3]) - float(b[1])))
	w.sector_size = float(d.get("sector", 256.0))
	for s: Variant in d.get("sectors", []):
		w.sectors[Vector2i(int(s[0]), int(s[1]))] = true
	var lod: Dictionary = d.get("lod", {})
	w.lod_tile = float(lod.get("tile", 1024.0))
	for t: Variant in lod.get("tiles", []):
		w.lod_tiles[Vector2i(int(t[0]), int(t[1]))] = true
	w.area_kinds = PackedStringArray(d.get("area_kinds", []))
	w.prop_kinds = PackedStringArray(d.get("prop_kinds", []))
	w.landmarks = d.get("landmarks", [])
	LandmarksExtra.use_zoo_layout_from(w.landmarks)
	for lmv: Variant in w.landmarks:
		for fv: Variant in (lmv as Dictionary).get("foot", []):
			var fa: Array = fv
			var poly: PackedVector2Array = PackedVector2Array()
			for i: int in range(0, fa.size() - 1, 2):
				poly.append(Vector2(float(fa[i]), float(fa[i + 1])))
			if poly.size() >= 3:
				var r: Rect2 = Rect2(poly[0], Vector2.ZERO)
				for pv: Vector2 in poly:
					r = r.expand(pv)
				w.veg_block.append(poly)
				w.veg_block_rect.append(r)
	w.map_m_per_px = float((d.get("map", {}) as Dictionary).get("m_per_px", 4.0))
	return w


## gzip-komprimiertes JSON lesen (Standard-gzip aus Python).
static func read_gz_json(path: String) -> Variant:
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		return null
	var data: PackedByteArray = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if data.is_empty():
		return null
	return JSON.parse_string(data.get_string_from_utf8())


func sector_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - bounds.position.x) / sector_size)), int(floor((p.y - bounds.position.y) / sector_size)))


func sector_rect(ij: Vector2i) -> Rect2:
	return Rect2(bounds.position + Vector2(ij) * sector_size, Vector2(sector_size, sector_size))


func has_sector(ij: Vector2i) -> bool:
	return sectors.has(ij)


## Sektorinhalt laden (thread-sicher: nur Datei + JSON). Leeres Dictionary, wenn nicht vorhanden.
func load_sector(ij: Vector2i) -> Dictionary:
	if not sectors.has(ij):
		return {}
	var d: Variant = read_gz_json("%ssectors/s_%d_%d.json.gz" % [dir, ij.x, ij.y])
	return d if d is Dictionary else {}


func lod_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x - bounds.position.x) / lod_tile)), int(floor((p.y - bounds.position.y) / lod_tile)))


func load_lod(ij: Vector2i) -> Array:
	if not lod_tiles.has(ij):
		return []
	var d: Variant = read_gz_json("%slod/t_%d_%d.json.gz" % [dir, ij.x, ij.y])
	return d if d is Array else []


## Flaches Ganzzahl-Array (Dezimeter) -> Punktliste.
func pts(flat: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(flat.size() / 2)
	var inv: float = 1.0 / q
	for i: int in out.size():
		out[i] = Vector2(float(flat[i * 2]) * inv, float(flat[i * 2 + 1]) * inv)
	return out
