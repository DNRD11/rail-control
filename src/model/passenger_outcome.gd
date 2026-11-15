class_name PassengerOutcome
extends RefCounted
## Resultado agregado de los viajeros de un servicio, por parada de bajada (aproximación del MVP).
## Distingue hechos (parada alcanzada) de proyección (parada pendiente con hora estimada).

var booked: int = 0
## Viajeros que ya han llegado a su destino.
var carried: int = 0
## Viajeros cuyo destino ya no se alcanzará (servicio cancelado).
var needing_alternative: int = 0
var affected: int = 0
var compensation_eligible: int = 0
## Σ viajeros × minutos de retraso por encima de la tolerancia (solo llegadas, no cancelados).
var delay_pax_min: int = 0
## Σ viajeros × puntos de calidad (0-100) y viajeros considerados para la media.
var quality_points: int = 0
var quality_pax: int = 0
## Σ viajeros × % de indemnización (0-100): base del importe a pagar.
var compensation_pax_pct: int = 0
