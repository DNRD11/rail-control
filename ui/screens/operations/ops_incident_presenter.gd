class_name OpsIncidentPresenter
extends RefCounted
## Traduce incidencias de la sesión a modelos de presentación (tarjetas, historial, hoja de decisión).
## Solo LEE de la sesión; la decisión se emite como ResolveIncidentCommand desde la pantalla.

const TITLES: Dictionary[StringName, String] = {
	OptionType.WAIT_REPAIR: "Esperar reparación",
	OptionType.SUBSTITUTE_ROLLING_STOCK: "Sustituir material",
	OptionType.CANCEL_SERVICE: "Cancelar servicio",
}
const BLURBS: Dictionary[StringName, String] = {
	OptionType.WAIT_REPAIR: "El servicio sigue detenido mientras se repara el material en la vía.",
	OptionType.SUBSTITUTE_ROLLING_STOCK: "El material de reserva acude, se traslada a los viajeros y el servicio continúa.",
	OptionType.CANCEL_SERVICE: "Se cancela el servicio; los viajeros necesitan una alternativa de transporte.",
}

var session: SimulationSession

var _world: World


func setup(p_session: SimulationSession) -> void:
	session = p_session
	_world = p_session.world


func awaiting_count() -> int:
	var n: int = 0
	for inc: Incident in session.open_incidents():
		if inc.status == Enums.IncidentStatus.AWAITING_DECISION:
			n += 1
	return n


func open_count() -> int:
	return session.open_incidents().size()


# --- Tarjetas e historial ----------------------------------------------------------

## [{id, key, state, chip, title, detail, time, actionable}] de las incidencias abiertas.
func open_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inc: Incident in session.open_incidents():
		var awaiting: bool = inc.status == Enums.IncidentStatus.AWAITING_DECISION
		var detail: String = where_text(inc)
		if awaiting:
			detail += "\nDecisión automática en %s" % RcFormat.mmss(seconds_left(inc))
		elif inc.decision != null:
			detail += "\nDecisión: %s" % TITLES.get(inc.decision.option_type, "")
		out.append({
			"id": inc.id, "key": "%s|%d" % [inc.id, inc.status],
			"state": RcTokens.State.ALERT if awaiting else RcTokens.State.WARN,
			"chip": "AVERÍA" if awaiting else "EN CURSO",
			"title": "Servicio %s" % service_code(inc), "detail": detail,
			"time": SimTime.format(inc.detected_at), "actionable": awaiting})
	return out


## [{id, title, detail, state}] de las incidencias resueltas, la más reciente primero.
func history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for inc: Incident in session.all_incidents():
		if inc.is_open() or inc.decision == null:
			continue
		var who: String = "automática" if inc.decision.automatic else "decidida por ti"
		var cost: int = -inc.decision.total_cost_cents()
		out.append({
			"id": inc.id, "state": RcTokens.State.IDLE, "time": SimTime.format(inc.resolved_at),
			"title": "%s · %s" % [service_code(inc), TITLES.get(inc.decision.option_type, "")],
			"detail": "%s · coste %s" % [who, RcFormat.eur(cost)]})
	out.reverse()
	return out


# --- Hoja de decisión --------------------------------------------------------------

## Modelo completo de la hoja; recalcula las previsualizaciones a la hora actual.
func sheet_model(incident_id: StringName) -> Dictionary:
	var inc: Incident = session.query_incident_fresh(incident_id)
	if inc == null:
		return {}
	var service: Service = _world.services[inc.service_id]
	var total: int = _world.incident_rules.decision_timeout_s
	var default_type: StringName = _world.incident_rules.default_option
	var cards: Array[Dictionary] = []
	for opt: DecisionOption in inc.options:
		cards.append(_card(inc, opt))
	return {
		"id": inc.id, "awaiting": inc.status == Enums.IncidentStatus.AWAITING_DECISION,
		"title": _incident_title(inc), "service": "Servicio %s" % service.code,
		"when": SimTime.format(inc.detected_at), "where": where_text(inc),
		"aboard": RcFormat.count(PassengerCalc.aboard(_world, inc.service_id, inc.stop_index)),
		"repair": "%d–%d′" % [RcFormat.minutes(inc.repair_min_s), RcFormat.minutes(inc.repair_max_s)],
		"seconds_left": seconds_left(inc), "total_s": total,
		"deadline": SimTime.format(inc.detected_at + total), "default_title": TITLES.get(default_type, ""),
		"cards": cards, "inform": inform_model(inc.service_id),
	}


