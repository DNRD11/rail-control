extends TestCase
## Prueba de aceptación automatizada del MVP (docs/ROADMAP.md, «Prueba de aceptación del MVP»), headless y
## solo sobre la API pública de SimulationSession. Los 9 pasos:
##  1 iniciar jornada · 2 dos servicios con material circulando · 3 posición y avance temporal ·
##  4 avería en 3103 · 5 retraso observado · 6 efecto en 3105 (rotación en ZAR) ·
##  7 decisión (las tres variantes) · 8 consecuencias en viajeros y economía · 9 fin de jornada e informe.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const E = preload("res://tests/framework/economy_fixture.gd")

const SEED: int = 12345
const REPAIR: int = 5400
const OPTIONS: Array[StringName] = [OptionType.WAIT_REPAIR, OptionType.SUBSTITUTE_ROLLING_STOCK,
		OptionType.CANCEL_SERVICE]


## Paso 1 con la ruta real de carga (ScenarioLoader + validador) y la avería con reparación fija.
func _start_day() -> SimulationSession:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(ScenarioFixture.MVP)
	assert_true(res.ok, "el escenario MVP carga sin errores: %s" % res.report.summary())
	for d: Dictionary in res.world.scenario.scripted_incidents:
		d["repair_s"] = [REPAIR, REPAIR]
	return SimulationSession.create(res.world, SEED)


func _day_with(option: StringName, inform: bool = true) -> SimulationSession:
	var s: SimulationSession = _start_day()
	D.run_to_text(s, "08:12")
	assert_true(F.decide(s, option), "decisión %s aceptada" % option)
	if inform:
		assert_true(s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id)))
	D.run_to(s, s.clock.day_end, 300)
	return s


func _ledger_sum(s: SimulationSession, ref_id: StringName, category: StringName) -> int:
	return E.sum_amount(E.entries_ref(s, "SERVICE", ref_id).filter(
			func(e: Variant) -> bool: return E.cat_of(e) == String(category)))


# --- Pasos 1 a 3 ----------------------------------------------------------------------------

func test_step1_start_of_day() -> void:
	var s: SimulationSession = _start_day()
	assert_eq(s.clock.now, D.t("06:00"))
	assert_eq(s.clock.day_end, D.t("15:00"))
	assert_eq(s.clock.speed, 1)
	assert_false(s.clock.is_day_over())
	assert_eq(s.service_ids().size(), 10)
	for sid: StringName in s.service_ids():
		assert_eq(s.world.services[sid].status, Enums.ServiceStatus.SCHEDULED, "%s programado" % sid)
		assert_eq(s.query_service_position(sid).state, ServicePosition.State.NOT_STARTED)
	assert_eq(s.active_service_ids().size(), 0)
	assert_eq(s.open_incidents().size(), 0)
	assert_eq(s.query_ledger().entries.size(), 0, "libro vacío")
	assert_eq(s.log.count(), 0)
	var ind: Indicators = s.query_indicators()
	assert_eq(ind.result_cents, 0)
	assert_eq(ind.quality, 100.0)
	assert_eq(ind.affected, 0)


func test_step2_two_or_more_services_with_rolling_stock_running() -> void:
	var s: SimulationSession = _start_day()
	D.run_to_text(s, "07:10")
	var active: Array[StringName] = s.active_service_ids()
	assert_true(active.size() >= 2, "al menos dos servicios circulando a las 07:10, hay %d" % active.size())
	for expected: StringName in [&"svc_3101", &"svc_3150", &"svc_3103"]:
		assert_true(active.has(expected), "%s circula a las 07:10" % expected)
	assert_false(active.has(&"svc_3152"), "3152 sale a las 07:30")
	for sid: StringName in active:
		var comps: Array[StringName] = s.world.assignments.resource_ids_for(sid, Enums.ResourceType.COMPOSITION)
		assert_true(comps.size() >= 1, "%s tiene material asignado" % sid)
		var found_slot: bool = false
		for sl: ResourceSlot in s.query_service_resources(sid):
			if sl.resource_type == Enums.ResourceType.COMPOSITION and sl.is_current:
				found_slot = true
		assert_true(found_slot, "%s expone su composición en curso" % sid)
		for cid: StringName in comps:
			for vid: StringName in (s.world.compositions[cid] as Composition).vehicle_ids():
				assert_eq(s.world.vehicles[vid].status, Enums.VehicleStatus.IN_SERVICE, "vehículo %s en servicio" % vid)
	assert_eq(s.world.assignments.resource_ids_for(&"svc_3101", Enums.ResourceType.COMPOSITION),
			[&"cmp_c1"] as Array[StringName])


