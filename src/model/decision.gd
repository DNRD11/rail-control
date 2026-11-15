class_name Decision
extends RefCounted
## Decisión tomada sobre una incidencia y sus consecuencias registradas.

var id: StringName = &""
var incident_id: StringName = &""
var option_type: StringName = &""
var params: Dictionary = {}
var time: int = 0
## True si la aplicó DECISION_TIMEOUT en lugar del jugador.
var automatic: bool = false
## Líneas de coste: [{category, key, amount_cents}] (amount_cents negativo = coste). Las recoge la economía (Fase 6).
var cost_lines: Array[Dictionary] = []
var cancelled_service_ids: Array[StringName] = []
var replaced_assignment_ids: Array[StringName] = []
var new_assignment_ids: Array[StringName] = []
## Viajeros que necesitan alternativa por cancelación.
var needing_alternative: int = 0
var resume_at: int = SimTime.NONE


func total_cost_cents() -> int:
	var t: int = 0
	for line: Dictionary in cost_lines:
		t += int(line["amount_cents"])
	return t
