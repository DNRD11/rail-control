class_name IncidentRulesParser
extends RefCounted
## Convierte data/rules/incidents.json en IncidentRules, validando y reportando errores.


static func parse(file: Dictionary, report: ValidationReport) -> IncidentRules:
	var rules: IncidentRules = IncidentRules.new()
	var r: DictReader = DictReader.new(report, "incidents")
	rules.decision_timeout_s = r.read_int(file, "decision_timeout_s", false, 900)
	rules.default_option = r.read_id(file, "default_option", false, OptionType.WAIT_REPAIR)
	rules.positioning_speed_kmh = r.read_int(file, "positioning_speed_kmh", false, 200)
	if rules.positioning_speed_kmh <= 0:
		report.error(&"BAD_VALUE", "incidents.positioning_speed_kmh debe ser positivo")
		rules.positioning_speed_kmh = 200
	if not OptionType.ALL.has(rules.default_option):
		report.error(&"BAD_VALUE", "incidents.default_option desconocida «%s»" % rules.default_option)
		rules.default_option = OptionType.WAIT_REPAIR
	var costs: Dictionary = file.get("costs", {}) as Dictionary if typeof(file.get("costs")) == TYPE_DICTIONARY else {}
	var cr: DictReader = DictReader.new(report, "incidents.costs")
	rules.repair_on_route_cents = cr.read_int(costs, "repair_on_route_cents", false, 0)
	rules.rescue_cents = cr.read_int(costs, "rescue_cents", false, 0)
	rules.reserve_mobilization_cents = cr.read_int(costs, "reserve_mobilization_cents", false, 0)
	rules.empty_run_per_km_cents = cr.read_int(costs, "empty_run_per_km_cents", false, 0)
	var items: Array[Dictionary] = r.read_dicts(file, "types", true)
	for i: int in items.size():
		var t: IncidentType = _parse_type(items[i], "incidents.types[%d]" % i, report)
		if t.id == &"":
			continue
		if rules.types.has(t.id):
			report.error(&"DUPLICATE_ID", "incidents.types: id repetido «%s»" % t.id)
			continue
		rules.types[t.id] = t
	return rules


static func _parse_type(d: Dictionary, ctx: String, report: ValidationReport) -> IncidentType:
	var r: DictReader = DictReader.new(report, ctx)
	var t: IncidentType = IncidentType.new()
	t.id = r.read_id(d, "id")
	t.category = r.read_id(d, "category", false, &"ROLLING_STOCK")
	t.title = r.read_string(d, "title", false, String(t.id))
	t.probability_per_hour = r.read_float(d, "probability_per_hour", false, 0.0)
	t.options = r.read_ids(d, "options", true)
	for o: StringName in t.options:
		if not OptionType.ALL.has(o):
			report.error(&"BAD_VALUE", "%s.options: opción desconocida «%s»" % [ctx, o])
	var range_v: Variant = d.get("repair_time_range_s")
	if typeof(range_v) == TYPE_ARRAY and (range_v as Array).size() == 2:
		t.repair_min_s = int((range_v as Array)[0])
		t.repair_max_s = int((range_v as Array)[1])
	else:
		report.error(&"BAD_TYPE", "%s.repair_time_range_s: se esperaba [mín, máx] en segundos" % ctx)
	if t.repair_min_s <= 0 or t.repair_max_s < t.repair_min_s:
		report.error(&"BAD_VALUE", "%s.repair_time_range_s: rango no válido" % ctx)
		t.repair_min_s = maxi(t.repair_min_s, 1)
		t.repair_max_s = maxi(t.repair_max_s, t.repair_min_s)
	return t
