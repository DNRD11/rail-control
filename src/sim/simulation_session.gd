class_name SimulationSession
extends RefCounted
## Orquesta una jornada: reloj, cola de eventos, sistemas, log y comandos. RefCounted puro, headless.

signal clock_ticked(now: int)
signal speed_changed(speed: int)
signal service_updated(service_id: StringName)
signal service_stop_event(service_id: StringName, stop_index: int, kind: StringName)
signal day_finished()

var world: World
var clock: SimClock = SimClock.new()
var queue: EventQueue = EventQueue.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var log: OperationalLog = OperationalLog.new()
var systems: Array[SimSystem] = []
var command_log: Array[Command] = []
var _day_finished_emitted: bool = false


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
	s.register_system(MovementSystem.new())
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
	while not queue.is_empty() and queue.peek().time <= target:
		var e: SimEvent = queue.pop()
		clock.now = maxi(clock.now, e.time)
		_dispatch(e)
	clock.now = target
	if clock.now != start:
		clock_ticked.emit(clock.now)
	if clock.is_day_over() and not _day_finished_emitted:
		_day_finished_emitted = true
		day_finished.emit()


func _dispatch(e: SimEvent) -> void:
	if e.type == SimEventType.DAY_END:
		log.add(e.time, e.type)
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


## Retraso conocido (s): diferencia entre lo real y lo programado en el último punto alcanzado. 0 sin retrasos.
func delay_of(service_id: StringName) -> int:
	var s: Service = world.services.get(service_id) as Service
	if s == null:
		return 0
	for i: int in range(s.stops.size() - 1, -1, -1):
		var st: ServiceStop = s.stops[i]
		if st.act_dep != SimTime.NONE and st.exit_time() != SimTime.NONE:
			return st.act_dep - st.exit_time()
		if st.act_arr != SimTime.NONE and st.entry_time() != SimTime.NONE:
			return st.act_arr - st.entry_time()
	return 0


## Servicios en marcha o detenidos en estación (orden de inserción).
func active_service_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for sid: StringName in world.services:
		var st: Enums.ServiceStatus = (world.services[sid] as Service).status
		if st == Enums.ServiceStatus.RUNNING or st == Enums.ServiceStatus.STOPPED_AT_STATION \
				or st == Enums.ServiceStatus.HELD or st == Enums.ServiceStatus.BOARDING:
			out.append(sid)
	return out
