class_name Incident
extends RefCounted
## Incidencia de explotación (MVP: avería de material). Ver DATA_MODEL.md §8.

var id: StringName = &""
var type_id: StringName = &""
var severity: int = 1
var status: Enums.IncidentStatus = Enums.IncidentStatus.DETECTED
var detected_at: int = 0
var resolved_at: int = SimTime.NONE
## Servicio afectado y ubicación (tramo + fracción, o estación si está detenido en ella).
var service_id: StringName = &""
var section_id: StringName = &""
var station_id: StringName = &""
var fraction: float = 0.0
var km: float = 0.0
## Último punto del itinerario alcanzado al detectarse (índice de parada, -1 si no había salido).
var stop_index: int = -1
var affected_service_ids: Array[StringName] = []
var composition_id: StringName = &""
var vehicle_id: StringName = &""
## Estado del servicio antes de detenerse (para reanudarlo).
var resume_status: Enums.ServiceStatus = Enums.ServiceStatus.RUNNING
## Rango de reparación mostrado al jugador; `repair_s` real es oculto (sorteado al crearse).
var repair_min_s: int = 0
var repair_max_s: int = 0
var repair_s: int = 0
## Retraso ya aplicado como cota inferior al detectarse (cota mínima de la espera).
var projected_s: int = 0
var options: Array[DecisionOption] = []
var decision: Decision = null
var scripted: bool = false
var timeout_event: SimEvent = null


func option(option_type: StringName) -> DecisionOption:
	for o: DecisionOption in options:
		if o.option_type == option_type:
			return o
	return null


func is_open() -> bool:
	return status != Enums.IncidentStatus.RESOLVED and status != Enums.IncidentStatus.CLOSED
