extends TestCase
## Aceptación transversal del MVP: relaciones múltiples de material y personal, solapamientos, reloj a distintas
## velocidades, pausa real, propagación/absorción de retrasos y determinismo de extremo a extremo.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const E = preload("res://tests/framework/economy_fixture.gd")

const RUNNING_STATES: Array[Enums.ServiceStatus] = [Enums.ServiceStatus.RUNNING,
		Enums.ServiceStatus.STOPPED_AT_STATION, Enums.ServiceStatus.HELD, Enums.ServiceStatus.BOARDING]


## Bucle de «frames» como el de SimulationHost: acumula tiempo real y avanza la sesión en segundos enteros.
## `speeds` se aplica cíclicamente por frame con SetSpeedCommand (solo si cambia).
func _host_frames(s: SimulationSession, frames: int, frame_dt: float, speeds: Array[int],
		acc: StepAccumulator = StepAccumulator.new()) -> void:
	for i: int in frames:
		var sp: int = speeds[i % speeds.size()]
		if s.clock.speed != sp:
			s.apply_command(SetSpeedCommand.make(sp))
		var n: int = acc.feed(frame_dt, s.clock.time_scale, s.clock.speed)
		if n > 0:
			s.advance_seconds(n)


func _fingerprint(s: SimulationSession) -> String:
	return "%d|%s|%s|%s|%s" % [s.clock.now, s.log.digest(), D.state_dump(s), E.ledger_digest(s), E.indicators_text(s)]


# --- Relaciones múltiples ---------------------------------------------------------------------

func test_one_service_many_resources_one_resource_many_services() -> void:
	var s: SimulationSession = SimFixture.session()
	var w: World = s.world
	# 1 servicio -> varios maquinistas e interventores por tramos
	assert_eq(w.assignments.resource_ids_for(&"svc_3101", Enums.ResourceType.DRIVER).size(), 2)
	assert_eq(w.assignments.resource_ids_for(&"svc_3101", Enums.ResourceType.CONDUCTOR).size(), 2)
	# 1 maquinista/interventor/composición -> varios servicios en orden temporal
	var c2: Array[ResourceAssignment] = w.assignments.for_resource(Enums.ResourceType.COMPOSITION, &"cmp_c2")
	var services: Array[StringName] = []
	for a: ResourceAssignment in c2:
		services.append(a.service_id)
	assert_eq(services, [&"svc_3103", &"svc_3105", &"svc_3106", &"svc_3108"] as Array[StringName], "rotación de C2")
	assert_true(w.assignments.for_resource(Enums.ResourceType.CONDUCTOR, &"stf_c02").size() >= 2, "un interventor en varios servicios")
	# composición -> varios vehículos
	var c3: Composition = w.compositions[&"cmp_c3"]
	assert_eq(c3.vehicle_ids().size(), 2)
	assert_eq(w.composition_seats(&"cmp_c3"), 808)
	# ningún Service guarda un recurso en un campo propio (regla 4): solo asignaciones
	for p: Dictionary in (Service.new() as Object).get_property_list():
		var pname: String = p["name"]
		assert_false(pname in ["vehicle_id", "driver_id", "conductor_id", "composition_id"], "campo único %s en Service" % pname)


func test_relief_by_segments_visible_in_resource_slots() -> void:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "07:00")
	var drivers: Array[ResourceSlot] = []
	for sl: ResourceSlot in s.query_service_resources(&"svc_3101"):
		if sl.resource_type == Enums.ResourceType.DRIVER:
			drivers.append(sl)
	assert_eq(drivers.size(), 2)
	var cur: Array[StringName] = []
	for sl: ResourceSlot in drivers:
		if sl.is_current:
			cur.append(sl.resource_id)
	assert_eq(cur, [&"stf_d01"] as Array[StringName], "antes del relevo conduce d01")
	D.run_to_text(s, "08:30")
	cur.clear()
	for sl: ResourceSlot in s.query_service_resources(&"svc_3101"):
		if sl.resource_type == Enums.ResourceType.DRIVER and sl.is_current:
			cur.append(sl.resource_id)
	assert_eq(cur, [&"stf_d04"] as Array[StringName], "tras el relevo en ZAR conduce d04")


func test_baseline_data_has_no_overlaps_or_discontinuities() -> void:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(ScenarioFixture.MVP)
	assert_true(res.ok)
	assert_lacks_code(res.report, &"OVERLAP")
	assert_lacks_code(res.report, &"DISCONTINUITY")
	assert_eq(res.report.error_count() + res.report.warning_count(), 0, res.report.summary())


func test_overlap_and_discontinuity_are_detected() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	var arr: Array = (raw["assignments"] as Dictionary)["assignments"] as Array
	arr.append({"id": "asg_x1", "service": "svc_3103", "type": "COMPOSITION", "resource": "cmp_c2", "from_stop": 0, "to_stop": 3})
	arr.append({"id": "asg_x2", "service": "svc_3103", "type": "COMPOSITION", "resource": "cmp_c1", "from_stop": 0, "to_stop": 3})
	var report: ValidationReport = ScenarioFixture.build_and_validate(raw)
	assert_has_code(report, &"OVERLAP")
	assert_has_code(report, &"DISCONTINUITY")


