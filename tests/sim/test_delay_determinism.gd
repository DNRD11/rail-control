extends TestCase
## Determinismo con retrasos: el digest no depende del tamaño de paso ni de cómo se inyecta el retraso.

const D = preload("res://tests/framework/delay_fixture.gd")


func test_digest_same_for_steps_1_37_600_100000() -> void:
	var ref: String = D.run_digest(100000, "command")
	for step: int in [1, 37, 600]:
		assert_eq(D.run_digest(step, "command"), ref, "paso de %d s" % step)


func test_injection_changes_digest_and_logs_entries() -> void:
	var s: SimulationSession = D.injected(D.S3103, 1500)
	D.run_to(s, s.clock.day_end)
	var base: SimulationSession = SimFixture.session()
	D.run_to(base, base.clock.day_end)
	assert_ne(s.log.digest(), base.log.digest())
	assert_eq(s.log.filter(SimEventType.DELAY_APPLIED).size(), 1)
	assert_true(s.log.filter(&"DELAY_PROPAGATED").size() >= 2, "3105 y 3152 reciben propagación")


func test_injection_in_pause_equals_running() -> void:
	var ref: String = D.run_digest(100000, "command")
	assert_eq(D.run_digest(37, "paused_command"), ref, "inyección con la sesión en pausa")
	assert_eq(D.run_digest(600, "paused_command"), ref)


func test_process_due_events_path_equals_command() -> void:
	var ref: String = D.run_digest(100000, "command")
	assert_eq(D.run_digest(37, "queue_event"), ref, "evento en cola + process_due_events")
	assert_eq(D.run_digest(100000, "queue_event"), ref)
	assert_eq(D.run_digest(600, "queue_then_advance"), ref, "evento en cola procesado por advance_seconds")
	assert_eq(D.run_digest(1, "queue_then_advance"), ref)


func test_final_state_independent_of_step() -> void:
	var a: SimulationSession = D.injected(D.S3103, 1500, "08:00", 100000)
	D.run_to(a, a.clock.day_end, 100000)
	var b: SimulationSession = D.injected(D.S3103, 1500, "08:00", 37)
	D.run_to(b, b.clock.day_end, 37)
	assert_eq(D.state_dump(b), D.state_dump(a))
	for sid: StringName in a.service_ids():
		assert_eq(b.delay_of(sid), a.delay_of(sid), str(sid))


func test_same_seed_same_commands_same_digest() -> void:
	assert_eq(D.run_digest(600, "command", D.S3103, 1500), D.run_digest(600, "command", D.S3103, 1500))
	assert_ne(D.run_digest(600, "command", D.S3103, 1500), D.run_digest(600, "command", D.S3103, 1501))


func test_injection_at_other_hour_steps_equivalent() -> void:
	var ref: String = D.run_digest(100000, "command", D.S3150, 700, "07:15")
	assert_eq(D.run_digest(37, "command", D.S3150, 700, "07:15"), ref)
	assert_eq(D.run_digest(600, "command", D.S3150, 700, "07:15"), ref)


func test_two_injections_digest_step_independent() -> void:
	var digests: Array[String] = []
	for step: int in [100000, 37, 600]:
		var s: SimulationSession = SimFixture.session()
		D.run_to_text(s, "08:00", step)
		s.apply_command(InjectDelayCommand.make(D.S3103, 600))
		D.run_to_text(s, "08:20", step)
		s.apply_command(InjectDelayCommand.make(D.S3103, 900))
		D.run_to(s, s.clock.day_end, step)
		digests.append(s.log.digest())
	assert_eq(digests[1], digests[0])
	assert_eq(digests[2], digests[0])
