extends TestCase
## Las tres opciones producen consecuencias distintas y registradas (criterio de la Fase 5).

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")


# --- Esperar reparación -------------------------------------------------------------

func test_wait_resumes_at_repair_time_with_matching_delay() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_SHORT)
	assert_true(F.decide(s, OptionType.WAIT_REPAIR))
	var inc: Incident = F.incident(s)
	assert_eq(inc.status, Enums.IncidentStatus.IN_PROGRESS)
	D.run_to_text(s, "08:36")
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.HELD, "aún en reparación")
	D.run_to_text(s, "08:38")
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.RUNNING)
	assert_eq(inc.status, Enums.IncidentStatus.RESOLVED)
	assert_eq(inc.resolved_at, D.t("08:12") + F.REPAIR_SHORT)
	assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.IN_SERVICE)
	D.run_to_text(s, "10:00")
	var arrival: int = s.world.services[D.S3103].stops[3].act_arr
	assert_eq(arrival, D.t("08:25") + F.REPAIR_SHORT)


func test_wait_short_repair_barely_affects_3105() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_SHORT)
	F.decide(s, OptionType.WAIT_REPAIR)
	D.run_to_text(s, "09:30")
	var dep: int = s.world.services[D.S3105].stops[0].act_dep
	assert_eq(dep, D.t("08:25") + F.REPAIR_SHORT + 900, "sale tras la rotación mínima")


func test_wait_long_repair_propagates_to_3105() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.WAIT_REPAIR)
	var info: DelayInfo = s.delay_info(D.S3105)
	assert_eq(info.cause, DelayInfo.CAUSE_ROTATION_MATERIAL)
	D.run_to_text(s, "11:00")
	assert_eq(s.world.services[D.S3105].stops[0].act_dep, D.t("08:25") + F.REPAIR_LONG + 900)


func test_wait_records_cost_and_decision() -> void:
	var s: SimulationSession = F.detected()
	F.decide(s, OptionType.WAIT_REPAIR)
	var d: Decision = F.incident(s).decision
	assert_eq(d.option_type, OptionType.WAIT_REPAIR)
	assert_false(d.automatic)
	assert_eq(d.time, D.t("08:12"))
	assert_eq(d.total_cost_cents(), -s.world.incident_rules.repair_on_route_cents)
	assert_eq(s.log.filter(&"DECISION_TAKEN").size(), 1)


# --- Sustituir material -----------------------------------------------------------

func test_substitute_swaps_composition_for_rest_of_route_and_chain() -> void:
	var s: SimulationSession = F.detected()
	assert_true(F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK))
	var inc: Incident = F.incident(s)
	assert_eq(F.comp_of(s, D.S3103, 0), &"cmp_c2", "el tramo ya recorrido sigue con el original")
	assert_eq(F.comp_of(s, D.S3103, 2), &"cmp_res_v6", "el resto con la reserva")
	assert_eq(F.comp_of(s, D.S3105), &"cmp_res_v6")
	assert_eq(F.comp_of(s, D.S3106), &"cmp_res_v6")
	assert_eq(F.comp_of(s, D.S3108), &"cmp_res_v6")
	assert_eq(s.world.vehicles[inc.vehicle_id].status, Enums.VehicleStatus.FAILED, "el averiado no vuelve")
	assert_eq(s.world.vehicles[&"veh_v6"].status, Enums.VehicleStatus.IN_SERVICE)
	var replaced: int = 0
	for a: ResourceAssignment in s.world.assignments.all():
		if a.source == Enums.AssignmentSource.INCIDENT_REPLACEMENT:
			replaced += 1
			assert_ne(a.replaces_assignment_id, &"")
	assert_eq(replaced, 4)


func test_substitute_resumes_after_positioning_plus_transfer() -> void:
	var s: SimulationSession = F.detected()
	var preview: OptionPreview = F.incident(s).option(OptionType.SUBSTITUTE_ROLLING_STOCK).preview
	F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_eq(F.incident(s).decision.resume_at, preview.resume_at)
	assert_true(preview.resume_at - D.t("08:12") >= s.world.scenario.transfer_s)
	D.run_to(s, preview.resume_at - 1)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.HELD)
	D.run_to(s, preview.resume_at)
	assert_eq(s.world.services[D.S3103].status, Enums.ServiceStatus.RUNNING)
	D.run_to_text(s, "12:00")
	var arrival: int = s.world.services[D.S3103].stops[3].act_arr
	assert_eq(arrival, D.t("08:25") + (preview.resume_at - D.t("08:12")))


