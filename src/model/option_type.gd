class_name OptionType
extends RefCounted
## Tipos de opción de decisión ante una incidencia. Extensible (PAT, servicio especial…).

const WAIT_REPAIR: StringName = &"WAIT_REPAIR"
const SUBSTITUTE_ROLLING_STOCK: StringName = &"SUBSTITUTE_ROLLING_STOCK"
const CANCEL_SERVICE: StringName = &"CANCEL_SERVICE"

const ALL: Array[StringName] = [WAIT_REPAIR, SUBSTITUTE_ROLLING_STOCK, CANCEL_SERVICE]
