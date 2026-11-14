extends TestCase
## DelaySystem: inyección de 1500 s en el 3103 a las 08:00 y propagación por rotaciones (SIMULATION.md §5).

const D = preload("res://tests/framework/delay_fixture.gd")


func _svc(s: SimulationSession, id: StringName) -> Service:
	return s.world.services[id]


func _propagated(s: SimulationSession, id: StringName) -> Array[LogEntry]:
	return s.log.filter(&"DELAY_PROPAGATED", id)


func test_inject_3103_applies_and_logs() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	assert_true(s.apply_command(InjectDelayCommand.make(D.S3103, 1500)))
	assert_eq(s.delay_of(D.S3103), 1500)
	var info: DelayInfo = s.delay_info(D.S3103)
	assert_eq(info.cause, DelayInfo.CAUSE_INJECTED)
	assert_eq(info.source_service_id, D.S3103)
	assert_eq(info.level, DelayInfo.LEVEL_MAJOR)
	var applied: Array[LogEntry] = s.log.filter(SimEventType.DELAY_APPLIED, D.S3103)
	assert_eq(applied.size(), 1)
	assert_eq(applied[0].time, D.t("08:00"))
	assert_eq(int(applied[0].data.get("seconds", -1)), 1500)
	assert_eq(str(applied[0].data.get("cause", "")), "INJECTED")
	# el 3103 va de Guadalajara a Calatayud: llegada estimada a Calatayud 08:02 + 25 min
	var st: ServiceStop = _svc(s, D.S3103).stops[2]
	assert_eq(st.est_arr, D.t("08:27"))
	assert_eq(_svc(s, D.S3103).stops[3].est_arr, D.t("08:50"), "llegada estimada a Zaragoza")


func test_3105_inherits_600_by_rotation_material() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var sv: Service = _svc(s, D.S3105)
	assert_eq(sv.stops[0].est_dep, D.t("09:05"), "listo = 08:50 + 15 min de giro")
	assert_eq(sv.stops[0].sched_dep, D.t("08:55"), "el horario programado no cambia")
	var info: DelayInfo = s.delay_info(D.S3105)
	assert_eq(info.seconds, 600)
	assert_eq(info.cause, DelayInfo.CAUSE_ROTATION_MATERIAL)
	assert_eq(info.source_service_id, D.S3103)
	assert_eq(info.resource_id, &"cmp_c2")
	assert_eq(info.level, DelayInfo.LEVEL_MINOR)
	assert_eq(s.delay_of(D.S3105), 600)
	var ev: Array[LogEntry] = _propagated(s, D.S3105)
	assert_true(ev.size() >= 1, "DELAY_PROPAGATED registrado")
	if ev.size() >= 1:
		var last: LogEntry = ev[ev.size() - 1]
		assert_eq(str(last.data.get("cause", "")), "ROTATION_MATERIAL")
		assert_eq(str(last.data.get("source", "")), "svc_3103")
		assert_eq(int(last.data.get("seconds", -1)), 600)
		assert_eq(str(last.data.get("resource", "")), "cmp_c2")


func test_3105_is_prediction_not_actual() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	for st: ServiceStop in _svc(s, D.S3105).stops:
		assert_eq(st.act_arr, SimTime.NONE, "act_arr sin hechos reales aún")
		assert_eq(st.act_dep, SimTime.NONE, "act_dep sin hechos reales aún")
	assert_eq(_svc(s, D.S3105).status, Enums.ServiceStatus.SCHEDULED)


func test_3105_cascades_through_its_own_stops() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var sv: Service = _svc(s, D.S3105)
	# paradas con espera mínima (120 s = programada): el retraso se mantiene
	assert_eq(sv.stops[1].est_arr, D.t("09:40"))
	assert_eq(sv.stops[1].est_dep, D.t("09:42"))
	assert_eq(sv.stops[2].est_arr, D.t("10:04"))
	assert_eq(sv.stops[3].est_arr, D.t("10:30"))


