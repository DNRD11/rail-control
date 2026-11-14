extends TestCase

var world: World
var graph: RotationGraph


func before_each() -> void:
	world = ScenarioFixture.load_world()
	graph = RotationGraph.build(world)


func _edge(from_id: StringName, to_id: StringName, type: Enums.ResourceType) -> RotationEdge:
	for e: RotationEdge in graph.outgoing(from_id):
		if e.to_service_id == to_id and e.resource_type == type:
			return e
	return null


func test_composition_edge_3103_to_3105() -> void:
	var e: RotationEdge = _edge(&"svc_3103", &"svc_3105", Enums.ResourceType.COMPOSITION)
	assert_ne(e, null, "debe existir la arista 3103→3105 por composición")
	if e == null:
		return
	assert_eq(e.resource_id, &"cmp_c2")
	assert_eq(e.gap_s, 1800)
	assert_eq(e.min_connection_s, 900)
	assert_eq(e.margin_s, 900)


func test_edge_gap_matches_schedule() -> void:
	var e: RotationEdge = _edge(&"svc_3103", &"svc_3105", Enums.ResourceType.COMPOSITION)
	if e == null:
		assert_true(false, "falta la arista")
		return
	var a: Service = world.services[&"svc_3103"]
	var b: Service = world.services[&"svc_3105"]
	assert_eq(e.gap_s, b.scheduled_departure() - a.scheduled_arrival())
	assert_eq(e.station_id, a.destination_station_id)
	assert_eq(e.station_id, b.origin_station_id)


func test_chain_of_cmp_c2() -> void:
	var chain: Array[StringName] = graph.chain(Enums.ResourceType.COMPOSITION, &"cmp_c2")
	assert_eq(chain, [&"svc_3103", &"svc_3105", &"svc_3106", &"svc_3108"] as Array[StringName])


func test_downstream_of_3103() -> void:
	var ds: Array[StringName] = graph.downstream(&"svc_3103")
	assert_true(ds.has(&"svc_3105"))
	assert_true(ds.has(&"svc_3106"))
	assert_true(ds.has(&"svc_3108"))
	assert_false(ds.has(&"svc_3103"), "no incluye el propio servicio")
	var seen: Dictionary = {}
	for s: StringName in ds:
		assert_false(seen.has(s), "duplicado %s" % s)
		seen[s] = true


func test_downstream_of_last_in_chain_by_composition_only() -> void:
	var ds: Array[StringName] = graph.downstream(&"svc_3108")
	assert_false(ds.has(&"svc_3103"))


func test_downstream_unknown_service_is_empty() -> void:
	assert_eq(graph.downstream(&"svc_9999").size(), 0)


func test_no_vehicle_edges() -> void:
	for e: RotationEdge in graph.edges:
		assert_ne(e.resource_type, Enums.ResourceType.VEHICLE)


func test_staff_edges_use_staff_connection() -> void:
	var found: bool = false
	for e: RotationEdge in graph.edges:
		if e.resource_type == Enums.ResourceType.DRIVER or e.resource_type == Enums.ResourceType.CONDUCTOR:
			found = true
			assert_eq(e.min_connection_s, world.scenario.staff_connection_s)
			assert_eq(e.margin_s, e.gap_s - e.min_connection_s)
	assert_true(found, "el MVP tiene rotaciones de personal")


func test_no_self_edges() -> void:
	for e: RotationEdge in graph.edges:
		assert_ne(e.from_service_id, e.to_service_id)


func test_contiguous_segments_of_same_resource_make_no_edge() -> void:
	# stf_c01 hace 3101 y 3102; y d04 hace 3101 tramo 3-6 y 3102 tramo 0-3. Ninguna arista de un servicio a sí mismo.
	var chain: Array[StringName] = graph.chain(Enums.ResourceType.DRIVER, &"stf_d04")
	var seen: Dictionary = {}
	for s: StringName in chain:
		assert_false(seen.has(s))
		seen[s] = true


func test_incoming_outgoing_consistent() -> void:
	for e: RotationEdge in graph.edges:
		assert_true(graph.outgoing(e.from_service_id).has(e))
		assert_true(graph.incoming(e.to_service_id).has(e))


func test_deterministic_builds() -> void:
	var g2: RotationGraph = RotationGraph.build(world)
	assert_eq(graph.edges.size(), g2.edges.size())
	for i: int in graph.edges.size():
		var a: RotationEdge = graph.edges[i]
		var b: RotationEdge = g2.edges[i]
		assert_eq("%s>%s|%d|%s|%d" % [a.from_service_id, a.to_service_id, a.resource_type, a.resource_id, a.gap_s],
				"%s>%s|%d|%s|%d" % [b.from_service_id, b.to_service_id, b.resource_type, b.resource_id, b.gap_s])
