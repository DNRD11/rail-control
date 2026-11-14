extends TestCase

func test_pause_returns_zero_and_does_not_accumulate() -> void:
	var a: StepAccumulator = StepAccumulator.new()
	for i: int in 100:
		assert_eq(a.feed(0.5, 1, 0), 0)
	assert_eq(a.fraction(), 0.0)
	# al reanudar no hay segundos acumulados durante la pausa
	assert_eq(a.feed(0.0, 1, 1), 0)


func test_fraction_and_integer_steps() -> void:
	var a: StepAccumulator = StepAccumulator.new()
	assert_eq(a.feed(0.4, 1, 1), 0)
	assert_near_f(a.fraction(), 0.4)
	assert_eq(a.feed(0.4, 1, 1), 0)
	assert_eq(a.feed(0.4, 1, 1), 1)
	assert_near_f(a.fraction(), 0.2)


func assert_near_f(a: float, b: float) -> void:
	assertions += 1
	if absf(a - b) > 0.0001:
		_fail("esperado ~%s pero se obtuvo %s" % [b, a])


func _total(speed: int, scale: int, real_s: float, frame: float) -> int:
	var a: StepAccumulator = StepAccumulator.new()
	var total: int = 0
	var t: float = 0.0
	while t < real_s - 0.000001:
		total += a.feed(frame, scale, speed)
		t += frame
	return total


func test_speeds_equivalent() -> void:
	# x2 durante 10 s reales == x1 durante 20 s reales; x4 durante 5 s == x1 durante 20 s.
	var x1: int = _total(1, 1, 20.0, 0.25)
	var x2: int = _total(2, 1, 10.0, 0.25)
	var x4: int = _total(4, 1, 5.0, 0.25)
	assert_eq(x1, 20)
	assert_eq(x2, x1)
	assert_eq(x4, x1)


func test_time_scale_multiplies() -> void:
	assert_eq(_total(1, 60, 2.0, 0.5), 120)
	assert_eq(_total(4, 60, 2.0, 0.5), 480)


func test_frame_rate_independent_total() -> void:
	assert_eq(_total(1, 10, 6.0, 0.016), _total(1, 10, 6.0, 0.1) , "60fps vs 10fps")


func test_cap_600_and_excess_drained() -> void:
	var a: StepAccumulator = StepAccumulator.new()
	assert_eq(a.feed(2000.0, 1, 1), 600, "limitado a 600")
	assert_eq(a.feed(0.0, 1, 1), 600)
	assert_eq(a.feed(0.0, 1, 1), 600)
	assert_eq(a.feed(0.0, 1, 1), 200, "drena el exceso 2000 = 600*3+200")
	assert_eq(a.feed(0.0, 1, 1), 0)
	assert_eq(StepAccumulator.MAX_STEP_PER_FRAME, 600)


func test_negative_delta_ignored() -> void:
	var a: StepAccumulator = StepAccumulator.new()
	assert_eq(a.feed(-5.0, 1, 1), 0)
	assert_eq(a.feed(1.0, 1, 1), 1)
