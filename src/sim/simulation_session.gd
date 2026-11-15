class_name SimulationSession
extends RefCounted
## Orquesta una jornada: reloj, cola de eventos, sistemas, log y comandos. RefCounted puro, headless.

signal clock_ticked(now: int)
signal speed_changed(speed: int)
signal service_updated(service_id: StringName)
signal service_stop_event(service_id: StringName, stop_index: int, kind: StringName)
signal incident_changed(incident_id: StringName)
signal ledger_changed(entry: LedgerEntry)
signal indicators_changed()
signal day_finished()

var world: World
var clock: SimClock = SimClock.new()
var queue: EventQueue = EventQueue.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var log: OperationalLog = OperationalLog.new()
var systems: Array[SimSystem] = []
var command_log: Array[Command] = []
var movement: MovementSystem
var delay: DelaySystem
var incidents: IncidentSystem
var economy: EconomySystem
var passenger: PassengerSystem
var perception: PerceptionSystem
var _day_finished_emitted: bool = false
var _rotation_graph: RotationGraph


static func create(p_world: World, seed_override: int = -1) -> SimulationSession:
	var s: SimulationSession = SimulationSession.new()
	s.world = p_world
	var sc: ScenarioInfo = p_world.scenario
	s.clock.day_start = sc.day_start
	s.clock.day_end = sc.day_end
	s.clock.now = sc.day_start
	s.clock.time_scale = sc.time_scale
	s.rng.seed = sc.seed if seed_override < 0 else seed_override
	s.queue.push(SimEventType.DAY_END, sc.day_end)
	s.movement = MovementSystem.new()
	s.delay = DelaySystem.new()
	s.register_system(s.movement)
	s.incidents = IncidentSystem.new()
	s.register_system(s.delay)
	s.register_system(s.incidents)
	s.economy = EconomySystem.new()
	s.passenger = PassengerSystem.new()
	s.perception = PerceptionSystem.new()
	s.register_system(s.passenger)
	s.register_system(s.economy)
	s.register_system(s.perception)
	s.service_updated.connect(s._on_service_updated)
	s.incident_changed.connect(s._on_incident_changed)
	s.economy.entry_added.connect(s._on_entry_added)
	return s


## Añade un sistema y lo arranca (puede programar eventos iniciales).
func register_system(sys: SimSystem) -> void:
	systems.append(sys)
	sys.start(self)


## Valida y aplica un comando. Devuelve false (con aviso) si no es válido.
func apply_command(cmd: Command) -> bool:
	var reason: String = cmd.validate(self)
	if reason != "":
		push_warning("Comando %s rechazado: %s" % [cmd.kind, reason])
		return false
	cmd.applied_at = clock.now
	cmd.apply(self)
	command_log.append(cmd)
	return true


## Avanza la simulación n segundos enteros (SIMULATION.md §3). No pasa de day_end.
func advance_seconds(n: int) -> void:
	if n <= 0 or clock.is_day_over():
		return
	var start: int = clock.now
	var target: int = mini(clock.now + n, clock.day_end)
	_run_events_until(target)
	clock.now = target
	if clock.now != start:
		clock_ticked.emit(clock.now)
	if clock.is_day_over() and not _day_finished_emitted:
		_day_finished_emitted = true
		day_finished.emit()


## Procesa los eventos pendientes cuya hora ya es la actual (p. ej. tras un comando que programa a `now`).
func process_due_events() -> void:
	if not clock.is_day_over():
		_run_events_until(clock.now)


func _run_events_until(target: int) -> void:
	while not queue.is_empty() and queue.peek().time <= target:
		var e: SimEvent = queue.pop()
		if e.cancelled:
			continue
		clock.now = maxi(clock.now, e.time)
		_dispatch(e)


## Grafo de rotaciones derivado de las asignaciones (se construye una vez; invalidar si cambian).
func rotation_graph() -> RotationGraph:
	if _rotation_graph == null:
		_rotation_graph = RotationGraph.build(world)
	return _rotation_graph


func invalidate_rotation_graph() -> void:
	_rotation_graph = null


## Recalcula las horas estimadas aguas abajo de un servicio (tras un cambio de est_*).
func propagate_delays(service_id: StringName) -> void:
	if delay != null:
		delay.propagate(service_id, self)


