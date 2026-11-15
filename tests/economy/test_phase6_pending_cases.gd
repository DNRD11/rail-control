extends TestCase
## Casos pendientes de la Fase 6 (propuestos por economy-design): tramos SEVERE/MAJOR de calidad, liquidación al
## cierre de jornada, información doble, ventana de información de 600 s, baja ocupación del 3103 e importes de
## indemnización = precio x % / reservas (ECONOMY §3-§6).

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const D = preload("res://tests/framework/delay_fixture.gd")


# --- utilidades ---------------------------------------------------------------------------------

func _quality_of(s: SimulationSession, sid: StringName) -> float:
	var o: PassengerOutcome = PassengerCalc.outcome(s.world, s.world.services[sid])
	return float(o.quality_points) / float(o.quality_pax)


## Día completo con `seconds` de retraso inyectado en el 3109 a las `at_text` (sin avería).
func _delayed_3109(seconds: int, at_text: String = "10:00", mutate: Callable = Callable()) -> SimulationSession:
	var s: SimulationSession = SimFixture.session()
	if mutate.is_valid():
		mutate.call(s.world.passengers[E.S3109])
	D.run_to_text(s, at_text)
	if seconds > 0:
		s.apply_command(InjectDelayCommand.make(E.S3109, seconds))
	D.run_to(s, s.clock.day_end)
	return s


func _set_load(load: ServicePassengerLoad, booked: int, boardings: Dictionary, alightings: Dictionary) -> void:
	load.booked = booked
	load.boardings_by_stop.clear()
	for k: Variant in boardings:
		load.boardings_by_stop[int(k)] = int(boardings[k])
	load.alightings_by_stop.clear()
	for k: Variant in alightings:
		load.alightings_by_stop[int(k)] = int(alightings[k])


func _entry_sum(s: SimulationSession, category: StringName, sid: StringName) -> int:
	var t: int = 0
	for e: Variant in E.entries_of(s, category):
		if str(e.get("ref_id")) == String(sid):
			t += int(e.get("amount_cents"))
	return t


func _total_pax_weight(s: SimulationSession) -> int:
	var t: int = 0
	for sid: StringName in s.service_ids():
		t += PassengerCalc.outcome(s.world, s.world.services[sid]).quality_pax
	return t


# --- 1. tramos de calidad SEVERE 30 / MAJOR 65 ------------------------------------------------------

func test_quality_score_per_delay_tier() -> void:
	# retraso en destino -> puntuación (perception.json: ON_TIME 100, MINOR 85, MAJOR 65, SEVERE 30)
	var cases: Array = [[120, 100.0, "ON_TIME"], [181, 85.0, "MINOR"], [900, 85.0, "MINOR"], [901, 65.0, "MAJOR"],
			[1200, 65.0, "MAJOR"], [3600, 65.0, "MAJOR"], [3601, 30.0, "SEVERE"], [4000, 30.0, "SEVERE"]]
	for c: Array in cases:
		var s: SimulationSession = _delayed_3109(int(c[0]))
		var sv: Service = s.world.services[E.S3109]
		var last: ServiceStop = sv.stops[sv.stops.size() - 1]
		assert_eq(last.act_arr - last.sched_arr, int(c[0]), "retraso en destino aplicado")
		assert_eq(_quality_of(s, E.S3109), float(c[1]), "calidad del 3109 con %d s (%s)" % [int(c[0]), c[2]])
		assert_eq(String(DelayInfo.level_for(int(c[0]))), String(c[2]))


func test_global_quality_weights_severe_and_major_by_passengers() -> void:
	var weight: float = 0.0
	var quiet: SimulationSession = E.quiet_day()
	assert_eq(E.ind(quiet, "quality"), 100.0)
	for c: Array in [[1200, 65.0], [4000, 30.0]]:
		var s: SimulationSession = _delayed_3109(int(c[0]))
		weight = float(PassengerCalc.outcome(s.world, s.world.services[E.S3109]).quality_pax) / float(_total_pax_weight(s))
		assert_near(E.ind(s, "quality"), snappedf(100.0 - (100.0 - float(c[1])) * weight, 0.1), 0.11,
				"calidad global con 3109 a %.0f puntos" % float(c[1]))
		assert_true(E.ind(s, "quality") < 100.0)


