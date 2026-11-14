class_name RotationEdge
extends RefCounted
## Dependencia entre dos servicios consecutivos de un mismo recurso (rotación o continuidad de personal).

var from_service_id: StringName = &""
var to_service_id: StringName = &""
var resource_type: Enums.ResourceType = Enums.ResourceType.COMPOSITION
var resource_id: StringName = &""
var station_id: StringName = &""
var from_assignment_id: StringName = &""
var to_assignment_id: StringName = &""
var gap_s: int = 0
var min_connection_s: int = 0
var margin_s: int = 0
