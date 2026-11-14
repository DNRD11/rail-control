class_name SchematicService
extends RefCounted
## Datos de presentación de un servicio para el esquema. La UI solo lee; en fases
## posteriores se rellenará desde la simulación (interpolando la posición).

var code: String = ""
## +1 = sentido MAD→BCN (vía inferior); -1 = BCN→MAD (vía superior).
var direction: int = 1
var km: float = 0.0
## Posición teórica según horario (para la «sombra programada»).
var scheduled_km: float = 0.0
var delay_min: int = 0
var state: RcTokens.State = RcTokens.State.OK
var broken: bool = false
## Cadena de rotación: estación donde el material enlaza con el siguiente servicio.
var chain_km: float = -1.0
var chain_label: String = ""


func chip_text() -> String:
	if delay_min > 0:
		return "+%d′" % delay_min
	return "EN HORA"
