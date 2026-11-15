class_name DataValidator
extends RefCounted
## Validación estructural y de referencias del World cargado. Las reglas de recursos
## (solapes, continuidad, cobertura) viven en AssignmentValidator.


static func validate(world: World, report: ValidationReport) -> void:
	_validate_scenario(world, report)
	for line: Line in world.lines.values():
		_validate_line(line, world, report)
	for v: Vehicle in world.vehicles.values():
		_validate_vehicle(v, world, report)
	for c: Composition in world.compositions.values():
		_validate_composition(c, world, report)
	for s: StaffMember in world.staff.values():
		_validate_staff(s, world, report)
	for svc: Service in world.services.values():
		_validate_service(svc, world, report)
	for p: ServicePassengerLoad in world.passengers.values():
		_validate_passengers(p, world, report)
	for a: ResourceAssignment in world.assignments.all():
		_validate_assignment_refs(a, world, report)
	AssignmentValidator.validate(world, report)


static func _validate_scenario(world: World, report: ValidationReport) -> void:
	var sc: ScenarioInfo = world.scenario
	if sc == null:
		report.error(&"MISSING_FIELD", "El mundo no tiene escenario")
		return
	for lid: StringName in sc.line_ids:
		if not world.lines.has(lid):
			report.error(&"UNKNOWN_REF", "scenario: la línea «%s» no existe" % lid)
	if sc.day_start >= sc.day_end:
		report.error(&"BAD_VALUE", "scenario: day_start debe ser anterior a day_end")
	for i: int in sc.scripted_incidents.size():
		_validate_scripted_incident(sc.scripted_incidents[i], i, world, report)


static func _validate_scripted_incident(d: Dictionary, idx: int, world: World, report: ValidationReport) -> void:
	var ctx: String = "scenario.scripted_incidents[%d]" % idx
	var r: DictReader = DictReader.new(report, ctx)
	r.read_id(d, "id")
	var type_id: StringName = r.read_id(d, "type")
	if type_id != &"" and not world.incident_rules.types.has(type_id):
		report.error(&"UNKNOWN_REF", "%s: el tipo «%s» no está en incidents.json" % [ctx, type_id])
	var service_id: StringName = r.read_id(d, "service")
	if service_id != &"" and not world.services.has(service_id):
		report.error(&"UNKNOWN_REF", "%s: el servicio «%s» no existe" % [ctx, service_id])
	var section_id: StringName = r.read_id(d, "section", false)
	if section_id != &"" and not world.sections.has(section_id):
		report.error(&"UNKNOWN_REF", "%s: el tramo «%s» no existe" % [ctx, section_id])
	var t: int = r.read_time(d, "time")
	if t != SimTime.NONE and (t < world.scenario.day_start or t >= world.scenario.day_end):
		report.error(&"BAD_VALUE", "%s: la hora queda fuera de la jornada" % ctx)


static func _validate_line(line: Line, world: World, report: ValidationReport) -> void:
	var prev_km: float = -INF
	for sid: StringName in line.station_ids:
		var st: Station = world.stations.get(sid) as Station
		if st == null:
			report.error(&"UNKNOWN_REF", "Línea %s: la estación «%s» no existe" % [line.id, sid])
			continue
		if st.km <= prev_km:
			report.error(&"BAD_LINE", "Línea %s: los km no son ascendentes en «%s»" % [line.id, sid])
		prev_km = st.km
	if line.section_ids.size() != maxi(line.station_ids.size() - 1, 0):
		report.error(&"BAD_LINE", "Línea %s: %d estaciones requieren %d tramos, hay %d" % [
				line.id, line.station_ids.size(), maxi(line.station_ids.size() - 1, 0), line.section_ids.size()])
		return
	for i: int in line.section_ids.size():
		var sec: Section = world.sections.get(line.section_ids[i]) as Section
		if sec == null:
			report.error(&"UNKNOWN_REF", "Línea %s: el tramo «%s» no existe" % [line.id, line.section_ids[i]])
		elif not (sec.from_station_id == line.station_ids[i] and sec.to_station_id == line.station_ids[i + 1]):
			report.error(&"BAD_LINE", "Línea %s: el tramo «%s» no une %s y %s en orden" % [
					line.id, sec.id, line.station_ids[i], line.station_ids[i + 1]])
		elif sec.run_time_s <= 0 or sec.length_km <= 0.0:
			report.error(&"BAD_VALUE", "Tramo %s: longitud y tiempo de recorrido deben ser positivos" % sec.id)


