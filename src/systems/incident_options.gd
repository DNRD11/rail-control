class_name IncidentOptions
extends RefCounted
## Calcula las opciones de decisión de una incidencia y su previsualización (estimaciones, no hechos).
## Sin estado: lee la sesión y devuelve DecisionOption. Ver SIMULATION.md §6.

## Por debajo de este retraso un servicio no se considera «afectado» (ON_TIME de DelayInfo).
const NOTICE_MIN_S: int = DelayInfo.MINOR_MAX_S


static func build(session: SimulationSession, inc: Incident) -> Array[DecisionOption]:
	var out: Array[DecisionOption] = []
	var type: IncidentType = session.world.incident_rules.types.get(inc.type_id)
	if type == null:
		return out
	for option_type: StringName in type.options:
		match option_type:
			OptionType.WAIT_REPAIR:
				out.append(_wait(session, inc))
			OptionType.SUBSTITUTE_ROLLING_STOCK:
				out.append(_substitute(session, inc))
			OptionType.CANCEL_SERVICE:
				out.append(_cancel(session, inc))
	return out


# --- Opciones -----------------------------------------------------------------

static func _wait(session: SimulationSession, inc: Incident) -> DecisionOption:
	var world: World = session.world
	var s: Service = world.services[inc.service_id]
	var o: DecisionOption = DecisionOption.new()
	o.option_type = OptionType.WAIT_REPAIR
	var base: int = base_delay(s, inc)
	var p: OptionPreview = o.preview
	p.own_delay_min_s = base + inc.repair_min_s
	p.own_delay_max_s = base + inc.repair_max_s
	p.cost_cents = world.incident_rules.repair_on_route_cents
	var worst: Array[Dictionary] = project_dependents(session, s, p.own_delay_max_s)
	var best: Array[Dictionary] = project_dependents(session, s, p.own_delay_min_s)
	p.dependents = _merge_ranges(best, worst)
	p.affected_passengers = _affected(world, s, p.own_delay_max_s, worst)
	return o


static func _substitute(session: SimulationSession, inc: Incident) -> DecisionOption:
	var world: World = session.world
	var s: Service = world.services[inc.service_id]
	var o: DecisionOption = DecisionOption.new()
	o.option_type = OptionType.SUBSTITUTE_ROLLING_STOCK
	var reserve: Vehicle = find_reserve(world, inc)
	if reserve == null:
		o.available = false
		o.unavailable_reason = "No hay material de reserva disponible."
		return o
	var rules: IncidentRules = world.incident_rules
	var positioning: int = positioning_seconds(world, reserve, inc)
	var p: OptionPreview = o.preview
	p.reserve_vehicle_id = reserve.id
	p.resume_at = session.clock.now + positioning + world.scenario.transfer_s
	var delay: int = base_delay(s, inc) + (p.resume_at - inc.detected_at)
	p.own_delay_min_s = delay
	p.own_delay_max_s = delay
	var km: float = absf(_station_km(world, reserve.location_station_id) - inc.km)
	p.cost_cents = rules.rescue_cents + rules.reserve_mobilization_cents \
			+ int(roundf(km * float(rules.empty_run_per_km_cents)))
	p.dependents = project_dependents(session, s, delay)
	p.affected_passengers = _affected(world, s, delay, p.dependents)
	p.seats_short = maxi(PassengerCalc.booked(world, s.id) - _vehicle_seats(world, reserve), 0)
	o.params = {"vehicle_id": reserve.id}
	return o


static func _cancel(session: SimulationSession, inc: Incident) -> DecisionOption:
	var world: World = session.world
	var s: Service = world.services[inc.service_id]
	var o: DecisionOption = DecisionOption.new()
	o.option_type = OptionType.CANCEL_SERVICE
	var p: OptionPreview = o.preview
	var rules: IncidentRules = world.incident_rules
	p.cost_cents = rules.rescue_cents
	p.cancelled_service_ids.append(s.id)
	p.needing_alternative = PassengerCalc.needing_alternative(world, s)
	p.affected_passengers = p.needing_alternative
	var dependents: Array[StringName] = later_composition_services(session, inc)
	if not dependents.is_empty():
		var reserve: Vehicle = find_reserve(world, inc)
		if reserve != null and covers_dependents(session, inc, reserve):
			p.reserve_vehicle_id = reserve.id
			p.cost_cents += rules.reserve_mobilization_cents
			o.params = {"vehicle_id": reserve.id}
		else:
			for sid: StringName in dependents:
				p.cancelled_service_ids.append(sid)
				p.needing_alternative += PassengerCalc.booked(world, sid)
				p.affected_passengers += PassengerCalc.booked(world, sid)
	return o


# --- Utilidades ---------------------------------------------------------------

## Retraso vigente del servicio sin la cota mínima ya aplicada al detectarse la avería.
static func base_delay(s: Service, inc: Incident) -> int:
	return maxi(DelaySystem.seconds_of(s) - inc.projected_s, 0)


