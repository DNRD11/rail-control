class_name SimEvent
extends RefCounted
## Evento programado. Orden total: (time, priority, seq).

var time: int = 0
var priority: int = 0
var seq: int = 0
var type: StringName = &""
var service_id: StringName = &""
var stop_index: int = -1
var data: Dictionary = {}
## Evento invalidado (reprogramado): la sesión lo descarta sin despacharlo.
var cancelled: bool = false


## True si este evento debe procesarse antes que `other`.
func before(other: SimEvent) -> bool:
	if time != other.time:
		return time < other.time
	if priority != other.priority:
		return priority < other.priority
	return seq < other.seq
