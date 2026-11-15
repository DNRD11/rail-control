class_name PerceptionRules
extends RefCounted
## Parámetros de calidad y percepción (data/rules/perception.json). Ver ECONOMY.md §5.

var base: int = 75
## Retraso en destino que aún cuenta como «en hora».
var delay_tolerance_s: int = 180
## Puntos de calidad por nivel de DelayInfo (ON_TIME/MINOR/MAJOR/SEVERE) y para cancelado.
var quality_scores: Dictionary[StringName, int] = {}
var quality_cancelled: int = 0
## Todos los coeficientes son «puntos por cada 1000 viajeros» (el de retraso, por 1000 viajeros-minuto).
var delay_penalty_per_1000_pax_min: float = 0.0
var cancel_penalty_per_1000_pax: float = 0.0
var no_info_penalty_per_1000_pax: float = 0.0
var early_info_bonus_per_1000_pax: float = 0.0
var continuity_bonus_per_1000_pax: float = 0.0
## Ventana (s) desde que los viajeros quedan afectados para informar a tiempo.
var info_window_s: int = 600
## Fracción de la penalización por falta de información que se aplica si se informa fuera de ventana.
var late_info_factor: float = 0.5
