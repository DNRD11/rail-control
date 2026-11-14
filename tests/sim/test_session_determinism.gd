extends TestCase

func test_chunking_equivalence_same_digest() -> void:
	var full: String = SimFixture.run_day_digest(100000)
	assert_eq(SimFixture.run_day_digest(1000), full, "1000 s por paso")
	assert_eq(SimFixture.run_day_digest(10), full, "10 s por paso")
	assert_eq(SimFixture.run_day_digest(37), full, "37 s por paso")
	assert_eq(SimFixture.run_day_digest(600), full, "600 s por paso")


func test_600_at_once_equals_600_by_1_and_60_by_10_and_37() -> void:
	var a: SimulationSession = SimFixture.session()
	var b: SimulationSession = SimFixture.session()
	var c: SimulationSession = SimFixture.session()
	var d: SimulationSession = SimFixture.session()
	a.advance_seconds(600)
	for i: int in 600:
		b.advance_seconds(1)
	for i: int in 60:
		c.advance_seconds(10)
	for i: int in 16:
		d.advance_seconds(37)
	d.advance_seconds(8)  # 16*37 + 8 = 600
	assert_eq(a.clock.now, a.clock.day_start + 600)
	assert_eq(b.clock.now, a.clock.now)
	assert_eq(c.clock.now, a.clock.now)
	assert_eq(d.clock.now, a.clock.now)
	assert_eq(b.log.digest(), a.log.digest())
	assert_eq(c.log.digest(), a.log.digest())
	assert_eq(d.log.digest(), a.log.digest())


func test_speed_changes_do_not_alter_digest() -> void:
	var full: String = SimFixture.run_day_digest(100000)
	assert_eq(SimFixture.run_day_digest(37, 12345, true), full, "pasos de 37 s con cambios de velocidad")
	assert_eq(SimFixture.run_day_digest(600, 12345, true), full, "pasos de 600 s con cambios de velocidad")
	assert_eq(SimFixture.run_day_digest(1000, 12345, true), full)


func test_speed_change_midway_600() -> void:
	var a: SimulationSession = SimFixture.session()
	var b: SimulationSession = SimFixture.session()
	a.advance_seconds(600)
	for i: int in 300:
		b.advance_seconds(1)
	b.apply_command(SetSpeedCommand.make(4))
	for i: int in 300:
		b.advance_seconds(1)
	assert_eq(b.clock.now, a.clock.now)
	assert_eq(b.log.digest(), a.log.digest())


func test_two_sessions_same_seed_same_digest() -> void:
	var a: SimulationSession = SimFixture.session(99)
	var b: SimulationSession = SimFixture.session(99)
	a.advance_seconds(100000)
	b.advance_seconds(100000)
	assert_true(a.log.count() > 0)
	assert_eq(a.log.digest(), b.log.digest())


func test_digest_sensitive_to_content() -> void:
	var a: SimulationSession = SimFixture.session()
	a.advance_seconds(100000)
	var d1: String = a.log.digest()
	a.log.add(a.clock.now, &"EXTRA")
	assert_ne(a.log.digest(), d1, "añadir una entrada cambia el digest")
	var half: SimulationSession = SimFixture.session()
	half.advance_seconds(3600)
	assert_ne(half.log.digest(), d1)


func test_seed_override_sets_rng() -> void:
	var a: SimulationSession = SimFixture.session(5)
	var b: SimulationSession = SimFixture.session(5)
	var c: SimulationSession = SimFixture.session(6)
	assert_eq(a.rng.seed, 5)
	assert_eq(a.rng.randi(), b.rng.randi())
	assert_ne(a.rng.randi(), c.rng.randi())


func test_default_seed_from_scenario() -> void:
	var w: World = ScenarioFixture.load_world()
	var s: SimulationSession = SimulationSession.create(w)
	assert_eq(s.rng.seed, w.scenario.seed)


func test_advance_nonpositive_is_noop() -> void:
	var s: SimulationSession = SimFixture.session()
	var t0: int = s.clock.now
	var ticks: Array[int] = [0]
	s.clock_ticked.connect(func(_n: int) -> void: ticks[0] += 1)
	s.advance_seconds(0)
	s.advance_seconds(-10)
	assert_eq(s.clock.now, t0)
	assert_eq(ticks[0], 0)
	assert_eq(s.log.count(), 0)


func test_stops_at_day_end_and_signal_once() -> void:
	var s: SimulationSession = SimFixture.session()
	var fin: Array[int] = [0]
	s.day_finished.connect(func() -> void: fin[0] += 1)
	s.advance_seconds(10000000)
	assert_eq(s.clock.now, s.clock.day_end)
	assert_eq(fin[0], 1)
	var count: int = s.log.count()
	s.advance_seconds(100)
	s.advance_seconds(100000)
	assert_eq(s.clock.now, s.clock.day_end, "no pasa de day_end")
	assert_eq(fin[0], 1, "day_finished una sola vez")
	assert_eq(s.log.count(), count)
	assert_eq(s.log.filter(SimEventType.DAY_END).size(), 1)
	assert_true(s.queue.is_empty())


func test_clock_ticked_emitted_with_now() -> void:
	var s: SimulationSession = SimFixture.session()
	var seen: Array[int] = []
	s.clock_ticked.connect(func(n: int) -> void: seen.append(n))
	s.advance_seconds(5)
	s.advance_seconds(7)
	assert_eq(seen, [s.clock.day_start + 5, s.clock.day_start + 12] as Array[int])


func test_invalid_command_rejected() -> void:
	var s: SimulationSession = SimFixture.session()
	var before: int = s.clock.speed
	assert_false(s.apply_command(SetSpeedCommand.make(3)))
	assert_false(s.apply_command(SetSpeedCommand.make(-1)))
	assert_eq(s.clock.speed, before)
	assert_eq(s.command_log.size(), 0, "los rechazados no se registran")


func test_valid_command_applied_and_logged() -> void:
	var s: SimulationSession = SimFixture.session()
	var speeds: Array[int] = []
	s.speed_changed.connect(func(v: int) -> void: speeds.append(v))
	s.advance_seconds(30)
	assert_true(s.apply_command(SetSpeedCommand.make(4)))
	assert_true(s.apply_command(SetSpeedCommand.make(0)))
	assert_eq(s.clock.speed, 0)
	assert_true(s.clock.is_paused())
	assert_eq(speeds, [4, 0] as Array[int])
	assert_eq(s.command_log.size(), 2)
	assert_eq(s.command_log[0].applied_at, s.clock.day_start + 30)
	assert_eq(s.command_log[0].kind, &"SET_SPEED")


func test_pause_command_does_not_change_state() -> void:
	var s: SimulationSession = SimFixture.session()
	s.apply_command(SetSpeedCommand.make(0))
	assert_eq(s.clock.now, s.clock.day_start)
	assert_eq(s.log.count(), 0)