func test_no_resource_in_two_running_services_during_any_day() -> void:
	for option: StringName in [&"", OptionType.SUBSTITUTE_ROLLING_STOCK, OptionType.CANCEL_SERVICE]:
		var s: SimulationSession = SimFixture.session_with_incident(12345, 3000)
		D.run_to_text(s, "08:12")
		if option != &"":
			F.decide(s, option)
		while not s.clock.is_day_over():
			s.advance_seconds(120)
			var used: Dictionary = {}
			for sid: StringName in s.service_ids():
				var sv: Service = s.world.services[sid]
				if not RUNNING_STATES.has(sv.status):
					continue
				var pos: ServicePosition = s.query_service_position(sid)
				for sl: ResourceSlot in s.query_service_resources(sid):
					if not sl.is_current:
						continue
					# en una estación de relevo el recurso entrante espera al saliente: no es un solape
					if pos.state == ServicePosition.State.AT_STATION and (sl.from_stop_index == pos.stop_index
							or sl.to_stop_index == pos.stop_index) and sl.from_stop_index != sl.to_stop_index 							and s.world.assignments.at_stop(sid, sl.resource_type, pos.stop_index).size() > 1:
						continue
					var key: String = "%d|%s" % [sl.resource_type, sl.resource_id]
					var holder: StringName = used.get(key, &"")
					assert_true(holder == &"" or holder == sid, "%s usado a la vez por %s y %s (t=%d, opción %s)" % [key, holder, sid, s.clock.now, option])
					used[key] = sid


# --- Reloj ---------------------------------------------------------------------------------------

func test_x1_x2_x4_reach_identical_state() -> void:
	# time_scale = 30: 120 s reales a x1 == 60 s a x2 == 30 s a x4 == 3600 s de simulación
	var a: SimulationSession = SimFixture.session()
	var b: SimulationSession = SimFixture.session()
	var c: SimulationSession = SimFixture.session()
	_host_frames(a, 480, 0.25, [1] as Array[int])
	_host_frames(b, 240, 0.25, [2] as Array[int])
	_host_frames(c, 120, 0.25, [4] as Array[int])
	assert_eq(a.clock.now, a.clock.day_start + 3600)
	assert_eq(b.clock.now, a.clock.now)
	assert_eq(c.clock.now, a.clock.now)
	assert_eq(_fingerprint(b), _fingerprint(a))
	assert_eq(_fingerprint(c), _fingerprint(a))


func test_full_day_with_incident_equal_at_any_speed_and_frame_rate() -> void:
	var prints: Array[String] = []
	for plan: Array in [[1, 0.25, 4000], [4, 0.1, 1200], [2, 0.05, 4000]]:
		var s: SimulationSession = SimFixture.session_with_incident(12345, 3000)
		var speeds: Array[int] = [int(plan[0])]
		# 08:12 es el punto de decisión: se alcanza con avance directo para decidir en el mismo instante
		D.run_to_text(s, "08:12")
		F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK)
		_host_frames(s, int(plan[2]) * 20, float(plan[1]), speeds)
		D.run_to(s, s.clock.day_end)
		prints.append(_fingerprint(s))
	assert_eq(prints[1], prints[0], "x4 con frames de 0,1 s")
	assert_eq(prints[2], prints[0], "x2 con frames de 0,05 s")


func test_real_pause_freezes_state_and_resumes_identically() -> void:
	var paused: SimulationSession = SimFixture.session()
	var plain: SimulationSession = SimFixture.session()
	var acc_p: StepAccumulator = StepAccumulator.new()
	var acc_n: StepAccumulator = StepAccumulator.new()
	_host_frames(paused, 100, 0.25, [1] as Array[int], acc_p)
	var frozen: String = _fingerprint(paused)
	var queue_before: int = paused.queue.snapshot().size()
	_host_frames(paused, 5000, 0.25, [0] as Array[int], acc_p)
	assert_eq(_fingerprint(paused), frozen, "con pausa el estado no cambia")
	assert_eq(paused.queue.snapshot().size(), queue_before)
	assert_true(paused.clock.is_paused())
	# 100 frames con pausas intercaladas (50 activos) frente a 150 frames activos seguidos sin pausas
	_host_frames(paused, 100, 0.25, [1, 0, 0, 1] as Array[int], acc_p)
	_host_frames(plain, 150, 0.25, [1] as Array[int], acc_n)
	assert_eq(paused.clock.now, plain.clock.now, "la pausa no consume ni regala tiempo")
	assert_eq(_fingerprint(paused), _fingerprint(plain))


