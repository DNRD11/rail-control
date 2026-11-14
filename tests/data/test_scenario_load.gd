extends TestCase


func test_mvp_loads_without_errors_or_warnings() -> void:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(ScenarioFixture.MVP)
	assert_eq(res.report.error_count(), 0, res.report.summary())
	assert_eq(res.report.warning_count(), 0, res.report.summary())
	assert_true(res.ok)


func test_mvp_entity_counts() -> void:
	var w: World = ScenarioFixture.load_world()
	assert_eq(w.stations.size(), 7, "estaciones")
	assert_eq(w.services.size(), 10, "servicios")
	assert_eq(w.vehicles.size(), 6, "vehículos")
	assert_eq(w.compositions.size(), 4, "composiciones")
	assert_eq(w.staff.size(), 11, "personal")
	assert_eq(w.passengers.size(), 10, "cargas de viajeros")


func test_raw_has_no_io_errors() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	assert_eq((raw["_errors"] as Array).size(), 0)


func test_scenario_info() -> void:
	var w: World = ScenarioFixture.load_world()
	assert_eq(w.scenario.id, &"mvp_mad_bcn_morning")
	assert_true(w.scenario.day_start < w.scenario.day_end)
	assert_true(w.scenario.staff_connection_s > 0)


func test_missing_scenario_reports_io_error() -> void:
	# load_raw no hace push_error: solo acumula en "_errors".
	var raw: Dictionary = ScenarioLoader.load_raw("no_existe")
	assert_true((raw["_errors"] as Array).size() > 0)
	var report: ValidationReport = ValidationReport.new()
	WorldBuilder.build(raw, report)
	assert_true(report.has_errors())


func test_service_has_no_single_resource_fields() -> void:
	# Regla 4: Service no tiene campos únicos de recurso.
	var props: Array[String] = []
	for p: Dictionary in (Service.new() as Object).get_property_list():
		props.append(String(p["name"]))
	for forbidden: String in ["vehicle_id", "driver_id", "conductor_id", "composition_id"]:
		assert_false(props.has(forbidden), "Service no debe tener %s" % forbidden)
