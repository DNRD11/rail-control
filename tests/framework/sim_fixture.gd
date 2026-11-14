class_name SimFixture
extends RefCounted
## Utilidades de prueba de simulación: sesión nueva del escenario MVP con semilla fija.

static func session(seed_override: int = 12345) -> SimulationSession:
	return SimulationSession.create(ScenarioFixture.load_world(), seed_override)


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
