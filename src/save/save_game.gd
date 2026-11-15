class_name SaveGame
extends RefCounted
## Guardado determinista: {versión, scenario_id, seed, now, commands, hash}. La carga reconstruye el
## mundo, reaplica los comandos en sus instantes y verifica el hash del estado resultante.

const VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const AUTOSAVE_PATH: String = "user://saves/autosave.json"


static func save(session: SimulationSession, scenario_id: String, path: String = AUTOSAVE_PATH) -> bool:
	var cmds: Array[Dictionary] = []
	for c: Command in session.command_log:
		var d: Dictionary = CommandCodec.to_dict(c)
		if d.is_empty():
			return false
		cmds.append(d)
	var data: Dictionary = {"version": VERSION, "scenario_id": scenario_id, "seed": session.rng.seed,
			"now": session.clock.now, "commands": cmds, "hash": StateHash.of(session)}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir el guardado «%s» (error %d)" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func exists(path: String = AUTOSAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## Solo la cabecera {scenario_id, now, version}; vacío si no es válida.
static func peek(path: String = AUTOSAVE_PATH) -> Dictionary:
	var d: Dictionary = _read(path)
	if d.is_empty():
		return {}
	return {"scenario_id": String(d["scenario_id"]), "now": int(d["now"]), "version": int(d["version"])}


## Sesión restaurada, o null (con push_error) si el archivo falta, está corrupto o el hash no coincide.
static func load(path: String = AUTOSAVE_PATH, data_dir: String = "res://data") -> SimulationSession:
	var d: Dictionary = _read(path)
	if d.is_empty():
		return null
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(String(d["scenario_id"]), data_dir)
	if not res.ok:
		push_error("Guardado «%s»: el escenario «%s» no es válido" % [path, d["scenario_id"]])
		return null
	var s: SimulationSession = SimulationSession.create(res.world, int(d["seed"]))
	for item: Variant in d["commands"] as Array:
		var cmd: Command = null
		if typeof(item) == TYPE_DICTIONARY:
			cmd = CommandCodec.from_dict(item as Dictionary)
		if cmd == null:
			push_error("Guardado «%s»: comando no reconocido" % path)
			return null
		s.advance_seconds(cmd.applied_at - s.clock.now)
		if not s.apply_command(cmd):
			push_error("Guardado «%s»: comando %s rechazado al restaurar" % [path, cmd.kind])
			return null
	s.advance_seconds(int(d["now"]) - s.clock.now)
	if StateHash.of(s) != String(d["hash"]):
		push_error("Guardado «%s»: el estado restaurado no coincide con el guardado (hash)" % path)
		return null
	return s


static func delete(path: String = AUTOSAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("No existe el guardado «%s»" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Guardado «%s» corrupto (JSON no válido)" % path)
		return {}
	var d: Dictionary = parsed as Dictionary
	for key: String in ["version", "scenario_id", "seed", "now", "commands", "hash"]:
		if not d.has(key):
			push_error("Guardado «%s» incompleto: falta «%s»" % [path, key])
			return {}
	if int(d["version"]) != VERSION or typeof(d["commands"]) != TYPE_ARRAY:
		push_error("Guardado «%s»: versión %s no soportada" % [path, d["version"]])
		return {}
	return d
