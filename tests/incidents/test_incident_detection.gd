extends TestCase
## Detección de la avería guionizada: servicio detenido, material averiado, opciones y registro.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")


func test_no_incident_before_scheduled_time() -> void:
	var s: SimulationSession = SimFixture.session_with_incident()
	D.run_to_text(s, "08:11")
	assert_eq(s.all_incidents().size(), 0)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.RUNNING)


func test_detected_at_scheduled_time_holds_service() -> void:
	var s: SimulationSession = F.detected()
	var inc: Incident = F.incident(s)
	assert_ne(inc, null)
	assert_eq(inc.detected_at, D.t("08:12"))
	assert_eq(inc.status, Enums.IncidentStatus.AWAITING_DECISION)
	assert_eq(inc.service_id, D.S3103)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.HELD)
	assert_eq(inc.section_id, &"sec_cat_zar")
	assert_true(inc.fraction > 0.2 and inc.fraction < 0.6, "fracción %f" % inc.fraction)
	assert_eq(inc.composition_id, &"cmp_c2")
	assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.FAILED)
	assert_eq(s.world.services[D.S3103].incident_ids, [inc.id])
	assert_eq(s.open_incidents().size(), 1)


func test_three_options_offered_with_previews() -> void:
	var s: SimulationSession = F.detected()
	var inc: Incident = F.incident(s)
	assert_eq(inc.options.size(), 3)
	for o: DecisionOption in inc.options:
		assert_true(o.available, "%s disponible" % o.option_type)
	var wait: DecisionOption = inc.option(OptionType.WAIT_REPAIR)
	assert_eq(wait.preview.own_delay_min_s, F.REPAIR_LONG, "rango fijo")
	assert_true(wait.preview.cost_cents > 0)
	var sub: DecisionOption = inc.option(OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_eq(sub.preview.reserve_vehicle_id, &"veh_v6")
	assert_true(sub.preview.resume_at > D.t("08:12"))
	var cancel: DecisionOption = inc.option(OptionType.CANCEL_SERVICE)
	assert_eq(cancel.preview.cancelled_service_ids, [D.S3103])
	assert_eq(cancel.preview.needing_alternative, 290)


func test_repair_time_hidden_range_shown() -> void:
	var s: SimulationSession = SimFixture.session_with_incident()
	D.run_to_text(s, "08:12")
	var inc: Incident = F.incident(s)
	assert_eq(inc.repair_min_s, 1200)
	assert_eq(inc.repair_max_s, 5400)
	assert_true(inc.repair_s >= 1200 and inc.repair_s <= 5400)
	for e: LogEntry in s.log.filter(&"INCIDENT_DETECTED"):
		assert_false(e.data.has("repair_s"), "el tiempo real no se registra")
		assert_eq(e.data["repair_range_s"], [1200, 5400])


func test_position_frozen_while_held() -> void:
	var s: SimulationSession = F.detected()
	var before: ServicePosition = s.query_service_position(D.S3103)
	D.run_to_text(s, "08:20")
	var after: ServicePosition = s.query_service_position(D.S3103)
	assert_eq(after.state, ServicePosition.State.IN_SECTION)
	assert_eq(after.fraction, before.fraction)
	assert_eq(after.km, before.km)
	var later: ServicePosition = s.query_service_position_at(D.S3103, float(D.t("08:20")) + 0.7)
	assert_eq(later.fraction, before.fraction)


func test_no_movement_events_while_held() -> void:
	var s: SimulationSession = F.detected()
	D.run_to_text(s, "08:40")
	assert_eq(s.world.services[D.S3103].stops[3].status, Enums.StopStatus.PENDING)
	assert_eq(s.log.filter(SimEventType.SERVICE_ARRIVAL, D.S3103).size(), 2, "solo GUA y CAT")


func test_delay_visible_and_propagation_predicted_at_detection() -> void:
	var s: SimulationSession = F.detected()
	var info: DelayInfo = s.delay_info(D.S3103)
	assert_eq(info.cause, DelayInfo.CAUSE_BREAKDOWN)
	assert_true(info.seconds >= 900)


func test_vehicle_cannot_trigger_twice_on_same_service() -> void:
	var s: SimulationSession = F.detected()
	s.queue.push(SimEventType.INCIDENT_TRIGGER, s.clock.now, D.S3103, -1, {"type": "ROLLING_STOCK_FAILURE"})
	s.process_due_events()
	assert_eq(s.all_incidents().size(), 1)
	assert_eq(s.log.filter(&"INCIDENT_SKIPPED").size(), 1)


func test_incident_skipped_if_service_not_running() -> void:
	var s: SimulationSession = SimFixture.session()
	s.queue.push(SimEventType.INCIDENT_TRIGGER, s.clock.now, D.S3105, -1, {"type": "ROLLING_STOCK_FAILURE"})
	s.process_due_events()
	assert_eq(s.all_incidents().size(), 0)
	assert_eq(s.log.filter(&"INCIDENT_SKIPPED").size(), 1)
