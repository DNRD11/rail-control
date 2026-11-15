class_name OptionPreview
extends RefCounted
## Previsión mostrada al jugador para una opción (estimación, no un hecho).

## Retraso previsto del propio servicio en destino (rango; min == max si es determinista).
var own_delay_min_s: int = 0
var own_delay_max_s: int = 0
## Servicios dependientes con retraso previsto: [{service_id, delay_min_s, delay_max_s}].
var dependents: Array[Dictionary] = []
## Servicios que quedarían cancelados (el propio o dependientes sin material).
var cancelled_service_ids: Array[StringName] = []
var affected_passengers: int = 0
var needing_alternative: int = 0
var cost_cents: int = 0
## Material de reserva que se usaría (vacío si no aplica) y plazas que faltan respecto a las reservas.
var reserve_vehicle_id: StringName = &""
var seats_short: int = 0
## Instante previsto de reanudación (solo opciones deterministas), si no NONE.
var resume_at: int = SimTime.NONE
