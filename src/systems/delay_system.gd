class_name DelaySystem
extends SimSystem
## Retrasos: aplica DELAY_APPLIED a un servicio, desplaza sus horas estimadas (est_*) y propaga el efecto
## por el grafo de rotaciones (material y personal). Es predicción: los hechos reales (act_*) los
## registra MovementSystem cuando ocurren. Ver SIMULATION.md §5.
##
## Reglas (deterministas, enteras):
## - El retraso se suma a la hora estimada del próximo punto pendiente (llegada, o salida si está detenido).
## - Hacia delante, cada parada recupera tiempo recortando la espera hasta min_dwell_s:
##   est_dep = max(sched_dep, est_arr + min_dwell_s).
## - En marcha, opcionalmente recupera `recovery_pct` % del tiempo de recorrido programado de cada tramo
##   (data.recovery_pct del evento; por defecto 0), sin superar el retraso acumulado.
## - Rotación: para cada arista A->B, ready_B = llegada(A, fin de asignación) + min_connection_s; si
##   ready_B > salida estimada de B en el punto de relevo y B no ha salido de él, B hereda el retraso.

var _cause: Dictionary[StringName, DelayInfo] = {}


func handles(type: StringName) -> bool:
	return type == SimEventType.DELAY_APPLIED


func handle(event: SimEvent, session: SimulationSession) -> void:
	var s: Service = session.world.services.get(event.service_id) as Service
	var cause: StringName = StringName(event.data.get("cause", DelayInfo.CAUSE_INJECTED))
	var pct: int = clampi(int(event.data.get("recovery_pct", 0)), 0, 100)
	apply_delay(s, int(event.data.get("seconds", 0)), cause, session, pct)


## Suma un retraso al servicio (lo usan DELAY_APPLIED y las incidencias). False si no se pudo aplicar.
func apply_delay(s: Service, seconds: int, cause: StringName, session: SimulationSession, pct: int = 0) -> bool:
	if s == null or s.status == Enums.ServiceStatus.TERMINATED or s.is_cancelled() or seconds <= 0:
		return false
	var idx: int = session.movement.next_pending_index(s)
	if not _shift(s, seconds, pct):
		return false
	_mark(s.id, cause, s.id, &"")
	session.log.add(session.clock.now, SimEventType.DELAY_APPLIED, s.id, idx,
			{"seconds": seconds, "cause": String(cause)})
	session.movement.reschedule(s, session)
	session.service_updated.emit(s.id)
	propagate(s.id, session)
	return true


## Retraso vigente (segundos) y su causa para la UI.
func info_for(s: Service) -> DelayInfo:
	var info: DelayInfo = DelayInfo.new()
	info.service_id = s.id
	info.seconds = seconds_of(s)
	var c: DelayInfo = _cause.get(s.id)
	if c != null and info.seconds > 0:
		info.cause = c.cause
		info.source_service_id = c.source_service_id
		info.resource_id = c.resource_id
	info.level = DelayInfo.level_for(info.seconds)
	return info


## est - programada del próximo punto pendiente, o real - programada del último ocurrido.
static func seconds_of(s: Service) -> int:
	var n: int = s.stops.size()
	if n == 0 or s.is_cancelled():
		return 0
	if s.status == Enums.ServiceStatus.TERMINATED:
		var last: ServiceStop = s.stops[n - 1]
		if last.act_arr == SimTime.NONE or last.entry_time() == SimTime.NONE:
			return 0
		return last.act_arr - last.entry_time()
	var done: int = -1
	for i: int in n:
		if s.stops[i].status != Enums.StopStatus.PENDING:
			done = i
	if done < 0:
		var st0: ServiceStop = s.stops[0]
		return st0.est_dep - st0.exit_time() if st0.est_dep != SimTime.NONE and st0.exit_time() != SimTime.NONE else 0
	var st: ServiceStop = s.stops[done]
	if st.status == Enums.StopStatus.ARRIVED:
		return st.est_dep - st.exit_time() if st.est_dep != SimTime.NONE and st.exit_time() != SimTime.NONE else 0
	if done + 1 >= n:
		return 0
	var nxt: ServiceStop = s.stops[done + 1]
	if nxt.est_arr == SimTime.NONE or nxt.entry_time() == SimTime.NONE:
		return 0
	return nxt.est_arr - nxt.entry_time()


