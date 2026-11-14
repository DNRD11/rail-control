class_name ChainLink
extends RefCounted
## Dependencia saliente de un servicio hacia el siguiente que usa el mismo recurso (solo lectura).

var resource_type: Enums.ResourceType = Enums.ResourceType.COMPOSITION
var resource_id: StringName = &""
var label: String = ""
var next_service_id: StringName = &""
var station_id: StringName = &""
## Holgura vigente (s): salida estimada del siguiente - (llegada estimada del actual + conexión mínima).
var margin_s: int = 0
## Retraso previsto del siguiente en esa salida (est - programada), 0 si no lo hereda.
var predicted_delay_s: int = 0
var is_material: bool = false
## Salida estimada del siguiente servicio en la estación de relevo.
var next_departure: int = SimTime.NONE
