class_name Vehicle
extends RefCounted
## Unidad de material rodante.

var id: StringName = &""
var number: int = 0
var class_id: StringName = &""
var status: Enums.VehicleStatus = Enums.VehicleStatus.AVAILABLE
var location_station_id: StringName = &""
var km_since_maintenance: float = 0.0
var fault_ids: Array[StringName] = []


func is_usable() -> bool:
	return status == Enums.VehicleStatus.AVAILABLE \
		or status == Enums.VehicleStatus.IN_SERVICE \
		or status == Enums.VehicleStatus.RESERVE
