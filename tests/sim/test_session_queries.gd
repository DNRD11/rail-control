extends TestCase
## Consultas de solo lectura: delay_info, posiciones, recursos, cadena, estados y resumen.

const D = preload("res://tests/framework/delay_fixture.gd")


func _slot(slots: Array[ResourceSlot], rid: StringName) -> ResourceSlot:
	for sl: ResourceSlot in slots:
		if sl.resource_id == rid:
			return sl
	return null


func _link(links: Array[ChainLink], next_id: StringName, type: Enums.ResourceType) -> ChainLink:
	for l: ChainLink in links:
		if l.next_service_id == next_id and l.resource_type == type:
			return l
	return null


func _state(states: Array[ResourceState], rid: StringName) -> ResourceState:
	for r: ResourceState in states:
		if r.resource_id == rid:
			return r
	return null


# --- delay_info ---

func test_delay_level_thresholds() -> void:
	var cases: Array = [[0, &"ON_TIME"], [180, &"ON_TIME"], [181, &"MINOR"], [900, &"MINOR"],
			[901, &"MAJOR"], [3600, &"MAJOR"], [3601, &"SEVERE"]]
	for c: Array in cases:
		assert_eq(DelayInfo.level_for(c[0]), c[1], "level_for(%d)" % c[0])
		var s: SimulationSession = SimFixture.session()
		if int(c[0]) > 0:
			assert_true(s.apply_command(InjectDelayCommand.make(D.S3105, c[0])))
		var info: DelayInfo = s.delay_info(D.S3105)
		assert_eq(info.seconds, c[0])
		assert_eq(info.level, c[1], "delay_info.level con %d s" % c[0])


func test_delay_info_without_delay_and_unknown() -> void:
	var s: SimulationSession = SimFixture.session()
	var info: DelayInfo = s.delay_info(D.S3105)
	assert_eq(info.seconds, 0)
	assert_eq(info.cause, DelayInfo.CAUSE_NONE)
	assert_eq(info.level, DelayInfo.LEVEL_ON_TIME)
	assert_eq(info.source_service_id, &"")
	assert_eq(s.delay_info(&"svc_9999"), null)
	assert_eq(s.delay_of(&"svc_9999"), 0)


func test_delay_info_cause_cleared_when_delay_recovered() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to(s, s.clock.day_end)
	assert_eq(s.delay_info(D.S3106).cause, DelayInfo.CAUSE_NONE)
	assert_eq(s.delay_info(D.S3103).seconds, 1500, "real del último punto del servicio terminado")


# --- posiciones ---

func test_scheduled_position_equals_real_without_delay() -> void:
	var s: SimulationSession = SimFixture.session()
	var compared: int = 0
	while not s.clock.is_day_over():
		s.advance_seconds(61)
		for sid: StringName in s.service_ids():
			var real: ServicePosition = s.query_service_position_at(sid, float(s.clock.now))
			var sched: ServicePosition = s.query_scheduled_position(sid, float(s.clock.now))
			var ctx: String = "%s en %s" % [sid, SimTime.format(s.clock.now, true)]
			assert_eq(real.state, sched.state, "estado " + ctx)
			assert_eq(real.stop_index, sched.stop_index, "parada " + ctx)
			assert_true(absf(real.km - sched.km) < 0.001, "km %f vs %f en %s" % [real.km, sched.km, ctx])
			assert_true(absf(real.fraction - sched.fraction) < 0.001, "fracción " + ctx)
			compared += 1
	assert_true(compared > 0)


func test_position_at_equals_position_at_now() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:30")
	var a: ServicePosition = s.query_service_position(D.S3103)
	var b: ServicePosition = s.query_service_position_at(D.S3103, float(s.clock.now))
	assert_eq(a.state, b.state)
	assert_eq(a.km, b.km)
	assert_eq(a.fraction, b.fraction)