func test_3106_and_3108_absorb() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	for id: StringName in [D.S3106, D.S3108]:
		var sv: Service = _svc(s, id)
		assert_eq(s.delay_of(id), 0, str(id))
		assert_eq(s.delay_info(id).cause, DelayInfo.CAUSE_NONE, str(id))
		assert_eq(s.delay_info(id).level, DelayInfo.LEVEL_ON_TIME)
		for st: ServiceStop in sv.stops:
			assert_eq(st.est_arr, st.sched_arr, "%s est_arr parada %d" % [id, st.index])
			assert_eq(st.est_dep, st.sched_dep, "%s est_dep parada %d" % [id, st.index])
		assert_eq(_propagated(s, id).size(), 0, "sin DELAY_PROPAGATED en " + str(id))


func test_3152_inherits_600_by_rotation_staff_coherent_with_graph() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var edge: RotationEdge = null
	for e: RotationEdge in s.rotation_graph().incoming(D.S3152):
		if e.from_service_id == D.S3103 and e.resource_type == Enums.ResourceType.DRIVER:
			edge = e
	assert_ne(edge, null, "el grafo tiene la arista de maquinista 3103→3152")
	if edge == null:
		return
	assert_eq(edge.resource_id, &"stf_d02")
	var a: Service = _svc(s, D.S3103)
	var b: Service = _svc(s, D.S3152)
	var ready: int = a.stops[edge.from_end_stop].est_arr + edge.min_connection_s
	assert_eq(ready, D.t("09:00"))
	assert_eq(b.stops[edge.to_start_stop].est_dep, ready, "salida estimada de Zaragoza = listo")
	assert_eq(ready - b.stops[edge.to_start_stop].sched_dep, 600)
	# 3152 está en marcha: el retraso solo es visible al llegar a Zaragoza (08:48)
	D.run_to_text(s, "08:49")
	assert_eq(b.status, Enums.ServiceStatus.STOPPED_AT_STATION)
	var info: DelayInfo = s.delay_info(D.S3152)
	assert_eq(info.seconds, 600)
	assert_eq(info.cause, DelayInfo.CAUSE_ROTATION_STAFF)
	assert_eq(info.resource_id, &"stf_d02")
	assert_eq(info.source_service_id, D.S3103)
	var ev: Array[LogEntry] = _propagated(s, D.S3152)
	assert_true(ev.size() >= 1)
	if ev.size() >= 1:
		assert_eq(str(ev[0].data.get("cause", "")), "ROTATION_STAFF")
		assert_eq(str(ev[0].data.get("resource", "")), "stf_d02")


func test_3105_conductor_edge_does_not_override_material_cause() -> void:
	# c02 (conductor) también conecta 3103→3105 con listo 09:00 < 09:05: manda el material
	var s: SimulationSession = D.injected(D.S3103, 1500)
	assert_eq(s.delay_info(D.S3105).cause, DelayInfo.CAUSE_ROTATION_MATERIAL)
	assert_eq(_svc(s, D.S3105).stops[0].est_dep, D.t("09:05"))


func test_actuals_match_prediction_after_running_the_day() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var predicted: Dictionary = {}
	for id: StringName in [D.S3103, D.S3105, D.S3106, D.S3108, D.S3152]:
		var arr: Array[Vector2i] = []
		for st: ServiceStop in _svc(s, id).stops:
			arr.append(Vector2i(st.est_arr, st.est_dep))
		predicted[id] = arr
	D.run_to(s, s.clock.day_end, 37)
	for id: StringName in predicted:
		var sv: Service = _svc(s, id)
		assert_eq(sv.status, Enums.ServiceStatus.TERMINATED, str(id))
		var pr: Array = predicted[id]
		for st: ServiceStop in sv.stops:
			var p: Vector2i = pr[st.index]
			# 3103: solo lo pendiente a las 08:00 (parada 2 en adelante)
			if id == D.S3103 and st.index < 2:
				continue
			if p.x != SimTime.NONE and st.stop_type != Enums.StopType.ORIGIN:
				assert_eq(st.act_arr, p.x, "%s parada %d llegada real = prevista" % [id, st.index])
			if p.y != SimTime.NONE and st.stop_type != Enums.StopType.DESTINATION:
				assert_eq(st.act_dep, p.y, "%s parada %d salida real = prevista" % [id, st.index])
	var s3105: Service = _svc(s, D.S3105)
	assert_eq(s3105.stops[0].act_dep, D.t("09:05"), "3105 sale realmente a 09:05")
	assert_eq(s3105.stops[3].act_arr, D.t("10:30"))
	assert_eq(s.delay_of(D.S3105), 600, "retraso real final del 3105")
	assert_eq(s.delay_of(D.S3103), 1500, "retraso real final del 3103")
	assert_eq(_svc(s, D.S3152).stops[3].act_dep, D.t("09:00"))
	assert_eq(s.delay_of(D.S3152), 600, "el 3152 llega a Madrid con +600")


