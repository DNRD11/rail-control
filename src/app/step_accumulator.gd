class_name StepAccumulator
extends RefCounted
## Convierte tiempo real en segundos enteros de simulación.
## Sin dependencias de nodos ni de la sesión: testeable sin árbol.

## Máximo de segundos de simulación por llamada a feed().
const MAX_STEP_PER_FRAME: int = 600

var _acc: float = 0.0


## Devuelve los segundos enteros a avanzar. Con speed <= 0 devuelve 0 y no acumula.
func feed(real_delta: float, time_scale: int, speed: int) -> int:
	if speed <= 0 or time_scale <= 0:
		return 0
	_acc += maxf(real_delta, 0.0) * float(time_scale) * float(speed)
	var n: int = mini(int(floor(_acc)), MAX_STEP_PER_FRAME)
	_acc -= float(n)
	return n


## Resto fraccional (0 <= f < 1 salvo que haya exceso retenido por el límite).
func fraction() -> float:
	return clampf(_acc, 0.0, 1.0)


func reset() -> void:
	_acc = 0.0
