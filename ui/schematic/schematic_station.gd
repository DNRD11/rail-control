class_name SchematicStation
extends RefCounted
## Estación del esquema (código, nombre corto y punto kilométrico).

var code: String = ""
var short_name: String = ""
var km: float = 0.0


static func make(p_code: String, p_name: String, p_km: float) -> SchematicStation:
	var station := SchematicStation.new()
	station.code = p_code
	station.short_name = p_name
	station.km = p_km
	return station
