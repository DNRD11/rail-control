class_name ServicePositionCalc
extends RefCounted
## Calcula la posición de un servicio a partir del estado de sus puntos (SIMULATION.md §4). Sin estado propio.


static func compute(world: World, service: Service, now: int) -> ServicePosition:
	return compute_at(world, service, float(now))


## Posición teórica según el horario programado (sched_*), independiente del estado real.
static func compute_scheduled(world: World, service: Service, t: float) -> ServicePosition:
	var pos: ServicePosition = ServicePosition.new()
	pos.service_id = service.id
	var n: int = service.stops.size()
	if n == 0:
		return pos
	if t < float(service.stops[0].exit_time()):
		_at_station(world, service, 0, pos, ServicePosition.State.NOT_STARTED)
		return pos
	if t >= float(service.stops[n - 1].entry_time()):
		_at_station(world, service, n - 1, pos, ServicePosition.State.FINISHED)
		return pos
	for i: int in n - 1:
		var st: ServiceStop = service.stops[i]
		var nxt: ServiceStop = service.stops[i + 1]
		if t < float(st.exit_time()):
			if st.is_stopping():
				_at_station(world, service, i, pos, ServicePosition.State.AT_STATION)
				return pos
			continue
		if t < float(nxt.entry_time()):
			var span: int = nxt.entry_time() - st.exit_time()
			var frac: float = clampf((t - float(st.exit_time())) / float(maxi(span, 1)), 0.0, 1.0)
			_in_section(world, service, i, frac, pos)
			return pos
	_at_station(world, service, n - 1, pos, ServicePosition.State.FINISHED)
	return pos


## Posición en un instante fraccional con las horas estimadas vigentes.
static func compute_at(world: World, service: Service, now: float) -> ServicePosition:
	var pos: ServicePosition = ServicePosition.new()
	pos.service_id = service.id
	var n: int = service.stops.size()
	if n == 0:
		return pos
	match service.status:
		Enums.ServiceStatus.SCHEDULED:
			_at_station(world, service, 0, pos, ServicePosition.State.NOT_STARTED)
			return pos
		Enums.ServiceStatus.TERMINATED, Enums.ServiceStatus.CANCELLED:
			_at_station(world, service, n - 1, pos, ServicePosition.State.FINISHED)
			return pos
	var last: int = -1
	for i: int in n:
		if service.stops[i].status != Enums.StopStatus.PENDING:
			last = i
	if last < 0:
		_at_station(world, service, 0, pos, ServicePosition.State.NOT_STARTED)
		return pos
	var st: ServiceStop = service.stops[last]
	if st.status == Enums.StopStatus.ARRIVED or last >= n - 1:
		_at_station(world, service, last, pos, ServicePosition.State.AT_STATION)
		return pos
	var nxt: ServiceStop = service.stops[last + 1]
	var leg_start: int = st.act_dep
	var leg_end: int = nxt.est_arr
	var frac: float = 1.0
	if leg_end > leg_start:
		frac = clampf((now - float(leg_start)) / float(leg_end - leg_start), 0.0, 1.0)
	_in_section(world, service, last, frac, pos)
	return pos


static func _in_section(world: World, service: Service, i: int, frac: float, pos: ServicePosition) -> void:
	var st: ServiceStop = service.stops[i]
	var nxt: ServiceStop = service.stops[i + 1]
	pos.state = ServicePosition.State.IN_SECTION
	pos.stop_index = i
	pos.fraction = frac
	var ka: float = _km(world, st.station_id)
	var kb: float = _km(world, nxt.station_id)
	pos.km = ka + (kb - ka) * frac
	pos.direction = Enums.Direction.ASCENDING if kb >= ka else Enums.Direction.DESCENDING
	var sec: Section = world.section_between(st.station_id, nxt.station_id)
	pos.section_id = sec.id if sec != null else &""


static func _at_station(world: World, service: Service, index: int, pos: ServicePosition,
		state: ServicePosition.State) -> void:
	pos.state = state
	pos.stop_index = index
	pos.fraction = 0.0
	pos.km = _km(world, service.stops[index].station_id)
	pos.direction = _direction_at(world, service, index)


static func _direction_at(world: World, service: Service, index: int) -> Enums.Direction:
	var n: int = service.stops.size()
	var a: int = index if index < n - 1 else n - 2
	if a < 0:
		return Enums.Direction.ASCENDING
	var ka: float = _km(world, service.stops[a].station_id)
	var kb: float = _km(world, service.stops[a + 1].station_id)
	return Enums.Direction.ASCENDING if kb >= ka else Enums.Direction.DESCENDING


static func _km(world: World, station_id: StringName) -> float:
	var st: Station = world.stations.get(station_id) as Station
	return st.km if st != null else 0.0
