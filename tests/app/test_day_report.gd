extends TestCase
## DayReport coherente con los indicadores, el libro y las incidencias de la sesión.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const E = preload("res://tests/framework/economy_fixture.gd")


func _day(option: StringName) -> SimulationSession:
	return E.incident_day(5400, option, false, true)


func test_report_matches_indicators_and_ledger() -> void:
	for option: StringName in OptionType.ALL:
		var s: SimulationSession = _day(option)
		var r: DayReport = DayReport.from_session(s)
		var ind: Indicators = s.query_indicators()
		var ledger: Ledger = s.query_ledger()
		assert_eq(r.scenario_id, ScenarioFixture.MVP)
		assert_eq(r.day_start, s.clock.day_start)
		assert_eq(r.day_end, s.clock.day_end)
		assert_eq(r.finished_at, s.clock.now)
		assert_eq(r.quality, ind.quality)
		assert_eq(r.perception, ind.perception)
		assert_eq(r.result_cents, ind.result_cents)
		assert_eq(r.result_cents, ledger.total_cents())
		assert_eq(r.revenue_cents + r.cost_cents, r.result_cents, "ingresos + costes = resultado (%s)" % option)
		assert_true(r.revenue_cents > 0 and r.cost_cents < 0)
		assert_eq(r.passengers_carried, ind.passengers_carried)
		assert_eq(r.passengers_affected, ind.affected)
		assert_eq(r.passengers_compensated, ind.compensated)
		assert_eq(r.passengers_needing_alternative, ind.needing_alternative)
		var sum: int = 0
		for cat: StringName in r.ledger_by_category:
			sum += r.ledger_by_category[cat]
			assert_eq(r.ledger_by_category[cat], ledger.total_by_category(cat), "categoría %s" % cat)
		assert_eq(sum, r.result_cents, "suma de categorías = resultado")
		assert_true(r.quality >= 0.0 and r.quality <= 100.0 and r.perception >= 0.0 and r.perception <= 100.0)
		assert_true(r.score >= 0.0 and r.score <= 100.0)
		assert_true([&"A", &"B", &"C", &"D"].has(r.grade), "nota %s" % r.grade)


func test_report_services_and_incident_listed() -> void:
	var s: SimulationSession = _day(OptionType.SUBSTITUTE_ROLLING_STOCK)
	var r: DayReport = DayReport.from_session(s)
	assert_eq(r.services.size(), 10)
	var codes: Array[String] = []
	for row: Dictionary in r.services:
		codes.append(String(row["code"]))
		assert_eq(int(row["delay_s"]), s.delay_of(StringName(row["service_id"])))
		assert_eq(String(row["status"]), "TERMINATED")
	var sorted: Array[String] = codes.duplicate()
	sorted.sort()
	assert_eq(codes, sorted, "servicios ordenados por código")
	assert_eq(r.incidents.size(), 1)
	var inc: Dictionary = r.incidents[0]
	assert_eq(inc["service_id"], D.S3103)
	assert_eq(inc["type_id"], &"ROLLING_STOCK_FAILURE")
	assert_eq(inc["decision"], OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_false(inc["automatic"])
	assert_eq(inc["status"], "RESOLVED")
	assert_eq(inc["detected_at"], D.t("08:12"))
	assert_eq(int(inc["cost_cents"]), F.incident(s).decision.total_cost_cents())
	# el coste de la decisión está en el libro
	var booked: int = s.query_ledger().total_by_category(&"INCIDENT_COST") + s.query_ledger().total_by_category(&"SUBSTITUTION_COST")
	assert_eq(booked, int(inc["cost_cents"]))


func test_cancelled_service_status_in_report() -> void:
	var s: SimulationSession = _day(OptionType.CANCEL_SERVICE)
	var r: DayReport = DayReport.from_session(s)
	var found: bool = false
	for row: Dictionary in r.services:
		if row["service_id"] == D.S3103:
			found = true
			assert_ne(String(row["status"]), "TERMINATED")
	assert_true(found)
	assert_eq(r.passengers_needing_alternative, 290)


func test_report_to_dict_roundtrips_through_json() -> void:
	var r: DayReport = DayReport.from_session(_day(OptionType.WAIT_REPAIR))
	var d: Dictionary = r.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d)) as Dictionary
	assert_eq(int(parsed["result_cents"]), r.result_cents)
	assert_eq(String(parsed["grade"]), String(r.grade))
	assert_eq(int(parsed["passengers"]["affected"]), r.passengers_affected)
	assert_eq((parsed["services"] as Array).size(), r.services.size())
	assert_eq((parsed["incidents"] as Array).size(), 1)
	var cats: Dictionary = parsed["ledger_by_category"] as Dictionary
	var sum: int = 0
	for k: String in cats:
		sum += int(cats[k])
	assert_eq(sum, r.result_cents)


func test_report_is_deterministic_and_read_only() -> void:
	var s: SimulationSession = _day(OptionType.WAIT_REPAIR)
	var before: String = StateHash.of(s)
	var a: Dictionary = DayReport.from_session(s).to_dict()
	var b: Dictionary = DayReport.from_session(s).to_dict()
	assert_eq(JSON.stringify(a), JSON.stringify(b))
	assert_eq(StateHash.of(s), before, "construir el informe no altera la sesión")
	var again: Dictionary = DayReport.from_session(_day(OptionType.WAIT_REPAIR)).to_dict()
	assert_eq(JSON.stringify(a), JSON.stringify(again), "misma semilla y comandos, mismo informe")


func test_quiet_day_report_has_no_incidents_and_top_quality() -> void:
	var r: DayReport = DayReport.from_session(E.quiet_day())
	assert_eq(r.incidents.size(), 0)
	assert_eq(r.quality, 100.0)
	assert_eq(r.passengers_affected, 0)
	assert_eq(r.passengers_compensated, 0)
	assert_true(r.result_cents > 0)


func test_grade_follows_score_thresholds_and_better_play_scores_higher() -> void:
	var rules: ReportRules = ReportRules.load_default()
	assert_eq(rules.errors.size(), 0, str(rules.errors))
	assert_eq(rules.grade_for(100.0), &"A")
	assert_eq(rules.grade_for(rules.grades[rules.grades.size() - 1]["min_score"]), rules.grades[rules.grades.size() - 1]["grade"])
	assert_eq(rules.grade_for(0.0), rules.grades[rules.grades.size() - 1]["grade"])
	for i: int in range(rules.grades.size() - 1):
		var m: float = float(rules.grades[i]["min_score"])
		assert_eq(rules.grade_for(m), rules.grades[i]["grade"])
		assert_ne(rules.grade_for(m - 0.01), rules.grades[i]["grade"])
	var good: DayReport = DayReport.from_session(_day(OptionType.SUBSTITUTE_ROLLING_STOCK))
	var bad: DayReport = DayReport.from_session(E.incident_day(5400, OptionType.WAIT_REPAIR, false, false))
	assert_true(good.score > bad.score, "sustituir e informar (%.1f) puntúa más que esperar 90 min sin informar (%.1f)" % [good.score, bad.score])
	assert_near(good.score, rules.score(good.quality, good.perception), 0.001)
