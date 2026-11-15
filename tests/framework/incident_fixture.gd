class_name IncidentFixture
extends RefCounted
## Utilidades de prueba de incidencias: avería guionizada del 3103 a las 08:12 con reparación fija opcional.

const D = preload("res://tests/framework/delay_fixture.gd")
const REPAIR_SHORT: int = 1500
const REPAIR_LONG: int = 5400


## Sesión avanzada hasta justo después de detectarse la avería (08:12).
static func detected(repair_s: int = REPAIR_LONG) -> SimulationSession:
	var s: SimulationSession = SimFixture.session_with_incident(12345, repair_s)
	D.run_to_text(s, "08:12")
	return s


static func incident(s: SimulationSession) -> Incident:
	var all: Array[Incident] = s.all_incidents()
	return all[0] if not all.is_empty() else null


static func decide(s: SimulationSession, option_type: StringName) -> bool:
	return s.apply_command(ResolveIncidentCommand.make(incident(s).id, option_type))


static func comp_of(s: SimulationSession, service_id: StringName, segment: int = 0) -> StringName:
	var list: Array[ResourceAssignment] = s.world.assignments.for_segment(service_id,
			Enums.ResourceType.COMPOSITION, segment)
	return list[0].resource_id if not list.is_empty() else &""