func test_3106_3108_run_on_schedule_after_injection() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to(s, s.clock.day_end, 600)
	for id: StringName in [D.S3106, D.S3108]:
		for st: ServiceStop in _svc(s, id).stops:
			if st.stop_type != Enums.StopType.ORIGIN:
				assert_eq(st.act_arr, st.sched_arr, "%s parada %d" % [id, st.index])
			if st.stop_type != Enums.StopType.DESTINATION:
				assert_eq(st.act_dep, st.sched_dep, "%s parada %d" % [id, st.index])
		assert_eq(s.delay_of(id), 0)


func test_small_delay_absorbed_by_margin() -> void:
	var s: SimulationSession = D.injected(D.S3103, 300)
	assert_eq(s.delay_of(D.S3103), 300)
	assert_eq(_svc(s, D.S3105).stops[0].est_dep, D.t("08:55"), "3105 sin retraso")
	assert_eq(s.delay_of(D.S3105), 0)
	assert_eq(s.delay_info(D.S3105).cause, DelayInfo.CAUSE_NONE)
	assert_eq(_svc(s, D.S3152).stops[3].est_dep, D.t("08:50"))
	assert_eq(s.log.filter(&"DELAY_PROPAGATED").size(), 0)
	D.run_to(s, s.clock.day_end, 100000)
	assert_eq(_svc(s, D.S3105).stops[0].act_dep, D.t("08:55"))


func test_margin_boundary_900_absorbed_901_propagates_1() -> void:
	var s900: SimulationSession = D.injected(D.S3103, 900)
	assert_eq(_svc(s900, D.S3105).stops[0].est_dep, D.t("08:55"), "listo == salida: sin retraso")
	assert_eq(s900.delay_of(D.S3105), 0)
	var s901: SimulationSession = D.injected(D.S3103, 901)
	assert_eq(s901.delay_of(D.S3105), 1)
	assert_eq(s901.delay_info(D.S3105).level, DelayInfo.LEVEL_ON_TIME)
	var s1200: SimulationSession = D.injected(D.S3103, 1200)
	assert_eq(s1200.delay_of(D.S3105), 300)
	assert_eq(s1200.delay_info(D.S3105).level, DelayInfo.LEVEL_MINOR)


func test_repeated_injection_sums_and_equals_single() -> void:
	var twice: SimulationSession = SimFixture.session()
	D.run_to_text(twice, "08:00")
	assert_true(twice.apply_command(InjectDelayCommand.make(D.S3103, 600)))
	assert_true(twice.apply_command(InjectDelayCommand.make(D.S3103, 900)))
	assert_eq(twice.delay_of(D.S3103), 1500)
	var once: SimulationSession = D.injected(D.S3103, 1500)
	assert_eq(D.state_dump(twice), D.state_dump(once), "dos inyecciones = una de la suma (est_*)")
	assert_eq(twice.delay_of(D.S3105), 600)
	assert_eq(twice.command_log.size(), 2)