func test_position_at_fractional_interpolates() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:30")  # entre Madrid (07:00) y Guadalajara (07:20)... ya en el tramo siguiente
	var p0: ServicePosition = s.query_service_position_at(D.S3103, float(s.clock.now))
	var p1: ServicePosition = s.query_service_position_at(D.S3103, float(s.clock.now) + 0.5)
	var p2: ServicePosition = s.query_service_position_at(D.S3103, float(s.clock.now) + 30.0)
	assert_eq(p0.state, ServicePosition.State.IN_SECTION)
	assert_eq(p1.state, ServicePosition.State.IN_SECTION)
	assert_true(p0.fraction < p1.fraction and p1.fraction < p2.fraction, "fracción creciente")
	assert_true(p0.km < p1.km and p1.km < p2.km, "km creciente (sentido ascendente)")
	assert_true(p0.fraction > 0.0 and p2.fraction <= 1.0)


func test_real_position_lags_scheduled_with_delay() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var base: SimulationSession = SimFixture.session()
	for hhmm: String in ["08:00", "08:10", "08:20"]:
		D.run_to_text(s, hhmm, 60)
		D.run_to_text(base, hhmm, 60)
		var t: float = float(D.t(hhmm))
		var real: ServicePosition = s.query_service_position_at(D.S3103, t)
		var sched: ServicePosition = s.query_scheduled_position(D.S3103, t)
		assert_eq(real.state, ServicePosition.State.IN_SECTION, hhmm)
		assert_eq(real.direction, Enums.Direction.ASCENDING)
		assert_true(real.km < sched.km - 0.001, "%s: real km %f debe ir por detrás de programado %f" % [hhmm, real.km, sched.km])
		var sched_base: ServicePosition = base.query_scheduled_position(D.S3103, t)
		assert_eq(sched.km, sched_base.km, "la sombra programada no depende del retraso (%s)" % hhmm)
		assert_eq(sched.stop_index, sched_base.stop_index)


func test_scheduled_position_window_states() -> void:
	var s: SimulationSession = SimFixture.session()
	var before: ServicePosition = s.query_scheduled_position(D.S3103, float(D.t("06:30")))
	assert_eq(before.state, ServicePosition.State.NOT_STARTED)
	assert_eq(before.stop_index, 0)
	var after: ServicePosition = s.query_scheduled_position(D.S3103, float(D.t("09:00")))
	assert_eq(after.state, ServicePosition.State.FINISHED)
	assert_eq(after.stop_index, 3)
	var mid: ServicePosition = s.query_scheduled_position(D.S3103, float(D.t("07:21")))
	assert_eq(mid.state, ServicePosition.State.AT_STATION, "en Guadalajara durante la espera programada")
	assert_eq(s.query_scheduled_position(&"svc_9999", 0.0), null)
	assert_eq(s.query_service_position_at(&"svc_9999", 0.0), null)


# --- recursos del servicio ---

func test_service_resources_relief_at_zaragoza() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:49")  # 3101 detenido en Zaragoza (07:48-07:50)
	assert_eq(s.world.services[&"svc_3101"].status, Enums.ServiceStatus.STOPPED_AT_STATION)
	var slots: Array[ResourceSlot] = s.query_service_resources(&"svc_3101")
	var d01: ResourceSlot = _slot(slots, &"stf_d01")
	var d04: ResourceSlot = _slot(slots, &"stf_d04")
	assert_ne(d01, null)
	assert_ne(d04, null)
	assert_true(d01.is_current, "el maquinista saliente cubre la parada de relevo")
	assert_true(d04.is_current, "el entrante también")
	assert_eq(d01.label, "Lucía Marín")
	assert_eq(d04.label, "Raúl Cebrián")
	assert_eq(d01.resource_type, Enums.ResourceType.DRIVER)
	assert_eq([d01.from_stop_index, d01.to_stop_index], [0, 3])
	assert_eq([d04.from_stop_index, d04.to_stop_index], [3, 6])
	assert_eq([d01.from_station_id, d01.to_station_id], [&"sta_mad", &"sta_zar"])
	assert_eq([d04.from_station_id, d04.to_station_id], [&"sta_zar", &"sta_bcn"])
	assert_eq(d01.assignment_id, &"asg_3101_d01_03")
	var comp: ResourceSlot = _slot(slots, &"cmp_c1")
	assert_eq(comp.label, "C1")
	assert_true(comp.is_current)
	var c01: ResourceSlot = _slot(slots, &"stf_c01")
	assert_eq(c01.role, &"CHIEF_CONDUCTOR")
	assert_eq(_slot(slots, &"stf_c05").label, "Carmen Ibáñez")
	assert_true(_slot(slots, &"stf_c05").is_current, "interventor 0-3 cubre la parada de Zaragoza")


