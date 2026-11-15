class_name EconomyRulesParser
extends RefCounted
## Convierte data/rules/{economy,compensation,perception}.json en sus reglas, validando y reportando errores.


static func parse_economy(file: Dictionary, report: ValidationReport) -> EconomyRules:
	var rules: EconomyRules = EconomyRules.new()
	var r: DictReader = DictReader.new(report, "economy")
	rules.price_per_pax_km_cents = r.read_float(file, "price_per_pax_km_cents", true, 0.0)
	rules.operating_cost_per_vehicle_km_cents = r.read_int(file, "operating_cost_per_vehicle_km_cents", true, 0)
	rules.infra_charge_per_km_cents = r.read_int(file, "infra_charge_per_km_cents", true, 0)
	var staff: Dictionary = file.get("staff_per_hour_cents", {}) as Dictionary \
			if typeof(file.get("staff_per_hour_cents")) == TYPE_DICTIONARY else {}
	if staff.is_empty():
		report.error(&"MISSING_FIELD", "economy: falta el objeto «staff_per_hour_cents»")
	var sr: DictReader = DictReader.new(report, "economy.staff_per_hour_cents")
	rules.driver_per_hour_cents = sr.read_int(staff, "DRIVER", true, 0)
	rules.conductor_per_hour_cents = sr.read_int(staff, "CONDUCTOR", true, 0)
	if rules.price_per_pax_km_cents < 0.0 or rules.operating_cost_per_vehicle_km_cents < 0 \
			or rules.infra_charge_per_km_cents < 0 or rules.driver_per_hour_cents < 0 \
			or rules.conductor_per_hour_cents < 0:
		report.error(&"BAD_VALUE", "economy: precios y costes no pueden ser negativos")
	return rules


static func parse_compensation(file: Dictionary, report: ValidationReport) -> CompensationRules:
	var rules: CompensationRules = CompensationRules.new()
	var r: DictReader = DictReader.new(report, "compensation")
	rules.cancellation_percent = r.read_int(file, "cancellation_percent", false, 100)
	if rules.cancellation_percent < 0 or rules.cancellation_percent > 100:
		report.error(&"BAD_VALUE", "compensation.cancellation_percent debe estar entre 0 y 100")
		rules.cancellation_percent = clampi(rules.cancellation_percent, 0, 100)
	var items: Array[Dictionary] = r.read_dicts(file, "tiers", true)
	var prev: int = -1
	for i: int in items.size():
		var tr: DictReader = DictReader.new(report, "compensation.tiers[%d]" % i)
		var min_s: int = tr.read_int(items[i], "min_delay_s", true, 0)
		var pct: int = tr.read_int(items[i], "percent", true, 0)
		if min_s <= prev:
			report.error(&"BAD_VALUE", "compensation.tiers[%d]: min_delay_s debe ser ascendente" % i)
		if pct < 0 or pct > 100:
			report.error(&"BAD_VALUE", "compensation.tiers[%d]: percent debe estar entre 0 y 100" % i)
			pct = clampi(pct, 0, 100)
		prev = maxi(prev, min_s)
		rules.tiers.append({"min_delay_s": min_s, "percent": pct})
	return rules


static func parse_perception(file: Dictionary, report: ValidationReport) -> PerceptionRules:
	var rules: PerceptionRules = PerceptionRules.new()
	var r: DictReader = DictReader.new(report, "perception")
	rules.base = r.read_int(file, "base", false, 75)
	rules.delay_tolerance_s = r.read_int(file, "delay_tolerance_s", false, DelayInfo.MINOR_MAX_S)
	rules.info_window_s = r.read_int(file, "info_window_s", false, 600)
	rules.late_info_factor = r.read_float(file, "late_info_factor", false, 0.5)
	rules.delay_penalty_per_1000_pax_min = r.read_float(file, "delay_penalty_per_1000_pax_min", false, 0.0)
	rules.cancel_penalty_per_1000_pax = r.read_float(file, "cancel_penalty_per_1000_pax", false, 0.0)
	rules.no_info_penalty_per_1000_pax = r.read_float(file, "no_info_penalty_per_1000_pax", false, 0.0)
	rules.early_info_bonus_per_1000_pax = r.read_float(file, "early_info_bonus_per_1000_pax", false, 0.0)
	rules.continuity_bonus_per_1000_pax = r.read_float(file, "continuity_bonus_per_1000_pax", false, 0.0)
	if rules.base < 0 or rules.base > 100:
		report.error(&"BAD_VALUE", "perception.base debe estar entre 0 y 100")
		rules.base = clampi(rules.base, 0, 100)
	if rules.info_window_s < 0 or rules.delay_tolerance_s < 0 or rules.late_info_factor < 0.0 \
			or rules.late_info_factor > 1.0:
		report.error(&"BAD_VALUE", "perception: ventana, tolerancia y late_info_factor fuera de rango")
	var qs: Dictionary = file.get("quality_scores", {}) as Dictionary \
			if typeof(file.get("quality_scores")) == TYPE_DICTIONARY else {}
	if qs.is_empty():
		report.error(&"MISSING_FIELD", "perception: falta el objeto «quality_scores»")
	var qr: DictReader = DictReader.new(report, "perception.quality_scores")
	for level: StringName in [DelayInfo.LEVEL_ON_TIME, DelayInfo.LEVEL_MINOR, DelayInfo.LEVEL_MAJOR,
			DelayInfo.LEVEL_SEVERE]:
		rules.quality_scores[level] = clampi(qr.read_int(qs, String(level), true, 0), 0, 100)
	rules.quality_cancelled = clampi(qr.read_int(qs, "CANCELLED", true, 0), 0, 100)
	for v: float in [rules.delay_penalty_per_1000_pax_min, rules.cancel_penalty_per_1000_pax,
			rules.no_info_penalty_per_1000_pax, rules.early_info_bonus_per_1000_pax,
			rules.continuity_bonus_per_1000_pax]:
		if v < 0.0:
			report.error(&"BAD_VALUE", "perception: los coeficientes no pueden ser negativos")
			break
	return rules
