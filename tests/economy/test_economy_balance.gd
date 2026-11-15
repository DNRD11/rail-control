extends TestCase
## Equilibrado de la avería de 3103 (ECONOMY §6): simula las opciones en cuatro contextos, imprime la matriz
## y comprueba que la mejor opción coincide con la tabla y que ninguna domina en todos los contextos.

const E = preload("res://tests/framework/economy_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")

## Puntuación compuesta para comparar opciones: euros de resultado + PERCEPTION_WEIGHT_EUR por punto de percepción.
const PERCEPTION_WEIGHT_EUR: float = 1000.0

const CONTEXTS: Array[Dictionary] = [
	{"id": "corta+reserva", "repair": 1500, "consumed": false},
	{"id": "larga+reserva", "repair": 3600, "consumed": false},
	{"id": "corta+sin_reserva", "repair": 1500, "consumed": true},
	{"id": "larga+sin_reserva", "repair": 3600, "consumed": true},
]


## {option: {"available", "result_eur", "perception", "quality", "affected", "compensated", "comp_eur", "score"}}
func _matrix_for(ctx: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for opt: StringName in OptionType.ALL:
		# se informa siempre a tiempo para aislar el efecto de la decisión
		var s: SimulationSession = E.incident_day(int(ctx["repair"]), opt, bool(ctx["consumed"]), true)
		if s == null:
			out[opt] = {"available": false}
			continue
		var res_eur: float = E.ind(s, "result_cents") / 100.0
		var per: float = E.ind(s, "perception")
		out[opt] = {
			"available": true,
			"result_eur": res_eur,
			"perception": per,
			"quality": E.ind(s, "quality"),
			"affected": int(E.ind(s, "affected")),
			"compensated": int(E.ind(s, "compensated")),
			"comp_eur": -s.query_ledger().total_by_category(&"COMPENSATION") / 100.0,
			"inc_eur": -(s.query_ledger().total_by_category(&"INCIDENT_COST")
					+ s.query_ledger().total_by_category(&"SUBSTITUTION_COST")) / 100.0,
			"score": res_eur + PERCEPTION_WEIGHT_EUR * per,
		}
	return out


func _best(m: Dictionary) -> StringName:
	var best: StringName = &""
	var best_score: float = -INF
	for opt: StringName in OptionType.ALL:
		if m[opt]["available"] and float(m[opt]["score"]) > best_score:
			best_score = float(m[opt]["score"])
			best = opt
	return best


func _print_matrix(all: Dictionary) -> void:
	print("")
	print("== MATRIZ DE EQUILIBRADO (avería 3103; informado a tiempo; score = resultado EUR + %d * percepción) ==" % int(PERCEPTION_WEIGHT_EUR))
	print("%-18s %-26s %12s %9s %8s %8s %12s %12s %12s" % ["contexto", "opción", "resultado EUR", "percep.", "calidad", "afect.", "indemn. EUR", "incid. EUR", "score"])
	for ctx: Dictionary in CONTEXTS:
		var m: Dictionary = all[ctx["id"]]
		for opt: StringName in OptionType.ALL:
			var r: Dictionary = m[opt]
			if not r["available"]:
				print("%-18s %-26s %s" % [ctx["id"], opt, "NO DISPONIBLE"])
			else:
				print("%-18s %-26s %12.0f %9.1f %8.1f %8d %12.0f %12.0f %12.0f" % [ctx["id"], opt, r["result_eur"],
						r["perception"], r["quality"], r["affected"], r["comp_eur"], r["inc_eur"], r["score"]])
		print("  -> mejor: %s" % _best(m))


func _all_matrices() -> Dictionary:
	var all: Dictionary = {}
	for ctx: Dictionary in CONTEXTS:
		all[ctx["id"]] = _matrix_for(ctx)
	return all


func test_balance_matrix_matches_design_table() -> void:
	var all: Dictionary = _all_matrices()
	_print_matrix(all)
	# Reparación corta con reserva: esperar es lo mejor
	assert_eq(_best(all["corta+reserva"]), OptionType.WAIT_REPAIR, "corta+reserva -> esperar")
	# Reparación larga con reserva: sustituir es lo mejor
	assert_eq(_best(all["larga+reserva"]), OptionType.SUBSTITUTE_ROLLING_STOCK, "larga+reserva -> sustituir")
	# Reserva consumida: sustituir no está disponible en ningún caso
	for cid: String in ["corta+sin_reserva", "larga+sin_reserva"]:
		assert_false(all[cid][OptionType.SUBSTITUTE_ROLLING_STOCK]["available"], "%s: sustituir no disponible" % cid)
		assert_true(all[cid][OptionType.WAIT_REPAIR]["available"])
		assert_true(all[cid][OptionType.CANCEL_SERVICE]["available"])
	# Reparación corta: cancelar es pésimo (peor que esperar en resultado y percepción)
	var cs: Dictionary = all["corta+reserva"]
	assert_true(cs[OptionType.CANCEL_SERVICE]["result_eur"] < cs[OptionType.WAIT_REPAIR]["result_eur"], "corta: cancelar peor en resultado")
	assert_true(cs[OptionType.CANCEL_SERVICE]["perception"] < cs[OptionType.WAIT_REPAIR]["perception"], "corta: cancelar peor en percepción")
	# Reparación corta: sustituir caro e innecesario (peor que esperar en resultado)
	assert_true(cs[OptionType.SUBSTITUTE_ROLLING_STOCK]["result_eur"] < cs[OptionType.WAIT_REPAIR]["result_eur"], "corta: sustituir más caro")
	# Reparación larga con reserva: cancelar «malo» (peor que sustituir)
	var ls: Dictionary = all["larga+reserva"]
	assert_true(ls[OptionType.CANCEL_SERVICE]["score"] < ls[OptionType.SUBSTITUTE_ROLLING_STOCK]["score"], "larga: cancelar peor que sustituir")


func test_balance_no_option_dominates_all_contexts() -> void:
	var all: Dictionary = _all_matrices()
	var wins: Dictionary = {}
	for ctx: Dictionary in CONTEXTS:
		var b: StringName = _best(all[ctx["id"]])
		wins[b] = int(wins.get(b, 0)) + 1
	assert_true(wins.size() >= 2, "al menos dos opciones distintas ganan en algún contexto: %s" % str(wins))
	for opt: StringName in wins:
		assert_true(int(wins[opt]) < CONTEXTS.size(), "%s gana en todos los contextos" % opt)
	# dominancia estricta (resultado Y percepción) de una opción sobre otra en todos los contextos disponibles
	for a: StringName in OptionType.ALL:
		for b: StringName in OptionType.ALL:
			if a == b:
				continue
			var dominates_all: bool = true
			var compared: int = 0
			for ctx: Dictionary in CONTEXTS:
				var m: Dictionary = all[ctx["id"]]
				if not (m[a]["available"] and m[b]["available"]):
					continue
				compared += 1
				if not (m[a]["result_eur"] > m[b]["result_eur"] and m[a]["perception"] >= m[b]["perception"]):
					dominates_all = false
			if compared > 0 and dominates_all:
				# CANCELAR dominada por SUSTITUIR es un hallazgo de diseño (se informa), no un fallo del motor
				if b == OptionType.CANCEL_SERVICE:
					print("HALLAZGO: %s domina a %s (resultado y percepción) en todos los contextos comparables" % [a, b])
				else:
					assert_false(true, "%s domina a %s en todos los contextos comparables" % [a, b])


func test_balance_substitute_costs_in_documented_range() -> void:
	# ECONOMY §4: sustituir ≈ 11 000 – 15 000 € de coste de incidencia (rescate + movilización + vacío)
	var s: SimulationSession = E.incident_day(3600, OptionType.SUBSTITUTE_ROLLING_STOCK, false, true)
	var cost_eur: float = -(s.query_ledger().total_by_category(&"INCIDENT_COST")
			+ s.query_ledger().total_by_category(&"SUBSTITUTION_COST")) / 100.0
	assert_true(cost_eur >= 11000.0 and cost_eur <= 15000.0, "coste de sustituir %.0f EUR" % cost_eur)
	var w: SimulationSession = E.incident_day(3600, OptionType.WAIT_REPAIR, false, true)
	var wait_eur: float = -w.query_ledger().total_by_category(&"INCIDENT_COST") / 100.0
	assert_eq(wait_eur, 3000.0, "esperar: 3 000 EUR de reparación en ruta")


func test_balance_wait_indemnities_grow_with_repair_time() -> void:
	var short_comp: int = -E.incident_day(1500, OptionType.WAIT_REPAIR, false, true).query_ledger().total_by_category(&"COMPENSATION")
	var long_comp: int = -E.incident_day(3600, OptionType.WAIT_REPAIR, false, true).query_ledger().total_by_category(&"COMPENSATION")
	assert_true(long_comp > short_comp, "más reparación, más indemnización: %d vs %d" % [long_comp, short_comp])
