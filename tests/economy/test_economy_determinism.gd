extends TestCase
## Determinismo de la economía: misma semilla y mismos comandos -> mismo hash de libro e indicadores.

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")


func test_quiet_day_same_seed_same_ledger() -> void:
	var a: SimulationSession = E.quiet_day(777)
	var b: SimulationSession = E.quiet_day(777)
	assert_eq(E.ledger_digest(a), E.ledger_digest(b))
	assert_eq(E.indicators_text(a), E.indicators_text(b))


func test_ledger_independent_of_step_size() -> void:
	var a: SimulationSession = E.quiet_day(12345, 100000)
	var b: SimulationSession = E.quiet_day(12345, 37)
	assert_eq(E.ledger_digest(a), E.ledger_digest(b), "pasos grandes vs pequeños")
	assert_eq(E.indicators_text(a), E.indicators_text(b))


func test_incident_day_same_commands_same_ledger() -> void:
	for opt: StringName in OptionType.ALL:
		var a: SimulationSession = E.incident_day(F.REPAIR_LONG, opt, false, true)
		var b: SimulationSession = E.incident_day(F.REPAIR_LONG, opt, false, true)
		assert_eq(E.ledger_digest(a), E.ledger_digest(b), "libro %s" % opt)
		assert_eq(E.indicators_text(a), E.indicators_text(b), "indicadores %s" % opt)
		assert_eq(a.log.digest(), b.log.digest())


func test_incident_ledger_independent_of_step_size() -> void:
	var a: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.SUBSTITUTE_ROLLING_STOCK, false, true, 12345, 100000)
	var b: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.SUBSTITUTE_ROLLING_STOCK, false, true, 12345, 61)
	assert_eq(E.ledger_digest(a), E.ledger_digest(b))
	assert_eq(E.indicators_text(a), E.indicators_text(b))


func test_different_commands_give_different_ledger() -> void:
	var w: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR)
	var c: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.CANCEL_SERVICE)
	assert_ne(E.ledger_digest(w), E.ledger_digest(c))
	var informed: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, true)
	assert_ne(E.indicators_text(w), E.indicators_text(informed), "informar cambia los indicadores")


func test_decision_while_paused_posts_costs_immediately() -> void:
	# La pausa la gestiona el host (no avanza el reloj); un comando en pausa se contabiliza al instante.
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	s.apply_command(SetSpeedCommand.make(0))
	var now: int = s.clock.now
	F.decide(s, OptionType.WAIT_REPAIR)
	assert_eq(s.clock.now, now)
	var rows: Array = E.entries_ref(s, "INCIDENT", F.incident(s).id)
	assert_true(rows.size() > 0, "costes de la decisión en el libro sin avanzar el reloj")
	for e: Variant in rows:
		assert_eq(int(e.get("time")), now)
