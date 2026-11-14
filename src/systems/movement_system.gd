class_name MovementSystem
extends SimSystem
## Circulación: salidas, llegadas y pasos de los servicios comerciales (SIMULATION.md §4).
## Fase 3: los eventos ocurren a la hora programada. Cada servicio tiene como mucho un evento pendiente.


func start(session: SimulationSession) -> void:
	for sid: StringName in session.world.services:
		var s: Service = session.world.services[sid]
		if s.kind != Enums.ServiceKind.COMMERCIAL or s.stops.size() < 2:
			continue
		for st: ServiceStop in s.stops:
			st.est_arr = st.sched_arr
			st.est_dep = st.sched_dep
		session.queue.push(SimEventType.SERVICE_DEPARTURE, s.stops[0].est_dep, s.id, 0)


func handles(type: StringName) -> bool:
	return type == SimEventType.SERVICE_DEPARTURE or type == SimEventType.SERVICE_ARRIVAL \
			or type == SimEventType.SERVICE_PASS


func handle(event: SimEvent, session: SimulationSession) -> void:
	var s: Service = session.world.services.get(event.service_id) as Service
	if s == null or event.stop_index < 0 or event.stop_index >= s.stops.size():
		return
	match event.type:
		SimEventType.SERVICE_DEPARTURE:
			_on_departure(s, event.stop_index, session)
		SimEventType.SERVICE_ARRIVAL:
			_on_arrival(s, event.stop_index, session)
		SimEventType.SERVICE_PASS:
			_on_pass(s, event.stop_index, session)


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
		return
	s.status = Enums.ServiceStatus.STOPPED_AT_STATION
	st.est_dep = maxi(st.sched_dep, now + st.min_dwell_s)
	session.queue.push(SimEventType.SERVICE_DEPARTURE, st.est_dep, s.id, i)
	session.service_updated.emit(s.id)


func _on_pass(s: Service, i: int, session: SimulationSession) -> void:
	var now: int = session.clock.now
	var st: ServiceStop = s.stops[i]
	st.act_arr = now
	st.act_dep = now
	st.status = Enums.StopStatus.PASSED
	_emit(session, s, i, &"PASS", SimEventType.SERVICE_PASS)
	_schedule_next(s, i + 1, session)


## Programa la llegada o el paso por el punto `j` a su hora estimada (= programada en Fase 3).
func _schedule_next(s: Service, j: int, session: SimulationSession) -> void:
	var nxt: ServiceStop = s.stops[j]
	nxt.est_arr = nxt.sched_arr
	var type: StringName = SimEventType.SERVICE_PASS if nxt.stop_type == Enums.StopType.PASS \
			else SimEventType.SERVICE_ARRIVAL
	session.queue.push(type, nxt.est_arr, s.id, j)
	session.service_updated.emit(s.id)


func _emit(session: SimulationSession, s: Service, i: int, kind: StringName, log_type: StringName) -> void:
	session.log.add(session.clock.now, log_type, s.id, i)
	session.service_stop_event.emit(s.id, i, kind)
