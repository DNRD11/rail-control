class_name IncidentEffects
extends RefCounted
## Efectos de las decisiones sobre el mundo: asignaciones, servicios, vehículos y costes.
## Cada función rellena la Decision con lo que ha cambiado (trazabilidad). Ver SIMULATION.md §6.

const CAT_INCIDENT: StringName = &"INCIDENT_COST"
const CAT_SUBSTITUTION: StringName = &"SUBSTITUTION_COST"


## Esperar reparación: el servicio queda HELD hasta `held_since + repair_s`. Devuelve la hora de reanudación.
static func wait_repair(session: SimulationSession, inc: Incident, decision: Decision) -> int:
	var resume_at: int = maxi(inc.detected_at + inc.repair_s, session.clock.now)
	decision.resume_at = resume_at
	_cost(decision, CAT_INCIDENT, &"repair_on_route", session.world.incident_rules.repair_on_route_cents)
	return resume_at


## Sustituir material: forma una composición con el vehículo de reserva y le traspasa el resto del itinerario
## (y los servicios posteriores del material averiado). Devuelve la hora de reanudación.
static func substitute(session: SimulationSession, inc: Incident, decision: Decision) -> int:
	var world: World = session.world
	var rules: IncidentRules = world.incident_rules
	var reserve: Vehicle = IncidentOptions.find_reserve(world, inc)
	var positioning: int = IncidentOptions.positioning_seconds(world, reserve, inc)
	var resume_at: int = session.clock.now + positioning + world.scenario.transfer_s
	var comp: Composition = _form_composition(world, reserve, session.clock.now)
	var km: float = absf(_km(world, reserve.location_station_id) - inc.km)
	reserve.location_station_id = &""
	_swap_assignments(session, inc, comp, true, decision, _current_start(world, inc))
	decision.resume_at = resume_at
	_cost(decision, CAT_INCIDENT, &"rescue", rules.rescue_cents)
	_cost(decision, CAT_SUBSTITUTION, &"reserve_mobilization", rules.reserve_mobilization_cents)
	_cost(decision, CAT_SUBSTITUTION, &"empty_run", int(roundf(km * float(rules.empty_run_per_km_cents))))
	session.log.add(session.clock.now, &"SUBSTITUTION_DISPATCHED", inc.service_id, inc.stop_index,
			{"incident": String(inc.id), "composition": String(comp.id), "positioning_s": positioning,
			"resume_at": resume_at})
	return resume_at


## Cancelar el servicio. El material averiado se retira; los servicios posteriores del mismo material pasan
## a la reserva si cubre su estación de salida, y si no se cancelan también.
static func cancel_service(session: SimulationSession, inc: Incident, decision: Decision) -> void:
	var world: World = session.world
	var rules: IncidentRules = world.incident_rules
	var s: Service = world.services[inc.service_id]
	decision.needing_alternative = PassengerCalc.needing_alternative(world, s)
	var dependents: Array[StringName] = IncidentOptions.later_composition_services(session, inc)
	var reserve: Vehicle = IncidentOptions.find_reserve(world, inc) if not dependents.is_empty() else null
	var covered: bool = reserve != null and IncidentOptions.covers_dependents(session, inc, reserve)
	var current_start: int = _current_start(world, inc)
	_cancel_one(session, s, decision)
	_cost(decision, CAT_INCIDENT, &"rescue", rules.rescue_cents)
	if dependents.is_empty():
		return
	if covered:
		var comp: Composition = _form_composition(world, reserve, session.clock.now)
		_swap_assignments(session, inc, comp, false, decision, current_start)
		_cost(decision, CAT_SUBSTITUTION, &"reserve_mobilization", rules.reserve_mobilization_cents)
		return
	for sid: StringName in dependents:
		var dep: Service = world.services[sid]
		decision.needing_alternative += PassengerCalc.booked(world, sid)
		_cancel_one(session, dep, decision)


## Vuelve a poner en servicio el material tras una reparación en ruta (espera).
static func repair_vehicle(world: World, inc: Incident) -> void:
	var v: Vehicle = world.vehicles.get(inc.vehicle_id)
	if v != null and v.status == Enums.VehicleStatus.FAILED:
		v.status = Enums.VehicleStatus.IN_SERVICE


# --- Interno ------------------------------------------------------------------

