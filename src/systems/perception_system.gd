class_name PerceptionSystem
extends SimSystem
## Calidad y percepción (ECONOMY.md §5). Sin estado propio: se calculan al consultar a partir de los
## viajeros de cada servicio, la información enviada y las reglas de perception.json.

## Calidad: puntualidad en destino ponderada por viajeros (100 en hora, 70 MINOR, 40 MAJOR, 0 SEVERE/cancelado).
## Percepción: base 75; penaliza minutos de retraso x afectados, cancelaciones y falta de información;
## bonifica informar pronto y mantener la continuidad del viaje (servicio con incidencia no cancelado).
func compute(session: SimulationSession) -> Indicators:
	var world: World = session.world
	var rules: PerceptionRules = world.perception_rules
	var ind: Indicators = Indicators.new()
	var quality_points: int = 0
	var quality_pax: int = 0
	var delay_pax_min: int = 0
	var cancelled_pax: int = 0
	var no_info_pax: float = 0.0
	var early_info_pax: int = 0
	var continuity_pax: int = 0
	for sid: StringName in session.service_ids():
		var s: Service = world.services[sid]
		var load: ServicePassengerLoad = world.passengers.get(sid)
		if load == null:
			continue
		var o: PassengerOutcome = PassengerCalc.outcome(world, s)
		ind.passengers_carried += o.carried
		ind.affected += o.affected
		ind.needing_alternative += o.needing_alternative
		quality_points += o.quality_points
		quality_pax += o.quality_pax
		delay_pax_min += o.delay_pax_min
		cancelled_pax += o.needing_alternative
		match PassengerSystem.info_state(load, o.affected, session.clock.now, rules):
			PassengerSystem.INFO_MISSING:
				no_info_pax += float(o.affected)
			PassengerSystem.INFO_LATE:
				no_info_pax += float(o.affected) * rules.late_info_factor
			PassengerSystem.INFO_EARLY:
				early_info_pax += o.affected
		if not s.incident_ids.is_empty() and not s.is_cancelled():
			continuity_pax += o.affected
	ind.quality = snappedf(float(quality_points) / float(quality_pax), 0.1) if quality_pax > 0 else 100.0
	var p: float = float(rules.base)
	p -= rules.delay_penalty_per_1000_pax_min * float(delay_pax_min) / 1000.0
	p -= rules.cancel_penalty_per_1000_pax * float(cancelled_pax) / 1000.0
	p -= rules.no_info_penalty_per_1000_pax * no_info_pax / 1000.0
	p += rules.early_info_bonus_per_1000_pax * float(early_info_pax) / 1000.0
	p += rules.continuity_bonus_per_1000_pax * float(continuity_pax) / 1000.0
	ind.perception = snappedf(clampf(p, 0.0, 100.0), 0.1)
	ind.result_cents = session.economy.ledger.total_cents()
	ind.compensated = session.economy.compensated_pax
	ind.lost_revenue_cents = session.economy.lost_revenue_cents
	return ind