func test_repeated_injection_at_different_times() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "08:00")
	s.apply_command(InjectDelayCommand.make(D.S3103, 600))
	D.run_to_text(s, "08:13", 37)  # ya detenido en Calatayud con +600 (llegó 08:12, sale 08:14)
	assert_eq(_svc(s, D.S3103).status, Enums.ServiceStatus.STOPPED_AT_STATION)
	assert_eq(s.delay_of(D.S3103), 600)
	s.apply_command(InjectDelayCommand.make(D.S3103, 600))
	assert_eq(s.delay_of(D.S3103), 1200, "segunda inyección sobre servicio detenido suma")
	assert_eq(_svc(s, D.S3103).stops[3].est_arr, D.t("08:45"))
	assert_eq(s.delay_of(D.S3105), 300, "08:45 + 15 min = 09:00 vs 08:55")
	D.run_to(s, s.clock.day_end, 100000)
	assert_eq(_svc(s, D.S3105).stops[0].act_dep, D.t("09:00"))


func test_recovery_in_stops_down_to_min_dwell() -> void:
	# 3105 con 12 min de espera programada en Lleida (min_dwell 120 s): recupera hasta el mínimo
	var s: SimulationSession = SimFixture.session()
	var sv: Service = _svc(s, D.S3105)
	sv.stops[1].sched_dep = D.t("09:42")
	sv.stops[1].est_dep = D.t("09:42")
	assert_eq(sv.stops[1].min_dwell_s, 120)
	s.apply_command(InjectDelayCommand.make(D.S3105, 600))
	assert_eq(sv.stops[1].est_arr, D.t("09:40"), "+600 a la llegada a Lleida")
	assert_eq(sv.stops[1].est_dep, D.t("09:42"), "la espera se recorta de 12 min a 2 min: sale a su hora")
	assert_eq(sv.stops[2].est_arr, D.t("09:54"), "retraso totalmente recuperado")
	assert_eq(sv.stops[3].est_arr, D.t("10:20"))
	D.run_to_text(s, "09:41")
	assert_eq(s.delay_of(D.S3105), 0, "parado en Lleida sin retraso de salida")
	D.run_to(s, s.clock.day_end)
	assert_eq(s.delay_of(D.S3105), 0)
	assert_eq(sv.stops[1].act_dep, D.t("09:42"))


func test_recovery_never_below_min_dwell() -> void:
	var s: SimulationSession = SimFixture.session()
	var sv: Service = _svc(s, D.S3105)
	sv.stops[1].sched_dep = D.t("09:42")
	sv.stops[1].est_dep = D.t("09:42")
	s.apply_command(InjectDelayCommand.make(D.S3105, 900))
	assert_eq(sv.stops[1].est_arr, D.t("09:45"))
	assert_eq(sv.stops[1].est_dep, D.t("09:47"), "espera mínima 120 s")
	assert_eq(sv.stops[1].est_dep - sv.stops[1].est_arr, sv.stops[1].min_dwell_s)
	assert_eq(sv.stops[2].est_arr, D.t("09:59"), "queda +5 min tras agotar la recuperación")


func test_recovery_pct_documented_behaviour() -> void:
	# recovery_pct: recorta ese % del tiempo de recorrido programado de cada tramo, sin superar el retraso acumulado
	var s: SimulationSession = SimFixture.session()
	s.queue.push(SimEventType.DELAY_APPLIED, s.clock.now, D.S3105, -1,
			{"seconds": 600, "cause": DelayInfo.CAUSE_INJECTED, "recovery_pct": 10})
	s.process_due_events()
	var sv: Service = _svc(s, D.S3105)
	assert_eq(sv.stops[0].est_dep, D.t("09:05"))
	# tramo Zaragoza→Lleida programado 35 min = 2100 s; 10 % = 210 s recuperados
	assert_eq(sv.stops[1].est_arr, D.t("09:30") + 390)
	assert_true(sv.stops[3].est_arr < D.t("10:20") + 600, "con recuperación llega con menos de +600")
	assert_true(sv.stops[3].est_arr >= D.t("10:20"))
