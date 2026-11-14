extends TestCase

func _commercial(s: SimulationSession) -> Array[Service]:
	var out: Array[Service] = []
	for sid: StringName in s.world.services:
		var sv: Service = s.world.services[sid]
		if sv.kind == Enums.ServiceKind.COMMERCIAL:
			out.append(sv)
	return out


func test_ten_services_exist() -> void:
	var s: SimulationSession = SimFixture.session()
	assert_eq(_commercial(s).size(), 10)


func test_initial_queue_one_departure_per_service() -> void:
	var s: SimulationSession = SimFixture.session()
	var deps: int = 0
	for e: Dictionary in s.queue.snapshot():
		if e["type"] == SimEventType.SERVICE_DEPARTURE:
			deps += 1
	assert_eq(deps, 10)


func test_all_events_exactly_on_schedule() -> void:
	var s: SimulationSession = SimFixture.session()
	s.advance_seconds(s.clock.day_end)
	for sv: Service in _commercial(s):
		assert_eq(sv.status, Enums.ServiceStatus.TERMINATED, "%s terminado" % sv.id)
		for st: ServiceStop in sv.stops:
			var ctx: String = "%s parada %d" % [sv.id, st.index]
			match st.stop_type:
				Enums.StopType.ORIGIN:
					assert_eq(st.act_dep, st.sched_dep, ctx + " salida")
					assert_eq(st.status, Enums.StopStatus.DEPARTED, ctx)
				Enums.StopType.DESTINATION:
					assert_eq(st.act_arr, st.sched_arr, ctx + " llegada")
					assert_eq(st.status, Enums.StopStatus.ARRIVED, ctx)
				Enums.StopType.PASS:
					assert_eq(st.act_arr, st.sched_arr, ctx + " paso")
					assert_eq(st.status, Enums.StopStatus.PASSED, ctx)
				_:
					assert_eq(st.act_arr, st.sched_arr, ctx + " llegada")
					assert_eq(st.act_dep, st.sched_dep, ctx + " salida")
					assert_eq(st.status, Enums.StopStatus.DEPARTED, ctx)
		assert_eq(s.delay_of(sv.id), 0, "sin retraso " + str(sv.id))


func test_log_times_match_schedule_and_are_sorted() -> void:
	var s: SimulationSession = SimFixture.session()
	s.advance_seconds(s.clock.day_end)
	var prev: int = -1
	for e: LogEntry in s.log.entries:
		assert_true(e.time >= prev, "log ordenado por hora")
		prev = e.time
		if e.service_id == &"":
			continue
		var st: ServiceStop = (s.world.services[e.service_id] as Service).stops[e.stop_index]
		match e.type:
			SimEventType.SERVICE_ARRIVAL:
				assert_eq(e.time, st.sched_arr)
			SimEventType.SERVICE_PASS:
				assert_eq(e.time, st.sched_arr)
			SimEventType.SERVICE_DEPARTURE:
				assert_eq(e.time, st.sched_dep)


func test_event_counts_match_stop_types() -> void:
	var s: SimulationSession = SimFixture.session()
	s.advance_seconds(s.clock.day_end)
	var arr: int = 0
	var dep: int = 0
	var pas: int = 0
	for sv: Service in _commercial(s):
		for st: ServiceStop in sv.stops:
			match st.stop_type:
				Enums.StopType.ORIGIN:
					dep += 1
				Enums.StopType.DESTINATION:
					arr += 1
				Enums.StopType.PASS:
					pas += 1
				_:
					arr += 1
					dep += 1
	assert_eq(s.log.filter(SimEventType.SERVICE_ARRIVAL).size(), arr)
	assert_eq(s.log.filter(SimEventType.SERVICE_DEPARTURE).size(), dep)
	assert_eq(s.log.filter(SimEventType.SERVICE_PASS).size(), pas)


func test_at_most_one_pending_event_per_service() -> void:
	var s: SimulationSession = SimFixture.session()
	while not s.clock.is_day_over():
		s.advance_seconds(60)
		var counts: Dictionary = {}
		for e: Dictionary in s.queue.snapshot():
			var sid: StringName = e["service_id"]
			if sid == &"":
				continue
			counts[sid] = int(counts.get(sid, 0)) + 1
		for sid: StringName in counts:
			assert_true(counts[sid] <= 1, "%s tiene %d eventos pendientes en t=%d" % [sid, counts[sid], s.clock.now])


