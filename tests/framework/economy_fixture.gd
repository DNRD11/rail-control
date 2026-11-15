class_name EconomyFixture
extends RefCounted
## Utilidades de prueba de economía (Fase 6). Accede a las consultas de forma dinámica (Variant)
## para no depender de si el resultado es un objeto o un diccionario.

const D = preload("res://tests/framework/delay_fixture.gd")
const F = preload("res://tests/framework/incident_fixture.gd")

const S3109: StringName = &"svc_3109"
const CATEGORIES: Array[StringName] = [&"REVENUE", &"OPERATING_COST", &"STAFF_COST",
		&"INFRA_CHARGE_ORDINARY", &"INCIDENT_COST", &"SUBSTITUTION_COST", &"COMPENSATION"]


## Día completo sin avería ni retrasos.
static func quiet_day(seed_override: int = 12345, step: int = 100000) -> SimulationSession:
	var s: SimulationSession = SimFixture.session(seed_override)
	D.run_to(s, s.clock.day_end, step)
	return s


## Día completo con `seconds` de retraso inyectado en svc_3109 (sin sucesores en la rotación; llega 13:20 y la
## jornada acaba a las 15:00, así que admite hasta ~5 900 s) a las 10:00.
static func delayed_3109_day(seconds: int) -> SimulationSession:
	var s: SimulationSession = SimFixture.session()
	D.run_to_text(s, "10:00")
	if seconds > 0:
		s.apply_command(InjectDelayCommand.make(S3109, seconds))
	D.run_to(s, s.clock.day_end)
	return s


## Avería del 3103 con reparación `repair_s`; opcionalmente reserva consumida; opción decidida; informar opcional.
## `option` = &"" -> sin decidir (lo hará el tiempo agotado). `inform` = "" | "early" | "none".
static func incident_day(repair_s: int, option: StringName, reserve_consumed: bool = false,
		inform: bool = false, seed_override: int = 12345, step: int = 100000) -> SimulationSession:
	var s: SimulationSession = SimFixture.session_with_incident(seed_override, repair_s)
	D.run_to_text(s, "08:12", step)
	if reserve_consumed:
		s.world.vehicles[&"veh_v6"].status = Enums.VehicleStatus.MAINTENANCE
		s.incidents.refresh_options(F.incident(s), s)
	if option != &"":
		if not F.decide(s, option):
			return null
	if inform:
		s.apply_command(InformPassengersCommand.new(D.S3103, F.incident(s).id))
	D.run_to(s, s.clock.day_end, step)
	return s


static func cat_of(entry: Variant) -> String:
	return str(entry.get("category"))


static func entries_of(s: SimulationSession, category: StringName) -> Array:
	var out: Array = []
	var ledger: Variant = s.query_ledger()
	for e: Variant in ledger.entries:
		if cat_of(e) == String(category):
			out.append(e)
	return out


static func sum_amount(entries: Array) -> int:
	var t: int = 0
	for e: Variant in entries:
		t += int(e.get("amount_cents"))
	return t


## Entradas de un tipo de referencia y id concretos.
static func entries_ref(s: SimulationSession, ref_type: String, ref_id: StringName) -> Array:
	var out: Array = []
	var ledger: Variant = s.query_ledger()
	for e: Variant in ledger.entries:
		if str(e.get("ref_type")) == ref_type and str(e.get("ref_id")) == String(ref_id):
			out.append(e)
	return out


static func ledger_digest(s: SimulationSession) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var ledger: Variant = s.query_ledger()
	for e: Variant in ledger.entries:
		lines.append("%s|%d|%s|%s|%d" % [cat_of(e), int(e.get("amount_cents")),
				str(e.get("ref_type")), str(e.get("ref_id")), int(e.get("time"))])
	return "\n".join(lines).sha256_text()


static func indicators_text(s: SimulationSession) -> String:
	var i: Variant = s.query_indicators()
	var parts: PackedStringArray = PackedStringArray()
	for k: String in ["quality", "perception", "result_cents", "passengers_carried", "affected", "compensated"]:
		parts.append("%s=%s" % [k, str(i.get(k))])
	return ",".join(parts)


static func ind(s: SimulationSession, key: String) -> float:
	var i: Variant = s.query_indicators()
	return float(i.get(key))
