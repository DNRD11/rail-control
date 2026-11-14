class_name OperationsPresenter
extends RefCounted
## Traduce la sesión de simulación a modelos de presentación (esquema, detalle, avisos, recursos).
## Solo LEE de la sesión (consultas); la UI emite comandos por el SimulationHost. Sin lógica de simulación.

const MIN_NOTICE_LEVELS: Array[StringName] = [DelayInfo.LEVEL_MINOR, DelayInfo.LEVEL_MAJOR, DelayInfo.LEVEL_SEVERE]

var session: SimulationSession
var host: SimulationHost

var _world: World
var _list: Array[SchematicService] = []
var _by_code: Dictionary[String, SchematicService] = {}
var _id_of: Dictionary[String, StringName] = {}


func setup(p_session: SimulationSession, p_host: SimulationHost) -> void:
	session = p_session
	host = p_host
	_world = p_session.world
	_list.clear()
	_by_code.clear()
	_id_of.clear()
	for sid: StringName in session.service_ids():
		var service: Service = _world.services[sid]
		var item := SchematicService.new()
		item.code = service.code
		item.active = false
		_list.append(item)
		_by_code[service.code] = item
		_id_of[service.code] = sid


func service_id_of(code: String) -> StringName:
	return _id_of.get(code, &"")


func services() -> Array[SchematicService]:
	return _list


func stations() -> Array[SchematicStation]:
	var out: Array[SchematicStation] = []
	for line: Line in _world.lines.values():
		for sid: StringName in line.station_ids:
			var st: Station = _world.stations[sid]
			out.append(SchematicStation.make(st.code, _station_label(st), st.km))
		break
	return out


func _station_label(st: Station) -> String:
	return st.schematic_label if not st.schematic_label.is_empty() else st.name


func clock_text() -> String:
	return SimTime.format(session.clock.now, true)


# --- Esquema -----------------------------------------------------------------

## Posición interpolada (cada fotograma). `fraction` = resto del paso de simulación en curso.
func update_positions(fraction: float) -> void:
	var t: float = float(session.clock.now) + fraction
	for code: String in _by_code:
		var item: SchematicService = _by_code[code]
		if not item.active:
			continue
		var pos: ServicePosition = session.query_service_position_at(_id_of[code], t)
		var sched: ServicePosition = session.query_scheduled_position(_id_of[code], t)
		if pos != null:
			item.km = pos.km
			item.direction = 1 if pos.direction == Enums.Direction.ASCENDING else -1
		if sched != null:
			item.scheduled_km = sched.km


## Estado, retraso y cadena (al cambiar la simulación, no cada fotograma).
func update_state() -> void:
	for code: String in _by_code:
		var item: SchematicService = _by_code[code]
		var sid: StringName = _id_of[code]
		var service: Service = _world.services[sid]
		item.active = _is_running(service.status)
		if not item.active:
			continue
		var info: DelayInfo = session.delay_info(sid)
		item.delay_min = _minutes(info.seconds)
		item.state = _state_for(info.level)
		item.broken = service.status == Enums.ServiceStatus.HELD
		if item.broken:
			item.state = RcTokens.State.ALERT
		_apply_chain(item, sid)


func _apply_chain(item: SchematicService, sid: StringName) -> void:
	item.chain_km = -1.0
	item.chain_label = ""
	for link: ChainLink in session.query_service_chain(sid):
		if not link.is_material or link.next_service_id == &"":
			continue
		var station: Station = _world.stations.get(link.station_id)
		var next: Service = _world.services.get(link.next_service_id)
		if station == null or next == null:
			continue
		item.chain_km = station.km
		var text: String = "%s · sale %s" % [next.code, SimTime.format(link.next_departure)]
		if link.predicted_delay_s > DelayInfo.MINOR_MAX_S:
			text += " +%d′" % _minutes(link.predicted_delay_s)
		item.chain_label = text
		return


func eta_for(code: String) -> Array:
	var sid: StringName = _id_of.get(code, &"")
	if sid == &"":
		return ["", "", RcTokens.State.IDLE]
	var summary: ServiceSummary = session.query_service_summary(sid)
	var station: Station = _world.stations.get(summary.next_stop_station_id)
	if station == null:
		return ["", "", RcTokens.State.IDLE]
	var info: DelayInfo = session.delay_info(sid)
	var text: String = SimTime.format(summary.next_stop_eta)
	if _minutes(info.seconds) > 0 and info.level != DelayInfo.LEVEL_ON_TIME:
		text += " · +%d′" % _minutes(info.seconds)
	return [station.code, text, _state_for(info.level)]


# --- Avisos y resumen --------------------------------------------------------

