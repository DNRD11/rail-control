class_name ServicePassengerLoad
extends RefCounted
## Viajeros de un servicio: reservas y su distribución por parada.

var service_id: StringName = &""
var booked: int = 0
var boardings_by_stop: Dictionary[int, int] = {}
var alightings_by_stop: Dictionary[int, int] = {}
var informed: bool = false
var last_info_time: int = SimTime.NONE
## Contadores derivados (los calcula PassengerSystem; ver DATA_MODEL.md §7).
var affected: int = 0
var continuing: int = 0
var needing_alternative: int = 0
var compensation_eligible: int = 0
## Viajeros que ya han llegado a su destino.
var carried: int = 0
## Hora en que los viajeros quedaron afectados por primera vez (SimTime.NONE si no lo están).
var affected_since: int = SimTime.NONE
## Incidencia por la que se informó.
var info_incident_id: StringName = &""


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
