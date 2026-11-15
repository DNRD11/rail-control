class_name ResolveIncidentCommand
extends Command
## Decisión del jugador sobre una incidencia: elige una de las opciones ofrecidas (OptionType).

var incident_id: StringName = &""
var option_type: StringName = &""
var params: Dictionary = {}


static func make(p_incident_id: StringName, p_option_type: StringName, p_params: Dictionary = {}) -> ResolveIncidentCommand:
	var c: ResolveIncidentCommand = ResolveIncidentCommand.new()
	c.incident_id = p_incident_id
	c.option_type = p_option_type
	c.params = p_params
	return c


func _init() -> void:
	kind = &"RESOLVE_INCIDENT"


func validate(session: SimulationSession) -> String:
	var inc: Incident = session.incidents.get_incident(incident_id)
	if inc == null:
		return "Incidencia desconocida: %s" % incident_id
	return session.incidents.validate_decision(inc, option_type, session)


func apply(session: SimulationSession) -> void:
	session.incidents.decide(incident_id, option_type, params, session)
	session.process_due_events()
