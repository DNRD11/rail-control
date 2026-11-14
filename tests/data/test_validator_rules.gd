extends TestCase
## Cada prueba muta una copia profunda del `raw` del MVP y comprueba el código de validación esperado.

var raw: Dictionary


func before_each() -> void:
	raw = ScenarioFixture.raw_copy()


func _validate() -> ValidationReport:
	return ScenarioFixture.build_and_validate(raw)


func _asg(id: String) -> Dictionary:
	return ScenarioFixture.find_item(raw, "assignments", "assignments", id)


func _add_asg(d: Dictionary) -> void:
	((raw["assignments"] as Dictionary)["assignments"] as Array).append(d)


func test_baseline_is_clean() -> void:
	var r: ValidationReport = _validate()
	assert_eq(r.error_count() + r.warning_count(), 0, r.summary())


func test_overlap() -> void:
	# cmp_c2 asignada a la vez a svc_3103 (existente) y a una copia con otro id.
	_add_asg({"id": "asg_dup", "service": "svc_3103", "type": "COMPOSITION", "resource": "cmp_c2", "from_stop": 0, "to_stop": 3})
	assert_has_code(_validate(), &"OVERLAP")


func test_overlap_driver() -> void:
	_add_asg({"id": "asg_dup", "service": "svc_3103", "type": "DRIVER", "resource": "stf_d02", "from_stop": 0, "to_stop": 3})
	assert_has_code(_validate(), &"OVERLAP")


func test_discontinuity() -> void:
	# stf_d01 conduce 3101 (MAD→ZAR) y luego 3108 (MAD→ZAR): si 3108 saliese de otro punto habría salto.
	# Aquí se añade a cmp_c1 el servicio 3103 (sale de MAD) tras acabar 3101 en BCN.
	_add_asg({"id": "asg_dc", "service": "svc_3103", "type": "COMPOSITION", "resource": "cmp_c1", "from_stop": 0, "to_stop": 3})
	assert_has_code(_validate(), &"DISCONTINUITY")


func test_initial_location() -> void:
	ScenarioFixture.find_item(raw, "vehicles", "vehicles", "veh_v1")["location"] = "sta_bcn"
	assert_has_code(_validate(), &"INITIAL_LOCATION")


func test_initial_location_staff() -> void:
	ScenarioFixture.find_item(raw, "staff", "staff", "stf_d01")["base"] = "sta_bcn"
	assert_has_code(_validate(), &"INITIAL_LOCATION")


func test_no_composition() -> void:
	ScenarioFixture.remove_item(raw, "assignments", "assignments", "asg_3101_c1_06")
	assert_has_code(_validate(), &"NO_COMPOSITION")


func test_no_driver() -> void:
	ScenarioFixture.remove_item(raw, "assignments", "assignments", "asg_3103_d02_03")
	assert_has_code(_validate(), &"NO_DRIVER")


func test_few_conductors_is_warning() -> void:
	# Quita el único interventor de 3102 (stf_c01 sigue empezando en MAD con 3101): solo aviso.
	ScenarioFixture.remove_item(raw, "assignments", "assignments", "asg_3102_c01_06")
	var r: ValidationReport = _validate()
	assert_has_code(r, &"FEW_CONDUCTORS")
	assert_eq(r.error_count(), 0, "falta de interventores es solo aviso\n" + r.summary())


func test_vehicle_unavailable() -> void:
	ScenarioFixture.find_item(raw, "vehicles", "vehicles", "veh_v1")["status"] = "MAINTENANCE"
	assert_has_code(_validate(), &"VEHICLE_UNAVAILABLE")


func test_turnaround_tight_is_warning() -> void:
	var lines: Array = raw["lines"] as Array
	for line: Variant in lines:
		for st: Variant in (line as Dictionary)["stations"] as Array:
			(st as Dictionary)["min_turnaround_s"] = 99999
	var r: ValidationReport = _validate()
	assert_has_code(r, &"TURNAROUND_TIGHT")
	assert_eq(r.error_count(), 0, r.summary())


func test_out_of_shift_is_warning() -> void:
	ScenarioFixture.find_item(raw, "staff", "staff", "stf_d01")["shift_end"] = "08:00"
	var r: ValidationReport = _validate()
	assert_has_code(r, &"OUT_OF_SHIFT")
	assert_eq(r.error_count(), 0, r.summary())


func test_role_mismatch() -> void:
	_asg("asg_3101_d01_03")["resource"] = "stf_c05"
	assert_has_code(_validate(), &"ROLE_MISMATCH")


