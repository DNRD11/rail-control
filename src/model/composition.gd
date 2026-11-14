class_name Composition
extends RefCounted
## Vehículos que circulan acoplados.

var id: StringName = &""
var status: Enums.CompositionStatus = Enums.CompositionStatus.ACTIVE
var formed_at: int = 0
var dissolved_at: int = SimTime.NONE
var members: Array[CompositionMember] = []


func vehicle_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for m: CompositionMember in members:
		out.append(m.vehicle_id)
	return out


func vehicle_ids_during(start: int, end: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for m: CompositionMember in members:
		if m.is_active_during(start, end):
			out.append(m.vehicle_id)
	return out
