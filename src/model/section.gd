class_name Section
extends RefCounted
## Tramo entre dos estaciones adyacentes (infraestructura abstracta del administrador).

var id: StringName = &""
var from_station_id: StringName = &""
var to_station_id: StringName = &""
var length_km: float = 0.0
var run_time_s: int = 0
var stop_penalty_s: int = 180
var track_count: int = 2


## True si el tramo une a y b, en cualquier sentido.
func connects(a: StringName, b: StringName) -> bool:
	return (from_station_id == a and to_station_id == b) or (from_station_id == b and to_station_id == a)