# --- 2. liquidación al cierre con un servicio que llega después de day_end -------------------------------

func test_settlement_at_day_end_for_service_arriving_after_it() -> void:
	# 3109 llega a las 13:20; con 7 200 s de retraso lo haría a las 15:20 (> day_end 15:00)
	var s: SimulationSession = _delayed_3109(7200)
	var sv: Service = s.world.services[E.S3109]
	assert_true(s.clock.is_day_over())
	assert_ne(sv.status, Enums.ServiceStatus.TERMINATED, "3109 no ha llegado al cerrar la jornada")
	assert_true(sv.stops[sv.stops.size() - 1].est_arr > s.clock.day_end)
	var rows: Array = E.entries_ref(s, "SERVICE", E.S3109)
	assert_true(rows.size() >= 4, "se liquida igualmente: %d apuntes" % rows.size())
	var per_cat: Dictionary = {}
	for e: Variant in rows:
		assert_eq(int(e.get("time")), s.clock.day_end, "liquidado a la hora de cierre")
		per_cat[E.cat_of(e)] = int(per_cat.get(E.cat_of(e), 0)) + 1
	for cat: String in ["REVENUE", "OPERATING_COST", "STAFF_COST", "INFRA_CHARGE_ORDINARY", "COMPENSATION"]:
		assert_eq(int(per_cat.get(cat, 0)), 1, "un único apunte de %s" % cat)
	var fare: int = _entry_sum(s, &"REVENUE", E.S3109)
	assert_true(fare > 0, "se cobra el billete de los viajeros previstos")
	assert_eq(-_entry_sum(s, &"COMPENSATION", E.S3109), fare, "retraso proyectado >= 90 min: indemnización del 100 %")
	# nada vuelve a liquidarse después
	var digest: String = E.ledger_digest(s)
	s.advance_seconds(5000)
	assert_eq(E.ledger_digest(s), digest, "no hay doble liquidación")
	assert_eq(E.ind(s, "result_cents"), float(s.query_ledger().total_cents()))


# --- 3. informar dos veces al mismo servicio ----------------------------------------------------------

func test_inform_twice_is_rejected_and_logged_once() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.WAIT_REPAIR)
	var inc_id: StringName = F.incident(s).id
	var before: int = s.command_log.size()
	assert_true(s.apply_command(InformPassengersCommand.new(D.S3103, inc_id)))
	assert_eq(s.command_log.size(), before + 1)
	D.run_to(s, s.clock.now + 60)
	assert_false(s.apply_command(InformPassengersCommand.new(D.S3103, inc_id)), "la segunda información se rechaza")
	assert_eq(s.command_log.size(), before + 1, "el comando rechazado no se registra")
	assert_eq(s.passenger.messages.size(), 1)
	assert_eq(s.log.filter(PassengerSystem.LOG_INFO, D.S3103).size(), 1)
	assert_eq(s.world.passengers[D.S3103].last_info_time, D.t("08:12"), "conserva la hora del primer mensaje")
	var reason: String = s.passenger.validate_inform(s, D.S3103, inc_id)
	assert_true(reason.contains("informados"), "motivo claro: %s" % reason)


# --- 4. ventana de información de 600 s -------------------------------------------------------------

func _inform_at(offset_s: int, never: bool = false) -> SimulationSession:
	var s: SimulationSession = F.detected(F.REPAIR_SHORT)
	F.decide(s, OptionType.WAIT_REPAIR)
	var since: int = s.world.passengers[D.S3103].affected_since
	assert_ne(since, SimTime.NONE, "los viajeros del 3103 quedan afectados")
	if not never:
		D.run_to(s, since + offset_s)
		assert_true(s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id)))
	D.run_to(s, s.clock.day_end)
	return s


