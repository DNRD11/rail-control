class_name WorldBuilder
extends RefCounted
## Construye el World a partir de los JSON ya leídos (ver ScenarioLoader.load_raw).

const SUPPORTED_SCHEMA: int = 1
const FILE_KEYS: Array[String] = [
	"scenario", "vehicle_classes", "services", "vehicles", "compositions", "staff", "assignments", "passengers",
]


static func build(raw: Dictionary, report: ValidationReport) -> World:
	var world: World = World.new()
	for key: String in FILE_KEYS:
		var file: Dictionary = _file(raw, key)
		if file.is_empty():
			report.error(&"MISSING_FILE", "Falta o está vacío el archivo de datos «%s»" % key)
		elif not _schema_ok(file, key, report):
			return world
	world.scenario = _parse_scenario(_file(raw, "scenario"), report)
	var lines: Array[Dictionary] = []
	var raw_lines: Variant = raw.get("lines", [])
	if typeof(raw_lines) == TYPE_ARRAY:
		for item: Variant in raw_lines as Array:
			if typeof(item) == TYPE_DICTIONARY:
				var ld: Dictionary = item as Dictionary
				if _schema_ok(ld, "lines", report):
					lines.append(ld)
	NetworkParser.parse(lines, world, report)
	FleetParser.parse(_file(raw, "vehicle_classes"), _file(raw, "vehicles"), _file(raw, "compositions"),
			_file(raw, "staff"), world, report)
	ScheduleParser.parse(_file(raw, "services"), _file(raw, "assignments"), _file(raw, "passengers"), world, report)
	return world


static func _file(raw: Dictionary, key: String) -> Dictionary:
	var v: Variant = raw.get(key, {})
	return v as Dictionary if typeof(v) == TYPE_DICTIONARY else {}


static func _schema_ok(file: Dictionary, name: String, report: ValidationReport) -> bool:
	var v: Variant = file.get("schema_version")
	var ok: bool = (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and int(v as float) == SUPPORTED_SCHEMA
	if not ok:
		report.error(&"BAD_SCHEMA_VERSION", "%s: schema_version debe ser %d" % [name, SUPPORTED_SCHEMA])
	return ok


static func _parse_scenario(d: Dictionary, report: ValidationReport) -> ScenarioInfo:
	var r: DictReader = DictReader.new(report, "scenario")
	var s: ScenarioInfo = ScenarioInfo.new()
	s.id = r.read_id(d, "id")
	s.name = r.read_string(d, "name", false, String(s.id))
	s.description = r.read_string(d, "description", false, "")
	s.line_ids = r.read_ids(d, "line_ids", true)
	s.day_start = r.read_time(d, "day_start")
	s.day_end = r.read_time(d, "day_end")
	s.time_scale = r.read_int(d, "time_scale", false, 30)
	s.seed = r.read_int(d, "seed", false, 0)
	var rules: Dictionary = {}
	if typeof(d.get("rules")) == TYPE_DICTIONARY:
		rules = d["rules"] as Dictionary
	var rr: DictReader = DictReader.new(report, "scenario.rules")
	s.min_conductors_per_segment = rr.read_int(rules, "min_conductors_per_segment", false, 1)
	s.staff_connection_s = rr.read_int(rules, "staff_connection_s", false, 600)
	s.transfer_s = rr.read_int(rules, "transfer_s", false, 900)
	for item: Dictionary in r.read_dicts(d, "scripted_incidents", false):
		s.scripted_incidents.append(item)
	return s
