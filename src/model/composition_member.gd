class_name CompositionMember
extends RefCounted
## Pertenencia de un vehículo a una composición durante un intervalo.

var vehicle_id: StringName = &""
var position: int = 1
var from_time: int = 0
var to_time: int = SimTime.NONE


## True si el vehículo pertenece a la composición en algún instante de [start, end].
func is_active_during(start: int, end: int) -> bool:
	if to_time != SimTime.NONE and to_time < start:
		return false
	return from_time <= end