func _on_service_updated(service_id: StringName) -> void:
	passenger.on_service_updated(service_id, self)
	economy.on_service_updated(service_id, self)
	indicators_changed.emit()


func _on_incident_changed(incident_id: StringName) -> void:
	economy.on_incident_changed(incident_id, self)
	indicators_changed.emit()


func _on_entry_added(entry: LedgerEntry) -> void:
	ledger_changed.emit(entry)


func _dispatch(e: SimEvent) -> void:
	if e.type == SimEventType.DAY_END:
		log.add(e.time, e.type)
		economy.on_day_end(self)
		indicators_changed.emit()
		return
	for sys: SimSystem in systems:
		if sys.handles(e.type):
			sys.handle(e, self)


# --- Consultas de solo lectura ---

func query_service_position(service_id: StringName) -> ServicePosition:
	var s: Service = world.services.get(service_id) as Service
	if s == null:
		return null
	return ServicePositionCalc.compute(world, s, clock.now)


## Posición en un instante de simulación fraccional (interpolación visual) con las est_* vigentes.
func query_service_position_at(service_id: StringName, t: float) -> ServicePosition:
	var s: Service = world.services.get(service_id) as Service
	return ServicePositionCalc.compute_at(world, s, t) if s != null else null


## Posición teórica según el horario programado (sombra programada).
func query_scheduled_position(service_id: StringName, t: float) -> ServicePosition:
	var s: Service = world.services.get(service_id) as Service
	return ServicePositionCalc.compute_scheduled(world, s, t) if s != null else null


## Retraso vigente (s): est - programada del próximo punto pendiente, o real - programada del último.
func delay_of(service_id: StringName) -> int:
	var s: Service = world.services.get(service_id) as Service
	return DelaySystem.seconds_of(s) if s != null else 0


## Retraso vigente con su causa y nivel (null si el servicio no existe).
func delay_info(service_id: StringName) -> DelayInfo:
	var s: Service = world.services.get(service_id) as Service
	return delay.info_for(s) if s != null and delay != null else null


## Incidencias abiertas (esperan decisión o en curso), por orden de creación.
func open_incidents() -> Array[Incident]:
	return incidents.open_incidents()


## Todas las incidencias de la jornada, por orden de creación (historial).
func all_incidents() -> Array[Incident]:
	return incidents.incidents


func query_incident(incident_id: StringName) -> Incident:
	return incidents.get_incident(incident_id)


## Incidencia con las previsualizaciones recalculadas a la hora actual.
func query_incident_fresh(incident_id: StringName) -> Incident:
	var inc: Incident = incidents.get_incident(incident_id)
	if inc != null:
		incidents.refresh_options(inc, self)
	return inc


## Libro de la jornada (solo lectura).
func query_ledger() -> Ledger:
	return economy.ledger


## Calidad, percepción, resultado y viajeros de la jornada hasta ahora.
func query_indicators() -> Indicators:
	return perception.compute(self)


## Viajeros de un servicio con los contadores calculados ahora (copia; null si no hay datos).
func query_service_passengers(service_id: StringName) -> ServicePassengerLoad:
	return passenger.snapshot(service_id, self)


## Ids de servicios ordenados por código.
func service_ids() -> Array[StringName]:
	return SessionQueries.service_ids(world)


func query_service_resources(service_id: StringName) -> Array[ResourceSlot]:
	return SessionQueries.service_resources(world, service_id)


func query_service_chain(service_id: StringName) -> Array[ChainLink]:
	return SessionQueries.service_chain(world, rotation_graph(), service_id)


func query_resource_states() -> Array[ResourceState]:
	return SessionQueries.resource_states(world)


func query_service_summary(service_id: StringName) -> ServiceSummary:
	return SessionQueries.service_summary(world, service_id)


## Servicios en marcha o detenidos en estación (orden de inserción).
func active_service_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in world.services:
		var st: Enums.ServiceStatus = (world.services[sid] as Service).status
		if st == Enums.ServiceStatus.RUNNING or st == Enums.ServiceStatus.STOPPED_AT_STATION \
				or st == Enums.ServiceStatus.HELD or st == Enums.ServiceStatus.BOARDING:
			out.append(sid)
	return out
