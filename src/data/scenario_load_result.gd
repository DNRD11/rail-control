class_name ScenarioLoadResult
extends RefCounted
## Resultado de cargar un escenario: mundo + informe de validación.

var world: World
var report: ValidationReport
var ok: bool = false


func _init(p_world: World, p_report: ValidationReport) -> void:
	world = p_world
	report = p_report
	ok = not p_report.has_errors()
