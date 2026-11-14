class_name ScenarioLoader
extends RefCounted
## Lee los JSON de un escenario desde disco y construye + valida el World.

const SCENARIO_FILES: Dictionary[String, String] = {
	"services": "services.json",
	"vehicles": "vehicles.json",
	"compositions": "compositions.json",
	"staff": "staff.json",
	"assignments": "assignments.json",
	"passengers": "passengers.json",
}


## Lee todos los archivos. Los errores de E/S o de parseo se devuelven en `"_errors": Array[String]`.
static func load_raw(scenario_id: String, data_dir: String = "res://data") -> Dictionary:
	var errors: Array[String] = []
	var raw: Dictionary = {}
	var base: String = "%s/scenarios/%s" % [data_dir, scenario_id]
	var scenario: Dictionary = _read_json("%s/scenario.json" % base, errors)
	raw["scenario"] = scenario
	for key: String in SCENARIO_FILES:
		raw[key] = _read_json("%s/%s" % [base, SCENARIO_FILES[key]], errors)
	raw["vehicle_classes"] = _read_json("%s/rolling_stock/vehicle_classes.json" % data_dir, errors)
	raw["lines"] = _read_lines(scenario, data_dir, errors)
	raw["_errors"] = errors
	return raw


static func load_scenario(scenario_id: String, data_dir: String = "res://data") -> ScenarioLoadResult:
	var raw: Dictionary = load_raw(scenario_id, data_dir)
	var report: ValidationReport = ValidationReport.new()
	var io_errors: Array = raw.get("_errors", []) as Array
	for msg: Variant in io_errors:
		report.error(&"IO_ERROR", String(msg))
	var world: World = WorldBuilder.build(raw, report)
	DataValidator.validate(world, report)
	for issue: ValidationReport.Issue in report.issues:
		if issue.severity == ValidationReport.Severity.ERROR:
			push_error(str(issue))
	return ScenarioLoadResult.new(world, report)


static func _read_lines(scenario: Dictionary, data_dir: String, errors: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wanted: Array[String] = []
	var ids: Variant = scenario.get("line_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for id: Variant in ids as Array:
			wanted.append(String(id))
	var dir_path: String = "%s/lines" % data_dir
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		errors.append("No se puede abrir el directorio «%s»" % dir_path)
		return out
	var files: PackedStringArray = dir.get_files()
	files.sort()
	var found: Array[String] = []
	for f: String in files:
		if not f.ends_with(".json"):
			continue
		var d: Dictionary = _read_json("%s/%s" % [dir_path, f], errors)
		var id: String = String(d.get("id", ""))
		if wanted.has(id):
			out.append(d)
			found.append(id)
	for id: String in wanted:
		if not found.has(id):
			errors.append("No se encontró la línea «%s» en %s" % [id, dir_path])
	return out


static func _read_json(path: String, errors: Array[String]) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("No existe el archivo «%s»" % path)
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		errors.append("JSON no válido en «%s» (línea %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("«%s»: la raíz debe ser un objeto" % path)
		return {}
	return json.data as Dictionary
