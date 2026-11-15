extends TestCase
## Indemnizaciones por umbrales 30/60/90 min y por cancelación (ECONOMY §3). Se prueba con retraso inyectado
## en svc_3109 (sin sucesores en la rotación: no propaga) y con la cancelación de svc_3103.

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")
const D = preload("res://tests/framework/delay_fixture.gd")


func _comp(seconds: int) -> int:
	var s: SimulationSession = E.delayed_3109_day(seconds)
	var sv: Service = s.world.services[E.S3109]
	var last: ServiceStop = sv.stops[sv.stops.size() - 1]
	assert_eq(last.act_arr - last.sched_arr, seconds, "retraso en destino realmente aplicado")
	return -int(s.query_ledger().total_by_category(&"COMPENSATION"))


func _revenue_of(s: SimulationSession, sid: StringName) -> int:
	var t: int = 0
	for e: Variant in E.entries_of(s, &"REVENUE"):
		if str(e.get("ref_id")) == String(sid):
			t += int(e.get("amount_cents"))
	return t


func test_below_30_min_no_compensation() -> void:
	assert_eq(_comp(0), 0)
	assert_eq(_comp(1200), 0, "20 min")
	assert_eq(_comp(1799), 0, "29:59")


func test_30_to_59_min_is_25_percent() -> void:
	var c30: int = _comp(1800)
	assert_true(c30 > 0, "30 min ya indemniza")
	assert_eq(_comp(3599), c30, "59:59 mismo tramo que 30 min")


func test_60_to_89_min_is_50_percent() -> void:
	var c30: int = _comp(1800)
	var c60: int = _comp(3600)
	assert_true(absi(c60 - 2 * c30) <= maxi(10, c30 / 50), "60 min = 2 x (25%%): %d vs %d" % [c60, c30])
	assert_eq(_comp(5399), c60, "89:59 mismo tramo que 60 min")


func test_90_min_or_more_is_100_percent() -> void:
	var c30: int = _comp(1800)
	var c90: int = _comp(5400)
	assert_true(absi(c90 - 4 * c30) <= maxi(10, c30 / 25), "90 min = 4 x (25%%): %d vs %d" % [c90, c30])
	assert_eq(_comp(5700), c90, "mayor retraso no aumenta el porcentaje")


func test_full_compensation_equals_fare_revenue() -> void:
	var base: SimulationSession = E.delayed_3109_day(0)
	var fare_total: int = _revenue_of(base, E.S3109)
	if fare_total <= 0:
		return  # ingresos no referenciados por servicio: se cubre solo la relación entre tramos
	var c90: int = _comp(5400)
	assert_true(absi(c90 - fare_total) <= maxi(100, fare_total / 50),
			"100%% del billete: indemnización %d vs ingreso del servicio %d" % [c90, fare_total])


func test_compensation_entries_reference_service() -> void:
	var s: SimulationSession = E.delayed_3109_day(3600)
	var rows: Array = E.entries_of(s, &"COMPENSATION")
	assert_true(rows.size() > 0)
	for e: Variant in rows:
		assert_true(int(e.get("amount_cents")) < 0)
		assert_ne(str(e.get("ref_id")), "", "la indemnización referencia su origen")
	assert_true(int(E.ind(s, "compensated")) > 0, "viajeros compensados > 0")
	assert_true(int(E.ind(s, "affected")) > 0)


func test_cancellation_compensates_full_fare() -> void:
	var base: SimulationSession = E.quiet_day()
	var fare_3103: int = _revenue_of(base, D.S3103)
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.CANCEL_SERVICE)
	var comp: int = -int(s.query_ledger().total_by_category(&"COMPENSATION"))
	assert_true(comp > 0, "cancelar indemniza")
	if fare_3103 > 0:
		assert_true(absi(comp - fare_3103) <= fare_3103 / 6,
				"cancelación ~100%% del billete de 3103: %d vs %d" % [comp, fare_3103])
	assert_true(int(E.ind(s, "affected")) >= 290)


func test_cancellation_loses_revenue() -> void:
	var base: SimulationSession = E.quiet_day()
	var s: SimulationSession = E.incident_day(F.REPAIR_LONG, OptionType.CANCEL_SERVICE)
	assert_true(s.query_ledger().total_by_category(&"REVENUE") < base.query_ledger().total_by_category(&"REVENUE"),
			"el servicio cancelado no ingresa")
