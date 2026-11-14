class_name ServicePassengerLoad
extends RefCounted
## Viajeros de un servicio: reservas y su distribución por parada.

var service_id: StringName = &""
var booked: int = 0
var boardings_by_stop: Dictionary[int, int] = {}
var alightings_by_stop: Dictionary[int, int] = {}
var informed: bool = false
var last_info_time: int = SimTime.NONE


func total_boardings() -> int:
	var t: int = 0
	for k: int in boardings_by_stop:
		t += boardings_by_stop[k]
	return t


func total_alightings() -> int:
	var t: int = 0
	for k: int in alightings_by_stop:
		t += alightings_by_stop[k]
	return t