func _incident_title(inc: Incident) -> String:
	var type: IncidentType = _world.incident_rules.types.get(inc.type_id)
	return type.title if type != null else "Incidencia"


func _card(inc: Incident, opt: DecisionOption) -> Dictionary:
	var p: OptionPreview = opt.preview
	var model: Dictionary = {
		"option_type": opt.option_type, "title": TITLES.get(opt.option_type, String(opt.option_type)),
		"blurb": BLURBS.get(opt.option_type, ""), "available": opt.available, "reason": opt.unavailable_reason,
		"button_text": TITLES.get(opt.option_type, "Confirmar"), "danger": opt.option_type == OptionType.CANCEL_SERVICE,
		"dependents_title": "Servicios afectados", "dependents": [], "dependents_more": 0, "flags": [], "note": "",
	}
	if not opt.available:
		return model
	var cancel: bool = opt.option_type == OptionType.CANCEL_SERVICE
	var metrics: Array[Dictionary] = []
	if cancel:
		metrics.append({"label": "Retraso propio", "value": "Cancelado", "state": RcTokens.State.ALERT})
	else:
		metrics.append({"label": "Retraso propio", "value": RcFormat.delay_range(p.own_delay_min_s, p.own_delay_max_s),
				"state": _level_state(p.own_delay_max_s)})
	metrics.append({"label": "Viajeros afectados", "value": RcFormat.count(p.affected_passengers), "state": -1})
	metrics.append({"label": "Coste estimado", "value": RcFormat.eur(p.cost_cents), "state": -1})
	metrics.append({"label": "Reanudación", "value": _resume_text(inc, opt), "state": -1})
	model["metrics"] = metrics
	if cancel:
		_fill_cancel(model, inc, p)
	else:
		_fill_dependents(model, p.dependents)
	if p.seats_short > 0:
		(model["flags"] as Array).append({"text": "Faltan %d plazas" % p.seats_short, "state": RcTokens.State.WARN})
	if p.reserve_vehicle_id != &"" and not cancel:
		model["note"] = "Material de reserva %s, desde %s." % [_vehicle_label(p.reserve_vehicle_id), _reserve_origin(p.reserve_vehicle_id)]
	return model


func _fill_dependents(model: Dictionary, dependents: Array[Dictionary]) -> void:
	var rows: Array[Dictionary] = []
	for d: Dictionary in dependents:
		var service: Service = _world.services.get(d["service_id"])
		rows.append({"code": service.code if service != null else "?",
				"text": RcFormat.delay_range(int(d["delay_min_s"]), int(d["delay_max_s"])),
				"state": _level_state(int(d["delay_max_s"]))})
	_set_rows(model, rows)


func _fill_cancel(model: Dictionary, inc: Incident, p: OptionPreview) -> void:
	model["dependents_title"] = "Servicios cancelados"
	var rows: Array[Dictionary] = []
	for sid: StringName in p.cancelled_service_ids:
		var service: Service = _world.services.get(sid)
		rows.append({"code": service.code if service != null else "?", "text": "cancelado", "state": RcTokens.State.ALERT})
	_set_rows(model, rows)
	(model["flags"] as Array).append({"text": "%d necesitan alternativa" % p.needing_alternative,
			"state": RcTokens.State.SPECIAL})
	if p.reserve_vehicle_id != &"":
		model["note"] = "Material de reserva %s cubre el resto de la rotación." % _vehicle_label(p.reserve_vehicle_id)
	elif p.cancelled_service_ids.size() > 1:
		model["note"] = "Sin reserva que cubra la rotación: también se cancelan los servicios siguientes del material."


