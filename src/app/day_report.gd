class_name DayReport
extends RefCounted
## Informe de fin de jornada. Se construye solo con consultas de lectura de la sesión (ECONOMY.md §5).

var scenario_id: String = ""
var day_start: int = 0
var day_end: int = 0
var finished_at: int = 0
var quality: float = 100.0
var perception: float = 75.0
var result_cents: int = 0
var score: float = 0.0
## A (mejor) - D.
var grade: StringName = &"D"
## Importes por categoría del libro en céntimos (ingresos > 0, costes < 0).
var ledger_by_category: Dictionary[StringName, int] = {}
var revenue_cents: int = 0
var cost_cents: int = 0
var passengers_carried: int = 0
var passengers_affected: int = 0
var passengers_compensated: int = 0
var passengers_needing_alternative: int = 0
## [{service_id, code, route, status, delay_s}] por código.
var services: Array[Dictionary] = []
## [{id, type_id, service_id, severity, detected_at, resolved_at, status, decision, automatic, cost_cents}].
var incidents: Array[Dictionary] = []


static func from_session(session: SimulationSession, rules: ReportRules = null,
		p_scenario_id: String = "") -> DayReport:
	var r: DayReport = DayReport.new()
	var rr: ReportRules = rules if rules != null else ReportRules.load_default()
	r.scenario_id = p_scenario_id if p_scenario_id != "" else String(session.world.scenario.id)
	r.day_start = session.clock.day_start
	r.day_end = session.clock.day_end
	r.finished_at = session.clock.now
	var ind: Indicators = session.query_indicators()
	r.quality = ind.quality
	r.perception = ind.perception
	r.result_cents = ind.result_cents
	r.passengers_carried = ind.passengers_carried
	r.passengers_affected = ind.affected
	r.passengers_compensated = ind.compensated
	r.passengers_needing_alternative = ind.needing_alternative
	r.score = rr.score(ind.quality, ind.perception)
	r.grade = rr.grade_for(r.score)
	for e: LedgerEntry in session.query_ledger().entries:
		r.ledger_by_category[e.category] = int(r.ledger_by_category.get(e.category, 0)) + e.amount_cents
		if e.amount_cents > 0:
			r.revenue_cents += e.amount_cents
		else:
			r.cost_cents += e.amount_cents
	for sid: StringName in session.service_ids():
		var sum: ServiceSummary = session.query_service_summary(sid)
		if sum == null:
			continue
		r.services.append({"service_id": sid, "code": sum.code, "route": sum.route_text,
				"status": Enums.name_of(Enums.ServiceStatus, sum.status), "delay_s": session.delay_of(sid)})
	for inc: Incident in session.all_incidents():
		var d: Decision = inc.decision
		r.incidents.append({"id": inc.id, "type_id": inc.type_id, "service_id": inc.service_id,
				"severity": inc.severity, "detected_at": inc.detected_at, "resolved_at": inc.resolved_at,
				"status": Enums.name_of(Enums.IncidentStatus, inc.status),
				"decision": d.option_type if d != null else &"",
				"automatic": d.automatic if d != null else false,
				"cost_cents": d.total_cost_cents() if d != null else 0})
	return r


func to_dict() -> Dictionary:
	var cats: Dictionary = {}
	for k: StringName in ledger_by_category:
		cats[String(k)] = ledger_by_category[k]
	return {"scenario_id": scenario_id, "day_start": day_start, "day_end": day_end,
			"finished_at": finished_at, "quality": quality, "perception": perception,
			"result_cents": result_cents, "score": score, "grade": String(grade),
			"revenue_cents": revenue_cents, "cost_cents": cost_cents, "ledger_by_category": cats,
			"passengers": {"carried": passengers_carried, "affected": passengers_affected,
					"compensated": passengers_compensated, "needing_alternative": passengers_needing_alternative},
			"services": services.duplicate(true), "incidents": incidents.duplicate(true)}
