extends TestCase

func test_order_by_time() -> void:
	var q: EventQueue = EventQueue.new()
	q.push(SimEventType.SERVICE_ARRIVAL, 300, &"a")
	q.push(SimEventType.SERVICE_ARRIVAL, 100, &"b")
	q.push(SimEventType.SERVICE_ARRIVAL, 200, &"c")
	assert_eq(q.next_time(), 100)
	assert_eq(q.pop().service_id, &"b")
	assert_eq(q.pop().service_id, &"c")
	assert_eq(q.pop().service_id, &"a")
	assert_true(q.is_empty())
	assert_eq(q.next_time(), -1)
	assert_eq(q.pop(), null)
	assert_eq(q.peek(), null)


func test_same_time_priority_order() -> void:
	var q: EventQueue = EventQueue.new()
	q.push(SimEventType.DAY_END, 50)
	q.push(SimEventType.SERVICE_DEPARTURE, 50, &"d")
	q.push(SimEventType.SERVICE_PASS, 50, &"p")
	q.push(SimEventType.SERVICE_ARRIVAL, 50, &"a")
	q.push(SimEventType.INCIDENT_RESOLVED, 50)
	var order: Array[StringName] = []
	while not q.is_empty():
		order.append(q.pop().type)
	assert_eq(order, [SimEventType.INCIDENT_RESOLVED, SimEventType.SERVICE_ARRIVAL,
			SimEventType.SERVICE_PASS, SimEventType.SERVICE_DEPARTURE, SimEventType.DAY_END] as Array[StringName])


func test_priority_table() -> void:
	assert_eq(SimEventType.priority_of(SimEventType.INCIDENT_RESOLVED), 10)
	assert_eq(SimEventType.priority_of(SimEventType.SERVICE_ARRIVAL), 20)
	assert_eq(SimEventType.priority_of(SimEventType.SERVICE_PASS), 25)
	assert_eq(SimEventType.priority_of(SimEventType.SERVICE_DEPARTURE), 30)
	assert_eq(SimEventType.priority_of(SimEventType.ASSIGNMENT_START), 40)
	assert_eq(SimEventType.priority_of(SimEventType.DELAY_APPLIED), 50)
	assert_eq(SimEventType.priority_of(SimEventType.INCIDENT_TRIGGER), 60)
	assert_eq(SimEventType.priority_of(SimEventType.DECISION_TIMEOUT), 70)
	assert_eq(SimEventType.priority_of(SimEventType.SERVICE_CANCELLED), 80)
	assert_eq(SimEventType.priority_of(SimEventType.PASSENGER_INFO_SENT), 90)
	assert_eq(SimEventType.priority_of(SimEventType.DAY_END), 100)


func test_stability_same_time_same_priority_uses_seq() -> void:
	var q: EventQueue = EventQueue.new()
	var ids: Array[StringName] = []
	for i: int in 50:
		var id: StringName = StringName("s%d" % i)
		ids.append(id)
		q.push(SimEventType.SERVICE_DEPARTURE, 77, id)
	var got: Array[StringName] = []
	var last_seq: int = -1
	while not q.is_empty():
		var e: SimEvent = q.pop()
		got.append(e.service_id)
		assert_true(e.seq > last_seq, "seq creciente")
		last_seq = e.seq
	assert_eq(got, ids, "FIFO en empates")


func test_random_insertion_sorted_and_snapshot() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var q: EventQueue = EventQueue.new()
	var types: Array[StringName] = [SimEventType.SERVICE_ARRIVAL, SimEventType.SERVICE_PASS,
			SimEventType.SERVICE_DEPARTURE, SimEventType.DELAY_APPLIED]
	for i: int in 300:
		q.push(types[rng.randi() % 4], rng.randi_range(0, 40), &"x")
	var snap: Array[Dictionary] = q.snapshot()
	assert_eq(snap.size(), 300)
	assert_eq(q.size(), 300, "snapshot no modifica")
	var prev: Array = [-1, -1, -1]
	while not q.is_empty():
		var e: SimEvent = q.pop()
		var cur: Array = [e.time, e.priority, e.seq]
		assert_true(prev < cur, "orden (time, priority, seq) estrictamente creciente %s -> %s" % [prev, cur])
		prev = cur


func test_push_assigns_fields() -> void:
	var q: EventQueue = EventQueue.new()
	var e: SimEvent = q.push(SimEventType.SERVICE_PASS, 10, &"svc", 3, {"k": 1})
	assert_eq(e.priority, 25)
	assert_eq(e.stop_index, 3)
	assert_eq(e.time, 10)
	assert_eq(q.peek(), e)
