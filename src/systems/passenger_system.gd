class_name PassengerSystem
extends SimSystem
## Viajeros agregados por servicio: contadores (afectados, continúan, necesitan alternativa, con derecho a
## indemnización) e información al viajero (PASSENGER_INFO_SENT). DATA_MODEL.md §7.

const LOG_INFO: StringName = &"PASSENGER_INFO_SENT"
const INFO_NOT_NEEDED: StringName = &"NOT_NEEDED"
const INFO_PENDING: StringName = &"PENDING"
const INFO_EARLY: StringName = &"EARLY"
const INFO_LATE: StringName = &"LATE"
const INFO_MISSING: StringName = &"MISSING"

var messages: Array[PassengerInfoMessage] = []

var _next_message: int = 1


func handles(type: StringName) -> bool:
	return type == SimEventType.PASSENGER_INFO_SENT


func handle(event: SimEvent, session: SimulationSession) -> void:
	var load: ServicePassengerLoad = session.world.passengers.get(event.service_id)
	if load == null or load.informed:
		return
	var m: PassengerInfoMessage = PassengerInfoMessage.new()
	m.id = StringName("msg_%03d" % _next_message)
	_next_message += 1
	m.service_id = event.service_id
	m.time = session.clock.now
	m.incident_id = StringName(String(event.data.get("incident", "")))
	messages.append(m)
	load.informed = true
	load.last_info_time = m.time
	load.info_incident_id = m.incident_id
	session.log.add(session.clock.now, LOG_INFO, m.service_id, -1,
			{"incident": String(m.incident_id), "message": String(m.id)})


## Motivo por el que no se puede informar a los viajeros ("" si es válido).
func validate_inform(session: SimulationSession, service_id: StringName, incident_id: StringName) -> String:
	var s: Service = session.world.services.get(service_id) as Service
	var load: ServicePassengerLoad = session.world.passengers.get(service_id)
	if s == null or load == null:
		return "Servicio sin viajeros: %s" % service_id
	var inc: Incident = session.incidents.get_incident(incident_id)
	if inc == null:
		return "Incidencia desconocida: %s" % incident_id
	if load.informed:
		return "Los viajeros del servicio %s ya han sido informados" % s.code
	var affected: int = PassengerCalc.outcome(session.world, s).affected
	if affected <= 0 and inc.service_id != service_id:
		return "No hay viajeros afectados en el servicio %s" % s.code
	return ""


## Actualiza el estado guardado de un servicio tras un cambio (marca cuándo quedaron afectados).
func on_service_updated(service_id: StringName, session: SimulationSession) -> void:
	var s: Service = session.world.services.get(service_id) as Service
	var load: ServicePassengerLoad = session.world.passengers.get(service_id)
	if s == null or load == null:
		return
	var o: PassengerOutcome = PassengerCalc.outcome(session.world, s)
	if o.affected > 0 and load.affected_since == SimTime.NONE:
		load.affected_since = session.clock.now
	_apply(load, o)


## Copia de solo lectura con los contadores calculados ahora (no modifica el estado guardado).
func snapshot(service_id: StringName, session: SimulationSession) -> ServicePassengerLoad:
	var s: Service = session.world.services.get(service_id) as Service
	var load: ServicePassengerLoad = session.world.passengers.get(service_id)
	if s == null or load == null:
		return null
	var c: ServicePassengerLoad = ServicePassengerLoad.new()
	c.service_id = load.service_id
	c.booked = load.booked
	c.boardings_by_stop = load.boardings_by_stop.duplicate()
	c.alightings_by_stop = load.alightings_by_stop.duplicate()
	c.informed = load.informed
	c.last_info_time = load.last_info_time
	c.info_incident_id = load.info_incident_id
	c.affected_since = load.affected_since
	_apply(c, PassengerCalc.outcome(session.world, s))
	return c


## Estado de la información a los viajeros de un servicio con `affected` afectados (ECONOMY.md §5).
static func info_state(load: ServicePassengerLoad, affected: int, now: int, rules: PerceptionRules) -> StringName:
	if affected <= 0:
		return INFO_NOT_NEEDED
	var since: int = load.affected_since if load.affected_since != SimTime.NONE else now
	if load.informed:
		return INFO_EARLY if load.last_info_time - since <= rules.info_window_s else INFO_LATE
	return INFO_PENDING if now - since <= rules.info_window_s else INFO_MISSING


static func _apply(load: ServicePassengerLoad, o: PassengerOutcome) -> void:
	load.affected = o.affected
	load.needing_alternative = o.needing_alternative
	load.continuing = o.affected - o.needing_alternative
	load.compensation_eligible = o.compensation_eligible
	load.carried = o.carried
