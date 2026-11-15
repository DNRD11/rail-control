class_name Service
extends RefCounted
## Circulación comercial o especial. No contiene recursos: se ligan con ResourceAssignment.

var id: StringName = &""
var code: String = ""
var kind: Enums.ServiceKind = Enums.ServiceKind.COMMERCIAL
var origin_station_id: StringName = &""
var destination_station_id: StringName = &""
var stops: Array[ServiceStop] = []
var status: Enums.ServiceStatus = Enums.ServiceStatus.SCHEDULED
var incident_ids: Array[StringName] = []
var origin_ref: String = ""
## Mientras está HELD: fracción congelada del tramo en curso y hora de la detención.
var held_fraction: float = 0.0
var held_since: int = SimTime.NONE


## Número de segmentos (tramos entre puntos consecutivos del itinerario).
func segment_count() -> int:
	return maxi(stops.size() - 1, 0)


func scheduled_departure() -> int:
	return stops[0].exit_time() if not stops.is_empty() else SimTime.NONE


func scheduled_arrival() -> int:
	return stops[stops.size() - 1].entry_time() if not stops.is_empty() else SimTime.NONE


## Índice de la primera parada en la estación, o -1.
func stop_index_of(station_id: StringName) -> int:
	for i: int in stops.size():
		if stops[i].station_id == station_id:
			return i
	return -1


func is_cancelled() -> bool:
	return status == Enums.ServiceStatus.CANCELLED or status == Enums.ServiceStatus.PARTIALLY_CANCELLED
