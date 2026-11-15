class_name StateHash
extends RefCounted
## Huella del estado observable de una sesión: reloj, log de eventos, libro, indicadores y servicios.


static func of(s: SimulationSession) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("now=%d" % s.clock.now)
	lines.append("log=" + s.log.digest())
	for e: LedgerEntry in s.query_ledger().entries:
		lines.append("%s|%d|%s|%s|%d" % [e.category, e.amount_cents, e.ref_type, e.ref_id, e.time])
	var i: Indicators = s.query_indicators()
	lines.append("ind=%s,%s,%d,%d,%d,%d" % [str(i.quality), str(i.perception), i.result_cents,
			i.passengers_carried, i.affected, i.compensated])
	for sid: StringName in s.service_ids():
		var sv: Service = s.world.services[sid] as Service
		lines.append("svc=%s|%d|%d" % [sv.id, sv.status, s.delay_of(sv.id)])
	return "\n".join(lines).sha256_text()
