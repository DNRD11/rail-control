class_name IncidentRules
extends RefCounted
## Reglas de incidencias cargadas de datos: tipos, costes y parámetros de decisión.

var types: Dictionary[StringName, IncidentType] = {}
var decision_timeout_s: int = 900
var default_option: StringName = OptionType.WAIT_REPAIR
var positioning_speed_kmh: int = 200
var repair_on_route_cents: int = 0
var rescue_cents: int = 0
var reserve_mobilization_cents: int = 0
var empty_run_per_km_cents: int = 0