func test_information_window_600s_inside_and_outside() -> void:
	var rules: PerceptionRules = SimFixture.session().world.perception_rules
	assert_eq(rules.info_window_s, 600)
	var now_run: Dictionary = {}
	for k: String in ["0", "600", "601", "never"]:
		var s: SimulationSession = _inform_at(0 if k == "never" else int(k), k == "never")
		var load: ServicePassengerLoad = s.world.passengers[D.S3103]
		var state: StringName = PassengerSystem.info_state(load, 290, s.clock.now, rules)
		now_run[k] = {"state": state, "perception": E.ind(s, "perception")}
	assert_eq(now_run["0"]["state"], PassengerSystem.INFO_EARLY)
	assert_eq(now_run["600"]["state"], PassengerSystem.INFO_EARLY, "600 s exactos siguen dentro de la ventana")
	assert_eq(now_run["601"]["state"], PassengerSystem.INFO_LATE)
	assert_eq(now_run["never"]["state"], PassengerSystem.INFO_MISSING)
	assert_eq(now_run["0"]["perception"], now_run["600"]["perception"], "mismo trato dentro de la ventana")
	var early: float = now_run["600"]["perception"]
	var late: float = now_run["601"]["perception"]
	var none: float = now_run["never"]["perception"]
	assert_true(early > late and late > none, "pronto %.1f > tarde %.1f > sin informar %.1f" % [early, late, none])
	# 290 afectados: bonificación +15/1000 (dentro) frente a -25 x 50 %/1000 (fuera) y -25/1000 (sin informar)
	assert_near(early - late, (15.0 + 25.0 * rules.late_info_factor) * 290.0 / 1000.0, 0.15, "bonificación frente a penalización parcial")
	assert_near(late - none, 25.0 * (1.0 - rules.late_info_factor) * 290.0 / 1000.0, 0.15, "fuera de ventana: 50 % de la penalización")


# --- 5. baja ocupación del 3103: cancelar no queda dominado --------------------------------------------

func _low_occupancy_day(repair_s: int, option: StringName, pax: int) -> SimulationSession:
	var s: SimulationSession = SimFixture.session_with_incident(12345, repair_s)
	if pax > 0:
		_set_load(s.world.passengers[D.S3103], pax, {0: pax, 1: 0, 2: 0}, {1: 0, 2: 0, 3: pax})
	D.run_to_text(s, "08:12")
	assert_true(F.decide(s, option))
	assert_true(s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id)))
	D.run_to(s, s.clock.day_end, 600)
	return s


func _matrix(repair_s: int, pax: int) -> Dictionary:
	var m: Dictionary = {}
	for opt: StringName in OptionType.ALL:
		var s: SimulationSession = _low_occupancy_day(repair_s, opt, pax)
		m[opt] = {"result": E.ind(s, "result_cents") / 100.0, "perception": E.ind(s, "perception")}
	return m


func test_low_occupancy_cancel_is_not_dominated() -> void:
	var m: Dictionary = _matrix(5400, 40)
	print("  baja ocupación 40 pax, 90 min: ", m)
	var w: Dictionary = m[OptionType.WAIT_REPAIR]
	var sb: Dictionary = m[OptionType.SUBSTITUTE_ROLLING_STOCK]
	var c: Dictionary = m[OptionType.CANCEL_SERVICE]
	assert_true(c["perception"] > sb["perception"] and c["perception"] > w["perception"], "cancelar: mejor percepción")
	assert_true(c["result"] > w["result"], "cancelar mejor que esperar 90 min en resultado")
	assert_true(sb["result"] > c["result"], "sustituir aún gana en resultado: no hay una opción dominante")
	assert_true(absf(sb["result"] - c["result"]) < 3000.0, "diferencia de resultado pequeña (ECONOMY §6: ~1 200 EUR)")
	# valores de la tabla ECONOMY §6
	assert_near(w["result"], 26515.0, 500.0, "esperar 90 min")
	assert_near(sb["result"], 38404.0, 500.0, "sustituir")
	assert_near(c["result"], 37222.0, 500.0, "cancelar")
	assert_near(c["perception"], 72.0, 1.0)
	assert_near(sb["perception"], 58.9, 1.0)


func test_low_occupancy_short_repair_wait_still_wins_in_result() -> void:
	var m: Dictionary = _matrix(1200, 40)
	var w: Dictionary = m[OptionType.WAIT_REPAIR]
	assert_true(w["result"] > m[OptionType.SUBSTITUTE_ROLLING_STOCK]["result"])
	assert_true(w["result"] > m[OptionType.CANCEL_SERVICE]["result"])
	assert_near(w["result"], 46834.0, 500.0, "ECONOMY §6: baja ocupación, 20 min")


