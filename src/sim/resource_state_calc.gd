class_name ResourceStateCalc
extends RefCounted
## Estado instantáneo de composiciones, vehículos sueltos y personal (franja de recursos). Sin estado propio.
## Asignación en curso = el servicio ya salió (o está detenido) en su parada inicial y no ha llegado a la final.


static func compute(world: World) -> Array[ResourceState]:
	var out: Array[ResourceState] = []
	var in_comp: Dictionary = {}
	for cid: StringName in world.compositions:
		var comp: Composition = world.compositions[cid]
		for m: CompositionMember in comp.members:
			in_comp[m.vehicle_id] = true
		out.append(_resource(world, Enums.ResourceType.COMPOSITION, cid, _comp_start(world, comp),
				_comp_failed(world, comp)))
	for vid: StringName in world.vehicles:
		if in_comp.has(vid):
			continue
		var v: Vehicle = world.vehicles[vid]
		var r: ResourceState = _resource(world, Enums.ResourceType.VEHICLE, vid, v.location_station_id,
				v.status == Enums.VehicleStatus.FAILED or v.status == Enums.VehicleStatus.UNDER_REPAIR \
				or v.status == Enums.VehicleStatus.OUT_OF_SERVICE)
		out.append(r)
	for role: Enums.StaffRole in [Enums.StaffRole.DRIVER, Enums.StaffRole.CONDUCTOR]:
		var type: Enums.ResourceType = Enums.ResourceType.DRIVER if role == Enums.StaffRole.DRIVER \
				else Enums.ResourceType.CONDUCTOR
		for sid: StringName in world.staff:
			var m: StaffMember = world.staff[sid]
			if m.role == role:
				out.append(_resource(world, type, sid, m.base_station_id, m.status == Enums.StaffStatus.ABSENT))
	return out


static func _comp_start(world: World, comp: Composition) -> StringName:
	for m: CompositionMember in comp.members:
		var v: Vehicle = world.vehicles.get(m.vehicle_id)
		if v != null:
			return v.location_station_id
	return &""


static func _comp_failed(world: World, comp: Composition) -> bool:
	for m: CompositionMember in comp.members:
		var v: Vehicle = world.vehicles.get(m.vehicle_id)
		if v != null and (v.status == Enums.VehicleStatus.FAILED or v.status == Enums.VehicleStatus.UNDER_REPAIR \
				or v.status == Enums.VehicleStatus.OUT_OF_SERVICE):
			return true
	return false


static func _resource(world: World, type: Enums.ResourceType, rid: StringName, home: StringName,
		failed: bool) -> ResourceState:
	var r: ResourceState = ResourceState.new()
	r.resource_type = type
	r.resource_id = rid
	r.label = SessionQueries.label_of(world, type, rid)
	r.station_id = home
	var list: Array[ResourceAssignment] = world.assignments.for_resource(type, rid)
	var current: ResourceAssignment = null
	var last_done: ResourceAssignment = null
	var next: ResourceAssignment = null
	for a: ResourceAssignment in list:
		var s: Service = world.services.get(a.service_id) as Service
		if s == null or s.is_cancelled() or a.to_stop_index >= s.stops.size():
			continue
		var from_st: ServiceStop = s.stops[a.from_stop_index]
		var to_st: ServiceStop = s.stops[a.to_stop_index]
		if to_st.status != Enums.StopStatus.PENDING:
			last_done = a
		elif from_st.status != Enums.StopStatus.PENDING:
			current = a
		elif next == null:
			next = a
	if next != null:
		var sn: Service = world.services[next.service_id]
		var sb: ServiceStop = sn.stops[next.from_stop_index]
		r.next_service_id = next.service_id
		r.next_departure = sb.est_dep if sb.est_dep != SimTime.NONE else sb.sched_dep
	if failed:
		r.state = ResourceState.State.FAILED
	elif current != null:
		r.state = ResourceState.State.IN_SERVICE
		r.current_service_id = current.service_id
		var sc: Service = world.services[current.service_id]
		var last: int = SessionQueries.last_reached(sc)
		r.station_id = sc.stops[last].station_id \
				if last >= 0 and sc.stops[last].status == Enums.StopStatus.ARRIVED else &""
	else:
		if last_done != null:
			r.station_id = last_done.to_station_id
		elif next != null:
			r.station_id = next.from_station_id
		r.state = ResourceState.State.RESERVE if list.is_empty() else ResourceState.State.IDLE
	return r
