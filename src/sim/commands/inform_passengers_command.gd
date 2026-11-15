class_name InformPassengersCommand
extends Command
## Informa a los viajeros de un servicio afectado por una incidencia. Registra un PassengerInfoMessage y marca
## el servicio como informado; afecta a la percepción (informar pronto bonifica, no informar penaliza).

var service_id: StringName = &""
var incident_id: StringName = &""


func _init(p_service_id: StringName = &"", p_incident_id: StringName = &"") -> void:
	kind = &"INFORM_PASSENGERS"
	service_id = p_service_id
	incident_id = p_incident_id


static func make(p_service_id: StringName, p_incident_id: StringName) -> InformPassengersCommand:
	return InformPassengersCommand.new(p_service_id, p_incident_id)


func validate(session: SimulationSession) -> String:
	return session.passenger.validate_inform(session, service_id, incident_id)


func apply(session: SimulationSession) -> void:
	session.queue.push(SimEventType.PASSENGER_INFO_SENT, session.clock.now, service_id, -1,
			{"incident": String(incident_id)})
	session.process_due_events()
