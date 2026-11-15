class_name IncidentType
extends RefCounted
## Tipo de incidencia definido en data/rules/incidents.json.

var id: StringName = &""
var category: StringName = &""
var title: String = ""
var repair_min_s: int = 0
var repair_max_s: int = 0
var probability_per_hour: float = 0.0
var options: Array[StringName] = []
