class_name CompensationRules
extends RefCounted
## Indemnizaciones por retraso en destino (data/rules/compensation.json). Ver ECONOMY.md §3.

## Tramos ordenados por retraso mínimo ascendente: [{min_delay_s, percent}].
var tiers: Array[Dictionary] = []
var cancellation_percent: int = 100


## Porcentaje del precio medio del trayecto que corresponde a un retraso en llegada.
func percent_for_delay(delay_s: int) -> int:
	var pct: int = 0
	for t: Dictionary in tiers:
		if delay_s >= int(t["min_delay_s"]):
			pct = int(t["percent"])
	return pct
