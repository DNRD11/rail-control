class_name SessionQueries
extends RefCounted
## Consultas de solo lectura sobre el mundo para la UI (servicio: recursos, cadena, resumen). Sin estado.


static func service_ids(world: World) -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in world.services:
		out.append(sid)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ca: String = (world.services[a] as Service).code
		var cb: String = (world.services[b] as Service).code
		return ca < cb if ca != cb else String(a) < String(b))
	return out


static func label_of(world: World, type: Enums.ResourceType, rid: StringName) -> String:
	match type:
		Enums.ResourceType.COMPOSITION:
			var t: String = String(rid)
			return (t.substr(4) if t.begins_with("cmp_") else t).to_upper()
		Enums.ResourceType.VEHICLE:
			var v: Vehicle = world.vehicles.get(rid)
			return str(v.number) if v != null else String(rid)
		_:
			var m: StaffMember = world.staff.get(rid)
			return m.name if m != null else String(rid)


## Índice del último punto ya alcanzado (con salida, llegada o paso), o -1.
static func last_reached(s: Service) -> int:
	var last: int = -1
	for i: int in s.stops.size():
		if s.stops[i].status != Enums.StopStatus.PENDING:
			last = i
	return last


static func service_resources(world: World, service_id: StringName) -> Array[ResourceSlot]:
	var out: Array[ResourceSlot] = []
	var s: Service = world.services.get(service_id) as Service
	if s == null:
		return out
	var list: Array[ResourceAssignment] = world.assignments.for_service(service_id)
	list.sort_custom(func(a: ResourceAssignment, b: ResourceAssignment) -> bool:
		if a.resource_type != b.resource_type:
			return a.resource_type < b.resource_type
		if a.from_stop_index != b.from_stop_index:
			return a.from_stop_index < b.from_stop_index
		return String(a.id) < String(b.id))
	for a: ResourceAssignment in list:
		var slot: ResourceSlot = ResourceSlot.new()
		slot.resource_type = a.resource_type
		slot.resource_id = a.resource_id
		slot.label = label_of(world, a.resource_type, a.resource_id)
		slot.role = a.role
		slot.from_stop_index = a.from_stop_index
		slot.to_stop_index = a.to_stop_index
		slot.from_station_id = a.from_station_id
		slot.to_station_id = a.to_station_id
		slot.assignment_id = a.id
		slot.is_current = _is_current(s, a)
		out.append(slot)
	return out


## Segmento en curso; si el servicio está detenido en una parada, la parada (extremos incluidos).
static func _is_current(s: Service, a: ResourceAssignment) -> bool:
	match s.status:
		Enums.ServiceStatus.SCHEDULED:
			return a.covers_segment(0)
		Enums.ServiceStatus.TERMINATED, Enums.ServiceStatus.CANCELLED, Enums.ServiceStatus.PARTIALLY_CANCELLED:
			return false
	var last: int = last_reached(s)
	if last < 0:
		return a.covers_segment(0)
	if s.stops[last].status == Enums.StopStatus.ARRIVED:
		return a.covers_stop(last)
	return a.covers_segment(last)


static func service_chain(world: World, graph: RotationGraph, service_id: StringName) -> Array[ChainLink]:
	var out: Array[ChainLink] = []
	var a: Service = world.services.get(service_id) as Service
	if a == null:
		return out
	for e: RotationEdge in graph.outgoing(service_id):
		var b: Service = world.services.get(e.to_service_id) as Service
		if b == null or e.from_end_stop >= a.stops.size() or e.to_start_stop >= b.stops.size():
			continue
		var sa: ServiceStop = a.stops[e.from_end_stop]
		var sb: ServiceStop = b.stops[e.to_start_stop]
		var arrival: int = sa.act_arr if sa.act_arr != SimTime.NONE else sa.est_arr
		var dep: int = sb.act_dep if sb.act_dep != SimTime.NONE else sb.est_dep
		var link: ChainLink = ChainLink.new()
		link.resource_type = e.resource_type
		link.resource_id = e.resource_id
		link.label = label_of(world, e.resource_type, e.resource_id)
		link.next_service_id = e.to_service_id
		link.station_id = e.station_id
		link.is_material = e.resource_type == Enums.ResourceType.COMPOSITION
		link.next_departure = dep
		if arrival != SimTime.NONE and dep != SimTime.NONE:
			link.margin_s = dep - (arrival + e.min_connection_s)
			link.predicted_delay_s = maxi(dep - sb.exit_time(), 0)
		else:
			link.margin_s = e.margin_s
		out.append(link)
	return out


static func service_summary(world: World, service_id: StringName) -> ServiceSummary:
	var s: Service = world.services.get(service_id) as Service
	if s == null:
		return null
	var sum: ServiceSummary = ServiceSummary.new()
	sum.service_id = s.id
	sum.code = s.code
	sum.status = s.status
	sum.delay = DelaySystem.seconds_of(s)
	sum.route_text = "%s → %s" % [_station_name(world, s.origin_station_id), _station_name(world, s.destination_station_id)]
	for i: int in s.stops.size():
		var st: ServiceStop = s.stops[i]
		if st.status == Enums.StopStatus.PENDING and st.is_stopping():
			sum.next_stop_index = i
			sum.next_stop_station_id = st.station_id
			sum.next_stop_eta = st.est_arr if st.est_arr != SimTime.NONE else st.est_dep
			break
	var load: ServicePassengerLoad = world.passengers.get(service_id)
	sum.booked = load.booked if load != null else 0
	for slot: ResourceSlot in service_resources(world, service_id):
		if slot.resource_type == Enums.ResourceType.COMPOSITION and slot.is_current:
			sum.seats = world.composition_seats(slot.resource_id)
			break
	return sum


static func _station_name(world: World, sid: StringName) -> String:
	var st: Station = world.stations.get(sid)
	return st.name if st != null else String(sid)


static func resource_states(world: World) -> Array[ResourceState]:
	return ResourceStateCalc.compute(world)
