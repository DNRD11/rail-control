class_name ScheduleParser
extends RefCounted
## Servicios, asignaciones y viajeros → World. Las asignaciones derivan horas y estaciones del itinerario.


static func parse(services_raw: Dictionary, assignments_raw: Dictionary, passengers_raw: Dictionary,
		world: World, report: ValidationReport) -> void:
	_parse_services(services_raw, world, report)
	_parse_assignments(assignments_raw, world, report)
	_parse_passengers(passengers_raw, world, report)


static func _parse_services(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "services").read_dicts(raw, "services")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var ctx: String = "services[%d]" % i
		var r: DictReader = DictReader.new(report, ctx)
		var s: Service = Service.new()
		s.id = r.read_id(d, "id")
		s.code = r.read_string(d, "code", false, String(s.id))
		s.kind = r.read_enum(d, "kind", Enums.ServiceKind, false, Enums.ServiceKind.COMMERCIAL) as Enums.ServiceKind
		s.origin_station_id = r.read_id(d, "origin")
		s.destination_station_id = r.read_id(d, "destination")
		s.origin_ref = r.read_string(d, "origin_ref", false, "")
		var stops: Array[Dictionary] = r.read_dicts(d, "stops")
		for j: int in stops.size():
			s.stops.append(_parse_stop(stops[j], j, "%s.stops[%d]" % [ctx, j], world, report))
		if world.services.has(s.id):
			report.error(&"DUPLICATE_ID", "%s: servicio duplicado «%s»" % [ctx, s.id])
			continue
		world.services[s.id] = s


static func _parse_stop(d: Dictionary, index: int, ctx: String, world: World, report: ValidationReport) -> ServiceStop:
	var r: DictReader = DictReader.new(report, ctx)
	var st: ServiceStop = ServiceStop.new()
	st.index = index
	st.station_id = r.read_id(d, "station")
	st.stop_type = r.read_enum(d, "type", Enums.StopType, true, Enums.StopType.STOP) as Enums.StopType
	match st.stop_type:
		Enums.StopType.PASS:
			var t: int = r.read_time(d, "time")
			st.sched_arr = t
			st.sched_dep = t
		Enums.StopType.ORIGIN:
			st.sched_dep = r.read_time(d, "dep")
		Enums.StopType.DESTINATION:
			st.sched_arr = r.read_time(d, "arr")
		_:
			st.sched_arr = r.read_time(d, "arr")
			st.sched_dep = r.read_time(d, "dep")
	if st.stop_type == Enums.StopType.STOP:
		var station: Station = world.stations.get(st.station_id) as Station
		st.min_dwell_s = station.min_dwell_s if station != null else 120
	return st


static func _parse_assignments(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "assignments").read_dicts(raw, "assignments")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var ctx: String = "assignments[%d]" % i
		var r: DictReader = DictReader.new(report, ctx)
		var a: ResourceAssignment = ResourceAssignment.new()
		a.id = r.read_id(d, "id")
		a.service_id = r.read_id(d, "service")
		a.resource_type = r.read_enum(d, "type", Enums.ResourceType) as Enums.ResourceType
		a.resource_id = r.read_id(d, "resource")
		a.role = r.read_id(d, "role", false, &"")
		a.from_stop_index = r.read_int(d, "from_stop")
		a.to_stop_index = r.read_int(d, "to_stop")
		a.from_station_id = r.read_id(d, "from_station", false, &"")
		a.to_station_id = r.read_id(d, "to_station", false, &"")
		a.status = r.read_enum(d, "status", Enums.AssignmentStatus, false, Enums.AssignmentStatus.PLANNED) as Enums.AssignmentStatus
		a.source = r.read_enum(d, "source", Enums.AssignmentSource, false, Enums.AssignmentSource.PLAN) as Enums.AssignmentSource
		a.replaces_assignment_id = r.read_id(d, "replaces", false, &"")
		_derive_from_schedule(a, world)
		world.assignments.add(a)


## Rellena horas planificadas y estaciones ausentes a partir del itinerario (si los índices son válidos).
static func _derive_from_schedule(a: ResourceAssignment, world: World) -> void:
	var s: Service = world.services.get(a.service_id) as Service
	if s == null:
		return
	var n: int = s.stops.size()
	if a.from_stop_index >= 0 and a.from_stop_index < n:
		a.planned_start = s.stops[a.from_stop_index].exit_time()
		if a.from_station_id == &"":
			a.from_station_id = s.stops[a.from_stop_index].station_id
	if a.to_stop_index >= 0 and a.to_stop_index < n:
		a.planned_end = s.stops[a.to_stop_index].entry_time()
		if a.to_station_id == &"":
			a.to_station_id = s.stops[a.to_stop_index].station_id


static func _parse_passengers(raw: Dictionary, world: World, report: ValidationReport) -> void:
	var items: Array[Dictionary] = DictReader.new(report, "passengers").read_dicts(raw, "passengers")
	for i: int in items.size():
		var d: Dictionary = items[i]
		var ctx: String = "passengers[%d]" % i
		var r: DictReader = DictReader.new(report, ctx)
		var p: ServicePassengerLoad = ServicePassengerLoad.new()
		p.service_id = r.read_id(d, "service")
		p.booked = r.read_int(d, "booked")
		_read_stop_counts(d, "boardings_by_stop", p.boardings_by_stop, ctx, report)
		_read_stop_counts(d, "alightings_by_stop", p.alightings_by_stop, ctx, report)
		if world.passengers.has(p.service_id):
			report.error(&"DUPLICATE_ID", "%s: viajeros duplicados para «%s»" % [ctx, p.service_id])
			continue
		world.passengers[p.service_id] = p


static func _read_stop_counts(d: Dictionary, key: String, target: Dictionary[int, int], ctx: String,
		report: ValidationReport) -> void:
	if not d.has(key):
		report.error(&"MISSING_FIELD", "%s: falta el campo «%s»" % [ctx, key])
		return
	if typeof(d[key]) != TYPE_DICTIONARY:
		report.error(&"BAD_TYPE", "%s.%s: se esperaba un objeto" % [ctx, key])
		return
	var sub: Dictionary = d[key] as Dictionary
	for k: Variant in sub.keys():
		var ks: String = String(k)
		var v: Variant = sub[k]
		var is_num: bool = typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
		if not ks.is_valid_int() or not is_num:
			report.error(&"BAD_VALUE", "%s.%s: entrada no válida «%s»" % [ctx, key, ks])
			continue
		target[ks.to_int()] = int(v as float)