func test_step3_position_and_time_progress() -> void:
	var s: SimulationSession = _start_day()
	D.run_to_text(s, "07:00")
	var p: ServicePosition = s.query_service_position(&"svc_3101")
	assert_eq(p.state, ServicePosition.State.IN_SECTION, "3101 entre Guadalajara y Calatayud a las 07:00")
	assert_eq(p.stop_index, 1)
	var sv: Service = s.world.services[&"svc_3101"]
	var expected_frac: float = float(D.t("07:00") - D.t("06:47")) / float(D.t("07:24") - D.t("06:47"))
	assert_near(p.fraction, expected_frac, 0.001, "avance temporal dentro del tramo")
	var ka: float = s.world.stations[sv.stops[1].station_id].km
	var kb: float = s.world.stations[sv.stops[2].station_id].km
	assert_near(p.km, ka + (kb - ka) * expected_frac, 0.5, "km interpolado entre estaciones")
	# avanza monótonamente con el reloj
	var last_km: float = p.km
	for i: int in 6:
		s.advance_seconds(60)
		var q: ServicePosition = s.query_service_position(&"svc_3101")
		assert_true(q.km >= last_km, "el km no retrocede")
		last_km = q.km
	assert_true(last_km > p.km, "la posición avanza con el tiempo")
	# 3103 en Madrid-Guadalajara a las 07:10 (salió a las 07:00)
	var p3103: ServicePosition = s.query_service_position(&"svc_3103")
	assert_eq(p3103.state, ServicePosition.State.IN_SECTION)
	assert_eq(p3103.stop_index, 0)
	# parada comercial: 3103 está en Guadalajara 07:20-07:22
	D.run_to_text(s, "07:21")
	var st: ServicePosition = s.query_service_position(&"svc_3103")
	assert_eq(st.state, ServicePosition.State.AT_STATION)
	assert_eq(st.stop_index, 1)
	# sin retrasos, la posición real coincide con la programada
	var sched: ServicePosition = s.query_scheduled_position(&"svc_3103", float(s.clock.now))
	assert_eq(sched.state, st.state)
	assert_near(sched.km, st.km, 0.001)


# --- Pasos 4 a 6 ----------------------------------------------------------------------------

func test_step4_breakdown_on_3103_at_0812() -> void:
	var s: SimulationSession = _start_day()
	D.run_to(s, D.t("08:12") - 1)
	assert_eq(s.all_incidents().size(), 0, "aún no hay avería")
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.RUNNING)
	D.run_to_text(s, "08:12")
	var inc: Incident = F.incident(s)
	assert_ne(inc, null, "avería detectada a las 08:12")
	assert_eq(inc.service_id, D.S3103)
	assert_eq(inc.type_id, &"ROLLING_STOCK_FAILURE")
	assert_eq(inc.status, Enums.IncidentStatus.AWAITING_DECISION)
	assert_eq(inc.detected_at, D.t("08:12"))
	assert_eq(inc.composition_id, &"cmp_c2")
	assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.FAILED)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.HELD)
	assert_eq(s.open_incidents().size(), 1)
	assert_eq(s.log.filter(IncidentSystem.LOG_DETECTED).size(), 1)
	assert_eq(inc.options.size(), 3, "tres opciones: esperar, sustituir y cancelar")
	for opt: StringName in OPTIONS:
		assert_true(inc.option(opt) != null and inc.option(opt).available, "%s disponible" % opt)


func test_step5_delay_observed_on_3103() -> void:
	var s: SimulationSession = _start_day()
	D.run_to_text(s, "08:12")
	var at_detection: int = s.delay_of(D.S3103)
	assert_true(at_detection > 0, "retraso proyectado desde la detección")
	assert_eq(s.delay_info(D.S3103).cause, DelayInfo.CAUSE_BREAKDOWN)
	F.decide(s, OptionType.WAIT_REPAIR)
	D.run_to_text(s, "09:00")
	assert_true(s.delay_of(D.S3103) > at_detection, "el retraso crece mientras dura la reparación")
	assert_eq(s.delay_info(D.S3103).level, DelayInfo.LEVEL_SEVERE, "90 min proyectados = grave")
	D.run_to(s, D.t("08:12") + REPAIR)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.RUNNING, "reanuda al reparar")
	D.run_to_text(s, "10:30")
	assert_eq(s.world.services[D.S3103].stops[3].act_arr, D.t("08:25") + REPAIR, "llega a ZAR con el retraso de la reparación")
	assert_eq(s.delay_info(D.S3103).seconds, REPAIR)
	assert_eq(s.delay_info(D.S3103).level, DelayInfo.LEVEL_SEVERE)


