class_name IncidentSystem
extends SimSystem
## Incidencias de explotación (MVP: avería de material). Crea incidencias guionizadas o aleatorias,
## detiene el servicio, ofrece opciones con previsualización y aplica la decisión (jugador o tiempo
## agotado). Ver SIMULATION.md §6.
##
## Retraso: al detectarse la avería se aplica como cota inferior min(reparación mínima, transbordo);
## al reanudar se aplica el resto (tiempo detenido real - cota). Así las estimaciones solo avanzan.

const LOG_DETECTED: StringName = &"INCIDENT_DETECTED"
const LOG_DECISION: StringName = &"DECISION_TAKEN"
const LOG_RESOLVED: StringName = &"INCIDENT_RESOLVED"
const LOG_SKIPPED: StringName = &"INCIDENT_SKIPPED"

var incidents: Array[Incident] = []

var _by_id: Dictionary[StringName, Incident] = {}
var _next_incident: int = 1
var _next_decision: int = 1


func start(session: SimulationSession) -> void:
	var sc: ScenarioInfo = session.world.scenario
	for d: Dictionary in sc.scripted_incidents:
		if not bool(d.get("enabled", true)):
			continue
		var t: int = SimTime.parse(String(d.get("time", "")))
		if t == SimTime.NONE or t < session.clock.now:
			continue
		session.queue.push(SimEventType.INCIDENT_TRIGGER, t, StringName(String(d.get("service", ""))), -1,
				{"type": String(d.get("type", "")), "scripted_id": String(d.get("id", "")),
				"severity": int(d.get("severity", 1)), "repair_s": d.get("repair_s", [])})
	if sc.random_incidents_enabled:
		_schedule_random(session)


func handles(type: StringName) -> bool:
	return type == SimEventType.INCIDENT_TRIGGER or type == SimEventType.INCIDENT_RESOLVED \
			or type == SimEventType.DECISION_TIMEOUT


func handle(event: SimEvent, session: SimulationSession) -> void:
	match event.type:
		SimEventType.INCIDENT_TRIGGER:
			_trigger(event, session)
		SimEventType.INCIDENT_RESOLVED:
			_resolve_event(event, session)
		SimEventType.DECISION_TIMEOUT:
			var inc: Incident = _by_id.get(StringName(String(event.data.get("incident", ""))))
			if inc != null and inc.status == Enums.IncidentStatus.AWAITING_DECISION:
				_decide(inc, _default_option(session, inc), {}, session, true)


# --- Consultas ----------------------------------------------------------------

func get_incident(id: StringName) -> Incident:
	return _by_id.get(id)


## Incidencias que requieren atención o siguen en curso.
func open_incidents() -> Array[Incident]:
	var out: Array[Incident] = []
	for inc: Incident in incidents:
		if inc.is_open():
			out.append(inc)
	return out


func awaiting_decision() -> Array[Incident]:
	var out: Array[Incident] = []
	for inc: Incident in incidents:
		if inc.status == Enums.IncidentStatus.AWAITING_DECISION:
			out.append(inc)
	return out


## Recalcula las previsualizaciones con el estado actual (la hora de decisión cambia las estimaciones).
func refresh_options(inc: Incident, session: SimulationSession) -> void:
	if inc.status == Enums.IncidentStatus.AWAITING_DECISION:
		inc.options = IncidentOptions.build(session, inc)


## Aplica la decisión del jugador. Devuelve "" si se aplicó o el motivo del rechazo.
func decide(incident_id: StringName, option_type: StringName, params: Dictionary,
		session: SimulationSession) -> String:
	var inc: Incident = _by_id.get(incident_id)
	if inc == null:
		return "Incidencia desconocida: %s" % incident_id
	var reason: String = validate_decision(inc, option_type, session)
	if reason != "":
		return reason
	_decide(inc, option_type, params, session, false)
	return ""


func validate_decision(inc: Incident, option_type: StringName, session: SimulationSession) -> String:
	if inc.status != Enums.IncidentStatus.AWAITING_DECISION:
		return "La incidencia %s no espera ninguna decisión" % inc.id
	refresh_options(inc, session)
	var opt: DecisionOption = inc.option(option_type)
	if opt == null:
		return "Opción no ofrecida para esta incidencia: %s" % option_type
	if not opt.available:
		return opt.unavailable_reason if opt.unavailable_reason != "" else "Opción no disponible"
	return ""


# --- Creación -----------------------------------------------------------------

