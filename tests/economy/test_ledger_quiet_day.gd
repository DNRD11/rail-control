extends TestCase
## Día sin incidencias: el libro tiene ingresos y costes ordinarios, cuadra y los indicadores están en rango.

const E = preload("res://tests/framework/economy_fixture.gd")
const D = preload("res://tests/framework/delay_fixture.gd")


func test_quiet_day_has_revenue_and_ordinary_costs() -> void:
	var s: SimulationSession = E.quiet_day()
	var ledger: Variant = s.query_ledger()
	assert_true(ledger.total_by_category(&"REVENUE") > 0, "ingresos > 0")
	assert_true(ledger.total_by_category(&"OPERATING_COST") < 0, "coste de explotación negativo")
	assert_true(ledger.total_by_category(&"STAFF_COST") < 0, "coste de personal negativo")
	assert_true(ledger.total_by_category(&"INFRA_CHARGE_ORDINARY") < 0, "canon ordinario negativo")
	assert_eq(ledger.total_by_category(&"INCIDENT_COST"), 0)
	assert_eq(ledger.total_by_category(&"SUBSTITUTION_COST"), 0)
	assert_eq(ledger.total_by_category(&"COMPENSATION"), 0, "sin retrasos no hay indemnizaciones")


func test_quiet_day_ledger_balances_with_category_sum() -> void:
	var s: SimulationSession = E.quiet_day()
	var ledger: Variant = s.query_ledger()
	var by_cat: int = 0
	var seen: Dictionary = {}
	for e: Variant in ledger.entries:
		seen[E.cat_of(e)] = true
	for c: String in seen:
		by_cat += int(ledger.total_by_category(StringName(c)))
	assert_eq(by_cat, int(ledger.total_cents()), "suma por categoría == total")
	assert_eq(E.sum_amount(ledger.entries), int(ledger.total_cents()), "suma de entradas == total")
	for c: String in seen:
		assert_true(E.CATEGORIES.has(StringName(c)), "categoría desconocida en el MVP: %s" % c)


func test_quiet_day_entries_well_formed() -> void:
	var s: SimulationSession = E.quiet_day()
	var ledger: Variant = s.query_ledger()
	assert_true(ledger.entries.size() > 0)
	for e: Variant in ledger.entries:
		var t: int = int(e.get("time"))
		assert_true(t >= s.clock.day_start and t <= s.clock.day_end, "hora fuera de la jornada: %d" % t)
		var amount: int = int(e.get("amount_cents"))
		assert_true(amount != 0, "importe 0 en %s" % E.cat_of(e))
		if E.cat_of(e) == "REVENUE":
			assert_true(amount > 0)
		else:
			assert_true(amount < 0, "los costes son negativos: %s" % E.cat_of(e))


func test_quiet_day_indicators_in_range() -> void:
	var s: SimulationSession = E.quiet_day()
	var q: float = E.ind(s, "quality")
	var p: float = E.ind(s, "perception")
	assert_true(q >= 0.0 and q <= 100.0, "calidad %s" % q)
	assert_true(p >= 0.0 and p <= 100.0, "percepción %s" % p)
	assert_true(q >= 95.0, "día puntual -> calidad alta (%s)" % q)
	assert_true(p >= 70.0, "día puntual -> percepción >= base (%s)" % p)
	assert_eq(int(E.ind(s, "result_cents")), int(s.query_ledger().total_cents()), "resultado == suma del libro")
	assert_true(E.ind(s, "passengers_carried") > 0.0)
	assert_eq(int(E.ind(s, "affected")), 0)
	assert_eq(int(E.ind(s, "compensated")), 0)


func test_quiet_day_is_profitable() -> void:
	var s: SimulationSession = E.quiet_day()
	assert_true(s.query_ledger().total_cents() > 0, "el día ordinario debe dar beneficio (revisar equilibrio)")


func test_ledger_grows_monotonically_in_time() -> void:
	var s: SimulationSession = SimFixture.session()
	var prev_count: int = 0
	for t: String in ["07:00", "09:00", "12:00", "15:00"]:
		D.run_to_text(s, t)
		var n: int = s.query_ledger().entries.size()
		assert_true(n >= prev_count, "el libro no pierde entradas")
		prev_count = n
