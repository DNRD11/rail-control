class_name SimSystem
extends RefCounted
## Base de los sistemas de simulación: declaran los tipos de evento que manejan.


## La sesión lo llama al registrar el sistema (programar eventos iniciales).
func start(_session: SimulationSession) -> void:
	pass


func handles(_type: StringName) -> bool:
	return false


func handle(_event: SimEvent, _session: SimulationSession) -> void:
	pass