func test_service_resources_current_by_leg() -> void:
	var s: SimulationSession = SimFixture.session()
	var sched: Array[ResourceSlot] = s.query_service_resources(&"svc_3101")
	assert_true(_slot(sched, &"stf_d01").is_current, "programado: primer tramo")
	assert_false(_slot(sched, &"stf_d04").is_current)
	D.run_to_text(s, "07:00")
	var first: Array[ResourceSlot] = s.query_service_resources(&"svc_3101")
	assert_true(_slot(first, &"stf_d01").is_current)
	assert_false(_slot(first, &"stf_d04").is_current)
	D.run_to_text(s, "08:00")  # tramo Zaragoza → Lleida
	var second: Array[ResourceSlot] = s.query_service_resources(&"svc_3101")
	assert_false(_slot(second, &"stf_d01").is_current)
	assert_true(_slot(second, &"stf_d04").is_current)
	assert_false(_slot(second, &"stf_c05").is_current)
	assert_true(_slot(second, &"stf_c01").is_current)
	D.run_to(s, s.clock.day_end)
	for sl: ResourceSlot in s.query_service_resources(&"svc_3101"):
		assert_false(sl.is_current, "servicio terminado: nada en curso (%s)" % sl.resource_id)
	assert_eq(s.query_service_resources(&"svc_9999").size(), 0)


func test_service_resources_order_stable() -> void:
	var s: SimulationSession = SimFixture.session()
	var slots: Array[ResourceSlot] = s.query_service_resources(&"svc_3101")
	assert_eq(slots.size(), 5)
	for i: int in range(1, slots.size()):
		var a: ResourceSlot = slots[i - 1]
		var b: ResourceSlot = slots[i]
		assert_true(a.resource_type < b.resource_type or (a.resource_type == b.resource_type
				and a.from_stop_index <= b.from_stop_index), "orden por tipo y tramo")
	assert_eq(slots[0].resource_type, Enums.ResourceType.COMPOSITION)


# --- cadena ---

func test_service_chain_3103_before_and_after_injection() -> void:
	var s: SimulationSession = SimFixture.session()
	var links: Array[ChainLink] = s.query_service_chain(D.S3103)
	var mat: ChainLink = _link(links, D.S3105, Enums.ResourceType.COMPOSITION)
	assert_ne(mat, null)
	assert_true(mat.is_material)
	assert_eq(mat.resource_id, &"cmp_c2")
	assert_eq(mat.label, "C2")
	assert_eq(mat.station_id, &"sta_zar")
	assert_eq(mat.margin_s, 900)
	assert_eq(mat.predicted_delay_s, 0)
	assert_eq(mat.next_departure, D.t("08:55"))
	D.run_to_text(s, "08:00")
	s.apply_command(InjectDelayCommand.make(D.S3103, 1500))
	links = s.query_service_chain(D.S3103)
	mat = _link(links, D.S3105, Enums.ResourceType.COMPOSITION)
	assert_eq(mat.margin_s, 0, "09:05 - (08:50 + 15 min)")
	assert_eq(mat.predicted_delay_s, 600)
	assert_eq(mat.next_departure, D.t("09:05"))
	var staff: ChainLink = _link(links, D.S3152, Enums.ResourceType.DRIVER)
	assert_ne(staff, null)
	assert_false(staff.is_material)
	assert_eq(staff.resource_id, &"stf_d02")
	assert_eq(staff.label, "Andrés Prieto")
	assert_eq(staff.predicted_delay_s, 600)
	assert_eq(staff.margin_s, 0)
	var cond: ChainLink = _link(links, D.S3105, Enums.ResourceType.CONDUCTOR)
	assert_ne(cond, null)
	assert_eq(cond.predicted_delay_s, 600)
	assert_eq(cond.margin_s, 300, "09:05 - (08:50 + 10 min)")


