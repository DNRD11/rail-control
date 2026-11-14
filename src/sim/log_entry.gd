class_name LogEntry
extends RefCounted
## Entrada del log operativo.

var time: int = 0
var type: StringName = &""
var service_id: StringName = &""
var stop_index: int = -1
var data: Dictionary = {}


## Forma canónica (estable) para el hash.
func canonical() -> String:
	return "%d|%s|%s|%d|%s" % [time, type, service_id, stop_index, JSON.stringify(data, "", true)]
