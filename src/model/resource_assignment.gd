class_name ResourceAssignment
extends RefCounted
## Liga un recurso a un tramo del itinerario de un servicio.

var id: StringName = &""
var service_id: StringName = &""
var resource_type: Enums.ResourceType = Enums.ResourceType.COMPOSITION
var resource_id: StringName = &""
var role: StringName = &""
var from_stop_index: int = 0
var to_stop_index: int = 0
var from_station_id: StringName = &""
var to_station_id: StringName = &""
var planned_start: int = SimTime.NONE
var planned_end: int = SimTime.NONE
var actual_start: int = SimTime.NONE
var actual_end: int = SimTime.NONE
var status: Enums.AssignmentStatus = Enums.AssignmentStatus.PLANNED
var source: Enums.AssignmentSource = Enums.AssignmentSource.PLAN
var replaces_assignment_id: StringName = &""


func is_live() -> bool:
	return status != Enums.AssignmentStatus.CANCELLED and status != Enums.AssignmentStatus.REPLACED


## Cubre el segmento k (entre las paradas k y k+1).
func covers_segment(k: int) -> bool:
	return from_stop_index <= k and k < to_stop_index


## Cubre la parada i (extremos incluidos).
func covers_stop(i: int) -> bool:
	return from_stop_index <= i and i <= to_stop_index