func test_decision_during_pause_changes_state_but_not_time() -> void:
	var s: SimulationSession = SimFixture.session_with_incident(12345, 3000)
	D.run_to_text(s, "08:12")
	s.apply_command(SetSpeedCommand.make(0))
	var now: int = s.clock.now
	var log_count: int = s.log.count()
	_host_frames(s, 500, 0.25, [0] as Array[int])
	assert_eq(s.clock.now, now)
	assert_eq(F.incident(s).status, Enums.IncidentStatus.AWAITING_DECISION, "el plazo de decisión no corre en pausa")
	assert_true(F.decide(s, OptionType.CANCEL_SERVICE))
	assert_eq(s.clock.now, now, "decidir en pausa no avanza el reloj")
	assert_true(s.log.count() > log_count, "pero sí queda registrado")
	assert_true(s.world.services[D.S3103].is_cancelled())


# --- Propagación y absorción ------------------------------------------------------------------

func test_delay_absorbed_by_margin_then_propagated_by_material() -> void:
	# margen de rotación 3103 -> 3105 en ZAR: 08:55 - (08:25 + 900) = 900 s
	var small: SimulationSession = D.injected(D.S3103, 600, "07:00")
	assert_eq(small.delay_of(D.S3105), 0, "600 s absorbidos por el margen")
	assert_eq(small.delay_info(D.S3105).cause, DelayInfo.CAUSE_NONE)
	var edge: SimulationSession = D.injected(D.S3103, 900, "07:00")
	assert_eq(edge.delay_of(D.S3105), 0, "900 s justo absorbidos")
	var big: SimulationSession = D.injected(D.S3103, 1200, "07:00")
	assert_eq(big.delay_of(D.S3105), 300, "1200 s - 900 s de margen")
	assert_eq(big.delay_info(D.S3105).cause, DelayInfo.CAUSE_ROTATION_MATERIAL)
	# 3106 tiene 1200 s de holgura por el mismo material: 300 s se absorben
	assert_eq(big.delay_of(D.S3106), 0)
	var huge: SimulationSession = D.injected(D.S3103, 3000, "07:00")
	assert_eq(huge.delay_of(D.S3105), 2100)
	assert_true(huge.delay_of(D.S3106) > 0, "el retraso grande llega al 3106 por el mismo material")
	assert_eq(huge.delay_info(D.S3106).cause, DelayInfo.CAUSE_ROTATION_MATERIAL)


func test_delay_propagates_by_staff() -> void:
	# stf_d02 conduce 3103 y después 3152 en ZAR (conexión mínima 600 s; margen 900 s). 3152 ya está en marcha:
	# el retraso solo es visible al llegar a Zaragoza (08:48).
	var ok: SimulationSession = D.injected(D.S3103, 900, "07:00")
	D.run_to_text(ok, "08:49")
	assert_eq(ok.delay_of(D.S3152), 0, "dentro del margen de relevo")
	var s: SimulationSession = D.injected(D.S3103, 3000, "07:00")
	D.run_to_text(s, "08:49")
	var info: DelayInfo = s.delay_info(D.S3152)
	assert_eq(info.seconds, D.t("08:25") + 3000 + 600 - D.t("08:50"), "espera al maquinista de relevo")
	assert_eq(info.cause, DelayInfo.CAUSE_ROTATION_STAFF)
	assert_eq(info.source_service_id, D.S3103)
	assert_eq(info.resource_id, &"stf_d02")


# --- Determinismo -------------------------------------------------------------------------------

func _run_random_day(seed_value: int) -> String:
	# avería aleatoria (reparación del rango de datos) y decisión por tiempo agotado
	var world: World = ScenarioFixture.load_world()
	var s: SimulationSession = SimulationSession.create(world, seed_value)
	D.run_to(s, s.clock.day_end, 777)
	return "%s|%d" % [_fingerprint(s), F.incident(s).repair_s]


func test_same_seed_same_commands_same_hash() -> void:
	assert_eq(_run_random_day(777), _run_random_day(777))
	assert_eq(_run_random_day(20260514), _run_random_day(20260514))


func test_different_seeds_change_the_random_repair() -> void:
	var repairs: Dictionary = {}
	for sd: int in [1, 2, 3, 4, 5, 6]:
		var parts: PackedStringArray = _run_random_day(sd).split("|")
		repairs[parts[parts.size() - 1]] = true
	assert_true(repairs.size() >= 2, "la semilla gobierna la duración de la avería: %s" % str(repairs.keys()))


func test_same_commands_same_hash_with_decision_and_inform() -> void:
	var h: Array[String] = []
	for step: int in [60, 1000]:
		var s: SimulationSession = SimFixture.session_with_incident(12345, 3000)
		D.run_to_text(s, "08:12", step)
		F.decide(s, OptionType.WAIT_REPAIR)
		D.run_to_text(s, "08:20", step)
		s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id))
		D.run_to(s, s.clock.day_end, step)
		h.append(_fingerprint(s))
	assert_eq(h[0], h[1])
