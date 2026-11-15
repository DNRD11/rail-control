class_name ReportPresenter
extends RefCounted
## Convierte los datos del informe (`DayReport.to_dict()`) en el modelo que pinta ReportScreen:
## nota, lecturas de los tres indicadores, desglose económico, viajeros, retrasos e incidencias.
## Es el único punto que conoce los nombres de claves reales de `DayReport.to_dict()`.

const LEDGER_LABELS: Dictionary[String, String] = {
	"REVENUE": "Ingresos por viajeros", "OPERATING_COST": "Explotación del material", "STAFF_COST": "Personal",
	"INFRA_CHARGE_ORDINARY": "Canon de infraestructura", "INCIDENT_COST": "Incidencias",
	"SUBSTITUTION_COST": "Sustitución de material", "COMPENSATION": "Indemnizaciones",
}
const LEDGER_STATES: Dictionary[String, RcTokens.State] = {
	"REVENUE": RcTokens.State.OK, "OPERATING_COST": RcTokens.State.IDLE, "STAFF_COST": RcTokens.State.IDLE,
	"INFRA_CHARGE_ORDINARY": RcTokens.State.IDLE, "INCIDENT_COST": RcTokens.State.ALERT,
	"SUBSTITUTION_COST": RcTokens.State.ALERT, "COMPENSATION": RcTokens.State.WARN,
}
const HEADLINES: Dictionary[String, String] = {
	"A": "Jornada sobresaliente", "B": "Buena jornada", "C": "Jornada mejorable", "D": "Jornada difícil"}
const INCIDENT_TITLES: Dictionary[String, String] = {"ROLLING_STOCK_FAILURE": "Avería de material"}
const DELAY_MIN_S: int = 300
const OPTION_TITLES: Dictionary[String, String] = {
	"WAIT_REPAIR": "Esperar reparación", "SUBSTITUTE_ROLLING_STOCK": "Sustituir material",
	"CANCEL_SERVICE": "Cancelar servicio"}


static func build(d: Dictionary) -> Dictionary:
	var quality: float = float(d.get("quality", 0.0))
	var perception: float = float(d.get("perception", 0.0))
	var result: int = int(d.get("result_cents", 0))
	var grade: String = String(d.get("grade", "D"))
	var services: Array = d.get("services", []) as Array
	return {
		"scenario": _scenario_name(String(d.get("scenario_id", ""))),
		"window": "%s – %s" % [RcFormat.hhmm(int(d.get("day_start", 0))), RcFormat.hhmm(int(d.get("day_end", 0)))],
		"grade": grade, "score": float(d.get("score", 0.0)), "headline": HEADLINES.get(grade, ""),
		"quality": quality, "perception": perception, "result_cents": result,
		"readings": {"quality": _read_quality(quality), "perception": _read_perception(perception),
				"result": _read_result(result)},
		"ledger": _ledger(d.get("ledger_by_category", {}) as Dictionary),
		"passengers": _passengers(d.get("passengers", {}) as Dictionary),
		"delayed": _delayed(services),
		"incidents": _incidents(d.get("incidents", []) as Array, services),
	}


static func _scenario_name(id: String) -> String:
	for info: ScenarioInfo in ScenarioCatalog.list():
		if String(info.id) == id:
			return info.name
	return ""


static func _read_quality(v: float) -> Dictionary:
	if v >= 90.0:
		return {"text": "Puntualidad excelente", "state": RcTokens.State.OK}
	if v >= 75.0:
		return {"text": "Buena puntualidad", "state": RcTokens.State.OK}
	if v >= 55.0:
		return {"text": "Puntualidad irregular", "state": RcTokens.State.WARN}
	return {"text": "Servicio muy afectado", "state": RcTokens.State.ALERT}


static func _read_perception(v: float) -> Dictionary:
	if v >= 80.0:
		return {"text": "Viajeros satisfechos", "state": RcTokens.State.OK}
	if v >= 60.0:
		return {"text": "Percepción aceptable", "state": RcTokens.State.WARN}
	if v >= 40.0:
		return {"text": "Viajeros molestos", "state": RcTokens.State.WARN}
	return {"text": "Percepción muy dañada", "state": RcTokens.State.ALERT}


static func _read_result(cents: int) -> Dictionary:
	if cents >= 0:
		return {"text": "Jornada rentable", "state": RcTokens.State.OK}
	return {"text": "Jornada con pérdidas", "state": RcTokens.State.ALERT}


static func _ledger(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var biggest: int = 1
	for key: String in LEDGER_LABELS:
		biggest = maxi(biggest, absi(int(data.get(key, 0))))
	for key: String in LEDGER_LABELS:
		var cents: int = int(data.get(key, 0))
		if cents == 0 and key != "REVENUE":
			continue
		out.append({"label": LEDGER_LABELS[key], "cents": cents, "state": LEDGER_STATES[key],
				"fraction": float(absi(cents)) / float(biggest)})
	return out


static func _passengers(p: Dictionary) -> Array[Dictionary]:
	var items: Array[Array] = [
		["Transportados", "carried", -1],
		["Afectados", "affected", RcTokens.State.WARN],
		["Indemnizados", "compensated", RcTokens.State.WARN],
		["Sin alternativa", "needing_alternative", RcTokens.State.SPECIAL],
	]
	var out: Array[Dictionary] = []
	for item: Array in items:
		var value: int = int(p.get(item[1], 0))
		var state: int = int(item[2]) if value > 0 else -1
		out.append({"caption": item[0], "value": RcFormat.count(value), "state": state})
	return out


## Servicios cancelados o con retraso de al menos DELAY_MIN_S, de peor a mejor.
static func _delayed(services: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Variant in services:
		var s: Dictionary = item as Dictionary
		var status: String = String(s.get("status", ""))
		var cancelled: bool = status == "CANCELLED"
		var partial: bool = status == "PARTIALLY_CANCELLED"
		var delay_s: int = int(s.get("delay_s", 0))
		if not (cancelled or partial or delay_s >= DELAY_MIN_S):
			continue
		var minutes: int = RcFormat.minutes(delay_s)
		var chip: String = "CANCELADO" if cancelled else ("PARCIAL" if partial else "+%d′" % minutes)
		var state: RcTokens.State = RcTokens.State.ALERT if (cancelled or minutes >= 15) else RcTokens.State.WARN
		out.append({"title": "Servicio %s" % String(s.get("code", "?")), "subtitle": String(s.get("route", "")),
				"chip": chip, "state": state, "rank": 100000 if cancelled else delay_s})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["rank"]) > int(b["rank"]))
	return out


static func _incidents(incidents: Array, services: Array) -> Array[Dictionary]:
	var codes: Dictionary = {}
	for item: Variant in services:
		var s: Dictionary = item as Dictionary
		codes[String(s.get("service_id", ""))] = String(s.get("code", "?"))
	var out: Array[Dictionary] = []
	for item: Variant in incidents:
		var i: Dictionary = item as Dictionary
		var option: String = String(i.get("decision", ""))
		var parts: PackedStringArray = PackedStringArray([OPTION_TITLES.get(option, "Sin decisión")])
		parts.append(RcFormat.eur(-absi(int(i.get("cost_cents", 0)))))
		if bool(i.get("automatic", false)):
			parts.append("automática")
		out.append({"title": "%s · %s" % [codes.get(String(i.get("service_id", "")), "?"),
				INCIDENT_TITLES.get(String(i.get("type_id", "")), "Incidencia")],
				"subtitle": " · ".join(parts), "cost": ""})
	return out