func _trigger(event: SimEvent, session: SimulationSession) -> void:
	var world: World = session.world
	var type: IncidentType = world.incident_rules.types.get(StringName(String(event.data.get("type", ""))))
	var random: bool = event.service_id == &""
	var s: Service = _pick_service(session) if random else world.services.get(event.service_id) as Service
	var why: String = _ineligible(session, s, type)
	if why != "":
		session.log.add(session.clock.now, LOG_SKIPPED, event.service_id, -1, {"reason": why})
		return
	var comp: Composition = _current_composition(world, s)
	var pos: ServicePosition = ServicePositionCalc.compute(world, s, session.clock.now)
	var inc: Incident = Incident.new()
	inc.id = StringName("inc_%03d" % _next_incident)
	_next_incident += 1
	inc.type_id = type.id
	inc.severity = int(event.data.get("severity", 1))
	inc.detected_at = session.clock.now
	inc.service_id = s.id
	inc.scripted = not random
	inc.affected_service_ids = [s.id]
	inc.stop_index = pos.stop_index if pos.state != ServicePosition.State.NOT_STARTED else -1
	inc.section_id = pos.section_id
	inc.fraction = pos.fraction
	inc.km = pos.km
	if pos.state != ServicePosition.State.IN_SECTION:
		inc.station_id = s.stops[maxi(pos.stop_index, 0)].station_id
	inc.composition_id = comp.id
	inc.vehicle_id = comp.members[_failed_member(comp, random, session)].vehicle_id
	inc.resume_status = s.status
	_draw_repair(inc, type, event.data.get("repair_s", []), session)
	var vehicle: Vehicle = world.vehicles.get(inc.vehicle_id)
	if vehicle != null:
		vehicle.status = Enums.VehicleStatus.FAILED
	incidents.append(inc)
	_by_id[inc.id] = inc
	s.incident_ids.append(inc.id)
	s.held_fraction = pos.fraction
	s.held_since = session.clock.now
	inc.projected_s = mini(inc.repair_min_s, world.scenario.transfer_s)
	session.delay.apply_delay(s, inc.projected_s, DelayInfo.CAUSE_BREAKDOWN, session)
	session.movement.hold(s, session)
	session.log.add(session.clock.now, LOG_DETECTED, s.id, inc.stop_index,
			{"incident": String(inc.id), "type": String(inc.type_id), "section": String(inc.section_id),
			"fraction": snappedf(inc.fraction, 0.001), "vehicle": String(inc.vehicle_id),
			"repair_range_s": [inc.repair_min_s, inc.repair_max_s]})
	inc.options = IncidentOptions.build(session, inc)
	inc.status = Enums.IncidentStatus.AWAITING_DECISION
	inc.timeout_event = session.queue.push(SimEventType.DECISION_TIMEOUT,
			session.clock.now + world.incident_rules.decision_timeout_s, s.id, -1, {"incident": String(inc.id)})
	session.incident_changed.emit(inc.id)


## Motivo por el que no se puede crear la incidencia ("" si es válida).
func _ineligible(session: SimulationSession, s: Service, type: IncidentType) -> String:
	if type == null:
		return "tipo desconocido"
	if s == null:
		return "no hay servicio candidato"
	if s.status != Enums.ServiceStatus.RUNNING and s.status != Enums.ServiceStatus.STOPPED_AT_STATION:
		return "el servicio %s no está en circulación" % s.code
	for inc: Incident in incidents:
		if inc.is_open() and inc.service_id == s.id:
			return "el servicio %s ya tiene una incidencia abierta" % s.code
	if _current_composition(session.world, s) == null:
		return "el servicio %s no lleva composición" % s.code
	return ""


func _current_composition(world: World, s: Service) -> Composition:
	var last: int = SessionQueries.last_reached(s)
	var list: Array[ResourceAssignment] = []
	if last >= 0 and s.stops[last].status == Enums.StopStatus.ARRIVED:
		list = world.assignments.at_stop(s.id, Enums.ResourceType.COMPOSITION, last)
	elif last >= 0:
		list = world.assignments.for_segment(s.id, Enums.ResourceType.COMPOSITION, last)
	for a: ResourceAssignment in list:
		var comp: Composition = world.compositions.get(a.resource_id)
		if comp != null and not comp.members.is_empty():
			return comp
	return null


func _failed_member(comp: Composition, random: bool, session: SimulationSession) -> int:
	return session.rng.randi() % comp.members.size() if random and comp.members.size() > 1 else 0


## Sortea el tiempo de reparación real (oculto). Siempre consume una extracción del RNG.
func _draw_repair(inc: Incident, type: IncidentType, override: Variant, session: SimulationSession) -> void:
	inc.repair_min_s = type.repair_min_s
	inc.repair_max_s = type.repair_max_s
	if typeof(override) == TYPE_ARRAY and (override as Array).size() == 2:
		inc.repair_min_s = int((override as Array)[0])
		inc.repair_max_s = maxi(int((override as Array)[1]), inc.repair_min_s)
	inc.repair_s = session.rng.randi_range(inc.repair_min_s, inc.repair_max_s)


func _pick_service(session: SimulationSession) -> Service:
	var candidates: Array[Service] = []
	for sid: StringName in session.service_ids():
		var s: Service = session.world.services[sid]
		if s.kind == Enums.ServiceKind.COMMERCIAL and (s.status == Enums.ServiceStatus.RUNNING \
				or s.status == Enums.ServiceStatus.STOPPED_AT_STATION):
			candidates.append(s)
	if candidates.is_empty():
		return null
	return candidates[session.rng.randi() % candidates.size()]


