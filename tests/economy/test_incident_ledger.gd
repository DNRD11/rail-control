extends TestCase
## Volcado de Decision.cost_lines al libro (ref INCIDENT), importes negativos y una sola vez; viajeros por servicio.

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const D = preload("res://tests/framework/delay_fixture.gd")


func _check_dump(option: StringName) -> void:
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, option)
	var inc: Incident = F.incident(s)
	var rows: Array = E.entries_ref(s, "INCIDENT", inc.id)
	var lines: Array[Dictionary] = inc.decision.cost_lines
	assert_true(lines.size() > 0, "la opción %s deja líneas de coste" % option)
	assert_eq(rows.size(), lines.size(), "%s: una entrada por línea, ni más ni menos" % option)
	assert_eq(E.sum_amount(rows), inc.decision.total_cost_cents(), "%s: total volcado == Decision.total_cost_cents" % option)
	for e: Variant in rows:
		assert_true(int(e.get("amount_cents")) < 0, "importe negativo")
	# misma multiplicidad por categoría
	for cat: StringName in [&"INCIDENT_COST", &"SUBSTITUTION_COST"]:
		var expected: int = 0
		for l: Dictionary in lines:
			if StringName(l["category"]) == cat:
				expected += int(l["amount_cents"])
		assert_eq(E.sum_amount(E.entries_of(s, cat)) - _other_ref_sum(s, cat, inc.id), expected, "%s categoría %s" % [option, cat])


## Suma de entradas de la categoría cuyo ref no es la incidencia (no debería haber otras en estas categorías).
func _other_ref_sum(s: SimulationSession, cat: StringName, inc_id: StringName) -> int:
	var t: int = 0
	for e: Variant in E.entries_of(s, cat):
		if str(e.get("ref_id")) != String(inc_id):
			t += int(e.get("amount_cents"))
	return t


func test_wait_cost_lines_dumped() -> void:
	_check_dump(OptionType.WAIT_REPAIR)


func test_substitute_cost_lines_dumped() -> void:
	_check_dump(OptionType.SUBSTITUTE_ROLLING_STOCK)


func test_cancel_cost_lines_dumped() -> void:
	_check_dump(OptionType.CANCEL_SERVICE)


func test_cost_lines_dumped_exactly_once_over_time() -> void:
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, false, 12345, 100000)
	var inc: Incident = F.incident(s)
	var n: int = E.entries_ref(s, "INCIDENT", inc.id).size()
	# avanzar más no duplica; y el mismo resultado avanzando en pasos pequeños
	var s2: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR, false, false, 12345, 37)
	assert_eq(E.entries_ref(s2, "INCIDENT", F.incident(s2).id).size(), n)
	assert_eq(n, F.incident(s).decision.cost_lines.size())


func test_no_incident_entries_before_decision() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	assert_eq(E.entries_ref(s, "INCIDENT", F.incident(s).id).size(), 0, "nada hasta decidir")
	F.decide(s, OptionType.WAIT_REPAIR)
	assert_true(E.entries_ref(s, "INCIDENT", F.incident(s).id).size() > 0)
	var before: int = s.query_ledger().entries.size()
	assert_false(F.decide(s, OptionType.CANCEL_SERVICE), "no se decide dos veces")
	assert_eq(s.query_ledger().entries.size(), before, "una decisión rechazada no toca el libro")


func test_timeout_decision_also_dumped() -> void:
	var s: SimulationSession = SimFixture.session_with_incident(12345, F.REPAIR_LONG)
	D.run_to_text(s, "09:00")
	var inc: Incident = F.incident(s)
	assert_true(inc.decision.automatic)
	assert_eq(E.sum_amount(E.entries_ref(s, "INCIDENT", inc.id)), inc.decision.total_cost_cents())


func test_incident_costs_reduce_result_vs_quiet_day() -> void:
	var quiet: SimulationSession = E.quiet_day()
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_true(s.query_ledger().total_cents() < quiet.query_ledger().total_cents())


# --- Viajeros por servicio -------------------------------------------------------------------

func test_passengers_after_wait_continue() -> void:
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR)
	var p: Variant = s.query_service_passengers(D.S3103)
	assert_true(int(p.get("affected")) > 0)
	assert_eq(int(p.get("continuing")), int(p.get("affected")), "esperar: continúan todos")
	assert_eq(int(p.get("needing_alternative")), 0)
	assert_true(int(p.get("compensation_eligible")) > 0, "90 min de retraso en 3103 da derecho")


func test_passengers_after_cancel_need_alternative() -> void:
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.CANCEL_SERVICE)
	var p: Variant = s.query_service_passengers(D.S3103)
	assert_eq(int(p.get("needing_alternative")), 290)
	assert_eq(int(p.get("continuing")), 0)
	assert_eq(int(p.get("compensation_eligible")), 290, "cancelación indemniza a todos")


func test_unaffected_service_has_no_affected_passengers() -> void:
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.WAIT_REPAIR)
	var p: Variant = s.query_service_passengers(&"svc_3101")
	assert_eq(int(p.get("affected")), 0)
	assert_eq(int(p.get("compensation_eligible")), 0)
