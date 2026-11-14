class_name RotationGraph
extends RefCounted
## Grafo derivado de las asignaciones: cómo se propagan los retrasos entre servicios.

var edges: Array[RotationEdge] = []
var _out: Dictionary = {}
var _in: Dictionary = {}
var _chains: Dictionary = {}


static func build(world: World) -> RotationGraph:
	var g: RotationGraph = RotationGraph.new()
	# Recursos en orden de primera aparición (determinista).
	for a: ResourceAssignment in world.assignments.all():
		if not a.is_live() or a.resource_type == Enums.ResourceType.VEHICLE:
			continue
		var k: String = _key(a.resource_type, a.resource_id)
		if g._chains.has(k):
			continue
		g._chains[k] = []
		g._add_resource(world, a.resource_type, a.resource_id, k, world.assignments.for_resource(a.resource_type, a.resource_id))
	return g


static func _key(type: Enums.ResourceType, resource_id: StringName) -> String:
	return "%d:%s" % [type, resource_id]


func _add_resource(world: World, type: Enums.ResourceType, rid: StringName, k: String, list: Array[ResourceAssignment]) -> void:
	var chain: Array = _chains[k]
	var prev: ResourceAssignment = null
	for a: ResourceAssignment in list:
		if prev != null and prev.service_id == a.service_id:
			prev = a
			continue
		chain.append(a.service_id)
		if prev != null:
			var e: RotationEdge = RotationEdge.new()
			e.from_service_id = prev.service_id
			e.to_service_id = a.service_id
			e.resource_type = type
			e.resource_id = rid
			e.station_id = a.from_station_id
			e.from_assignment_id = prev.id
			e.to_assignment_id = a.id
			e.gap_s = a.planned_start - prev.planned_end
			e.min_connection_s = _min_connection(world, type, e.station_id)
			e.margin_s = e.gap_s - e.min_connection_s
			edges.append(e)
			_push(_out, e.from_service_id, e)
			_push(_in, e.to_service_id, e)
		prev = a


static func _min_connection(world: World, type: Enums.ResourceType, station_id: StringName) -> int:
	if type == Enums.ResourceType.COMPOSITION:
		var st: Station = world.stations.get(station_id)
		return st.min_turnaround_s if st != null else 0
	return world.scenario.staff_connection_s


func _push(d: Dictionary, key: StringName, e: RotationEdge) -> void:
	if not d.has(key):
		d[key] = []
	var arr: Array = d[key]
	arr.append(e)


func outgoing(service_id: StringName) -> Array[RotationEdge]:
	return _typed(_out.get(service_id, []))


func incoming(service_id: StringName) -> Array[RotationEdge]:
	return _typed(_in.get(service_id, []))


## Servicios del recurso en orden cronológico (sin repetir consecutivos).
func chain(type: Enums.ResourceType, resource_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var src: Array = _chains.get(_key(type, resource_id), [])
	for s: Variant in src:
		out.append(s)
	return out


## Cierre transitivo de servicios afectados aguas abajo (BFS, sin duplicados ni el propio).
func downstream(service_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var queue: Array[StringName] = [service_id]
	var visited: Dictionary = {service_id: true}
	var head: int = 0
	while head < queue.size():
		var cur: StringName = queue[head]
		head += 1
		for e: RotationEdge in outgoing(cur):
			if not visited.has(e.to_service_id):
				visited[e.to_service_id] = true
				out.append(e.to_service_id)
				queue.append(e.to_service_id)
	return out


func _typed(src: Array) -> Array[RotationEdge]:
	var out: Array[RotationEdge] = []
	for e: Variant in src:
		out.append(e)
	return out