## Averías aleatorias: todas las extracciones al arrancar (independientes del tamaño de paso).
func _schedule_random(session: SimulationSession) -> void:
	var ids: Array[StringName] = []
	for tid: StringName in session.world.incident_rules.types:
		ids.append(tid)
	ids.sort()
	var t: int = session.clock.day_start
	while t < session.clock.day_end:
		for tid: StringName in ids:
			var type: IncidentType = session.world.incident_rules.types[tid]
			if type.probability_per_hour > 0.0 and session.rng.randf() < type.probability_per_hour:
				var at: int = t + session.rng.randi_range(0, 3599)
				if at < session.clock.day_end:
					session.queue.push(SimEventType.INCIDENT_TRIGGER, at, &"", -1,
							{"type": String(tid), "severity": 1})
		t += 3600


# --- Decisión y resolución ----------------------------------------------------

func _default_option(session: SimulationSession, inc: Incident) -> StringName:
	refresh_options(inc, session)
	var wanted: StringName = session.world.incident_rules.default_option
	var opt: DecisionOption = inc.option(wanted)
	if opt != null and opt.available:
		return wanted
	return OptionType.WAIT_REPAIR


func _decide(inc: Incident, option_type: StringName, params: Dictionary, session: SimulationSession,
		automatic: bool) -> void:
	if inc.timeout_event != null:
		inc.timeout_event.cancelled = true
	var d: Decision = Decision.new()
	d.id = StringName("dec_%03d" % _next_decision)
	_next_decision += 1
	d.incident_id = inc.id
	d.option_type = option_type
	d.params = params
	d.time = session.clock.now
	d.automatic = automatic
	inc.decision = d
	var resume_at: int = SimTime.NONE
	match option_type:
		OptionType.WAIT_REPAIR:
			resume_at = IncidentEffects.wait_repair(session, inc, d)
		OptionType.SUBSTITUTE_ROLLING_STOCK:
			resume_at = IncidentEffects.substitute(session, inc, d)
		OptionType.CANCEL_SERVICE:
			IncidentEffects.cancel_service(session, inc, d)
	_project_known_hold(inc, option_type, resume_at, session)
	session.log.add(session.clock.now, LOG_DECISION, inc.service_id, -1,
			{"incident": String(inc.id), "option": String(option_type), "automatic": automatic,
			"cost_cents": d.total_cost_cents(), "cancelled": _ids_text(d.cancelled_service_ids)})
	if resume_at != SimTime.NONE:
		inc.status = Enums.IncidentStatus.IN_PROGRESS
		session.queue.push(SimEventType.INCIDENT_RESOLVED, resume_at, inc.service_id, -1,
				{"incident": String(inc.id)})
		session.service_updated.emit(inc.service_id)
	else:
		_close(inc, session)
	session.incident_changed.emit(inc.id)


## Tras decidir, el retraso previsto debe cubrir lo que ya se sabe de la parada (si no, el material que rota
## saldría a su hora mientras el servicio sigue detenido). Esperar: cota inferior (reparación mínima, la real
## es oculta); sustituir: la hora de reanudación conocida.
func _project_known_hold(inc: Incident, option_type: StringName, resume_at: int, session: SimulationSession) -> void:
	if resume_at == SimTime.NONE:
		return
	var known: int = inc.repair_min_s if option_type == OptionType.WAIT_REPAIR else resume_at - inc.detected_at
	var extra: int = known - inc.projected_s
	if extra <= 0:
		return
	var s: Service = session.world.services[inc.service_id]
	session.delay.apply_delay(s, extra, DelayInfo.CAUSE_BREAKDOWN, session)
	inc.projected_s = known


func _resolve_event(event: SimEvent, session: SimulationSession) -> void:
	var inc: Incident = _by_id.get(StringName(String(event.data.get("incident", ""))))
	if inc == null or inc.status != Enums.IncidentStatus.IN_PROGRESS:
		return
	var s: Service = session.world.services[inc.service_id]
	if s.status == Enums.ServiceStatus.HELD:
		var held_total: int = session.clock.now - inc.detected_at
		session.delay.apply_delay(s, held_total - inc.projected_s, DelayInfo.CAUSE_BREAKDOWN, session)
		session.movement.release(s, inc.resume_status, session)
	if inc.decision.option_type == OptionType.WAIT_REPAIR:
		IncidentEffects.repair_vehicle(session.world, inc)
	_close(inc, session)
	session.incident_changed.emit(inc.id)


func _close(inc: Incident, session: SimulationSession) -> void:
	inc.status = Enums.IncidentStatus.RESOLVED
	inc.resolved_at = session.clock.now
	session.log.add(session.clock.now, LOG_RESOLVED, inc.service_id, -1,
			{"incident": String(inc.id), "option": String(inc.decision.option_type)})


func _ids_text(ids: Array[StringName]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id: StringName in ids:
		parts.append(String(id))
	return ",".join(parts)
