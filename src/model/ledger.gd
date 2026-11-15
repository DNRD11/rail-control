class_name Ledger
extends RefCounted
## Libro de la jornada: apuntes en orden de registro. Solo se añade, nunca se modifica (ECONOMY.md §1).

var entries: Array[LedgerEntry] = []
var _next: int = 1


## Añade un apunte y lo devuelve. Un importe 0 no se registra (devuelve null).
func add(time: int, category: StringName, amount_cents: int, ref_type: StringName, ref_id: StringName,
		description_key: StringName = &"", details: Dictionary = {}) -> LedgerEntry:
	if amount_cents == 0:
		return null
	var e: LedgerEntry = LedgerEntry.new()
	e.id = StringName("led_%05d" % _next)
	_next += 1
	e.time = time
	e.category = category
	e.amount_cents = amount_cents
	e.ref_type = ref_type
	e.ref_id = ref_id
	e.description_key = description_key
	e.details = details
	entries.append(e)
	return e


func total_cents() -> int:
	var t: int = 0
	for e: LedgerEntry in entries:
		t += e.amount_cents
	return t


func total_by_category(category: StringName) -> int:
	var t: int = 0
	for e: LedgerEntry in entries:
		if e.category == category:
			t += e.amount_cents
	return t


## Apuntes de un origen concreto (p. ej. SERVICE / svc_3103).
func entries_for_ref(ref_type: StringName, ref_id: StringName) -> Array[LedgerEntry]:
	var out: Array[LedgerEntry] = []
	for e: LedgerEntry in entries:
		if e.ref_type == ref_type and e.ref_id == ref_id:
			out.append(e)
	return out


func entries_in_category(category: StringName) -> Array[LedgerEntry]:
	var out: Array[LedgerEntry] = []
	for e: LedgerEntry in entries:
		if e.category == category:
			out.append(e)
	return out
