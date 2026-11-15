class_name ScenarioInfo
extends RefCounted
## Metadatos y reglas de un escenario.

var id: StringName = &""
var name: String = ""
var description: String = ""
var line_ids: Array[StringName] = []
var day_start: int = 0
var day_end: int = 86400
var time_scale: int = 1
var seed: int = 0
var min_conductors_per_segment: int = 1
var staff_connection_s: int = 600
var transfer_s: int = 900
var scripted_incidents: Array[Dictionary] = []
## Incidencias aleatorias: desactivadas por defecto (el escenario MVP es guionizado).
var random_incidents_enabled: bool = false