func test_signals_emitted() -> void:
	var s: SimulationSession = SimFixture.session()
	var stop_events: Array[int] = [0]
	var updated: Array[int] = [0]
	s.service_stop_event.connect(func(_i: StringName, _k: int, _kind: StringName) -> void: stop_events[0] += 1)
	s.service_updated.connect(func(_i: StringName) -> void: updated[0] += 1)
	s.advance_seconds(s.clock.day_end)
	assert_eq(stop_events[0], s.log.count() - 1, "un signal por evento de circulación (sin DAY_END)")
	assert_true(updated[0] > 0)


func test_position_lifecycle() -> void:
	var s: SimulationSession = SimFixture.session()
	var sv: Service = _commercial(s)[0]
	var p0: ServicePosition = s.query_service_position(sv.id)
	assert_eq(p0.state, ServicePosition.State.NOT_STARTED)
	assert_eq(s.active_service_ids().size(), 0)
	assert_eq(s.query_service_position(&"no_existe"), null)
	s.advance_seconds(sv.stops[0].sched_dep - s.clock.now)
	assert_true(s.active_service_ids().has(sv.id))
	var found_section: bool = false
	var found_station: bool = false
	var last_km: float = -1.0
	var asc: bool = false
	var first: bool = true
	while not s.clock.is_day_over():
		s.advance_seconds(30)
		var p: ServicePosition = s.query_service_position(sv.id)
		if p.state == ServicePosition.State.FINISHED:
			break
		if p.state == ServicePosition.State.IN_SECTION:
			found_section = true
			assert_true(p.fraction >= 0.0 and p.fraction <= 1.0, "fracción en [0,1]")
			var a: ServiceStop = sv.stops[p.stop_index]
			var b: ServiceStop = sv.stops[p.stop_index + 1]
			var ka: float = s.world.stations[a.station_id].km
			var kb: float = s.world.stations[b.station_id].km
			assert_true(p.km >= minf(ka, kb) - 0.001 and p.km <= maxf(ka, kb) + 0.001,
					"km %f dentro del tramo [%f, %f]" % [p.km, ka, kb])
			var expected_frac: float = float(s.clock.now - a.act_dep) / float(b.sched_arr - a.act_dep)
			assert_true(absf(p.fraction - expected_frac) < 0.001, "fracción coherente con el reloj")
			assert_ne(p.section_id, &"", "tramo identificado")
			if first:
				asc = kb >= ka
				first = false
			assert_eq(p.direction, Enums.Direction.ASCENDING if asc else Enums.Direction.DESCENDING)
			if last_km >= 0.0:
				assert_true((p.km >= last_km - 0.001) if asc else (p.km <= last_km + 0.001), "avanza en su sentido")
			last_km = p.km
		elif p.state == ServicePosition.State.AT_STATION:
			found_station = true
			assert_eq(p.fraction, 0.0)
			last_km = p.km
	assert_true(found_section, "se observó en tramo")
	assert_true(found_station, "se observó en estación")
	var pf: ServicePosition = s.query_service_position(sv.id)
	assert_eq(pf.state, ServicePosition.State.FINISHED)
	assert_eq(pf.stop_index, sv.stops.size() - 1)
	assert_eq(pf.km, s.world.stations[sv.stops[sv.stops.size() - 1].station_id].km)
	assert_false(s.active_service_ids().has(sv.id))


func test_position_at_station_during_dwell() -> void:
	var s: SimulationSession = SimFixture.session()
	for sv: Service in _commercial(s):
		for st: ServiceStop in sv.stops:
			if st.stop_type == Enums.StopType.STOP and st.sched_dep > st.sched_arr:
				var fresh: SimulationSession = SimFixture.session()
				fresh.advance_seconds(st.sched_arr - fresh.clock.now)
				var p: ServicePosition = fresh.query_service_position(sv.id)
				assert_eq(p.state, ServicePosition.State.AT_STATION)
				assert_eq(p.stop_index, st.index)
				assert_eq(p.km, fresh.world.stations[st.station_id].km)
				return
	assert_true(false, "no hay ninguna parada comercial con estancia en el MVP")


func test_all_services_end_finished() -> void:
	var s: SimulationSession = SimFixture.session()
	s.advance_seconds(s.clock.day_end)
	for sv: Service in _commercial(s):
		assert_eq(s.query_service_position(sv.id).state, ServicePosition.State.FINISHED, str(sv.id))
	assert_eq(s.active_service_ids().size(), 0)