## Retrasos >= leve (en curso o previstos por propagación). Más grave primero.
func notices() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for code: String in _by_code:
		var sid: StringName = _id_of[code]
		var service: Service = _world.services[sid]
		if service.status == Enums.ServiceStatus.TERMINATED or service.status == Enums.ServiceStatus.CANCELLED:
			continue
		var info: DelayInfo = session.delay_info(sid)
		if not MIN_NOTICE_LEVELS.has(info.level):
			continue
		var minutes: int = _minutes(info.seconds)
		rows.append({
			"code": code, "seconds": info.seconds, "state": _state_for(info.level),
			"chip": "+%d′" % minutes, "title": "Servicio %s" % code,
			"detail": cause_text(info, service)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["seconds"]) > int(b["seconds"]))
	return rows


func summary() -> Dictionary:
	var out: Dictionary = {"running": 0, "total": _list.size(), "ontime": 0, "minor": 0, "major": 0}
	for code: String in _by_code:
		var sid: StringName = _id_of[code]
		if not _is_running((_world.services[sid] as Service).status):
			continue
		out["running"] += 1
		match session.delay_info(sid).level:
			DelayInfo.LEVEL_ON_TIME:
				out["ontime"] += 1
			DelayInfo.LEVEL_MINOR:
				out["minor"] += 1
			_:
				out["major"] += 1
	return out


## Texto español de la causa vigente: «+10′ previstos por rotación de material (3103)».
func cause_text(info: DelayInfo, service: Service) -> String:
	var minutes: int = _minutes(info.seconds)
	var planned: bool = service.status == Enums.ServiceStatus.SCHEDULED or service.status == Enums.ServiceStatus.BOARDING
	var amount: String = "+%d′ %s" % [minutes, "previstos" if planned else "de retraso"]
	var source: Service = _world.services.get(info.source_service_id)
	var source_code: String = source.code if source != null else ""
	match info.cause:
		DelayInfo.CAUSE_ROTATION_MATERIAL:
			return "%s por rotación de material (%s)" % [amount, source_code]
		DelayInfo.CAUSE_ROTATION_STAFF:
			return "%s por rotación de personal (%s)" % [amount, source_code]
		DelayInfo.CAUSE_INJECTED:
			return "%s por retraso en ruta" % amount
	return "%s sobre horario" % amount if minutes > 0 else "Circula según horario"


# --- Detalle -----------------------------------------------------------------

func detail(code: String) -> Dictionary:
	var sid: StringName = _id_of.get(code, &"")
	if sid == &"":
		return {}
	var service: Service = _world.services[sid]
	var info: DelayInfo = session.delay_info(sid)
	var summary: ServiceSummary = session.query_service_summary(sid)
	var status: Array = _status_for(service, info)
	var delayed: bool = info.level != DelayInfo.LEVEL_ON_TIME
	return {
		"code": code, "route": _route_text(service), "status": status[0], "state": status[1],
		"delay": ("+%d′" % _minutes(info.seconds)) if delayed else "0′",
		"note": cause_text(info, service) if delayed else _idle_note(service),
		"stops": _stop_rows(service), "resources": _resource_rows(sid),
		"passengers": "%d / %d" % [summary.booked, summary.seats],
	}


## «Madrid → Zaragoza» con las etiquetas cortas de estación (el panel es estrecho).
func _route_text(service: Service) -> String:
	var origin: Station = _world.stations.get(service.origin_station_id)
	var dest: Station = _world.stations.get(service.destination_station_id)
	if origin == null or dest == null:
		return ""
	return "%s → %s" % [_station_label(origin), _station_label(dest)]


func _idle_note(service: Service) -> String:
	match service.status:
		Enums.ServiceStatus.SCHEDULED:
			return "Sale a las %s" % SimTime.format(service.scheduled_departure())
		Enums.ServiceStatus.TERMINATED:
			return "Servicio finalizado"
	return "Circula según horario"


func _status_for(service: Service, info: DelayInfo) -> Array:
	var delayed: Array = _delay_chip(info.level)
	match service.status:
		Enums.ServiceStatus.HELD:
			return ["RETENIDO", RcTokens.State.ALERT]
		Enums.ServiceStatus.CANCELLED:
			return ["CANCELADO", RcTokens.State.ALERT]
		Enums.ServiceStatus.TERMINATED:
			return ["FINALIZADO", RcTokens.State.IDLE]
		Enums.ServiceStatus.SCHEDULED, Enums.ServiceStatus.BOARDING:
			if info.level == DelayInfo.LEVEL_ON_TIME:
				return ["PROGRAMADO", RcTokens.State.IDLE]
			return [("%s PREVISTO" % delayed[0]) as String, delayed[1]]
	return delayed


func _delay_chip(level: StringName) -> Array:
	match level:
		DelayInfo.LEVEL_MINOR:
			return ["RETRASO", RcTokens.State.WARN]
		DelayInfo.LEVEL_MAJOR, DelayInfo.LEVEL_SEVERE:
			return ["RETRASO GRAVE", RcTokens.State.ALERT]
	return ["EN HORA", RcTokens.State.OK]


