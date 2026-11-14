extends TestCase

var world: World


func before_each() -> void:
	world = ScenarioFixture.load_world()


func test_service_3101_has_two_drivers_and_two_conductors() -> void:
	var drivers: Array[StringName] = world.assignments.resource_ids_for(&"svc_3101", Enums.ResourceType.DRIVER)
	var conductors: Array[StringName] = world.assignments.resource_ids_for(&"svc_3101", Enums.ResourceType.CONDUCTOR)
	assert_eq(drivers, [&"stf_d01", &"stf_d04"] as Array[StringName])
	assert_eq(conductors.size(), 2)
	assert_true(conductors.has(&"stf_c01") and conductors.has(&"stf_c05"))


func test_double_composition_c3() -> void:
	var comp: Composition = world.compositions[&"cmp_c3"]
	assert_eq(comp.members.size(), 2)
	assert_eq(world.composition_seats(&"cmp_c3"), 808)
	assert_eq(comp.vehicle_ids().size(), 2)


func test_single_composition_seats() -> void:
	assert_eq(world.composition_seats(&"cmp_c1"), 404)
	assert_eq(world.composition_seats(&"cmp_inexistente"), 0)


func test_driver_relief_at_zaragoza() -> void:
	var svc: Service = world.services[&"svc_3101"]
	assert_eq(svc.stops[3].station_id, &"sta_zar")
	var at_zar: Array[ResourceAssignment] = world.assignments.at_stop(&"svc_3101", Enums.ResourceType.DRIVER, 3)
	assert_eq(at_zar.size(), 2, "en la estación de relevo hay 2 maquinistas")
	assert_eq(world.assignments.at_stop(&"svc_3101", Enums.ResourceType.DRIVER, 1).size(), 1)
	assert_eq(world.assignments.at_stop(&"svc_3101", Enums.ResourceType.DRIVER, 5).size(), 1)


func test_for_segment_driver_by_segment() -> void:
	var s2: Array[ResourceAssignment] = world.assignments.for_segment(&"svc_3101", Enums.ResourceType.DRIVER, 2)
	var s3: Array[ResourceAssignment] = world.assignments.for_segment(&"svc_3101", Enums.ResourceType.DRIVER, 3)
	assert_eq(s2.size(), 1)
	assert_eq(s3.size(), 1)
	assert_eq(s2[0].resource_id, &"stf_d01")
	assert_eq(s3[0].resource_id, &"stf_d04")


func test_every_commercial_segment_is_covered() -> void:
	for svc: Service in world.services.values():
		for k: int in svc.segment_count():
			assert_true(world.assignments.for_segment(svc.id, Enums.ResourceType.COMPOSITION, k).size() >= 1, "%s tramo %d sin composición" % [svc.id, k])
			assert_true(world.assignments.for_segment(svc.id, Enums.ResourceType.DRIVER, k).size() >= 1, "%s tramo %d sin maquinista" % [svc.id, k])


func test_for_resource_sorted_by_planned_start() -> void:
	var list: Array[ResourceAssignment] = world.assignments.for_resource(Enums.ResourceType.COMPOSITION, &"cmp_c2")
	assert_eq(list.size(), 4)
	for i: int in range(1, list.size()):
		assert_true(list[i - 1].planned_start <= list[i].planned_start)


func test_planned_times_derived_from_schedule() -> void:
	var a: ResourceAssignment = null
	for x: ResourceAssignment in world.assignments.for_service(&"svc_3101"):
		if x.id == &"asg_3101_d04_36":
			a = x
	assert_ne(a, null)
	var svc: Service = world.services[&"svc_3101"]
	assert_eq(a.planned_start, svc.stops[3].exit_time())
	assert_eq(a.planned_end, svc.stops[6].entry_time())
	assert_eq(a.from_station_id, &"sta_zar")
	assert_eq(a.to_station_id, &"sta_bcn")


func test_service_times() -> void:
	var svc: Service = world.services[&"svc_3101"]
	assert_eq(svc.scheduled_departure(), SimTime.parse("06:30"))
	assert_eq(svc.scheduled_arrival(), SimTime.parse("09:05"))
	assert_eq(svc.segment_count(), 6)
	assert_eq(svc.stop_index_of(&"sta_zar"), 3)
	assert_true(svc.stops[3].is_stopping())
	assert_false(svc.stops[1].is_stopping())
