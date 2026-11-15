extends TestCase
## Percepción: informar a tiempo frente a no informar; cancelar penaliza más que esperar poco.

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const D = preload("res://tests/framework/delay_fixture.gd")


func test_informing_early_beats_not_informing() -> void:
	var uninformed: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, false)
	var informed: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, true)
	assert_true(E.ind(informed, "perception") > E.ind(uninformed, "perception"),
			"informar sube la percepción: %s vs %s" % [E.ind(informed, "perception"), E.ind(uninformed, "perception")])


func test_informing_marks_passengers_informed() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.WAIT_REPAIR)
	assert_false(bool(s.query_service_passengers(D.S3103).get("informed")))
	assert_true(s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id)))
	assert_true(bool(s.query_service_passengers(D.S3103).get("informed")))
	assert_eq(s.command_log[s.command_log.size() - 1].kind, &"INFORM_PASSENGERS")


func test_inform_invalid_rejected() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	assert_false(s.apply_command(InformPassengersCommand.new(&"svc_nope", F.incident(s).id)))
	assert_false(s.apply_command(InformPassengersCommand.new(D.S3103, &"inc_999")))


func test_informing_twice_does_not_double_bonus() -> void:
	var once: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, true)
	var twice: SimulationSession = SimFixture.session_with_incident(12345, F.REPAIR_LONG)
	D.run_to_text(twice, "08:12")
	F.decide(twice, OptionType.WAIT_REPAIR)
	twice.apply_command(InformPassengersCommand.new(D.S3103, F.incident(twice).id))
	twice.apply_command(InformPassengersCommand.new(D.S3103, F.incident(twice).id))
	D.run_to(twice, twice.clock.day_end)
	assert_eq(E.ind(twice, "perception"), E.ind(once, "perception"), "informar dos veces no acumula bonificación")


func test_early_information_beats_late_information() -> void:
	var early: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, true)
	var late: SimulationSession = SimFixture.session_with_incident(12345, F.REPAIR_LONG)
	D.run_to_text(late, "08:12")
	F.decide(late, OptionType.WAIT_REPAIR)
	D.run_to_text(late, "10:30")  # muy posterior a cualquier ventana «pronto»
	late.apply_command(InformPassengersCommand.new(D.S3103, F.incident(late).id))
	D.run_to(late, late.clock.day_end)
	assert_true(E.ind(early, "perception") >= E.ind(late, "perception"),
			"informar tarde no mejora a informar pronto")


func test_cancellation_hurts_perception_more_than_short_wait() -> void:
	var wait: SimulationSession = E.incident_day(F.REPAIR_SHORT, OptionType.WAIT_REPAIR)
	var cancel: SimulationSession = E.incident_day(F.REPAIR_SHORT, OptionType.CANCEL_SERVICE)
	assert_true(E.ind(wait, "perception") > E.ind(cancel, "perception"))


## ECONOMY §5: un servicio cancelado puntúa 0 en calidad, luego cancelar no puede MEJORAR la calidad del día
## frente a esperar una reparación corta (BUG conocido si falla: los cancelados salen del denominador).
func test_cancellation_does_not_improve_quality_vs_short_wait() -> void:
	var wait: SimulationSession = E.incident_day(F.REPAIR_SHORT, OptionType.WAIT_REPAIR)
	var cancel: SimulationSession = E.incident_day(F.REPAIR_SHORT, OptionType.CANCEL_SERVICE)
	assert_true(E.ind(cancel, "quality") <= E.ind(wait, "quality"),
			"calidad cancelar %s > esperar %s" % [E.ind(cancel, "quality"), E.ind(wait, "quality")])


func test_incident_lowers_quality_and_perception_vs_quiet_day() -> void:
	var quiet: SimulationSession = E.quiet_day()
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR)
	assert_true(E.ind(s, "quality") < E.ind(quiet, "quality"))
	assert_true(E.ind(s, "perception") < E.ind(quiet, "perception"))
	for k: String in ["quality", "perception"]:
		assert_true(E.ind(s, k) >= 0.0 and E.ind(s, k) <= 100.0, "%s en rango" % k)