static func _validate_vehicle(v: Vehicle, world: World, report: ValidationReport) -> void:
	if not world.vehicle_classes.has(v.class_id):
		report.error(&"UNKNOWN_REF", "Vehículo %s: la clase «%s» no existe" % [v.id, v.class_id])
	if not world.stations.has(v.location_station_id):
		report.error(&"UNKNOWN_REF", "Vehículo %s: la estación «%s» no existe" % [v.id, v.location_station_id])


static func _validate_composition(c: Composition, world: World, report: ValidationReport) -> void:
	var positions: Dictionary[int, bool] = {}
	var max_coupled: int = 1000
	for m: CompositionMember in c.members:
		var v: Vehicle = world.vehicles.get(m.vehicle_id) as Vehicle
		if v == null:
			report.error(&"UNKNOWN_REF", "Composición %s: el vehículo «%s» no existe" % [c.id, m.vehicle_id])
			continue
		if positions.has(m.position):
			report.error(&"BAD_COMPOSITION", "Composición %s: posición %d repetida" % [c.id, m.position])
		positions[m.position] = true
		var cls: VehicleClass = world.vehicle_classes.get(v.class_id) as VehicleClass
		if cls != null:
			max_coupled = mini(max_coupled, cls.max_coupled)
	if c.members.is_empty():
		report.error(&"BAD_COMPOSITION", "Composición %s: no tiene vehículos" % c.id)
	elif c.members.size() > max_coupled:
		report.error(&"BAD_COMPOSITION", "Composición %s: %d vehículos superan el máximo acoplable (%d)" % [
				c.id, c.members.size(), max_coupled])


static func _validate_staff(s: StaffMember, world: World, report: ValidationReport) -> void:
	if not world.stations.has(s.base_station_id):
		report.error(&"UNKNOWN_REF", "Personal %s: la base «%s» no existe" % [s.id, s.base_station_id])
	if s.shift_start >= s.shift_end:
		report.error(&"BAD_VALUE", "Personal %s: shift_start debe ser anterior a shift_end" % s.id)


static func _validate_service(svc: Service, world: World, report: ValidationReport) -> void:
	var n: int = svc.stops.size()
	if n < 2:
		report.error(&"BAD_SERVICE", "Servicio %s: necesita al menos 2 paradas" % svc.id)
		return
	if svc.stops[0].stop_type != Enums.StopType.ORIGIN or svc.stops[n - 1].stop_type != Enums.StopType.DESTINATION:
		report.error(&"BAD_SERVICE", "Servicio %s: debe empezar en ORIGIN y acabar en DESTINATION" % svc.id)
	if svc.stops[0].station_id != svc.origin_station_id or svc.stops[n - 1].station_id != svc.destination_station_id:
		report.error(&"BAD_SERVICE", "Servicio %s: origen/destino no coinciden con el itinerario" % svc.id)
	for i: int in n:
		var st: ServiceStop = svc.stops[i]
		if not world.stations.has(st.station_id):
			report.error(&"UNKNOWN_REF", "Servicio %s: la estación «%s» no existe" % [svc.id, st.station_id])
		if st.entry_time() == SimTime.NONE or st.exit_time() == SimTime.NONE:
			report.error(&"TIME_ORDER", "Servicio %s parada %d: falta la hora" % [svc.id, i])
			continue
		if st.sched_arr != SimTime.NONE and st.sched_dep != SimTime.NONE:
			if st.sched_dep < st.sched_arr:
				report.error(&"TIME_ORDER", "Servicio %s parada %d: salida anterior a la llegada" % [svc.id, i])
			elif st.stop_type == Enums.StopType.STOP and st.sched_dep - st.sched_arr < st.min_dwell_s:
				report.warning(&"SHORT_DWELL", "Servicio %s parada %d: estancia de %d s < mínimo %d s" % [
						svc.id, i, st.sched_dep - st.sched_arr, st.min_dwell_s])
		if i > 0:
			_validate_hop(svc, svc.stops[i - 1], st, world, report)


