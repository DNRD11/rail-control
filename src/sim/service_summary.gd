class_name ServiceSummary
extends RefCounted
## Resumen de un servicio para listas y panel de detalle (solo lectura).

var service_id: StringName = &""
var code: String = ""
## «Madrid → Zaragoza».
var route_text: String = ""
var status: Enums.ServiceStatus = Enums.ServiceStatus.SCHEDULED
## Retraso vigente en segundos (ver SimulationSession.delay_of).
var delay: int = 0
## Siguiente punto con parada pendiente, o -1.
var next_stop_index: int = -1
var next_stop_station_id: StringName = &""
## Hora estimada de llegada (de salida si es el origen sin salir), SimTime.NONE si no hay.
var next_stop_eta: int = SimTime.NONE
var booked: int = 0
var seats: int = 0
