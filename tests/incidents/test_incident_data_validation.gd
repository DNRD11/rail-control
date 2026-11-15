extends TestCase
## Validación de datos de incidencias: guion del escenario y data/rules/incidents.json.


func _raw_with_script_change(key: String, value: Variant) -> Dictionary:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	var list: Array = (raw["scenario"] as Dictionary)["scripted_incidents"] as Array
	(list[0] as Dictionary)[key] = value
	return raw


func _validate(raw: Dictionary) -> ValidationReport:
	return ScenarioFixture.build_and_validate(raw)


func _rules(raw: Dictionary) -> Dictionary:
	return raw["incident_rules"] as Dictionary


func _first_type(raw: Dictionary) -> Dictionary:
	return (_rules(raw)["types"] as Array)[0] as Dictionary


func test_mvp_incident_data_is_valid() -> void:
	assert_no_errors(_validate(ScenarioFixture.raw_copy()))


func test_unknown_incident_type_reported() -> void:
	assert_has_code(_validate(_raw_with_script_change("type", "TELEPORT_FAILURE")), &"UNKNOWN_REF")


func test_unknown_service_reported() -> void:
	assert_has_code(_validate(_raw_with_script_change("service", "svc_9999")), &"UNKNOWN_REF")


func test_unknown_section_reported() -> void:
	assert_has_code(_validate(_raw_with_script_change("section", "sec_nope")), &"UNKNOWN_REF")


func test_time_outside_day_reported() -> void:
	assert_has_code(_validate(_raw_with_script_change("time", "23:59")), &"BAD_VALUE")


func test_missing_script_type_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	var list: Array = (raw["scenario"] as Dictionary)["scripted_incidents"] as Array
	(list[0] as Dictionary).erase("type")
	assert_true(_validate(raw).has_errors(), "falta type")


func test_missing_rules_file_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	raw.erase("incident_rules")
	assert_has_code(_validate(raw), &"MISSING_FILE")


func test_unknown_option_in_type_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_first_type(raw)["options"] = ["WAIT_REPAIR", "TELEPORT"]
	assert_has_code(_validate(raw), &"BAD_VALUE")


func test_invalid_repair_range_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_first_type(raw)["repair_time_range_s"] = [900, 100]
	assert_has_code(_validate(raw), &"BAD_VALUE")


func test_repair_range_wrong_shape_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_first_type(raw)["repair_time_range_s"] = "mucho"
	assert_has_code(_validate(raw), &"BAD_TYPE")


func test_unknown_default_option_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_rules(raw)["default_option"] = "NOPE"
	assert_has_code(_validate(raw), &"BAD_VALUE")


func test_bad_positioning_speed_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_rules(raw)["positioning_speed_kmh"] = 0
	assert_has_code(_validate(raw), &"BAD_VALUE")


func test_duplicate_type_id_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	var types: Array = _rules(raw)["types"] as Array
	types.append((types[0] as Dictionary).duplicate(true))
	assert_has_code(_validate(raw), &"DUPLICATE_ID")


func test_types_missing_reported() -> void:
	var raw: Dictionary = ScenarioFixture.raw_copy()
	_rules(raw).erase("types")
	assert_true(_validate(raw).has_errors())
