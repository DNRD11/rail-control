class_name Command
extends RefCounted
## Orden del jugador o del sistema aplicada a la sesión. Se registra en `session.command_log`.

var kind: StringName = &""
## Hora de simulación en que se aplicó (la rellena la sesión).
var applied_at: int = -1


## "" si es válido; si no, el motivo (en español).
func validate(_session: SimulationSession) -> String:
	return ""


func apply(_session: SimulationSession) -> void:
	pass