static func _validate_hop(svc: Service, prev: ServiceStop, cur: ServiceStop, world: World, report: ValidationReport) -> void:
	var sec: Section = world.section_between(prev.station_id, cur.station_id)
	if sec == null:
		if world.stations.has(prev.station_id) and world.stations.has(cur.station_id):
			report.error(&"NO_SECTION", "Servicio %s: no hay tramo entre %s y %s" % [svc.id, prev.station_id, cur.station_id])
		return
	if prev.exit_time() == SimTime.NONE or cur.entry_time() == SimTime.NONE:
		return
	var run: int = cur.entry_time() - prev.exit_time()
	if run <= 0:
		report.error(&"TIME_ORDER", "Servicio %s: la hora en %s no es posterior a la de %s" % [svc.id, cur.station_id, prev.station_id])
	elif run < sec.run_time_s:
		report.warning(&"TIGHT_RUNTIME", "Servicio %s: %s→%s en %d s < tiempo mínimo del tramo %d s" % [
				svc.id, prev.station_id, cur.station_id, run, sec.run_time_s])


static func _validate_passengers(p: ServicePassengerLoad, world: World, report: ValidationReport) -> void:
	var svc: Service = world.services.get(p.service_id) as Service
	if svc == null:
		report.error(&"UNKNOWN_REF", "Viajeros: el servicio «%s» no existe" % p.service_id)
		return
	for idx: int in p.boardings_by_stop:
		if idx < 0 or idx >= svc.stops.size():
			report.error(&"PAX_MISMATCH", "Viajeros %s: índice de embarque %d fuera del itinerario" % [p.service_id, idx])
	for idx: int in p.alightings_by_stop:
		if idx < 0 or idx >= svc.stops.size():
			report.error(&"PAX_MISMATCH", "Viajeros %s: índice de desembarque %d fuera del itinerario" % [p.service_id, idx])
	if p.total_boardings() != p.booked or p.total_alightings() != p.booked:
		report.error(&"PAX_MISMATCH", "Viajeros %s: reservados %d, embarques %d, desembarques %d" % [
				p.service_id, p.booked, p.total_boardings(), p.total_alightings()])


static func _validate_assignment_refs(a: ResourceAssignment, world: World, report: ValidationReport) -> void:
	var svc: Service = world.services.get(a.service_id) as Service
	if svc == null:
		report.error(&"UNKNOWN_REF", "Asignación %s: el servicio «%s» no existe" % [a.id, a.service_id])
	if not _resource_exists(a, world):
		report.error(&"UNKNOWN_REF", "Asignación %s: el recurso «%s» (%s) no existe" % [
				a.id, a.resource_id, Enums.name_of(Enums.ResourceType, a.resource_type)])
	if svc == null:
		return
	var n: int = svc.stops.size()
	if a.from_stop_index < 0 or a.to_stop_index >= n or a.from_stop_index >= a.to_stop_index:
		report.error(&"BAD_RANGE", "Asignación %s: tramo de paradas %d..%d no válido (el servicio tiene %d paradas)" % [
				a.id, a.from_stop_index, a.to_stop_index, n])
		return
	if a.from_station_id != svc.stops[a.from_stop_index].station_id or a.to_station_id != svc.stops[a.to_stop_index].station_id:
		report.error(&"STATION_MISMATCH", "Asignación %s: estaciones %s→%s no coinciden con las paradas" % [
				a.id, a.from_station_id, a.to_station_id])


static func _resource_exists(a: ResourceAssignment, world: World) -> bool:
	match a.resource_type:
		Enums.ResourceType.COMPOSITION:
			return world.compositions.has(a.resource_id)
		Enums.ResourceType.VEHICLE:
			return world.vehicles.has(a.resource_id)
		_:
			return world.staff.has(a.resource_id)