func test_unknown_ref_resource() -> void:
	_asg("asg_3101_d01_03")["resource"] = "stf_fantasma"
	assert_has_code(_validate(), &"UNKNOWN_REF")


func test_unknown_ref_service() -> void:
	_asg("asg_3101_d01_03")["service"] = "svc_9999"
	assert_has_code(_validate(), &"UNKNOWN_REF")


func test_unknown_ref_vehicle_station() -> void:
	ScenarioFixture.find_item(raw, "vehicles", "vehicles", "veh_v1")["location"] = "sta_nada"
	assert_has_code(_validate(), &"UNKNOWN_REF")


func test_bad_range_out_of_itinerary() -> void:
	_asg("asg_3101_d01_03")["to_stop"] = 99
	assert_has_code(_validate(), &"BAD_RANGE")


func test_bad_range_inverted() -> void:
	var a: Dictionary = _asg("asg_3101_d01_03")
	a["from_stop"] = 3
	a["to_stop"] = 3
	assert_has_code(_validate(), &"BAD_RANGE")


func test_pax_mismatch() -> void:
	(raw["passengers"] as Dictionary)["passengers"][0]["booked"] = 291
	assert_has_code(_validate(), &"PAX_MISMATCH")


func test_time_order() -> void:
	# La hora de Guadalajara (parada 1) anterior a la salida de origen.
	var svc: Dictionary = ScenarioFixture.find_item(raw, "services", "services", "svc_3101")
	(svc["stops"] as Array)[1]["time"] = "05:00"
	assert_has_code(_validate(), &"TIME_ORDER")


func test_time_order_departure_before_arrival() -> void:
	var svc: Dictionary = ScenarioFixture.find_item(raw, "services", "services", "svc_3101")
	(svc["stops"] as Array)[3]["dep"] = "07:40"
	assert_has_code(_validate(), &"TIME_ORDER")


func test_no_section() -> void:
	var svc: Dictionary = ScenarioFixture.find_item(raw, "services", "services", "svc_3101")
	var stops: Array = svc["stops"] as Array
	stops.remove_at(2)
	stops.remove_at(1)
	assert_has_code(_validate(), &"NO_SECTION")


func test_bad_composition_too_many_vehicles() -> void:
	var cmp: Dictionary = ScenarioFixture.find_item(raw, "compositions", "compositions", "cmp_c3")
	(cmp["members"] as Array).append({"vehicle": "veh_v5", "position": 3})
	(cmp["members"] as Array).append({"vehicle": "veh_v6", "position": 4})
	assert_has_code(_validate(), &"BAD_COMPOSITION")


func test_station_mismatch() -> void:
	_asg("asg_3101_d01_03")["from_station"] = "sta_bcn"
	var r: ValidationReport = _validate()
	assert_true(r.has_code(&"STATION_MISMATCH") or r.has_errors(), "estación redundante incoherente debe detectarse\n" + r.summary())


func test_missing_field() -> void:
	(ScenarioFixture.find_item(raw, "vehicles", "vehicles", "veh_v1")).erase("class")
	assert_has_code(_validate(), &"MISSING_FIELD")


func test_missing_field_in_service() -> void:
	(ScenarioFixture.find_item(raw, "services", "services", "svc_3101")).erase("origin")
	assert_has_code(_validate(), &"MISSING_FIELD")


func test_bad_schema_version() -> void:
	(raw["vehicles"] as Dictionary)["schema_version"] = 2
	assert_has_code(_validate(), &"BAD_SCHEMA_VERSION")


func test_bad_schema_version_missing() -> void:
	(raw["services"] as Dictionary).erase("schema_version")
	assert_has_code(_validate(), &"BAD_SCHEMA_VERSION")


func test_missing_file() -> void:
	raw["staff"] = {}
	assert_has_code(_validate(), &"MISSING_FILE")


func test_bad_type() -> void:
	ScenarioFixture.find_item(raw, "vehicles", "vehicles", "veh_v1")["number"] = "cuatro mil"
	var r: ValidationReport = _validate()
	assert_true(r.has_code(&"BAD_TYPE") or r.has_code(&"BAD_VALUE"), r.summary())


func test_original_raw_not_polluted_by_mutations() -> void:
	ScenarioFixture.remove_item(raw, "assignments", "assignments", "asg_3101_c1_06")
	var fresh: Dictionary = ScenarioFixture.raw_copy()
	assert_eq(ScenarioFixture.find_item(fresh, "assignments", "assignments", "asg_3101_c1_06").is_empty(), false)
