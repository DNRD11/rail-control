class_name SimFixture
extends RefCounted
## Utilidades de prueba de simulación: sesión nueva del escenario MVP con semilla fija.

## Sesión del escenario MVP SIN la avería guionizada (las pruebas de retrasos y movimiento la excluyen).
static func session(seed_override: int = 12345) -> SimulationSession:
	var world: World = ScenarioFixture.load_world()
	world.scenario.scripted_incidents.clear()
	return SimulationSession.create(world, seed_override)


## Sesión con la avería guionizada del 3103 (reparación fija opcional: `repair_s` = segundos exactos).
static func session_with_incident(seed_override: int = 12345, repair_s: int = -1) -> SimulationSession:
	var world: World = ScenarioFixture.load_world()
	if repair_s > 0:
		for d: Dictionary in world.scenario.scripted_incidents:
			d["repair_s"] = [repair_s, repair_s]
	return SimulationSession.create(world, seed_override)


## Avanza hasta day_end en pasos de `step` segundos y devuelve el digest del log.
static func run_day_digest(step: int, seed_override: int = 12345, change_speed: bool = false) -> String:
	var s: SimulationSession = session(seed_override)
	var total: int = s.clock.day_end - s.clock.now
	var done: int = 0
	var speeds: Array[int] = [1, 2, 4, 0, 1]
	var k: int = 0
	while done < total:
		if change_speed:
			s.apply_command(SetSpeedCommand.make(speeds[k % speeds.size()]))
			k += 1
		var n: int = mini(step, total - done)
		s.advance_seconds(n)
		done += n
	return s.log.digest()