func test_step6_effect_on_3105_by_rotation_in_zaragoza() -> void:
	var s: SimulationSession = _start_day()
	D.run_to_text(s, "08:12")
	F.decide(s, OptionType.WAIT_REPAIR)
	var sv: Service = s.world.services[D.S3105]
	assert_eq(sv.stops[0].station_id, &"sta_zar", "3105 sale de Zaragoza, donde termina 3103")
	var info: DelayInfo = s.delay_info(D.S3105)
	assert_eq(info.cause, DelayInfo.CAUSE_ROTATION_MATERIAL)
	assert_eq(info.source_service_id, D.S3103)
	assert_eq(info.resource_id, &"cmp_c2", "mismo material")
	var expected_dep: int = D.t("08:25") + REPAIR + s.world.scenario.transfer_s
	assert_eq(sv.stops[0].est_dep, expected_dep, "sale tras llegada + giro mínimo en ZAR")
	assert_eq(info.seconds, expected_dep - D.t("08:55"))
	assert_eq(sv.stops[0].sched_dep, D.t("08:55"), "el horario programado no se toca")
	var found_link: bool = false
	for l: ChainLink in s.query_service_chain(D.S3103):
		if l.next_service_id == D.S3105 and l.is_material:
			found_link = true
			assert_eq(l.station_id, &"sta_zar")
			assert_eq(l.predicted_delay_s, info.seconds)
	assert_true(found_link, "la cadena del 3103 incluye al 3105 por material")
	D.run_to_text(s, "11:00")
	assert_eq(sv.stops[0].act_dep, expected_dep, "el hecho real coincide con la predicción")
	assert_eq(s.log.filter(&"DELAY_PROPAGATED", D.S3105).size() > 0, true)


# --- Paso 7: las tres variantes -----------------------------------------------------------------

func test_step7_three_decisions_have_distinct_recorded_outcomes() -> void:
	var seen_dep: Array[int] = []
	var seen_cost: Array[int] = []
	for opt: StringName in OPTIONS:
		var s: SimulationSession = _start_day()
		D.run_to_text(s, "08:12")
		assert_true(F.decide(s, opt))
		var inc: Incident = F.incident(s)
		assert_eq(inc.decision.option_type, opt)
		assert_false(inc.decision.automatic)
		assert_eq(s.command_log.back().kind, &"RESOLVE_INCIDENT")
		assert_eq(s.log.filter(IncidentSystem.LOG_DECISION).size(), 1)
		D.run_to_text(s, "12:00")
		seen_dep.append(s.world.services[D.S3105].stops[0].act_dep)
		seen_cost.append(inc.decision.total_cost_cents())
		match opt:
			OptionType.WAIT_REPAIR:
				assert_eq(inc.status, Enums.IncidentStatus.RESOLVED)
				assert_eq(F.comp_of(s, D.S3105), &"cmp_c2")
				assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.IN_SERVICE)
			OptionType.SUBSTITUTE_ROLLING_STOCK:
				assert_eq(F.comp_of(s, D.S3105), &"cmp_res_v6", "3105 sale con la reserva")
				assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.FAILED)
				assert_false(s.world.services[D.S3103].is_cancelled())
			OptionType.CANCEL_SERVICE:
				assert_true(s.world.services[D.S3103].is_cancelled())
				assert_eq(s.world.services[D.S3105].stops[0].act_dep, D.t("08:55"), "3105 sale a su hora con la reserva")
	assert_eq(seen_dep.size(), 3)
	assert_ne(seen_dep[0], seen_dep[1])
	assert_ne(seen_dep[1], seen_dep[2])
	assert_ne(seen_cost[0], seen_cost[1])
	assert_ne(seen_cost[1], seen_cost[2])


# --- Paso 8: viajeros y economía -----------------------------------------------------------------

func test_step8_wait_repair_consequences() -> void:
	var s: SimulationSession = _day_with(OptionType.WAIT_REPAIR)
	var ledger: Ledger = s.query_ledger()
	assert_eq(ledger.total_by_category(&"INCIDENT_COST"), -s.world.incident_rules.repair_on_route_cents)
	assert_eq(ledger.total_by_category(&"SUBSTITUTION_COST"), 0)
	assert_true(ledger.entries_for_ref(&"INCIDENT", F.incident(s).id).size() >= 1, "coste de la decisión referenciado a la incidencia")
	var pax: ServicePassengerLoad = s.query_service_passengers(D.S3103)
	assert_eq(pax.affected, 290)
	assert_eq(pax.needing_alternative, 0)
	assert_eq(pax.continuing, 290)
	assert_eq(pax.compensation_eligible, 290, "90 min de retraso en destino = 100 %")
	assert_true(_ledger_sum(s, D.S3103, &"COMPENSATION") < 0)
	assert_true(_ledger_sum(s, D.S3105, &"COMPENSATION") < 0, "los viajeros del 3105 también se indemnizan")
	assert_true(_ledger_sum(s, D.S3103, &"REVENUE") > 0, "el 3103 sigue ingresando")
	var ind: Indicators = s.query_indicators()
	assert_true(ind.affected >= 580)
	assert_true(ind.compensated >= 580)
	assert_true(ind.perception < 75.0 and ind.quality < 100.0)