func test_service_chain_absorbing_link_and_edges() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var l: ChainLink = _link(s.query_service_chain(D.S3105), D.S3106, Enums.ResourceType.COMPOSITION)
	assert_ne(l, null)
	assert_eq(l.predicted_delay_s, 0)
	assert_eq(l.margin_s, D.t("11:00") - (D.t("10:30") + 1200), "margen vigente con est_*")
	assert_eq(s.query_service_chain(D.S3108).size(), 0, "último de la cadena sin salientes de material")
	assert_eq(s.query_service_chain(&"svc_9999").size(), 0)


func test_service_chain_uses_actuals_after_the_fact() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to_text(s, "09:10", 37)
	var mat: ChainLink = _link(s.query_service_chain(D.S3103), D.S3105, Enums.ResourceType.COMPOSITION)
	assert_eq(mat.margin_s, 0)
	assert_eq(mat.predicted_delay_s, 600)
	assert_eq(s.world.services[D.S3105].stops[0].act_dep, D.t("09:05"))


# --- estados de recursos ---

func test_resource_states_composition_cmp_c2_over_the_day() -> void:
	var s: SimulationSession = SimFixture.session()
	var r: ResourceState = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IDLE)
	assert_eq(r.station_id, &"sta_mad")
	assert_eq(r.next_service_id, D.S3103)
	assert_eq(r.next_departure, D.t("07:00"))
	assert_eq(r.label, "C2")
	D.run_to_text(s, "07:30")
	r = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IN_SERVICE)
	assert_eq(r.current_service_id, D.S3103)
	assert_eq(r.station_id, &"", "en circulación no está en estación")
	D.run_to_text(s, "08:30")
	r = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IDLE, "entre 3103 y 3105")
	assert_eq(r.station_id, &"sta_zar")
	assert_eq(r.next_service_id, D.S3105)
	assert_eq(r.next_departure, D.t("08:55"))
	D.run_to_text(s, "09:00")
	r = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IN_SERVICE)
	assert_eq(r.current_service_id, D.S3105)
	D.run_to(s, s.clock.day_end)
	r = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IDLE)
	assert_eq(r.station_id, &"sta_mad", "termina en Madrid con el 3108")
	assert_eq(r.next_service_id, &"")


func test_resource_states_cmp_c2_with_injection() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to_text(s, "08:30")
	var r: ResourceState = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IN_SERVICE, "el 3103 aún circula")
	assert_eq(r.current_service_id, D.S3103)
	assert_eq(r.next_departure, D.t("09:05"), "salida estimada del siguiente, con retraso")
	D.run_to_text(s, "08:55")
	r = _state(s.query_resource_states(), &"cmp_c2")
	assert_eq(r.state, ResourceState.State.IDLE, "3105 aún no ha salido")
	assert_eq(r.station_id, &"sta_zar")
	assert_eq(r.next_departure, D.t("09:05"))


