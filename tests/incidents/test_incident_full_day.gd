extends TestCase
## Jornada completa con cada opción: sin errores, sin eventos huérfanos, todo cerrado y registrado.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")

const OPTIONS: Array[StringName] = [OptionType.WAIT_REPAIR, OptionType.SUBSTITUTE_ROLLING_STOCK,
		OptionType.CANCEL_SERVICE]


func _full_day(option: StringName) -> SimulationSession:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	assert_true(F.decide(s, option), "decisión %s aceptada" % option)
	D.run_to(s, s.clock.day_end, 600)
	return s


func test_day_finishes_with_each_option() -> void:
	for option: StringName in OPTIONS:
		var s: SimulationSession = _full_day(option)
		assert_true(s.clock.is_day_over(), "jornada terminada con %s" % option)
		for sid: StringName in s.service_ids():
			var st: int = s.world.services[sid].status
			assert_true(st == Enums.ServiceStatus.TERMINATED or st == Enums.ServiceStatus.CANCELLED
					or st == Enums.ServiceStatus.PARTIALLY_CANCELLED,
					"%s con %s termina o se cancela (estado %d)" % [sid, option, st])


func test_incident_resolved_and_logged_once_with_each_option() -> void:
	for option: StringName in OPTIONS:
		var s: SimulationSession = _full_day(option)
		assert_eq(s.open_incidents().size(), 0, "sin incidencias abiertas con %s" % option)
		assert_eq(F.incident(s).status, Enums.IncidentStatus.RESOLVED)
		assert_eq(s.log.filter(IncidentSystem.LOG_DETECTED).size(), 1)
		assert_eq(s.log.filter(IncidentSystem.LOG_DECISION).size(), 1)
		assert_eq(s.log.filter(IncidentSystem.LOG_RESOLVED).size(), 1)


func test_no_orphan_pending_incident_events() -> void:
	for option: StringName in OPTIONS:
		var s: SimulationSession = _full_day(option)
		for e: Dictionary in s.queue.snapshot():
			var t: String = String(e.get("type", ""))
			assert_false(t == String(SimEventType.INCIDENT_RESOLVED) or t == String(SimEventType.DECISION_TIMEOUT)
					or t == String(SimEventType.INCIDENT_TRIGGER),
					"evento de incidencia huérfano con %s: %s" % [option, e])


func test_no_pending_events_for_cancelled_services() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.CANCEL_SERVICE)
	var cancelled: Array[StringName] = F.incident(s).decision.cancelled_service_ids.duplicate()
	assert_false(cancelled.is_empty())
	for e: Dictionary in s.queue.snapshot():
		assert_false(cancelled.has(StringName(String(e.get("service_id", "")))), "cola limpia: %s" % e)


func test_finished_services_have_no_pending_stops() -> void:
	for option: StringName in OPTIONS:
		var s: SimulationSession = _full_day(option)
		for sid: StringName in s.service_ids():
			var sv: Service = s.world.services[sid]
			if sv.status == Enums.ServiceStatus.TERMINATED:
				for st: ServiceStop in sv.stops:
					assert_ne(st.status, Enums.StopStatus.PENDING, "%s parada %d sin completar (%s)" % [sid, st.index, option])


func test_decision_cost_recorded_per_option() -> void:
	for option: StringName in OPTIONS:
		var s: SimulationSession = _full_day(option)
		var d: Decision = F.incident(s).decision
		assert_eq(d.option_type, option)
		assert_true(d.total_cost_cents() != 0, "la decisión %s tiene coste registrado" % option)