func test_step8_substitute_consequences() -> void:
	var s: SimulationSession = _day_with(OptionType.SUBSTITUTE_ROLLING_STOCK)
	var ledger: Ledger = s.query_ledger()
	assert_true(ledger.total_by_category(&"SUBSTITUTION_COST") < 0, "movilización y vacío")
	assert_true(ledger.total_by_category(&"INCIDENT_COST") < 0, "rescate")
	var pax: ServicePassengerLoad = s.query_service_passengers(D.S3103)
	assert_eq(pax.needing_alternative, 0, "nadie queda sin transporte")
	assert_eq(pax.continuing, pax.affected)
	assert_true(_ledger_sum(s, D.S3103, &"REVENUE") > 0)
	var wait: SimulationSession = _day_with(OptionType.WAIT_REPAIR)
	assert_true(-_ledger_sum(s, D.S3105, &"COMPENSATION") < -_ledger_sum(wait, D.S3105, &"COMPENSATION"),
			"sustituir reduce la indemnización del 3105")
	assert_true(E.ind(s, "perception") > E.ind(wait, "perception"))
	assert_true(E.ind(s, "result_cents") > E.ind(wait, "result_cents"), "con 90 min de avería sustituir da mejor resultado")


func test_step8_cancel_consequences() -> void:
	var s: SimulationSession = _day_with(OptionType.CANCEL_SERVICE)
	var pax: ServicePassengerLoad = s.query_service_passengers(D.S3103)
	assert_eq(pax.needing_alternative, 290, "viajeros que necesitan alternativa")
	assert_eq(pax.carried, 0)
	assert_eq(s.query_indicators().needing_alternative, 290)
	var fare: int = _ledger_sum(E.quiet_day(), D.S3103, &"REVENUE")
	assert_true(fare > 0)
	assert_eq(_ledger_sum(s, D.S3103, &"REVENUE"), 0, "no se cobra el billete de un servicio cancelado")
	assert_eq(-_ledger_sum(s, D.S3103, &"COMPENSATION"), fare, "indemnización del 100 % del billete")
	assert_eq(s.economy.lost_revenue_cents, fare, "ingreso no cobrado informativo")
	assert_true(E.ind(s, "perception") < 75.0 - 20.0, "cancelar hunde la percepción")


# --- Paso 9 ------------------------------------------------------------------------------------

func test_step9_end_of_day_and_report_data() -> void:
	for opt: StringName in OPTIONS:
		var s: SimulationSession = _start_day()
		var finished: Array[int] = [0]
		s.day_finished.connect(func() -> void: finished[0] += 1)
		D.run_to_text(s, "08:12")
		F.decide(s, opt)
		D.run_to(s, s.clock.day_end, 600)
		assert_true(s.clock.is_day_over(), "jornada terminada (%s)" % opt)
		assert_eq(finished[0], 1, "day_finished una vez")
		assert_eq(s.log.filter(SimEventType.DAY_END).size(), 1)
		assert_eq(s.open_incidents().size(), 0, "sin incidencias abiertas")
		for sid: StringName in s.service_ids():
			var st: int = s.world.services[sid].status
			assert_true(st == Enums.ServiceStatus.TERMINATED or st == Enums.ServiceStatus.CANCELLED
					or st == Enums.ServiceStatus.PARTIALLY_CANCELLED, "%s cerrado con %s" % [sid, opt])
			assert_true(s.query_ledger().entries_for_ref(&"SERVICE", sid).size() >= 1, "%s liquidado" % sid)
		var ind: Indicators = s.query_indicators()
		assert_eq(ind.result_cents, s.query_ledger().total_cents(), "resultado = suma del libro")
		for cat: StringName in [&"REVENUE", &"OPERATING_COST", &"STAFF_COST", &"INFRA_CHARGE_ORDINARY"]:
			assert_ne(s.query_ledger().total_by_category(cat), 0, "categoría %s con apuntes (%s)" % [cat, opt])
		assert_true(ind.quality >= 0.0 and ind.quality <= 100.0)
		assert_true(ind.perception >= 0.0 and ind.perception <= 100.0)
		# avanzar de más no cambia el informe
		var digest: String = E.ledger_digest(s)
		s.advance_seconds(3600)
		assert_eq(E.ledger_digest(s), digest, "el libro queda cerrado")
		assert_eq(s.query_indicators().result_cents, ind.result_cents)
		assert_eq(F.incident(s).status, Enums.IncidentStatus.RESOLVED)
		assert_eq(F.incident(s).decision.option_type, opt)