## Material de reserva utilizable: vehículo RESERVE sin asignaciones vivas, de la misma clase que el averiado.
static func find_reserve(world: World, inc: Incident) -> Vehicle:
	var failed: Vehicle = world.vehicles.get(inc.vehicle_id)
	var ids: Array[StringName] = []
	for vid: StringName in world.vehicles:
		ids.append(vid)
	ids.sort()
	for vid: StringName in ids:
		var v: Vehicle = world.vehicles[vid]
		if v.status != Enums.VehicleStatus.RESERVE or v.location_station_id == &"":
			continue
		if failed != null and v.class_id != failed.class_id:
			continue
		if _in_composition_with_work(world, v.id):
			continue
		return v
	return null


static func _in_composition_with_work(world: World, vehicle_id: StringName) -> bool:
	for cid: StringName in world.compositions:
		var c: Composition = world.compositions[cid]
		if c.vehicle_ids().has(vehicle_id) \
				and not world.assignments.for_resource(Enums.ResourceType.COMPOSITION, cid).is_empty():
			return true
	return false


## Segundos de posicionamiento en vacío desde la estación del vehículo de reserva hasta el punto de la avería.
static func positioning_seconds(world: World, reserve: Vehicle, inc: Incident) -> int:
	var dist: float = absf(_station_km(world, reserve.location_station_id) - inc.km)
	return int(ceilf(dist / float(world.incident_rules.positioning_speed_kmh) * 3600.0))


## Servicios posteriores del mismo material (composición averiada), en orden cronológico.
static func later_composition_services(session: SimulationSession, inc: Incident) -> Array[StringName]:
	var out: Array[StringName] = []
	var chain: Array[StringName] = session.rotation_graph().chain(Enums.ResourceType.COMPOSITION, inc.composition_id)
	var seen: bool = false
	for sid: StringName in chain:
		if sid == inc.service_id:
			seen = true
		elif seen:
			out.append(sid)
	return out


## True si el vehículo de reserva está en la estación donde empieza el primer servicio dependiente.
static func covers_dependents(session: SimulationSession, inc: Incident, reserve: Vehicle) -> bool:
	var later: Array[StringName] = later_composition_services(session, inc)
	if later.is_empty():
		return true
	var list: Array[ResourceAssignment] = session.world.assignments.for_resource(
			Enums.ResourceType.COMPOSITION, inc.composition_id)
	for a: ResourceAssignment in list:
		if a.service_id == later[0]:
			return a.from_station_id == reserve.location_station_id
	return false


## Retraso previsto (s) de cada servicio dependiente si `service` termina su asignación con `end_delay_s`.
## Devuelve [{service_id, delay_min_s, delay_max_s}] (min == max) para los que heredan retraso apreciable.
static func project_dependents(session: SimulationSession, service: Service, end_delay_s: int) -> Array[Dictionary]:
	var world: World = session.world
	var graph: RotationGraph = session.rotation_graph()
	var order: Array[StringName] = graph.downstream(service.id)
	order.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da: int = (world.services[a] as Service).scheduled_departure()
		var db: int = (world.services[b] as Service).scheduled_departure()
		return da < db if da != db else String(a) < String(b))
	var delays: Dictionary[StringName, int] = {service.id: end_delay_s}
	var out: Array[Dictionary] = []
	for bid: StringName in order:
		var b: Service = world.services[bid]
		if b.status == Enums.ServiceStatus.TERMINATED or b.is_cancelled():
			continue
		var worst: int = 0
		for e: RotationEdge in graph.incoming(bid):
			if not delays.has(e.from_service_id) or e.to_start_stop >= b.stops.size():
				continue
			var a: Service = world.services[e.from_service_id]
			var sb: ServiceStop = b.stops[e.to_start_stop]
			if sb.status == Enums.StopStatus.DEPARTED or sb.status == Enums.StopStatus.PASSED:
				continue
			var ready: int = a.stops[e.from_end_stop].entry_time() + delays[e.from_service_id] + e.min_connection_s
			var dep: int = maxi(sb.est_dep, ready) if sb.est_dep != SimTime.NONE else ready
			worst = maxi(worst, dep - sb.exit_time())
		if worst > 0:
			delays[bid] = worst
			if worst > NOTICE_MIN_S:
				out.append({"service_id": bid, "delay_min_s": worst, "delay_max_s": worst})
	return out


static func _merge_ranges(best: Array[Dictionary], worst: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in worst:
		var lo: int = 0
		for b: Dictionary in best:
			if b["service_id"] == w["service_id"]:
				lo = int(b["delay_min_s"])
		out.append({"service_id": w["service_id"], "delay_min_s": lo, "delay_max_s": int(w["delay_max_s"])})
	return out


## Viajeros de los servicios que quedarían con retraso apreciable (propio y dependientes).
static func _affected(world: World, s: Service, own_delay_s: int, dependents: Array[Dictionary]) -> int:
	var n: int = PassengerCalc.booked(world, s.id) if own_delay_s > NOTICE_MIN_S else 0
	for d: Dictionary in dependents:
		n += PassengerCalc.booked(world, d["service_id"])
	return n


static func _station_km(world: World, station_id: StringName) -> float:
	var st: Station = world.stations.get(station_id)
	return st.km if st != null else 0.0


static func _vehicle_seats(world: World, v: Vehicle) -> int:
	var c: VehicleClass = world.vehicle_classes.get(v.class_id)
	return c.seats if c != null else 0
