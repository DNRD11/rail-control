class_name AssignmentBook
extends RefCounted
## Colección de asignaciones con consultas por servicio, recurso, segmento y parada.

var _items: Array[ResourceAssignment] = []


func add(a: ResourceAssignment) -> void:
	_items.append(a)


func all() -> Array[ResourceAssignment]:
	return _items


func count() -> int:
	return _items.size()


func for_service(service_id: StringName, live_only: bool = true) -> Array[ResourceAssignment]:
	var out: Array[ResourceAssignment] = []
	for a: ResourceAssignment in _items:
		if a.service_id == service_id and (a.is_live() or not live_only):
			out.append(a)
	return out


## Asignaciones vivas de un recurso ordenadas por planned_start (desempate por id).
func for_resource(type: Enums.ResourceType, resource_id: StringName) -> Array[ResourceAssignment]:
	var out: Array[ResourceAssignment] = []
	for a: ResourceAssignment in _items:
		if a.resource_type == type and a.resource_id == resource_id and a.is_live():
			out.append(a)
	out.sort_custom(_before)
	return out


static func _before(x: ResourceAssignment, y: ResourceAssignment) -> bool:
	if x.planned_start != y.planned_start:
		return x.planned_start < y.planned_start
	return String(x.id) < String(y.id)


func for_segment(service_id: StringName, type: Enums.ResourceType, segment_index: int) -> Array[ResourceAssignment]:
	var out: Array[ResourceAssignment] = []
	for a: ResourceAssignment in for_service(service_id):
		if a.resource_type == type and a.covers_segment(segment_index):
			out.append(a)
	return out


func at_stop(service_id: StringName, type: Enums.ResourceType, stop_index: int) -> Array[ResourceAssignment]:
	var out: Array[ResourceAssignment] = []
	for a: ResourceAssignment in for_service(service_id):
		if a.resource_type == type and a.covers_stop(stop_index):
			out.append(a)
	return out


## Ids de recursos distintos (orden de aparición) del tipo dado en un servicio.
func resource_ids_for(service_id: StringName, type: Enums.ResourceType) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: ResourceAssignment in for_service(service_id):
		if a.resource_type == type and not out.has(a.resource_id):
			out.append(a.resource_id)
	return out