func test_substitute_is_faster_than_long_wait_and_costs_more() -> void:
	var w: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(w, OptionType.WAIT_REPAIR)
	D.run_to_text(w, "12:00")
	var sub: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(sub, OptionType.SUBSTITUTE_ROLLING_STOCK)
	D.run_to_text(sub, "12:00")
	assert_true(sub.world.services[D.S3103].stops[3].act_arr < w.world.services[D.S3103].stops[3].act_arr)
	assert_true(sub.world.services[D.S3105].stops[0].act_dep < w.world.services[D.S3105].stops[0].act_dep)
	assert_true(-F.incident(sub).decision.total_cost_cents() > -F.incident(w).decision.total_cost_cents())


func test_substitute_preview_matches_outcome() -> void:
	var s: SimulationSession = F.detected()
	var preview: OptionPreview = F.incident(s).option(OptionType.SUBSTITUTE_ROLLING_STOCK).preview
	F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK)
	D.run_to_text(s, "12:00")
	var own: int = s.world.services[D.S3103].stops[3].act_arr - D.t("08:25")
	assert_eq(own, preview.own_delay_min_s)
	assert_eq(preview.own_delay_min_s, preview.own_delay_max_s)
	var dep3105: int = s.world.services[D.S3105].stops[0].act_dep - D.t("08:55")
	var found: bool = false
	for dd: Dictionary in preview.dependents:
		if dd["service_id"] == D.S3105:
			found = true
			assert_eq(int(dd["delay_min_s"]), dep3105)
	assert_true(found, "3105 aparece como afectado")


func test_wait_preview_range_contains_outcome() -> void:
	var s: SimulationSession = SimFixture.session_with_incident(12345)
	D.run_to_text(s, "08:12")
	var preview: OptionPreview = F.incident(s).option(OptionType.WAIT_REPAIR).preview
	F.decide(s, OptionType.WAIT_REPAIR)
	D.run_to_text(s, "12:00")
	var own: int = s.world.services[D.S3103].stops[3].act_arr - D.t("08:25")
	assert_true(own >= preview.own_delay_min_s and own <= preview.own_delay_max_s, "retraso propio %d" % own)


func test_substitute_unavailable_when_reserve_used() -> void:
	var s: SimulationSession = F.detected()
	F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_eq(IncidentOptions.find_reserve(s.world, F.incident(s)), null)


# --- Cancelar -------------------------------------------------------------------------

func test_cancel_service_partially_and_registers_passengers() -> void:
	var s: SimulationSession = F.detected()
	assert_true(F.decide(s, OptionType.CANCEL_SERVICE))
	var inc: Incident = F.incident(s)
	var sv: Service = s.world.services[D.S3103]
	assert_eq(sv.status, Enums.ServiceStatus.PARTIALLY_CANCELLED)
	assert_eq(inc.status, Enums.IncidentStatus.RESOLVED)
	assert_eq(inc.decision.needing_alternative, 290)
	assert_eq(inc.decision.cancelled_service_ids, [D.S3103])
	assert_eq(sv.stops[3].status, Enums.StopStatus.CANCELLED)
	assert_eq(s.world.assignments.for_service(D.S3103).size(), 0, "recursos liberados")
	assert_eq(s.log.filter(SimEventType.SERVICE_CANCELLED, D.S3103).size(), 1)
	assert_eq(s.delay_of(D.S3103), 0)


func test_cancel_moves_following_services_to_reserve_on_time() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.CANCEL_SERVICE)
	assert_eq(F.comp_of(s, D.S3105), &"cmp_res_v6")
	D.run_to_text(s, "12:00")
	assert_eq(s.world.services[D.S3105].stops[0].act_dep, D.t("08:55"), "3105 sale a su hora")
	assert_eq(s.world.services[D.S3105].status, Enums.ServiceStatus.TERMINATED)


