class_name ResourceState
extends RefCounted
## Estado de un recurso en el instante actual (franja de recursos de la UI).

enum State { IN_SERVICE, IDLE, RESERVE, FAILED }

var resource_type: Enums.ResourceType = Enums.ResourceType.COMPOSITION
var resource_id: StringName = &""
var label: String = ""
var state: State = State.IDLE
var current_service_id: StringName = &""
## Estación donde está (vacío si en circulación entre estaciones).
var station_id: StringName = &""
var next_service_id: StringName = &""
## Salida estimada del próximo servicio (SimTime.NONE si no hay).
var next_departure: int = SimTime.NONE
