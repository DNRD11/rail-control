class_name AssignmentValidator
extends RefCounted
## Reglas de asignaciones (DATA_MODEL §6) sobre las asignaciones vivas. Los recursos se comparan
## por clave física: "veh:<id>" (las composiciones se expanden a sus vehículos) y "stf:<id>".


static func validate(world: World, report: ValidationReport) -> void:
	_check_roles(world, report)
	var groups: Dictionary[String, Array] = _group_by_physical_key(world)
	var keys: Array = groups.keys()
	keys.sort()
	var seen: Dictionary[String, bool] = {}
	for key: String in keys:
		var list: Array = groups[key]
		list.sort_custom(_by_start)
		_check_group(key, list, world, report, seen)
	_check_coverage(world, report)


static func _by_start(a: ResourceAssignment, b: ResourceAssignment) -> bool:
	if a.planned_start != b.planned_start:
		return a.planned_start < b.planned_start
	if a.planned_end != b.planned_end:
		return a.planned_end < b.planned_end
	return String(a.id) < String(b.id)


static func _check_roles(world: World, report: ValidationReport) -> void:
	for a: ResourceAssignment in world.assignments.all():
		if not a.is_live():
			continue
		var wanted: int = -1
		if a.resource_type == Enums.ResourceType.DRIVER:
			wanted = Enums.StaffRole.DRIVER
		elif a.resource_type == Enums.ResourceType.CONDUCTOR:
			wanted = Enums.StaffRole.CONDUCTOR
		if wanted == -1:
			continue
		var s: StaffMember = world.staff.get(a.resource_id) as StaffMember
		if s != null and s.role != wanted:
			report.error(&"ROLE_MISMATCH", "Asignación %s: %s tiene rol %s, no coincide con el tipo %s" % [
					a.id, s.id, Enums.name_of(Enums.StaffRole, s.role), Enums.name_of(Enums.ResourceType, a.resource_type)])


static func _group_by_physical_key(world: World) -> Dictionary[String, Array]:
	var groups: Dictionary[String, Array] = {}
	for a: ResourceAssignment in world.assignments.all():
		if not a.is_live() or a.planned_start == SimTime.NONE or a.planned_end == SimTime.NONE:
			continue
		for key: String in _keys_for(a, world):
			if not groups.has(key):
				groups[key] = []
			groups[key].append(a)
	return groups


static func _keys_for(a: ResourceAssignment, world: World) -> Array[String]:
	var keys: Array[String] = []
	match a.resource_type:
		Enums.ResourceType.COMPOSITION:
			var c: Composition = world.compositions.get(a.resource_id) as Composition
			if c != null:
				for vid: StringName in c.vehicle_ids_during(a.planned_start, a.planned_end):
					keys.append("veh:%s" % vid)
		Enums.ResourceType.VEHICLE:
			keys.append("veh:%s" % a.resource_id)
		_:
			keys.append("stf:%s" % a.resource_id)
	return keys


static func _check_group(key: String, list: Array, world: World, report: ValidationReport,
		seen: Dictionary[String, bool]) -> void:
	var is_vehicle: bool = key.begins_with("veh:")
	var rid: StringName = StringName(key.substr(4))
	var first: ResourceAssignment = list[0] as ResourceAssignment
	var origin: StringName = &""
	var vehicle: Vehicle = null
	var staff: StaffMember = null
	if is_vehicle:
		vehicle = world.vehicles.get(rid) as Vehicle
		origin = vehicle.location_station_id if vehicle != null else &""
	else:
		staff = world.staff.get(rid) as StaffMember
		origin = staff.base_station_id if staff != null else &""
	if origin != &"" and first.from_station_id != origin:
		report.error(&"INITIAL_LOCATION", "%s: la primera asignación (%s) empieza en %s pero el recurso está en %s" % [
				key, first.id, first.from_station_id, origin])
	for i: int in list.size():
		var cur: ResourceAssignment = list[i] as ResourceAssignment
		if vehicle != null and not vehicle.is_usable() and _once(seen, "VU|%s|%s" % [key, cur.id]):
			report.error(&"VEHICLE_UNAVAILABLE", "%s asignado en %s pero su estado es %s" % [
					key, cur.id, Enums.name_of(Enums.VehicleStatus, vehicle.status)])
		if staff != null and (cur.planned_start < staff.shift_start or cur.planned_end > staff.shift_end):
			report.warning(&"OUT_OF_SHIFT", "%s: la asignación %s (%s-%s) queda fuera de turno (%s-%s)" % [
					key, cur.id, SimTime.format(cur.planned_start), SimTime.format(cur.planned_end),
					SimTime.format(staff.shift_start), SimTime.format(staff.shift_end)])
		if i > 0:
			_check_pair(key, list[i - 1] as ResourceAssignment, cur, is_vehicle, world, report, seen)


static func _check_pair(key: String, prev: ResourceAssignment, next: ResourceAssignment, is_vehicle: bool,
		world: World, report: ValidationReport, seen: Dictionary[String, bool]) -> void:
	var pair: String = "%s|%s" % [prev.id, next.id]
	var overlap: bool = next.planned_start < prev.planned_end
	if overlap and _once(seen, "OV|" + pair):
		report.error(&"OVERLAP", "%s: las asignaciones %s y %s se solapan (%s < %s)" % [
				key, prev.id, next.id, SimTime.format(next.planned_start), SimTime.format(prev.planned_end)])
	if next.from_station_id != prev.to_station_id and _once(seen, "DC|" + pair):
		report.error(&"DISCONTINUITY", "%s: %s termina en %s y %s empieza en %s" % [
				key, prev.id, prev.to_station_id, next.id, next.from_station_id])
	if is_vehicle and not overlap and next.from_station_id == prev.to_station_id:
		var st: Station = world.stations.get(prev.to_station_id) as Station
		var gap: int = next.planned_start - prev.planned_end
		if st != null and gap < st.min_turnaround_s and prev.service_id != next.service_id and _once(seen, "TT|" + pair):
			report.warning(&"TURNAROUND_TIGHT", "%s: %d s entre %s y %s en %s (mínimo %d s)" % [
					key, gap, prev.id, next.id, st.code, st.min_turnaround_s])


static func _check_coverage(world: World, report: ValidationReport) -> void:
	var min_conductors: int = world.scenario.min_conductors_per_segment if world.scenario != null else 1
	var ids: Array = world.services.keys()
	ids.sort()
	for sid: StringName in ids:
		var svc: Service = world.services[sid] as Service
		if svc.kind != Enums.ServiceKind.COMMERCIAL:
			continue
		for k: int in svc.segment_count():
			var seg: String = "%s tramo %d (%s→%s)" % [svc.id, k, svc.stops[k].station_id, svc.stops[k + 1].station_id]
			if world.assignments.for_segment(svc.id, Enums.ResourceType.COMPOSITION, k).is_empty():
				report.error(&"NO_COMPOSITION", "%s: sin composición" % seg)
			if world.assignments.for_segment(svc.id, Enums.ResourceType.DRIVER, k).is_empty():
				report.error(&"NO_DRIVER", "%s: sin maquinista" % seg)
			var n_cond: int = world.assignments.for_segment(svc.id, Enums.ResourceType.CONDUCTOR, k).size()
			if n_cond < min_conductors:
				report.warning(&"FEW_CONDUCTORS", "%s: %d interventores (mínimo %d)" % [seg, n_cond, min_conductors])


static func _once(seen: Dictionary[String, bool], token: String) -> bool:
	if seen.has(token):
		return false
	seen[token] = true
	return true
