class_name LedgerEntry
extends RefCounted
## Apunte del libro. Importe en céntimos enteros: positivo = ingreso, negativo = coste (DATA_MODEL.md §9).

var id: StringName = &""
var time: int = 0
var category: StringName = &""
var amount_cents: int = 0
## Origen: SERVICE | INCIDENT | PAT (LedgerCategory.REF_*) y su id.
var ref_type: StringName = &""
var ref_id: StringName = &""
var description_key: StringName = &""
var details: Dictionary = {}
