class_name ServiceStop
extends RefCounted
## Punto del itinerario de un servicio (parada o paso).

var index: int = 0
var station_id: StringName = &""
var stop_type: Enums.StopType = Enums.StopType.STOP
var sched_arr: int = SimTime.NONE
var sched_dep: int = SimTime.NONE
var est_arr: int = SimTime.NONE
var est_dep: int = SimTime.NONE
var act_arr: int = SimTime.NONE
var act_dep: int = SimTime.NONE
var min_dwell_s: int = 0
var status: Enums.StopStatus = Enums.StopStatus.PENDING


## Hora programada de llegada (o de salida si no hay llegada).
func entry_time() -> int:
	return sched_arr if sched_arr != SimTime.NONE else sched_dep


## Hora programada de salida (o de llegada si no hay salida).
func exit_time() -> int:
	return sched_dep if sched_dep != SimTime.NONE else sched_arr


func is_stopping() -> bool:
	return stop_type != Enums.StopType.PASS
