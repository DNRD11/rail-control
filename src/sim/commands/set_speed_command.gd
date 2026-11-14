class_name SetSpeedCommand
extends Command
## Cambia la velocidad de simulación (0 = pausa, 1, 2, 4).

var speed: int = 1


static func make(s: int) -> SetSpeedCommand:
	var c: SetSpeedCommand = SetSpeedCommand.new()
	c.speed = s
	return c


func _init() -> void:
	kind = &"SET_SPEED"


func validate(_session: SimulationSession) -> String:
	if not SimClock.VALID_SPEEDS.has(speed):
		return "Velocidad no válida: %d (solo 0, 1, 2 o 4)" % speed
	return ""


func apply(session: SimulationSession) -> void:
	session.clock.set_speed(speed)
	session.speed_changed.emit(speed)