func test_cancel_without_reserve_cancels_dependents() -> void:
	var s: SimulationSession = F.detected()
	s.world.vehicles[&"veh_v6"].status = Enums.VehicleStatus.MAINTENANCE
	s.incidents.refresh_options(F.incident(s), s)
	var preview: OptionPreview = F.incident(s).option(OptionType.CANCEL_SERVICE).preview
	assert_eq(preview.cancelled_service_ids.size(), 4, "3103, 3105, 3106 y 3108")
	F.decide(s, OptionType.CANCEL_SERVICE)
	for sid: StringName in [D.S3103, D.S3105, D.S3106, D.S3108]:
		assert_true(s.world.services[sid].is_cancelled(), String(sid))
	assert_true(F.incident(s).decision.needing_alternative > 290)


# --- Distintas y registradas --------------------------------------------------------------

func test_three_options_produce_distinct_recorded_consequences() -> void:
	var results: Dictionary = {}
	for opt: StringName in OptionType.ALL:
		var s: SimulationSession = F.detected(F.REPAIR_LONG)
		F.decide(s, opt)
		D.run_to_text(s, "12:00")
		var inc: Incident = F.incident(s)
		results[opt] = {
			"cancelled": s.world.services[D.S3103].is_cancelled(),
			"dep3105": s.world.services[D.S3105].stops[0].act_dep,
			"cost": inc.decision.total_cost_cents(),
		}
		assert_eq(s.log.filter(&"DECISION_TAKEN").size(), 1)
		assert_eq(inc.decision.option_type, opt)
		assert_eq(inc.status, Enums.IncidentStatus.RESOLVED)
	var w: Dictionary = results[OptionType.WAIT_REPAIR]
	var sb: Dictionary = results[OptionType.SUBSTITUTE_ROLLING_STOCK]
	var c: Dictionary = results[OptionType.CANCEL_SERVICE]
	assert_true(c["cancelled"] and not w["cancelled"] and not sb["cancelled"])
	assert_ne(w["dep3105"], sb["dep3105"])
	assert_ne(sb["dep3105"], c["dep3105"])
	assert_ne(w["cost"], sb["cost"])
	assert_ne(sb["cost"], c["cost"])


# --- Tiempo agotado y validación --------------------------------------------------------

func test_timeout_applies_default_option_automatically() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	var timeout: int = s.world.incident_rules.decision_timeout_s
	D.run_to(s, D.t("08:12") + timeout - 1)
	assert_eq(F.incident(s).status, Enums.IncidentStatus.AWAITING_DECISION)
	D.run_to(s, D.t("08:12") + timeout)
	var inc: Incident = F.incident(s)
	assert_eq(inc.status, Enums.IncidentStatus.IN_PROGRESS)
	assert_true(inc.decision.automatic)
	assert_eq(inc.decision.option_type, OptionType.WAIT_REPAIR)
	assert_eq(inc.decision.time, D.t("08:12") + timeout)


func test_decision_cancels_timeout() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	F.decide(s, OptionType.CANCEL_SERVICE)
	D.run_to_text(s, "09:00")
	assert_eq(s.log.filter(&"DECISION_TAKEN").size(), 1)
	assert_false(F.incident(s).decision.automatic)


func test_invalid_commands_rejected() -> void:
	var s: SimulationSession = F.detected()
	assert_false(s.apply_command(ResolveIncidentCommand.make(&"inc_999", OptionType.WAIT_REPAIR)))
	assert_false(s.apply_command(ResolveIncidentCommand.make(F.incident(s).id, &"TELEPORT")))
	assert_eq(F.incident(s).status, Enums.IncidentStatus.AWAITING_DECISION)
	assert_true(F.decide(s, OptionType.WAIT_REPAIR))
	assert_false(F.decide(s, OptionType.CANCEL_SERVICE), "no se decide dos veces")
	assert_eq(s.command_log.size(), 1)
	assert_eq(s.command_log[0].kind, &"RESOLVE_INCIDENT")
	assert_eq(s.command_log[0].applied_at, D.t("08:12"))


func test_decision_while_paused_applies_immediately() -> void:
	var s: SimulationSession = F.detected(F.REPAIR_LONG)
	s.apply_command(SetSpeedCommand.make(0))
	F.decide(s, OptionType.SUBSTITUTE_ROLLING_STOCK)
	assert_eq(F.comp_of(s, D.S3105), &"cmp_res_v6")
	assert_eq(s.clock.now, D.t("08:12"))
