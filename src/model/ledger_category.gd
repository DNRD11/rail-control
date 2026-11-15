class_name LedgerCategory
extends RefCounted
## Categorías del libro (ECONOMY.md §1) y tipos de referencia de las entradas.

const REVENUE: StringName = &"REVENUE"
const OPERATING_COST: StringName = &"OPERATING_COST"
const STAFF_COST: StringName = &"STAFF_COST"
const INFRA_CHARGE_ORDINARY: StringName = &"INFRA_CHARGE_ORDINARY"
const INCIDENT_COST: StringName = &"INCIDENT_COST"
const SUBSTITUTION_COST: StringName = &"SUBSTITUTION_COST"
const COMPENSATION: StringName = &"COMPENSATION"
# Reservadas (futuro, sin implementar en el MVP).
const PAT_ROAD: StringName = &"PAT_ROAD"
const SPECIAL_SERVICE_OPERATION: StringName = &"SPECIAL_SERVICE_OPERATION"
const INFRA_CHARGE_EXTRA: StringName = &"INFRA_CHARGE_EXTRA"

const MVP: Array[StringName] = [REVENUE, OPERATING_COST, STAFF_COST, INFRA_CHARGE_ORDINARY, INCIDENT_COST,
		SUBSTITUTION_COST, COMPENSATION]

const REF_SERVICE: StringName = &"SERVICE"
const REF_INCIDENT: StringName = &"INCIDENT"
const REF_PAT: StringName = &"PAT"  # futuro
