class_name InjectDelayCommand
extends Command
## Inyecta un retraso en un servicio (mecanismo de «provocar» retraso en Fase 4). Programa un
## DELAY_APPLIED a la hora actual; el DelaySystem lo aplica y lo propaga.

var service_id: StringName = &""
var seconds: int = 0


static func make(p_service_id: StringName, p_seconds: int) -> InjectDelayCommand:
	var c: InjectDelayCommand = InjectDelayCommand.new()
	c.service_id = p_service_id
	c.seconds = p_seconds
	return c


func _init() -> void:
	kind = &"INJECT_DELAY"


func validate(session: SimulationSession) -> String:
	if seconds <= 0:
		return "El retraso debe ser positivo: %d s" % seconds
	var s: Service = session.world.services.get(service_id) as Service
	if s == null:
		return "Servicio desconocido: %s" % service_id
	if s.status == Enums.ServiceStatus.TERMINATED or s.is_cancelled():
		return "El servicio %s ya ha terminado o está cancelado" % s.code
	return ""


func apply(session: SimulationSession) -> void:
	session.queue.push(SimEventType.DELAY_APPLIED, session.clock.now, service_id, -1,
			{"seconds": seconds, "cause": DelayInfo.CAUSE_INJECTED})
	session.process_due_events()  # visible de inmediato aunque la simulación esté en pausa
