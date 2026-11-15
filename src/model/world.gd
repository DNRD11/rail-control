class_name World
extends RefCounted
## Estado completo de una jornada: entidades indexadas por id.

var scenario: ScenarioInfo = ScenarioInfo.new()
var lines: Dictionary[StringName, Line] = {}
var stations: Dictionary[StringName, Station] = {}
var sections: Dictionary[StringName, Section] = {}
var vehicle_classes: Dictionary[StringName, VehicleClass] = {}
var vehicles: Dictionary[StringName, Vehicle] = {}
var compositions: Dictionary[StringName, Composition] = {}
var staff: Dictionary[StringName, StaffMember] = {}
var services: Dictionary[StringName, Service] = {}
var passengers: Dictionary[StringName, ServicePassengerLoad] = {}
var assignments: AssignmentBook = AssignmentBook.new()
var incident_rules: IncidentRules = IncidentRules.new()
var economy_rules: EconomyRules = EconomyRules.new()
var compensation_rules: CompensationRules = CompensationRules.new()
var perception_rules: PerceptionRules = PerceptionRules.new()


## Tramo que une a y b (cualquier sentido) o null.
func section_between(a: StringName, b: StringName) -> Section:
	for sid: StringName in sections:
		var s: Section = sections[sid]
		if s.connects(a, b):
			return s
	return null


## Plazas totales de una composición (suma de sus vehículos miembros).
func composition_seats(composition_id: StringName) -> int:
	var comp: Composition = compositions.get(composition_id)
	if comp == null:
		return 0
	var total: int = 0
	for m: CompositionMember in comp.members:
		var v: Vehicle = vehicles.get(m.vehicle_id)
		if v == null:
			continue
		var c: VehicleClass = vehicle_classes.get(v.class_id)
		if c != null:
			total += c.seats
	return total
