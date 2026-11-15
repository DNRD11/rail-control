class_name ScenarioCatalog
extends RefCounted
## Lista los escenarios disponibles leyendo data/scenarios/*/scenario.json (sin construir el mundo).

const SCENARIOS_DIR: String = "res://data/scenarios"


## Escenarios por orden de carpeta. Los JSON ilegibles se omiten con push_warning.
static func list(data_dir: String = "res://data") -> Array[ScenarioInfo]:
	var out: Array[ScenarioInfo] = []
	for folder: String in folders(data_dir):
		var d: Dictionary = _read(data_dir, folder)
		if d.is_empty():
			push_warning("Escenario «%s» ilegible; se omite" % folder)
			continue
		var info: ScenarioInfo = ScenarioInfo.new()
		info.id = StringName(String(d.get("id", folder)))
		info.name = String(d.get("name", folder))
		info.description = String(d.get("description", ""))
		info.day_start = _time(d.get("day_start", "00:00"), 0)
		info.day_end = _time(d.get("day_end", "24:00"), 86400)
		info.seed = int(d.get("seed", 0))
		out.append(info)
	return out


## Carpetas bajo data/scenarios que contienen un scenario.json.
static func folders(data_dir: String = "res://data") -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open("%s/scenarios" % data_dir)
	if dir == null:
		return out
	var names: PackedStringArray = dir.get_directories()
	names.sort()
	for n: String in names:
		if FileAccess.file_exists("%s/scenarios/%s/scenario.json" % [data_dir, n]):
			out.append(n)
	return out


## Datos extra para la selección y el briefing que ScenarioInfo no guarda:
## {difficulty: String ("" si no existe), service_count: int, incident_count: int}.
static func meta(folder: String, data_dir: String = "res://data") -> Dictionary:
	var d: Dictionary = _read(data_dir, folder)
	var services: Dictionary = _read_file("%s/scenarios/%s/services.json" % [data_dir, folder])
	var svc_list: Array = services.get("services", []) as Array
	var incs: Array = d.get("scripted_incidents", []) as Array
	return {
		"difficulty": String(d.get("difficulty", "")),
		"service_count": svc_list.size(),
		"incident_count": incs.size(),
	}


static func _read(data_dir: String, folder: String) -> Dictionary:
	return _read_file("%s/scenarios/%s/scenario.json" % [data_dir, folder])


static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}


static func _time(v: Variant, fallback: int) -> int:
	if typeof(v) != TYPE_STRING:
		return fallback
	var t: int = SimTime.parse(String(v))
	return fallback if t == SimTime.NONE else t
