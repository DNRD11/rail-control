class_name BriefingPresenter
extends RefCounted
## Modelo de presentación del briefing: carga el escenario (solo lectura) y resume objetivos,
## datos de la jornada y recursos disponibles. No crea la jornada: eso lo hace AppFlow.

## Devuelve {ok, error, name, description, window, services, stations, length_km, goals: Array[Dictionary],
## resources: Array[Dictionary{label, value, note}]}.
static func build(scenario_id: String) -> Dictionary:
	var result: ScenarioLoadResult = ScenarioLoader.load_scenario(scenario_id)
	if not result.ok:
		return {"ok": false, "error": "No se pudo cargar el escenario «%s»." % scenario_id}
	var world: World = result.world
	var scenario: ScenarioInfo = world.scenario
	var session: SimulationSession = SimulationSession.create(world)
	return {
		"ok": true, "error": "", "name": scenario.name, "description": scenario.description,
		"window": "%s – %s" % [RcFormat.hhmm(scenario.day_start), RcFormat.hhmm(scenario.day_end)],
		"services": world.services.size(), "stations": world.stations.size(), "length_km": _length_km(world),
		"line": line_of(world), "goals": _goals(), "resources": _resources(world, session),
	}


## Estaciones [{code, km}] ordenadas por km (para RcLineGlyph).
static func line_of(world: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for st: Station in world.stations.values():
		out.append({"code": st.code, "km": st.km})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["km"]) < float(b["km"]))
	return out


## Solo la línea de un escenario (ficha de selección).
static func line_for(scenario_id: String) -> Array[Dictionary]:
	var result: ScenarioLoadResult = ScenarioLoader.load_scenario(scenario_id)
	var empty: Array[Dictionary] = []
	return line_of(result.world) if result.ok else empty


static func _length_km(world: World) -> int:
	var max_km: float = 0.0
	for st: Station in world.stations.values():
		max_km = maxf(max_km, st.km)
	return int(roundf(max_km))


## Objetivos de la jornada: la nota A-D sale de calidad y percepción (data/rules/report.json).
static func _goals() -> Array[Dictionary]:
	var rules: ReportRules = ReportRules.load_default()
	var top: float = 85.0
	for g: Dictionary in rules.grades:
		if g["grade"] == &"A":
			top = float(g["min_score"])
	return [
		{"title": "Puntualidad", "text": "Mantén los servicios en hora: la calidad pesa un %d %% de la nota." % int(roundf(
				rules.weight_quality / (rules.weight_quality + rules.weight_perception) * 100.0)), "state": RcTokens.State.OK},
		{"title": "Viajeros informados", "text": "Avisa pronto a quien sufra un retraso: la percepción pesa el resto.",
				"state": RcTokens.State.SPECIAL},
		{"title": "Nota A", "text": "Alcanza %d puntos de media entre calidad y percepción y cierra la jornada con buen resultado económico." % int(top),
				"state": RcTokens.State.WARN},
	]


static func _resources(world: World, session: SimulationSession) -> Array[Dictionary]:
	var compositions: int = 0
	var reserve: Array[String] = []
	var drivers: int = 0
	var conductors: int = 0
	for rs: ResourceState in session.query_resource_states():
		if rs.resource_type == Enums.ResourceType.COMPOSITION:
			compositions += 1
		if rs.state == ResourceState.State.RESERVE:
			var st: Station = world.stations.get(rs.station_id)
			reserve.append("%s (%s)" % [rs.label, st.code if st != null else "—"])
	for member: StaffMember in world.staff.values():
		if member.role == Enums.StaffRole.DRIVER:
			drivers += 1
		else:
			conductors += 1
	var out: Array[Dictionary] = [
		{"label": "Composiciones", "value": str(compositions), "note": "material en servicio"},
		{"label": "Material de reserva", "value": str(reserve.size()),
				"note": ", ".join(reserve) if not reserve.is_empty() else "sin reserva"},
		{"label": "Maquinistas", "value": str(drivers), "note": "conducción"},
		{"label": "Interventores", "value": str(conductors), "note": "acompañamiento"},
	]
	return out
