class_name PassengerCalc
extends RefCounted
## Viajeros agregados de un servicio según el punto alcanzado (aproximación del MVP). Sin estado.


## Viajeros a bordo tras el último punto alcanzado `last` (-1 si no ha salido).
static func aboard(world: World, service_id: StringName, last: int) -> int:
	var load: ServicePassengerLoad = world.passengers.get(service_id)
	if load == null or last < 0:
		return 0
	var n: int = 0
	for k: int in load.boardings_by_stop:
		if k <= last:
			n += load.boardings_by_stop[k]
	for k: int in load.alightings_by_stop:
		if k <= last:
			n -= load.alightings_by_stop[k]
	return maxi(n, 0)


## Viajeros que aún no han subido (suben en paradas posteriores a `last`).
static func pending_boardings(world: World, service_id: StringName, last: int) -> int:
	var load: ServicePassengerLoad = world.passengers.get(service_id)
	if load == null:
		return 0
	var n: int = 0
	for k: int in load.boardings_by_stop:
		if k > last:
			n += load.boardings_by_stop[k]
	return n


static func booked(world: World, service_id: StringName) -> int:
	var load: ServicePassengerLoad = world.passengers.get(service_id)
	return load.booked if load != null else 0


## Viajeros que no llegarían a su destino si el servicio se cancela ahora.
static func needing_alternative(world: World, s: Service) -> int:
	var last: int = SessionQueries.last_reached(s)
	return aboard(world, s.id, last) + pending_boardings(world, s.id, last)


## Resultado agregado de los viajeros de un servicio ahora mismo: hechos en paradas alcanzadas, proyección
## (horas estimadas) en las pendientes y cancelación en las canceladas. Cada grupo es una parada de bajada.
static func outcome(world: World, s: Service) -> PassengerOutcome:
	var o: PassengerOutcome = PassengerOutcome.new()
	var load: ServicePassengerLoad = world.passengers.get(s.id)
	if load == null:
		return o
	o.booked = load.booked
	var pr: PerceptionRules = world.perception_rules
	var cr: CompensationRules = world.compensation_rules
	for k: int in load.alightings_by_stop:
		var n: int = load.alightings_by_stop[k]
		if n <= 0 or k < 0 or k >= s.stops.size():
			continue
		var st: ServiceStop = s.stops[k]
		if st.status == Enums.StopStatus.CANCELLED:
			o.needing_alternative += n
			o.affected += n
			o.compensation_eligible += n
			o.compensation_pax_pct += n * cr.cancellation_percent
			o.quality_pax += n
			o.quality_points += n * pr.quality_cancelled
			continue
		var reached: bool = st.status == Enums.StopStatus.ARRIVED or st.status == Enums.StopStatus.PASSED
		var delay: int = arrival_delay(st, reached)
		var level: StringName = DelayInfo.LEVEL_ON_TIME if delay <= pr.delay_tolerance_s \
				else DelayInfo.level_for(delay)
		if reached:
			o.carried += n
		if delay > pr.delay_tolerance_s:
			o.affected += n
			o.delay_pax_min += n * (delay - pr.delay_tolerance_s) / 60
		var pct: int = cr.percent_for_delay(delay)
		if pct > 0:
			o.compensation_eligible += n
			o.compensation_pax_pct += n * pct
		# Denominador fijo (todos los viajeros previstos): cancelar nunca mejora la media por «quitar» viajeros.
		o.quality_pax += n
		o.quality_points += n * int(pr.quality_scores.get(level, 0))
	return o


## Retraso (s) en la llegada a una parada: real si se ha alcanzado, estimado si no.
static func arrival_delay(st: ServiceStop, reached: bool) -> int:
	var ref: int = st.entry_time()
	var t: int = st.act_arr if reached and st.act_arr != SimTime.NONE else st.est_arr
	if t == SimTime.NONE:
		t = st.est_dep
	if t == SimTime.NONE or ref == SimTime.NONE:
		return 0
	return maxi(t - ref, 0)
