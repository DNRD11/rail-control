class_name MovementSystem
extends SimSystem
## Circulación: salidas, llegadas y pasos de los servicios comerciales (SIMULATION.md §4).
## Los eventos se programan siempre desde las horas estimadas (est_*). Cada servicio tiene como mucho
## un evento de movimiento pendiente; al cambiar est_* (DelaySystem) se invalida y se reprograma.

var _pending: Dictionary[StringName, SimEvent] = {}


func start(session: SimulationSession) -> void:
	for sid: StringName in session.world.services:
		var s: Service = session.world.services[sid]
		if s.kind != Enums.ServiceKind.COMMERCIAL or s.stops.size() < 2:
			continue
		for st: ServiceStop in s.stops:
			st.est_arr = st.sched_arr
			st.est_dep = st.sched_dep
		_push(session, SimEventType.SERVICE_DEPARTURE, s.stops[0].est_dep, s, 0)


func handles(type: StringName) -> bool:
	return type == SimEventType.SERVICE_DEPARTURE or type == SimEventType.SERVICE_ARRIVAL \
			or type == SimEventType.SERVICE_PASS


func handle(event: SimEvent, session: SimulationSession) -> void:
	var s: Service = session.world.services.get(event.service_id) as Service
	if s == null or event.stop_index < 0 or event.stop_index >= s.stops.size():
		return
	if _pending.get(s.id) == event:
		_pending.erase(s.id)
	match event.type:
		SimEventType.SERVICE_DEPARTURE:
			_on_departure(s, event.stop_index, session)
		SimEventType.SERVICE_ARRIVAL:
			_on_arrival(s, event.stop_index, session)
		SimEventType.SERVICE_PASS:
			_on_pass(s, event.stop_index, session)


## Índice del punto cuyo evento (salida, llegada o paso) está pendiente, o -1 si no hay.
func next_pending_index(s: Service) -> int:
	var ev: Dictionary = _next_event(s)
	return int(ev.get("index", -1))


## Reprograma el evento pendiente del servicio si su hora estimada ha cambiado.
func reschedule(s: Service, session: SimulationSession) -> void:
	var ev: Dictionary = _next_event(s)
	var cur: SimEvent = _pending.get(s.id)
	if ev.is_empty():
		if cur != null:
			cur.cancelled = true
			_pending.erase(s.id)
		return
	if cur != null and not cur.cancelled and cur.type == ev["type"] and cur.time == ev["time"] \
			and cur.stop_index == ev["index"]:
		return
	_push(session, ev["type"], ev["time"], s, ev["index"])


func _push(session: SimulationSession, type: StringName, time: int, s: Service, index: int) -> void:
	var old: SimEvent = _pending.get(s.id)
	if old != null:
		old.cancelled = true
	_pending[s.id] = session.queue.push(type, time, s.id, index)


## Próximo evento de movimiento según el estado actual del servicio ({} si no tiene).
func _next_event(s: Service) -> Dictionary:
	var n: int = s.stops.size()
	if n < 2 or s.stops[0].est_dep == SimTime.NONE:
		return {}
	var last: int = -1
	for i: int in n:
		if s.stops[i].status != Enums.StopStatus.PENDING:
			last = i
	match s.status:
		Enums.ServiceStatus.SCHEDULED:
			return {"type": SimEventType.SERVICE_DEPARTURE, "time": s.stops[0].est_dep, "index": 0}
		Enums.ServiceStatus.STOPPED_AT_STATION:
			return {"type": SimEventType.SERVICE_DEPARTURE, "time": s.stops[last].est_dep, "index": last}
		Enums.ServiceStatus.RUNNING:
			var j: int = last + 1
			if last < 0 or j >= n:
				return {}
			var type: StringName = SimEventType.SERVICE_PASS if s.stops[j].stop_type == Enums.StopType.PASS \
					else SimEventType.SERVICE_ARRIVAL
			return {"type": type, "time": s.stops[j].est_arr, "index": j}
	return {}


func _on_departure(s: Service, i: int, session: SimulationSession) -> void:
	var now: int = session.clock.now
	var st: ServiceStop = s.stops[i]
	st.act_dep = now
	st.status = Enums.StopStatus.DEPARTED
	s.status = Enums.ServiceStatus.RUNNING
	_emit(session, s, i, &"DEPARTURE", SimEventType.SERVICE_DEPARTURE)
	_schedule_next(s, i + 1, session)


func _on_arrival(s: Service, i: int, session: SimulationSession) -> void:
	var now: int = session.clock.now
	var st: ServiceStop = s.stops[i]
	st.act_arr = now
	st.status = Enums.StopStatus.ARRIVED
	_emit(session, s, i, &"ARRIVAL", SimEventType.SERVICE_ARRIVAL)
	if i == s.stops.size() - 1 or st.stop_type == Enums.StopType.DESTINATION:
		s.status = Enums.ServiceStatus.TERMINATED
		session.service_updated.emit(s.id)
		session.propagate_delays(s.id)
		return
	s.status = Enums.ServiceStatus.STOPPED_AT_STATION
	var before: int = st.est_dep
	st.est_dep = maxi(before, maxi(st.sched_dep, now + st.min_dwell_s))
	_push(session, SimEventType.SERVICE_DEPARTURE, st.est_dep, s, i)
	session.service_updated.emit(s.id)
	if st.est_dep != before:
		session.propagate_delays(s.id)


func _on_pass(s: Service, i: int, session: SimulationSession) -> void:
	var now: int = session.clock.now
	var st: ServiceStop = s.stops[i]
	st.act_arr = now
	st.act_dep = now
	st.status = Enums.StopStatus.PASSED
	_emit(session, s, i, &"PASS", SimEventType.SERVICE_PASS)
	_schedule_next(s, i + 1, session)


## Programa la llegada o el paso por el punto `j` a su hora estimada.
func _schedule_next(s: Service, j: int, session: SimulationSession) -> void:
	var nxt: ServiceStop = s.stops[j]
	var type: StringName = SimEventType.SERVICE_PASS if nxt.stop_type == Enums.StopType.PASS \
			else SimEventType.SERVICE_ARRIVAL
	_push(session, type, nxt.est_arr, s, j)
	session.service_updated.emit(s.id)


func _emit(session: SimulationSession, s: Service, i: int, kind: StringName, log_type: StringName) -> void:
	session.log.add(session.clock.now, log_type, s.id, i)
	session.service_stop_event.emit(s.id, i, kind)
