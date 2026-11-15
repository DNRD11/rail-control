class_name DelayInfo
extends RefCounted
## Retraso vigente de un servicio y su causa (solo lectura para la UI).

const LEVEL_ON_TIME: StringName = &"ON_TIME"
const LEVEL_MINOR: StringName = &"MINOR"
const LEVEL_MAJOR: StringName = &"MAJOR"
const LEVEL_SEVERE: StringName = &"SEVERE"

const CAUSE_NONE: StringName = &"NONE"
const CAUSE_INJECTED: StringName = &"INJECTED"
const CAUSE_ROTATION_MATERIAL: StringName = &"ROTATION_MATERIAL"
const CAUSE_ROTATION_STAFF: StringName = &"ROTATION_STAFF"
const CAUSE_BREAKDOWN: StringName = &"BREAKDOWN"

const MINOR_MAX_S: int = 180
const MAJOR_MAX_S: int = 900
const SEVERE_MIN_S: int = 3600

var service_id: StringName = &""
## Retraso estimado en el próximo punto pendiente (o el real del último ocurrido).
var seconds: int = 0
var cause: StringName = CAUSE_NONE
var source_service_id: StringName = &""
var resource_id: StringName = &""
var level: StringName = LEVEL_ON_TIME


static func level_for(delay_s: int) -> StringName:
	if delay_s <= MINOR_MAX_S:
		return LEVEL_ON_TIME
	if delay_s <= MAJOR_MAX_S:
		return LEVEL_MINOR
	if delay_s <= SEVERE_MIN_S:
		return LEVEL_MAJOR
	return LEVEL_SEVERE
