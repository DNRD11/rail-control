class_name OperationalLog
extends RefCounted
## Log operativo ordenado de hechos de la simulación. Su digest identifica la ejecución.

var entries: Array[LogEntry] = []


func add(time: int, type: StringName, service_id: StringName = &"", stop_index: int = -1,
		data: Dictionary = {}) -> LogEntry:
	var e: LogEntry = LogEntry.new()
	e.time = time
	e.type = type
	e.service_id = service_id
	e.stop_index = stop_index
	e.data = data
	entries.append(e)
	return e


func count() -> int:
	return entries.size()


## Huella SHA-256 (hex) de todas las entradas en orden.
func digest() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for e: LogEntry in entries:
		lines.append(e.canonical())
	return "\n".join(lines).sha256_text()


## Entradas de un tipo (y opcionalmente de un servicio).
func filter(type: StringName, service_id: StringName = &"") -> Array[LogEntry]:
	var out: Array[LogEntry] = []
	for e: LogEntry in entries:
		if e.type == type and (service_id == &"" or e.service_id == service_id):
			out.append(e)
	return out