func test_normal_occupancy_cancel_stays_dominated_by_substitute() -> void:
	var m: Dictionary = _matrix(5400, 0)
	var sb: Dictionary = m[OptionType.SUBSTITUTE_ROLLING_STOCK]
	var c: Dictionary = m[OptionType.CANCEL_SERVICE]
	assert_true(sb["result"] > c["result"] and sb["perception"] > c["perception"],
			"con ocupación normal sustituir domina a cancelar (hallazgo abierto de diseño)")


# --- 6. importes de COMPENSATION = precio x % / reservas -------------------------------------------------

func _fare(s: SimulationSession) -> int:
	return EconomyCalc.fare_total_cents(s.world, s.world.services[E.S3109])


func test_compensation_amount_is_fare_times_percent_over_booked() -> void:
	for c: Array in [[1799, 0], [1800, 25], [3599, 25], [3600, 50], [5399, 50], [5400, 100], [5900, 100]]:
		var s: SimulationSession = _delayed_3109(int(c[0]))
		var expected: int = -roundi(float(_fare(s)) * float(c[1]) / 100.0)
		assert_eq(_entry_sum(s, &"COMPENSATION", E.S3109), expected, "retraso %d s -> %d %% del billete" % [int(c[0]), int(c[1])])


func test_compensation_divides_by_booked_not_by_carried() -> void:
	# 300 reservas pero solo 290 viajeros bajan en destino (10 no se presentan): importe = billete x 290 x % / 300
	var mutate: Callable = func(load: ServicePassengerLoad) -> void:
		_set_load(load, 300, {0: 203, 3: 87}, {3: 0, 6: 290})
	var s: SimulationSession = _delayed_3109(3600, "10:00", mutate)
	var expected: int = -roundi(float(_fare(s)) * 290.0 * 50.0 / (300.0 * 100.0))
	assert_eq(_entry_sum(s, &"COMPENSATION", E.S3109), expected)
	assert_eq(_entry_sum(s, &"REVENUE", E.S3109), roundi(float(_fare(s)) * 290.0 / 300.0), "ingreso = billete x llegados / reservas")


func test_compensation_weights_each_alighting_stop_by_its_own_percent() -> void:
	# 100 viajeros bajan en Zaragoza (sin retraso: el retraso se inyecta después de salir) y 190 en Barcelona
	# (3 600 s -> 50 %): importe = billete x (100 x 0 + 190 x 50) / (290 x 100)
	var mutate: Callable = func(load: ServicePassengerLoad) -> void:
		_set_load(load, 290, {0: 290}, {3: 100, 6: 190})
	var s: SimulationSession = _delayed_3109(3600, "12:10", mutate)
	var sv: Service = s.world.services[E.S3109]
	assert_eq(sv.stops[3].act_arr, sv.stops[3].sched_arr, "en Zaragoza llegó en hora")
	assert_eq(sv.stops[6].act_arr - sv.stops[6].sched_arr, 3600)
	var expected: int = -roundi(float(_fare(s)) * (100.0 * 0.0 + 190.0 * 50.0) / (290.0 * 100.0))
	assert_eq(_entry_sum(s, &"COMPENSATION", E.S3109), expected)
	var o: PassengerOutcome = PassengerCalc.outcome(s.world, sv)
	assert_eq(o.compensation_eligible, 190)


func test_cancellation_compensation_is_cancellation_percent_of_fare() -> void:
	var s: SimulationSession = _low_occupancy_day(5400, OptionType.CANCEL_SERVICE, 40)
	var sv: Service = s.world.services[D.S3103]
	var cancel_pct: int = s.world.compensation_rules.cancellation_percent
	var expected: int = -roundi(float(EconomyCalc.fare_total_cents(s.world, sv)) * 40.0 * float(cancel_pct) / (40.0 * 100.0))
	assert_eq(_entry_sum(s, &"COMPENSATION", D.S3103), expected)
	assert_eq(s.query_service_passengers(D.S3103).needing_alternative, 40)