func test_resource_states_reserve_vehicle_and_counts() -> void:
	var s: SimulationSession = SimFixture.session()
	var states: Array[ResourceState] = s.query_resource_states()
	var v6: ResourceState = _state(states, &"veh_v6")
	assert_ne(v6, null)
	assert_eq(v6.resource_type, Enums.ResourceType.VEHICLE)
	assert_eq(v6.state, ResourceState.State.RESERVE)
	assert_eq(v6.station_id, &"sta_zar")
	assert_eq(v6.next_service_id, &"")
	var in_comp: int = 0
	for c: Composition in s.world.compositions.values():
		in_comp += c.members.size()
	var expected: int = s.world.compositions.size() + (s.world.vehicles.size() - in_comp) + s.world.staff.size()
	assert_eq(states.size(), expected, "composiciones + vehículos sueltos + personal")
	for r: ResourceState in states:
		assert_true(r.label != "", "etiqueta de " + str(r.resource_id))
	D.run_to(s, s.clock.day_end)
	assert_eq(_state(s.query_resource_states(), &"veh_v6").state, ResourceState.State.RESERVE)


func test_resource_states_staff_in_service() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:30")
	var d02: ResourceState = _state(s.query_resource_states(), &"stf_d02")
	assert_eq(d02.state, ResourceState.State.IN_SERVICE)
	assert_eq(d02.current_service_id, D.S3103)
	assert_eq(d02.label, "Andrés Prieto")
	assert_eq(_state(s.query_resource_states(), &"stf_c02").resource_type, Enums.ResourceType.CONDUCTOR)


# --- resumen y listado ---

func test_service_summary_3103() -> void:
	var s: SimulationSession = SimFixture.session()
	var sum: ServiceSummary = s.query_service_summary(D.S3103)
	assert_eq(sum.code, "3103")
	assert_eq(sum.route_text, "%s → %s" % [s.world.stations[&"sta_mad"].name, s.world.stations[&"sta_zar"].name])
	assert_eq(sum.status, Enums.ServiceStatus.SCHEDULED)
	assert_eq(sum.delay, 0)
	assert_eq(sum.next_stop_index, 0)
	assert_eq(sum.next_stop_eta, D.t("07:00"))
	assert_eq(sum.booked, s.world.passengers[D.S3103].booked)
	assert_eq(sum.seats, s.world.composition_seats(&"cmp_c2"))
	assert_true(sum.seats > 0)
	D.run_to_text(s, "07:10")
	sum = s.query_service_summary(D.S3103)
	assert_eq(sum.status, Enums.ServiceStatus.RUNNING)
	assert_eq(sum.next_stop_index, 1)
	assert_eq(sum.next_stop_station_id, &"sta_gua")
	assert_eq(sum.next_stop_eta, D.t("07:20"))


func test_service_summary_with_delay_and_end() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	var sum: ServiceSummary = s.query_service_summary(D.S3103)
	assert_eq(sum.delay, 1500)
	assert_eq(sum.next_stop_index, 2)
	assert_eq(sum.next_stop_station_id, &"sta_cat")
	assert_eq(sum.next_stop_eta, D.t("08:27"), "ETA estimada, no programada")
	D.run_to(s, s.clock.day_end)
	sum = s.query_service_summary(D.S3103)
	assert_eq(sum.status, Enums.ServiceStatus.TERMINATED)
	assert_eq(sum.next_stop_index, -1)
	assert_eq(sum.delay, 1500)
	assert_eq(s.query_service_summary(&"svc_9999"), null)


func test_service_summary_matches_delay_of() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	for sid: StringName in s.service_ids():
		assert_eq(s.query_service_summary(sid).delay, s.delay_of(sid), str(sid))
		assert_eq(s.delay_info(sid).seconds, s.delay_of(sid), str(sid))


func test_service_ids_sorted_by_code() -> void:
	var s: SimulationSession = SimFixture.session()
	var ids: Array[StringName] = s.service_ids()
	assert_eq(ids.size(), s.world.services.size())
	var prev: String = ""
	for id: StringName in ids:
		var code: String = (s.world.services[id] as Service).code
		assert_true(code >= prev, "orden por código: %s tras %s" % [code, prev])
		prev = code
	assert_eq(ids[0], &"svc_3101")
	assert_eq(ids[ids.size() - 1], &"svc_3152")
