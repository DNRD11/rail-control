class_name SimEventType
extends RefCounted
## Tipos de evento de la simulación y su prioridad a igual hora (menor = antes). Ver SIMULATION.md §3.

const INCIDENT_RESOLVED: StringName = &"INCIDENT_RESOLVED"
const SERVICE_ARRIVAL: StringName = &"SERVICE_ARRIVAL"
const SERVICE_PASS: StringName = &"SERVICE_PASS"
const SERVICE_DEPARTURE: StringName = &"SERVICE_DEPARTURE"
const STOP_END: StringName = &"STOP_END"
const ASSIGNMENT_START: StringName = &"ASSIGNMENT_START"
const ASSIGNMENT_END: StringName = &"ASSIGNMENT_END"
const DELAY_APPLIED: StringName = &"DELAY_APPLIED"
const INCIDENT_TRIGGER: StringName = &"INCIDENT_TRIGGER"
const DECISION_TIMEOUT: StringName = &"DECISION_TIMEOUT"
const SERVICE_CANCELLED: StringName = &"SERVICE_CANCELLED"
const PASSENGER_INFO_SENT: StringName = &"PASSENGER_INFO_SENT"
const DAY_END: StringName = &"DAY_END"

const DEFAULT_PRIORITY: int = 90

const PRIORITIES: Dictionary[StringName, int] = {
	INCIDENT_RESOLVED: 10,
	SERVICE_ARRIVAL: 20,
	SERVICE_PASS: 25,
	SERVICE_DEPARTURE: 30,
	STOP_END: 30,
	ASSIGNMENT_START: 40,
	ASSIGNMENT_END: 40,
	DELAY_APPLIED: 50,
	INCIDENT_TRIGGER: 60,
	DECISION_TIMEOUT: 70,
	SERVICE_CANCELLED: 80,
	PASSENGER_INFO_SENT: 90,
	DAY_END: 100,
}


static func priority_of(type: StringName) -> int:
	return PRIORITIES.get(type, DEFAULT_PRIORITY)
