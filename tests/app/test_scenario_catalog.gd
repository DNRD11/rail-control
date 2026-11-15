extends TestCase
## ScenarioCatalog detecta el escenario MVP y sus datos de cabecera sin construir el mundo.


func test_catalog_lists_mvp_scenario() -> void:
	var list: Array[ScenarioInfo] = ScenarioCatalog.list()
	assert_true(list.size() >= 1)
	var found: ScenarioInfo = null
	for info: ScenarioInfo in list:
		if info.id == StringName(ScenarioFixture.MVP):
			found = info
	assert_ne(found, null, "el catálogo contiene %s" % ScenarioFixture.MVP)
	if found == null:
		return
	assert_ne(found.name, "")
	assert_ne(found.description, "")
	assert_eq(found.day_start, SimTime.parse("06:00"))
	assert_eq(found.day_end, SimTime.parse("15:00"))
	assert_eq(found.seed, 20260514)
	assert_true(ScenarioCatalog.folders().has(ScenarioFixture.MVP))


func test_catalog_agrees_with_full_loader() -> void:
	var res: ScenarioLoadResult = ScenarioLoader.load_scenario(ScenarioFixture.MVP)
	assert_true(res.ok)
	var info: ScenarioInfo = null
	for i: ScenarioInfo in ScenarioCatalog.list():
		if i.id == StringName(ScenarioFixture.MVP):
			info = i
	assert_ne(info, null)
	if info == null:
		return
	assert_eq(info.id, res.world.scenario.id)
	assert_eq(info.name, res.world.scenario.name)
	assert_eq(info.day_start, res.world.scenario.day_start)
	assert_eq(info.day_end, res.world.scenario.day_end)
	assert_eq(info.seed, res.world.scenario.seed)
	var meta: Dictionary = ScenarioCatalog.meta(ScenarioFixture.MVP)
	assert_eq(meta["service_count"], 10)
	assert_eq(meta["incident_count"], res.world.scenario.scripted_incidents.size())
	assert_eq(meta["incident_count"], 1)


func test_every_listed_scenario_loads_without_errors() -> void:
	for info: ScenarioInfo in ScenarioCatalog.list():
		var res: ScenarioLoadResult = ScenarioLoader.load_scenario(String(info.id))
		assert_true(res.ok, "%s carga sin errores: %s" % [info.id, res.report.summary()])


func test_catalog_on_empty_or_missing_data_dir() -> void:
	assert_eq(ScenarioCatalog.list("res://tests/fixtures_no_existe").size(), 0)
	assert_eq(ScenarioCatalog.folders("res://tests/fixtures_no_existe").size(), 0)
	var meta: Dictionary = ScenarioCatalog.meta("no_existe")
	assert_eq(meta["service_count"], 0)
	assert_eq(meta["incident_count"], 0)