static func _cancel_one(session: SimulationSession, s: Service, decision: Decision) -> void:
	var partial: bool = s.stops[0].status != Enums.StopStatus.PENDING
	session.movement.cancel(s, partial, session)
	for a: ResourceAssignment in session.world.assignments.for_service(s.id):
		a.status = Enums.AssignmentStatus.CANCELLED
		decision.replaced_assignment_ids.append(a.id)
	decision.cancelled_service_ids.append(s.id)
	session.log.add(session.clock.now, SimEventType.SERVICE_CANCELLED, s.id, -1,
			{"incident": String(decision.incident_id), "partial": partial})
	session.invalidate_rotation_graph()


## Traspasa a `comp` las asignaciones de la composición averiada. Con `include_current`, también el resto del
## servicio afectado (se recorta la asignación original en el punto de la avería).
static func _swap_assignments(session: SimulationSession, inc: Incident, comp: Composition,
		include_current: bool, decision: Decision, current_start: int) -> void:
	var world: World = session.world
	var list: Array[ResourceAssignment] = world.assignments.for_resource(Enums.ResourceType.COMPOSITION,
			inc.composition_id)
	for a: ResourceAssignment in list:
		if a.service_id == inc.service_id:
			if include_current and a.to_stop_index > inc.stop_index:
				_replace_from(world, a, maxi(inc.stop_index, a.from_stop_index), comp, inc, decision)
		elif a.planned_start > current_start:
			_replace_from(world, a, a.from_stop_index, comp, inc, decision)
	session.invalidate_rotation_graph()


## Inicio planificado de la asignación de material del servicio afectado (referencia para «los posteriores»).
static func _current_start(world: World, inc: Incident) -> int:
	for a: ResourceAssignment in world.assignments.for_resource(Enums.ResourceType.COMPOSITION, inc.composition_id):
		if a.service_id == inc.service_id:
			return a.planned_start
	return SimTime.NONE


## Sustituye `a` desde la parada `from_stop` por una asignación de `comp`.
static func _replace_from(world: World, a: ResourceAssignment, from_stop: int, comp: Composition, inc: Incident,
		decision: Decision) -> void:
	var s: Service = world.services[a.service_id]
	var n: ResourceAssignment = ResourceAssignment.new()
	n.id = _unique_id(world, StringName("%s_r" % a.id))
	n.service_id = a.service_id
	n.resource_type = Enums.ResourceType.COMPOSITION
	n.resource_id = comp.id
	n.role = a.role
	n.from_stop_index = from_stop
	n.to_stop_index = a.to_stop_index
	n.from_station_id = s.stops[from_stop].station_id
	n.to_station_id = a.to_station_id
	n.planned_start = s.stops[from_stop].exit_time()
	n.planned_end = a.planned_end
	n.source = Enums.AssignmentSource.INCIDENT_REPLACEMENT
	n.replaces_assignment_id = a.id
	if from_stop > a.from_stop_index:
		# Se conserva el tramo ya recorrido con el material original.
		a.to_stop_index = from_stop
		a.to_station_id = s.stops[from_stop].station_id
		a.planned_end = s.stops[from_stop].entry_time()
		a.actual_end = inc.detected_at
		a.status = Enums.AssignmentStatus.COMPLETED
	else:
		a.status = Enums.AssignmentStatus.REPLACED
	world.assignments.add(n)
	decision.replaced_assignment_ids.append(a.id)
	decision.new_assignment_ids.append(n.id)


static func _unique_id(world: World, base: StringName) -> StringName:
	var taken: Dictionary[StringName, bool] = {}
	for a: ResourceAssignment in world.assignments.all():
		taken[a.id] = true
	var id: StringName = base
	var k: int = 2
	while taken.has(id):
		id = StringName("%s%d" % [base, k])
		k += 1
	return id


static func _form_composition(world: World, vehicle: Vehicle, now: int) -> Composition:
	var comp: Composition = Composition.new()
	var suffix: String = String(vehicle.id).trim_prefix("veh_")
	comp.id = StringName("cmp_res_%s" % suffix)
	comp.formed_at = now
	var m: CompositionMember = CompositionMember.new()
	m.vehicle_id = vehicle.id
	m.position = 1
	m.from_time = now
	comp.members.append(m)
	world.compositions[comp.id] = comp
	vehicle.status = Enums.VehicleStatus.IN_SERVICE
	return comp


static func _cost(decision: Decision, category: StringName, key: StringName, cents: int) -> void:
	if cents == 0:
		return
	decision.cost_lines.append({"category": String(category), "key": String(key), "amount_cents": -cents})


static func _km(world: World, station_id: StringName) -> float:
	var st: Station = world.stations.get(station_id)
	return st.km if st != null else 0.0
