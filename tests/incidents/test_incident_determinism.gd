extends TestCase
## Determinismo de las incidencias: tamaño de paso, opciones y semillas (SIMULATION.md §7).

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")

const STEPS: Array[int] = [1, 37, 600, 100000]
const OPTIONS: Array[StringName] = [OptionType.WAIT_REPAIR, OptionType.SUBSTITUTE_ROLLING_STOCK,
		OptionType.CANCEL_SERVICE]


## Jornada con la avería guionizada, decisión a las 08:12 y pasos de `step` segundos.
static func _digest(option: StringName, step: int, seed_value: int = 12345) -> String:
	var s: SimulationSession = SimFixture.session_with_incident(seed_value)
	D.run_to_text(s, "08:12", step)
	F.decide(s, option)
	D.run_to(s, s.clock.day_end, step)
	return s.log.digest()


func test_same_digest_for_any_step_size_per_option() -> void:
	for option: StringName in OPTIONS:
		var reference: String = _digest(option, STEPS[0])
		for step: int in STEPS:
			assert_eq(_digest(option, step), reference, "%s con paso %d" % [option, step])


func test_options_produce_different_logs() -> void:
	var seen: Dictionary = {}
	for option: StringName in OPTIONS:
		seen[_digest(option, 600)] = true
	assert_eq(seen.size(), 3, "cada opción deja un log distinto")


func test_same_seed_same_digest_repeated() -> void:
	assert_eq(_digest(OptionType.WAIT_REPAIR, 600, 777), _digest(OptionType.WAIT_REPAIR, 600, 777))


func test_hidden_repair_time_depends_only_on_seed() -> void:
	var a: SimulationSession = SimFixture.session_with_incident(5)
	var b: SimulationSession = SimFixture.session_with_incident(5)
	D.run_to_text(a, "08:12", 37)
	D.run_to_text(b, "08:12", 100000)
	assert_eq(F.incident(a).repair_s, F.incident(b).repair_s)


func test_timeout_default_is_step_independent() -> void:
	var digests: Array[String] = []
	for step: int in STEPS:
		var s: SimulationSession = SimFixture.session_with_incident()
		D.run_to(s, s.clock.day_end, step)
		digests.append(s.log.digest())
	for d: String in digests:
		assert_eq(d, digests[0])


static func _random_digest(seed_value: int, step: int) -> String:
	var world: World = ScenarioFixture.load_world()
	world.scenario.scripted_incidents.clear()
	world.scenario.random_incidents_enabled = true
	var s: SimulationSession = SimulationSession.create(world, seed_value)
	D.run_to(s, s.clock.day_end, step)
	return s.log.digest()


func test_random_incidents_same_seed_same_result() -> void:
	for seed_value: int in [1, 2, 3, 42]:
		assert_eq(_random_digest(seed_value, 600), _random_digest(seed_value, 600), "semilla %d" % seed_value)


func test_random_incidents_step_independent() -> void:
	assert_eq(_random_digest(42, 37), _random_digest(42, 100000))


func test_random_incidents_different_seeds_can_differ() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(1, 9):
		seen[_random_digest(seed_value, 600)] = true
	assert_true(seen.size() > 1, "8 semillas distintas producen al menos 2 jornadas distintas")
