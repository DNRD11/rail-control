class_name EventQueue
extends RefCounted
## Montículo mínimo de eventos ordenado por (time, priority, seq).

var _heap: Array[SimEvent] = []
var _next_seq: int = 0


func push(type: StringName, time: int, service_id: StringName = &"", stop_index: int = -1,
		data: Dictionary = {}) -> SimEvent:
	var e: SimEvent = SimEvent.new()
	e.type = type
	e.time = time
	e.priority = SimEventType.priority_of(type)
	e.seq = _next_seq
	_next_seq += 1
	e.service_id = service_id
	e.stop_index = stop_index
	e.data = data
	_heap.append(e)
	_sift_up(_heap.size() - 1)
	return e


func peek() -> SimEvent:
	return _heap[0] if not _heap.is_empty() else null


func pop() -> SimEvent:
	if _heap.is_empty():
		return null
	var top: SimEvent = _heap[0]
	var last: SimEvent = _heap.pop_back()
	if not _heap.is_empty():
		_heap[0] = last
		_sift_down(0)
	return top


func is_empty() -> bool:
	return _heap.is_empty()


func size() -> int:
	return _heap.size()


## Hora del primer evento, o -1 si la cola está vacía.
func next_time() -> int:
	return _heap[0].time if not _heap.is_empty() else -1


## Resúmenes en orden de procesamiento (para pruebas). No modifica la cola.
func snapshot() -> Array[Dictionary]:
	var copy: Array[SimEvent] = _heap.duplicate()
	copy.sort_custom(func(a: SimEvent, b: SimEvent) -> bool: return a.before(b))
	var out: Array[Dictionary] = []
	for e: SimEvent in copy:
		out.append({"time": e.time, "priority": e.priority, "seq": e.seq, "type": e.type,
				"service_id": e.service_id, "stop_index": e.stop_index})
	return out


func _sift_up(start: int) -> void:
	var i: int = start
	while i > 0:
		var p: int = (i - 1) / 2
		if not _heap[i].before(_heap[p]):
			return
		var tmp: SimEvent = _heap[i]
		_heap[i] = _heap[p]
		_heap[p] = tmp
		i = p


func _sift_down(start: int) -> void:
	var i: int = start
	var n: int = _heap.size()
	while true:
		var l: int = 2 * i + 1
		var r: int = l + 1
		var m: int = i
		if l < n and _heap[l].before(_heap[m]):
			m = l
		if r < n and _heap[r].before(_heap[m]):
			m = r
		if m == i:
			return
		var tmp: SimEvent = _heap[i]
		_heap[i] = _heap[m]
		_heap[m] = tmp
		i = m
