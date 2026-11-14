extends TestCase
## InjectDelayCommand: validación, registro y reprogramación de eventos pendientes.

const D = preload("res://tests/framework/delay_fixture.gd")


func test_valid_command_logged_in_command_log() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	var cmd: InjectDelayCommand = InjectDelayCommand.make(D.S3103, 600)
	assert_true(s.apply_command(cmd))
	assert_eq(s.command_log.size(), 1)
	assert_eq(s.command_log[0], cmd)
	assert_eq(s.command_log[0].kind, &"INJECT_DELAY")
	assert_eq(s.command_log[0].applied_at, D.t("08:00"))


func test_nonpositive_seconds_rejected() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	var n: int = s.log.count()
	var q: int = s.queue.size()
	assert_false(s.apply_command(InjectDelayCommand.make(D.S3103, 0)))
	assert_false(s.apply_command(InjectDelayCommand.make(D.S3103, -300)))
	assert_eq(s.command_log.size(), 0)
	assert_eq(s.log.count(), n)
	assert_eq(s.queue.size(), q, "no se programa ningún evento")
	assert_eq(s.delay_of(D.S3103), 0)


func test_unknown_service_rejected() -> void:
	var s: SimulationSession = SimFixture.session()
	var q: int = s.queue.size()
	assert_false(s.apply_command(InjectDelayCommand.make(&"svc_9999", 600)))
	assert_false(s.apply_command(InjectDelayCommand.make(&"", 600)))
	assert_eq(s.command_log.size(), 0)
	assert_eq(s.queue.size(), q)


func test_terminated_service_rejected() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:30")
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.TERMINATED)
	var n: int = s.log.count()
	assert_false(s.apply_command(InjectDelayCommand.make(D.S3103, 600)))
	assert_eq(s.command_log.size(), 0)
	assert_eq(s.log.count(), n)


func test_cancelled_service_rejected() -> void:
	var s: SimulationSession = SimFixture.session()
	s.world.services[D.S3105].status = Enums.ServiceStatus.CANCELLED
	assert_false(s.apply_command(InjectDelayCommand.make(D.S3105, 600)))
	assert_eq(s.command_log.size(), 0)


func test_scheduled_service_accepts_delay() -> void:
	var s: SimulationSession = SimFixture.session()
	assert_true(s.apply_command(InjectDelayCommand.make(D.S3105, 600)))
	assert_eq(s.delay_of(D.S3105), 600)
	assert_eq(s.delay_info(D.S3105).cause, DelayInfo.CAUSE_INJECTED)
	D.run_to_text(s, "09:00")
	assert_eq(s.world.services[D.S3105].status, Enums.ServiceStatus.SCHEDULED, "no sale a su hora programada")
	D.run_to_text(s, "09:06")
	assert_eq(s.world.services[D.S3105].stops[0].act_dep, D.t("09:05"))


func test_applied_even_if_session_paused_speed_zero() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	s.apply_command(SetSpeedCommand.make(0))
	assert_true(s.apply_command(InjectDelayCommand.make(D.S3103, 1500)))
	assert_eq(s.delay_of(D.S3105), 600, "propagación visible de inmediato en pausa")
	assert_eq(s.clock.now, D.t("08:00"), "no avanza el reloj")


func _pending_by_service(s: SimulationSession) -> Dictionary:
	var counts: Dictionary = {}
	for e: Dictionary in s.queue.snapshot():
		var sid: StringName = e["service_id"]
		if sid != &"":
			counts[sid] = int(counts.get(sid, 0)) + 1
	return counts


func test_at_most_one_pending_event_per_service_with_injections() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:50")
	var checks: int = 0
	while not s.clock.is_day_over():
		s.advance_seconds(60)
		if s.clock.now == D.t("08:00") or s.clock.now == D.t("08:13") or s.clock.now == D.t("09:20"):
			s.apply_command(InjectDelayCommand.make(D.S3103, 400))
			s.apply_command(InjectDelayCommand.make(D.S3105, 300))
			s.apply_command(InjectDelayCommand.make(D.S3152, 200))
		var counts: Dictionary = _pending_by_service(s)
		for sid: StringName in counts:
			checks += 1
			assert_true(counts[sid] <= 1, "%s: %d eventos pendientes en %s" % [sid, counts[sid], SimTime.format(s.clock.now)])
	assert_true(checks > 0)


func test_pending_departure_of_3105_moved_to_new_estimate() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var found: bool = false
	for e: Dictionary in s.queue.snapshot():
		if e["service_id"] == D.S3105:
			found = true
			assert_eq(e["type"], SimEventType.SERVICE_DEPARTURE)
			assert_eq(e["time"], D.t("09:05"), "salida reprogramada a la hora estimada")
			assert_eq(e["stop_index"], 0)
	assert_true(found)


func test_cancelled_events_never_dispatched_event_counts_match_baseline() -> void:
	var base: SimulationSession = SimFixture.session()
	D.run_to(base, base.clock.day_end)
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to(s, s.clock.day_end, 37)
	for type: StringName in [SimEventType.SERVICE_ARRIVAL, SimEventType.SERVICE_DEPARTURE, SimEventType.SERVICE_PASS]:
		assert_eq(s.log.filter(type).size(), base.log.filter(type).size(), "mismo nº de %s que sin retraso" % type)
	# cada punto de cada servicio tiene exactamente un hecho de cada clase: nada despachado dos veces
	var seen: Dictionary = {}
	for e: LogEntry in s.log.entries:
		if e.service_id == &"" or e.type == SimEventType.DELAY_APPLIED or e.type == &"DELAY_PROPAGATED":
			continue
		var key: String = "%s|%d|%s" % [e.service_id, e.stop_index, e.type]
		assert_false(seen.has(key), "evento duplicado " + key)
		seen[key] = true


func test_log_times_match_actuals_and_stay_sorted_with_delay() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to(s, s.clock.day_end, 600)
	var prev: int = -1
	for e: LogEntry in s.log.entries:
		assert_true(e.time >= prev, "log ordenado")
		prev = e.time
		if e.service_id == &"" or e.stop_index < 0:
			continue
		var st: ServiceStop = (s.world.services[e.service_id] as Service).stops[e.stop_index]
		match e.type:
			SimEventType.SERVICE_ARRIVAL, SimEventType.SERVICE_PASS:
				assert_eq(e.time, st.act_arr, "%s/%d" % [e.service_id, e.stop_index])
			SimEventType.SERVICE_DEPARTURE:
				assert_eq(e.time, st.act_dep, "%s/%d" % [e.service_id, e.stop_index])


func test_service_updated_emitted_on_propagation() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	var seen: Array[StringName] = []
	s.service_updated.connect(func(id: StringName) -> void: seen.append(id))
	s.apply_command(InjectDelayCommand.make(D.S3103, 1500))
	assert_true(seen.has(D.S3103))
	assert_true(seen.has(D.S3105), "señal para el servicio afectado por propagación")
	assert_true(seen.has(D.S3152))
	assert_false(seen.has(D.S3106))
