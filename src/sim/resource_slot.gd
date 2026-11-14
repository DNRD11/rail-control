class_name ResourceSlot
extends RefCounted
## Recurso asignado a un tramo de un servicio (solo lectura para la UI).

var resource_type: Enums.ResourceType = Enums.ResourceType.COMPOSITION
var resource_id: StringName = &""
## Texto legible: «C2», «Lucía Marín», «4001».
var label: String = ""
var role: StringName = &""
var from_stop_index: int = 0
var to_stop_index: int = 0
var from_station_id: StringName = &""
var to_station_id: StringName = &""
## Cubre el segmento en curso (o la parada actual, extremos incluidos, si el servicio está detenido).
var is_current: bool = false
var assignment_id: StringName = &""
