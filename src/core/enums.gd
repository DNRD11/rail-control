class_name Enums
extends RefCounted
## Enums compartidos por modelo, datos y simulación. Los nombres coinciden con los textos de los JSON.

enum Direction { ASCENDING, DESCENDING }
enum StopType { ORIGIN, STOP, PASS, DESTINATION }
enum StopStatus { PENDING, ARRIVED, DEPARTED, PASSED, SKIPPED, CANCELLED }
enum ServiceKind { COMMERCIAL, SPECIAL, EMPTY_RUN }
enum ServiceStatus { SCHEDULED, BOARDING, RUNNING, STOPPED_AT_STATION, HELD, TERMINATED, CANCELLED, PARTIALLY_CANCELLED }
enum VehicleStatus { AVAILABLE, IN_SERVICE, RESERVE, FAILED, UNDER_REPAIR, MAINTENANCE, OUT_OF_SERVICE }
enum CompositionStatus { ACTIVE, DISSOLVED }
enum StaffRole { DRIVER, CONDUCTOR }
enum StaffStatus { AVAILABLE, ON_DUTY, RESTING, ABSENT }
enum ResourceType { COMPOSITION, VEHICLE, DRIVER, CONDUCTOR }
enum AssignmentStatus { PLANNED, ACTIVE, COMPLETED, CANCELLED, REPLACED }
enum AssignmentSource { PLAN, PLAYER, INCIDENT_REPLACEMENT, PAT }
enum IncidentStatus { DETECTED, AWAITING_DECISION, IN_PROGRESS, RESOLVED, CLOSED }


## Nombre (JSON) → valor del enum. Devuelve `fallback` si no existe.
static func parse(enum_dict: Dictionary, text: String, fallback: int = -1) -> int:
	return int(enum_dict.get(text.strip_edges().to_upper(), fallback))


## Valor → nombre (JSON).
static func name_of(enum_dict: Dictionary, value: int) -> String:
	var key: Variant = enum_dict.find_key(value)
	return String(key) if key != null else "?"
