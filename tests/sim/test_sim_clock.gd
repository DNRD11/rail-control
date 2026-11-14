extends TestCase

func test_valid_speeds() -> void:
	var c: SimClock = SimClock.new()
	for sp: int in [0, 1, 2, 4]:
		assert_true(c.set_speed(sp), "velocidad %d válida" % sp)
		assert_eq(c.speed, sp)
	assert_true(c.is_paused() == false)
	c.set_speed(0)
	assert_true(c.is_paused())


func test_invalid_speed_ignored() -> void:
	var c: SimClock = SimClock.new()
	c.set_speed(2)
	for bad: int in [3, -1, 8, 100]:
		assert_false(c.set_speed(bad), "velocidad %d rechazada" % bad)
		assert_eq(c.speed, 2, "la velocidad no cambia")


func test_day_over() -> void:
	var c: SimClock = SimClock.new()
	c.day_end = 1000
	c.now = 999
	assert_false(c.is_day_over())
	c.now = 1000
	assert_true(c.is_day_over())
