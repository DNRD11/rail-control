class_name DelayFixture
extends RefCounted
## Utilidades de prueba de retrasos: avance por pasos hasta una hora, inyección y volcado de estado.

const S3103: StringName = &"svc_3103"
const S3105: StringName = &"svc_3105"
const S3106: StringName = &"svc_3106"
const S3108: StringName = &"svc_3108"
const S3152: StringName = &"svc_3152"
const S3150: StringName = &"svc_3150"


static func t(text: String) -> int:
	return SimTime.parse(text)


## Avanza en pasos de `step` segundos hasta alcanzar exactamente `target` (el último paso se recorta).
static func run_to(s: SimulationSession, target: int, step: int = 100000) -> void:
	while s.clock.now < target and not s.clock.is_day_over():
		s.advance_seconds(mini(step, target - s.clock.now))


static func run_to_text(s: SimulationSession, text: String, step: int = 100000) -> void:
	run_to(s, t(text), step)


## Sesión avanzada a `at_text` con una inyección ya aplicada (comando).
static func injected(service_id: StringName, seconds: int, at_text: String = "08:00",
		step: int = 100000) -> SimulationSession:
	var s: SimulationSession = SimFixture.session()
	run_to_text(s, at_text, step)
	s.apply_command(InjectDelayCommand.make(service_id, seconds))
	return s


## Volcado canónico de las horas est_/act_/estado de todos los servicios (para comparar estados).
static func state_dump(s: SimulationSession, with_actuals: bool = true) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for sid: StringName in s.service_ids():
		var sv: Service = s.world.services[sid]
		for st: ServiceStop in sv.stops:
			var line: String = "%s|%d|%d|%d|%d|%d" % [sid, st.index, sv.status, st.status, st.est_arr, st.est_dep]
			if with_actuals:
				line += "|%d|%d" % [st.act_arr, st.act_dep]
			lines.append(line)
	return "\n".join(lines)


## Digest de una jornada completa con una inyección a `at_text` aplicada de distintas formas.
## mode: "command" | "paused_command" | "queue_event" (empuja DELAY_APPLIED y lo procesa) |
## "queue_then_advance" (empuja y deja que advance_seconds lo procese).
static func run_digest(step: int, mode: String, service_id: StringName = S3103, seconds: int = 1500,
		at_text: String = "08:00") -> String:
	var s: SimulationSession = SimFixture.session()
	run_to_text(s, at_text, step)
	match mode:
		"command":
			s.apply_command(InjectDelayCommand.make(service_id, seconds))
		"paused_command":
			s.apply_command(SetSpeedCommand.make(0))
			s.apply_command(InjectDelayCommand.make(service_id, seconds))
			s.apply_command(SetSpeedCommand.make(1))
		"queue_event":
			s.queue.push(SimEventType.DELAY_APPLIED, s.clock.now, service_id, -1,
					{"seconds": seconds, "cause": DelayInfo.CAUSE_INJECTED})
			s.process_due_events()
		"queue_then_advance":
			s.queue.push(SimEventType.DELAY_APPLIED, s.clock.now, service_id, -1,
					{"seconds": seconds, "cause": DelayInfo.CAUSE_INJECTED})
	run_to(s, s.clock.day_end, step)
	return s.log.digest()
