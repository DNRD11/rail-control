class_name ScenarioFixture
extends RefCounted
## Utilidades de prueba: carga única del escenario MVP y copias profundas para mutarlas.

const MVP: String = "mvp_mad_bcn_morning"

static var _raw: Dictionary = {}


## Copia profunda del `raw` del MVP (se lee del disco una sola vez).
static func raw_copy() -> Dictionary:
	if _raw.is_empty():
		_raw = ScenarioLoader.load_raw(MVP)
	return _raw.duplicate(true)


## Construye World + valida a partir de un `raw`. Devuelve el informe; `out_world` recibe el World.
static func build_and_validate(raw: Dictionary, out_world: Array = []) -> ValidationReport:
	var report: ValidationReport = ValidationReport.new()
	var world: World = WorldBuilder.build(raw, report)
	DataValidator.validate(world, report)
	out_world.append(world)
	return report


static func load_world() -> World:
	var out: Array = []
	build_and_validate(raw_copy(), out)
	return out[0] as World


## Devuelve el diccionario de un archivo `raw[file][list_key]` cuyo `id` coincide.
static func find_item(raw: Dictionary, file: String, list_key: String, id: String) -> Dictionary:
	for item: Variant in (raw[file] as Dictionary)[list_key] as Array:
		if (item as Dictionary).get("id", "") == id:
			return item as Dictionary
	return {}


static func remove_item(raw: Dictionary, file: String, list_key: String, id: String) -> void:
	var arr: Array = (raw[file] as Dictionary)[list_key] as Array
	for i: int in arr.size():
		if (arr[i] as Dictionary).get("id", "") == id:
			arr.remove_at(i)
			return