## Recalcula las dependencias aguas abajo de `service_id` hasta que no haya cambios.
func propagate(service_id: StringName, session: SimulationSession) -> void:
	var graph: RotationGraph = session.rotation_graph()
	var affected: Array[StringName] = graph.downstream(service_id)
	if affected.is_empty():
		return
	affected.sort_custom(func(a: StringName, b: StringName) -> bool:
		var da: int = _first_departure(session.world, a)
		var db: int = _first_departure(session.world, b)
		return da < db if da != db else String(a) < String(b))
	var changed: bool = true
	var guard: int = 0
	while changed and guard <= affected.size():
		changed = false
		guard += 1
		for bid: StringName in affected:
			for e: RotationEdge in graph.incoming(bid):
				if _apply_edge(e, session):
					changed = true


func _first_departure(world: World, sid: StringName) -> int:
	var s: Service = world.services.get(sid) as Service
	return s.scheduled_departure() if s != null else 0


## Aplica una arista A->B. True si ha desplazado est_* de B.
func _apply_edge(e: RotationEdge, session: SimulationSession) -> bool:
	var a: Service = session.world.services.get(e.from_service_id) as Service
	var b: Service = session.world.services.get(e.to_service_id) as Service
	if a == null or b == null or a.is_cancelled() \
			or b.status == Enums.ServiceStatus.TERMINATED or b.is_cancelled():
		return false
	if e.from_end_stop >= a.stops.size() or e.to_start_stop >= b.stops.size():
		return false
	var sa: ServiceStop = a.stops[e.from_end_stop]
	var sb: ServiceStop = b.stops[e.to_start_stop]
	if sb.status == Enums.StopStatus.DEPARTED or sb.status == Enums.StopStatus.PASSED:
		return false
	var arrival: int = sa.act_arr if sa.act_arr != SimTime.NONE else sa.est_arr
	if arrival == SimTime.NONE or sb.est_dep == SimTime.NONE:
		return false
	var ready: int = arrival + e.min_connection_s
	if ready <= sb.est_dep:
		return false
	sb.est_dep = ready
	_cascade(b, e.to_start_stop, 0)
	var cause: StringName = DelayInfo.CAUSE_ROTATION_MATERIAL \
			if e.resource_type == Enums.ResourceType.COMPOSITION else DelayInfo.CAUSE_ROTATION_STAFF
	_mark(b.id, cause, a.id, e.resource_id)
	session.log.add(session.clock.now, &"DELAY_PROPAGATED", b.id, e.to_start_stop,
			{"seconds": ready - sb.exit_time(), "cause": String(cause), "source": String(a.id),
			"resource": String(e.resource_id)})
	session.movement.reschedule(b, session)
	session.service_updated.emit(b.id)
	return true


func _mark(service_id: StringName, cause: StringName, source: StringName, resource: StringName) -> void:
	var c: DelayInfo = DelayInfo.new()
	c.service_id = service_id
	c.cause = cause
	c.source_service_id = source
	c.resource_id = resource
	_cause[service_id] = c


## Suma `d` al próximo punto pendiente y recalcula los siguientes. False si no hay punto pendiente.
func _shift(s: Service, d: int, pct: int) -> bool:
	var n: int = s.stops.size()
	var done: int = -1
	for i: int in n:
		if s.stops[i].status != Enums.StopStatus.PENDING:
			done = i
	if s.stops[0].est_dep == SimTime.NONE:
		return false
	if done < 0:
		s.stops[0].est_dep += d
		_cascade(s, 0, pct)
		return true
	var st: ServiceStop = s.stops[done]
	if st.status == Enums.StopStatus.ARRIVED:
		st.est_dep += d
		_cascade(s, done, pct)
		return true
	var j: int = done + 1
	if j >= n:
		return false
	var nxt: ServiceStop = s.stops[j]
	nxt.est_arr += d
	_settle(nxt)
	_cascade(s, j, pct)
	return true


## est_dep del punto a partir de su est_arr (paso: sin espera; parada: respeta min_dwell_s).
func _settle(st: ServiceStop) -> void:
	if st.stop_type == Enums.StopType.PASS:
		st.est_dep = st.est_arr
	elif st.stop_type != Enums.StopType.DESTINATION and st.est_dep != SimTime.NONE:
		st.est_dep = maxi(st.est_dep, st.est_arr + st.min_dwell_s)


## Propaga hacia delante desde la salida estimada del punto k. Solo retrasa (max con lo vigente).
func _cascade(s: Service, k: int, pct: int) -> void:
	for m: int in range(k + 1, s.stops.size()):
		var prev: ServiceStop = s.stops[m - 1]
		var cur: ServiceStop = s.stops[m]
		if cur.status != Enums.StopStatus.PENDING:
			return
		var run: int = cur.entry_time() - prev.exit_time()
		var recov: int = mini(run * pct / 100, maxi(prev.est_dep - prev.exit_time(), 0))
		cur.est_arr = maxi(cur.est_arr, prev.est_dep + run - recov)
		_settle(cur)
