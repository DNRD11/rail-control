class_name EconomySystem
extends SimSystem
## Libro de la jornada (ECONOMY.md §1, §8). No consume eventos: reacciona a los cambios que publica la sesión.
## - Al terminar o cancelarse un servicio lo liquida: ingresos, explotación, personal, canon e indemnizaciones.
## - Al decidirse una incidencia vuelca `Decision.cost_lines` con ref INCIDENT.
## Todo en céntimos enteros y determinista: solo depende de las horas reales y de las reglas de datos.
## Mecánica del simulador inspirada en la realidad; no reproduce tarifas ni compromisos reales.

signal entry_added(entry: LedgerEntry)

var ledger: Ledger = Ledger.new()
## Ingresos no cobrados por viajeros no transportados (informativo; no es un apunte del libro).
var lost_revenue_cents: int = 0
## Viajeros con indemnización ya liquidada.
var compensated_pax: int = 0

var _settled: Dictionary[StringName, bool] = {}
var _booked_decisions: Dictionary[StringName, bool] = {}


func on_service_updated(service_id: StringName, session: SimulationSession) -> void:
	if _settled.has(service_id):
		return
	var s: Service = session.world.services.get(service_id) as Service
	if s == null or s.stops.size() < 2:
		return
	if s.status == Enums.ServiceStatus.TERMINATED or s.is_cancelled():
		_settled[service_id] = true
		_settle(s, session)


func on_incident_changed(incident_id: StringName, session: SimulationSession) -> void:
	var inc: Incident = session.incidents.get_incident(incident_id)
	if inc == null or inc.decision == null or _booked_decisions.has(inc.decision.id):
		return
	_booked_decisions[inc.decision.id] = true
	for line: Dictionary in inc.decision.cost_lines:
		_add(inc.decision.time, StringName(String(line["category"])), int(line["amount_cents"]),
				LedgerCategory.REF_INCIDENT, inc.id, StringName("incident_%s" % line["key"]),
				{"option": String(inc.decision.option_type), "service": String(inc.service_id)})


## Cierre de jornada: los servicios que no han terminado se liquidan con sus horas estimadas (como si
## terminaran con ese retraso), para que ingresos, costes e indemnizaciones no se pierdan.
func on_day_end(session: SimulationSession) -> void:
	for sid: StringName in session.service_ids():
		var s: Service = session.world.services[sid]
		if _settled.has(sid) or s.kind != Enums.ServiceKind.COMMERCIAL or s.stops.size() < 2:
			continue
		if s.status == Enums.ServiceStatus.SCHEDULED and s.scheduled_departure() >= session.clock.day_end:
			continue
		_settled[sid] = true
		_settle(s, session, true)


func _settle(s: Service, session: SimulationSession, closing: bool = false) -> void:
	var world: World = session.world
	var rules: EconomyRules = world.economy_rules
	var now: int = session.clock.now
	var last: int = s.stops.size() - 1 if closing else SessionQueries.last_reached(s)
	var o: PassengerOutcome = PassengerCalc.outcome(world, s)
	if closing:
		o.carried = o.booked - o.needing_alternative
	var fare: int = EconomyCalc.fare_total_cents(world, s)
	var details: Dictionary = {"service": s.code, "status": Enums.name_of(Enums.ServiceStatus, s.status)}
	_add(now, LedgerCategory.REVENUE, EconomyCalc.share_cents(fare, o.carried, o.booked),
			LedgerCategory.REF_SERVICE, s.id, &"fare_revenue", details)
	lost_revenue_cents += EconomyCalc.share_cents(fare, o.needing_alternative, o.booked)
	var vehicle_km: float = EconomyCalc.vehicle_km(world, s, last)
	_add(now, LedgerCategory.OPERATING_COST, -roundi(vehicle_km * float(rules.operating_cost_per_vehicle_km_cents)),
			LedgerCategory.REF_SERVICE, s.id, &"operating_cost", details)
	_add(now, LedgerCategory.STAFF_COST, -EconomyCalc.staff_cost_cents(world, s, last),
			LedgerCategory.REF_SERVICE, s.id, &"staff_cost", details)
	var km: float = EconomyCalc.km_between(world, s, 0, last)
	_add(now, LedgerCategory.INFRA_CHARGE_ORDINARY, -roundi(km * float(rules.infra_charge_per_km_cents)),
			LedgerCategory.REF_SERVICE, s.id, &"infra_charge_ordinary", details)
	var comp: Dictionary = details.duplicate()
	comp["incident"] = String(s.incident_ids[s.incident_ids.size() - 1]) if not s.incident_ids.is_empty() else ""
	comp["eligible"] = o.compensation_eligible
	comp["cancelled_pax"] = o.needing_alternative
	_add(now, LedgerCategory.COMPENSATION, -EconomyCalc.share_cents(fare, o.compensation_pax_pct, o.booked, 1),
			LedgerCategory.REF_SERVICE, s.id, &"passenger_compensation", comp)
	compensated_pax += o.compensation_eligible


func _add(time: int, category: StringName, amount: int, ref_type: StringName, ref_id: StringName,
		key: StringName, details: Dictionary) -> void:
	var e: LedgerEntry = ledger.add(time, category, amount, ref_type, ref_id, key, details)
	if e != null:
		entry_added.emit(e)