## Paradas comerciales: [código, nombre, programada, estimada o real, done | next | pending].
func _stop_rows(service: Service) -> Array:
	var rows: Array = []
	var next_marked: bool = false
	for stop: ServiceStop in service.stops:
		if not stop.is_stopping():
			continue
		var station: Station = _world.stations.get(stop.station_id)
		var done: bool = stop.status == Enums.StopStatus.ARRIVED or stop.status == Enums.StopStatus.DEPARTED
		var kind: String = "done" if done else "pending"
		if not done and not next_marked:
			kind = "next"
			next_marked = true
		var actual: int = stop.act_arr if stop.act_arr != SimTime.NONE else stop.act_dep
		var est: int = stop.est_arr if stop.est_arr != SimTime.NONE else stop.est_dep
		var shown: int = actual if (done and actual != SimTime.NONE) else (est if est != SimTime.NONE else stop.entry_time())
		rows.append([station.code if station != null else "?", _station_label(station) if station != null else "",
				SimTime.format(stop.entry_time()), SimTime.format(shown), kind])
	return rows


## [tipo, etiqueta, tramo (solo si hay relevos), es_actual].
func _resource_rows(sid: StringName) -> Array:
	var slots: Array[ResourceSlot] = session.query_service_resources(sid)
	var counts: Dictionary[int, int] = {}
	for slot: ResourceSlot in slots:
		counts[slot.resource_type] = int(counts.get(slot.resource_type, 0)) + 1
	var rows: Array = []
	for slot: ResourceSlot in slots:
		var leg: String = ""
		if int(counts[slot.resource_type]) > 1:
			leg = "%s–%s" % [_code_of(slot.from_station_id), _code_of(slot.to_station_id)]
		rows.append([_type_name(slot.resource_type), slot.label, leg, slot.is_current])
	return rows


func _type_name(type: Enums.ResourceType) -> String:
	match type:
		Enums.ResourceType.COMPOSITION:
			return "Composición"
		Enums.ResourceType.VEHICLE:
			return "Vehículo"
		Enums.ResourceType.DRIVER:
			return "Maquinista"
	return "Interventor"


func _code_of(station_id: StringName) -> String:
	var st: Station = _world.stations.get(station_id)
	return st.code if st != null else "?"


# --- Franja de recursos -------------------------------------------------------

## Items [título, valor, sufijo] y nota (siguiente salida pendiente).
func resource_strip() -> Dictionary:
	var used: Dictionary[int, int] = {}
	var total: Dictionary[int, int] = {}
	var reserve: Array[String] = []
	var failed: int = 0
	var next_dep: int = SimTime.NONE
	var next_text: String = ""
	for rs: ResourceState in session.query_resource_states():
		var key: int = rs.resource_type
		if rs.state == ResourceState.State.RESERVE:
			var where: String = (" (%s)" % _code_of(rs.station_id)) if rs.station_id != &"" else ""
			reserve.append(rs.label + where)
			continue
		total[key] = int(total.get(key, 0)) + 1
		if rs.state == ResourceState.State.IN_SERVICE:
			used[key] = int(used.get(key, 0)) + 1
		elif rs.state == ResourceState.State.FAILED:
			failed += 1
		elif rs.resource_type == Enums.ResourceType.COMPOSITION and rs.next_departure != SimTime.NONE 				and (next_dep == SimTime.NONE or rs.next_departure < next_dep):
			var next: Service = _world.services.get(rs.next_service_id)
			next_dep = rs.next_departure
			next_text = "Siguiente salida: %s · %s" % [next.code if next != null else "?", SimTime.format(next_dep)]
	var items: Array[Array] = []
	var types: Array[Array] = [["Material", Enums.ResourceType.COMPOSITION], ["Maquinistas", Enums.ResourceType.DRIVER],
			["Interventores", Enums.ResourceType.CONDUCTOR]]
	for entry: Array in types:
		var key: int = entry[1]
		items.append([entry[0], "%d/%d" % [int(used.get(key, 0)), int(total.get(key, 0))], "en servicio" if key == Enums.ResourceType.COMPOSITION else ""])
	if not reserve.is_empty():
		items.insert(1, ["Reserva", ", ".join(reserve), ""])
	if failed > 0:
		items.append(["Averiados", str(failed), ""])
	return {"items": items, "note": next_text}


# --- Utilidades ---------------------------------------------------------------

func _is_running(status: Enums.ServiceStatus) -> bool:
	return status == Enums.ServiceStatus.RUNNING or status == Enums.ServiceStatus.STOPPED_AT_STATION \
			or status == Enums.ServiceStatus.HELD


func _state_for(level: StringName) -> RcTokens.State:
	match level:
		DelayInfo.LEVEL_MINOR:
			return RcTokens.State.WARN
		DelayInfo.LEVEL_MAJOR, DelayInfo.LEVEL_SEVERE:
			return RcTokens.State.ALERT
	return RcTokens.State.OK


func _minutes(seconds: int) -> int:
	return int(roundf(float(seconds) / 60.0))
