class_name SimClock
extends RefCounted
## Reloj de simulación: segundos enteros de jornada y velocidad (0 pausa, 1, 2, 4).

const VALID_SPEEDS: Array[int] = [0, 1, 2, 4]

var now: int = 0
var speed: int = 1
var time_scale: int = 1
var day_start: int = 0
var day_end: int = 86400


## Cambia la velocidad. Devuelve false (con aviso) si no es 0/1/2/4.
func set_speed(s: int) -> bool:
	if not VALID_SPEEDS.has(s):
		push_warning("Velocidad de simulación no válida: %d" % s)
		return false
	speed = s
	return true


func is_paused() -> bool:
	return speed == 0


func is_day_over() -> bool:
	return now >= day_end
