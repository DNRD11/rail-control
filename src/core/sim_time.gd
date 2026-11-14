class_name SimTime
extends RefCounted
## Tiempo de simulación: segundos enteros desde las 00:00 de la jornada.

const NONE: int = -1
const MAX_SECONDS: int = 48 * 3600


## "HH:MM" o "HH:MM:SS" → segundos. Devuelve NONE (-1) si el texto no es válido.
static func parse(text: String) -> int:
	var parts: PackedStringArray = text.strip_edges().split(":")
	if parts.size() < 2 or parts.size() > 3:
		return NONE
	var total: int = 0
	var limits: Array[int] = [48, 60, 60]
	var mult: Array[int] = [3600, 60, 1]
	for i: int in parts.size():
		if not parts[i].is_valid_int():
			return NONE
		var value: int = parts[i].to_int()
		if value < 0 or value >= limits[i]:
			return NONE
		total += value * mult[i]
	return total


## Segundos → "HH:MM" (o "HH:MM:SS"). NONE se muestra como "--:--".
static func format(seconds: int, with_seconds: bool = false) -> String:
	if seconds < 0:
		return "--:--:--" if with_seconds else "--:--"
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	if with_seconds:
		return "%02d:%02d:%02d" % [h, m, seconds % 60]
	return "%02d:%02d" % [h, m]
