class_name ServicePosition
extends RefCounted
## Posición de un servicio en un instante (solo lectura).

enum State { NOT_STARTED, AT_STATION, IN_SECTION, FINISHED }

var service_id: StringName = &""
var state: State = State.NOT_STARTED
## Parada actual, o punto de inicio del tramo.
var stop_index: int = 0
var section_id: StringName = &""
## Avance 0-1 dentro del tramo (0 en estación).
var fraction: float = 0.0
var direction: Enums.Direction = Enums.Direction.ASCENDING
## Posición en km de la línea.
var km: float = 0.0