func _set_rows(model: Dictionary, rows: Array[Dictionary]) -> void:
	var shown: Array[Dictionary] = []
	for i: int in mini(rows.size(), RcDecisionCard.DEPENDENTS_ROWS):
		shown.append(rows[i])
	model["dependents"] = shown
	model["dependents_more"] = maxi(rows.size() - shown.size(), 0)


func _resume_text(inc: Incident, opt: DecisionOption) -> String:
	match opt.option_type:
		OptionType.WAIT_REPAIR:
			return "%s–%s" % [SimTime.format(inc.detected_at + inc.repair_min_s),
					SimTime.format(inc.detected_at + inc.repair_max_s)]
		OptionType.SUBSTITUTE_ROLLING_STOCK:
			return SimTime.format(opt.preview.resume_at) if opt.preview.resume_at != SimTime.NONE else "—"
	return "—"


# --- Información al viajero --------------------------------------------------------

## Estado de «Informar a los viajeros» de un servicio:
## {visible, informed, available, incident_id, service_id, text}. Solo lee la sesión.
func inform_model(service_id: StringName) -> Dictionary:
	var out: Dictionary = {"visible": false, "informed": false, "available": false, "incident_id": &"",
			"service_id": service_id, "text": ""}
	var load: ServicePassengerLoad = session.query_service_passengers(service_id)
	if load == null:
		return out
	var inc: Incident = _incident_for(service_id)
	if load.informed:
		out["visible"] = true
		out["informed"] = true
		out["text"] = "Viajeros informados a las %s" % SimTime.format(load.last_info_time)
		return out
	if inc == null or (load.affected <= 0 and inc.service_id != service_id):
		return out
	out["visible"] = true
	out["available"] = true
	out["incident_id"] = inc.id
	out["text"] = "%s viajeros afectados sin informar" % RcFormat.count(load.affected) if load.affected > 0 \
			else "Los viajeros aún no han recibido aviso"
	return out


## Incidencia que justifica informar: la del propio servicio o, si no, la abierta más reciente.
func _incident_for(service_id: StringName) -> Incident:
	var found: Incident = null
	for inc: Incident in session.all_incidents():
		if inc.service_id == service_id:
			found = inc
	if found != null:
		return found
	var open: Array[Incident] = session.open_incidents()
	return open[open.size() - 1] if not open.is_empty() else null


# --- Utilidades --------------------------------------------------------------------

func seconds_left(inc: Incident) -> int:
	return maxi(inc.detected_at + _world.incident_rules.decision_timeout_s - session.clock.now, 0)


func service_code(inc: Incident) -> String:
	var service: Service = _world.services.get(inc.service_id)
	return service.code if service != null else "?"


func where_text(inc: Incident) -> String:
	if inc.station_id != &"":
		return "En %s" % _station_name(inc.station_id)
	var section: Section = _world.sections.get(inc.section_id)
	if section == null:
		return "En ruta"
	return "Entre %s y %s" % [_station_name(section.from_station_id), _station_name(section.to_station_id)]


func _station_name(station_id: StringName) -> String:
	var st: Station = _world.stations.get(station_id)
	if st == null:
		return "?"
	return st.schematic_label if not st.schematic_label.is_empty() else st.name


func _vehicle_label(vehicle_id: StringName) -> String:
	var v: Vehicle = _world.vehicles.get(vehicle_id)
	return str(v.number) if v != null else "?"


func _reserve_origin(vehicle_id: StringName) -> String:
	var v: Vehicle = _world.vehicles.get(vehicle_id)
	return _station_name(v.location_station_id) if v != null else "?"


func _level_state(delay_s: int) -> RcTokens.State:
	match DelayInfo.level_for(delay_s):
		DelayInfo.LEVEL_MINOR:
			return RcTokens.State.WARN
		DelayInfo.LEVEL_MAJOR, DelayInfo.LEVEL_SEVERE:
			return RcTokens.State.ALERT
	return RcTokens.State.OK
