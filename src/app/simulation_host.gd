class_name SimulationHost
extends Node
## Único puente entre el árbol de escenas y la simulación (RefCounted).
## Acumula el delta real y llama a session.advance_seconds(int).

signal clock_ticked(now: int)
signal speed_changed(speed: int)
signal service_updated(service_id: StringName)
signal service_stop_event(service_id: StringName, stop_index: int, kind: StringName)
signal day_finished()

var session: SimulationSession = null

var _accumulator: StepAccumulator = StepAccumulator.new()


func _ready() -> void:
	set_process(false)


func start(new_session: SimulationSession) -> void:
	_disconnect_session()
	session = new_session
	_accumulator.reset()
	if session == null:
		set_process(false)
		return
	session.clock_ticked.connect(_on_clock_ticked)
	session.speed_changed.connect(_on_speed_changed)
	session.service_updated.connect(_on_service_updated)
	session.service_stop_event.connect(_on_service_stop_event)
	session.day_finished.connect(_on_day_finished)
	set_process(true)


func stop() -> void:
	_disconnect_session()
	session = null
	set_process(false)


func set_speed(speed: int) -> bool:
	if session == null:
		return false
	var cmd: SetSpeedCommand = SetSpeedCommand.new()
	cmd.speed = speed
	return session.apply_command(cmd)


func pause() -> void:
	set_speed(0)


func resume(speed: int = 1) -> void:
	set_speed(speed)


func get_speed() -> int:
	return 0 if session == null else session.clock.speed


## Resto fraccional del acumulador, para interpolar la presentación.
func get_fraction() -> float:
	return _accumulator.fraction()


func _process(delta: float) -> void:
	if session == null or session.clock.is_day_over():
		return
	var n: int = _accumulator.feed(delta, session.clock.time_scale, session.clock.speed)
	if n > 0:
		session.advance_seconds(n)


func _disconnect_session() -> void:
	if session == null:
		return
	session.clock_ticked.disconnect(_on_clock_ticked)
	session.speed_changed.disconnect(_on_speed_changed)
	session.service_updated.disconnect(_on_service_updated)
	session.service_stop_event.disconnect(_on_service_stop_event)
	session.day_finished.disconnect(_on_day_finished)


func _on_clock_ticked(now: int) -> void:
	clock_ticked.emit(now)


func _on_speed_changed(speed: int) -> void:
	speed_changed.emit(speed)


func _on_service_updated(service_id: StringName) -> void:
	service_updated.emit(service_id)


func _on_service_stop_event(service_id: StringName, stop_index: int, kind: StringName) -> void:
	service_stop_event.emit(service_id, stop_index, kind)


func _on_day_finished() -> void:
	day_finished.emit()
