class_name Indicators
extends RefCounted
## Indicadores de la jornada para el panel (solo lectura). Ver ECONOMY.md §5.

## Calidad del servicio 0-100 (puntualidad en destino ponderada por viajeros).
var quality: float = 100.0
## Percepción del cliente 0-100.
var perception: float = 75.0
## Resultado económico: suma del libro, en céntimos.
var result_cents: int = 0
var passengers_carried: int = 0
## Viajeros afectados por retraso apreciable o cancelación.
var affected: int = 0
## Viajeros con indemnización (ya pagada o prevista según el retraso proyectado).
var compensated: int = 0
var needing_alternative: int = 0
## Ingresos que no se cobran por viajeros no transportados (informativo; no es un apunte del libro).
var lost_revenue_cents: int = 0
